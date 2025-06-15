{
	ExtMem - stub

	Copyright (c) 2020 Alan Williams
	Copyright (c) 2021 Adrian "asie" Siekierka

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
		TExtMemType = (NoMem, Conv);
		TExtMemBlockPtr = ^TExtMemBlock;
		TExtMemBlock = record
			case MemType: TExtMemType of
				Conv: (Ptr: pointer);
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
var
	ConvError: boolean;

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
		ExtMemEmsActive := false;
	end;

function ExtMemXmsActive: boolean;
	begin
		ExtMemXmsActive := false;
	end;

procedure ExtMemMoveBlockPtr(var blockFrom, blockTo: TExtMemBlock);
	begin
		blockTo := blockFrom;
	end;
	
function ExtMemXmsAvail: longint;
	begin
		ExtMemXmsAvail := 0;
	end;

function ExtMemEmsAvailPages: word;
	begin
		ExtMemEmsAvailPages := 0;
	end;

procedure ExtMemInstall(useEms: boolean; useXms: boolean);
	begin
{$IFNDEF FPC}
		HeapError := @ConvDefErrorHandler;
{$ELSE}
		ReturnNilIfGrowHeapfails := false;
{$ENDIF}
	end;

function ExtMemGet(var block: TExtMemBlock; size: word): boolean;
	label Done;
	begin
		block.MemType := NoMem;
		if size = 0 then goto Done;
{$IFNDEF FPC}
		HeapError := @ConvErrorHandler;
		ConvError := false;

		block.MemType := Conv;
		GetMem(block.Ptr, size);

		HeapError := @ConvDefErrorHandler;
		if not ConvError then goto Done;
{$ELSE}
		ReturnNilIfGrowHeapfails := true;

		block.MemType := Conv;
		GetMem(block.Ptr, size);

		ReturnNilIfGrowHeapfails := false;
		if block.Ptr <> nil then goto Done;
{$ENDIF}
		ExtMemGet := false;
		exit;
	Done:
		ExtMemGet := true;
	end;

procedure ExtMemWrite(var block: TExtMemBlock; var data; count: word);
	begin
		case block.MemType of
			Conv: Move(data, block.Ptr^, count);
		else
			if count <> 0 then RunError(204)
		end;
	end;

procedure ExtMemRead(var block: TExtMemBlock; var data; count: word);
	begin
		case block.MemType of
			Conv: Move(block.Ptr^, data, count);
		else
			if count <> 0 then RunError(204)
		end;
	end;

procedure ExtMemFree(var block: TExtMemBlock; size: word);
	begin
		case block.MemType of
			Conv: FreeMem(block.Ptr, size);
		else
			if size <> 0 then RunError(204)
		end;
		block.MemType := NoMem;
	end;

procedure ExtMemUninstall;
	begin
	end;

begin
end.
