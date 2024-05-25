{
	Copyright (c) 2020 Alan Williams

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
}

{$I-}
{-$DEFINE EXT_MEM_DEBUG}
unit ExtMem;

interface
	type
		TExtMemType = (NoMem, Conv, Ems, Xms);
		TExtMemBlockPtr = ^TExtMemBlock;
		TExtMemBlock = record
			case MemType: TExtMemType of
				Conv: (Ptr: pointer);
				Ems: (Pages: array[0 .. 3] of word);
				Xms: (Offset: longint; Next: TExtMemBlockPtr);
				NoMem: ();
		end;
	function ExtMemXmsAvail: longint;
	function ExtMemEmsAvailPages: word;
	procedure ExtMemInstall(useEms: boolean; useXms: boolean);
	function ExtMemGet(var block: TExtMemBlock; size: word): boolean;
	procedure ExtMemWrite(var block: TExtMemBlock; var data; count: word);
	procedure ExtMemRead(var block: TExtMemBlock; var data; count: word);
	procedure ExtMemFree(var block: TExtMemBlock; size: word);
	procedure ExtMemUninstall;
	procedure ExtMemMoveBlockPtr(var blockFrom, blockTo: TExtMemBlock);
	function ExtMemEmsActive: boolean;
	function ExtMemXmsActive: boolean;
implementation
uses Dos;
const
	{ 256 boards at 64K each (16M) is the largest any ZZT world }
	{ could possibly be without major changes }
	EXT_MEM_MAX_ALLOC = 16777216;

	XMS_MIN_VERSION = $0200;

	EMS_MIN_VERSION = $32;
	EMS_MAX_PAGES = (EXT_MEM_MAX_ALLOC + 16383) div 16384;
	EMS_MAX_PAGE_SETS = (EMS_MAX_PAGES + 255) div 256;

	XmsControl: pointer = nil;
	XmsSize: longint = 0;
	XmsHandle: word = 0;
	XmsAllocPoint: longint = 0;
	XmsHead: TExtMemBlockPtr = nil;

	EmsFrame: pointer = nil;
	EmsHandle: word = 0;
	EmsPageCount: word = 0;
	EmsPageAvail: word = 0;
	EmsLastPage: word = 0;

	{$IFDEF EXT_MEM_DEBUG}
	ExtMemInstalled: boolean = false;
	{$ENDIF}
var
	ConvError: boolean;
	EmsPageSets: array[0 .. EMS_MAX_PAGE_SETS-1] of set of byte;
	{$IFDEF EXT_MEM_DEBUG}
	ExtMemDebug: text;
	{$ENDIF}

type
	ExtMemMoveStruct = record
		Length: longint;
		SourceHandle: word;
		SourceOffset: longint;
		DestHandle: word;
		DestOffset: longint;
	end;

{$IFNDEF FPC}
{$F+}

function ConvErrorHandler(size: word): integer;
	begin
		ConvError := true;
		ConvErrorHandler := 1; { prevent runtime error }
	end;

function ConvDefErrorHandler(size: word): integer;
	begin
		ConvDefErrorHandler := 0; { crash! }
	end;

{$F-}
{$ENDIF}

function ExtMemEmsActive: boolean;
	begin
		ExtMemEmsActive := EmsHandle <> 0;
	end;

function ExtMemXmsActive: boolean;
	begin
		ExtMemXmsActive := XmsControl <> nil;
	end;

function XmsPresent: boolean;
	var
		regs: Registers;
	begin
		regs.AX := $4300;
		Intr($2F, regs);
		XmsPresent := regs.AL = $80;
	end;

function XmsGetControlProc: pointer;
	var
		regs: Registers;
	begin
		regs.AX := $4310;
		Intr($2F, regs);
		XmsGetControlProc := Ptr(regs.ES, regs.BX);
	end;

{$IFNDEF FPC}
function XmsVersion: word;
	var
		version: word;
	begin
		if XmsControl <> nil then begin
			inline(
				$B4/$00/              { MOV AH, 0x00 }
				$FF/$1E/>XmsControl/  { CALL FAR [XmsControl] }
				$89/$46/<version      { MOV [BP+version], AX }
			);
			XmsVersion := version;
		end else
			XmsVersion := 0;
	end;

