{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from ZZT,
	Copyright 1991 Epic MegaGames, used with permission.

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
unit Video;

interface
	type
		TVideoLine = string[80];
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
	const
		PORT_CGA_MODE = $03D8;
		PORT_CGA_PALETTE = $03D9;
	var
		VideoWriteText: TVideoWriteTextProc;
		VideoMonochrome: boolean;
		VideoColumns: integer;
		VideoBorderColor: integer;
		VideoTextSegment: word;
		VideoTextPointer: pointer;
		VideoCursorVisible: boolean;
		VideoEGAInstalled: boolean;
		VideoMDAInstalled: boolean;
		VideoUseFastPath: boolean;
	function VideoConfigure(SkipToTitle: boolean): boolean;
	procedure VideoInstall(columns, borderColor: integer);
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	procedure SetBlink(blinkState: boolean);
	procedure SetAccKeys;

implementation
uses Crt, Dos, AccKeys;

{$F+}

procedure SetAccKeys;
	var
		regs: Registers;
	begin
		if not VideoEGAInstalled then exit;
		regs.ax := $1110;
		regs.bh := $0E;                           (* bytes per character *)
		regs.bl := 0;                             (* load to block 0 *)
		regs.cx := 14;                            (* 14 characters *)
		regs.dx := 133;                           (* start with character 0 *)
		regs.es := Seg(acc);  				      (* segment of table *)
		regs.bp := Ofs(acc);     				  (* offset of the table *)
		intr($10, regs);
	end;

procedure SetBlink(blinkState: boolean);
	var
		regs: Registers;
	begin
		{ CGA cards }
		if blinkState then
			Port[PORT_CGA_MODE] := Port[PORT_CGA_MODE] or $20
		else
			Port[PORT_CGA_MODE] := Port[PORT_CGA_MODE] and $DF;

		{ EGA/VGA cards }
		regs.ax := $1003;
		if blinkState then
			regs.bx := $0001
		else
			regs.bx := $0000;
		Intr($10, regs);
	end;

procedure VideoWriteTextCGA(x, y, color: byte; text: TVideoLine);
	begin
		inline(
			$8B/$06/VideoTextSegment/{ MOV AX, VideoTextSegment }
			$8E/$C0/             { MOV ES, AX }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$F6/$26/VideoColumns/{ MUL VideoColumns }
			$31/$C9/             { XOR CX, CX }
			$89/$CE/             { MOV SI, CX }
			$8A/$8E/x/           { MOV CL, byte ptr [BP + x] }
			$01/$C8/             { ADD AX, CX }
			$D1/$E0/             { SHL AX, 1 }
			$8B/$F8/             { MOV DI, AX }
			$8A/$BE/color/       { MOV BH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$BA/$03DA/           { MOV DX, 0x03DA }
			$22/$C9/             { AND CL, CL }
			$74/$1A/             { JZ finish }
			$FA/                 { CLI }
		{ next_char: }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
		{ cga_snow: }
			$EC/                 { IN AL, DX }
			$A8/$08/             { TEST AL, 8 }
			$75/$09/             { JNZ write_char }
			$D0/$E8/             { SHR AL, 1 }
			$72/$F7/             { JC cga_snow }
		{ cga_snow2: }
			$EC/                 { IN AL, DX }
			$D0/$E8/             { SHR AL, 1 }
			$73/$FB/             { JNC cga_snow2 }
		{ write_char: }
			$89/$D8/             { MOV AX, BX }
			$AB/                 { STOSW }
			$E2/$E8/             { LOOP next_char }
			$FB                  { STI }
		{ finish: }
		);
	end;

procedure VideoWriteTextFast(x, y, color: byte; text: TVideoLine);
	begin
		inline(
			$8B/$06/VideoTextSegment/{ MOV AX, VideoTextSegment }
			$8E/$C0/             { MOV ES, AX }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$F6/$26/VideoColumns/{ MUL VideoColumns }
			$31/$C9/             { XOR CX, CX }
			$89/$CE/             { MOV SI, CX }
			$8A/$8E/x/           { MOV CL, byte ptr [BP + x] }
			$01/$C8/             { ADD AX, CX }
			$D1/$E0/             { SHL AX, 1 }
			$8B/$F8/             { MOV DI, AX }
			$8A/$A6/color/       { MOV AH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$22/$C9/             { AND CL, CL }
			$74/$0A/             { JZ finish }
			$FA/                 { CLI }
		{ next_char: }
			$46/                 { INC SI }
			$8A/$82/text/        { MOV AL, byte ptr [BP + SI + text] }
			$AB/                 { STOSW }
			$E2/$F8/             { LOOP next_char }
			$FB                  { STI }
		{ finish: }
		);
	end;


function ColorToBW(color: byte): byte;
	begin
		if (color and $08) = $08 then begin
			if (color and $F0) = 0 then
				color := $0F
			else
				color := $7F;
		end else begin
			if (color and $07) <> 0 then
				color := $07
			else
				color := $70;
		end;
		ColorToBW := color;
	end;

procedure VideoWriteTextCGABW(x, y, color: byte; text: TVideoLine);
	begin
		VideoWriteTextCGA(x, y, ColorToBW(color), text);
	end;

procedure VideoWriteTextFastBW(x, y, color: byte; text: TVideoLine);
	begin
		VideoWriteTextFast(x, y, ColorToBW(color), text);
	end;

{$F-}

function VideoConfigure(SkipToTitle: boolean): boolean;
	var
		charTyped: Char;
	begin
		if SkipToTitle then begin
			if LastMode = 7 then begin
				VideoWriteText := VideoWriteTextFastBW;
				VideoMonochrome := true;
			end else
				VideoMonochrome := false;
			VideoConfigure := true;
			exit;
		end;	
		charTyped := ' ';
		if LastMode = 7 then begin
			VideoWriteText := VideoWriteTextFastBW;
			VideoMonochrome := true;
		end else begin
			Writeln;
			Write('  Video mode:  C)olor,  M)onochrome?  ');
			repeat
				repeat until KeyPressed;
				charTyped := UpCase(ReadKey);
			until charTyped in [#27, 'C', 'M'];
			case charTyped of
				'C': VideoMonochrome := false;
				'M': VideoMonochrome := true;
				#27: VideoMonochrome := (LastMode = 7);
			end;
		end;
		VideoConfigure := charTyped <> #27;
	end;

procedure VideoInstall(columns, borderColor: integer);
	var
		regs: Registers;
	begin
		regs.AH := $12;
		regs.BX := $FF10;
		Intr($10, regs);
		VideoEGAInstalled := regs.BH <> $FF;
		VideoMDAInstalled := LastMode = 7;
		VideoUseFastPath := VideoUseFastPath or VideoEGAInstalled or VideoMDAInstalled;

		if VideoEGAInstalled then begin
			regs.AX := $1201;
			regs.BL := $30;
			Intr($10, regs);
		end;

		if not VideoMonochrome then
			TextBackground(borderColor);

		VideoColumns := columns;
		if VideoMonochrome then begin
			if VideoUseFastPath then
				VideoWriteText := VideoWriteTextFastBW
			else
				VideoWriteText := VideoWriteTextCGABW;

			if (LastMode >= 0) and (LastMode <= 3) then begin
				if columns = 80 then begin
					TextMode(BW80);
				end else begin
					TextMode(BW40);
				end;
			end else begin
				TextMode(7);
				VideoColumns := 80;
			end;
		end else begin
			if VideoUseFastPath then
				VideoWriteText := VideoWriteTextFast
			else
				VideoWriteText := VideoWriteTextCGA;

			if VideoColumns = 80 then begin
				TextMode(CO80);
			end else begin
				TextMode(CO40);
			end;

			TextBackground(borderColor);
		end;

		ClrScr;

		if not VideoCursorVisible then
			VideoHideCursor;
		VideoSetBorderColor(borderColor);
	end;

procedure VideoUninstall;
	var
		regs: Registers;
	begin
		if VideoEGAInstalled then begin
			regs.AX := $1201;
			regs.BL := $30;
			Intr($10, regs);
		end;

		TextBackground(0);
		VideoColumns := 80;
		if VideoMonochrome then
			TextMode(BW80)
		else
			TextMode(CO80);
		VideoSetBorderColor(0);
		ClrScr;
	end;

procedure VideoSetCursorShape(value: integer);
	var
		regs: Registers;
	begin
		regs.AH := $01;
		regs.CX := value;
		Intr($10, regs);
	end;

procedure VideoShowCursor;
	begin
		VideoSetCursorShape($0607);
		VideoCursorVisible := true;
	end;

procedure VideoHideCursor;
	begin
		VideoSetCursorShape($2000);
		VideoCursorVisible := false;
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		Port[PORT_CGA_PALETTE] := value;
		VideoBorderColor := value;
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
		if not VideoUseFastPath then
			VideoWriteTextCGA(0, 0, 0, '');
		if toVideo then
			Move(data^, Ptr(VideoTextSegment, offset)^, chars * 2)
		else
			Move(Ptr(VideoTextSegment, offset)^, data^, chars * 2);
	end;


begin
	VideoBorderColor := 0;
	VideoColumns := 80;
	VideoWriteText := VideoWriteTextFastBW;
	if LastMode = 7 then begin
		VideoTextSegment := $B000;
		VideoMonochrome := true;
	end else begin
		VideoTextSegment := $B800;
		VideoMonochrome := false;
	end;
	VideoTextPointer := Ptr(VideoTextSegment, $0000);
	VideoCursorVisible := true;
	VideoUseFastPath := false;
end.
