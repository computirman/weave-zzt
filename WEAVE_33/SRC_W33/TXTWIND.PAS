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

{$IFDEF FPC}
{$PACKRECORDS 1}
{$ENDIF}

{$I-}
{$V-}
unit TxtWind;

interface
	uses Gamevars,ZVideo;
	const
{$IFDEF SDL2}
		MAX_TEXT_WINDOW_LINES = 6144;
{$ELSE}
		MAX_TEXT_WINDOW_LINES = 1024;
{$ENDIF}
		TextWindowX = 5;
		TextWindowY = 3;
		TextWindowWidth = 50;
		TextWindowHeight = 18;
		MAX_LINE_LENGTH = 50;
		TWS_HYPERLINK_AS_SELECT = $01;
		TWS_VIEWING_FILE = $02;
		TWS_IGNORE_HYPERLINKS = $04;
	type
{$IFDEF SDL2}
		TExtensionString = string[12];
{$ELSE}
		TExtensionString = string[4];
{$ENDIF}
		TTextWindowLine = string[MAX_LINE_LENGTH];
		PTTextWindowLine = ^TTextWindowLine;
		TTextWindowState = record
			Selectable: boolean;
			LineCount: integer;
			LinePos: integer;
			Lines: array[1 .. MAX_TEXT_WINDOW_LINES] of PTTextWindowLine;
			Hyperlink: string[20];
			Title: TTextWindowLine;
			ScreenCopy: array[1 .. 25] of TScreenCopyLine;
		end;
	var
		TextWindowStrInnerEmpty: TVideoLine;
		TextWindowStrText: TVideoLine;
		TextWindowStrInnerLine: TVideoLine;
		TextWindowStrTop: TVideoLine;
		TextWindowStrBottom: TVideoLine;
		TextWindowStrSep: TVideoLine;
		TextWindowStrInnerSep: TVideoLine;
		TextWindowStrInnerArrows: TVideoLine;
		TextWindowRejected: boolean;
	procedure TextWindowInitState(var state: TTextWindowState);
	procedure TextWindowDrawOpen(var state: TTextWindowState);
	procedure TextWindowDrawClose(var state: TTextWindowState);
	procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	procedure TextWindowFree(var state: TTextWindowState);
	procedure TextWindowSelect(var state: TTextWindowState; flags: byte);
	procedure TextWindowSort(var state: TTextWindowState; fromIdx, toIdx: integer);
	procedure TextWindowOpenFile(filename: TFilenameString; var state: TTextWindowState; editing, showError: boolean);
	procedure TextWindowDisplayFile(filename: TFilenameString; title: TTextWindowLine);
	procedure TextWindowInit;
	procedure GameAboutScreen;

implementation
uses Crt, Sounds, TimerSys, ZInput, Keys, FileSel, FileSys, Game;

