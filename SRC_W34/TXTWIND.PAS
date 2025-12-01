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
	procedure TextWindowInitState(var state: TTextWindowState; startline: integer);
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
		TextWindowInitState(textWindow,0);
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

procedure TextWindowInitState(var state: TTextWindowState; startline: integer);
	begin
		with state do begin
			LineCount := 0;
			LinePos := startline;
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

function PathColor(x, y: integer): byte;
	var
		path: pointer;
	begin
		path := PathTmpBuf;
		AdvancePointer(path, (y * 60) + x);
		PathColor := Byte(path^);
	end;


procedure TextWindowDrawOpen(var state: TTextWindowState);
	var
		ix, iy, ic: integer;
	begin
		with state do begin
			for iy := 1 to (TextWindowHeight + 1) do
				VideoMove(TextWindowX, iy + TextWindowY - 1, TextWindowWidth, @ScreenCopy[iy], false);

{
			for iy := (TextWindowHeight div 2) downto 0 do begin
				VideoWriteText(TextWindowX, TextWindowY + iy + 1,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy - 1,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + iy,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy,
					AsColor(XDat.Params[THEME_START + 1],0), TextWindowStrBottom);
				Delay(9);
			end;
}
			for ix := 0 to TextWindowWidth - 2 do begin
				for iy := 1 to TextWindowHeight - 1 do begin
					ic := PathColor(TextWindowX + ix, TextWindowY + iy);
					if TextWindowStrText[ix + 1] <> ' ' then
						VideoWriteText(TextWindowX + ix, TextWindowY + iy,
							ic, TextWindowStrText[ix + 1])
					else
						VideoWriteText(TextWindowX + ix, TextWindowY + iy,
							ic, #176);
				end;
				ic := PathColor(TextWindowX + ix, TextWindowY);
				VideoWriteText(TextWindowX + ix, TextWindowY,
					ic, TextWindowStrTop[ix + 1]);
				ic := PathColor(TextWindowX + ix, TextWindowY + TextWindowHeight);
				VideoWriteText(TextWindowX + ix, TextWindowY + TextWindowHeight,
					ic, TextWindowStrBottom[ix + 1]);
				ic := PathColor(TextWindowX + ix, TextWindowY + 2);
				VideoWriteText(TextWindowX + ix, TextWindowY + 2,
					ic, TextWindowStrSep[ix + 1]);
			end;

			TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
				0), Title);
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
				Delay(8);
				VideoMove(TextWindowX, TextWindowY + iy, TextWindowWidth,
					@ScreenCopy[iy + 1], true);
				VideoMove(TextWindowX, TextWindowY + TextWindowHeight - iy, TextWindowWidth,
					@ScreenCopy[(TextWindowHeight - iy) + 1], true);
			end;
		end;
	end;