function XmsMaxAvail: word;
	var
		avail: word;
	begin
		if XmsControl <> nil then begin
			inline(
				$B4/$08/              { MOV AH, 0x08 }
				$FF/$1E/>XmsControl/  { CALL FAR [XmsControl] }
				$89/$46/<avail        { MOV [BP+avail], AX }
			);
			XmsMaxAvail := avail;
		end else
			XmsMaxAvail := 0;
	end;

function XmsAlloc(size: word): word;
	var
		handle: word;
	begin
		if XmsControl <> nil then begin
			inline(
				$B4/$09/              { MOV AH, 0x09 }
				$8B/$56/<size/        { MOV DX, [BP+size] }
				$FF/$1E/>XmsControl/  { CALL FAR [XmsControl] }
				$83/$F8/$01/          { CMP AX, 0x0001 }
				$74/$02/              { JE success }
				$31/$D2/              { XOR DX, DX }
				{ success }
				$89/$56/<handle       { MOV [BP+handle], DX }
			);
			XmsAlloc := handle;
		end else
			XmsAlloc := 0;
	end;

procedure XmsDealloc(handle: word);
	begin
		if XmsControl <> nil then begin
			inline(
				$B4/$0A/             { MOV AH, 0x0A }
				$8B/$56/<handle/     { MOV DX, [BP+handle] }
				$FF/$1E/>XmsControl  { CALL FAR [XmsControl] }
			);
		end;
	end;

procedure XmsCopy(var moveStruct: ExtMemMoveStruct);
	begin
		if XmsControl <> nil then begin
			inline(
				$1E/                      { PUSH DS }
				$1E/                      { PUSH DS }
				$07/                      { POP ES }
				$B4/$0B/                  { MOV AH, 0x0B }
				$C5/$76/<moveStruct/      { LDS SI, [BP+moveStruct] }
				$26/$FF/$1E/>XmsControl/  { CALL FAR [ES:XmsControl] }
				$1F                       { POP DS }
			);
		end;
	end;
{$ELSE}
function XmsVersion: word;
	var
		version: word;
	begin
		if XmsControl <> nil then begin
			asm
				mov ah, 00h
				call far [XmsControl]
				mov version, ax
			end ['ax', 'bx', 'dx'];
			XmsVersion := version;
		end else
			XmsVersion := 0;
	end;

function XmsMaxAvail: word;
	var
		avail: word;
	begin
		if XmsControl <> nil then begin
			asm
				mov ah, 08h
				call far [XmsControl]
				mov avail, ax;
			end ['ax', 'bx', 'dx'];
			XmsMaxAvail := avail;
		end else
			XmsMaxAvail := 0;
	end;

function XmsAlloc(size: word): word;
	var
		handle: word;
	label success;
	begin
		if XmsControl <> nil then begin
			asm
				mov ah, 09h
				mov dx, size
				call far [XmsControl]
				cmp ax, 1
				je success
				xor dx, dx
			success:
				mov handle, dx
			end ['ax', 'bx', 'dx'];
			XmsAlloc := handle;
		end else
			XmsAlloc := 0;
	end;

procedure XmsDealloc(handle: word);
	begin
		if XmsControl <> nil then begin
			asm
				mov ah, 0Ah
				mov dx, handle
				call far [XmsControl]
			end ['ax', 'bx', 'dx'];
		end;
	end;

procedure XmsCopy(var moveStruct: ExtMemMoveStruct);
	begin
		if XmsControl <> nil then begin
			asm
				push es
				push ds
				push ds
				pop es
				mov ah, 0Bh
				lds si, moveStruct
				call far es:[XmsControl]
				pop ds
				pop es
			end ['ax', 'bx', 'dx', 'si'];
		end;
	end;
{$ENDIF}

