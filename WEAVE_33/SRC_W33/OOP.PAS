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
unit Oop;

interface
	uses GameVars;
	const
		CFlagPos: array[1..32] of longint = (
			$00000001, $00000002, $00000004, $00000008,
			$00000010, $00000020, $00000040, $00000080,
			$00000100, $00000200, $00000400, $00000800,
			$00001000, $00002000, $00004000, $00008000,
			$00010000, $00020000, $00040000, $00080000,
			$00100000, $00200000, $00400000, $00800000,
			$01000000, $02000000, $04000000, $08000000,
			$10000000, $20000000, $40000000, -$80000000
		);
	function WorldGetFlagPosition(name: TString20): integer;
	function GetCustomFlag(name: TString20): boolean;
	procedure WorldSetFlag(name: TString20);
	procedure WorldClearFlag(name: TString20);
	procedure InspectObjectCode(statId, PointPos: integer; ErrMsg: string);
	function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	procedure OopExecute(statId: integer; name: TString50);
	function OopStringToWord(input: TString50): TString50;
	procedure OopReadValue(statId: integer; var position: integer);
	procedure GetBoardInfo;
	function GetNumFlags: integer;
	function WorldInfoFlags(flag: integer): string;

implementation
uses Sounds, TxtWind, Game, ZVideo, Elements, Counter, ObjTrack, FileSys;

procedure OopError(statId, position: integer; message: string);
	begin
		if DebugEnabled then begin
			SoundQueue(5, SoundParse(XDat.Configs[58])); {Error sound}
			InspectObjectCode(statId, position, XDat.Configs[57] + message);
			Board.Stats[statId].DataPos := -1;
		end else if XDat.Configs[57] <> '' then begin
			DisplayMessage(200, XDat.Configs[57] + message); {"ERR: "}
			SoundQueue(5, SoundParse(XDat.Configs[58])); {Error sound}
			Board.Stats[statId].DataPos := -1;
		end;
	end;

procedure OopReadChar(statId: integer; var position: integer);
	begin
		with Board.Stats[statId] do begin
			if (position >= 0) and (position < DataLen) then begin
{$IFDEF FPC}
				OopChar := Data[position];
{$ELSE}
				OopChar := Data^[position];
{$ENDIF}
				Inc(position);
			end else begin
				OopChar := #0
			end;
		end;
	end;

