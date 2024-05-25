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
{$V-}
unit Game;

interface
	uses GameVars, TxtWind;
	const
		PROMPT_NUMERIC = 0;
		PROMPT_ALPHANUM = 1;
		PROMPT_ANY = 2;
	function ColorNumber(s: string; statId: integer): integer;
	procedure SidebarClearLine(y: integer);
	procedure SidebarClear;
	function EnsureIoTmpBufSize(newSize: word): integer;
{$IFNDEF FPC}
	procedure AdvancePointer(var address: pointer; count: integer);
		inline(
			$58/$5F/$07/ { POP AX, DI, ES }
			$26/$01/$05 { ADD ES:[DI], AX }
		);
{$ELSE}
	procedure AdvancePointer(var address: pointer; count: integer);
{$ENDIF}
	procedure BoardClose;
	procedure BoardOpen(boardId: integer);
	procedure BoardChange(boardId: integer);
	procedure BoardCreate;
	procedure WorldCreate;
	procedure TransitionDrawToFill(chr: char; color: integer);
	procedure BoardDrawTile(x, y: integer);
	procedure BoardDrawRow(row: integer);
	procedure BoardDrawBorder;
	procedure TransitionDrawToBoard;
	procedure SidebarPromptSlider(editable: boolean; x, y: integer; prompt: string; var value: shortint);
	procedure PromptString(x, y, arrowColor, color, width: integer; mode: byte; var buffer: TString50);
	function SidebarPromptYesNo(message: string; defaultReturn: boolean): boolean;
	procedure SidebarPromptString(prompt: string; extension: TString50; var filename: string; promptMode: byte);
	procedure PauseOnError;
	procedure WorldUnload;
	function DisplayIOError(filename: TString50): boolean;
	function WorldLoad(filename, extension: TString50): boolean;
	procedure WorldSave(filename, extension: TString50);
	procedure GameWorldSave(prompt: TString50; var filename: TString50; extension: TString50);
	function GameWorldLoad(extension: TString50): boolean;
	procedure AddStat(tx, ty: integer; txelement, txcolor: byte; tcycle: integer; template: TStat);
	function FileLoadStatData(s: TString50; statId: integer): boolean;
	function FileAppendStatData(s: TString50; statId: integer): boolean;
	procedure RemoveStat(statId: integer);
	function GetStatIdAt(tx, ty: integer): integer;
	procedure MoveStat(statId: integer; newX, newY: integer);
	procedure PopupPromptString(question: string; var buffer: TString50);
	function Signum(val: integer): integer;
	function Difference(a, b: integer): integer;
	procedure DamageStat(attackerStatId: integer);
	procedure BoardDamageTile(x, y: integer);
	procedure BoardAttack(attackerStatId: integer; x, y: integer);
	procedure OopPlaceTile(x, y: integer; var tile: TTile);
	procedure OopForceTile(x, y: integer; tile: TTile);
	function BoardShoot(txelement: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	procedure CalcDirectionToward(x, y: integer; var deltaX, deltaY: integer);
	procedure CalcDirectionFind(x, y: integer; var deltaX, deltaY: integer);
	procedure TransitionDrawBoardChange;
	procedure GameUpdateSidebar;
	procedure GameDrawMainSidebar;
	procedure GameDrawCustomSidebar;
	procedure GameDrawTheme;
	procedure DisplayMessage(time: integer; message: string);
	procedure BoardEnter;
	procedure BoardPassageTeleport(x, y: integer);
	procedure GameDebugPrompt;
	procedure GameTitleLoop;
	procedure ResetCachedLinePos;
	function ParamConfigs(i: integer): string;
	function DefaultParamList(i: integer): integer;
	procedure KeyRepeat;

const
	ColorNames: array[0 .. 7] of TString8 =
		('Black', 'Blue', 'Green', 'Cyan', 'Red', 'Purple', 'Yellow', 'White');

	MainSidebarList: array[1..15] of integer = (
		6,7,8,9,10,11,12,14,15,16,18,19,21,22,23
	);

	NeighborArrowList: array[0..3] of char = (
		#30, #31, #17, #16
	);
	LFSR11_START = 42;
	{}
	DiagonalDeltaX: array[0 .. 7] of integer = (-1, 0, 1, 1, 1, 0, -1, -1);
	DiagonalDeltaY: array[0 .. 7] of integer = (1, 1, 1, 0, -1, -1, -1, 0);
	NeighborDeltaX: array[0 .. 3] of integer = (0, 0, -1, 1);
	NeighborDeltaY: array[0 .. 3] of integer = (-1, 1, 0, 0);
	{}
	TileBorder: TTile = (Element: E_NORMAL; Color: $0E);
	TileBoardEdge: TTile = (Element: E_BOARD_EDGE; Color: $00);
	StatTemplateDefault: TStat = (
		X: 0; Y: 0; StepX: 0; StepY: 0;
		Cycle: 255; P1: 0; P2: 0; P3: 0;
		Follower: -1; Leader: -1
	);
	LineChars: string[16] = #249#208#210#186#181#188#187#185#198#200#201#204#205#202#203#206;

implementation
uses Dos, FileSel, FileSys, Crt, ExtMem, ZVideo, Sounds, TimerSys,
ZInput, Elements, Oop, Counter, ObjTrack;

procedure KeyRepeat;
	begin
		if HasINI then
			RepeatSpeed(1)
		else
			RepeatSpeed(0);
	end;

function ColorNumber(s: string; statId: integer): integer;
	var
		counter: TCounter;
		i, code: integer;
	begin
		ColorNumber := -32767;
		Val(s, i, code);
		if (code = 0) then begin
			if ((i > -1) and (i < 256)) then ColorNumber := i;
			exit;
		end;
		if (s = 'BLACK') then ColorNumber := 0
		else if (s = 'DKBLUE') then ColorNumber := 1
		else if (s = 'DKGREEN') then ColorNumber := 2
		else if (s = 'DKCYAN') then ColorNumber := 3
		else if (s = 'DKRED') then ColorNumber := 4
		else if (s = 'DKPURPLE') then ColorNumber := 5
		else if (s = 'BROWN') then ColorNumber := 6
		else if ((s = 'GRAY') or (s = 'GREY')) then ColorNumber := 7
		else if ((s = 'DKGRAY') or (s = 'DKGREY')) then ColorNumber := 8
		else if (s = 'BLUE') then ColorNumber := 9
		else if (s = 'GREEN') then ColorNumber := 10
		else if (s = 'CYAN') then ColorNumber := 11
		else if (s = 'RED') then ColorNumber := 12
		else if (s = 'PURPLE') then ColorNumber := 13
		else if (s = 'YELLOW') then ColorNumber := 14
		else if (s = 'WHITE') then ColorNumber := 15
		else if statId <> -1 then begin
			if CounterFromWord(counter, statId, s) then begin
				CounterReadValue(counter);
				if counter.Value >= 0 then
					ColorNumber := counter.Value;
			end;
		end;
	end;

function ParamConfigs(i: integer): string;
	var
		s: string;
		j: integer;
	begin
		case i of
			1: ParamConfigs := 'OTHER.ALTCHAR';
			2: ParamConfigs := 'OTHER.OUCHDAMAGE';
			3: ParamConfigs := 'OTHER.TORCHRATIOX';
			4: ParamConfigs := 'OTHER.TORCHRATIOY';
			5: ParamConfigs := 'OTHER.TORCHSIZE';
			6: ParamConfigs := 'OTHER.BOMBRATIOX';
			7: ParamConfigs := 'OTHER.BOMBRATIOY';
			8: ParamConfigs := 'OTHER.BOMBSIZE';
			9: ParamConfigs := 'OTHER.MAXSTATS';
			10: ParamConfigs := 'OTHER.MAXOOP';
			11: ParamConfigs := 'OTHER.GRACEPERIOD';
			12: ParamConfigs := 'OTHER.FRIENDLYFIRE';
			13: ParamConfigs := 'THEME.BG.SIDEBAR';
			14: ParamConfigs := 'THEME.FG.TEXT1';
			15: ParamConfigs := 'THEME.FG.TEXT2';
			16: ParamConfigs := 'THEME.FG.ALT';
			17: ParamConfigs := 'THEME.BG.ALT1';
			18: ParamConfigs := 'THEME.BG.ALT2';
			19: ParamConfigs := 'THEME.FG.SPECIAL';
			20: ParamConfigs := 'THEME.BLINKING';
			21: ParamConfigs := 'OTHER.STARTBOARD';
			22: ParamConfigs := 'OTHER.EXTRAFLAGS';
			71: ParamConfigs := 'OTHER.FOOTSTEPS';
			72: ParamConfigs := 'OTHER.HIGHSCORES';
		else ParamConfigs := '_nil' end;
	end;

procedure VerifyPalette;
	var
		c: integer;
	begin
		for c := 0 to 47 do begin
			if (XDat.Params[PALETTE_START + c] < 0) or (XDat.Params[PALETTE_START + c] > 63) then
				XDat.Params[PALETTE_START + c] := DefaultParamList(PALETTE_START + c);
			if (XDat.CurrentPalette[c] < 0) or (XDat.CurrentPalette[c] > 63) then
				XDat.CurrentPalette[c] := XDat.Params[PALETTE_START + c];
		end;
	end;

procedure PushPalette;
	var
		c: integer;
	begin
		for c := 0 to 47 do
			XDat.CurrentPalette[c] := XDat.Params[PALETTE_START + c];
	end;

procedure SetPalette(sourcePal: boolean);
	var
		c,r,g,b: integer;
	begin
		VerifyPalette;
		for c := 0 to 15 do begin
			r := c * 3;
			g := (c * 3) + 1;
			b := (c * 3) + 2;
			if sourcePal then begin
				r := XDat.Params[PALETTE_START + r];
				g := XDat.Params[PALETTE_START + g];
				b := XDat.Params[PALETTE_START + b];
			end else begin
				r := XDat.CurrentPalette[r];
				g := XDat.CurrentPalette[g];
				b := XDat.CurrentPalette[b];
			end;
			BlockPalette(c,r,g,b);
		end;
	end;

procedure LoadPalette;
	var
		f: file;
		c: integer;
		TempPalette: array[0..47] of byte;
	begin
		if FileExists(World.Info.Name + '.PAL') then begin
			AssignFSys(f, World.Info.Name + '.PAL');
			Reset(f, 1);
			if IOResult = 0 then begin
				BlockRead(f, TempPalette, 48);
				Close(f);
			end;
			for c := 0 to 47 do
				XDat.Params[PALETTE_START + c] := TempPalette[c];
		end;
		PushPalette;
		SetPalette(false);
	end;

function DefaultParamList(i: integer): integer;
	begin
		case i of
			1,3,6,12,13,20,22: DefaultParamList := 1;
			2: DefaultParamList := 10;
			4,7: DefaultParamList := 2;
			5,8: DefaultParamList := 50;
			9: DefaultParamList := 254;
			10: DefaultParamList := 33;
			11,16,23,24,25,26,27,29,31,32,36,37,39,43,71: DefaultParamList := 0;
			14: DefaultParamList := 15;
			15: DefaultParamList := 14;
			17: DefaultParamList := 7;
			18: DefaultParamList := 3;
			19: DefaultParamList := 12;
			21: DefaultParamList := -1;
			72: DefaultParamList := 30;
			28,30,33,34,35,38,40,41,44,45,46: DefaultParamList := 42;
			42,47,48,49,50,51,53,55,56,60,61,63,67: DefaultParamList := 21;
			52,54,57,58,59,62,64,65,66,68,69,70: DefaultParamList := 63;
		else DefaultParamList := -32767 end;
	end;

function OopConfigs (i: integer): string;
	begin
		case i of
			1: OopConfigs := 'INPUT.1.KEYBIND';
			2: OopConfigs := 'INPUT.1.LABEL';
			3: OopConfigs := 'INPUT.1.SIDEBAR.ROW';
			4: OopConfigs := 'INPUT.2.KEYBIND';
			5: OopConfigs := 'INPUT.2.LABEL';
			6: OopConfigs := 'INPUT.2.SIDEBAR.ROW';
			7: OopConfigs := 'INPUT.3.KEYBIND';
			8: OopConfigs := 'INPUT.3.LABEL';
			9: OopConfigs := 'INPUT.3.SIDEBAR.ROW';
			10: OopConfigs := 'INPUT.4.KEYBIND';
			11: OopConfigs := 'INPUT.4.LABEL';
			12: OopConfigs := 'INPUT.4.SIDEBAR.ROW';
			13: OopConfigs := 'INPUT.5.KEYBIND';
			14: OopConfigs := 'INPUT.5.LABEL';
			15: OopConfigs := 'INPUT.5.SIDEBAR.ROW';
			16: OopConfigs := 'INPUT.6.KEYBIND';
			17: OopConfigs := 'INPUT.6.LABEL';
			18: OopConfigs := 'INPUT.6.SIDEBAR.ROW';
			19: OopConfigs := 'INPUT.7.KEYBIND';
			20: OopConfigs := 'INPUT.7.LABEL';
			21: OopConfigs := 'INPUT.7.SIDEBAR.ROW';
			22: OopConfigs := 'INPUT.8.KEYBIND';
			23: OopConfigs := 'INPUT.8.LABEL';
			24: OopConfigs := 'INPUT.8.SIDEBAR.ROW';
			25: OopConfigs := 'FLAG.BOARD.1';
			26: OopConfigs := 'FLAG.BOARD.2';
			27: OopConfigs := 'FLAG.BOARD.3';
			28: OopConfigs := 'FLAG.BOARD.4';
			29: OopConfigs := 'FLAG.BOARD.5';
			30: OopConfigs := 'FLAG.BOARD.6';
			31: OopConfigs := 'FLAG.BOARD.7';
			32: OopConfigs := 'FLAG.OBJ.1';
			33: OopConfigs := 'FLAG.OBJ.2';
			34: OopConfigs := 'FLAG.OBJ.3';
			35: OopConfigs := 'FLAG.OBJ.4';
			36: OopConfigs := 'FLAG.OBJ.5';
			37: OopConfigs := 'FLAG.OBJ.6';
			38: OopConfigs := 'WORLD.COUNTER';
			39: OopConfigs := 'WORLD.FLAG';
		else OopConfigs := '_nil' end;
	end;

procedure CustomCharsetLoad(chrfile: string);
	var
		f: file;
		ch: TCharsetData;
	begin
		if LastLoadedCHR <> chrfile then begin
			LastLoadedCHR := chrfile;
			HasCHR := false;
			if (chrfile <> '') and FileExists(chrfile + '.CHR') then begin
				AssignFSys(f, chrfile + '.CHR');
				Reset(f, 1);
				if IOResult = 0 then begin
					HasCHR := true;
					BlockRead(f, ch, 3584);
					Close(f);
					if VideoSetCharset(@ch, 14) then exit;
				end;
			end;
			{ Load default charset if failure/no charset }
			if chrfile = World.Info.Name then
				if VideoSetCharset(nil, 0) then begin end;
		end;

	end;

procedure CustomOOPLoad;
	var
		s: string;
		k, l: string[20];
		c: char;
		f: text;
		i, j, m, n, v: integer;
	begin
		KeyLimit := 0;
		for i := 0 to (CUSTOM_KEY_COUNT - 1) do
			KeyList[i] := #2;
		for i := 1 to CUSTOM_COUNTER_COUNT do begin
			Str(i,s);
			CustomCounterList[i] := 'COUNTER' + s;
		end;
		for i := 1 to (CUSTOM_FLAG_COUNT - 22) do begin
			Str(i,s);
			CustomFlagList[i] := 'FLAG' + s;
		end;
		for i := 3 to 24 do begin
			Str(i,s);
			CustomFlagList[104 + i] := 'HIDELINE' + s;
		end;
		for i := 1 to 7 do begin
			Str(i,s);
			CustomBoardList[i] := 'LOCAL' + s;
		end; 
		for i := 1 to 6 do begin
			Str(i,s);
			CustomObjList[i] := 'OBJ' + s;
		end;
		for i := 3 to 24 do begin
			CustomSidebar[i].Disp := '';
			CustomSidebar[i].Ident := -8;
			CustomSidebar[i].Elmt := -1;
		end;
		HasINI := false;
		if (World.Info.Name <> '')
			and FileExists(World.Info.Name + '.INI')
		then begin
			HasINI := true;
			AssignFSysText(f, World.Info.Name + '.INI');
			Reset(f);
			if IOResult = 0 then begin
				j := 0;
				v := 1;
				m := 1;
				n := 1;
				while j <= 64 do begin
					s := '';
					ReadLn(f, s);
					if s = '' then
						Inc(j)
					else if s[1] <> '#' then begin
						k := '';
						l := '';
						i := 1;
						while (s[i] <> '=') and (i <= Length(s)) do begin
							c := UpCase(s[i]);
							if ((c >= 'A') and (c <= 'Z'))
								or ((c >= '0') and (c <= '9'))
								or (c = '.')
							then
								k := k + c;
							Inc(i);
						end;
						while (s[i] <> #34) and (i <= Length(s)) do
							Inc(i);
						Inc(i);
						while (s[i] <> #34) and (i <= Length(s)) do begin
							l := l + s[i];
							Inc(i);
						end;
						for i := 1 to CUSTOM_KEY_COUNT do
							if OopConfigs(i) = k then begin
								KeyList[i - 1] := l;
								if KeyLimit <= (i div 3) then
									KeyLimit := (i div 3) + 1;
							end;
						for i := (CUSTOM_KEY_COUNT + 1) to CUSTOM_LOCAL_OFFSET do
							if (OopConfigs(i) = k) and (l <> '') then
								CustomBoardList[i - CUSTOM_KEY_COUNT] := UpcaseString(l, false);
						for i := (CUSTOM_LOCAL_OFFSET + 1) to CUSTOM_OBJ_OFFSET do
							if (OopConfigs(i) = k) and (l <> '') then
								CustomObjList[i - CUSTOM_LOCAL_OFFSET] := UpcaseString(l, false);
						if (OopConfigs(CUSTOM_COUNTER_OFFSET) = k) and (l <> '') then begin
							CustomCounterList[v] := UpcaseString(l, false);
							Inc(v);
						end;
						if (OopConfigs(CUSTOM_FLAG_OFFSET) = k) and (l <> '') then begin
							CustomFlagList[m] := UpcaseString(l, false);
							Inc(m);
						end;
					end;
				end;
				Close(f);
			end;
		end;
	end;

procedure CustomSidebarLoad;
	var
		s: string;
		l, t: string[20];
		c: char;
		f: text;
		h, i, j, k: integer;
	begin
		HasCustomSidebar := false;
		if HasINI then begin
			k := 0;
			AssignFSysText(f, World.Info.Name + '.INI');
			Reset(f);
			if (IOResult = 0) then begin
				while k <= 64 do begin
					s := '';
					ReadLn(f, s);
					if s = '' then
						Inc(k);
					if length(s) > 20 then begin
						t := '       ';
						for i := 1 to 7 do
							t[i] := s[i];
						if (t = 'SIDEBAR') or (t = 'sidebar') then begin
							j := Ord(s[9]) - 48;
							if s[10] <> '.' then begin
								j := j * 10;
								inc(j, Ord(s[10]) - 48);
							end;
							if (j > 2) and (j < 25) then begin
								i := 11;
								h := -2;
								while (s[i] <> #34) and (i <= Length(s)) do begin
									if h <> -1 then
										if s[i] = '-' then
											h := -1
										else if (s[i] >= '0') and (s[i] <= '9') then begin
											if h = -2 then Inc(h,2);
											h := h * 10;
											h := h + Ord(s[i]) - 48;
										end;
									Inc(i);
								end;
								CustomSidebar[j].Elmt := h;
								Inc(i);
								l := '';
								t := '';
								while (s[i] <> #34) and (i <= Length(s)) do begin
									l := l + s[i];
									c := UpCase(s[i]);
									if ((c >= 'A') and (c <= 'Z'))
										or ((c >= '0') and (c <= '9'))
									then
										t := t + c;
									Inc(i);
								end;
								if length(l) <= 8 then begin
									CustomSidebar[j].Disp := l;
									for i := 1 to 7 do
										if CustomBoardList[i] = t then
											CustomSidebar[j].Ident := -i;
									for i := 1 to CUSTOM_COUNTER_COUNT do
										if CustomCounterList[i] = t then
											CustomSidebar[j].Ident := i;
									if CustomSidebar[j].Ident > -8 then
										HasCustomSidebar := true;
								end;
							end;
						end;
					end;
				end;
			end;
			Close(f);
		end;
	end;

procedure HighScoresLoad;
	var
		f: file of THighScoreList;
		i: integer;
	begin
		if XDat.Params[72] > 0 then begin
{$IFNDEF MSDOS}
			AssignFSys(f, World.Info.Name + '.HI');
{$ELSE}
			Assign(f, World.Info.Name + '.HI');
{$ENDIF}
			Reset(f);
			if IOResult = 0 then begin
				Read(f, HighScoreList);
				Close(f);
			end else begin
				for i := 1 to XDat.Params[72] do begin
					HighScoreList[i].Name := '';
					HighScoreList[i].Score := -1;
				end;
			end;
		end;
	end;

procedure HighScoresSave;
	var
		f: file of THighScoreList;
	begin
		if XDat.Params[72] > 0 then begin
{$IFNDEF MSDOS}
			AssignFSys(f, World.Info.Name + '.HI');
{$ELSE}
			Assign(f, World.Info.Name + '.HI');
{$ENDIF}
			Rewrite(f);
			Write(f, HighScoreList);
			Close(f);
			if DisplayIOError(World.Info.Name + '.HI') then begin
			end else begin
			end;
		end;
	end;

procedure HighScoresInitTextWindow(var state: TTextWindowState);
	var
		i: integer;
		scoreStr: string;
	begin
		TextWindowInitState(state);
		TextWindowAppend(state, 'Score  Name');
		TextWindowAppend(state, '-----  ----------------------------------');
		for i := 1 to XDat.Params[72] do begin
			if (Length(HighScoreList[i].Name) > 0) and (HighScoreList[i].Score > 0) then begin
				Str(HighScoreList[i].Score:5, scoreStr);
				TextWindowAppend(state, scoreStr + '  ' + HighScoreList[i].Name);
			end;
		end;
	end;

procedure HighScoresDisplay(linePos: integer);
	var
		state: TTextWindowState;
	begin
		state.LinePos := linePos;
		HighScoresInitTextWindow(state);
		if (state.LineCount > 2) then begin
			state.Title := 'High scores for ' + World.Info.Name;
			TextWindowDrawOpen(state);
			TextWindowSelect(state, TWS_VIEWING_FILE);
			TextWindowDrawClose(state);
		end;
		TextWindowFree(state);
	end;

procedure HighScoresAdd(score: integer);
	var
		textWindow: TTextWindowState;
		name: TString50;
		i, listPos: integer;
	begin
		listPos := 1;
		while (listPos <= XDat.Params[72]) and (score < HighScoreList[listPos].Score) do
			listPos := listPos + 1;
		if (listPos <= XDat.Params[72]) and (score > 0) then begin
			for i := (XDat.Params[72] - 1) downto listPos do
				HighScoreList[i + 1] := HighScoreList[i];
			HighScoreList[listPos].Score := score;
			HighScoreList[listPos].Name := '-- You! --';

			HighScoresInitTextWindow(textWindow);
			textWindow.LinePos := listPos;
			textWindow.Title := 'New high score for ' + World.Info.Name;
			TextWindowDrawOpen(textWindow);
			TextWindowDraw(textWindow, false, false);

			name := '';
			PopupPromptString('Congratulations!  Enter your name:', name);
			HighScoreList[listPos].Name := name;
			HighScoresSave;

			TextWindowDrawClose(textWindow);
			TransitionDrawToBoard;
			TextWindowFree(textWindow);
		end;
	end;

function LFSR11UpdateSeed(var seed: word; var tx, ty: byte): boolean;
	begin
		seed := (seed shr 1) xor ((-(seed and 1)) and $740);
		tx := (seed - 1) and $3F;
		ty := ((seed - 1) shr 6) and $3F;
		LFSR11UpdateSeed := seed = LFSR11_START;
	end;

procedure SidebarClearLine(y: integer);
	begin
		if XDat.Params[THEME_START] < 16 then
			VideoWriteText(60, y, XDat.Params[THEME_START], #219)
		else
			VideoWriteText(60, y, AsColor(XDat.Params[THEME_START] div 16 mod 16,
				XDat.Params[THEME_START] mod 16), #179);
		VideoWriteText(61, y, AsColor(XDat.Params[THEME_START] mod 16,
			XDat.Params[THEME_START] div 16 mod 16),
			#219#219#219#219#219#219#219#219#219#219#219#219#219#219#219#219#219#219#219);
	end;

procedure SidebarClear;
	var
		i: integer;
	begin
		for i := 3 to 24 do
			SidebarClearLine(i);
	end;

function EnsureIoTmpBufSize(newSize: word): integer;
	var
		oldSize: word;
	begin
		if newSize > IO_BUFFER_MAXIMUM_SIZE then begin
			EnsureIoTmpBufSize := 2;
			exit;
		end;
		oldSize := IoTmpBufSize;
		EnsureIoTmpBufSize := 0;
		while IoTmpBufSize < newSize do
			Inc(IoTmpBufSize, IO_BUFFER_SIZE_INCREMENT);
		if oldSize <> IoTmpBufSize then begin
			FreeMem(IoTmpBuf, oldSize);
			GetMem(IoTmpBuf, IoTmpBufSize);
			EnsureIoTmpBufSize := 1;
		end;
	end;

procedure BoardClose;
	var
		ix, iy: integer;
		isize: word;
		ptr: pointer;
		rle: TRleTile;
	label RestartWrite;
	begin
		{ Bind stats early. }
		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then begin
					for iy := 1 to (ix - 1) do begin
						if Board.Stats[iy].Data = Data then
							DataLen := -iy;
					end;
				end;
			end;
		end;

	RestartWrite:
		ptr := IoTmpBuf;

		Move(Board.Name, ptr^, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 1;
		rle.Tile := Board.Tiles[ix][iy];
		repeat
			Inc(ix);
			if ix > BOARD_WIDTH then begin
				ix := 1;
				Inc(iy);
			end;
			if (Board.Tiles[ix][iy].Color = rle.Tile.Color) and
				(Board.Tiles[ix][iy].Element = rle.Tile.Element) and
				(rle.Count < 255) and (iy <= BOARD_HEIGHT) then
			begin
				Inc(rle.Count);
			end else begin
				Move(rle, ptr^, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
				rle.Tile := Board.Tiles[ix][iy];
				rle.Count := 1;
			end;
		until iy > BOARD_HEIGHT;

		Move(Board.Info, ptr^, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));

		Move(Board.StatCount, ptr^, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));

		{ We will always have enough size to store the above in the default IoTmpBuf. }
		{ From here, do size estimation. }
		isize := (Ofs(ptr^) - Ofs(IoTmpBuf^)) + ((Board.StatCount + 1) * TSTAT_OFFSET);

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then
					Inc(isize, DataLen);
			end;
		end;

		case EnsureIoTmpBufSize(isize) of
			0: begin end; { We good. }
			1: goto RestartWrite; { Not so good. }
			2: RunError(203);
		end;

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				Move(Board.Stats[ix], ptr^, TSTAT_OFFSET);
				AdvancePointer(ptr, TSTAT_OFFSET);
				if DataLen > 0 then begin
					Move(Data^, ptr^, DataLen);
					FreeMem(Data, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;
		end;

		ExtMemFree(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]);
		World.BoardLen[World.Info.CurrentBoard] := Ofs(ptr^) - Ofs(IoTmpBuf^);
		if ExtMemGet(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]) then begin
			ExtMemWrite(World.BoardData[World.Info.CurrentBoard], IoTmpBuf^, World.BoardLen[World.Info.CurrentBoard]);
		end else RunError(203);
	end;

procedure BoardOpen(boardId: integer);
	var
		ptr: pointer;
		ix, iy: integer;
		rle: TRleTile;
	begin
		if (boardId > World.BoardCount)
			or (boardId < 0)
		then
			boardId := World.Info.CurrentBoard;

		case EnsureIoTmpBufSize(World.BoardLen[boardId]) of
			0, 1: begin end;
			2: RunError(203);
		end;

		ExtMemRead(World.BoardData[boardId], IoTmpBuf^, World.BoardLen[boardId]);

		ptr := IoTmpBuf;

		Move(ptr^, Board.Name, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 0;
		repeat
			if rle.Count <= 0 then begin
				Move(ptr^, rle, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
			end;
			Board.Tiles[ix][iy] := rle.Tile;
			Inc(ix);
			if ix > BOARD_WIDTH then begin
				ix := 1;
				Inc(iy);
			end;
			Dec(rle.Count);
		until iy > BOARD_HEIGHT;

		Move(ptr^, Board.Info, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));

		Move(ptr^, Board.StatCount, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				Move(ptr^, Board.Stats[ix], TSTAT_OFFSET);
				AdvancePointer(ptr, TSTAT_OFFSET);
				Data := nil;
				if DataLen > 0 then begin
{$IFDEF MSDOS}
					if MaxAvail < DataLen then begin
					end;
{$ENDIF}

					GetMem(Data, DataLen);
					Move(ptr^, Data^, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				if DataLen < 0 then begin
					Data := Board.Stats[-DataLen].Data;
					DataLen := Board.Stats[-DataLen].DataLen;
				end;
			end;

		World.Info.CurrentBoard := boardId;
	end;

procedure BoardChange(boardId: integer);
	var
		iy: integer;
		lstring: string;
	begin
		if World.Info.CurrentBoard <> boardId then begin
			BoardClose;
			BoardOpen(boardId);
			If HasCustomSidebar and (boardId <> 0) then GameDrawCustomSidebar;
		end;
		if HasCHR then
			if (Board.Name[1] = ':') then begin
				iy := 1;
				lstring := '';
				while iy < 9 do begin
					if ((Board.Name[iy + 1] >= 'A') and (Board.Name[iy + 1] <= 'Z'))
						or ((Board.Name[iy + 1] >= 'a') and (Board.Name[iy + 1] <= 'z'))
						or ((Board.Name[iy + 1] >= '0') and (Board.Name[iy + 1] <= '9'))
					then begin
						lstring[0] := Chr(iy);
						lstring[iy] := Board.Name[iy + 1];
					end else
						iy := 8;
					inc(iy);
				end;
				if lstring <> '' then
					CustomCharsetLoad(lstring);
			end else
				CustomCharsetLoad(World.Info.Name);
	end;

procedure BoardCreate;
	var
		ix, iy, i: integer;
	begin
		Board.Name := '';
		Board.Info.Message := '';
		Board.Info.MaxShots := -1;
		Board.Info.IsDark := 0;
		Board.Info.ReenterWhenZapped := false;
		Board.Info.TimeLimitSec := 0;
		Board.Info.BoardTicks := 0;
		for i := 0 to 3 do
			Board.Info.NeighborBoards[i] := 0;

		for ix := 0 to BOARD_WIDTH+1 do begin
			Board.Tiles[ix][0] := TileBoardEdge;
			Board.Tiles[ix][BOARD_HEIGHT+1] := TileBoardEdge;
		end;
		for iy := 0 to BOARD_HEIGHT+1 do begin
			Board.Tiles[0][iy] := TileBoardEdge;
			Board.Tiles[BOARD_WIDTH+1][iy] := TileBoardEdge;
		end;

		for ix := 1 to BOARD_WIDTH do
			for iy := 1 to BOARD_HEIGHT do begin
				Board.Tiles[ix][iy].Element := E_EMPTY;
				Board.Tiles[ix][iy].Color := 0;
			end;

		for ix := 1 to BOARD_WIDTH do begin
			Board.Tiles[ix][1] := TileBorder;
			Board.Tiles[ix][BOARD_HEIGHT] := TileBorder;
		end;
		for iy := 1 to BOARD_HEIGHT do begin
			Board.Tiles[1][iy] := TileBorder;
			Board.Tiles[BOARD_WIDTH][iy] := TileBorder;
		end;

		Board.Tiles[BOARD_WIDTH div 2][BOARD_HEIGHT div 2].Element := E_PLAYER;
		Board.Tiles[BOARD_WIDTH div 2][BOARD_HEIGHT div 2].Color := XDat.EDefs[E_PLAYER].Color;
		Board.StatCount := 0;
		Board.Stats[0].X := BOARD_WIDTH div 2;
		Board.Stats[0].Y := BOARD_HEIGHT div 2;
		Board.Stats[0].Cycle := 1;
		Board.Stats[0].Under.Element := E_EMPTY;
		Board.Stats[0].Under.Color := 0;
		Board.Stats[0].Data := nil;
		Board.Stats[0].DataLen := 0;
	end;

procedure WorldCreate;
	var
		i: integer;
	begin
		World.Info.Name := '';
		InitElementsGame;
		PushPalette;
		SetPalette(false);
		World.BoardCount := 0;
		World.BoardLen[0] := 0;
		ResetMessageNotShownFlags;
		BoardCreate;
		World.Info.IsSave := 0;
		World.Info.CurrentBoard := 0;
		World.Info.Ammo := 0;
		World.Info.Gems := 0;
		World.Info.Health := 100;
		World.Info.EnergizerTicks := 0;
		World.Info.Torches := 0;
		World.Info.TorchTicks := 0;
		World.Info.Score := 0;
		World.Info.BoardTimeSec := 0;
		World.Info.BoardTimeHsec := 0;
		for i := 1 to 7 do
			World.Info.Keys[i] := 0;
		for i := 1 to MAX_FLAG do
			World.Info.Flags[i] := '';
		for i := MAX_FLAG + 1 to MAX_EXTENDEDFLAG do
			XDat.Flags[i] := '';
		BoardChange(0);
		Board.Name := 'Title screen';
		LoadedGameFileName := '';

		for i := 1 to CUSTOM_COUNTER_COUNT do
			World.Info.CustomCounters[i] := 0;
		CustomOOPLoad;
		HasCHR := false;
	end;

procedure TransitionDrawToFill(chr: char; color: integer);
	var
		seed: word;
		tx, ty: byte;
	begin
		seed := LFSR11_START;
		repeat
			if (tx < 60) and (ty < 25) then
				VideoWriteText(tx, ty, color, chr);
		until LFSR11UpdateSeed(seed, tx, ty);

		if (tx < 60) and (ty < 25) then
			VideoWriteText(tx, ty, color, chr);
	end;

procedure BoardDrawTile(x, y: integer);
	var
		e: integer;
		ch: byte;
	begin
		if (y < BOARD_HEIGHT)
			or (Board.Info.Message = '')
			or (x <= (60 - Length(Board.Info.Message)) div 2)
			or (x > (60 + Length(Board.Info.Message)) div 2)
		then begin
			if (x < 1) or (x > BOARD_WIDTH) or (y < 1) or (y > BOARD_HEIGHT) then exit;
			with Board.Tiles[x][y] do begin
				e := Enum(Element);
				if ((Board.Info.IsDark < 1) or XDat.EDefs[e].SeeDark)
					or (
						(World.Info.TorchTicks <> 0)
						and (
							(Sqr(Board.Stats[0].X-x)*XDat.Params[3])
							+ (Sqr(Board.Stats[0].Y-y)*XDat.Params[4])
							< XDat.Params[5]
						)
					) {Torch Radius}
				then begin
					if Element = E_EMPTY then
						VideoWriteText(x - 1, y - 1, $0F, ' ')
					else if XDat.EDefs[e].HasDrawProc then begin
						XDat.EDefs[e].DrawProc(x, y, ch);
						VideoWriteText(x - 1, y - 1, Color, Chr(ch));
					end else if Element < E_TEXT_MIN then
						VideoWriteText(x - 1, y - 1, Color, XDat.EDefs[e].Character)
					else if Element > 127 then
						VideoWriteText(x - 1, y - 1, Element - 128, Chr(Board.Tiles[x][y].Color))
					else
						VideoWriteText(x - 1, y - 1, XDat.EDefs[e].Color, Chr(Board.Tiles[x][y].Color));
				end else begin
					{ Darkness }
					VideoWriteText(x - 1, y - 1, XDat.EDefs[E_DARKNESS].Color, XDat.EDefs[E_DARKNESS].Character); {Darkness}
				end;
			end;
		end;
	end;

procedure BoardDrawRow(row: integer);
	var
		ix: integer;
	begin
		for ix := 1 to BOARD_WIDTH do
			BoardDrawTile(ix, row);
	end;

procedure BoardDrawBottom;
	var
		s: string[58];
		ix: integer;
	begin
		s := Board.Info.Message;
		Board.Info.Message := '';
		for ix := 1 to BOARD_WIDTH do
			BoardDrawTile(ix, BOARD_HEIGHT);
		Board.Info.Message := s;
	end;

procedure BoardDrawBorder;
	var
		iy: integer;
	begin
		BoardDrawRow(1);
		BoardDrawRow(BOARD_HEIGHT);

		for iy := 1 to BOARD_HEIGHT do begin
			BoardDrawTile(1, iy);
			BoardDrawTile(BOARD_WIDTH, iy);
		end;
	end;

procedure TransitionDrawToBoard;
	var
		seed: word;
		tx, ty: byte;
	begin
		seed := LFSR11_START;
		BoardDrawBorder;
		repeat
			if (tx < 60) and (ty < 25) then
				BoardDrawTile(tx+1, ty+1);
		until LFSR11UpdateSeed(seed, tx, ty);
		if (tx < 60) and (ty < 25) then
			BoardDrawTile(tx+1, ty+1);
	end;


procedure SidebarPromptSlider(editable: boolean; x, y: integer; prompt: string; var value: shortint);
	var
		newValue: integer;
		startChar, endChar: char;
	begin
		if prompt[Length(prompt) - 2] = ';' then begin
			startChar := prompt[Length(prompt) - 1];
			endChar := prompt[Length(prompt)];
			prompt := Copy(prompt, 1, Length(prompt) - 3);
		end else begin
			startChar := '1';
			endChar := '9';
		end;

		SidebarClearLine(y);
		VideoWriteText(x, y, AsColor(XDat.Params[THEME_START + 2 - Integer(editable)],
			XDat.Params[THEME_START]), prompt);
		SidebarClearLine(y + 1);
		SidebarClearLine(y + 2);
		VideoWriteText(x, y + 2, AsColor(XDat.Params[THEME_START + 2],
			XDat.Params[THEME_START]), startChar + '....:....' + endChar);

		repeat
			if editable then begin
				if InputJoystickMoved then
					Delay(45);
				VideoWriteText(x + value + 1, y + 1, AsColor(XDat.Params[THEME_START + 1],
					XDat.Params[THEME_START] + 8), #31);

{$IFDEF SDL2}
				TimerSysIdle(IMUntilFrame);
{$ENDIF}
				InputUpdate;
				if (InputKeyPressed >= '1') and (InputKeyPressed <= '9') then begin
					value := Ord(InputKeyPressed) - 49;
					SidebarClearLine(y + 1);
				end else begin
					newValue := value + InputDeltaX;
					if (value <> newValue) and (newValue >= 0) and (newValue <= 8) then begin
						value := newValue;
						SidebarClearLine(y + 1);
					end;
				end;
			end;
		until (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = KEY_ESCAPE) or not editable or InputShiftPressed;

		VideoWriteText(x + value + 1, y + 1, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), #31);
	end;

procedure PromptString(x, y, arrowColor, color, width: integer; mode: byte; var buffer: TString50);
	var
		i: integer;
		oldBuffer: string;
		firstKeyPress: boolean;
	begin
		oldBuffer := buffer;
		firstKeyPress := true;

		repeat
			for i := 0 to (width - 1) do begin
				VideoWriteText(x + i, y, color, ' ');
				VideoWriteText(x + i, y - 1, arrowColor, ' ');
			end;
			VideoWriteText(x + width, y - 1, arrowColor, ' ');
			VideoWriteText(x + Length(buffer), y - 1, AsColor(XDat.Params[THEME_START + 1],
				arrowColor div $10), #31);
			VideoWriteText(x, y, color, buffer);

			InputReadWaitKey;

			if (Length(buffer) < width) and (InputKeyPressed >= #32) and (InputKeyPressed < #128) then begin
				if firstKeyPress then
					buffer := '';
				case mode of
					PROMPT_NUMERIC: begin
						if (InputKeyPressed in ['0' .. '9']) then begin
							buffer := buffer + InputKeyPressed;
						end;
					end;
					PROMPT_ANY: begin
						buffer := buffer + InputKeyPressed;
					end;
					PROMPT_ALPHANUM: begin
						if (UpCase(InputKeyPressed) in ['A' .. 'Z'])
							or (InputKeyPressed in ['0' .. '9'])
							or (InputKeyPressed = '-') then
						begin
							buffer := buffer + UpCase(InputKeyPressed);
						end;
					end;
				end;
			end else if (InputKeyPressed = KEY_LEFT) or (InputKeyPressed = KEY_BACKSPACE) then begin
				buffer := Copy(buffer, 1, Length(buffer) - 1);
			end;

			firstKeyPress := false;
		until (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = KEY_ESCAPE);
		if InputKeyPressed = KEY_ESCAPE then begin
			buffer := oldBuffer;
		end;
	end;

function SidebarPromptYesNo(message: string; defaultReturn: boolean): boolean;
	begin
		SidebarClearLine(5);
		VideoWriteText(63, 5, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), message);
		VideoWriteText(63 + Length(message), 5, AsColor(XDat.Params[THEME_START + 2],
			8 + XDat.Params[THEME_START]), '_');

		SetPalette(true);
		repeat
			InputReadWaitKey;
		until UpCase(InputKeyPressed) in [KEY_ESCAPE, 'N', 'Y'];
		SetPalette(false);
		if UpCase(InputKeyPressed) = 'Y' then
			defaultReturn := true
		else
			defaultReturn := false;

		SidebarClearLine(5);
		GameDrawCustomSidebar;
		SidebarPromptYesNo := defaultReturn;
	end;

procedure SidebarPromptString(prompt: string; extension: TString50; var filename: string; promptMode: byte);
	begin
		SidebarClearLine(3);
		SidebarClearLine(4);
		SidebarClearLine(5);
		VideoWriteText(75 - Length(prompt), 3, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), prompt);
		VideoWriteText(63, 5, AsColor(XDat.Params[THEME_START + 1],0), '        ' + extension);

		PromptString(63, 5, AsColor(XDat.Params[THEME_START + 2],
			XDat.Params[THEME_START]),
			AsColor(XDat.Params[THEME_START + 1],0), 8, promptMode, filename);

		SidebarClearLine(3);
		SidebarClearLine(4);
		SidebarClearLine(5);
		GameDrawCustomSidebar;
	end;

procedure PauseOnError;
	begin
		SoundQueue(1, SoundParse('s004x114x9'));
		InputKeyPressed := #0;
		while (InputKeyPressed = #0) do begin
			if SoundHasTimeElapsed(TickTimeCounter, 25) then begin
{$IFDEF SDL2}
				TimerSysIdle(IMUntilFrame);
{$ENDIF}
				InputUpdate;
			end;

			if ((InputKeyPressed >= 'A')
				and (InputKeyPressed <= 'Z'))
				or ((InputKeyPressed >= 'a')
				and (InputKeyPressed <= 'z'))
				or ((InputKeyPressed >= '0')
				and (InputKeyPressed <= '9'))
				or (InputKeyPressed in [KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, #27, ' '])
			then
				Delay(2000)
			else
				InputKeyPressed := #0;
		end;
	end;

function DisplayIOError(filename: TString50): boolean;
	begin
		if IOResult = 0 then
			DisplayIOError := false
		else
			DisplayIOError := true;
	end;

procedure WorldUnload;
	var
		i: integer;
	begin
		BoardClose;
		for i := 0 to World.BoardCount do
			ExtMemFree(World.BoardData[i], World.BoardLen[i]);
	end;

function WorldLoad(filename, extension: TString50): boolean;
	var
		f: file;
		ptr: pointer;
		boardId: integer;
	label OnError;
	begin
		WorldLoad := false;
		if not FileExists(filename + extension) then begin
			exit;
		end;
		SidebarClearLine(4);
		SidebarClearLine(5);
		VideoWriteText(62, 5, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), 'Loading.....');

		AssignFSys(f, filename + extension);
		Reset(f, 1);

		if not DisplayIOError(filename + extension) then begin
			WorldUnload;
			BlockRead(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);

			if not DisplayIOError(filename + extension) then begin
				ptr := IoTmpBuf;
				Move(ptr^, World.BoardCount, SizeOf(World.BoardCount));
				AdvancePointer(ptr, SizeOf(World.BoardCount));

				if World.BoardCount < 0 then begin
					if World.BoardCount <> -1 then begin
						VideoWriteText(21, 11, $40,
							#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223);
						VideoWriteText(21, 12, $40, '    This is not a   ');
						VideoWriteText(21, 13, $40, '  valid WEAVE .ZZT! ');
						VideoWriteText(21, 14, $04,
							#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223);
						Close(f);
						goto OnError;
					end else begin
						Move(ptr^, World.BoardCount, SizeOf(World.BoardCount));
						AdvancePointer(ptr, SizeOf(World.BoardCount));
					end;
				end;

				if (World.BoardCount > MAX_BOARD) or (World.BoardCount < 0) then begin
					VideoWriteText(62, 5, $1E, 'Too many boards!');
					World.BoardCount := 0;
					exit;
				end;

				Move(ptr^, World.Info, SizeOf(World.Info));
				AdvancePointer(ptr, SizeOf(World.Info));

				for boardId := 0 to World.BoardCount do begin
					BlockRead(f, World.BoardLen[boardId], 2);

					if ExtMemGet(World.BoardData[boardId], World.BoardLen[boardId]) then begin
						case EnsureIoTmpBufSize(World.BoardLen[boardId]) of
							0, 1: begin end;
							2: RunError(203);
						end;

						BlockRead(f, IoTmpBuf^, World.BoardLen[boardId]);
						Move(IoTmpBuf^, BoardNames^[boardId], SizeOf(TString50));
						ExtMemWrite(World.BoardData[boardId], IoTmpBuf^, World.BoardLen[boardId]);
					end else RunError(203);
				end;


				if extension = '.SAV' then begin
					BlockRead(f, XDat, SizeOf(XDat));
					if (XDat.Version <> FOOTER_VERSION) then begin
						VideoWriteText(22, 10, $40,
							#219#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#223#219);
						VideoWriteText(22, 11, $40, ' This .SAV file is ');
						VideoWriteText(22, 12, $40, '   for the wrong   ');
						VideoWriteText(22, 13, $40, ' version of WEAVE! ');
						VideoWriteText(22, 14, $40,
							#219#220#220#220#220#220#220#220#220#220#220#220#220#220#220#220#220#220#219);
						Close(f);
						goto OnError;
					end;
					GameDrawTheme;
				end else
					InitElementsGame;
				SetPalette(false);
				CurrentBlink := (XDat.Params[THEME_BLINK] = 0);
				SetBlink(CurrentBlink);
				if QuickStart and (QStartBoard > -1) then
					XDat.Params[21] := QStartBoard;
				if (XDat.Params[21] <> -1) and (World.Info.IsSave = 0) then
					World.Info.CurrentBoard := XDat.Params[21];
				BoardOpen(World.Info.CurrentBoard);
				BoardDrawBottom;
				LoadedGameFileName := filename;
				WorldLoad := true;

				CustomOOPLoad;
				CustomSidebarLoad;
				CustomCharsetLoad(World.Info.Name);

				HighScoresLoad;
				SidebarClearLine(5);

			end;
		OnError:
			Close(f);
		end;
	end;

procedure WorldSave(filename, extension: TString50);
	var
		f: file;
		i: integer;
		unk1: integer;
		ptr: pointer;
		version: integer;
	label OnError;
	begin
		BoardClose;
		VideoWriteText(63, 5, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), 'Saving...');

		AssignFSys(f, filename + extension);
		Rewrite(f, 1);

		if not DisplayIOError(filename + extension) then begin
			ptr := IoTmpBuf;
			FillChar(IoTmpBuf^, WORLD_FILE_HEADER_SIZE, 0);
			version := -1;
			Move(version, ptr^, SizeOf(version));
			AdvancePointer(ptr, SizeOf(version));

			Move(World.BoardCount, ptr^, SizeOf(World.BoardCount));
			AdvancePointer(ptr, SizeOf(World.BoardCount));

			Move(World.Info, ptr^, SizeOf(World.Info));
			AdvancePointer(ptr, SizeOf(World.Info));

			BlockWrite(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);
			if DisplayIOError(filename + extension) then goto OnError;

			for i := 0 to World.BoardCount do begin
				BlockWrite(f, World.BoardLen[i], 2);
				if DisplayIOError(filename + extension) then goto OnError;

				ExtMemRead(World.BoardData[i], IoTmpBuf^, World.BoardLen[i]);
				BlockWrite(f, IoTmpBuf^, World.BoardLen[i]);
				if DisplayIOError(filename + extension) then goto OnError;
			end;
			if extension = '.SAV' then begin
				XDat.Version := FOOTER_VERSION;
				BlockWrite(f, XDat, SizeOf(XDat));
			end;
			Close(f);
		end;

		BoardOpen(World.Info.CurrentBoard);
		SidebarClearLine(5);
		GameDrawCustomSidebar;
		exit;

	OnError:
		Close(f);
		Erase(f);
		BoardOpen(World.Info.CurrentBoard);
		SidebarClearLine(5);
		GameDrawCustomSidebar;
	end;

procedure GameWorldSave(prompt: TString50; var filename: TString50; extension: TString50);
	var
		newFilename: TString50;
	begin
		newFilename := filename;
		SetPalette(true);
		SidebarPromptString(prompt, extension, newFilename, PROMPT_ALPHANUM);
		SetPalette(false);
		if (InputKeyPressed <> KEY_ESCAPE) and (Length(newFilename) <> 0) then begin
			filename := newFilename;
			if extension = '.ZZT' then
				World.Info.Name := filename
			else
				CurrentSave := filename;
			WorldSave(filename, extension);
		end;
	end;

function GameWorldLoad(extension: TString50): boolean;
	var
		entryName: string;
	begin
		{ As directory listings can take up a lot of memory, }
		{ free IoTmpBuf for the duration - the data will be }
		{ unloaded later anyway. - asie }
		FreeMem(IoTmpBuf, IoTmpBufSize);

		GameWorldLoad := false;
		if extension = '.ZZT' then
			entryName := FileSelect('ZZT Worlds', extension, FileWorldCachedLinePos)
		else
			entryName := FileSelect('Saved Games', extension, FileSaveCachedLinePos);

		GetMem(IoTmpBuf, IoTmpBufSize);

		if Length(entryName) > 0 then begin
			if WorldLoad(entryName, extension) then begin
				GameWorldLoad := true;
				if extension = '.ZZT' then LoadPalette;
			end else begin
				WorldCreate;
				PauseOnError;
			end;
			TransitionDrawToFill(#177, $4C);
		end;
	end;

procedure AddStat(tx, ty: integer; txelement, txcolor: byte; tcycle: integer; template: TStat);
	var
		i: integer;
	begin
		if Board.StatCount < XDat.Params[9] then begin {Max Stats}
			Inc(Board.StatCount);
			Board.Stats[Board.StatCount] := template;
			with Board.Stats[Board.StatCount] do begin
				X := tx;
				Y := ty;
				Cycle := tcycle;
				if template.Cycle = 255 then begin
					P1 := XDat.EDefs[Enum(txelement)].P1;
					P2 := XDat.EDefs[Enum(txelement)].P2;
					P3 := XDat.EDefs[Enum(txelement)].P3;
				end else begin
					P1 := template.P1;
					P2 := template.P2;
					P3 := template.P3;
					for i := 1 to 4 do
						ObjLocal[i] := template.ObjLocal[i];
					Leader := template.Leader;
					Follower := template.Follower;
				end;
				Under := Board.Tiles[tx][ty];
				Data := nil;
				DataPos := 0;
			end;

			if (template.Data <> nil) and (template.DataLen > 0) then begin
				GetMem(Board.Stats[Board.StatCount].Data, template.DataLen);
				Move(template.Data^, Board.Stats[Board.StatCount].Data^, template.DataLen);
			end;

			Board.Tiles[tx][ty].Color := txcolor;
			Board.Tiles[tx][ty].Element := txelement;

			if ty > 0 then
				BoardDrawTile(tx, ty);
		end;
	end;

procedure FreeStatDataMem(statId: integer);
	var
		i: integer;
	begin
		with Board.Stats[statId] do begin
			if DataLen <> 0 then begin
				for i := 1 to Board.StatCount do begin
					if (Board.Stats[i].Data = Data) and (i <> statId) then
						exit;
				end;
				FreeMem(Data, DataLen);
			end;
		end;
	end;

function FileLoadStatData(s: TString50; statId: integer): boolean;
	var
		TmpString: string;
		f: text;
		i, j, k: integer;
		NumRead: word;
		TmpPtr: pointer;
	begin
		FileLoadStatData := false;
		if not FileExists(s + '.OBJ') then exit;
		FileLoadStatData := true;
		AssignFSysText(f, s + '.OBJ');
		Reset(f);
		with TrackPushStat(statId)^ do begin
			FreeStatDataMem(Index);
			if s <> CurrentFile then begin
				CurrentFile := s;
				NumRead := 0;
				k := 0;
				TmpPtr := ObjTmpBuf;

				for i := 1 to 1024 do begin
					TmpString := '';
					ReadLn(f, TmpString);
					if NumRead < (LOAD_OBJ_LENGTH - 255) then begin
						if TmpString <> '' then begin
							k := 0;
							TmpString := TmpString + KEY_ENTER;
							NumRead := NumRead + Length(TmpString);
							for j := 1 to Length(TmpString) do begin
								Char(TmpPtr^) := TmpString[j];
								AdvancePointer(TmpPtr, 1);
							end;
						end else begin
							Inc(NumRead);
							Inc(k);
							Char(TmpPtr^) := KEY_ENTER;
							AdvancePointer(TmpPtr, 1);
						end;
					end;
				end;
				CurFileLen := NumRead -k;
			end;

			GetMem(Stat^.Data, CurFileLen);
			Move(ObjTmpBuf^, Stat^.Data^, CurFileLen);
			Stat^.DataLen := CurFileLen;
			Stat^.DataPos := 0;
		end;
		TrackPopStat;

		Close(f);
		if IOResult <> 0 then begin end;
	end;

function FileAppendStatData(s: TString50; statId: integer): boolean;
	var
		TmpString: string;
		f: text;
		i, j, k: integer;
		NumRead: word;
		TmpPtr: pointer;
	begin
		FileAppendStatData := false;
		if not FileExists(s + '.OBJ') then exit;
		FileAppendStatData := true;
		AssignFSysText(f, s + '.OBJ');
		Reset(f);
		CurrentFile := #0;
		with TrackPushStat(statId)^ do begin
			TmpPtr := ObjTmpBuf;
			Move(Stat^.Data^, TmpPtr^, Stat^.DataLen);
			AdvancePointer(TmpPtr, Stat^.DataLen);
			NumRead := Stat^.DataLen;
			FreeStatDataMem(Index);
			k := 0;
			i := 0;

			while i < 1024 do begin
				Inc(i);
				TmpString := '';
				ReadLn(f, TmpString);
				if NumRead < (LOAD_OBJ_LENGTH - 255) then begin
					if TmpString <> '' then begin
						k := 0;
						TmpString := TmpString + KEY_ENTER;
						NumRead := NumRead + Length(TmpString);
						for j := 1 to Length(TmpString) do begin
							Char(TmpPtr^) := TmpString[j];
							AdvancePointer(TmpPtr, 1);
						end;
					end else begin
						Inc(NumRead);
						Inc(k);
						if k > 5 then i := 1024;
						Char(TmpPtr^) := KEY_ENTER;
						AdvancePointer(TmpPtr, 1);
					end;
				end;
			end;

			GetMem(Stat^.Data, NumRead - k);
			Move(ObjTmpBuf^, Stat^.Data^, NumRead - k);
			Stat^.DataLen := NumRead - k;
		end;
		TrackPopStat;
		Close(f);
		if IOResult <> 0 then begin end;
	end;

procedure RemoveStat(statId: integer);
	var
		i: integer;
	begin
		with Board.Stats[statId] do begin
			FreeStatDataMem(statId);

			if statId < CurrentStatTicked then
				CurrentStatTicked := CurrentStatTicked - 1;
			TrackOnRemoveStat(statId);

			Board.Tiles[X][Y] := Under;
			if Y > 0 then
				BoardDrawTile(X, Y);
			for i := 1 to Board.StatCount do begin
				if (Board.Tiles[Board.Stats[i].X,Board.Stats[i].Y].Element = E_CENTIPEDE_HEAD)
					or (Board.Tiles[Board.Stats[i].X,Board.Stats[i].Y].Element = E_CENTIPEDE_SEGMENT)
				then begin
					if Board.Stats[i].Follower >= statId then begin
						if Board.Stats[i].Follower = statId then
							Board.Stats[i].Follower := -1
						else
							Dec(Board.Stats[i].Follower);
					end;
					if Board.Stats[i].Leader >= statId then begin
						if Board.Stats[i].Leader = statId then
							Board.Stats[i].Leader := -1
						else
							Dec(Board.Stats[i].Leader);
					end;
				end;
			end;
			for i := (statId + 1) to Board.StatCount do
				Board.Stats[i - 1] := Board.Stats[i];
			Dec(Board.StatCount);
		end;
	end;

{$IFDEF FPC}
procedure AdvancePointer(var address: pointer; count: integer);
	begin
		Inc(address, count);
	end;
{$ENDIF}


{$IFDEF CPU8086}
{ GetStatIdAt - hand-rolled ASM version }
{$IFNDEF FPC}
function GetStatIdAt(tx, ty: integer): integer;
	var
		sc: integer;
		st: word;
	begin
		{ Work around TP 5.5 flaw }
		sc := Board.StatCount;
		st := Ofs(Board.Stats);

		inline(
			$8B/$46/<tx/ { MOV AX, tx }
			$0B/$46/<ty/ { OR AX, ty }
			$25/$00/$FF/ { AND AX, 0xFF00 }
			$74/$02/ { JZ func_valid_range }
			$EB/$1E/ { JMP func_notfound }
			{ func_valid_range: }
			$8B/$5E/<ty/ { MOV BX, ty }
			$B1/$08/ { MOV CL, 0x8 }
			$D3/$E3/ { SHL BX, CL }
			$0B/$5E/<tx/ { OR BX, tx }
			$8B/$7E/<st/ { MOV DI, Board.Stats }
			$8B/$4E/<sc/ { MOV CX, [Board.StatCount] }
			$31/$C0/ { XOR AX, AX }
			{ func_loop: }
			$39/$1D/ { CMP [DI], BX }
			$74/$0B/ { JZ func_exit }
			$83/$C7/SizeOf(TStat)/ { ADD DI, SizeOf(TStat) }
			$40/ { INC AX }
			$39/$C8/ { CMP AX, CX }
			$7E/$F4/ { JLE func_loop }
			{ func_notfound: }
			$B8/$FF/$FF/ { MOV AX, 0xFFFF }
			{ func_finish: }
			{ Another TP 5.5 workaround... }
			$89/$46/$FE { MOV [return value], AX }
		);
	end;
{$ELSE}
function GetStatIdAt(tx, ty: integer): integer;
	assembler;
	label func_valid_range;
	label func_loop;
	label func_notfound;
	label func_finish;
	asm
		mov ax, tx
		or ax, ty
		and ax, 0FF00h
		jz func_valid_range
		jmp func_notfound
	func_valid_range:
		mov bx, ty
		mov cl, 8
		shl bx, cl
		or bx, tx
		mov di, offset Board.Stats
		mov cx, [Board.StatCount]
		xor ax, ax
	func_loop:
		cmp [di], bx
		je func_finish
		add di, SizeOf(TStat)
		inc ax
		cmp ax, cx
		jle func_loop
	func_notfound:
		mov ax, 0FFFFh
	func_finish:
	end ['ax', 'bx', 'cx', 'di'];
{$ENDIF}

{$ELSE}
function GetStatIdAt(tx, ty: integer): integer;
	var
		i: integer;
	begin
		i := -1;
		repeat
			Inc(i);
		until ((Board.Stats[i].X = tx) and (Board.Stats[i].Y = ty)) or (i > Board.StatCount);

		if i > Board.StatCount then
			GetStatIdAt := -1
		else
			GetStatIdAt := i;
	end;
{$ENDIF}

function BoardPrepareTileForPlacement(x, y: integer): boolean;
	var
		statId: integer;
		result: boolean;
	begin
		statId := GetStatIdAt(x, y);
		if statId > 0 then begin
			RemoveStat(statId);
			result := true;
		end else if statId < 0 then begin
			if not XDat.EDefs[Enum(Board.Tiles[x][y].Element)].CanPut then
				Board.Tiles[x][y].Element := E_EMPTY;
			result := true;
		end else result := false;
		BoardDrawTile(x, y);
		BoardPrepareTileForPlacement := result;
	end;

procedure MoveStat(statId: integer; newX, newY: integer);
	var
		iUnder: TTile;
		ix, iy: integer;
		oldX, oldY: integer;
		oldBgColor: integer;
		ptr: pointer;
	begin
		if statId = 0 then begin
			if (newX < 0) or (newX > (BOARD_WIDTH + 1)) then exit;
			if (newY < 0) or (newY > (BOARD_HEIGHT + 1)) then exit;
			ptr := PathTmpBuf;
			AdvancePointer(ptr, (newY - 1) * 60);
			AdvancePointer(ptr, newX - 1);
			Char(ptr^) := Chr(Board.Info.BoardTicks mod 255);
		end else begin
			if (newX < 1) or (newX > BOARD_WIDTH) then exit;
			if (newY < 1) or (newY > BOARD_HEIGHT) then exit;
		end;
		with Board.Stats[statId] do begin
			with Board.Tiles[newX][newY] do begin
				if Element = E_EMPTY then
					oldBgColor := 0
				else if Element >= E_TEXT_MIN then
					oldBgColor := ElemDefColor(Element) and $F0
				else
					oldBgColor := Color and $F0;
			end;
			if XDat.Params[THEME_BLINK] = 0 then
				oldBgColor := oldBgColor and $70;

			iUnder := Under;
			Under := Board.Tiles[newX][newY];

			with Board.Tiles[X][Y] do begin
				if (Element = E_PLAYER) or ((ElemDefColor(Element) and $F0) > 0) then
					Board.Tiles[newX][newY].Color := Color
				else
					Board.Tiles[newX][newY].Color := (Color and $0F) + oldBgColor;
				Board.Tiles[newX][newY].Element := Element;
			end;
			Board.Tiles[X][Y] := iUnder;

			oldX := X;
			oldY := Y;
			X := newX;
			Y := newY;

			BoardDrawTile(X, Y);
			BoardDrawTile(oldX, oldY);

			if (statId = 0)
				and (Board.Info.IsDark > 0)
				and (World.Info.TorchTicks <> 0)
			then
				TransitionDrawToBoard;

		end;
	end;

procedure PopupPromptString(question: string; var buffer: TString50);
	var
		x, y: integer;
	begin
		VideoWriteText(3, 18, $4F, TextWindowStrTop);
		VideoWriteText(3, 19, $4F, TextWindowStrText);
		VideoWriteText(3, 20, $4F, TextWindowStrSep);
		VideoWriteText(3, 21, $4F, TextWindowStrText);
		VideoWriteText(3, 22, $4F, TextWindowStrText);
		VideoWriteText(3, 23, $4F, TextWindowStrBottom);
		VideoWriteText(4 + (TextWindowWidth - Length(question)) div 2, 19, $4F, question);
		buffer := '';
		PromptString(10, 22, $4F, $4E, TextWindowWidth - 16, PROMPT_ANY, buffer);
		for y := 18 to 23 do
			for x := 3 to (TextWindowWidth + 3) do
				BoardDrawTile(x + 1, y + 1);
	end;

function Signum(val: integer): integer;
	begin
		if val > 0 then
			Signum := 1
		else if val < 0 then
			Signum := -1
		else
			Signum := 0;
	end;

function Difference(a, b: integer): integer;
	begin
		if (a - b) >= 0 then
			Difference := a - b
		else
			Difference := b - a;
	end;

procedure GameUpdateSidebar;
	var
		keyChar: char;
		numStr: TString8;
		i, j, y: integer;
	begin
		if GameStateElement = E_PLAYER then begin
			if World.Info.Health < 0 then
				World.Info.Health := 0;
			for j := 1 to 9 do begin
				y := MainSidebarList[j];
				if ((CFlagPos[8 + y] and World.Info.CustomFlags[3]) = 0) then begin
					case y of
						6: if XDat.Configs[69] <> '' then {Time Sidebar}
							if Board.Info.TimeLimitSec > 0 then begin
								VideoWriteText(64, 6, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), XDat.Configs[69]);
								Str(Board.Info.TimeLimitSec - World.Info.BoardTimeSec, numStr);
								VideoWriteText(72, 6, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), numStr + ' ');
							end else SidebarClearLine(6);
						7: begin
							Str(World.Info.Health, numStr);
							if XDat.Configs[63] <> '' then {Health Sidebar}
								VideoWriteText(72, 7, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), numStr + ' ');
						end;
						8: begin
							Str(World.Info.Ammo, numStr);
							if XDat.Configs[64] <> '' then {Ammo Sidebar}
								VideoWriteText(72, 8, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), numStr + '  ');
						end;
						9: begin
							if XDat.Configs[65] <> '' then begin {Torches Sidebar}
								Str(World.Info.Torches, numStr);
								VideoWriteText(72, 9, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), numStr + ' ');
								if World.Info.TorchTicks <= 0 then
									VideoWriteText(75, 9, AsColor(XDat.EDefs[E_TORCH].Color and $0F,
										XDat.Params[THEME_START]), '    ')
								else begin
									for i := 2 to 5 do begin
										if i <= ((World.Info.TorchTicks * 5) div XDat.EDefs[E_TORCH].P2) then
											VideoWriteText(
												73 + i,
												9,
												AsColor(XDat.EDefs[E_TORCH].Color and $0F,
												XDat.Params[THEME_START]),
												#177
											)
										else
											VideoWriteText(
												73 + i,
												9,
												AsColor(XDat.EDefs[E_TORCH].Color and $0F,
												XDat.Params[THEME_START]),
												#176
											);
									end;
								end;
							end;
						end;
						10: begin
							Str(World.Info.Gems, numStr);
							if XDat.Configs[66] <> '' then {Gems Sidebar}
								VideoWriteText(72, 10, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), numStr + ' ');
						end;
						11: begin
							Str(World.Info.Score, numStr);
							if XDat.Configs[67] <> '' then {Score Sidebar}
								VideoWriteText(72, 11, AsColor(XDat.Params[THEME_START + 2],
									XDat.Params[THEME_START]), numStr + ' ');
						end;
						12: if XDat.Configs[68] <> '' then {Keys Sidebar}
								for i := 1 to 7 do begin
									if Diffkeys then
										keyChar := Chr(139 + i)
									else
										keyChar := Chr(Ord(XDat.EDefs[E_KEY].Character) + (i * XDat.EDefs[E_KEY].P2));
									if World.Info.Keys[i] > 0 then begin
										if World.Info.Keys[i] = 1 then
											VideoWriteText(71 + i, 12, AsColor(8 + i,XDat.Params[THEME_START]), keyChar)
										else if World.Info.Keys[i] < 10 then
											VideoWriteText(71 + i, 12, AsColor(8 + i,XDat.Params[THEME_START]), Chr(World.Info.Keys[i] + 48))
										else 
											VideoWriteText(71 + i, 12, AsColor(8 + i,XDat.Params[THEME_START]), '*')
									end else
										VideoWriteText(71 + i, 12, AsColor(XDat.Params[THEME_START + 1],
											XDat.Params[THEME_START]), ' ');
								end;
						15: if XDat.Configs[72] <> '' then begin {Sound toggle sidebar}
								if SoundEnabled then
									VideoWriteText(65, 15, AsColor(XDat.Params[THEME_START + 1],
										XDat.Params[THEME_START]), ' ' + XDat.Configs[73])
								else
									VideoWriteText(65, 15, AsColor(XDat.Params[THEME_START + 1],
										XDat.Params[THEME_START]), ' ' + XDat.Configs[74]);
							end;
					end;
				end else SideBarClearLine(y);
			end;

{$IFDEF MSDOS}
			if DebugEnabled then begin
				Str(MemAvail, numStr);
				VideoWriteText(62, 0, $1E, 'm' + numStr + ' ');
				if ExtMemEmsActive then begin
					Str(ExtMemEmsAvailPages, numstr);
					VideoWriteText(62, 1, $1E, 'e' + numStr + 'p ');
				end;
				if ExtMemXmsActive then begin
					Str(ExtMemXmsAvail, numStr);
					VideoWriteText(62, 2, $1E, 'x' + numStr + ' ');
				end;
			end;
{$ENDIF}
		end;
	end;

procedure DisplayMessage(time: integer; message: string);
	var
		statId: integer;
	begin
		if Length(message) <> 0 then begin
			if message = '$' then begin
				Board.Stats[0].P3 := 0;
				BoardDrawRow(BOARD_HEIGHT);
			end else begin
				if Length(Board.Info.Message) > Length(message) then begin
					Board.Info.Message := message;
					BoardDrawRow(BOARD_HEIGHT);
				end else
					Board.Info.Message := message;
				Board.Stats[0].P3 := time div (TickTimeDuration + 1);
				VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, 9 + (Board.Stats[0].P3 mod 7), ' '+Board.Info.Message+' ');
			end;
		end;
	end;

procedure DamageStat(attackerStatId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[attackerStatId] do begin
			if attackerStatId = 0 then begin
				if World.Info.Health > 0 then begin
					World.Info.Health := World.Info.Health - XDat.Params[2]; {Damage}

					GameUpdateSidebar;
					DisplayMessage(100, XDat.Configs[48]); {"Ouch!"}

					if Board.Tiles[X][Y].Element = E_PLAYER then
						VideoWriteText(X-1,Y-1,$70 + World.Info.PlayerColor and $0F, World.Info.PlayerChar);

					if World.Info.Health > 0 then begin
						World.Info.BoardTimeSec := 0;
						if Board.Info.ReenterWhenZapped then begin

							{ Move player to start }
							Board.Tiles[X][Y].Element := E_EMPTY;
							BoardDrawTile(X, Y);
							oldX := X;
							oldY := Y;
							X := Board.Info.StartPlayerX;
							Y := Board.Info.StartPlayerY;
							TransitionDrawToBoard;

							if XDat.Configs[79] <> '' then
								GamePaused := true;
						end;
						SoundQueue(4, SoundParse(XDat.Configs[49])); {Ouch sound}
					end;
				end;
			end else begin
				case Board.Tiles[X][Y].Element of
					E_BULLET: SoundQueue(3, SoundParse(XDat.Configs[56])); {Breakwall sound}
					E_OBJECT: begin end;
				else
					SoundQueue(3, SoundParse(XDat.Configs[47])) {Enemy die sound}
				end;
				RemoveStat(attackerStatId);
			end;
		end;
	end;

procedure BoardDamageTile(x, y: integer);
	var
		statId: integer;
	begin
		statId := GetStatIdAt(x, y);
		if statId <> -1 then begin
			DamageStat(statId);
		end else if not XDat.EDefs[Enum(Board.Tiles[x][y].Element)].CanPut then begin
			Board.Tiles[x][y].Element := E_EMPTY;
			BoardDrawTile(x, y);
		end;
	end;

procedure BoardAttack(attackerStatId: integer; x, y: integer);
	begin
		if (attackerStatId = 0) and (World.Info.EnergizerTicks > 0) then begin
			Inc(World.Info.Score, XDat.EDefs[Enum(Board.Tiles[x][y].Element)].ScoreValue);
			GameUpdateSidebar;
		end else begin
			DamageStat(attackerStatId);
		end;

		if (attackerStatId > 0) and (attackerStatId <= CurrentStatTicked) then
			Dec(CurrentStatTicked);

		if (Board.Tiles[x][y].Element = E_PLAYER) and (World.Info.EnergizerTicks > 0) then begin
			Inc(World.Info.Score, XDat.EDefs[
				Enum(Board.Tiles[Board.Stats[attackerStatId].X][Board.Stats[attackerStatId].Y].Element)].ScoreValue);
			GameUpdateSidebar;
		end else begin
			BoardDamageTile(x, y);
		end;
	end;

procedure OopForceTile(x, y: integer; tile: TTile);
	begin
		with Board.Tiles[x][y] do begin
			if Element <> E_PLAYER then begin
				if Element = tile.Element then
					Color := tile.Color
				else begin
					BoardDamageTile(x, y);
					if XDat.EDefs[Enum(tile.Element)].Cycle >= 0 then
						AddStat(x, y, tile.Element, tile.Color,
							XDat.EDefs[Enum(tile.Element)].Cycle, StatTemplateDefault)
					else begin
						Element := tile.Element;
						Color := tile.Color;
					end;
				end;
				BoardDrawTile(x, y);
			end;
		end;
	end;

procedure OopPlaceTile(x, y: integer; var tile: TTile);
	var
		txcolor, fg, bg: byte;
	begin
		with Board.Tiles[x][y] do begin
			if (Element >= E_TEXT_MIN) and (tile.Element >= E_TEXT_MIN) then begin
				Element := tile.Element;
				if tile.Color > 0 then
					Color := tile.Color;
				BoardDrawTile(x, y);
			end else if Element <> E_PLAYER then begin
				if tile.Color and $F0 > 0 then
					bg := tile.Color div 16
				else if ElemDefColor(tile.Element) and $F0 > 0 then
					bg := ElemDefColor(tile.Element) div 16
				else if ((tile.Element = E_PASSAGE) or (tile.Element = E_DOOR)) then
					if tile.Color and $0F <> 0 then
						bg := tile.Color and $07
					else
						bg := (Color div 16) and $07
				else bg := Color div 16;

				if tile.Color > 0 then
					fg := tile.Color and $0F
				else if ElemDefColor(tile.Element) > 0 then
					fg := ElemDefColor(tile.Element) and $0F
				else fg := Color and $0F;

				if fg + bg = 0 then
					fg := 15;
				txcolor := AsColor(fg,bg);

				if Element = tile.Element then
					Color := txcolor
				else begin
					BoardDamageTile(x, y);
					if XDat.EDefs[Enum(tile.Element)].Cycle >= 0 then
						AddStat(x, y, tile.Element, txcolor,
							XDat.EDefs[Enum(tile.Element)].Cycle, StatTemplateDefault)
					else begin
						Element := tile.Element;
						Color := txcolor;
					end;
				end;
				BoardDrawTile(x, y);
			end;
		end;
	end;

function BoardShoot(txelement: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	var
		tile: TTile;
	begin
		if ((tx + deltaX) > 0)
			and ((tx + deltaX) <= BOARD_WIDTH)
			and ((ty + deltaY) > 0)
			and ((ty + deltaY) <= BOARD_HEIGHT)
		then begin
			with Board.Tiles[tx + deltaX][ty + deltaY] do begin
				if XDat.EDefs[Enum(Element)].CanPut then begin
					tile.Element := txelement;
					tile.Color := ElemDefColor(txelement);
					OopPlaceTile(tx + deltaX, ty + deltaY, tile);
					with Board.Stats[Board.StatCount] do begin
						P1 := source;
						StepX := deltaX;
						StepY := deltaY;
						P2 := XDat.EDefs[Enum(txelement)].P2; {Projectile Health}
					end;
					BoardShoot := true;
				end else if (
						(Element = E_BREAKABLE)
						or ((Element >= E_TEXT_MIN)
						and (XDat.EDefs[Enum(Element)].CanShoot))
					) or (
						XDat.EDefs[Enum(Element)].CanShoot
						and ((Element = E_PLAYER) = Boolean(source))
						and (World.Info.EnergizerTicks <= 0)
					) then
				begin
					BoardDamageTile(tx + deltaX, ty + deltaY);
					BoardShoot := true;
				end else begin
					BoardShoot := false;
				end;
			end;
		end else BoardShoot := false;
	end;

procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	begin
		deltaX := Random(3) - 1;

		if deltaX = 0 then
			deltaY := Random(2) * 2 - 1
		else
			deltaY := 0;
	end;

procedure CalcDirectionSearch(x, y, srcx, srcy, destx, desty: shortint);
	begin
		SearchArea[x][y] := 98;
		if ((srcx + x > 0) and (srcx + x <= BOARD_WIDTH)) and ((srcy + y > 0) and (srcy + y <= BOARD_HEIGHT)) then begin
			if (XDat.EDefs[Enum(Board.Tiles[x + srcx][y + srcy].Element)].Walkable) or ((x = 0) and (y = 0)) then begin
				if (x <> 0) or (y <> 0) then begin
					if x + srcx > destx then SearchArea[x][y] := (x + srcx) - destx
						else SearchArea[x][y] := destx - (x + srcx);
					if y + srcy > desty then Inc(SearchArea[x][y],(y + srcy) - desty)
						else Inc(SearchArea[x][y],desty - (y + srcy));
				end;
				if (Sqr(x) + Sqr(y) < 49) and (SearchArea[0][0] > 0) then begin
					if (x <= 0)	and (SearchArea[x - 1][y] = 99) then begin
						CalcDirectionSearch(x - 1, y, srcx, srcy, destx, desty);
						if SearchArea[x - 1][y] < SearchArea[x][y] then SearchArea[x][y] := SearchArea[x - 1][y];
					end;
					if (x >= 0)	and (SearchArea[x + 1][y] = 99)	then begin
						CalcDirectionSearch(x + 1, y, srcx, srcy, destx, desty);
						if SearchArea[x + 1][y] < SearchArea[x][y] then	SearchArea[x][y] := SearchArea[x + 1][y];
					end;
					if (y <= 0) and (SearchArea[x][y - 1] = 99) then begin
						CalcDirectionSearch(x, y - 1, srcx, srcy, destx, desty);
						if SearchArea[x][y - 1] < SearchArea[x][y] then	SearchArea[x][y] := SearchArea[x][y - 1];
					end;
					if (y >= 0) and (SearchArea[x][y + 1] = 99)	then begin
						CalcDirectionSearch(x, y + 1, srcx, srcy, destx, desty);
						if SearchArea[x][y + 1] < SearchArea[x][y] then	SearchArea[x][y] := SearchArea[x][y + 1];
					end;
				end;
			end;
		end;
	end;

procedure CalcDirectionFind(x, y: integer; var deltaX, deltaY: integer);
	var
		ix, iy: shortint;
	begin
		if Random(9) < 1 then
			CalcDirectionRnd(deltaX,deltaY)
		else begin
			for ix := -8 to 8 do
				for iy := -8 to 8 do
					SearchArea[ix][iy] := 99;
			ix := deltaX;
			iy := deltaY;
			CalcDirectionSearch(0,0,x,y,ix,iy);
			deltaX := 0;
			deltaY := 0;
			if SearchArea[-1][0] <= SearchArea[0][0] then begin
				deltaX := -1;
				SearchArea[0][0] := SearchArea[-1][0];
			end;
			if SearchArea[0][-1] <= SearchArea[0][0] then begin
				deltaY := -1;
				SearchArea[0][0] := SearchArea[0][-1];
			end;
			if SearchArea[1][0] <= SearchArea[0][0] then begin
				deltaX := 1;
				SearchArea[0][0] := SearchArea[1][0];
			end;
			if SearchArea[0][1] <= SearchArea[0][0] then
				deltaY := 1;
			if (deltaX <> 0) and (deltaY <> 0) then
				if Random(Abs(x - Board.Stats[0].X) + Abs(y - Board.Stats[0].Y)) > Abs(x - Board.Stats[0].X) then
					deltaX := 0
				else
					deltaY := 0;
		end;
	end;

procedure CalcDirectionToward(x, y: integer; var deltaX, deltaY: integer);
	var
		ix, iy: integer;
	begin
		ix := deltaX;
		iy := deltaY;
		deltaX := 0;
		deltaY := 0;
		if (Random(2) < 1) or (iy = y) then
			deltaX := Signum(ix - x);

		if deltaX = 0 then
			deltaY := Signum(iy - y);

	end;

procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	begin
		deltaX := 0;
		deltaY := 0;

		if (Random(2) < 1) or (Board.Stats[0].Y = y) then
			deltaX := Signum(Board.Stats[0].X - x);

		if deltaX = 0 then
			deltaY := Signum(Board.Stats[0].Y - y);

		if World.Info.EnergizerTicks > 0 then begin
			deltaX := -deltaX;
			deltaY := -deltaY;
		end;
	end;

procedure TransitionDrawBoardChange;
	begin
		TransitionDrawToFill(#177, $58);
		TransitionDrawToBoard;
	end;

procedure BoardEnter;
	begin
		FillChar(PathTmpBuf^, BOARD_TILE_COUNT, 0);

		Board.Info.StartPlayerX := Board.Stats[0].X;
		Board.Info.StartPlayerY := Board.Stats[0].Y;

		if (Board.Info.IsDark > 0) and MessageHintTorchNotShown then begin
			DisplayMessage(200, XDat.Configs[46]); {"Board is dark - you need to light a torch!"}
			MessageHintTorchNotShown := false;
		end;

		World.Info.BoardTimeSec := 0;
		GameUpdateSidebar;
	end;

procedure BoardPassageTeleport(x, y: integer);
	var
		oldBoard: integer;
		col: byte;
		ix, iy: integer;
		newX, newY: integer;
	begin
		col := Board.Tiles[x][y].Color;

		oldBoard := World.Info.CurrentBoard;
		BoardChange(Board.Stats[GetStatIdAt(x, y)].P3);

		newX := 0;
		for ix := 1 to BOARD_WIDTH do
			for iy := 1 to BOARD_HEIGHT do
				if (Board.Tiles[ix][iy].Element = E_PASSAGE) and (Board.Tiles[ix][iy].Color = col) then begin
					newX := ix;
					newY := iy;
				end;

		with Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y] do begin
			if Element = E_PLAYER then begin
				Element := Board.Stats[0].Under.Element;
				Color := Board.Stats[0].Under.Color;
			end;
		end;
		if newX <> 0 then begin
			Board.Stats[0].X := newX;
			Board.Stats[0].Y := newY;
		end;

		GamePaused := true;
		SoundQueue(4, SoundParse(XDat.Configs[61])); {Passage Sound}
		TransitionDrawBoardChange;
		BoardEnter;
	end;

procedure GameDebugPrompt;
	var
		input: TString50;
		i, j: integer;
		toggle: boolean;
		textWindow: TTextWindowState;
		s: string;
		ptr: pointer;
	begin
		input := '';
		SidebarClearLine(4);
		SidebarClearLine(5);

		PromptString(63, 5, AsColor(XDat.Params[THEME_START + 2],XDat.Params[THEME_START]),
			AsColor(XDat.Params[THEME_START + 1],0), 11, PROMPT_ANY, input);
		for i := 1 to Length(input) do
			input[i] := UpCase(input[i]);

		toggle := true;
		if (input[1] = '+') or (input[1] = '-') then begin
			if input[1] = '-' then
				toggle := false;
			input := Copy(input, 2, Length(input) - 1);

			if toggle = true then
				WorldSetFlag(input)
			else
				WorldClearFlag(input);
		end;

		DebugEnabled := WorldGetFlagPosition('DEBUG') >= 0;

		if input = 'HEALTH' then
			World.Info.Health := World.Info.Health + 50
		else if input = 'AMMO' then
			World.Info.Ammo := World.Info.Ammo + 5
		else if input = 'KEYS' then
			for i := 1 to 7 do Inc(World.Info.Keys[i])
		else if input = 'TORCHES' then
			World.Info.Torches := World.Info.Torches + 3
		else if input = 'TIME' then
			World.Info.BoardTimeSec := World.Info.BoardTimeSec - 30
		else if input = 'GEMS' then
			World.Info.Gems := World.Info.Gems + 5
		else if (input = 'NODMG') or (input = 'IDDQD') then
			XDat.Params[2] := 0
		else if input = 'INSPECT' then
			InspectNext := true
		else if (input = 'STATS') or (input = 'INFO') then
			GetBoardInfo
		else if input = 'FREE' then
			Board.Stats[0].P2 := 0
		else if input = 'NOZAP' then
			Board.Info.ReenterWhenZapped := false
		else if (input = 'NOCLIP') or (input = 'CLIP') then begin
			GamePaused := true;
			NoClip := not NoClip;
		end else if input = 'PATH'then begin
			ptr := PathTmpBuf;
			for j := 0 to 24 do begin
				for i := 0 to 59 do begin
					if Byte(ptr^) <> 0 then
						VideoWriteText(i,j,XDat.EDefs[E_PLAYER].Color, Chr(Byte(ptr^)));
					AdvancePointer(ptr,1);
				end;
			end;
		end else if input = 'SPEED' then begin
			SidebarPromptSlider(true, 64, 4, 'Game speed:;FS', TickSpeed);
			TickTimeDuration := TickSpeed * 2;
			SidebarClearLine(6);
		end else if input = 'FLAGS' then begin
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			textWindow.Title := 'List of Flags';
			TextWindowAppend(textWindow, '$** Flags **');
			for i := 1 to GetNumFlags do
				if WorldInfoFlags(i) <> '' then
					TextWindowAppend(textWindow, WorldInfoFlags(i));
			TextWindowAppend(textWindow, '$** Keys **');
			for i := 1 to 7 do
				if World.Info.Keys[i] > 0 then begin
					if World.Info.Keys[i] > 1 then begin
						Str(World.Info.Keys[i],s);
						TextWindowAppend(textWindow, ColorNames[i] + ' Keys: ' + s);
					end else
						TextWindowAppend(textWindow, ColorNames[i] + ' Key');
				end;
			TextWindowAppend(textWindow, '$** Custom World Parameters **');
			for i := 1 to CUSTOM_COUNTER_COUNT do
				if World.Info.CustomCounters[i] <> 0 then begin
					Str(World.Info.CustomCounters[i],s);
					TextWindowAppend(textWindow, CustomCounterList[i] + ': ' + s);
				end;
			for i := 1 to CUSTOM_FLAG_COUNT do
				if GetCustomFlag(CustomFlagList[i]) then
					TextWindowAppend(textWindow, CustomFlagList[i]);

			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end else if input = 'BOARD' then begin
			TextWindowInitState(textWindow);
			textWindow.Selectable := true;
			textWindow.Title := 'Warp To Board';
			for i := 0 to World.BoardCount do
				TextWindowAppend(textWindow, BoardNames^[i]);
			TextWindowAppend(textWindow, 'Cancel');
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			if ((textWindow.LinePos <> textWindow.LineCount) 
				and (TextWindowRejected = false))
				and (textWindow.LinePos <> (World.Info.CurrentBoard + 1))
			then begin
				BoardChange(textWindow.LinePos - 1);
				TransitionDrawToBoard;
				BoardEnter;
			end;
			TextWindowFree(textWindow);
		end else if input = 'DARK' then begin
			Board.Info.IsDark := 1 - Board.Info.IsDark;
			TransitionDrawToBoard;
		end else if input = 'ZAP' then begin
			for i := 0 to 3 do begin
				BoardDamageTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
				Board.Tiles[Board.Stats[0].X + NeighborDeltaX[i]][Board.Stats[0].Y + NeighborDeltaY[i]].Element := E_EMPTY;
				BoardDrawTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
			end;
		end;

		SoundQueue(10, SoundParse(XDat.Configs[59])); {Cheat sound}
		SidebarClearLine(4);
		SidebarClearLine(5);
		GameDrawMainSidebar;
		GameDrawCustomSidebar;
		GameUpdateSidebar;
	end;

procedure GameDrawMainSidebarElement(y: integer);
	begin
		if ((CFlagPos[8 + y] and World.Info.CustomFlags[3]) = 0) then begin
			case y of
				7: begin
					VideoWriteText(64, 7, AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]), XDat.Configs[63]); {Health Sidebar}
					if (XDat.Configs[63] <> '') then  {Sidebar player}
						VideoWriteText(62, 7, XDat.EDefs[E_PLAYER].Color, XDat.EDefs[E_PLAYER].Character);
				end;
				8: begin
					VideoWriteText(64, 8, AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]), XDat.Configs[64]); {Ammo Sidebar}
					if XDat.Configs[64] <> '' then begin {Sidebar ammo}
						if XDat.EDefs[E_AMMO].Color and $F0 = 0 then
							VideoWriteText(62, 8, AsColor(XDat.EDefs[E_AMMO].Color and $0F,
								XDat.Params[THEME_START]), XDat.EDefs[E_AMMO].Character)
						else
							VideoWriteText(62, 8, XDat.EDefs[E_AMMO].Color, XDat.EDefs[E_AMMO].Character);
					end;
				end;
				9: begin
					VideoWriteText(64, 9, AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]), XDat.Configs[65]); {Torches Sidebar}
					if XDat.Configs[65] <> '' then begin {Sidebar Torch}
						if XDat.EDefs[E_TORCH].Color and $F0 = 0 then
							VideoWriteText(
								62, 9,
								AsColor(XDat.EDefs[E_TORCH].Color and $0F,
									XDat.Params[THEME_START]),
								XDat.EDefs[E_TORCH].Character
							)
						else
							VideoWriteText(
								62, 9,
								XDat.EDefs[E_TORCH].Color,
								XDat.EDefs[E_TORCH].Character
							);
					end;
				end;
				10: begin
					if XDat.Configs[66] <> '' then begin {Sidebar Gem}
						if XDat.EDefs[E_GEM].Color = 0 then
							VideoWriteText(62, 10, AsColor(XDat.Params[THEME_START + 6],
								XDat.Params[THEME_START]), XDat.EDefs[E_GEM].Character)
						else if XDat.EDefs[E_GEM].Color and $F0 = 0 then
							VideoWriteText(62, 10, AsColor(XDat.EDefs[E_GEM].Color and $0F,
								XDat.Params[THEME_START]), XDat.EDefs[E_GEM].Character)
						else
							VideoWriteText(62, 10, XDat.EDefs[E_GEM].Color, XDat.EDefs[E_GEM].Character);
					end;
					VideoWriteText(64, 10, AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]), XDat.Configs[66]); {Gems Sidebar}
				end;
				11: VideoWriteText(64, 11, AsColor(XDat.Params[THEME_START + 2],
					XDat.Params[THEME_START]), XDat.Configs[67]); {Score Sidebar}
				12: begin
					VideoWriteText(64, 12, AsColor(XDat.Params[THEME_START + 2],
						XDat.Params[THEME_START]), XDat.Configs[68]); {Keys Sidebar}
					if XDat.Configs[68] <> '' then begin {Sidebar key}
						if XDat.EDefs[E_KEY].Color = 0 then
							VideoWriteText(62, 12, AsColor(XDat.Params[THEME_START + 1],
								XDat.Params[THEME_START]), XDat.EDefs[E_KEY].Character)
						else if XDat.EDefs[E_KEY].Color and $F0 = 0 then
							VideoWriteText(62, 12, AsColor(XDat.EDefs[E_KEY].Color and $0F,
								XDat.Params[THEME_START]), XDat.EDefs[E_KEY].Character)
						else
							VideoWriteText(62, 12, XDat.EDefs[E_KEY].Color, XDat.EDefs[E_KEY].Character);
					end;
				end;
				14: if XDat.Configs[70] <> '' then begin  {'T' Torch hotkey}
						VideoWriteText(62, 14, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 5]), ' ' + XDat.Configs[70] + ' ');
						VideoWriteText(65, 14, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), ' ' + XDat.Configs[71]);
					end;
				15: if XDat.Configs[72] <> '' then {'B' Toggle Sounds hotkey}
						VideoWriteText(62, 15, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 4]), ' ' + XDat.Configs[72] + ' ');
				16: if XDat.Configs[75] <> '' then begin {'H' Help hotkey}
						VideoWriteText(62, 16, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 5]), ' ' + XDat.Configs[75] + ' ');
						VideoWriteText(65, 16, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), ' ' + XDat.Configs[76]);
					end;
				18: if XDat.Configs[86] <> '' then begin {' Move'}
						VideoWriteText(67, 18, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 5]), ' '#24#25#26#27' ');
						VideoWriteText(72, 18, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), XDat.Configs[86]);
					end;
				19: if XDat.Configs[87] <> '' then begin {' Shoot'}
						VideoWriteText(61, 19, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 4]), XDat.Configs[88] + #24#25#26#27' ');
						VideoWriteText(72, 19, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), XDat.Configs[87]);
					end;
				21: if XDat.Configs[77] <> '' then begin {'S' Save gave hotkey}
						VideoWriteText(62, 21, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 4]), ' ' + XDat.Configs[77] + ' ');
						VideoWriteText(65, 21, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), ' ' + XDat.Configs[78]);
					end;
				22:	if NeuromotorAssist then begin
						VideoWriteText(62, 22, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 5]), ' P ');
						VideoWriteText(65, 22, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), ' Proceed')
					end else if XDat.Configs[79] <> '' then begin {'P' Pause game hotkey}
						VideoWriteText(62, 22, AsColor(XDat.Params[THEME_START + 3],
							XDat.Params[THEME_START + 5]), ' ' + XDat.Configs[79] + ' ');
						VideoWriteText(65, 22, AsColor(XDat.Params[THEME_START + 1],
							XDat.Params[THEME_START]), ' ' + XDat.Configs[80]);
					end;
				23: begin
					VideoWriteText(62, 23, AsColor(XDat.Params[THEME_START + 3],
						XDat.Params[THEME_START + 4]), ' Q ');
					VideoWriteText(65, 23, AsColor(XDat.Params[THEME_START + 1],
						XDat.Params[THEME_START]), ' Quit');
				end;
			end;
		end else SideBarClearLine(y);
	end;

