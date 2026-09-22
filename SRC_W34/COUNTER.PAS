{
	Copyright (c) 2024 Adrian Siekierka

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
unit Counter;

interface
	type
		TCounter = record
			CType: (TCReadOnly, TCByte, TCShortInt, TCInteger, TCTickSpeed, TCElement, TCConfig);
			Value: integer;
			Pointer: pointer;
			Entry: string[20];

			{ Copied to scheduled updates in CounterWriteValue }
			UpdateBoard: boolean;
			UpdateTheme: boolean;
		end;
		cInteger = ^integer;
		cShortint = ^shortint;
		cByte = ^byte;
	{ Parses the counter name s. Returns true if valid counter }
	function CounterFromWord(var c: TCounter; statId: integer; s: string): boolean;
	{ Reads value to c.Value }
	procedure CounterReadValue(var c: TCounter);
	{ Writes value from c.Value }
	function CounterWriteValue(var c: TCounter): boolean;
	procedure ScheduledUpdatesApply;

implementation
uses GameVars, Elements, Game;

function ElementRead(var c: TCounter): integer;
	var
		i, j: integer;
		t,u: string[20];
	begin
		ElementRead := -32767;
		for i := 4 to 12 do
			if (c.Entry[i] = '.') and (i <= Length(c.Entry)) then j := i;
		for i := 1 to j - 1 do
			t[i] := UpCase(c.Entry[i]);
		t[0] := Chr(j - 1);
		for i := j + 1 to Length(c.Entry) do
			u[i - j] := UpCase(c.Entry[i]);
		u[0] := Chr(Length(c.Entry) - j);
		for i := 1 to MAX_ELEMENT do
			if XDat.EDefs[i].Name = t then
				ElementRead := ElementGet(i,u);
	end;

procedure ElementWrite(var c: TCounter);
	var
		i, j: integer;
		t, u, v: string[20];
	begin
		Str(c.Value, v);
		for i := 4 to 12 do
			if (c.Entry[i] = '.') and (i <= Length(c.Entry)) then j := i;
		for i := 1 to j - 1 do
			t[i] := UpCase(c.Entry[i]);
		t[0] := Chr(j - 1);
		for i := j + 1 to Length(c.Entry) do
			u[i - j] := UpCase(c.Entry[i]);
		u[0] := Chr(Length(c.Entry) - j);
		for i := 1 to MAX_ELEMENT do
			if XDat.EDefs[i].Name = t then begin
				ElementMod(i, u, v, -1);
				scheduledUpdates.UpdateTheme := true;
				scheduledUpdates.UpdateBoard := true;
				exit;
			end;
	end;

function CounterFromWord(var c: TCounter; statId: integer; s: string): boolean;
	var
		i, lo, hi, mid: integer;
		sfound: boolean;
	begin
		if length(s) < 1 then begin
			CounterFromWord := false;
			exit;
		end;

		c.UpdateBoard := false;
		c.UpdateTheme := false;
		c.Entry := s;
		c.CType := TCInteger;
		sfound := true;

		case s[1] of
			'A':
				if s = 'AMMO' then c.Pointer := @World.Info.Ammo
				else if s = 'ARRAY' then c.Pointer := @Board.Stats[statId].ObjArray
				else if s = 'ARG' then begin
					c.CType := TCReadOnly;
					c.Value := GlobalArg;
				end else if s[5] = '.' then begin
					c.CType := TCConfig;
					if s = 'AMMO.MSG.TOUCH' then c.Value := 24
					else if s = 'AMMO.SND.TOUCH' then c.Value := 25
					else sfound := false;
				end else
					sfound := false;
			'B':
				if s = 'BLUEKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[1];
				end else if s = 'BOARDID' then begin
					c.CType := TCReadOnly;
					c.Value := World.Info.CurrentBoard;
				end else if s = 'BREAKABLE.SND' then begin
					c.CType := TCConfig;
					c.Value := 56;
				end else if s[5] = '.' then begin
					c.CType := TCConfig;
					if s = 'BOMB.MSG.TOUCH' then c.Value := 1
					else if s = 'BOMB.SND.TOUCH' then c.Value := 2
					else if s = 'BOMB.SND.TICK' then c.Value := 3
					else if s = 'BOMB.SND.TOCK' then c.Value := 4
					else if s = 'BOMB.SND.EXPLODE' then c.Value := 5
					else sfound := false;
				end else
					sfound := false;
			'C':
				if s = 'CYANKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[3];
				end else if s = 'CANTSHOOT.MSG' then begin
					c.CType := TCConfig;
					c.Value := 40;
				end else if s = 'CHEAT.SND' then begin
					c.CType := TCConfig;
					c.Value := 59;
				end else if s[8] = '.' then begin
					c.CType := TCConfig;
					if s = 'COUNTER.HEALTH' then c.Value := 63
					else if s = 'COUNTER.AMMO' then c.Value := 64
					else if s = 'COUNTER.TORCHES' then c.Value := 65
					else if s = 'COUNTER.GEMS' then c.Value := 66
					else if s = 'COUNTER.SCORE' then c.Value := 67
					else if s = 'COUNTER.KEYS' then c.Value := 68
					else if s = 'COUNTER.TIME' then c.Value := 69
					else sfound := false;
				end else
					sfound := false;
			'D':
				if s[5] = '.' then begin
					c.CType := TCConfig;
					if s = 'DOOR.MSG.TOUCH1' then c.Value := 18
					else if s = 'DOOR.MSG.TOUCH2' then c.Value := 19
					else if s = 'DOOR.SND.TOUCH' then c.Value := 20
					else if s = 'DOOR.MSG.FAIL1' then c.Value := 21
					else if s = 'DOOR.MSG.FAIL2' then c.Value := 22
					else if s = 'DOOR.SND.FAIL' then c.Value := 23
					else sfound := false;
				end else if s = 'DARKBOARD.MSG' then begin
					c.CType := TCConfig;
					c.Value := 46;
				end else if s = 'DUPLICATOR.SND' then begin
					c.CType := TCConfig;
					c.Value := 50;
				end else if s = 'DUPEBLOCKED.SND' then begin
					c.CType := TCConfig;
					c.Value := 51;
				end else if s = 'DEFAULT.OBJECT.NAME' then begin
					c.CType := TCConfig;
					c.Value := 84;
				end else if s = 'DEFAULT.SCROLL.NAME' then begin
					c.CType := TCConfig;
					c.Value := 85;
				end else
					sfound := false;
			'E':
				if s = 'EDGEN' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Info.NeighborBoards[0];
				end else if s = 'EDGES' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Info.NeighborBoards[1];
				end else if s = 'EDGEW' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Info.NeighborBoards[2];
				end else if s = 'EDGEE' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Info.NeighborBoards[3];
				end else if s = 'ENERGIZED' then c.Pointer := @World.Info.EnergizerTicks
				else if s[6] = '.' then begin
					c.CType := TCConfig;
					if s = 'ERROR.MSG' then c.Value := 57
					else if s = 'ERROR.SND' then c.Value := 58
					else sfound := false;
				end else if s[10] = '.' then begin
					c.CType := TCConfig;
					if s = 'ENERGIZER.MSG.TOUCH' then c.Value := 6
					else if s = 'ENERGIZER.SND.START' then c.Value := 7
					else if s = 'ENERGIZER.SND.SONG' then c.Value := 8
					else if s = 'ENERGIZER.SND.END' then c.Value := 11
					else sfound := false;
				end else
					sfound := false;
			'F':
				if s = 'FAKE.MSG.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 35;
				end else if s = 'FOREST.MSG.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 33;
				end else if s = 'FOREST.SND.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 34;
				end else
					sfound := false;
			'G':
				if s = 'GREENKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[2];
				end else if s = 'GAMESPEED' then c.CType := TCTickSpeed
				else if s = 'GEMS' then	c.Pointer := @World.Info.Gems
				else if s = 'GEM.MSG.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 26;
				end else if s = 'GEM.SND.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 27;
				end else if s = 'GAMEOVER.MSG' then begin
					c.CType := TCConfig;
					c.Value := 38;
				end else if s = 'GAMEOVER.SND' then begin
					c.CType := TCConfig;
					c.Value := 39;
				end else
					sfound := false;
			'H':
				if s = 'HEALTH' then c.Pointer := @World.Info.Health
				else 
					sfound := false;
			'I':
				if s = 'ISDARK' then begin
					c.CType := TCShortInt;
					c.Pointer := @Board.Info.IsDark;
					c.UpdateBoard := true;
				end else if s = 'INVISIBLE.MSG.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 31;
				end else if s = 'INVISIBLE.SND.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 32;
				end else
					sfound := false;
			'K':
				if ((s[2] = 'E') and (s[3] = 'Y'))
					and ((s[4] = '.') or (s[5] = '.'))
				then begin
					c.CType := TCConfig;
					if s = 'KEY.MSG.TOUCH1' then c.Value := 12
					else if s = 'KEY.MSG.TOUCH2' then c.Value := 13
					else if s = 'KEY.SND.TOUCH' then c.Value := 14
					else if s = 'KEY.MSG.FAIL1' then c.Value := 15
					else if s = 'KEY.MSG.FAIL2' then c.Value := 16
					else if s = 'KEY.SND.FAIL' then c.Value := 17
					else if s = 'KEYS.TORCH.BIND' then c.Value := 70
					else if s = 'KEYS.TORCH.LABEL' then c.Value := 71
					else if s = 'KEYS.SOUND.BIND' then c.Value := 72
					else if s = 'KEYS.SOUND.LABEL.ON' then c.Value := 73
					else if s = 'KEYS.SOUND.LABEL.OFF' then c.Value := 74
					else if s = 'KEYS.HELP.BIND' then c.Value := 75
					else if s = 'KEYS.HELP.LABEL' then c.Value := 76
					else if s = 'KEYS.SAVE.BIND' then c.Value := 77
					else if s = 'KEYS.SAVE.LABEL' then c.Value := 78
					else if s = 'KEYS.PAUSE.BIND' then c.Value := 79
					else if s = 'KEYS.PAUSE.LABEL' then c.Value := 80
					else if s = 'KEYS.CHEAT.BIND' then c.Value := 83
					else sfound := false;
				end else
					sfound := false;
			'L':
				if s = 'LOCAL1' then c.Pointer := @Board.Info.Local[1]
				else if s = 'LOCAL2' then c.Pointer := @Board.Info.Local[2]
				else if s = 'LOCAL3' then c.Pointer := @Board.Info.Local[3]
				else if s = 'LOCAL4' then c.Pointer := @Board.Info.Local[4]
				else if s = 'LOCAL5' then c.Pointer := @Board.Info.Local[5]
				else if s = 'LOCAL6' then c.Pointer := @Board.Info.Local[6]
				else if s = 'LOCAL7' then c.Pointer := @Board.Info.Local[7]
				else if s = 'LOWTIMER.MSG' then begin
					c.CType := TCConfig;
					c.Value := 54;
				end else if s = 'LOWTIMER.SND' then begin
					c.CType := TCConfig;
					c.Value := 55;
				end else
					sfound := false;
			'M':
				if s = 'MAXBULLETS' then begin
					c.CType := TCShortInt;
					c.Pointer := @Board.Info.MaxShots;
				end else if s = 'MOUSEX' then begin
					c.CType := TCReadOnly;
					c.Value := PMouseX;
				end else if s = 'MOUSEY' then begin
					c.CType := TCReadOnly;
					c.Value := PMouseY;
				end else 
					sfound := false;
			'N':
				if s = 'NOTDARK.MSG' then begin
					c.CType := TCConfig;
					c.Value := 44;
				end else
					sfound := false;
			'O':
				if s = 'OBJ1' then c.Pointer := @Board.Stats[statId].ObjLocal[1]
				else if s = 'OBJ2' then c.Pointer := @Board.Stats[statId].ObjLocal[2]
				else if s = 'OBJ3' then c.Pointer := @Board.Stats[statId].ObjLocal[3]
				else if s = 'OBJ4' then c.Pointer := @Board.Stats[statId].ObjLocal[4]
				else if s = 'OBJ5' then c.Pointer := @Board.Stats[statId].Leader
				else if s = 'OBJ6' then c.Pointer := @Board.Stats[statId].Follower
				else if s = 'OUTOFAMMO.MSG' then begin
					c.CType := TCConfig;
					c.Value := 41;
				end else if s = 'OBJECTSHOOT.SND' then begin
					c.CType := TCConfig;
					c.Value := 43;
				end else if s = 'OUTOFTORCHES.MSG' then begin
					c.CType := TCConfig;
					c.Value := 45;
				end else if s[6] = '.' then begin
					c.UpdateBoard := true;
					if s = 'OTHER.FOOTSTEPS' then c.Pointer := @XDat.Params[1]
					else if s = 'OTHER.OUCHDAMAGE' then c.Pointer := @XDat.Params[2]
					else if s = 'OTHER.TORCHRATIOX' then c.Pointer := @XDat.Params[3]
					else if s = 'OTHER.TORCHRATIOY' then c.Pointer := @XDat.Params[4]
					else if s = 'OTHER.TORCHSIZE' then c.Pointer := @XDat.Params[5]
					else if s = 'OTHER.BOMBRATIOX' then c.Pointer := @XDat.Params[6]
					else if s = 'OTHER.BOMBRATIOY' then c.Pointer := @XDat.Params[7]
					else if s = 'OTHER.BOMBSIZE' then c.Pointer := @XDat.Params[8]
					else if s = 'OTHER.STRICTWINDOW' then c.Pointer := @XDat.Params[9]
					else if s = 'OTHER.MAXOOP' then c.Pointer := @XDat.Params[10]
					else if s = 'OTHER.GRACEPERIOD' then c.Pointer := @XDat.Params[11]
					else if s = 'OTHER.FRIENDLYFIRE' then c.Pointer := @XDat.Params[12]
					else if s = 'OTHER.STARTBOARD' then c.Pointer := @XDat.Params[21]
					else if s = 'OTHER.HIGHSCORES' then c.Pointer := @XDat.Params[22]
					else if s = 'OTHER.STRICTLOCK' then c.Pointer := @XDat.Params[23]
					else if s = 'OTHER.TEXTWINDOW' then c.Pointer := @XDat.Params[24]
					else if s = 'OTHER.STRICTARRAY' then c.Pointer := @XDat.Params[25]
					else if s = 'OTHER.SOFTSHOVE' then c.Pointer := @XDat.Params[26]
					else sfound := false;
				end else 
					sfound := false;
			'P':
				if s = 'PURPLEKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[5];
				end else if s = 'PLAYERX' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Stats[0].X;
				end else if s = 'PLAYERY' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Stats[0].Y;
				end else if s = 'PLAYERSHOOT.SND' then begin
					c.CType := TCConfig;
					c.Value := 42;
				end else if s = 'PLAYERHURT.MSG' then begin
					c.CType := TCConfig;
					c.Value := 48;
				end else if s = 'PLAYERHURT.SND' then begin
					c.CType := TCConfig;
					c.Value := 49;
				end else if s = 'PUSH.SND' then begin
					c.CType := TCConfig;
					c.Value := 52;
				end else if s = 'PASSAGE.SND' then begin
					c.CType := TCConfig;
					c.Value := 61;
				end else
					sfound := false;
			'R':
				if s = 'REDKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[4];
				end else if s = 'RICOCHET.SND' then begin
					c.CType := TCConfig;
					c.Value := 53;
				end else 
					sfound := false;
			'S':
				if s = 'SCORE' then c.Pointer := @World.Info.Score
				else if s = 'STATDEATH.SND' then begin
					c.CType := TCConfig;
					c.Value := 47;
				end else if s = 'SCROLL.SND' then begin
					c.CType := TCConfig;
					c.Value := 60;
				end else if (s[8] = '.') and
					((s[10] = '.') or (s[11] = '.'))
				then begin
					c.CType := TCConfig;
					c.Entry := 'SIDEBAR';
					if s = 'SIDEBAR.3.COUNTER' then c.Value := 103
					else if s = 'SIDEBAR.4.COUNTER' then c.Value := 104
					else if s = 'SIDEBAR.5.COUNTER' then c.Value := 105
					else if s = 'SIDEBAR.6.COUNTER' then c.Value := 106
					else if s = 'SIDEBAR.7.COUNTER' then c.Value := 107
					else if s = 'SIDEBAR.8.COUNTER' then c.Value := 108
					else if s = 'SIDEBAR.9.COUNTER' then c.Value := 109
					else if s = 'SIDEBAR.10.COUNTER' then c.Value := 110
					else if s = 'SIDEBAR.11.COUNTER' then c.Value := 111
					else if s = 'SIDEBAR.12.COUNTER' then c.Value := 112
					else if s = 'SIDEBAR.13.COUNTER' then c.Value := 113
					else if s = 'SIDEBAR.14.COUNTER' then c.Value := 114
					else if s = 'SIDEBAR.15.COUNTER' then c.Value := 115
					else if s = 'SIDEBAR.16.COUNTER' then c.Value := 116
					else if s = 'SIDEBAR.17.COUNTER' then c.Value := 117
					else if s = 'SIDEBAR.18.COUNTER' then c.Value := 118
					else if s = 'SIDEBAR.19.COUNTER' then c.Value := 119
					else if s = 'SIDEBAR.20.COUNTER' then c.Value := 120
					else if s = 'SIDEBAR.21.COUNTER' then c.Value := 121
					else if s = 'SIDEBAR.22.COUNTER' then c.Value := 122
					else if s = 'SIDEBAR.23.COUNTER' then c.Value := 123
					else if s = 'SIDEBAR.24.COUNTER' then c.Value := 124
					else sfound := false;
				end else 
					sfound := false;
			'T':
				if (s = 'TICKSPEED') then c.CType := TCTickSpeed
				else if s = 'THISX' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Stats[statId].X;
				end else if s = 'THISY' then begin
					c.CType := TCReadOnly;
					c.Value := Board.Stats[statId].Y;
				end else if s = 'TORCHES' then c.Pointer := @World.Info.Torches
				else if s = 'TIME' then c.Pointer := @World.Info.BoardTimeSec
				else if s = 'TIMELIMIT' then c.Pointer := @Board.Info.TimeLimitSec
				else if s = 'TRANSPORTER.SND' then begin
					c.CType := TCConfig;
					c.Value := 62;
				end else if s[6] = '.' then begin
					c.CType := TCConfig;
					if s = 'TORCH.MSG.TOUCH' then c.Value := 28
					else if s = 'TORCH.SND.TOUCH' then c.Value := 29
					else if s = 'TORCH.SND.END' then c.Value := 30
					else if s = 'THEME.PAUSE.MSG' then c.Value := 81
					else if s = 'THEME.TITLEPROMPT' then c.Value := 82
					else if s = 'THEME.MOVE.MSG' then c.Value := 86
					else if s = 'THEME.SHOOT.MSG' then c.Value := 87
					else if s = 'THEME.SHIFT.MSG' then c.Value := 88
					else begin
						c.CType := TCInteger;
						c.UpdateBoard := true;
						c.UpdateTheme := true;
						if s = 'THEME.BG.SIDEBAR' then c.Pointer := @XDat.Params[13]
						else if s = 'THEME.FG.TEXT1' then c.Pointer := @XDat.Params[14]
						else if s = 'THEME.FG.TEXT2' then c.Pointer := @XDat.Params[15]
						else if s = 'THEME.FG.ALT' then c.Pointer := @XDat.Params[16]
						else if s = 'THEME.BG.ALT1' then c.Pointer := @XDat.Params[17]
						else if s = 'THEME.BG.ALT2' then c.Pointer := @XDat.Params[18]
						else if s = 'THEME.FG.SPECIAL' then c.Pointer := @XDat.Params[19]
						else if s = 'THEME.BLINKING' then c.Pointer := @XDat.Params[20]
						else sfound := false;
					end;
				end else
					sfound := false;
			'W':
				if s = 'WHITEKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[7];
				end else if s = 'WICK' then begin
					c.Pointer := @World.Info.TorchTicks;
					c.UpdateBoard := true;
				end else if s = 'WATER.MSG.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 36;
				end else if s = 'WATER.SND.TOUCH' then begin
					c.CType := TCConfig;
					c.Value := 37;
				end else 
					sfound := false;
			'Y':
				if s = 'YELLOWKEY' then begin
					c.CType := TCShortInt;
					c.Pointer := @World.Info.Keys[6];
				end else 
					sfound := false;
			else
				sfound := false
		end;
		if sfound then begin
			CounterFromWord := true;
			exit;
		end;
		c.CType := TCInteger;
		c.UpdateBoard := false;
		c.UpdateTheme := false;
	    lo := 1;
   		hi := CustomCounterIndexCount;
		while lo <= hi do begin
			mid := (lo + hi) shr 1;
			i := CustomCounterIndex[mid];
			if CustomCounterList[i] = s then begin
				c.Pointer := @World.Info.CustomCounters[i];
				CounterFromWord := true;
				exit;
			end else if CustomCounterList[i] < s then
				lo := mid + 1
			else
				hi := mid - 1;
		end;
		for i := 4 to 12 do
			if (i <= Length(s)) and (s[i] = '.') then begin
				c.CType := TCElement;
				CounterFromWord := true;
				exit;
			end;
		CounterFromWord := false;
	end;

procedure CounterReadValue(var c: TCounter);
	begin
		if c.CType = TCByte then
			c.Value := cByte(c.Pointer)^
		else if c.CType = TCShortInt then
			c.Value := cShortInt(c.Pointer)^
		else if c.CType = TCInteger then
			c.Value := cInteger(c.Pointer)^
		else if c.CType = TCElement then
			c.Value := ElementRead(c)
		else if c.CType = TCTickSpeed then
			c.Value := TickSpeed + 1;
	end;

function CounterWriteValue(var c: TCounter): boolean;
	begin
		CounterWriteValue := true;

		{ Copy counter update requests to scheduled updates }
		scheduledUpdates.UpdateBoard := scheduledUpdates.UpdateBoard or c.UpdateBoard;
		scheduledUpdates.UpdateTheme := scheduledUpdates.UpdateTheme or c.UpdateTheme;

		if c.CType = TCByte then
			cByte(c.Pointer)^ := c.Value
		else if c.CType = TCShortInt then
			cShortInt(c.Pointer)^ := c.Value
		else if c.CType = TCInteger then
			cInteger(c.Pointer)^ := c.Value
		else if c.CType = TCElement then
			ElementWrite(c)
		else if c.CType = TCTickSpeed then begin
			if c.Value <= 0 then
				TickSpeed := 0
			else
				TickSpeed := c.Value - 1;
			if TickSpeed = 8 then
				TickTimeDuration := 1
			else
				TickTimeDuration := TickSpeed * 4;
		end else
			CounterWriteValue := false;
	end;

procedure ScheduledUpdatesApply;
	begin
		if scheduledUpdates.UpdateTheme then
			GameDrawTheme;
		if scheduledUpdates.UpdateTheme or scheduledUpdates.UpdateSidebar then begin
			GameUpdateSidebar;
			if XDat.HasCustomSidebar then GameDrawCustomSidebar;
		end;
		if scheduledUpdates.UpdateBoard then
			TransitionDrawToBoard;
		scheduledUpdates.UpdateTheme := false;
		scheduledUpdates.UpdateSidebar := false;
		scheduledUpdates.UpdateBoard := false;
	end;

end.