procedure XmsCopyIn(var source; destHandle: word; destOffset: longint; count: longint);
	var
		moveStruct: ExtMemMoveStruct;
	begin
		moveStruct.Length := count;
		moveStruct.SourceHandle := 0;
		moveStruct.SourceOffset := (LongInt(Seg(source)) shl 16) + Ofs(source);
		moveStruct.DestHandle := destHandle;
		moveStruct.DestOffset := destOffset;
		XmsCopy(moveStruct);
	end;

procedure XmsCopyOut(sourceHandle: word; sourceOffset: longint; var dest; count: longint);
	var
		moveStruct: ExtMemMoveStruct;
	begin
		moveStruct.Length := count;
		moveStruct.SourceHandle := sourceHandle;
		moveStruct.SourceOffset := sourceOffset;
		moveStruct.DestHandle := 0;
		moveStruct.DestOffset := (LongInt(Seg(dest)) shl 16) + Ofs(dest);
		XmsCopy(moveStruct);
	end;

procedure XmsCopyExt(sourceHandle: word; sourceOffset: longint; destHandle: word; destOffset: longint; count: longint);
	var
		moveStruct: ExtMemMoveStruct;
	begin
		moveStruct.Length := count;
		moveStruct.SourceHandle := sourceHandle;
		moveStruct.SourceOffset := sourceOffset;
		moveStruct.DestHandle := destHandle;
		moveStruct.DestOffset := destOffset;
		XmsCopy(moveStruct);
	end;

function RoundUp(a, b: longint): longint;
	begin
		RoundUp := (a + (b - 1)) div b;
	end;

function XmsInstall(maxAlloc: longint; useXms: boolean): longint;
	var
		regs: Registers;
		version: word;
		avail: word;
	begin
		XmsInstall := maxAlloc;
		XmsControl := nil;
		if maxAlloc <= 0 then exit;
		if not useXms then exit;
		if not XmsPresent then exit;
		XmsControl := XmsGetControlProc;
		version := XmsVersion;
		if version < XMS_MIN_VERSION then begin
			XmsControl := nil;
			exit;
		end;
		{ Allocate as much as we can up to maxAlloc bytes }
		avail := XmsMaxAvail;
		if avail = 0 then begin
			XmsControl := nil;
			exit;
		end;
		if avail > RoundUp(maxAlloc, 1024) then
			avail := RoundUp(maxAlloc, 1024);
		XmsSize := LongInt(avail) * 1024;
		XmsHandle := XmsAlloc(avail);
		XmsAllocPoint := 0;
		XmsHead := nil;
		if XmsHandle = 0 then begin
			XmsControl := nil;
			exit;
		end;
		if XmsSize > maxAlloc then
			XmsInstall := 0
		else
			XmsInstall := maxAlloc - XmsSize;
	end;

function XmsGet(var block: TExtMemBlock; size: word): boolean;
	var
		newAllocPoint: longint;
	begin
		XmsGet := false;
		if XmsControl = nil then exit;
		newAllocPoint := XmsAllocPoint + size + (size and 1);
		if newAllocPoint > XmsSize then exit;
		block.MemType := Xms;
		block.Offset := XmsAllocPoint;
		block.Next := XmsHead;
		XmsHead := @block;
		XmsAllocPoint := newAllocPoint;
		XmsGet := true;
	end;

procedure XmsWrite(var block: TExtMemBlock; var data; count: word);
	begin
		XmsCopyIn(data, XmsHandle, block.Offset, LongInt(count) + (count and 1));
	end;

procedure XmsRead(var block: TExtMemBlock; var data; count: word);
	var
		overPtr: ^byte;
		over: byte;
	begin
		{ XMS copies memory word-by-word }
		{ so preserve the next byte over }
		{ by reading before and writing after }
		overPtr := Ptr(Seg(data), Ofs(data) + count);
		over := overPtr^;
		XmsCopyOut(XmsHandle, block.Offset, data, LongInt(count) + (count and 1));
		overPtr^ := over;
	end;

procedure XmsUnlink(var block: TExtMemBlock);
	var
		blockPtr: ^TExtMemBlockPtr;
	begin
		blockPtr := @XmsHead;
		while blockPtr^ <> nil do begin
			if blockPtr^ = @block then
				blockPtr^ := block.Next
			else
				blockPtr := Addr(blockPtr^^.Next);
		end;
	end;