procedure GameDrawMainSidebar;
	var
		i: integer;
	begin
		for i := 2 to 15 do
			GameDrawMainSidebarElement(MainSidebarList[i]);
	end;

procedure GameDrawCustomSidebar;
	var
		i, j, y, code: integer;
		m: char;
		numStr: string[8];
		disp: string[20];
	begin
		i := 0;
		{ Custom Key elements }
		while i < KeyLimit do begin
			j := 62;
			Val(KeyList[(i * 3) + 2],y,code);
			if (y > 2) and (y < 25) then begin
				if length(KeyList[i * 3]) < 4 then begin
					disp := ' ' + UpCase(KeyList[i * 3][1]) + ' ';
					Inc(j);
				end else begin
					disp := KeyList[i * 3];
					Delete(disp,1,1);
					while (Length(disp) > 1) and (disp[1] <> #39) do
						Delete(disp,1,1);
					if disp[1] = #39 then Delete(disp,1,1);
					if (disp[Length(disp)] = #39) then Delete(disp,Length(disp),1);
				end;
				if ((CFlagPos[y + 8] and World.Info.CustomFlags[3]) = 0) then begin
					VideoWriteText(62, y,
						AsColor(XDat.Params[THEME_START + 3],
						XDat.Params[THEME_START + 5 - (y mod 2)]),
						disp);
					VideoWriteText(j + Length(disp), y,
						AsColor(XDat.Params[THEME_START + 1],
						XDat.Params[THEME_START]), KeyList[(i * 3) + 1]);
				end else SideBarClearLine(y);
			end;
			Inc(i);
		end;
		{ Custom Sidebar Counters }
		for i := 3 to 24 do
			with CustomSidebar[i] do begin
				if Ident > -8 then begin
					if ((CFlagPos[i + 8] and World.Info.CustomFlags[3]) = 0) then begin
						VideoWriteText(64, i, AsColor(XDat.Params[THEME_START + 2],
							XDat.Params[THEME_START]), Disp);
						if Ident < 0 then
							Str(Board.Info.Local[-Ident], numStr)
						else
							Str(World.Info.CustomCounters[Ident], numStr);
						VideoWriteText(72, i, AsColor(XDat.Params[THEME_START + 2],
							XDat.Params[THEME_START]), numStr + ' ');
						if Elmt > -1 then {Sidebar Element}
							if XDat.EDefs[Enum(Elmt)].Color = 0 then
								VideoWriteText(62, i,
									AsColor(XDat.Params[THEME_START + 6],
									XDat.Params[THEME_START]),
									XDat.EDefs[Enum(Elmt)].Character)
							else if XDat.EDefs[Enum(Elmt)].Color and $F0 = 0 then
								VideoWriteText(62, i,
									AsColor(XDat.EDefs[Enum(Elmt)].Color and $0F,
									XDat.Params[THEME_START]),
									XDat.EDefs[Enum(Elmt)].Character)
							else
								VideoWriteText(62, i,
									XDat.EDefs[Enum(Elmt)].Color,
									XDat.EDefs[Enum(Elmt)].Character);
					end else SideBarClearLine(i);
				end;
			end;
	end;

procedure GoToDirectory(var input: string);
	var
		s, k: string;
		i: integer;
	begin
		s := '';
		k := '';
		for i := 1 to Length(input) do begin
			if Input[i] = '\' then
				s := k;
			k := k + Input[i];
		end;
		if Length(s) <> 0 then begin
			Chdir(s);
			input := Copy(input, Length(s) + 2, 12);
		end;
	end;

procedure GameDrawTheme;
	begin
		if CurrentBlink <> (XDat.Params[THEME_BLINK] = 0) then begin
			CurrentBlink := (XDat.Params[THEME_BLINK] = 0);
			SetBlink(CurrentBlink);
		end;
		SidebarClear;
		SidebarClearLine(0);
		SidebarClearLine(1);
		SidebarClearLine(2);
		VideoWriteText(61, 0, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), '    - - - - -      ');
		VideoWriteText(62, 1, AsColor(XDat.Params[THEME_START + 3],
			XDat.Params[THEME_START + 4]), '      ZZT      ');
		VideoWriteText(62, 1, AsColor(XDat.Params[THEME_START + 5],
			XDat.Params[THEME_START + 4]), ' Weave');
		if not HasINI then VideoWriteText(74, 1, AsColor(XDat.Params[THEME_START + 5],
			XDat.Params[THEME_START + 4]), '3.2');
		VideoWriteText(61, 2, AsColor(XDat.Params[THEME_START + 1],
			XDat.Params[THEME_START]), '    - - - - -      ');
		if GameStateElement = E_PLAYER then begin
			GameDrawMainSidebar;
			GameDrawCustomSidebar;
		end else if GameStateElement = E_MONITOR then begin
			if (IsRelease = false) or (IsSpeedForced = false) then begin
				VideoWriteText(62, 21, AsColor(XDat.Params[THEME_START + 3],
					XDat.Params[THEME_START + 4]), ' S ');
				SidebarPromptSlider(false, 66, 21, 'Game speed:;FS', TickSpeed);
			end else
				SpeedMenuChar := #0;

			if (IsRelease = false) or (FileIsMult = true) then begin
				VideoWriteText(62, 7, AsColor(XDat.Params[THEME_START + 3],
					XDat.Params[THEME_START + 5]), ' W ');
			end else
				WorldMenuChar := #0;

			VideoWriteText(65, 7, AsColor(XDat.Params[THEME_START + 2],
				XDat.Params[THEME_START]), ' World:');

			if (World.Info.Name <> '')
			then
				VideoWriteText(69, 8, AsColor(XDat.Params[THEME_START + 1],
					XDat.Params[THEME_START]), World.Info.Name)
			else
				VideoWriteText(69, 8, AsColor(XDat.Params[THEME_START + 1],
					XDat.Params[THEME_START]), 'Untitled');

			if PlayMenuChar = 'P' then begin
				VideoWriteText(62, 11, AsColor(XDat.Params[THEME_START + 3],
					XDat.Params[THEME_START + 4]), ' P ');
				VideoWriteText(65, 11, AsColor(XDat.Params[THEME_START + 1],
					XDat.Params[THEME_START]), ' Play');
			end;
			if ((XDat.Configs[77][1] <> #1) or (IsRelease = false)) then begin
				VideoWriteText(62, 12, AsColor(XDat.Params[THEME_START + 3],
					XDat.Params[THEME_START + 5]), ' R ');
				VideoWriteText(65, 12, AsColor(XDat.Params[THEME_START + 2],
					XDat.Params[THEME_START]), ' Restore game');
			end else
				RestoreMenuChar := #0;
			if (IsWebRelease = false) then begin
				VideoWriteText(62, 13, AsColor(XDat.Params[THEME_START + 3],
					XDat.Params[THEME_START + 4]), ' Q ');
				VideoWriteText(65, 13, AsColor(XDat.Params[THEME_START + 2],
					XDat.Params[THEME_START]), ' Quit');
			end else
				QuitMenuChar := #0;
			VideoWriteText(62, 16, AsColor(XDat.Params[THEME_START + 3],
				XDat.Params[THEME_START + 5]), ' A ');
			VideoWriteText(65, 16, AsColor(XDat.Params[THEME_START + 1],
				XDat.Params[THEME_START]), ' License Info');
			if XDat.Params[72] > 0 then begin
				VideoWriteText(62, 17, AsColor(XDat.Params[THEME_START + 3],
					XDat.Params[THEME_START + 4]), ' H ');
				VideoWriteText(65, 17, AsColor(XDat.Params[THEME_START + 2],
					XDat.Params[THEME_START]), ' High Scores');
			end else
				HighScoreChar := #0;

		end;
	end;


procedure GamePlayLoop(boardChanged: boolean);
	var
		f: file;
		exitLoop: boolean;
		pauseBlink: boolean;
	begin
		GameDrawTheme;
		GameUpdateSidebar;

		if JustStarted then begin
			if (StartupWorldFileName = '') then
				WorldCreate
			else begin
				GoToDirectory(StartupWorldFileName);
				if (FileExists(StartupWorldFileName + '.ZZT')
					and WorldLoad(StartupWorldFileName, '.ZZT'))
					or (FileExists(StartupWorldFileName)
					and WorldLoad(StartupWorldFileName,''))
				then begin
					LoadPalette;
					GameDrawTheme;
					GameUpdateSidebar;
					VideoWriteText(69, 8, AsColor(XDat.Params[THEME_START + 1],
						XDat.Params[THEME_START]), World.Info.Name);
				end;
			end;
			if (ParamStr(1) = '') and not SkipToTitle then
				GameAboutScreen;
			ReturnBoardId := World.Info.CurrentBoard;
			BoardChange(0);
			JustStarted := false;
		end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := GameStateElement;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElemDefColor(GameStateElement);

		if GameStateElement = E_MONITOR then begin
			DisplayMessage(0, '');
			VideoWriteText(62, 5, AsColor(XDat.Params[THEME_START + 6],
				XDat.Params[THEME_START]), XDat.Configs[82]); {"Pick a command:"}
		end;

		if boardChanged then
			TransitionDrawBoardChange;

		TickTimeDuration := TickSpeed * 2;
		GamePlayExitRequested := false;
		exitLoop := false;

		CurrentTick := Board.Info.BoardTicks;
		CurrentStatTicked := Board.StatCount + 1;

		repeat
			if GamePaused then begin
				if SoundHasTimeElapsed(TickTimeCounter, 25) then
					pauseBlink := not pauseBlink;

				if pauseBlink then begin
					if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1,
							XDat.EDefs[E_PLAYER].Color,XDat.EDefs[E_PLAYER].Character)
					else
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1,
							World.Info.PlayerColor, World.Info.PlayerChar);
				end else begin
					if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1, $0F, ' ')
					else
						BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
				end;

				VideoWriteText(64, 5, AsColor(XDat.Params[THEME_START + 1],
					XDat.Params[THEME_START]), XDat.Configs[81]); {"Pausing..."}
{$IFDEF SDL2}
				TimerSysIdle(IMUntilFrame);
{$ENDIF}
				InputUpdate;

				if InputKeyPressed = KEY_ESCAPE then
					GamePromptEndPlay;

				if UpCase(InputKeyPressed) = UpCase(XDat.Configs[83][1]) then begin {Cheat hotkey}
					GameDebugPrompt;
					InputKeyPressed := #0;
				end;

				{ Fix bug where the unpause movement is not taken into account for SPACE. }
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					PlayerDirX := InputDeltaX;
					PlayerDirY := InputDeltaY;
				end;

				if NoClip then begin
					if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
						with Board.Stats[0] do begin
							if Board.Tiles[X][Y].Element = E_PLAYER then
								Board.Tiles[X][Y] := Under;
							if (X + InputDeltaX > 0) and (X + InputDeltaX <= BOARD_WIDTH) then
								X := X + InputDeltaX;
							if (Y + InputDeltaY > 0) and (Y + InputDeltaY <= BOARD_HEIGHT) then
								Y := Y + InputDeltaY;
							BoardDrawTile(X, Y);
							BoardDrawTile(X - InputDeltaX, Y - InputDeltaY);
						end;
					end;
				end else begin
					if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
						XDat.EDefs[Enum(Board.Tiles[Board.Stats[0].X + InputDeltaX][Board.Stats[0].Y + InputDeltaY].Element)].TouchProc(
							Board.Stats[0].X + InputDeltaX, Board.Stats[0].Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
					end;

					if ((InputDeltaX <> 0) or (InputDeltaY <> 0))
						and XDat.EDefs[Enum(Board.Tiles[Board.Stats[0].X + InputDeltaX][Board.Stats[0].Y + InputDeltaY].Element)].Walkable
					then begin
						{ Move player }
						if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then
							MoveStat(0, Board.Stats[0].X + InputDeltaX, Board.Stats[0].Y + InputDeltaY)
						else begin
							Inc(Board.Stats[0].X, InputDeltaX);
							Inc(Board.Stats[0].Y, InputDeltaY);
							with Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y] do begin
								Board.Stats[0].Under.Element := Element;
								Board.Stats[0].Under.Color := Color;
								Element := E_PLAYER;
								BoardDrawTile(Board.Stats[0].X,Board.Stats[0].Y);
							end;
							TransitionDrawToBoard;
						end;

						{ Unpause }
						GamePaused := false;
						SidebarClearLine(5);
						GameDrawCustomSidebar;
						CurrentTick := Board.Info.BoardTicks;
						CurrentStatTicked := Board.StatCount + 1;
						if World.Info.IsSave = 0 then
							World.Info.IsSave := 1;
					end;
				end;

			end else begin { not GamePaused }
				if CurrentStatTicked <= Board.StatCount then begin
					with Board.Stats[CurrentStatTicked] do begin
						if (Cycle <> 0) and ((CurrentTick mod Cycle) = (CurrentStatTicked mod Cycle)) then
							if Board.Tiles[X][Y].Element <= MAX_ELEMENT then
								XDat.EDefs[Board.Tiles[X][Y].Element].TickProc(CurrentStatTicked);
						Inc(CurrentStatTicked);
					end;
				end;
			end;

			if (CurrentStatTicked > Board.StatCount) and not GamePlayExitRequested then begin
				if SoundHasTimeElapsed(TickTimeCounter, TickTimeDuration) then begin
					CurrentTick := Board.Info.BoardTicks;
					if CurrentTick > 420 then begin
						CurrentTick := 1;
						Board.Info.BoardTicks := 1;
					end;
					CurrentStatTicked := 0;

					InputUpdate;
				end else begin
					TimerSysIdle(IMUntilPit);
				end;
			end;
		until (exitLoop or GamePlayExitRequested) and GamePlayExitRequested;

		SoundClearQueue;

		if GameStateElement = E_PLAYER then begin
			if (World.Info.Health <= 0) and (XDat.Params[72] > 0) then begin
				HighScoresLoad;
				HighScoresAdd(World.Info.Score);
			end;
			if (HasINI and not DebugEnabled) then if WorldLoad(World.Info.Name, '.ZZT') then begin
				LoadPalette;
			end;
		end else if GameStateElement = E_MONITOR then
			SidebarClearLine(5);

		{ Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
		BoardDrawTile(Board.Stats[0].X,Board.Stats[0].Y); }

		SoundBlockQueueing := false;
	end;