procedure GameAboutScreen;
	var
		textWindow: TTextWindowState;
		i: integer;
	begin
		TextWindowInitState(textWindow);
		textWindow.Selectable := false;
		textWindow.Title := 'License Info';
		TextWindowAppend(textWindow,'The Reconstruction of ZZT');
		TextWindowAppend(textWindow,'');
		TextWindowAppend(textWindow,'Copyright (c) 2020 Adrian Siekierka');
		TextWindowAppend(textWindow,'Based on a reconstruction of code');
		TextWindowAppend(textWindow,'from ZZT, Copyright 1991 Epic MegaGames,');
		TextWindowAppend(textWindow,'used with permission.');
		TextWindowAppend(textWindow,'');
		TextWindowAppend(textWindow,'Permission is hereby granted, free of');
		TextWindowAppend(textWindow,'charge, to any person obtaining a copy');
		TextWindowAppend(textWindow,'of this software and associated');
		TextWindowAppend(textWindow,'documentation files (the "Software"), to');
		TextWindowAppend(textWindow,'deal in the Software without restriction,');
		TextWindowAppend(textWindow,'including without limitation the rights');
		TextWindowAppend(textWindow,'to use, copy, modify, merge, publish,');
		TextWindowAppend(textWindow,'distribute, sublicense, and/or sell');
		TextWindowAppend(textWindow,'copies of the Software, and to permit');
		TextWindowAppend(textWindow,'persons to whom the Software is');
		TextWindowAppend(textWindow,'furnished to do so, subject to the');
		TextWindowAppend(textWindow,'following conditions:');
		TextWindowAppend(textWindow,'');
		TextWindowAppend(textWindow,'The above copyright notice and this');
		TextWindowAppend(textWindow,'permission notice shall be included in');
		TextWindowAppend(textWindow,'all copies or substantial portions of');
		TextWindowAppend(textWindow,'the Software.');
		TextWindowAppend(textWindow,'');
		TextWindowAppend(textWindow,'THE SOFTWARE IS PROVIDED "AS IS",');
		TextWindowAppend(textWindow,'WITHOUT WARRANTY OF ANY KIND, EXPRESS');
		TextWindowAppend(textWindow,'OR IMPLIED, INCLUDING BUT NOT LIMITED');
		TextWindowAppend(textWindow,'TO THE WARRANTIES OF MERCHANTABILITY,');
		TextWindowAppend(textWindow,'FITNESS FOR A PARTICULAR PURPOSE AND');
		TextWindowAppend(textWindow,'NONINFRINGEMENT. IN NO EVENT SHALL THE');
		TextWindowAppend(textWindow,'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE');
		TextWindowAppend(textWindow,'FOR ANY CLAIM, DAMAGES OR OTHER');
		TextWindowAppend(textWindow,'LIABILITY, WHETHER IN AN ACTION OF');
		TextWindowAppend(textWindow,'CONTRACT, TORT OR OTHERWISE, ARISING');
		TextWindowAppend(textWindow,'FROM, OUT OF OR IN CONNECTION WITH THE');
		TextWindowAppend(textWindow,'SOFTWARE OR THE USE OR OTHER DEALINGS IN');
		TextWindowAppend(textWindow,'THE SOFTWARE.');
		TextWindowDrawOpen(textWindow);
		TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
		TextWindowDrawClose(textWindow);
		TextWindowFree(textWindow);
	end;

procedure TextWindowInitState(var state: TTextWindowState);
	begin
		with state do begin
			LineCount := 0;
			LinePos := 1;
		end;
	end;

procedure TextWindowDrawTitle(color: integer; title: TTextWindowLine);
	begin
		VideoWriteText(TextWindowX + 2, TextWindowY + 1, color, TextWindowStrInnerEmpty);
		VideoWriteText(TextWindowX + ((TextWindowWidth - Length(title)) div 2), TextWindowY + 1, color, title);
	end;

function AsColor(fg, bg: integer): byte;
	begin
		AsColor := ((bg * 16) + fg) + $00;
	end;

procedure TextWindowDrawOpen(var state: TTextWindowState);
	var
		ix, iy: integer;
	begin
		with state do begin
			for iy := 1 to (TextWindowHeight + 1) do
				VideoMove(TextWindowX, iy + TextWindowY - 1, TextWindowWidth, @ScreenCopy[iy], false);

			for iy := (TextWindowHeight div 2) downto 0 do begin
				VideoWriteText(TextWindowX, TextWindowY + iy + 1,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy - 1,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + iy,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrBottom);
				Delay(25);
			end;

			VideoWriteText(TextWindowX, TextWindowY + 2, AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrSep);
			TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
				XDat.Params[THEME_START]), Title);
		end;
	end;

procedure TextWindowDrawClose(var state: TTextWindowState);
	var
		ix, iy: integer;
	begin
		with state do begin
			for iy := 0 to (TextWindowHeight div 2) do begin
				VideoWriteText(TextWindowX, TextWindowY + iy,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrBottom);
				Delay(18);
				VideoMove(TextWindowX, TextWindowY + iy, TextWindowWidth,
					@ScreenCopy[iy + 1], true);
				VideoMove(TextWindowX, TextWindowY + TextWindowHeight - iy, TextWindowWidth,
					@ScreenCopy[(TextWindowHeight - iy) + 1], true);
			end;
		end;
	end;