procedure XmsFree(var block: TExtMemBlock; size: word);
	var
		blockPtr: TExtMemBlockPtr;
		oldOffset: longint;
		newOffset: longint;
	begin
		XmsUnlink(block);
		if size > 0 then begin
			{ Move all allocated memory after the freed block backwards }
			oldOffset := block.Offset;
			XmsAllocPoint := XmsAllocPoint - size - (size and 1);
			while oldOffset < XmsAllocPoint do begin
				newOffset := oldOffset + size + (size and 1);
				if newOffset <= XmsAllocPoint then
					XmsCopyExt(XmsHandle, newOffset, XmsHandle, oldOffset, newOffset - oldOffset)
				else
					XmsCopyExt(XmsHandle, newOffset, XmsHandle, oldOffset, XmsAllocPoint - oldOffset);
				oldOffset := newOffset;
			end;
			{ Update offsets in XMS TExtMemBlock records }
			oldOffset := block.Offset;
			blockPtr := XmsHead;
			while blockPtr <> nil do begin
				if blockPtr^.Offset > oldOffset then
					blockPtr^.Offset := blockPtr^.Offset - size - (size and 1);
				blockPtr := blockPtr^.Next;
			end;
		end;
	end;

procedure XmsOnMoveBlockPtr(var blockFrom, blockTo: TExtMemBlock);
	var
		blockPtr: TExtMemBlockPtr;
	begin
		if @blockFrom = XmsHead then begin
			XmsHead := @blockTo;
		end else begin
			blockPtr := XmsHead;
			while blockPtr <> nil do begin
				if @blockFrom = blockPtr^.Next then begin
					blockPtr^.Next := @blockTo;
					exit;
				end;
				blockPtr := blockPtr^.Next;
			end;
		end;
	end;

procedure ExtMemMoveBlockPtr(var blockFrom, blockTo: TExtMemBlock);
	begin
		case blockFrom.MemType of
			Xms: XmsOnMoveBlockPtr(blockFrom, blockTo);
		end;
		blockTo := blockFrom;
	end;
	
function ExtMemXmsAvail: longint;
	begin
		if XmsControl <> nil then
			ExtMemXmsAvail := XmsSize - XmsAllocPoint
		else
			ExtMemXmsAvail := 0;
	end;

procedure XmsUninstall;
	begin 
		if XmsControl = nil then exit;
		XmsDealloc(XmsHandle);
		XmsControl := nil;
		XmsHead := nil;
	end;

function EmsPresent: boolean;
	var
		regs: Registers;
		filename: string[9];
		handle: word;
	label CloseHandle;
	begin
		EmsPresent := false;
		{ Open EMS device file }
		filename := 'EMMXXXX0'#0;
		regs.AX := $3D00;
		regs.DX := Ofs(filename) + 1;
		regs.DS := Seg(filename);
		MsDos(regs);
		if (regs.Flags and FCarry) <> 0 then exit;
		handle := regs.AX;
		{ Check if a device or regular file }
		regs.AX := $4400;
		regs.BX := handle;
		MsDos(regs);
		if (regs.Flags and FCarry) <> 0 then goto CloseHandle;
		if (regs.DX and (1 shl 7)) = 0 then goto CloseHandle;
		{ Check if device is ready }
		regs.AX := $4407;
		regs.BX := handle;
		MsDos(regs);
		if regs.AL <> $FF then goto CloseHandle;
		EmsPresent := true;
	CloseHandle:
		regs.AH := $3E;
		regs.BX := handle;
		MsDos(regs);
	end;

function EmsFrameSeg: word;
	var
		regs: Registers;
	begin
		regs.AH := $41;
		Intr($67, regs);
		if regs.AH = 0 then
			EmsFrameSeg := regs.BX
		else
			EmsFrameSeg := 0;
	end;

function EmsMaxPagesAvail: word;
	var
		regs: Registers;
	begin
		regs.AH := $42;
		Intr($67, regs);
		if regs.AH = 0 then
			EmsMaxPagesAvail := regs.BX
		else
			EmsMaxPagesAvail := 0;
	end;