procedure GameTitleLoop;
	var
		i: integer;
		boardChanged: boolean;
		startPlay: boolean;
		inputC: char;
	begin
		GameTitleExitRequested := false;
		ReturnBoardId := 0;
		boardChanged := true;
		repeat
			BoardChange(0);
			repeat
				GameStateElement := E_MONITOR;
				startPlay := false;
				GamePaused := false;
				GamePlayLoop(boardChanged);
				boardChanged := false;
				inputC := UpCase(InputKeyPressed);
				if inputC = 'W' then inputC := WorldMenuChar;
				if inputC = 'S' then inputC := SpeedMenuChar;
				if inputC = 'H' then inputC := HighScoreChar;
				if InputC = 'P' then inputC := PlayMenuChar;
				if InputC = 'R' then inputC := RestoreMenuChar;
				if QuickStart then inputC := 'P';
				if (inputC = 'Q')
					or (inputC = KEY_ESCAPE)
				then
					inputC := QuitMenuChar;

				if inputC in ['W','A','S','R','H','|','Q',#27] then SetPalette(true);
				case inputC of
					'W': 
						if GameWorldLoad('.ZZT') then begin
							ReturnBoardId := World.Info.CurrentBoard;
							boardChanged := true;
						end;
					'P': begin
						if not DebugEnabled then begin
							startPlay := WorldLoad(World.Info.Name, '.ZZT');
							LoadPalette;
							ReturnBoardId := World.Info.CurrentBoard;
						end else begin
							startPlay := true;
						end;
						if startPlay then begin
							BoardChange(ReturnBoardId);
							BoardEnter;
						end;
						KeyRepeat;
					end;
					'A': GameAboutScreen;
					'S': begin
						SidebarPromptSlider(true, 66, 21, 'Game speed:;FS', TickSpeed);
						inputC := #0;
						SetPalette(false);
					end;
					'R': begin
						if GameWorldLoad('.SAV') then begin
							ReturnBoardId := World.Info.CurrentBoard;
							BoardChange(ReturnBoardId);
							startPlay := true;
						end;
						KeyRepeat;
					end;
					'H': begin
						HighScoresLoad;
						HighScoresDisplay(1);
					end;
					'|': GameDebugPrompt;
					KEY_ESCAPE, 'Q': GameTitleExitRequested := SidebarPromptYesNo('Quit ZZT? ', true);
				end;
				if inputC in ['W','A','S','R','H','|','Q',#27] then SetPalette(false);

				if startPlay then begin
					GameStateElement := E_PLAYER;
					if (QuickStart = false) and (XDat.Configs[79] <> '') then
						GamePaused := true
					else
						QuickStart := false;
					GamePlayLoop(true);
					boardChanged := true;
				end;
			until boardChanged or GameTitleExitRequested;
		until GameTitleExitRequested;
	end;

procedure ResetCachedLinePos;
	begin
		FileWorldCachedLinePos := 1;
		FileSaveCachedLinePos := 1;
	end;

begin
end.