function TextWindowDrawLine(var state: TTextWindowState; lpos: integer;
		withoutFormatting, viewingFile, putNew: boolean): boolean;
	var
		lineY, ix, ic: integer;
		textOffset, textColor, textX: integer;
	begin
		TextWindowDrawLine := true;
		with state do begin
			lineY := ((TextWindowY + lpos) - LinePos) + (TextWindowHeight div 2) + 1;
			if (lpos >= 0) and (lpos <= LineCount + 1) then begin
				if lpos = LinePos then
					VideoWriteText(TextWindowX + 2, lineY,
						AsColor(XDat.Params[THEME_START + 6],
							0), TextWindowStrInnerArrows)
				else
					VideoWriteText(TextWindowX + 2, lineY,
						AsColor(XDat.Params[THEME_START + 2],
						0), TextWindowStrInnerEmpty);
			end else begin
				 for ix := 2 to TextWindowWidth - 4 do begin
					ic := PathColor(TextWindowX + ix, LineY);
					VideoWriteText(TextWindowX + ix, lineY,
						ic, #176);
				end;
			end;
			if (lpos > 0) and (lpos <= LineCount) then begin
				if withoutFormatting then begin
					VideoWriteText(TextWindowX + 4, lineY,
						AsColor(XDat.Params[THEME_START + 2],
							0), Lines[lpos]^);
				end else begin
					textOffset := 1;
					textColor := AsColor(XDat.Params[THEME_START + 2],
						0);
					textX := TextWindowX + 4;
					if Length(state.Lines[lpos]^) > 0 then begin
						case state.Lines[lpos]^[1] of
							'!': begin
								if putNew and (LinePos > lpos) then begin
									LinePos := lpos;
									TextWindowDrawLine := false;
								end;
								textOffset := Pos(';', Lines[lpos]^) + 1;
								VideoWriteText(textX + 2, lineY,
									AsColor(XDat.Params[THEME_START + 6],
										0), #16);
								textX := textX + 5;
								textColor := AsColor(XDat.Params[THEME_START + 1],
									0);
							end;
							':': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								textColor := AsColor(XDat.Params[THEME_START + 1],
									0);
							end;
							'$': begin
								textOffset := 2;
								textColor := AsColor(XDat.Params[THEME_START + 1],
									0);
								textX := (textX - 4) + ((TextWindowWidth - Length(Lines[lpos]^)) div 2);
							end;
							'@': begin
								textColor := AsColor(XDat.Params[THEME_START + 4],
									0);
							end;
							#255: begin
								textOffset := 3;
								VideoWriteText(textX - 1, lineY,
									AsColor(XDat.Params[THEME_START + 3],
										0), state.Lines[lpos]^[2]);
								textColor := AsColor(XDat.Params[THEME_START + 6], 
									0);
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
					0), TextWindowStrInnerSep);
			end else if (lpos = -4) and viewingFile then begin
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(XDat.Params[THEME_START + 6],
						0), '   Use            to view text,');
				VideoWriteText(TextWindowX + 2 + 7, lineY,
					AsColor(XDat.Params[THEME_START + 1],
						0), #24' '#25', Enter');
			end;
		end;
	end;

procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	var
		i,k: integer;
		first: boolean;
	begin
		i := 0;
		k := TextWindowHeight - 4;
		first := false;
		if state.LinePos < 1 then begin
			first := true;
			state.LinePos := (state.LineCount + 1) div 2;
			if state.LinePos > (TextWindowHeight div 2) - 1 then
				state.LinePos := (TextWindowHeight div 2) - 1;
		end;
		while i <= k do
			if TextWindowDrawLine(state, state.LinePos - (TextWindowHeight div 2) + i + 2,
				withoutFormatting, viewingFile, first)
			then
				Inc(i)
			else begin
				first := false;
				i := 0;
			end;

		TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
			0), state.Title);
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
		viewingFile, strictShift: boolean;
		iLine, iChar: integer;
		pointerStr, qStr: string[20];
		c: char;
	label LabelMatched;
	label LabelNotMatched;
	begin
		viewingFile := (flags and TWS_VIEWING_FILE) <> 0;
		if XDat.Params[9] > 0 then begin
			c := #2;
			qStr := ''
		end else begin
			c := ' ';
			qStr := 'or SPACE '
		end;
		with state do begin
			TextWindowRejected := false;
			Hyperlink := '';
			TextWindowDraw(state, false, viewingFile);
			repeat
{$IFDEF SDL2}
				TimerSysIdle(IMUntilFrame);
{$ENDIF}
				InputUpdate;
				if c = ' ' then
					strictShift := InputShiftPressed
				else
					strictShift := false;
				newLinePos := LinePos;
				if InputDeltaY <> 0 then begin
					Inc(newLinePos, InputDeltaY);
				end else if strictShift or (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = c) then begin
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
								strictShift := false;
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
										strictShift := false;
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
								0),
								#174'Press ENTER ' + qStr + 'to select'#175)
						else
							TextWindowDrawTitle(AsColor(XDat.Params[THEME_START + 2],
								0),
								#174'Press ENTER for more info'#175);
				end;
				if InputJoystickMoved then begin
					Delay(35);
				end;
						until (InputKeyPressed = KEY_ESCAPE) or (InputKeyPressed = KEY_ENTER) or strictShift or (InputKeyPressed = c);
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

			TextWindowInitState(state,0);

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
			TextWindowStrInnerLine[i] := #177
		end;
		TextWindowStrTop    := #178#177 + TextWindowStrInnerLine  + #177#178;
		TextWindowStrBottom := #178#177 + TextWindowStrInnerLine  + #177#178;
		TextWindowStrSep    := #178#177 + TextWindowStrInnerLine  + #177#178;
		TextWindowStrText   := #178#177 + TextWindowStrInnerEmpty + #177#178;
		TextWindowStrInnerArrows := TextWindowStrInnerEmpty;
		TextWindowStrInnerArrows[1] := #175;
		TextWindowStrInnerArrows[Length(TextWindowStrInnerArrows)] := #174;
		TextWindowStrInnerSep := TextWindowStrInnerEmpty;
		for i := 1 to (TextWindowWidth div 5) do
			TextWindowStrInnerSep[i * 5 + ((TextWindowWidth mod 5) shr 1)] := #250;
	end;

begin
end.