function EmsAllocPages(numPages: word): word;
	var
		regs: Registers;
	begin
		regs.AH := $43;
		regs.BX := numPages;
		Intr($67, regs);
		if regs.AH = 0 then
			EmsAllocPages := regs.DX
		else
			EmsAllocPages := 0;
	end;

procedure EmsMapPage(handle: word; logicalPage: word; physicalPage: byte);
	var
		regs: Registers;
	begin
		regs.AH := $44;
		regs.AL := physicalPage;
		regs.BX := logicalPage;
		regs.DX := handle;
		Intr($67, regs);
	end;

procedure EmsDeallocPages(handle: word);
	var
		regs: Registers;
	begin
		regs.AH := $45;
		regs.DX := handle;
		Intr($67, regs);
	end;

function EmsVersion: byte;
	var
		regs: Registers;
	begin
		regs.AH := $46;
		Intr($67, regs);
		if regs.AH = 0 then
			EmsVersion := regs.AL
		else
			EmsVersion := 0;
	end;

function EmsInstall(maxAlloc: longint; useEms: boolean): longint;
	var
		avail, i: word;
	begin
		EmsInstall := maxAlloc;
		EmsHandle := 0;
		if maxAlloc <= 0 then exit;
		if not useEms then exit;
		if not EmsPresent then exit;
		if EmsVersion < EMS_MIN_VERSION then exit;
		EmsFrame := Ptr(EmsFrameSeg, 0);
		if Seg(EmsFrame^) = 0 then exit;
		avail := EmsMaxPagesAvail;
		if avail = 0 then exit;
		if avail > RoundUp(maxAlloc, 16384) then
			avail := RoundUp(maxAlloc, 16384);
		EmsHandle := EmsAllocPages(avail);
		if EmsHandle = 0 then exit;
		EmsPageCount := avail;
		EmsPageAvail := avail;
		EmsLastPage := 0;
		for i := 0 to EMS_MAX_PAGE_SETS - 1 do begin
			if EmsPageCount > i * 256 then begin
				if EmsPageCount < (i + 1) * 256 then
					EmsPageSets[i] := [0 .. EmsPageCount - (i * 256) - 1]
				else
					EmsPageSets[i] := [0 .. 255];
			end else
				EmsPageSets[i] := [];
		end;
		if LongInt(avail) * 16384 > maxAlloc then
			EmsInstall := 0
		else
			EmsInstall := maxAlloc - (LongInt(avail) * 16384);
	end;

function EmsGetPage: word;
	var
		lastPage: byte;
		lastSet: word;
	begin
		lastPage := EmsLastPage mod 256;
		lastSet := EmsLastPage div 256;
		while not (lastPage in EmsPageSets[lastSet]) do begin
			if EmsPageSets[lastSet] = [] then
				EmsLastPage := lastSet * 256
			else
			Inc(EmsLastPage);
			if EmsLastPage >= EmsPageCount then
				EmsLastPage := 0;
			lastPage := EmsLastPage mod 256;
			lastSet := EmsLastPage div 256;
		end;
		Dec(EmsPageAvail);
		EmsGetPage := EmsLastPage;
		EmsPageSets[lastSet] := EmsPageSets[lastSet] - [lastPage];
		Inc(EmsLastPage);
		if EmsLastPage >= EmsPageCount then
			EmsLastPage := 0;
	end;

function EmsGet(var block: TExtMemBlock; size: word): boolean;
	var
		numPages, i: word;
	begin
		EmsGet := false;
		if EmsHandle = 0 then exit;
		numPages := RoundUp(size, 16384);
		if numPages > EmsPageAvail then exit;
		block.MemType := Ems;
		for i := 0 to numPages - 1 do
			block.Pages[i] := EmsGetPage;
		EmsGet := true;
	end;

procedure EmsWrite(var block: TExtMemBlock; var data; count: word);
	var
		numPages, i: word;
	begin
		if count = 0 then exit;
		numPages := RoundUp(count, 16384);
		for i := 0 to numPages - 1 do
			EmsMapPage(EmsHandle, block.Pages[i], i);
		Move(data, EmsFrame^, count);
	end;