procedure OopReadWord(statId: integer; var position: integer);
	var
		s: string;
		wordPos: byte;
	begin
		wordPos := 0;
		repeat
			OopReadChar(statId, position);
		until OopChar <> ' ';
		OopChar := UpCase(OopChar);
		while ((OopChar >= 'A') and (OopChar <= 'Z'))
			or ((OopChar >= '0') and (OopChar <= '9'))
			or (OopChar = '_')
			or (OopChar = ':')
			or (OopChar = '-')
			or (OopChar = '^')
			or (OopChar = '\')
			or (OopChar = '.')
		do begin
			if OopChar = '^' then begin
				Str(Board.Stats[statId].ObjArray, s);
				OopWord[0] := Chr(wordPos);
				OopWord := OopWord + s;
				wordPos := Ord(OopWord[0]);
			end else if wordPos <= OOP_TOKEN_LENGTH then begin
				Inc(wordPos);
				OopWord[wordPos] := oopChar;
			end;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
		end;
		OopWord[0] := Chr(wordPos);
		if position > 0 then
			Dec(position);
	end;

function OopNextWord(statId: integer; var position: integer): string;
	var
		s: string;
		iPos: integer;
	begin
		iPos := position;
		s := OopWord;
		OopReadWord(statId, position);
		OopNextWord := OopWord;
		OopWord := s;
		position := iPos;
	end;


function OopStringToWord(input: TString50): TString50;
	var
		output: TString50;
		i: integer;
		outPos: byte;
	begin
		output := '';
		outPos := 0;
		for i := 1 to Length(input) do begin
			if ((input[i] >= 'A') and (input[i] <= 'Z'))
				or ((input[i] >= '0') and (input[i] <= '9')) then begin
				Inc(outPos);
				output[outPos] := input[i];
			end else if ((input[i] >= 'a') and (input[i] <= 'z')) then begin
				Inc(outPos);
				output[outPos] := Chr(Ord(input[i]) - $20);
			end;
		end;
		output[0] := Chr(outPos);
		OopStringToWord := output;
	end;

{OUTPUT}
procedure OopOutputTile(x, y, dx, dy: integer; tile: TTile);
	var
		s, t, q, r: string;
		i, j: integer;
	begin
		Str(x, s);
		q := s + ' ';
		t := '#PUT BY ' + s;
		Str(y, s);
		q := q + s;
		t := t + ' ' + s;
		i := 0 + tile.Color;
		Str(i, s);
		if i >= 16 then
			r := s
		else
			r := s + ' 0';
		t := t + ' ' + r;
		if tile.Element > MAX_ELEMENT then begin
			Str(tile.Element,s);
			t := t + ' TEXT ' + s;
		end else begin
			s := XDat.EDefs[tile.Element].name;
			t := t + ' ' + s;
			if tile.Element = E_OBJECT then begin
				Str(Board.Stats[GetStatIdAt(dx + x, dy + y)].P1,s);
				t := '#PUT BY ' + q + ' 0 OBJECT';
				t := t + #13 + '#PSET BY ' + q + ' P1 ' + s;
				t := t + #13 + '#COLOR BY ' + q + ' ' + r;
			end;
		end;
		t := t + #13;
		for j := 1 to Length(t) do begin
			Char(OutTmpPos^) := t[j];
			AdvancePointer(OutTmpPos, 1);
		end;
	end;

{OUTPUT}
procedure XOut(s: TString50);
	var
		f: text;
		t: string;
		j: integer;
	begin
		Char(OutTmpPos^) := #13;
		AdvancePointer(OutTmpPos, 1);
		Char(OutTmpPos^) := #13;
		AdvancePointer(OutTmpPos, 1);
		Char(OutTmpPos^) := #13;
		OutTmpPos := ObjTmpBuf;
		AssignFSysText(f, s + '.OBJ');
		Rewrite(f);
		if IOResult = 0 then begin
			j := 0;
			while (j < 2) do begin
				Inc(j);
				t := '';
				while Char(OutTmpPos^) <> #13 do begin
					j := 0;
					t := t + Char(OutTmpPos^);
					AdvancePointer(OutTmpPos, 1);
				end;
				AdvancePointer(OutTmpPos, 1);
				if (j = 0) then Writeln(f, t);
			end;
			OutTmpPos := ObjTmpBuf;
		end;
		Close(f);
	end;

function OopRunFunc(statId: integer; var position: integer): integer;
	var
		ix, iy, qpos: integer;
		labelPtr: pointer;
		tmpcond: boolean;
	begin
		OopReadWord(statId, position);
		OopFuncReturn := -1;
		with TrackPushStat(statId)^ do begin
			tmpcond := Stat^.elseCheck;
			ix := Stat^.DataPos;
			if OopWord[1] = ':' then begin
				Delete(OopWord, 1, 1);
				if OopSend(Index, OopWord, true) then
					OopExecute(Index,'%%Function');
			end else begin
				labelPtr := Stat^.Data;
				iy := Stat^.DataLen;
				Stat^.Data := nil;
				Stat^.DataLen := 0;
				if FileLoadStatData(OopWord,Index) then begin
					OopExecute(Index,'%%Function');
					FreeMem(Stat^.Data,Stat^.DataLen);
				end else 
					OopError(Index,position, 'File not found ' + OopWord + '.OBJ');
				Stat^.Data := labelPtr;
				Stat^.DataLen := iy;
			end;
			Stat^.elseCheck := tmpcond;
			Stat^.DataPos := ix;
		end;
		TrackPopStat;
		GameUpdateSidebar;
		OopRunFunc := OopFuncReturn;
	end;

function OopRunFuncWith(statId: integer; var position: integer; var arg: integer): integer;
	var
		tempArg: integer;
	begin
		tempArg := GlobalArg;
		GlobalArg := arg;
		OopRunFuncWith := OopRunFunc(statId, position);
		GlobalArg := tempArg;
	end;

function MatchTiles(sourceTile: TTile; searchTile: TMatchTile): boolean;
	begin
		MatchTiles := false;
		if (sourceTile.Element = searchTile.Element) or (searchTile.Element = 2) then
			if (searchTile.Color <> 0) or (searchTile.SetFG = true) then begin
				if (searchTile.Color and $F0 > 0) or (searchTile.SetBG = true) then
					MatchTiles := (searchTile.Color = sourceTile.Color)
				else
					MatchTiles := (searchTile.Color = (sourceTile.Color and $0F));
			end else
				MatchTiles := true;
	end;

function FindTileOnBoard(var x, y: integer; tile: TMatchTile): boolean;
	begin
		FindTileOnBoard := false;
		while true do begin
			x := x + 1;
			if x > BOARD_WIDTH then begin
				x := 1;
				y := y + 1;
				if y > BOARD_HEIGHT then
					exit;
			end;

			if MatchTiles(Board.Tiles[x][y],tile) then begin
				FindTileOnBoard := true;
				exit;
			end;
		end;
	end;

function OopGetColor(statId: integer; var position: integer; var tile: TMatchTile): integer;
	var 
		i, j, p: integer;
		doFind: boolean;
	begin
		doFind := (OopWord <> 'TEXT');
		OopGetColor := -1;
		p := position;
		OopReadWord(statId, position);
		if OopWord = 'AMMO' then begin
			position := p;
			exit;
		end;
		i := ColorNumber(OopWord, statId);
		if i < 0 then begin
			position := p;
			exit;
		end;
		if (i = 0) and doFind then tile.setFG := true;
		j := 0;
		if i < 16 then begin
			p := position;
			OopReadWord(statId, position);
			if OopWord = 'AMMO' then begin
				OopGetColor := i;
				tile.Color := AsColor(i, 0);
				position := p;
				exit;
			end;
			j := ColorNumber(OopWord, statId) mod 16;
			if (j = 0) and doFind then
				tile.SetBG := true
			else if j < 0 then begin
				j := 0;
				position := p;
			end;
		end;
		if i < 256 then begin
			OopGetColor := i + (j * 16);
			tile.Color := AsColor(i, j);
		end;
	end;

function OopParseTile(var statId, position: integer; var tile: TMatchTile): boolean;
	var
		i, elem: integer;
		tmpTile: TMatchTile;
	begin
		elem := -1;
		OopParseTile := false;
		tile.Color := 0;
		tile.setBG := false;
		tile.setFG := false;

		i := OopGetColor(statId, position, tile);
		OopReadWord(statId, position);
		if OopWord = 'TEXT' then begin
			i := OopGetColor(statId, position, tmpTile);
			if i < 0 then exit;
			elem := 128 + (i mod 128);
		end else 
			for i := 0 to MAX_ELEMENT do
				if OopWord = XDat.EDefs[i].Name then elem := i;

		if elem < 0 then exit;
		OopParseTile := true;
		tile.Element := elem;
	end;

function OopParseDirection(statId: integer; var position: integer; var dx, dy: integer): boolean;
	var
		ix, iy: integer;
		q: string;
		argTile: TMatchTile;
	begin
		SelUnder := false;
		with Board.Stats[statId] do begin
			OopParseDirection := true;
			if OopWord = 'PLAYER' then begin
				dx := Board.Stats[0].X - X;
				dy := Board.Stats[0].Y - Y;
			end else if
				(OopWord = 'BY') {}
				or (OopWord = 'AT') {}
				or (OopWord = 'TOWARD') {}
			then begin
				OopReadValue(statId, position);
				dx := OopValue;
				OopReadValue(statId, position);
				dy := OopValue;
				if ((dx <> -32767) and (dy <> -32767)) then begin
					if (OopWord = 'AT') then begin 
						dx := dx - X;
						dy := dy - Y;
					end;
					if (OopWord = 'TOWARD') then 
						CalcDirectionToward(X, Y, dx, dy);
				end else begin
					dx := 0;
					dy := 0;
					OopParseDirection := false;
				end;
			end else if (OopWord = 'N') or (OopWord = 'NORTH') then begin
				dx := 0;
				dy := -1;
			end else if (OopWord = 'S') or (OopWord = 'SOUTH') then begin
				dx := 0;
				dy := 1;
			end else if (OopWord = 'E') or (OopWord = 'EAST') then begin
				dx := 1;
				dy := 0;
			end else if (OopWord = 'W') or (OopWord = 'WEST') then begin
				dx := -1;
				dy := 0;
			end else if (OopWord = 'I') or (OopWord = 'IDLE') then begin
				dx := 0;
				dy := 0;
			end else if (OopWord = 'SEEK') then begin
				CalcDirectionSeek(X, Y, dx, dy);
			end else if (OopWord = 'FLOW') then begin
				dx := StepX;
				dy := StepY;
			end else if (OopWord = 'RND') then begin
				CalcDirectionRnd(dx, dy)
			end else if (OopWord = 'RNDNS') then begin
				dx := 0;
				dy := Random(2) * 2 - 1;
			end else if (OopWord = 'RNDNE') then begin
				dx := Random(2);
				if dx = 0 then dy := -1 else dy := 0;
			end else if (OopWord = 'UNDER') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				SelUnder := true;
			end else if (OopWord = 'CW') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				dx := -dx;
			end else if (OopWord = 'CCW') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				dy := -dy;
			end else if (OopWord = 'RNDP') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				if Random(2) = 0 then
					dx := -dx
				else
					dy := -dy;
			end else if (OopWord = 'OPP') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				dx := -dx;
				dy := -dy;
			end else if (OopWord = 'FIND') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				Inc(dx,X);
				Inc(dy,Y);
				CalcDirectionFind(X, Y, dx, dy);
			end else if (OopWord = 'PFIND') then begin
				ix := 0;
				iy := 1;
				dx := 0;
				dy := 0;
				if OopParseTile(statId, position, argTile) then begin
					if FindTileOnBoard(ix, iy, argTile) then begin
						dx := ix - X;
						dy := iy - Y;
					end;
				end else
					OopParseDirection := false;
			end else if (OopWord = 'TO') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				ix := dx;
				iy := dy;
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				Inc(dx,ix);
				Inc(dy,iy);
			end else begin
				dx := 0;
				dy := 0;
				OopParseDirection := false;
			end;
		end;
	end;

procedure OopReadDirection(statId: integer; var position: integer; var dx, dy: integer);
	begin
		OopReadWord(statId, position);
		if not OopParseDirection(statId, position, dx, dy) then
			OopError(statId,position, 'Bad direction ' + OopWord);
	end;

procedure OopReadDirectionRel(statId: integer; var position: integer; var dx, dy: integer;
	ix, iy: integer; textLine: string);
	begin
		if (textLine = 'FIND') then begin
			OopReadWord(statId, position);
			OopReadDirection(statId, position, dx, dy);
			Inc(dx,Board.Stats[statId].X);
			Inc(dy,Board.Stats[statId].Y);
			CalcDirectionFind(ix, iy, dx, dy);
		end else if (textLine = 'TOWARD') then begin
			OopReadWord(statId, position);
			OopReadValue(statId, position);
			dx := OopValue;
			OopReadValue(statId, position);
			dy := OopValue;
			if ((dx <> -32767) and (dy <> -32767)) then
				CalcDirectionToward(ix, iy, dx, dy)
			else begin
				dx := 0;
				dy := 0;
				OopError(statId, position, 'Bad direction TOWARD');
			end;
		end else begin
			OopReadDirection(statId, position, dx, dy);
			if (textLine = 'AT') then begin
				Dec(dx,ix - Board.Stats[statId].X);
				Dec(dy,iy - Board.Stats[statId].Y);
			end;
		end;
	end;

function OopPget(statId: integer; var position: integer): integer;
	var
		deltaX, deltaY, bindStatId, shift: integer;
		counter: TCounter;
		argTile: TTile;
		filter: byte;
	begin
		filter := $00;
		shift := 1;
		OopReadWord(statId, position);
		OopPGet := -32767;
		if OopParseDirection(statId, position, deltaX, deltaY) then begin
			argTile := Board.Tiles[Board.Stats[statId].X + deltaX][Board.Stats[statId].Y + deltaY];
			bindStatId := GetStatIdAt(Board.Stats[statId].X + deltaX, Board.Stats[statId].Y + deltaY);
			if SelUnder and (bindStatId > -1) then begin
				argTile := Board.Stats[bindStatId].Under;
				bindStatId := -1;
			end;
			OopReadWord(statId, position);
			if OopWord = 'COLOR' then
				filter := $FF
			else if OopWord = 'FG' then
				filter := $0F
			else if OopWord = 'BG' then begin
				filter := $F0;
				shift := 16;
			end;
			if filter <> $00 then begin				
				if argTile.Element > 127 then
					OopPget := Ord((argTile.Element - 128) and filter) div shift
				else if argTile.Element >= E_TEXT_MIN then
					OopPget := Ord(XDat.EDefs[Enum(argTile.Element)].Color and filter) div shift
				else
					OopPget := Ord(argTile.Color and filter) div shift;
				exit;
			end else if OopWord = 'CHAR' then begin
				if (bindStatId > -1) and (argTile.Element = E_OBJECT) then
					OopPget := Board.Stats[bindStatId].P1
				else if argTile.Element >= E_TEXT_MIN then
					OopPget := argTile.Color
				else
					OopPget := Ord(XDat.EDefs[Enum(argTile.Element)].Character);
				exit;
			end else if bindStatId > -1 then with Board.Stats[bindStatId] do begin
				if OopWord = 'STEPX' then
					OopPget := StepX
				else if OopWord = 'STEPY' then
					OopPget := StepY
				else if (OopWord = 'P1') or (OopWord = 'INTEL') or (OopWord = 'INTELLIGENCE') then
					OopPget := P1
				else if (OopWord = 'P2') or (OopWord = 'RATE') or (OopWord = 'SPEED') or (OopWord = 'LOCKED') then
					OopPget := P2
				else if (OopWord = 'P3') or (OopWord = 'DESTINATION') then
					OopPget := P3
				else if OopWord = 'CYCLE' then
					OopPget := Cycle
				else if CounterFromWord(counter, bindStatId, OopWord) then begin
					CounterReadValue(counter);
					OopPget := counter.Value;
				end;
			end;
		end else
			OopError(statId,position, 'Bad direction ' + OopWord);
	end;

procedure OopReadValue(statId: integer; var position: integer);
	var
		s: string[20];
		wordPos: byte;
		t: string;
		ix, iy, code: integer;
		isNumeric: boolean;
		counter: TCounter;
		tmpCond: boolean;
	begin
		wordPos := 0;
		repeat
			OopReadChar(statId, position)
		until OopChar <> ' ';

		OopChar := UpCase(OopChar);
		isNumeric := true;
		while ((OopChar >= 'A') and (OopChar <= 'Z'))
			or ((OopChar >= '0') and (OopChar <= '9'))
			or (OopChar = '-')
			or (OopChar = '^')
			or (OopChar = '.')
			or (OopChar = '_')
		do begin
			if (((OopChar < '0') or (OopChar > '9'))
				and (OopChar <> '-')) and (OopChar <> '^')
			then
				isNumeric := false;
			if OopChar = '^' then begin
				Str(Board.Stats[statId].ObjArray, t);
				s[0] := Chr(wordPos);
				s := s + t;
				wordPos := Ord(s[0]);
			end else if wordPos <= OOP_TOKEN_LENGTH then begin
				Inc(wordPos);
				s[wordPos] := oopChar;
			end;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
		end;

		s[0] := Chr(wordPos);
		if position > 0 then
			Dec(position);

		OopValue := -32767;
		if Length(s) <> 0 then begin
			if isNumeric then
				Val(s, OopValue, code)
			else if HasINI and (s = 'RANDOM') then begin
				OopReadValue(statId, position);
				if OopValue <> -32767 then begin
					ix := OopValue;
					OopReadValue(statId, position);
					if OopValue <> -32767 then begin
						iy := OopValue;
						if ix > iy then
							OopValue := Random((ix - iy) + 1) + iy
						else if iy > ix then
							OopValue := Random((iy - ix) + 1) + ix
						else
							OopValue := ix;
					end;
				end;
			end else if s = 'TRUE' then
				OopValue := 1
			else if s = 'FALSE' then
				OopValue := 0
			else if s = 'PGET' then begin
				s := OopWord;
				OopValue := OopPget(statId, position);
				OopWord := s;
			end else if s = 'RUN' then begin
				s := OopWord;
				OopValue := OopRunFunc(statId, position);
				OopWord := s;
			end else if s = 'RUNWITH' then begin
				s := OopWord;
				OopReadValue(statId, position);
				if OopValue <> -32767 then begin
					ix := OopValue;
					OopValue := OopRunFuncWith(statId, position, ix);
				end;
				OopWord := s;
			end else if CounterFromWord(counter, statId, s) then begin
				CounterReadValue(counter);
				OopValue := counter.Value;
			end else OopValue := ColorNumber(s, -1);
		end;
	end;

procedure OopSkipLine(statId: integer; var position: integer);
	begin
		repeat
			OopReadChar(statId, position);
		until (OopChar = #0) or (OopChar = #13);
	end;

function OopFindString(statId, searchDir: integer; s: string): integer;
	var
		pos, wordPos, cmpPos, revPos: integer;
		maxPos: integer;
	label NoMatch;
	begin
		for pos := 1 to Length(s) do
			s[pos] := UpCase(s[pos]);
		with Board.Stats[statId] do begin
			pos := 0;
			revPos := -1;
			maxPos := DataLen - Length(s);
			while pos <= maxPos do begin
				wordPos := 1;
				cmpPos := pos;
				repeat
{$IFDEF FPC}
					OopChar := Data[cmpPos];
{$ELSE}
					OopChar := Data^[cmpPos];
{$ENDIF}
					if s[wordPos] <> UpCase(OopChar) then
						goto NoMatch;
					Inc(wordPos);
					Inc(cmpPos);
				until wordPos > Length(s);

				{ string matches }
				OopReadChar(statId, cmpPos);
				OopChar := UpCase(OopChar);

				if ((OopChar >= 'A') and (OopChar <= 'Z'))
					or ((OopChar >= '0') and (OopChar <= '9'))
					or (OopChar = '_') or (OopChar = '-')
				then begin
					{ word continues, match invalid }
				end else begin
					{ word complete, match valid }
					if (searchDir > 0) then begin
						OopFindString := pos;
						exit;
					end else
						revPos := pos;
				end;

			NoMatch:
				Inc(pos);
			end;
			OopFindString := revPos;
		end;
	end;

function OopIterateStat(statId: integer; var iStat: integer; lookup: string): boolean;
	var
		pos: integer;
		found: boolean;
	begin
		iStat := iStat + 1;
		found := false;

		if lookup = 'ALL' then begin
			if iStat <= Board.StatCount then
				found := true;
		end else if lookup = 'OTHERS' then begin
			if iStat <= Board.StatCount then begin
				if iStat <> statId then
					found := true
				else begin
					iStat := iStat + 1;
					found := (iStat <= Board.StatCount);
				end;
			end;
		end else if lookup = 'SELF' then begin
			if (statId > 0) and (iStat <= statId) then begin
				iStat := statId;
				found := true;
			end;
		end else begin
			while (iStat <= Board.StatCount) and not found do begin
				if Board.Stats[iStat].Data <> nil then begin
					pos := 0;
					OopReadChar(iStat, pos);
					if OopChar = '@' then begin
						OopReadWord(iStat, pos);
						if OopWord = lookup then
							found := true;
					end;
				end;

				if not found then
					iStat := iStat + 1;
			end;
		end;

		OopIterateStat := found;
	end;

function OopFindLabel(
	statId, searchDir: integer;
	sendLabel: string;
	var iStat, iDataPos: integer;
	labelPrefix: string
): boolean;
	var
		targetSplitPos: integer;
		targetLookup: string[20];
		objectMessage: string[20];
		foundStat: boolean;
	label FindNextStat;
	begin
		foundStat := false;
		targetSplitPos := Pos(':', sendLabel);
		if targetSplitPos <= 0 then begin
			{ if there is no target, we only check statId }
			if iStat < statId then begin
				objectMessage := sendLabel;
				iStat := statId;
				targetSplitPos := 0;
				foundStat := true;
			end;
		end else begin
			targetLookup := Copy(sendLabel, 1, targetSplitPos - 1);
			objectMessage := Copy(sendLabel, targetSplitPos + 1, Length(sendLabel) - targetSplitPos);
		FindNextStat:
			foundStat := OopIterateStat(statId, iStat, targetLookup);
		end;

		if foundStat then begin
			if objectMessage = 'RESTART' then begin
				iDataPos := 0;
			end else if HasINI and (objectMessage = 'END') then
				iDataPos := Board.Stats[iStat].DataLen
			else begin
				iDataPos := OopFindString(iStat, searchDir, labelPrefix + objectMessage);
				{ if lookup target exists, there may be more stats }
				if (iDataPos < 0) and (targetSplitPos > 0) then
					goto FindNextStat;
			end;
			foundStat := iDataPos >= 0;
		end;

		OopFindLabel := foundStat;
	end;

function WorldGetBoardPosition(statId: integer; var position: integer): integer;
	var
		zpos, bpos, ix, iy: integer;
	begin
		ix := 0;
		zpos := position;
		bpos := -1;
		OopReadWord(statId, position);
		if length(OopWord) < 1 then begin
			WorldGetBoardPosition := -32767;
			exit;
		end;
		while ((ix <= World.BoardCount) and (bpos = -1)) do begin
			if BoardNames^[ix][1] = ':' then begin
				bpos := ix;
				for iy := 1 to Length(OopWord) do
					if UpCase(BoardNames^[ix][iy + 1]) <> OopWord[iy] then
						bpos := -1;
					if (((BoardNames^[ix][Length(OopWord) + 2] >= 'A') and
						(BoardNames^[ix][Length(OopWord) + 2] <= 'Z')) or
						((BoardNames^[ix][Length(OopWord) + 2] >= '0') and
						(BoardNames^[ix][Length(OopWord) + 2] <= '9'))) then
						bpos := -1;
			end;
			Inc(ix);
		end;
		if bpos = -1 then begin
			position := zpos;
			OopReadValue(statId, position);
			WorldGetBoardPosition := OopValue;
		end else
			WorldGetBoardPosition := bpos;
	end;

function GetNumFlags: integer;
	begin
		if (XDat.Params[22] = 1) then
			GetNumFlags := 99
		else
		GetNumFlags := 10;
	end;

function WorldInfoFlags(flag: integer): string;
	begin
		if flag > MAX_FLAG then
			WorldInfoFlags := XDat.Flags[flag]
		else
			WorldInfoFlags := World.Info.Flags[flag];
	end;

function WorldGetFlagPosition(name: TString20): integer;
	var
		i: integer;
	begin
		WorldGetFlagPosition := -1;
		for i := 1 to GetNumFlags do begin
			if WorldInfoFlags(i) = name then
				WorldGetFlagPosition := i;
		end;
	end;

function CustomGetFlagPosition(name: TString20): integer;
	var
		i: integer;
	begin
		CustomGetFlagPosition := -1;
		for i := 1 to CUSTOM_FLAG_COUNT do
			if CustomFlagList[i] = name then CustomGetFlagPosition := i;
	end;

function GetCustomFlag(name: TString20): boolean;
	var
		i,j,k: integer;
	begin
		GetCustomFlag := false;
		k := CustomGetFlagPosition(name) - 1;
		if k >= 0 then begin
			j := k div 32;
			i := (k mod 32) + 1;
			if ((CFlagPos[i] and World.Info.CustomFlags[j]) <> 0) then
				GetCustomFlag := true;
		end;
	end;

function CustomSetFlag(name: TString20): boolean;
	var
		i,j,k: integer;
	begin
		CustomSetFlag := false;
		k := CustomGetFlagPosition(name) - 1;
		if k >= 0 then begin
			CustomSetFlag := true;
			j := k div 32;
			i := (k mod 32) + 1;
			if ((CFlagPos[i] and World.Info.CustomFlags[j]) = 0) then
				Inc(World.Info.CustomFlags[j], CFlagPos[i]);
			if (k >= (CUSTOM_FLAG_COUNT - 22)) then begin
				GameDrawMainSidebar;
				GameDrawCustomSidebar;
			end;
		end;
	end;

procedure WorldSetFlag(name: TString20);
	var
		i: integer;
	begin
		if not CustomSetFlag(name) then begin
			if WorldGetFlagPosition(name) < 0 then begin
				i := 1;
				while (i < GetNumFlags) and (Length(WorldInfoFlags(i)) <> 0) do
					i := i + 1;
				if i > MAX_FLAG then
					XDat.Flags[i] := name
				else
					World.Info.Flags[i] := name;
			end;
		end;
	end;

function CustomClearFlag(name: TString20): boolean;
	var
		i,j,k: integer;
	begin
		CustomClearFlag := false;
		k := CustomGetFlagPosition(name) - 1;
		if k >= 0 then begin
			CustomClearFlag := true;
			j := k div 32;
			i := (k mod 32) + 1;
			if ((CFlagPos[i] and World.Info.CustomFlags[j]) <> 0) then
				Dec(World.Info.CustomFlags[j], CFlagPos[i]);
			if (k >= (CUSTOM_FLAG_COUNT - 22)) then begin
				GameDrawMainSidebar;
				GameDrawCustomSidebar;
			end;
		end;
	end;

procedure WorldClearFlag(name: TString20);
	var
		i: integer;
	begin
		if not CustomClearFlag(name) then begin
			i := WorldGetFlagPosition(name);
			if (i > 0) then begin
				if i > MAX_FLAG then
					XDat.Flags[i] := ''
				else
					World.Info.Flags[i] := '';
			end;
		end;
	end;

function OopCheckCondition(statId: integer; var position: integer): boolean;
	var
		deltaX, deltaY: integer;
		tile: TMatchTile;
		code, ix, iy: integer;
		isCounter: boolean;
		counter: TCounter;
	begin
		with Board.Stats[statId] do begin
			if OopWord = 'NOT' then begin
				OopReadWord(statId, position);
				OopCheckCondition := not OopCheckCondition(statId, position);
			end else if (OopWord = 'ALLIGNED') or (OopWord = 'ALIGNED') then
				OopCheckCondition := (X = Board.Stats[0].X) or (Y = Board.Stats[0].Y)
			else if OopWord = 'CONTACT' then
				OopCheckCondition := (Sqr(X - Board.Stats[0].X) + Sqr(Y - Board.Stats[0].Y)) = 1
			else if OopWord = 'BLOCKED' then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				if ((X + deltaX) > 0)
					and ((X + deltaX) <= BOARD_WIDTH)
					and ((Y + deltaY) > 0)
					and ((Y + deltaY) <= BOARD_HEIGHT)
				then
					OopCheckCondition := not XDat.EDefs[Enum(Board.Tiles[X + deltaX][Y + deltaY].Element)].Walkable
				else
					OopCheckCondition := true;
			end else if OopWord = 'ANY' then begin
				if not OopParseTile(statId, position, tile) then
					OopError(statId,position, 'Bad object kind');
				ix := 0;
				iy := 1;
				OopCheckCondition := FindTileOnBoard(ix, iy, tile);
			end else if HasINI then begin
				if OopWord = 'COLOR' then begin
					OopReadDirection(statId, position, deltaX, deltaY);
					if ((X + deltaX) > 0)
						and ((X + deltaX) <= BOARD_WIDTH)
						and ((Y + deltaY) > 0)
						and ((Y + deltaY) <= BOARD_HEIGHT)
					then begin
						{read X value}
						OopReadValue(statId, position);
						ix := OopValue;
						if ix = 0 then
							tile.setFG := true
						else
							tile.setFG := false;
						{read Y value, if present. If not a detected color, reset code position.}
						code := position;
						OopReadValue(statId, position);
						if OopValue = 0 then
							tile.setBG := true
						else
							tile.setBG := false;
						if OopValue = -32767 then begin
							position := code;
							OopValue := 0;
						end;
						iy := OopValue;
						{if it's within range, make the color check.}
						if (ix + (iy * 16) > -1) and (ix + (iy * 16) < 256) then begin
							tile.Element := 2;
							tile.Color := AsColor( ix, iy );

							if SelUnder and (GetStatIdAt(X + deltaX,Y + deltaY) > -1) then
								OopCheckCondition := MatchTiles(Board.Stats[GetStatIdAt(X + deltaX,Y + deltaY)].Under, tile)
							else
								OopCheckCondition := MatchTiles(Board.Tiles[X + deltaX][Y + deltaY], tile);
						end else OopError(statId,position,'Unknown color');
					end else OopCheckCondition := false;
				end else if OopWord = 'DETECT' then begin
					OopReadDirection(statId, position, deltaX, deltaY);
					if not OopParseTile(statId, position, tile) then
						OopError(statId,position, 'Bad object kind');
					if ((X + deltaX) > 0)
						and ((X + deltaX) <= BOARD_WIDTH)
						and ((Y + deltaY) > 0)
						and ((Y + deltaY) <= BOARD_HEIGHT)
					then begin
						if SelUnder and (GetStatIdAt(X + deltaX,Y + deltaY) > -1) then
							OopCheckCondition := MatchTiles(Board.Stats[GetStatIdAt(X + deltaX,Y + deltaY)].Under, tile)
						else
							OopCheckCondition := MatchTiles(Board.Tiles[X + deltaX][Y + deltaY], tile);
					end else OopCheckCondition := false;
				end else if OopWord = 'RND' then
					OopCheckCondition := Random(2) = 0
				else if OopWord = 'AT' then begin
					OopReadValue(statId, position);
					ix := OopValue;
					OopReadValue(statId, position);
					iy := OopValue;
					if ((ix <> -32767) and (iy <> -32767)) then
						OopCheckCondition := (X = ix) and (Y = iy)
					else
						OopError(statId,position, 'Bad condition');
				end else if OopWord = 'PGET' then
					OopCheckCondition := OopPget(statId, position) > 0
				else if OopWord = 'RUN' then
					OopCheckCondition := OopRunFunc(statId, position) > 0
				else if OopWord = 'RUNWITH' then begin
					OopReadValue(statId, position);
					if OopValue <> -32767 then 
						OopCheckCondition := OopRunFuncWith(statId, position, OopValue) > 0
					else
						OopError(statId,position, 'Could not read ' + OopWord + ' value');
				end else if OopWord = 'WITHIN' then begin
					OopReadValue(statId, position);
					OopCheckCondition := ((Sqr(Board.Stats[0].X - x) + Sqr(Board.Stats[0].Y - y) * 7 / 4) <= (Sqr(OopValue)));
				end else if CounterFromWord(counter, statId, OopWord) then begin
					CounterReadValue(counter);
					iy := counter.Value;
					ix := position;
					OopReadWord(statId, position);
					if (OopWord = 'ABOVE') or ((OopWord = 'BELOW') or (OopWord = 'IS')) then begin
						code := position;
						OopReadValue(statId, position);
						if OopValue = -32767 then
							OopError(statId,position, 'Could not read ' + OopWord + ' value');
					end;
					if (OopWord = 'ABOVE') then
						OopCheckCondition := (iy > OopValue)
					else if (OopWord = 'BELOW') then
						OopCheckCondition := (iy < OopValue)
					else if (OopWord = 'IS') then
						OopCheckCondition := (iy = OopValue)
					else begin
						position := ix;
						OopCheckCondition := (iy > 0);
					end;
				end else
					if GetCustomFlag(OopWord) then
						OopCheckCondition := true
					else
						OopCheckCondition := WorldGetFlagPosition(OopWord) > 0;
			end else
				OopCheckCondition := WorldGetFlagPosition(OopWord) > 0;
		end;
	end;

function OopReadLineToEnd(statId: integer; var position: integer) : string;
	var
		s,t: string;
	begin
		s := '';
		OopReadChar(statId, position);
		while (OopChar <> #0) and (OopChar <> #13) do begin
			if (OopChar <> '^') or (Board.Stats[statId].ObjArray = 0) then
				s := s + OopChar
			else begin
				Str(Board.Stats[statId].ObjArray, t);
				s := s + t;
			end;
			OopReadChar(statId, position);
		end;
		OopReadLineToEnd := s;
	end;

procedure GetBoardInfo;
	var
		i: integer;
		s, t: string;
		textWindow: TTextWindowState;
	begin
		with Board.Info do begin
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			{ TextWindowAppend(textWindow, '$** Key Binds: **');
			Str(KeyLimit,s);
			TextWindowAppend(textWindow, 'Key Limit: ' + s);
			for i := 1 to CUSTOM_KEY_COUNT do begin
				Str(i,s);
				TextWindowAppend(textWindow, 'Key Slot ' + s + ': ' + KeyList[i]);
			end; }
			TextWindowAppend(textWindow, '$** Board Info: **');
			s := 'Board is: ';
			if IsDark > 0 then
				s := s + 'Dark, '
			else
				s := s + 'Not Dark, ';
			if ReenterWhenZapped then
				s := s + 'Zappy'
			else
				s := s + 'Not Zappy';
			TextWindowAppend(textWindow, s);
			Str(StartPlayerX,t);
			Str(StartPlayerY,s);
			TextWindowAppend(textWindow, 'Re-enter at: ' + t + ', ' + s);
			if MaxShots < 0 then
				TextWindowAppend(textWindow, 'Max Shots: Unlimited')
			else if MaxShots = 0 then
				TextWindowAppend(textWindow, 'Shooting disabled on this board')
			else begin
				Str(MaxShots,s);
				TextWindowAppend(textWindow, 'Max Shots: ' + s);
			end;
				Str(TimeLimitSec,s);
				Str(TimeLimitSec - World.Info.BoardTimeSec,t);
			if (TimeLimitSec > 0) and (World.Info.BoardTimeSec >= 0) then
				TextWindowAppend(textWindow, 'Time: ' + t + 's remains of ' + s + 's limit')
			else 
				TextWindowAppend(textWindow, 'No time limit (TIMELIMIT counter: ' + s + ')');
			Str(World.Info.BoardTimeSec,s);
			TextWindowAppend(textWindow, 'TIME Counter: ' + s);
			Str(Board.StatCount, s);
			TextWindowAppend(textWindow, 'Stat Count: ' + s);
			Str(World.Info.PlayerColor, s);
			TextWindowAppend(textWindow, 'Player Color: ' + s);
			TextWindowAppend(textWindow, 'Player Char: ' + World.Info.PlayerChar);
			for i := 1 to 7 do begin
				Str(Local[i],s);
				TextWindowAppend(textWindow, CustomBoardList[i] + ': ' + s);
			end;
			TextWindowAppend(textWindow, '$** Board connections: **');
			for i := 0 to 3 do
				if NeighborBoards[i] <> 0 then
					TextWindowAppend(textWindow, '  ' + NeighborArrowList[i] + '  ' +  BoardNames^[NeighborBoards[i]])
				else
					TextWindowAppend(textWindow, '  ' + NeighborArrowList[i] + '  None');
			textWindow.Title := 'Inspecting Board';
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end;
	end;

procedure InspectObjectCode(statId, PointPos: integer; ErrMsg: string);
	var
		s, t: string;
		ch: char;
		i, pos: integer;
		textWindow: TTextWindowState;
		isCurLine: boolean;
	begin
		with Board.Stats[statId] do begin
			pos := 0;
			s := '';
			isCurLine := false;
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			if ErrMsg <> '' then
				TextWindowAppend(textWindow, #255#32 + ErrMsg)
			else begin
				TextWindowAppend(textWindow, '$** Object Stats: **');
				Str(P1,s);
				t := s + ', ';
				Str(P2,s);
				t := t + s + ', ';
				Str(P3,s);
				TextWindowAppend(textWindow, 'Params: ' + t + s);
				Str(StepX,s);
				t := s + ', ';
				Str(StepY,s);
				TextWindowAppend(textWindow, 'Step: ' + t + s);
				Str(Cycle,s);
				TextWindowAppend(textWindow, 'Cycle: ' + s);
				for i := 1 to 4 do begin
					Str(ObjLocal[i],s);
					TextWindowAppend(textWindow, CustomObjList[i] + ': ' + s);
				end;
				Str(Leader,s);
				TextWindowAppend(textWindow, CustomObjList[5] + ': ' + s);
				Str(Follower,s);
				TextWindowAppend(textWindow, CustomObjList[6] + ': ' + s);
				Str(ObjArray,s);
				TextWindowAppend(textWindow, 'Array: ' + s);
				s := '';
				TextWindowAppend(textWindow, '$** Object Data: **');
			end;
			while pos <= DataLen do begin
{$IFDEF FPC}
				ch := Data[pos];
{$ELSE}
				ch := Data^[pos];
{$ENDIF}
				if ch = #13 then begin
					if isCurLine then begin
						TextWindowAppend(textWindow, #255#16 + s);
						if ErrMsg <> '' then
							TextWindowAppend(textWindow, #255#32 + ErrMsg);
					end else
						TextWindowAppend(textWindow, s);
					s := '';
					isCurLine := false;
				end else
					s := s + ch;
				Inc(pos);
				if pos = PointPos then
					isCurLine := true;
			end;
			if DataLen = 0 then
				TextWindowAppend(textWindow, 'There is no object data.');
			textWindow.Title := 'Inspecting Object';
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end;
	end;

function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	var
		iDataPos, iStat: integer;
		ignoreSelfLock: boolean;
	begin
		if statId < 0 then begin
			{ if statId is negative, label send will always succeed on self }
			{ this is used for in-game events (f.e. TOUCH, SHOT) }
			statId := -statId;
			ignoreSelfLock := true;
		end else begin
			ignoreSelfLock := false;
		end;

		OopSend := false;
		iStat := 0;

		while OopFindLabel(statId, 1, sendLabel, iStat, iDataPos, #13':') do begin
			if ((Board.Stats[iStat].P2 = 0) or (ignoreLock)) or ((statId = iStat) and not ignoreSelfLock) then begin
				if iStat = statId then
					OopSend := true;

				Board.Stats[iStat].DataPos := iDataPos + 1;
			end;
		end;
	end;

procedure OopExecute(statId: integer; name: TString50);
	var
		textWindow: TTextWindowState;
		textLine: string;
		deltaX, deltaY: integer;
		code, ix, iy: integer;
		stopRunning: boolean;
		endOfProgram: boolean;
		replaceTile: TTile;
		namePosition: integer;
		lastPosition: integer;
		repeatInsNextTick: boolean;
		replaceBoard, replaceStat, replaceForce, dieItem: boolean;
		MatchFG, MatchBG: boolean;
		lineFinished: boolean;
		labelPtr: pointer;
		labelDataPos: integer;
		labelStatId: integer;
		labelZap, labelUnzap, tmpchar: char;
		counter: TCounter;
		scheduledUpdates: TScheduledUpdates;
		counterSubtract: boolean;
		bindStatId: integer;
		insCount: integer;
		argTile: TMatchTile;
		argTile2: TMatchTile;
		tmpcond: byte;
	label StartParsing;
	label ReadInstruction;
	label ReadCommand;
	label StopExecution;
	begin
		ScheduledUpdatesClear(scheduledUpdates);

		with TrackPushStat(statId)^ do begin
		StartParsing:
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			stopRunning := false;
			repeatInsNextTick := false;
			replaceBoard := false;
			replaceStat := false;
			replaceForce := false;
			dieItem := false;
			endOfProgram := false;
			insCount := 1;
			repeat
		ReadInstruction:
				lineFinished := true;
				lastPosition := Stat^.DataPos;
				OopReadChar(Index, Stat^.DataPos);

				{ skip labels }
				while OopChar = ':' do begin
					repeat
						OopReadChar(Index, Stat^.DataPos);
					until (OopChar = #0) or (OopChar = #13);
					OopReadChar(Index, Stat^.DataPos);
				end;

				if (OopChar = '@') or (OopChar = #39) { apostrophe } then
					OopSkipLine(Index, Stat^.DataPos)
				else if (OopChar = '/') or (OopChar = '?') then begin
					if OopChar = '/' then
						repeatInsNextTick := true;

					OopReadWord(Index, Stat^.DataPos);
					if OopParseDirection(Index, Stat^.DataPos, deltaX, deltaY) then begin
						if (deltaX <> 0) or (deltaY <> 0) then begin
							if not XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then
								ElementPushablePush(Stat^.X + deltaX, Stat^.Y + deltaY, deltaX, deltaY);

							if XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then begin
								MoveStat(Index, Stat^.X + deltaX, Stat^.Y + deltaY);
								repeatInsNextTick := false;
							end;
						end else begin
							repeatInsNextTick := false;
						end;

						OopReadChar(Index, Stat^.DataPos);
						if OopChar <> #13 then
							Dec(Stat^.DataPos);

						stopRunning := true;
					end else
						OopError(Index,Stat^.DataPos, 'Bad direction ' + OopWord);
				end else if OopChar = '#' then begin
		ReadCommand:
					OopReadWord(Index, Stat^.DataPos);
					if OopWord = 'THEN' then OopReadWord(Index, Stat^.DataPos);
					if Length(OopWord) = 0 then goto ReadInstruction;
					if name <> '%%Function' then Inc(insCount);
					if Length(OopWord) <> 0 then begin
						if OopWord = 'GO' then begin
							OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
							if not XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then
								ElementPushablePush(Stat^.X + deltaX, Stat^.Y + deltaY, deltaX, deltaY);

							if XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then begin
								MoveStat(Index, Stat^.X + deltaX, Stat^.Y + deltaY);
							end else begin
								repeatInsNextTick := true;
							end;
							stopRunning := true;
						end else if OopWord = 'TRY' then begin
							OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
							if not XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then
								ElementPushablePush(Stat^.X + deltaX, Stat^.Y + deltaY, deltaX, deltaY);

							if XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then begin
								MoveStat(Index, Stat^.X + deltaX, Stat^.Y + deltaY);
								stopRunning := true;
							end else begin
								OopReadChar(Index, Stat^.DataPos);
								Dec(Stat^.DataPos);
								if (OopChar <> #13) then
									goto ReadCommand;
							end;
						end else if OopWord = 'WALK' then begin
							OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
							Stat^.StepX := deltaX;
							Stat^.StepY := deltaY;
						end else if OopWord = 'SET' then begin
							OopReadWord(Index, Stat^.DataPos);
							textLine := OopWord;
							if not HasINI then
								WorldSetFlag(OopWord)
							else if CounterFromWord(counter, Index, OopWord) then begin
								if counter.CType = TCConfig then begin
									Inc(Stat^.DataPos);
									textLine := OopReadLineToEnd(Index, Stat^.DataPos);
									if textLine <> '' then begin
										XDat.Configs[counter.Value] := textLine;
										Dec(Stat^.DataPos);
									end;
									scheduledUpdates.UpdateTheme := true;
								end else begin
									OopReadValue(Index, Stat^.DataPos);
									if OopValue = -32767 then
										counter.Value := 1
									else
										counter.Value := OopValue;
									if CounterWriteValue(counter, scheduledUpdates) then begin end;
								end;
								scheduledUpdates.UpdateSidebar := true;
							end else if OopNextWord(Index, Stat^.DataPos) = '' then begin
								WorldSetFlag(OopWord);
							end else
								OopError(Index,Stat^.DataPos, 'Unknown counter ' + OopWord);
							If HasCustomSidebar then GameDrawCustomSidebar;
						end else if OopWord = 'CLEAR' then begin
							OopReadWord(Index, Stat^.DataPos);
							if not HasINI then
								WorldClearFlag(OopWord)
							else if CounterFromWord(counter, Index, OopWord) then begin
								if counter.CType = TCConfig then begin
									XDat.Configs[counter.Value] := '';
									XDat.Configs[counter.Value][1] := #1;
									scheduledUpdates.UpdateTheme := true;
								end else begin
									counter.Value := 0;
									if CounterWriteValue(counter, scheduledUpdates) then begin end;
								end;
								scheduledUpdates.UpdateSidebar := true;
							end else
								WorldClearFlag(OopWord);
							If HasCustomSidebar then GameDrawCustomSidebar;
						end else if OopWord = 'IF' then begin
							Stat^.elseCheck := false;
							OopReadWord(Index, Stat^.DataPos);
							if OopCheckCondition(Index, Stat^.DataPos) then begin
								OopReadChar(Index, Stat^.DataPos);
								Dec(Stat^.DataPos);
								if (OopChar <> #13) then
									goto ReadCommand;
							end else
								Stat^.elseCheck := true;
						end else if OopWord = 'SHOOT' then begin
							OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
							if BoardShoot(E_BULLET, Stat^.X, Stat^.Y, deltaX, deltaY, XDat.EDefs[E_BULLET].P3) then
								SoundQueue(2, SoundParse(XDat.Configs[43])); {Object shoot}
							stopRunning := true;
						end else if OopWord = 'THROWSTAR' then begin
							OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
							if BoardShoot(E_STAR, Stat^.X, Stat^.Y, deltaX, deltaY, SHOT_SOURCE_ENEMY) then
								begin end;
							stopRunning := true;
						end else if (OopWord = 'GIVE') or (OopWord = 'TAKE') then begin
							if OopWord = 'TAKE' then
								counterSubtract := true
							else
								counterSubtract := false;

							OopReadWord(Index, Stat^.DataPos);
							textLine := OopWord;

							if CounterFromWord(counter, Index, OopWord) then begin
								CounterReadValue(counter);
								code := Stat^.DataPos;
								OopReadValue(Index, Stat^.DataPos);
								if OopValue = -32767 then begin
									Stat^.DataPos := code;
									OopValue := 1;
								end;
								if counterSubtract then
									OopValue := -OopValue;
								counter.Value := counter.Value + OopValue;
								if counter.Value < 0 then begin
									OopReadChar(Index, Stat^.DataPos);
									Dec(Stat^.DataPos);
									if (OopChar <> #13) then
										goto ReadCommand;
								end else if CounterWriteValue(counter, scheduledUpdates) then begin end;
							end else
								OopError(Index,Stat^.DataPos, 'Unknown counter ' + OopWord);
							scheduledUpdates.UpdateSidebar := true;
							If HasCustomSidebar then GameDrawCustomSidebar;
						end else if OopWord = 'END' then begin {#END Returns Functions.}
							OopReadValue(Index, Stat^.DataPos);
							OopFuncReturn := OopValue;
							Stat^.DataPos := -1;
							OopChar := #0;
						end else if OopWord = 'ENDGAME' then begin
							World.Info.Health := 0;
							World.Info.GracePeriod := XDat.Params[11];
						end else if OopWord = 'IDLE' then begin
							stopRunning := true;
						end else if OopWord = 'RESTART' then begin
							Stat^.DataPos := 0;
							lineFinished := false;
						end else if (OopWord = 'ZAP') or (OopWord = 'RESTORE') then begin
							textLine := OopWord;
							repeat
								OopReadChar(Index, Stat^.DataPos);
							until OopChar <> ' ';
							if OopChar = '!' then begin
								labelZap := '@';
								labelUnzap := '!';
								ix := 1;
							end else begin
								Dec(Stat^.DataPos);
								labelZap := #39;
								labelUnzap := ':';
								ix := 99;
							end;
							if textLine = 'RESTORE' then begin
								tmpchar := labelZap;
								labelZap := labelUnzap;
								labelUnzap := tmpchar;
							end else
								ix := 1;
							OopReadWord(Index, Stat^.DataPos);
							textLine := OopWord;
							OopReadValue(Index, Stat^.DataPos);
							if OopValue = -32767 then 
								OopValue := ix;
							if OopValue < 0 then begin
								ix := -1
							end else
								ix := 1;
							while (OopValue <> 0) do begin
								labelStatId := 0;
								OopWord := textLine;
								iy := ix;
								while OopFindLabel(Index, ix, OopWord, labelStatId, labelDataPos, #13 + labelUnzap) do begin
									iy := OopValue;
									labelPtr := Board.Stats[labelStatId].Data;
									AdvancePointer(labelPtr, labelDataPos + 1);
									Char(labelPtr^) := labelZap;
								end;
								OopValue := iy;
								Dec(OopValue, ix);
							end;
						end else if (OopWord = 'UNLOCK') or (OopWord = 'LOCK') then begin
							if OopWord = 'UNLOCK' then
								iy := 0
							else
								iy := 1;
							OopReadWord(Index, Stat^.DataPos);
							if not OopParseDirection(Index, Stat^.DataPos, deltaX, deltaY) then
								Stat^.P2 := iy
							else begin
								ix := GetStatIdAt( Stat^.X + deltaX, Stat^.Y + deltaY );
								if ix <> -1 then
									Board.Stats[ix].P2 := iy;
							end;
						end else if OopWord = 'SEND' then begin
							repeat
								OopReadChar(Index, Stat^.DataPos);
							until OopChar <> ' ';
							if OopChar = '/' then begin
								OopReadWord(Index, Stat^.DataPos);
								if OopParseDirection(Index, Stat^.DataPos, deltaX, deltaY) then begin
									OopReadWord(Index, Stat^.DataPos);
									ix := GetStatIdAt(Stat^.X + deltaX, Stat^.Y + deltaY);
									if ix > 0 then
										if OopSend(-ix, OopWord, false) then lineFinished := false;
								end;
							end else begin
								Dec(Stat^.DataPos);
								OopReadWord(Index, Stat^.DataPos);
								if OopSend(Index, OopWord, false) then lineFinished := false;
							end;
						end else if OopWord = 'BECOME' then begin
							if OopParseTile(Index, Stat^.DataPos, argTile) then begin
								replaceStat := true;
								if (argTile.SetFG = true) or (argTile.SetBG = true) then
									replaceForce := true;
								replaceTile.Element := argTile.Element;
								replaceTile.Color := argTile.Color;
							end else begin
								OopError(Index,Stat^.DataPos, 'Bad #BECOME');
							end;
						end else if OopWord = 'PUT' then begin
							OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
							if not OopParseTile(Index, Stat^.DataPos, argTile) then
								OopError(Index,Stat^.DataPos, 'Bad #PUT')
							else if ((Stat^.X + deltaX) > 0)
								and ((Stat^.X + deltaX) <= BOARD_WIDTH)
								and ((Stat^.Y + deltaY) > 0)
								and ((Stat^.Y + deltaY) <= BOARD_HEIGHT) then
							begin
								ix := GetStatIdAt(Stat^.X + deltaX,Stat^.Y + deltaY);
								if SelUnder and (ix > -1) then begin
									Board.Stats[ix].Under.Element := argTile.Element;
									if argTile.Color and $F0 > 0 then
										argTile.setBG := true;
									if argTile.Color and $0F > 0 then
										argTile.setFG := true;
									if (argTile.setBG = true)
										or (argTile.Element >= E_TEXT_MIN)
									then
										Board.Stats[ix].Under.Color := argTile.Color
									else if argtile.setFG = true then
										Board.Stats[ix].Under.Color := argTile.Color and $0F
									else if XDat.EDefs[Enum(argTile.Element)].Color > 15 then
										Board.Stats[ix].Under.Color := XDat.EDefs[Enum(argTile.Element)].Color
									else if XDat.EDefs[Enum(argTile.Element)].Color > 0 then
										Board.Stats[ix].Under.Color := AsColor(XDat.EDefs[Enum(argTile.Element)].Color,
											Board.Stats[ix].Under.Color and $F0);

								end else if ((deltaX <> 0) or (deltaY <> 0)) then begin
									if not XDat.EDefs[Enum(Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Element)].Walkable then
										ElementPushablePush(Stat^.X + deltaX, Stat^.Y + deltaY, deltaX, deltaY);
									replaceTile.Element := argTile.Element;
									replaceTile.Color := argTile.Color;
									if (argTile.setFG = true) or (argTile.setBG = true) then
										OopForceTile(Stat^.X + deltaX, Stat^.Y + deltaY, replaceTile)
									else
										OopPlaceTile(Stat^.X + deltaX, Stat^.Y + deltaY, replaceTile);
								end;
							end;
						end else if OopWord = 'CHANGE' then begin
							if not OopParseTile(Index, Stat^.DataPos, argTile) then
								OopError(Index,Stat^.DataPos, 'Bad #CHANGE to ' + OopWord)
							else begin
								textLine := OopWord;
								if not OopParseTile(Index, Stat^.DataPos, argTile2) then
									OopError(Index,Stat^.DataPos, 'Bad #CHANGE from ' + textLine + ' to ' + OopWord)
								else begin
									if (argTile.Element = E_PLAYER) then begin
										if (argTile.Color = 0)
											or (argTile.Color = World.Info.PlayerColor and $0F)
											or (argTile.Color = World.Info.PlayerColor)
										then begin
											if ArgTile2.Element > 127 then begin
												World.Info.PlayerChar := Chr(ArgTile2.Color);
												World.Info.PlayerColor := ArgTile2.Element - 128;
											end else begin
												World.Info.PlayerChar := XDat.EDefs[Enum(argTile2.Element)].Character;
												if (ArgTile2.Color = 0) and (XDat.EDefs[Enum(argTile2.Element)].Color > 0) then
													World.Info.PlayerColor := XDat.EDefs[Enum(argTile2.Element)].Color
												else
													World.Info.PlayerColor := ArgTile2.Color;
											end;
										end;
									end else begin
										ix := 0;
										iy := 1;
										if ((argTile2.Color = 0) and (argtile2.SetFG = false))
											and ((argTile.Element < E_TEXT_MIN) or (argTile2.Element < E_TEXT_MIN))
										then
											argTile2.Color := ElemDefColor(argTile2.Element);
										replaceTile.Element := argTile2.Element;
										replaceTile.Color := argTile2.Color;

										while FindTileOnBoard(ix, iy, argTile) do begin
											if (argTile.Element <= E_TEXT_MIN) and (XDat.EDefs[argTile.Element].Cycle < 0) then
												Board.Tiles[ix][iy].Element := E_EMPTY;
											if (argTile2.SetFG = true) or (argTile2.SetBG = true) then
												OopForceTile(ix, iy, replaceTile)
											else
												OopPlaceTile(ix, iy, replaceTile);
										end;
									end;
								end;
							end;
						end else if OopWord = 'PLAY' then begin
							OopReadChar(Index, Stat^.DataPos);
							if OopChar = #13 then
								SoundClearQueue;
							Dec(Stat^.DataPos);
							textLine := SoundParse(OopReadLineToEnd(Index, Stat^.DataPos));
							if Length(textLine) <> 0 then
								SoundQueue(-1, textLine);
							lineFinished := false;
						end else if OopWord = 'CYCLE' then begin
							OopReadValue(Index, Stat^.DataPos);
							if OopValue > 0 then
								Stat^.Cycle := OopValue;
						end else if OopWord = 'CHAR' then begin
							OopReadValue(Index, Stat^.DataPos);
							if (OopValue > 0) and (OopValue <= 255) then begin
								Stat^.P1 := OopValue;
								BoardDrawTile(Stat^.X, Stat^.Y);
							end;
						end else if OopWord = 'DIE' then begin
							replaceStat := true;
							replaceForce := true;
							replaceTile.Element := Stat^.Under.Element;
							replaceTile.Color := Stat^.Under.Color;
							OopReadWord(Index, Stat^.DataPos);
							if OopWord = 'ITEM' then
								dieItem := true;
						end else if OopWord = 'BIND' then begin
							OopReadWord(Index, Stat^.DataPos);
							bindStatId := 0;
							if OopIterateStat(Index, bindStatId, OopWord) then begin
								if Index <> bindStatId then begin
									FreeMem(Stat^.Data, Stat^.DataLen);
									Stat^.Data := Board.Stats[bindStatId].Data;
									Stat^.DataLen := Board.Stats[bindStatId].DataLen;
								end;
								Stat^.DataPos := 0;
							end;
						end else if HasINI then begin
							if (OopWord = 'ELSE') then begin
								if Stat^.elseCheck then goto ReadCommand;
							end else if (OopWord = 'AND') then begin
								if not Stat^.elseCheck then goto ReadCommand;
							end else if (OopWord = 'RUN') then begin
								ix := OopRunFunc(Index, Stat^.DataPos);
							end else if OopWord = 'RUNWITH' then begin
								OopReadValue(Index, Stat^.DataPos);
								if OopValue <> -32767 then
									ix := OopRunFuncWith(Index, Stat^.DataPos, OopValue)
								else
									OopError(Index,Stat^.DataPos, 'Could not read ' + OopWord + ' value');
							end else if OopWord = 'OUT' then begin {OUTPUT}
								OopReadValue(Index, Stat^.DataPos);
								deltaX := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								deltaY := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								ix := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								iy := OopValue;
								OopOutputTile(ix, iy, deltaX, deltaY, Board.Tiles[deltaX + ix][deltaY + iy]);
							end else if OopWord = 'XOUT' then begin {OUTPUT}
								OopReadChar(Index, Stat^.DataPos);
								while OopChar = ' ' do
									OopReadChar(Index, Stat^.DataPos);
								Dec(Stat^.DataPos);
								textLine := OopReadLineToEnd(Index, Stat^.DataPos);
								XOut(textLine);
								Dec(Stat^.DataPos);
							end else if OopWord = 'LOAD' then begin
								OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
								if ((Stat^.X + deltaX) > 0)
									and ((Stat^.X + deltaX) <= BOARD_WIDTH)
									and ((Stat^.Y + deltaY) > 0)
									and ((Stat^.Y + deltaY) <= BOARD_HEIGHT)
								then begin
									bindStatId := GetStatIdAt(Stat^.X + deltaX, Stat^.Y + deltaY);
									if (Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].element = E_OBJECT)
										and (bindStatId > 0)
									then begin
										ix := Stat^.DataPos;
										OopReadWord(Index, Stat^.DataPos);
										if OopWord <> 'APPEND' then
											Stat^.DataPos := ix;
										Inc(Stat^.DataPos);
										textLine := OopReadLineToEnd(Index, Stat^.DataPos);
										Dec(Stat^.DataPos);
										if (OopWord = 'APPEND') then begin
											if FileAppendStatData(textLine,bindStatId) then
												goto ReadCommand
											else
												OopError(Index,Stat^.DataPos, 'Unable to load ' + textLine + '.OBJ');
										end else if FileLoadStatData(textLine,bindStatId) then begin
											Board.Stats[bindStatId].DataPos := 0;
											goto ReadCommand;
										end else
											OopError(Index,Stat^.DataPos, 'Unable to load ' + textLine + '.OBJ');
									end;
								end;
							end else if OopWord = 'WRITE' then begin
								OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
								Inc(deltaX,Stat^.X);
								Inc(deltaY,Stat^.Y);

								ix := OopGetColor(Index, Stat^.DataPos, argTile);
								if ix < 0 then OopError(Index,Stat^.DataPos, 'Invalid WRITE color.');
								argTile.Element := 128 + (ix mod 128);

								Inc(Stat^.DataPos);
								textLine := OopReadLineToEnd(Index, Stat^.DataPos);
								Dec(Stat^.DataPos);								

								iy := Length(textLine);

								while iy > 0 do begin
									Dec(iy);
									if ((deltaX) > 0)
										and ((deltaX) <= BOARD_WIDTH)
										and ((deltaY) > 0)
										and ((deltaY) <= BOARD_HEIGHT) then
									begin
										argTile.Color := Ord(textLine[Length(textLine) - iy]);
										if ((deltaX <> 0) or (deltaY <> 0)) and (GetStatIdAt(deltaX, deltaY) <> 0) then
											if SelUnder and (GetStatIdAt(Stat^.X + deltaX,Stat^.Y + deltaY) > 0) then begin
												Board.Stats[GetStatIdAt(Stat^.X + deltaX,Stat^.Y + deltaY)].Under.Element := argTile.Element;
												Board.Stats[GetStatIdAt(Stat^.X + deltaX,Stat^.Y + deltaY)].Under.Color := argTile.Color;
											end else begin
												replaceTile.Element := argTile.Element;
												replaceTile.Color := argTile.Color;
												OopForceTile(deltaX, deltaY, replaceTile)
											end;
										Inc(deltaX);
									end;
								end;
							end else if OopWord = 'PALETTE' then begin
								OopReadValue(Index, Stat^.DataPos);
								ix := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								iy := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								deltaX := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								deltaY := OopValue;
								if (ix >= 0)
									and (ix <= 15)
									and (iy = -1)
									and (deltaX = -1)
									and (deltaY = -1)
								then begin
									iy := XDat.Params[PALETTE_START + (ix * 3)];
									deltaX := XDat.Params[PALETTE_START + (ix * 3) + 1];
									deltaY := XDat.Params[PALETTE_START + (ix * 3) + 2];
								end;
								if (((ix >= 0) and (ix <= 15))
									and ((iy >= 0) and (iy <= 63)))
									and (((deltaX >= 0) and (deltaX <= 63))
									and ((deltaY >= 0) and (deltaY <= 63)))
								then begin
									XDat.CurrentPalette[(ix * 3)] := iy;
									XDat.CurrentPalette[(ix * 3) + 1] := deltaX;
									XDat.CurrentPalette[(ix * 3) + 2] := deltaY;
									BlockPalette(ix,iy,deltaX,deltaY);
								end else
									OopError(Index,Stat^.DataPos, 'Bad PALETTE Command');
							end else if OopWord = 'PLAYER' then begin
								OopReadValue(Index, Stat^.DataPos);
								ix := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								iy := OopValue;
								OopReadValue(Index, Stat^.DataPos);
								if ((( ix > -1 ) and ( ix < 16 ))
									and (( iy > -1 ) and ( iy < 16 )))
								then
									World.Info.PlayerColor := AsColor( ix, iy );
								if (( OopValue > -1 ) and ( OopValue < 256 )) then 
									World.Info.PlayerChar := Chr(OopValue);
							end else if OopWord = 'STARTGAME' then begin
								if GameStateElement <> E_PLAYER then begin
									QuickStart := true;
									deltaX := WorldGetBoardPosition(Index, Stat^.DataPos);
									if (deltaX > -1) and (deltaX <= World.BoardCount) then
										QStartBoard := deltaX
									else
										QStartBoard := -1;
								end;
							end else if OopWord = 'SAVEGAME' then begin
								ix := Stat^.DataPos;
								OopReadChar(Index, Stat^.DataPos);
								while OopChar = ' ' do
									OopReadChar(Index, Stat^.DataPos);
								Dec(Stat^.DataPos);
								if Stat^.DataPos = ix then
									GameWorldSave(XDat.Configs[78] + ':', SavedGameFileName, '.SAV')
								else begin
									textLine := OopReadLineToEnd(Index, Stat^.DataPos);
									WorldSave(textLine,'.SAV');
									Dec(Stat^.DataPos);
								end;
								stopRunning := true;
							end else if OopWord = 'LOADGAME' then begin
								ix := Stat^.DataPos;
								OopReadChar(Index, Stat^.DataPos);
								while OopChar = ' ' do
									OopReadChar(Index, Stat^.DataPos);
								Dec(Stat^.DataPos);
								if Stat^.DataPos = ix then begin
									if GameWorldLoad('.SAV') then begin
										ReturnBoardId := World.Info.CurrentBoard;
										BoardChange(ReturnBoardId);
										TransitionDrawToBoard;
									end;
								end else begin
									textLine := OopReadLineToEnd(Index, Stat^.DataPos);
									if WorldLoad(textLine, '.SAV') then begin
										ReturnBoardId := World.Info.CurrentBoard;
										BoardChange(ReturnBoardId);
										TransitionDrawToBoard;
									end;
 									Dec(Stat^.DataPos);
								end;
								scheduledUpdates.UpdateSidebar := true;
								stopRunning := true;
							end else if OopWord = 'STEP' then begin
								OopReadDirection(Index, Stat^.DataPos, ix, iy);
								textLine := OopNextWord(Index, Stat^.DataPos);
								Inc(ix,Stat^.X);
								Inc(iy,Stat^.Y);
								OopReadDirectionRel(Index, Stat^.DataPos, deltaX, deltaY, ix, iy, textLine);
								bindStatId := GetStatIdAt(ix, iy);
								if (bindStatId > -1) then begin
									Board.Stats[bindStatId].StepX := deltaX;
									Board.Stats[bindStatId].StepY := deltaY;
								end;
							end else if OopWord = 'PSET' then begin
								OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
								bindStatId := GetStatIdAt( Stat^.X + deltaX, Stat^.Y + deltaY );
								if bindStatId > -1 then begin
									OopReadWord(Index, Stat^.DataPos);
									if OopWord = 'STEP' then begin
										textLine := OopNextWord(Index, Stat^.DataPos);
										Inc(deltaX,Stat^.X);
										Inc(deltaY,Stat^.Y);
										OopReadDirectionRel(Index, Stat^.DataPos, ix, iy, deltaX, deltaY, textLine);
										Board.Stats[bindStatId].StepX := ix;
										Board.Stats[bindStatId].StepY := iy;
									end else if OopWord = 'DESTINATION' then begin
										iy := WorldGetBoardPosition(Index, Stat^.DataPos);
										Board.Stats[bindStatId].P3 := iy;
									end else begin
										OopReadValue(Index, Stat^.DataPos);
										iy := OopValue;
										if ((OopWord = 'P1') or (OopWord = 'CHAR')) or ((OopWord = 'INTEL') or (OopWord = 'INTELLIGENCE')) then
											Board.Stats[bindStatId].P1 := iy
										else if (OopWord = 'P2') or (OopWord = 'RATE') or (OopWord = 'SPEED') then
											Board.Stats[bindStatId].P2 := iy
										else if OopWord = 'P3' then
											Board.Stats[bindStatId].P3 := iy
										else if OopWord = 'CYCLE' then
											Board.Stats[bindStatId].Cycle := iy										
										else if CounterFromWord(counter, bindStatId, OopWord) then begin
											counter.Value := iy;
											if CounterWriteValue(counter, scheduledUpdates) then begin end;
										end;
									end;
								end;
							end else if OopWord = 'EDGE' then begin
								OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
								if (Sqr(deltaX) + Sqr(deltaY)) = 1 then begin
									ix := WorldGetBoardPosition(Index, Stat^.DataPos);
									if (ix > -1) and (ix <= World.BoardCount) then begin
										if deltaY = -1 then
											Board.Info.NeighborBoards[0] := ix
										else if deltaY = 1 then
											Board.Info.NeighborBoards[1] := ix
										else if deltaX = -1 then
											Board.Info.NeighborBoards[2] := ix
										else Board.Info.NeighborBoards[3] := ix;
									end else
										OopError(Index,Stat^.DataPos, 'No board label :' + OopWord);
								end else
									OopError(Index,Stat^.DataPos, 'Bad board direction');
							end else if OopWord = 'BOARD' then begin
								deltaX := WorldGetBoardPosition(Index, Stat^.DataPos);
								if (deltaX > -1) and (deltaX <= World.BoardCount) then begin
									OopReadValue(Index, Stat^.DataPos);
									ix := OopValue;
									OopReadValue(Index, Stat^.DataPos);
									iy := OopValue;
									replaceBoard := true;
									stopRunning := true;
								end else
									OopError(Index,Stat^.DataPos, 'No board label :' + OopWord);
							end else if OopWord = 'DUPLICATE' then begin
								OopReadDirection(Index, Stat^.DataPos, ix, iy);
								textLine := OopNextWord(Index, Stat^.DataPos);
								OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
								if ElementDuplicate(ix, iy, deltaX, deltaY, Index) then
									BoardDrawTile(Stat^.X + deltaX, Stat^.Y + deltaY);
							end else if OopWord = 'SHOVE' then begin
								OopReadDirection(Index, Stat^.DataPos, ix, iy);
								textLine := OopNextWord(Index, Stat^.DataPos);
								Inc(ix,Stat^.X);
								Inc(iy,Stat^.Y);
								OopReadDirectionRel(Index, Stat^.DataPos, deltaX, deltaY, ix, iy, textLine);
								argTile.Element := Board.Tiles[ix][iy].Element;
								if (((deltaX <> 0) or (deltaY <> 0)) and (argTile.Element <> E_EMPTY))
									and (((ix + deltaX > 0) and (ix + deltaX <= BOARD_WIDTH))
									and ((iy + deltaY > 0) and (iy + deltaY <= BOARD_HEIGHT)))
								then begin
									ElementPushablePush(ix, iy, deltaX, deltaY);
									if (argTile.Element = Board.Tiles[ix][iy].Element) then begin
										ElementPushablePush(ix + deltaX, iy + deltaY, deltaX, deltaY);
										if GetStatIdAt(ix + deltaX, iy + deltaY) < 0 then begin
											bindStatId := GetStatIdAt(ix,iy);
											if (bindStatId > -1) then
												MoveStat(bindStatId, ix + deltaX, iy + deltaY)
											else begin
												Board.Tiles[ix + deltaX][iy + deltaY] := Board.Tiles[ix][iy];
												Board.Tiles[ix][iy].Element := E_EMPTY;
											end;
											BoardDrawTile(ix, iy);
											BoardDrawTile(ix + deltaX, iy + deltaY);
										end;
									end;
								end;
							end else if OopWord = 'COLOR' then begin
								OopReadDirection(Index, Stat^.DataPos, deltaX, deltaY);
								if ((Stat^.X + deltaX) > 0)
									and ((Stat^.X + deltaX) <= BOARD_WIDTH)
									and ((Stat^.Y + deltaY) > 0)
									and ((Stat^.Y + deltaY) <= BOARD_HEIGHT) then
								begin
									OopReadValue(Index, Stat^.DataPos);
									ix := OopValue;
									OopReadValue(Index, Stat^.DataPos);
									iy := OopValue;
									if ( iy < 1 ) or ( iy > 15 ) then
										iy := 0;
									if ((ix + (iy * 16)) > -1) and ((ix + (iy * 16)) < 256) then begin
										if SelUnder and (GetStatIdAt(Stat^.X + deltaX,Stat^.Y + deltaY) > -1) then
											Board.Stats[GetStatIdAt(Stat^.X + deltaX,Stat^.Y + deltaY)].Under.Color := AsColor(ix, iy)
										else begin
											Board.Tiles[Stat^.X + deltaX][Stat^.Y + deltaY].Color := AsColor(ix, iy);
											BoardDrawTile(Stat^.X + deltaX, Stat^.Y + deltaY);
										end;
									end else
										OopError(Index,Stat^.DataPos, 'Unknown color.');
								end;
							end else if OopWord = 'BGPLAY' then begin
								textLine := SoundParse(OopReadLineToEnd(Index, Stat^.DataPos));
								if Length(textLine) <> 0 then
									SoundQueue(2, textLine);
								lineFinished := false;
							end else begin
								textLine := OopWord;
								if OopSend(Index, OopWord, false) then
									lineFinished := false
								else if Pos(':', textLine) <= 0 then
									OopError(Index,Stat^.DataPos, 'Bad command ' + textLine);
							end;
						end else begin
							textLine := OopWord;
							if OopSend(Index, OopWord, false) then
								lineFinished := false
							else if Pos(':', textLine) <= 0 then
								OopError(Index,Stat^.DataPos, 'Bad command ' + textLine);
						end;
					end;

					if lineFinished then
						OopSkipLine(Index, Stat^.DataPos);

				end else if OopChar = #13 then begin
					if textWindow.LineCount > 0 then
						TextWindowAppend(textWindow, '');
				end else if OopChar = #0 then begin
					endOfProgram := true;
				end else begin
					textLine := OopChar;
					textLine := textLine + OopReadLineToEnd(Index, Stat^.DataPos);
					TextWindowAppend(textWindow, textLine);
				end;

			until endOfProgram or stopRunning or repeatInsNextTick or replaceStat or (insCount > XDat.Params[10]);

			ScheduledUpdatesApply(scheduledUpdates);

			if OopWord = 'SAVEDGAMES' then goto StopExecution;

			if repeatInsNextTick then
				Stat^.DataPos := lastPosition;

			if OopChar = #0 then
				Stat^.DataPos := -1;

			if textWindow.LineCount > 1 then begin
				namePosition := 0;
				OopReadChar(Index, namePosition);
				if (OopChar = '@') then begin
					name := OopReadLineToEnd(Index, namePosition);
				end;

				if Length(name) = 0 then
					name := 'Interaction';

				textWindow.Title := name;
				TextWindowDrawOpen(textWindow);
				TextWindowSelect(textWindow, TWS_HYPERLINK_AS_SELECT);
				TextWindowDrawClose(textWindow);
				TextWindowFree(textWindow);

				if Length(textWindow.Hyperlink) <> 0 then
					if OopSend(Index, textWindow.Hyperlink, false) then
						goto StartParsing;
			end else if textWindow.LineCount = 1 then begin
				DisplayMessage(200, textWindow.Lines[1]^);
				TextWindowFree(textWindow);
			end;

			if replaceStat and (name <> '%%Function') then begin
				ix := Stat^.X;
				iy := Stat^.Y;
				DamageStat(Index);
				if replaceForce then
					OopForceTile(ix, iy, replaceTile)
				else
					OopPlaceTile(ix, iy, replaceTile);
				if dieItem then
					MoveStat(0, ix, iy);
			end;

			if replaceBoard then begin
				BoardChange(deltaX);
				TransitionDrawToBoard;
				BoardEnter;
				if (( ix > 0 ) and ( iy > 0 )) and
					((Board.Stats[0].X <> ix) or
						(Board.Stats[0].Y <> iy)) then
					MoveStat(0, ix, iy);
				if HasINI then
					if OopSend(0, 'ALL:ENTER', false) then begin end;
			end;
		end;

		StopExecution:
		TrackPopStat;
	end;

begin
end.