procedure TextWindowDrawLine(var state: TTextWindowState; lpos: integer; withoutFormatting, viewingFile: boolean);
	var
		lineY: integer;
		textOffset, textColor, textX: integer;
	begin
		with state do begin
			lineY := ((TextWindowY + lpos) - LinePos) + (TextWindowHeight div 2) + 1;
			if lpos = LinePos then
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(XDat.Params[THEME_START + 6],
						XDat.Params[THEME_START]), TextWindowStrInnerArrows)
			else
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]), TextWindowStrInnerEmpty);
			if (lpos > 0) and (lpos <= LineCount) then begin
				if withoutFormatting then begin
					VideoWriteText(TextWindowX + 4, lineY,
						AsColor(XDat.Params[THEME_START + 2],
							XDat.Params[THEME_START]), Lines[lpos]^);
				end else begin
					textOffset := 1;
					textColor := AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]);
					textX := TextWindowX + 4;
					if Length(state.Lines[lpos]^) > 0 then begin
						case state.Lines[lpos]^[1] of
							'!': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								VideoWriteText(textX + 2, lineY,
									AsColor(XDat.Params[THEME_START + 6],
										XDat.Params[THEME_START]), #16);
								textX := textX + 5;
								textColor := AsColor(XDat.Params[THEME_START + 1],
									XDat.Params[THEME_START]);
							end;
							':': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								textColor := AsColor(XDat.Params[THEME_START + 1],
									XDat.Params[THEME_START]);
							end;
							'$': begin
								textOffset := 2;
								textColor := AsColor(XDat.Params[THEME_START + 1],
									XDat.Params[THEME_START]);
								textX := (textX - 4) + ((TextWindowWidth - Length(Lines[lpos]^)) div 2);
							end;
							'@': begin
								textColor := AsColor(XDat.Params[THEME_START + 4],
									XDat.Params[THEME_START]);
							end;
							#255: begin
								textOffset := 3;
								VideoWriteText(textX - 1, lineY,
									AsColor(XDat.Params[THEME_START + 3],
										XDat.Params[THEME_START]), state.Lines[lpos]^[2]);
								textColor := AsColor(XDat.Params[THEME_START + 6], 
									XDat.Params[THEME_START]);
							end;
						end;
					end;
					if textOffset > 0 then begin
						VideoWriteText(textX, lineY, textColor,
							Copy(Lines[lpos]^, textOffset,Length(Lines[lpos]^) - textOffset + 1));
					end;
				end;
			end else if (lpos = 0) or (lpos = (state.LineCount + 1)) then begin
				VideoWriteText(TextWindowX + 2, lineY, AsColor(XDat.Params[THEME_START + 2],
					XDat.Params[THEME_START]), TextWindowStrInnerSep);
			end else if (lpos = -4) and viewingFile then begin
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(XDat.Params[THEME_START + 6],
						XDat.Params[THEME_START]), '   Use            to view text,');
				VideoWriteText(TextWindowX + 2 + 7, lineY,
					AsColor(XDat.Params[THEME_START + 1],
						XDat.Params[THEME_START]), #24' '#25', Enter');
			end;
		end;
	end;

procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	var
		i: integer;
	begin
		for i := 0 to (TextWindowHeight - 4) do
			TextWindowDrawLine(state, state.LinePos - (TextWindowHeight div 2) + i + 2,
				withoutFormatting, viewingFile);
		TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
			XDat.Params[THEME_START]), state.Title);
	end;

procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	begin
		with state do begin
			LineCount := LineCount + 1;
			New(Lines[LineCount]);
			Lines[LineCount]^ := line;
		end;
	end; 

procedure TextWindowFree(var state: TTextWindowState);
	begin
		with state do begin
			while LineCount > 0 do begin
				Dispose(Lines[LineCount]);
				LineCount := LineCount - 1;
			end;
		end;
	end;