procedure EmsRead(var block: TExtMemBlock; var data; count: word);
	var
		numPages, i: word;
	begin
		if count = 0 then exit;
		numPages := RoundUp(count, 16384);
		for i := 0 to numPages - 1 do
			EmsMapPage(EmsHandle, block.Pages[i], i);
		Move(EmsFrame^, data, count);
	end;

procedure EmsFreePage(page: word);
	var
		lastPage: byte;
		lastSet: word;
	begin
		lastPage := page mod 256;
		lastSet := page div 256;
		Inc(EmsPageAvail);
		EmsPageSets[lastSet] := EmsPageSets[lastSet] + [lastPage];
	end;

procedure EmsFree(var block: TExtMemBlock; size: word);
	var
		numPages, i: word;
	begin
		if size = 0 then exit;
		numPages := RoundUp(size, 16384);
		for i := 0 to numPages - 1 do
			EmsFreePage(block.Pages[i]);
	end;

procedure EmsUninstall;
	begin
		if EmsHandle = 0 then exit;
		EmsDeallocPages(EmsHandle);
		EmsHandle := 0;
	end;

function ExtMemEmsAvailPages: word;
	begin
		if EmsHandle <> 0 then
			ExtMemEmsAvailPages := EmsPageAvail
		else
			ExtMemEmsAvailPages := 0;
	end;

function ConvGet(var block: TExtMemBlock; size: word): boolean;
	begin
{$IFNDEF FPC}
		HeapError := @ConvErrorHandler;
		ConvError := false;

		block.MemType := Conv;
		GetMem(block.Ptr, size);

		HeapError := @ConvDefErrorHandler;
		ConvGet := not ConvError;
{$ELSE}
		ReturnNilIfGrowHeapfails := true;

		block.MemType := Conv;
		GetMem(block.Ptr, size);

		ReturnNilIfGrowHeapfails := false;
		ConvGet := block.Ptr <> nil;
{$ENDIF}
	end;

procedure ConvWrite(var block: TExtMemBlock; var data; count: word);
	begin
		Move(data, block.Ptr^, count);
	end;

procedure ConvRead(var block: TExtMemBlock; var data; count: word);
	begin
		Move(block.Ptr^, data, count);
	end;

procedure ConvFree(var block: TExtMemBlock; size: word);
	begin
		FreeMem(block.Ptr, size);
	end;

{$IFDEF EXT_MEM_DEBUG}
procedure ExtMemDebugState;
	begin
		WriteLn(ExtMemDebug, 'Status: ', ExtMemXmsAvail, ' ', ExtMemEmsAvailPages);
		Flush(ExtMemDebug);
	end;

function WordHexString(w: word): string;
	var
		digits: string[16];
		buf: string[4];
		i: integer;
	begin
		digits := '0123456789ABCDEF';
		buf := '    ';
		for i := 4 downto 1 do begin
			buf[i] := digits[(w and $F) + 1];
			w := w shr 4;
		end;
		WordHexString := buf;
	end;

function PointerString(p: pointer): string;
	begin
		PointerString := WordHexString(Seg(p^)) + ':' + WordHexString(Ofs(p^));
	end;

procedure ExtMemDebugBlock(var block: TExtMemBlock);
	var
		i: integer;
	begin
		case block.MemType of
			NoMem: Write(ExtMemDebug, 'Block: Null  @');
			Conv: Write(ExtMemDebug, 'Block: Conventional ', PointerString(block.Ptr), '  @');
			Ems: begin
				Write(ExtMemDebug, 'Block: EMS [ ');
				for i := 0 to 3 do
					Write(ExtMemDebug, WordHexString(block.Pages[i]), ' ');
				Write(ExtMemDebug, ']  @');
			end;
			Xms: Write(ExtMemDebug, 'Block: XMS ', block.Offset, ' ->', PointerString(block.Next), '  @');
		else
			Write(ExtMemDebug, 'Block: Unknown ', Integer(block.MemType), '  @')
		end;
		WriteLn(ExtMemDebug, PointerString(@block));
		ExtMemDebugState;
	end;
{$ENDIF}