procedure TextWindowSelect(var state: TTextWindowState; flags: byte);
	var
		newLinePos: integer;
		viewingFile: boolean;
		iLine, iChar: integer;
		pointerStr: string[20];
	label LabelMatched;
	label LabelNotMatched;
	begin
		viewingFile := (flags and TWS_VIEWING_FILE) <> 0;

		with state do begin
			TextWindowRejected := false;
			Hyperlink := '';
			TextWindowDraw(state, false, viewingFile);
			repeat
{$IFDEF SDL2}
				TimerSysIdle(IMUntilFrame);
{$ENDIF}
				InputUpdate;
				newLinePos := LinePos;
				if InputDeltaY <> 0 then begin
					Inc(newLinePos, InputDeltaY);
				end else if InputShiftPressed or (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = ' ') then begin
					InputShiftAccepted := true;
					if ((flags and TWS_IGNORE_HYPERLINKS) = 0) and ((Lines[LinePos]^[1]) = '!') then begin
						pointerStr := Copy(Lines[LinePos]^, 2, Length(Lines[LinePos]^) - 1);

						if Pos(';', pointerStr) > 0 then begin
							pointerStr := Copy(pointerStr, 1, Pos(';', pointerStr) - 1);
						end;

						if pointerStr[1] = '-' then begin
							Delete(pointerStr, 1, 1);
							TextWindowFree(state);
							TextWindowOpenFile(pointerStr, state, false, false);
							if state.LineCount = 0 then
								exit
							else begin
								viewingFile := true;
								newLinePos := LinePos;
								TextWindowDraw(state, false, viewingFile);
								InputKeyPressed := #0;
								InputShiftPressed := false;
							end;
						end else begin
							if (flags and TWS_HYPERLINK_AS_SELECT) <> 0 then begin
								Hyperlink := pointerStr;
							end else begin
								pointerStr := ':' + pointerStr;
								for iLine := 1 to LineCount do begin
									if Length(pointerStr) > Length(Lines[iLine]^) then begin
									end else begin
										for iChar := 1 to Length(pointerStr) do begin
											if UpCase(pointerStr[iChar]) <> UpCase(Lines[iLine]^[iChar]) then
												goto LabelNotMatched;
										end;
										newLinePos := iLine;
										InputKeyPressed := #0;
										InputShiftPressed := false;
										goto LabelMatched;
									LabelNotMatched:
									end;
								end;
							end;
						end;
					end;
				end else begin
					if InputKeyPressed = KEY_PAGE_UP then begin
						newLinePos := LinePos - TextWindowHeight + 4;
					end else if InputKeyPressed = KEY_PAGE_DOWN then begin
						newLinePos := LinePos + TextWindowHeight - 4;
					end;
				end;

			LabelMatched:
				if newLinePos < 1 then
					newLinePos := 1
				else if newLinePos > state.LineCount then
					newLinePos := LineCount;

				if newLinePos <> LinePos then begin
					LinePos := newLinePos;
					TextWindowDraw(state, false, viewingFile);
					if (Lines[LinePos]^[1]) = '!' then
						if (flags and TWS_HYPERLINK_AS_SELECT) <> 0 then
							TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
								XDat.Params[THEME_START]),
								#174'Press ENTER or SPACE to select'#175)
						else
							TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
								XDat.Params[THEME_START]),
								#174'Press ENTER for more info'#175);
				end;
				if InputJoystickMoved then begin
					Delay(35);
				end;
			until (InputKeyPressed = KEY_ESCAPE) or (InputKeyPressed = KEY_ENTER) or InputShiftPressed or (InputKeyPressed = ' ');
			if InputKeyPressed = KEY_ESCAPE then begin
				InputKeyPressed := #0;
				TextWindowRejected := true;
			end;
		end;
	end;

procedure TextWindowSort(var state: TTextWindowState; fromIdx, toIdx: integer);
	var
		i, j: integer;
		smallestIdx: integer;

	procedure Swap(var a, b: PTTextWindowLine);
		var
			c: PTTextWindowLine;
		begin
			c := a;
			a := b;
			b := c;
		end;

	{ Returns the location of the pivot after separating. }
	function Partition(var state: TTextWindowState; low: integer;
		high: integer): integer;
	var
		pivot: PTTextWindowLine;
		i, j: integer;
	begin
		{ Choose a random pivot. A cannae be bothered to do anything
		  faster/more sophisticated. }
		pivot := state.Lines[Random(high-low) + low];
		i := low;
		j := high;

	    repeat
			while state.Lines[i]^ < pivot^ do Inc(i);
			while state.Lines[j]^ > pivot^ do Dec(j);

			if i <= j then begin
				Swap(state.Lines[i], state.Lines[j]);

				Inc(i);
				Dec(j);
	    	end;
		until i > j;

		Partition := i;
	end;

	procedure Quicksort(var state: TTextWindowState; low: integer;
		high: integer);
	var
		pivotPt: integer;
	begin
		if low < high then begin
			pivotPt := partition(state, low, high);
			Quicksort(state, low, pivotPt-1);
			Quicksort(state, pivotPt, high);
		end;
	end;

	begin
		if fromIdx < 1 then fromIdx := 1;
		if toIdx > state.LineCount then toIdx := state.LineCount;
		Quicksort(state, fromIdx, toIdx);
	end;

procedure TextWindowOpenFile(filename: TFilenameString; var state: TTextWindowState; editing, showError: boolean);
	var
		tf: text;
		i: integer;
		retVal: boolean;
	begin
		with state do begin
			retVal := true;
			for i := 1 to Length(filename) do
				retVal := retVal and (filename[i] <> '.');
			if retVal then
				filename := filename + '.HLP';

			if filename[1] = '*' then
				filename := Copy(filename, 2, Length(filename) - 1);

			TextWindowInitState(state);

			AssignFSysText(tf, filename);
			Reset(tf);
			while (IOResult = 0) and (not Eof(tf)) do begin
				Inc(LineCount);
				New(Lines[LineCount]);
				ReadLn(tf, Lines[LineCount]^);
			end;
			Close(tf);
		end;
	end;

procedure TextWindowDisplayFile(filename: TFilenameString; title: TTextWindowLine);
	var
		state: TTextWindowState;
	begin
		state.Title := title;
		TextWindowOpenFile(filename, state, false, false);
		state.Selectable := false;
		if state.LineCount > 0 then begin
			TextWindowDrawOpen(state);
			TextWindowSelect(state, TWS_VIEWING_FILE);
			TextWindowDrawClose(state);
		end;
		TextWindowFree(state);
	end;

procedure TextWindowInit;
	var
		i: integer;
	begin
		TextWindowStrInnerEmpty[0] := Chr(TextWindowWidth - 5);
		TextWindowStrInnerLine[0] := Chr(TextWindowWidth - 5);
		for i := 1 to (TextWindowWidth - 5) do begin
			TextWindowStrInnerEmpty[i] := ' ';
			TextWindowStrInnerLine[i] := #205;
		end;
		TextWindowStrTop    := #198#209 + TextWindowStrInnerLine  + #209#181;
		TextWindowStrBottom := #198#207 + TextWindowStrInnerLine  + #207#181;
		TextWindowStrSep    :=  ' '#198 + TextWindowStrInnerLine  + #181' ';
		TextWindowStrText   :=  ' '#179 + TextWindowStrInnerEmpty + #179' ';
		TextWindowStrInnerArrows := TextWindowStrInnerEmpty;
		TextWindowStrInnerArrows[1] := #175;
		TextWindowStrInnerArrows[Length(TextWindowStrInnerArrows)] := #174;
		TextWindowStrInnerSep := TextWindowStrInnerEmpty;
		for i := 1 to (TextWindowWidth div 5) do
			TextWindowStrInnerSep[i * 5 + ((TextWindowWidth mod 5) shr 1)] := #7;
	end;

begin
end.