procedure ExtMemInstall(useEms: boolean; useXms: boolean);
	var
		extAlloc: longint;
	begin
		extAlloc := EXT_MEM_MAX_ALLOC;
		extAlloc := XmsInstall(extAlloc, useXms);
		extAlloc := EmsInstall(extAlloc, useEms);

{$IFNDEF FPC}
		HeapError := @ConvDefErrorHandler;
{$ELSE}
		ReturnNilIfGrowHeapfails := false;
{$ENDIF}

		{$IFDEF EXT_MEM_DEBUG}
		ExtMemInstalled := true;
		Assign(ExtMemDebug, 'MEMDEBUG.LOG');
		Append(ExtMemDebug);
		if IOResult <> 0 then Rewrite(ExtMemDebug);
		WriteLn(ExtMemDebug, '---------- ExtMemInstall ----------');
		ExtMemDebugState;
		{$ENDIF}
	end;

function ExtMemGet(var block: TExtMemBlock; size: word): boolean;
	label Done;
	begin
		{$IFDEF EXT_MEM_DEBUG}
		if not ExtMemInstalled then RunError(204);
		WriteLn(ExtMemDebug, '-- ExtMemGet ', size, ' --');
		ExtMemDebugBlock(block);
		{$ENDIF}
		{ Unlink block from XMS block list }
		{ in case we're overwriting an allocated XMS block }
		XmsUnlink(block);
		block.MemType := NoMem;
		if size = 0 then goto Done;
		if XmsGet(block, size) then goto Done;
		if EmsGet(block, size) then goto Done;
		if ConvGet(block, size) then goto Done;
		ExtMemGet := false;
		exit;
	Done:
		{$IFDEF EXT_MEM_DEBUG}
		ExtMemDebugBlock(block);
		{$ENDIF}
		ExtMemGet := true;
	end;

procedure ExtMemWrite(var block: TExtMemBlock; var data; count: word);
	begin
		{$IFDEF EXT_MEM_DEBUG}
		if not ExtMemInstalled then RunError(204);
		WriteLn(ExtMemDebug, '-- ExtMemWrite ', count, ' --');
		ExtMemDebugBlock(block);
		{$ENDIF}
		case block.MemType of
			Xms: XmsWrite(block, data, count);
			Ems: EmsWrite(block, data, count);
			Conv: ConvWrite(block, data, count);
		else
			if count <> 0 then RunError(204)
		end;
	end;

procedure ExtMemRead(var block: TExtMemBlock; var data; count: word);
	begin
		{$IFDEF EXT_MEM_DEBUG}
		if not ExtMemInstalled then RunError(204);
		WriteLn(ExtMemDebug, '-- ExtMemRead ', count, ' --');
		ExtMemDebugBlock(block);
		{$ENDIF}
		case block.MemType of
			Xms: XmsRead(block, data, count);
			Ems: EmsRead(block, data, count);
			Conv: ConvRead(block, data, count);
		else
			if count <> 0 then RunError(204)
		end;
	end;

procedure ExtMemFree(var block: TExtMemBlock; size: word);
	begin
		{$IFDEF EXT_MEM_DEBUG}
		if not ExtMemInstalled then RunError(204);
		WriteLn(ExtMemDebug, '-- ExtMemFree ', size, ' --');
		ExtMemDebugBlock(block);
		{$ENDIF}
		case block.MemType of
			Xms: XmsFree(block, size);
			Ems: EmsFree(block, size);
			Conv: ConvFree(block, size);
		else
			if size <> 0 then RunError(204)
		end;
		block.MemType := NoMem;
		{$IFDEF EXT_MEM_DEBUG}
		ExtMemDebugBlock(block);
		{$ENDIF}
	end;

procedure ExtMemUninstall;
	begin
		{$IFDEF EXT_MEM_DEBUG}
		WriteLn(ExtMemDebug, '---------- ExtMemUninstall ----------');
		ExtMemDebugState;
		Close(ExtMemDebug);
		ExtMemInstalled := false;
		{$ENDIF}
		XmsUninstall;
		EmsUninstall;
	end;

end.
