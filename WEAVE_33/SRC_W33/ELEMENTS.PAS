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

{$F+}
{$I-}
unit Elements;

interface
	uses GameVars;
	function AsColor(fg, bg: integer): byte;
	procedure ElementMove(oldX, oldY, newX, newY: integer);
	procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	function ElementDuplicate(srcX, srcY, dstX, dstY, statId: integer): boolean;
	procedure DrawBombSurroundings(x, y: integer; bombPhase: integer);
	procedure GamePromptEndPlay;
	procedure ResetMessageNotShownFlags;
	procedure InitElementsGame;
	procedure ElementMod(e: integer; par: string; op: string; statId: integer);
	function ElementGet(e: integer; par: string): integer;
	function StringConfigs(i: integer): string;
	function Enum(elem: integer): integer;
	function ElemDefColor(elem: integer): byte;

implementation
uses Crt, ZVideo, FileSel, FileSys, Sounds, ZInput, TxtWind,
{$IFDEF SDL2}AudioSim,{$ENDIF} Oop, Game, ObjTrack;

const
	TransporterNSChars: string[8] = '^~^-v_v-';
	TransporterEWChars: string[8] = '(<('#179')>)'#179;
	StarAnimChars: string[4] = #179'/'#196'\';

function AsColor(fg, bg: integer): byte;
	begin
		AsColor := ((bg * 16) + fg) and $FF;
	end;

procedure ElemDefaultTick(statId: integer);
	begin
	end;

procedure ElemDefaultTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
	end;

procedure ElemDefaultDraw(x, y: integer; var ch: byte);
	begin
		ch := Ord('?');
	end;

procedure ElementDamagingTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardAttack(sourceStatId, x, y);
	end;

procedure ElementLionTick(statId: integer);
	var
		deltaX, deltaY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 < Random(10) then
				CalcDirectionRnd(deltaX, deltaY)
			else
				CalcDirectionSeek(X, Y, deltaX, deltaY);

			if XDat.EDefs[Enum(Board.Tiles[X + deltaX][Y + deltaY].Element)].Walkable then begin
				MoveStat(statId, X + deltaX, Y + deltaY);
			end else if Board.Tiles[X + deltaX][Y + deltaY].Element = E_PLAYER then begin
				BoardAttack(statId, X + deltaX, Y + deltaY)
			end;
		end;
	end;

procedure ElementTigerTick(statId: integer);
	var
		shot: boolean;
		element: byte;
	begin
		with Board.Stats[statId] do begin
			element := E_BULLET;
			if P2 >= $80 then
				element := E_STAR;

			if (Random(10) * 3) <= (P2 mod $80) then begin
				if Difference(X, Board.Stats[0].X) <= 2 then begin
					shot := BoardShoot(element, X, Y, 0, Signum(Board.Stats[0].Y - Y), SHOT_SOURCE_ENEMY);
				end else begin
					shot := false;
				end;

				if not shot then begin
					if Difference(Y, Board.Stats[0].Y) <= 2 then begin
						shot := BoardShoot(element, X, Y, Signum(Board.Stats[0].X - X), 0, SHOT_SOURCE_ENEMY);
					end;
				end;
			end;

			ElementLionTick(statId);
		end;
	end;

procedure ElementRuffianTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if (StepX = 0) and (StepY = 0) then begin
				if (P2 + 8) <= Random(17) then begin
					if P1 >= Random(9) then
						CalcDirectionSeek(X, Y, StepX, StepY)
					else
						CalcDirectionRnd(StepX, StepY);
				end;
			end else begin
				if ((Y = Board.Stats[0].Y) or (X = Board.Stats[0].X)) and (Random(9) <= P1) then begin
					CalcDirectionSeek(X, Y, StepX, StepY);
				end;

				with Board.Tiles[X + StepX][Y + StepY] do begin
					if Element = E_PLAYER then begin
						BoardAttack(statId, X + StepX, Y + StepY)
					end else if XDat.EDefs[Enum(Element)].Walkable then begin
						MoveStat(statId, X + StepX, Y + StepY);
						if (P2 + 8) <= Random(17) then begin
							StepX := 0;
							StepY := 0;
						end;
					end else begin
						StepX := 0;
						StepY := 0;
					end;
				end;

			end;
		end;
	end;

procedure ElementBearTick(statId: integer);
	var
		deltaX, deltaY: integer;
	label Movement;
	begin
		with Board.Stats[statId] do begin
			if X <> Board.Stats[0].X then
				if Difference(Y, Board.Stats[0].Y) <= (8 - P1) then begin
					deltaX := Signum(Board.Stats[0].X - X);
					deltaY := 0;
					goto Movement;
				end;

			if Difference(X, Board.Stats[0].X) <= (8 - P1) then begin
				deltaY := Signum(Board.Stats[0].Y - Y);
				deltaX := 0;
			end else begin
				deltaX := 0;
				deltaY := 0;
			end;

		Movement:
			with Board.Tiles[X + deltaX][Y + deltaY] do begin
				if XDat.EDefs[Enum(Element)].Walkable then begin
					MoveStat(statId, X + deltaX, Y + deltaY);
				end else if (Element = E_PLAYER) or (Element = E_BREAKABLE) then begin
					BoardAttack(statId, X + deltaX, Y + deltaY)
				end;
			end;

		end;
	end;

procedure ElementCentipedeHeadTick(statId: integer);
	var
		ix, iy: integer;
		tx, ty: integer;
		tmp: integer;
	begin
		with Board.Stats[statId] do begin
			if (X = Board.Stats[0].X) and (Random(10) < P1) then begin
				StepY := Signum(Board.Stats[0].Y - Y);
				StepX := 0;
			end else if (Y = Board.Stats[0].Y) and (Random(10) < P1) then begin
				StepX := Signum(Board.Stats[0].X - X);
				StepY := 0;
			end else if ((Random(10) * 4) < P2) or ((StepX = 0) and (StepY = 0)) then begin
				CalcDirectionRnd(StepX, StepY);
			end;

			if not XDat.EDefs[Enum(Board.Tiles[X + StepX][Y + StepY].Element)].Walkable
				and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
			begin
				ix := StepX;
				iy := StepY;
				tmp := ((Random(2) * 2) - 1) * StepY;
				StepY := ((Random(2) * 2) - 1) * StepX;
				StepX := tmp;
				if not XDat.EDefs[Enum(Board.Tiles[X + StepX][Y + StepY].Element)].Walkable
					and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
				begin
					StepX := -StepX;
					StepY := -StepY;
					if not XDat.EDefs[Enum(Board.Tiles[X + StepX][Y + StepY].Element)].Walkable
						and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
					begin
						if XDat.EDefs[Enum(Board.Tiles[X - ix][Y - iy].Element)].Walkable
							or (Board.Tiles[X - ix][Y - iy].Element = E_PLAYER) then
						begin
							StepX := -ix;
							StepY := -iy;
						end else begin
							StepX := 0;
							StepY := 0;
						end;
					end;
				end;
			end;

			if (StepX = 0) and (StepY = 0) then begin
				Board.Tiles[X][Y].Element := E_CENTIPEDE_SEGMENT;
				Leader := -1;
				while Board.Stats[statId].Follower > 0 do begin
					tmp := Board.Stats[statId].Follower;
					Board.Stats[statId].Follower := Board.Stats[statId].Leader;
					Board.Stats[statId].Leader := tmp;
					statId := tmp;
				end;
				Board.Stats[statId].Follower := Board.Stats[statId].Leader;
				Board.Tiles[Board.Stats[statId].X][Board.Stats[statId].Y].Element := E_CENTIPEDE_HEAD;
			end else if Board.Tiles[X + StepX][Y + StepY].Element = E_PLAYER then begin
				if Follower <> -1 then begin
					Board.Tiles[Board.Stats[Follower].X][Board.Stats[Follower].Y].Element := E_CENTIPEDE_HEAD;
					Board.Stats[Follower].StepX := StepX;
					Board.Stats[Follower].StepY := StepY;
					BoardDrawTile(Board.Stats[Follower].X, Board.Stats[Follower].Y);
				end;
				BoardAttack(statId, X + StepX, Y + StepY);
			end else begin
				MoveStat(statId, X + StepX, Y + StepY);
				tx := X - StepX;
				ty := Y - StepY;
				ix := StepX;
				iy := StepY;

				repeat
					with Board.Stats[statId] do begin
						tx := X - StepX;
						ty := Y - StepY;
						ix := StepX;
						iy := StepY;
						if Follower < 0 then begin
							if (Board.Tiles[tx - ix][ty - iy].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx - ix, ty - iy)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx - ix, ty - iy)
							end else if (Board.Tiles[tx - iy][ty - ix].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx - iy, ty - ix)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx - iy, ty - ix);
							end else if (Board.Tiles[tx + iy][ty + ix].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx + iy, ty + ix)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx + iy, ty + ix);
							end;
						end;

						if Follower > 0 then begin
							Board.Stats[Follower].Leader := statId;
							Board.Stats[Follower].P1 := P1;
							Board.Stats[Follower].P2 := P2;
							Board.Stats[Follower].StepX := tx - Board.Stats[Follower].X;
							Board.Stats[Follower].StepY := ty - Board.Stats[Follower].Y;
							MoveStat(Follower, tx, ty);
						end;
						statId := Follower;
					end;
				until statId = -1;
			end;
		end;
	end;

procedure ElementCentipedeSegmentTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if Leader < 0 then begin
				if Leader < -1 then
					Board.Tiles[X][Y].Element := E_CENTIPEDE_HEAD
				else
					Leader := Leader - 1;
			end;
		end;
	end;

procedure ElementBulletTick(statId: integer);
	var
		ix, iy: integer;
		iStat: integer;
		iElem: byte;
		firstTry: boolean;
	label TryMove;
	label BulletExpire;
	begin
		with Board.Stats[statId] do begin
			if P2 < XDat.EDefs[E_BULLET].P1 then
				goto BulletExpire
			else
				Dec(P2, XDat.EDefs[E_BULLET].P1);
			firstTry := true;

		TryMove:
			ix := X + StepX;
			iy := Y + StepY;
			if (ix <= 0) or (ix > BOARD_WIDTH) or (iy <= 0) or (iy > BOARD_HEIGHT) then goto BulletExpire;
			iElem := Board.Tiles[ix][iy].Element;

			if XDat.EDefs[Enum(iElem)].Walkable or (iElem = E_WATER) then begin
				MoveStat(statId, ix, iy);
				exit;
			end;

			if (iElem = E_RICOCHET) and firstTry then begin
				StepX := -StepX;
				StepY := -StepY;
				SoundQueue(1, SoundParse(XDat.Configs[53])); {Ricochet sound}
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (iElem = E_BREAKABLE)
				or (XDat.EDefs[Enum(iElem)].CanShoot and ((iElem = E_PLAYER) or (P1 = 0))) then
			begin
				if XDat.EDefs[Enum(iElem)].ScoreValue <> 0 then begin
					Inc(World.Info.Score, XDat.EDefs[Enum(iElem)].ScoreValue);
					GameUpdateSidebar;
				end;
				BoardAttack(statId, ix, iy);
				exit;
			end;

			if (Board.Tiles[X + StepY][Y + StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := -StepY;
				StepY := -ix;
				SoundQueue(1, SoundParse(XDat.Configs[53])); {Ricochet sound}
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (Board.Tiles[X - StepY][Y - StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := StepY;
				StepY := ix;
				SoundQueue(1, SoundParse(XDat.Configs[53])); {Ricochet sound}
				firstTry := false;
				goto TryMove;
				exit;
			end;

		BulletExpire:
			if (iElem = E_OBJECT) or (iElem = E_SCROLL) then begin
				if (P1 = XDat.Params[12]) or (P1 = SHOT_SOURCE_PLAYER) then begin {Friendly Fire}
					iStat := GetStatIdAt(ix, iy);
					if OopSend(-iStat, 'SHOT', false) then begin end;
				end;
			end;
			RemoveStat(statId);
			{ Dec(CurrentStatTicked); }
		end;
	end;

procedure ElementSpinningGunDraw(x, y: integer; var ch: byte);
	begin
		case CurrentTick mod 8 of
			0, 1: ch := 24;
			2, 3: ch := 26;
			4, 5: ch := 25;
		else ch := 27 end;
	end;

procedure ElementLineDraw(x, y: integer; var ch: byte);
	var
		i, v, shift: integer;
	begin
		v := 1;
		shift := 1;
		for i := 0 to 3 do begin
			case Board.Tiles[x + NeighborDeltaX[i]][y + NeighborDeltaY[i]].Element of
				E_LINE, E_BOARD_EDGE: v := v + shift;
			end;
			shift := shift shl 1;
		end;
		ch := Ord(LineChars[v]);
	end;

procedure ElementDoorDraw(x, y: integer; var ch: byte);
	var
		key: integer;
	begin
		key := (Board.Tiles[x][y].Color div 16) mod 8;
		if Diffkeys then
			ch := 132 + key
		else
			ch := Ord(XDat.EDefs[E_DOOR].Character) + (key * XDat.EDefs[E_DOOR].P2);
	end;

procedure ElementKeyDraw(x, y: integer; var ch: byte);
	var
		key: integer;
	begin
		key := Board.Tiles[x][y].Color mod 8;
		if Diffkeys then
			ch := 139 + key
		else
			ch := Ord(XDat.EDefs[E_KEY].Character) + (key * XDat.EDefs[E_KEY].P2);
	end;

procedure ElementSpinningGunTick(statId: integer);
	var
		shot: boolean;
		deltaX, deltaY: integer;
		element: byte;
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);

			element := E_BULLET;
			if P2 >= $80 then
				element := E_STAR;

			if Random(9) < (P2 mod $80) then begin
				if Random(9) <= P1 then begin
					if Difference(X, Board.Stats[0].X) <= 2 then begin
						shot := BoardShoot(element, X, Y, 0, Signum(Board.Stats[0].Y - Y), SHOT_SOURCE_ENEMY);
					end else begin
						shot := false;
					end;

					if not shot then begin
						if Difference(Y, Board.Stats[0].Y) <= 2 then begin
							shot := BoardShoot(element, X, Y, Signum(Board.Stats[0].X - X), 0, SHOT_SOURCE_ENEMY);
						end;
					end;
				end else begin
					CalcDirectionRnd(deltaX, deltaY);
					shot := BoardShoot(element, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY);
				end;
			end;
		end;
	end;

procedure ElementConveyorTick(x, y: integer; direction: integer);
	var
		i: integer;
		iStat: integer;
		ix, iy: integer;
		canMove: boolean;
		tiles: array[0..7] of TTile;
		statIds: array[0..7] of integer;
		iMin, iMax: integer;
		tmpTile: TTile;
		tx, ty: integer;
	begin
		if direction = 1 then begin
			iMin := 0;
			iMax := 8;
		end else begin
			iMin := 7;
			iMax := -1;
		end;

		{ Moved from CWTick/CCWTick }
		BoardDrawTile(X, Y);

		canMove := true;
		i := iMin;
		repeat
			tx := x + DiagonalDeltaX[i];
			ty := y + DiagonalDeltaY[i];
			tiles[i] := Board.Tiles[tx][ty];
			with tiles[i] do begin
				if Element = E_EMPTY then
					canMove := true
				else if not XDat.EDefs[Enum(Element)].Pushable then
					canMove := false;
				{ FIX: In some cases, a movement could cause two stats to briefly overlap each other. }
				{ Pre-find stat IDs to prevent such a scenario from occuring. }
				statIds[i] := GetStatIdAt(tx, ty);
			end;
			Inc(i, direction);
		until i = iMax;

		i := iMin;
		repeat
			with tiles[i] do begin
				if canMove then begin
					if XDat.EDefs[Enum(Element)].Pushable or (Element = E_EMPTY) then begin
						ix := x + DiagonalDeltaX[(i - direction) and 7];
						iy := y + DiagonalDeltaY[(i - direction) and 7];
						tx := x + DiagonalDeltaX[i];
						ty := y + DiagonalDeltaY[i];

						if statIds[i] >= 0 then begin
							tmpTile := Board.Tiles[tx][ty];
							Board.Tiles[tx][ty] := tiles[i];
							Board.Tiles[ix][iy].Element := E_EMPTY;
							MoveStat(statIds[i], ix, iy);

							Board.Tiles[tx][ty] := tmpTile;
							{ FIX: Add missing BoardDrawTile. }
							BoardDrawTile(tx, ty);
						end else begin
							Board.Tiles[ix][iy] := tiles[i];
							BoardDrawTile(ix, iy);
						end;
						if not (XDat.EDefs[Enum(tiles[(i + direction) and 7].Element)].Pushable
							or (tiles[(i + direction) and 7].Element = E_EMPTY))
						then begin
							Board.Tiles[tx][ty].Element := E_EMPTY;
							BoardDrawTile(tx, ty);
						end;
					end else begin
						canMove := false;
					end;
				end else if Element = E_EMPTY then
					canMove := true
				else if not (XDat.EDefs[Enum(Element)].Pushable or (Element = E_EMPTY)) then
					canMove := false;
			end;
			Inc(i, direction);
		until i = iMax;
	end;

procedure ElementConveyorCWDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick div XDat.EDefs[E_CONVEYOR_CW].Cycle) and 3 of
			0: ch := 179;
			1: ch := 47;
			2: ch := 196;
		else ch := 92 end;
	end;

procedure ElementConveyorCWTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			ElementConveyorTick(X, Y, 1);
		end;
	end;

procedure ElementConveyorCCWDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick div XDat.EDefs[E_CONVEYOR_CCW].Cycle) and 3 of
			3: ch := 179;
			2: ch := 47;
			1: ch := 196;
		else ch := 92 end;
	end;

procedure ElementConveyorCCWTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			ElementConveyorTick(X, Y, -1);
		end;
	end;

procedure ElementBombDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			if P1 <= 1 then
				ch := Ord(XDat.EDefs[E_BOMB].Character)
			else
				ch := 48 + P1;
	end;

procedure ElementBombTick(statId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 > 0 then begin
				P1 := P1 - 1;
				BoardDrawTile(X, Y);

				if P1 = 1 then begin
					SoundQueue(1, SoundParse(XDat.Configs[5])); {Bomb explode sound}
					DrawBombSurroundings(X, Y, 1);
				end else if P1 = 0 then begin
					oldX := X;
					oldY := Y;
					RemoveStat(statId);
					DrawBombSurroundings(oldX, oldY, 2);
				end else begin
					if (P1 mod 2) = 0 then
						SoundQueue(1, SoundParse(XDat.Configs[4])) {Bomb tock}
					else
						SoundQueue(1, SoundParse(XDat.Configs[3])); {Bomb tick}
				end;
			end;
		end;
	end;

procedure ElementBombTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if P1 = 0 then begin
				P1 := 9;
				BoardDrawTile(X, Y);
				DisplayMessage(200, XDat.Configs[1]); {"Bomb Activated!"}
				SoundQueue(4, SoundParse(XDat.Configs[2])); {Bomb activate sound}
			end else begin
				ElementPushablePush(X, Y, deltaX, deltaY);
			end;
		end;
	end;

procedure ElementTransporterMove(x, y, deltaX, deltaY: integer);
	var
		ix, iy: integer;
		newX, newY: integer;
		iStat: integer;
		finishSearch: boolean;
		isValidDest: boolean;
	begin
		with Board.Stats[GetStatIdAt(x + deltaX, y + deltaY)] do begin
			if (deltaX = StepX) and (deltaY = StepY) then begin
				ix := X;
				iy := Y;
				newX := -1;
				finishSearch := false;
				isValidDest := true;
				repeat
					ix := ix + deltaX;
					iy := iy + deltaY;
					with Board.Tiles[ix][iy] do begin
						if Element = E_BOARD_EDGE then
							finishSearch := true
						else if isValidDest then begin
							isValidDest := false;

							if not XDat.EDefs[Enum(Element)].Walkable then
								ElementPushablePush(ix, iy, deltaX, deltaY);

							if XDat.EDefs[Enum(Element)].Walkable then begin
								finishSearch := true;
								newX := ix;
								newY := iy;
							end else begin
								newX := -1
							end;
						end;
						if Element = E_TRANSPORTER then begin
							iStat := GetStatIdAt(ix, iy);
							if (Board.Stats[iStat].StepX = -deltaX) and (Board.Stats[iStat].StepY = -deltaY) then
								isValidDest := true;
						end;
					end;
				until finishSearch;
				if newX <> -1 then begin
					ElementMove(X - deltaX, Y - deltaY, newX, newY);
					SoundQueue(3, SoundParse(XDat.Configs[62])); {Transporter sound}
				end;
			end;
		end;
	end;

procedure ElementTransporterTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementTransporterMove(x - deltaX, y - deltaY, deltaX, deltaY);
		deltaX := 0;
		deltaY := 0;
	end;

procedure ElementTransporterTick(statId: integer);
	begin
		with Board.Stats[statId] do
			BoardDrawTile(X, Y);
	end;

procedure ElementTransporterDraw(x, y: integer; var ch: byte);
	var
		i: integer;
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if Cycle = 0 then
				i := 0
			else
				i := (CurrentTick div Cycle) and 3;

			ch := 0;
			if StepX = 0 then begin
				i := StepY * 2 + 3 + i;
				if (i >= 1) and (i <= 8) then
					ch := Ord(TransporterNSChars[i]);
			end else begin
				i := StepX * 2 + 3 + i;
				if (i >= 1) and (i <= 8) then
					ch := Ord(TransporterEWChars[i]);
			end;
		end;
	end;

procedure ElementStarDraw(x, y: integer; var ch: byte);
	begin
		ch := Ord(StarAnimChars[(CurrentTick mod 4) + 1]);
		Board.Tiles[x][y].Color := Board.Tiles[x][y].Color + 1;
		if Board.Tiles[x][y].Color > 15 then
			Board.Tiles[x][y].Color := 9;
	end;

procedure ElementPlayerDraw(x, y: integer; var ch: byte);
	begin
		if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then begin
			World.Info.PlayerChar := XDat.EDefs[E_PLAYER].Character;
			World.Info.PlayerColor := XDat.EDefs[E_PLAYER].Color;
		end;

		ch := Ord(World.Info.PlayerChar);

		if (x = Board.Stats[0].X) and (y = Board.Stats[0].Y) then begin
			Board.Tiles[x][y].Color := World.Info.PlayerColor;
			if World.Info.EnergizerTicks > 0 then begin
				Board.Tiles[x][y].Color := AsColor(World.Info.PlayerColor and $0F,(CurrentTick mod 7) + 1);
				if (CurrentTick mod 2) <> 0 then
					ch := XDat.Params[1];
			end;
		end;
	end;


procedure ElementStarTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if P2 < XDat.EDefs[E_STAR].P1 then {Star Health Drain}
				RemoveStat(statId)
			else begin
				Dec(P2, XDat.EDefs[E_STAR].P1);
				if (P2 mod 2) = 0 then begin
					CalcDirectionSeek(X, Y, StepX, StepY);
					with Board.Tiles[X + StepX][Y + StepY] do begin
						if (Element = E_PLAYER) or (Element = E_BREAKABLE) then begin
							BoardAttack(statId, X + StepX, Y + StepY);
						end else begin
							if not XDat.EDefs[Enum(Element)].Walkable then
								ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);

							if XDat.EDefs[Enum(Element)].Walkable or (Element = E_WATER) then
								MoveStat(statId, X + StepX, Y + StepY);
						end;
					end;
				end;
			end;
			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementEnergizerTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		SoundQueue(9, SoundParse(XDat.Configs[7]) {Energizer Song}
			+ SoundParse(XDat.Configs[8])
			+ SoundParse(XDat.Configs[9])
			+ SoundParse(XDat.Configs[10]));

		Board.Tiles[x][y].Element := XDat.EDefs[E_ENERGIZER].P3;
		BoardDrawTile(x, y);

		World.Info.EnergizerTicks := XDat.EDefs[E_ENERGIZER].P1; 
		GameUpdateSidebar;

		if MessageEnergizerNotShown then begin
			DisplayMessage(200, XDat.Configs[6]); {"Energizer - You are Invincible!"}
			MessageEnergizerNotShown := false;
		end;

		if OopSend(0, 'ALL:ENERGIZE', false) then begin end;
		if not XDat.EDefs[Enum(XDat.EDefs[E_ENERGIZER].P3)].Walkable then
			MoveStat(0, x, y);
	end;

procedure ElementSlimeTick(statId: integer);
	var
		dir, changedTiles: integer;
		startX, startY: integer;
		color: byte;
	begin
		with Board.Stats[statId] do begin
			if P1 < P2 then
				P1 := P1 + 1
			else begin
				color := Board.Tiles[X][Y].Color;
				P1 := 0;
				startX := X;
				startY := Y;
				changedTiles := 0;

				for dir := 0 to 3 do begin
					if XDat.EDefs[Enum(Board.Tiles[startX + NeighborDeltaX[dir]][startY + NeighborDeltaY[dir]].Element)].Walkable then begin
						if changedTiles = 0 then begin
							MoveStat(statId, startX + NeighborDeltaX[dir], startY + NeighborDeltaY[dir]);
							Board.Tiles[startX][startY].Color := color;
							Board.Tiles[startX][startY].Element := E_BREAKABLE;
							BoardDrawTile(startX, startY);
						end else begin
							AddStat(startX + NeighborDeltaX[dir], startY + NeighborDeltaY[dir], E_SLIME, color,
								XDat.EDefs[E_SLIME].Cycle, StatTemplateDefault);
							Board.Stats[Board.StatCount].P2 := P2;
						end;

						changedTiles := changedTiles + 1;
					end;
				end;

				if changedTiles = 0 then begin
					RemoveStat(statId);
					Board.Tiles[startX][startY].Element := E_BREAKABLE;
					Board.Tiles[startX][startY].Color := color;
					BoardDrawTile(startX, startY);
				end;
			end;
		end;
	end;

procedure ElementSlimeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		color: integer;
	begin
		color := Board.Tiles[x][y].Color;
		DamageStat(GetStatIdAt(x, y));
		Board.Tiles[x][y].Element := E_BREAKABLE;
		Board.Tiles[x][y].Color := color;
		BoardDrawTile(x, y);
	end;

procedure ElementSharkTick(statId: integer);
	var
		deltaX, deltaY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 < Random(10) then
				CalcDirectionRnd(deltaX, deltaY)
			else
				CalcDirectionSeek(X, Y, deltaX, deltaY);

			if Board.Tiles[X + deltaX][Y + deltaY].Element = E_WATER then
				MoveStat(statId, X + deltaX, Y + deltaY)
			else if Board.Tiles[X + deltaX][Y + deltaY].Element = E_PLAYER then
				BoardAttack(statId, X + deltaX, Y + deltaY);
		end;
	end;

procedure ElementBlinkWallTick(statId: integer);
	var
		ix, iy: integer;
		hitBoundary: boolean;
		playerStatId: integer;
		el: integer;
	begin
		with Board.Stats[statId] do begin
			if P3 = 0 then
				P3 := P1 + 1;
			if P3 = 1 then begin
				ix := X + StepX;
				iy := Y + StepY;

				if StepX <> 0 then
					el := E_BLINK_RAY_EW
				else
					el := E_BLINK_RAY_NS;

				while (Board.Tiles[ix][iy].Element = el)
					and (Board.Tiles[ix][iy].Color = Board.Tiles[X][Y].Color) do
				begin
					Board.Tiles[ix][iy].Element := E_EMPTY;
					BoardDrawTile(ix, iy);
					ix := ix + StepX;
					iy := iy + StepY;
					P3 := (P2) * 2 + 1;
				end;

				if ((X + StepX) = ix) and ((Y + StepY) = iy) then begin
					hitBoundary := false;
					repeat
						if (Board.Tiles[ix][iy].Element <> E_EMPTY) and (XDat.EDefs[Enum(Board.Tiles[ix][iy].Element)].CanShoot) then
							BoardDamageTile(ix, iy);

						if Board.Tiles[ix][iy].Element = E_PLAYER then begin
							playerStatId := GetStatIdAt(ix, iy);
							if StepX <> 0 then begin
								if Board.Tiles[ix][iy - 1].Element = E_EMPTY then
									MoveStat(playerStatId, ix, iy - 1)
								else if Board.Tiles[ix][iy + 1].Element = E_EMPTY then
									MoveStat(playerStatId, ix, iy + 1);
							end else begin
								if Board.Tiles[ix + 1][iy].Element = E_EMPTY then
									MoveStat(playerStatId, ix + 1, iy)
								else if Board.Tiles[ix - 1][iy].Element = E_EMPTY then
									MoveStat(playerStatId, ix - 1, iy);
							end;

							if Board.Tiles[ix][iy].Element = E_PLAYER then begin
								while World.Info.Health > 0 do
									DamageStat(playerStatId);
								hitBoundary := true;
							end;
						end;

						if Board.Tiles[ix][iy].Element = E_EMPTY then begin
							Board.Tiles[ix][iy].Element := el;
							Board.Tiles[ix][iy].Color := Board.Tiles[X][Y].Color;
							BoardDrawTile(ix, iy);
						end else begin
							hitBoundary := true;
						end;

						ix := ix + StepX;
						iy := iy + StepY;
					until hitBoundary;

					P3 := (P2 * 2) + 1;
				end;
			end else begin
				P3 := P3 - 1;
			end;
		end;
	end;

procedure ElementMove(oldX, oldY, newX, newY: integer);
	var
		statId: integer;
	begin
		if (newX < 1) or (newX > BOARD_WIDTH) then exit;
		if (newY < 1) or (newY > BOARD_HEIGHT) then exit;

		statId := GetStatIdAt(oldX, oldY);

		if statId >= 0 then begin
			MoveStat(statId, newX, newY);
		end else begin
			Board.Tiles[newX][newY] := Board.Tiles[oldX][oldY];
			BoardDrawTile(newX, newY);
			Board.Tiles[oldX][oldY].Element := E_EMPTY;
			BoardDrawTile(oldX, oldY);
		end;
	end;

procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	begin
		if ((x + deltaX) < 1) or ((x + deltaX) > BOARD_WIDTH) then exit;
		if ((y + deltaY) < 1) or ((y + deltaY) > BOARD_HEIGHT) then exit;
		if (deltaX <> 0) or (deltaY <> 0) then begin
			with Board.Tiles[x][y] do begin
				if ((Element = E_SLIDER_NS) and (deltaX = 0)) or ((Element = E_SLIDER_EW) and (deltaY = 0))
					or XDat.EDefs[Enum(Element)].Pushable then
				begin
					if Board.Tiles[x + deltaX][y + deltaY].Element = E_TRANSPORTER then
						ElementTransporterMove(x, y, deltaX, deltaY)
					else if Board.Tiles[x + deltaX][y + deltaY].Element <> E_EMPTY then
						ElementPushablePush(x + deltaX, y + deltaY, deltaX, deltaY);

					if not XDat.EDefs[Enum(Board.Tiles[x + deltaX][y + deltaY].Element)].Walkable
						and XDat.EDefs[Enum(Board.Tiles[x + deltaX][y + deltaY].Element)].CanShoot
						and (Board.Tiles[x + deltaX][y + deltaY].Element <> E_PLAYER) then
					begin
						BoardDamageTile(x + deltaX, y + deltaY);
					end;

					if XDat.EDefs[Enum(Board.Tiles[x + deltaX][y + deltaY].Element)].Walkable then
						ElementMove(x, y, x + deltaX, y + deltaY);
				end;
			end;
		end;
	end;

procedure ElementDuplicatorDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			case P1 of
				1: ch := 250;
				2: ch := 249;
				3: ch := 248;
				4: ch := 111;
				5: ch := 79;
			else ch := 250 end;
	end;

procedure ElementObjectTick(statId: integer);
	var
		retVal: boolean;
	begin
		with TrackPushStat(statId)^ do begin
			if Stat^.DataPos >= 0 then
				OopExecute(Index, XDat.Configs[84]);

			if (Stat^.StepX <> 0) or (Stat^.StepY <> 0) then begin
				if XDat.EDefs[Enum(Board.Tiles[Stat^.X + Stat^.StepX][Stat^.Y + Stat^.StepY].Element)].Walkable then
					MoveStat(Index, Stat^.X + Stat^.StepX, Stat^.Y + Stat^.StepY)
				else if (Index > 0) then
					retVal := OopSend(-Index, 'THUD', false);
			end;
		end;
		TrackPopStat;
	end;

procedure ElementObjectDraw(x, y: integer; var ch: byte);
	begin
		ch := Board.Stats[GetStatIdAt(x, y)].P1;
	end;

procedure ElementObjectTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		statId: integer;
		retVal: boolean;
	begin
		statId := GetStatIdAt(x, y);
		if InspectNext then begin
			InspectObjectCode(statId, Board.Stats[statId].DataPos, '');
			InspectNext := false;
		end else
			retVal := OopSend(-statId, 'TOUCH', false);
	end;

function ElementDuplicate(srcX, srcY, dstX, dstY, statId: integer): boolean;
	var
		sourceStatId: integer;
	begin
		ElementDuplicate := false;
		if (srcX = dstX) and (srcY = dstY) then
			exit;
		with Board.Stats[statId] do begin
			with Board.Tiles[X + dstX][Y + dstY] do begin
				if Element = E_PLAYER then begin
					XDat.EDefs[ENum(Board.Tiles[X + srcX][Y + srcY].Element)]
						.TouchProc(X + srcX, Y + srcY, 0, InputDeltaX, InputDeltaY);
					BoardDrawTile(X + srcX, Y + srcY);
				end else begin
					if Element <> E_EMPTY then
						ElementPushablePush(X + dstX, Y + dstY, dstX, dstY);

					if (Element = E_EMPTY)
						or (HasINI and XDat.EDefs[ENum(Element)].CanPut = true)
					then begin
						sourceStatId := GetStatIdAt(X + srcX, Y + srcY);
						if sourceStatId > 0 then begin
							ElementDuplicate := true;
							AddStat(X + dstX, Y + dstY,
								Board.Tiles[X + srcX][Y + srcY].Element,
								Board.Tiles[X + srcX][Y + srcY].Color,
								Board.Stats[sourceStatId].Cycle,
								Board.Stats[sourceStatId]);
						end else if sourceStatId <> 0 then begin
							ElementDuplicate := true;
							Board.Tiles[X + dstX][Y + dstY]
								:= Board.Tiles[X + srcX][Y + srcY];
						end;
					end;
				end;
			end;
		end;
	end;

procedure ElementDuplicatorTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			Cycle := (9 - P2) * 3;
			if P1 <= 4 then
				Inc(P1)
			else begin
				P1 := 0;
				if ElementDuplicate(StepX,StepY,-StepX,-StepY,statId) then begin
					SoundQueue(3, SoundParse(XDat.Configs[50])); {Duplicator success}
					BoardDrawTile(X - StepX, Y - StepY);
				end else
					SoundQueue(3, SoundParse(XDat.Configs[51])); {Duplicator blocked}
			end;
			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementScrollTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			Board.Tiles[X][Y].Color := Board.Tiles[X][Y].Color + 1;
			if Board.Tiles[X][Y].Color > $0F then
				Board.Tiles[X][Y].Color := $09;

			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementScrollTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		textWindow: TTextWindowState;
		statId: integer;
		unk1: integer;
	begin
		statId := GetStatIdAt(x, y);

		with TrackPushStat(statId)^ do begin
			textWindow.Selectable := false;
			textWindow.LinePos := 1;

			SoundQueue(2, SoundParse(XDat.Configs[60])); {Scroll Touch}

			Stat^.DataPos := 0;
			OopExecute(Index, XDat.Configs[85]);

			if Index >= 0 then
				RemoveStat(Index);
		end;
		TrackPopStat;
	end;




procedure ElementKeyTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := Board.Tiles[x][y].Color and $07;

		if World.Info.Keys[key] >= XDat.EDefs[E_KEY].P1 then begin {Key Limit}
			DisplayMessage(200, XDat.Configs[15]+ColorNames[key]+XDat.Configs[16]); {Already have key}
			SoundQueue(2, SoundParse(XDat.Configs[17]));
		end else begin
			Inc(World.Info.Keys[key]);
			Board.Tiles[x][y].Element := XDat.EDefs[E_KEY].P3;
			GameUpdateSidebar;
			DisplayMessage(200, XDat.Configs[12]+ColorNames[key]+XDat.Configs[13]); {You got the key}
			SoundQueue(2, SoundParse(XDat.Configs[14]));
			if not XDat.EDefs[Enum(XDat.EDefs[E_KEY].P3)].Walkable then
				MoveStat(0, x, y);
		end;
	end;

procedure ElementAmmoTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Inc(World.Info.Ammo, XDat.EDefs[E_AMMO].P1); {Amount per ammo collected}

		Board.Tiles[x][y].Element := XDat.EDefs[E_AMMO].P3;
		GameUpdateSidebar;
		SoundQueue(2, SoundParse(XDat.Configs[25])); {Ammo Collect sound}

		if MessageAmmoNotShown then begin
			MessageAmmoNotShown := false;
			DisplayMessage(200, XDat.Configs[24]); {"Ammunition - 5 shots per container"}
		end;
		if not XDat.EDefs[Enum(XDat.EDefs[E_AMMO].P3)].Walkable then
			MoveStat(0, x, y);
	end;

procedure ElementGemTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Inc(World.Info.Gems, XDat.EDefs[E_GEM].P1);
		Inc(World.Info.Health, XDat.EDefs[E_GEM].P2);
		Inc(World.Info.Score, XDat.EDefs[E_GEM].ScoreValue);

		Board.Tiles[x][y].Element := XDat.EDefs[E_GEM].P3;
		GameUpdateSidebar;
		SoundQueue(2, SoundParse(XDat.Configs[27])); {Gem sound}

		if MessageGemNotShown then begin
			MessageGemNotShown := false;
			DisplayMessage(200, XDat.Configs[26]); {"Gems give you Health!"}
		end;
		if not XDat.EDefs[Enum(XDat.EDefs[E_GEM].P3)].Walkable then
			MoveStat(0, x, y);
	end;

procedure ElementPassageTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardPassageTeleport(x, y);
		deltaX := 0;
		deltaY := 0;
		if HasINI then
			if OopSend(0, 'ALL:ENTER', false) then begin end;
	end;

procedure ElementDoorTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := (Board.Tiles[x][y].Color div 16) and $07;

		if World.Info.Keys[key] > 0 then begin
			Board.Tiles[x][y].Element := XDat.EDefs[E_DOOR].P3;
			BoardDrawTile(x, y);

			Dec(World.Info.Keys[key]);
			GameUpdateSidebar;

			DisplayMessage(200, XDat.Configs[18]+ColorNames[key]+XDat.Configs[19]); {You opened the door}
			SoundQueue(3, SoundParse(XDat.Configs[20]));
			if not XDat.EDefs[Enum(XDat.EDefs[E_DOOR].P3)].Walkable then
				MoveStat(0, x, y);
		end else begin
			DisplayMessage(200, XDat.Configs[21]+ColorNames[key]+XDat.Configs[22]); {The door is locked}
			SoundQueue(3, SoundParse(XDat.Configs[23]));
		end;
	end;

procedure ElementPushableTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementPushablePush(x, y, deltaX, deltaY);
		SoundQueue(2, SoundParse(XDat.Configs[52])); {Push boulder sound}
	end;

procedure ElementPusherDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if StepX = 1 then
				ch := 16
			else if StepX = -1 then
				ch := 17
			else if StepY = -1 then
				ch := 30
			else
				ch := 31;
		end;
	end;

procedure ElementPusherTick(statId: integer);
	var
		i, startX, startY: integer;
	begin
		with Board.Stats[statId] do begin
			startX := X;
			startY := Y;

			if not XDat.EDefs[Enum(Board.Tiles[X + StepX][Y + StepY].Element)].Walkable then begin
				ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);
			end;
		end;

		statId := GetStatIdAt(startX, startY);
		with Board.Stats[statId] do begin
			if XDat.EDefs[Enum(Board.Tiles[X + StepX][Y + StepY].Element)].Walkable then begin
				MoveStat(statId, X + StepX, Y + StepY);
				SoundQueue(2, SoundParse(XDat.Configs[52])); {Pusher push sound}

				if Board.Tiles[X - (StepX * 2)][Y - (StepY * 2)].Element = E_PUSHER then begin
					i := GetStatIdAt(X - (StepX * 2), Y - (StepY * 2));
					if (Board.Stats[i].StepX = StepX) and (Board.Stats[i].StepY = StepY) then
						XDat.EDefs[E_PUSHER].TickProc(i);
				end;
			end;
		end;
	end;

procedure ElementTorchTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Inc(World.Info.Torches, XDat.EDefs[E_TORCH].P1);
		Board.Tiles[x][y].Element := XDat.EDefs[E_TORCH].P3;

		BoardDrawTile(x, y);
		GameUpdateSidebar;

		if MessageTorchNotShown then begin
			DisplayMessage(200, XDat.Configs[28]); {"Torch - Used for lighting in the underground."}
		end;
		MessageTorchNotShown := false;

		SoundQueue(3, SoundParse(XDat.Configs[29])); {Torch sound}
		if not XDat.EDefs[Enum(XDat.EDefs[E_TORCH].P3)].Walkable then
			MoveStat(0, x, y);
	end;

procedure ElementInvisibleTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Tiles[x][y] do begin
			Element := XDat.EDefs[E_INVISIBLE].P1;
			BoardDrawTile(x, y);

			SoundQueue(3, SoundParse(XDat.Configs[32])); {Invisible wall touch}
			DisplayMessage(100, XDat.Configs[31]); {"You are blocked by an invisible wall."}
		end;
	end;

procedure ElementForestTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Board.Tiles[x][y].Element := XDat.EDefs[E_FOREST].P3;
		BoardDrawTile(x, y);

		SoundQueue(3, SoundParse(XDat.Configs[34])); {Forest sound}

		if MessageForestNotShown then begin
			DisplayMessage(200, XDat.Configs[33]); {"A path is cleared through the forest."}
		end;
		MessageForestNotShown := false;
		if not XDat.EDefs[Enum(XDat.EDefs[E_FOREST].P3)].Walkable then
			MoveStat(0, x, y);
	end;

procedure ElementFakeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		if MessageFakeNotShown then begin
			DisplayMessage(150, XDat.Configs[35]); {"Fake Wall - Secret Passage}
		end;
		MessageFakeNotShown := false;
	end;

procedure ElementBoardEdgeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		neighborId: integer;
		boardId: integer;
		entryX, entryY: integer;
	begin
		entryX := Board.Stats[0].X;
		entryY := Board.Stats[0].Y;
		if deltaY = -1 then begin
			neighborId := 0;
			entryY := BOARD_HEIGHT;
		end else if deltaY = 1 then begin
			neighborId := 1;
			entryY := 1;
		end else if deltaX = -1 then begin
			neighborId := 2;
			entryX := BOARD_WIDTH;
		end else begin
			neighborId := 3;
			entryX := 1;
		end;

		if Board.Info.NeighborBoards[neighborId] <> 0 then begin
			boardId := World.Info.CurrentBoard;
			BoardChange(Board.Info.NeighborBoards[neighborId]);
			if Board.Tiles[entryX][entryY].Element <> E_PLAYER then begin
				XDat.EDefs[Enum(Board.Tiles[entryX][entryY].Element)].TouchProc(
					entryX, entryY, sourceStatId, InputDeltaX, InputDeltaY);
			end;

			if XDat.EDefs[Enum(Board.Tiles[entryX][entryY].Element)].Walkable
				or (Board.Tiles[entryX][entryY].Element = E_PLAYER) then
			begin
				if Board.Tiles[entryX][entryY].Element <> E_PLAYER then
					MoveStat(0, entryX, entryY);

				TransitionDrawBoardChange;
				deltaX := 0;
				deltaY := 0;
				BoardEnter;
				if HasINI then
					if OopSend(0, 'ALL:ENTER', false) then begin end;
			end else begin
				BoardChange(boardId);
			end;
		end;
	end;

procedure ElementWaterTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		SoundQueue(3, SoundParse(XDat.Configs[37])); {Water touch sound}
		DisplayMessage(100, XDat.Configs[36]); {"Your way is blocked by water."}
	end;

procedure DrawBombSurroundings(x, y: integer; bombPhase: integer);
	var
		ix, iy: integer;
		istat: integer;
		result: boolean;
	begin
		for ix := 1 to BOARD_WIDTH do {Bomb Radius}
			for iy := 1 to BOARD_HEIGHT do
				with Board.Tiles[ix][iy] do begin
					if ((Sqr(ix-x)*XDat.Params[6]) + (Sqr(iy-y)*XDat.Params[7])) < XDat.Params[8] then begin
						if bombPhase = 1 then begin
							if Element = E_OBJECT then begin
								istat := GetStatIdAt(ix, iy);
								if istat > 0 then
									result := OopSend(-istat, 'BOMBED', false);
							end;
							if XDat.EDefs[Enum(Element)].CanShoot or (Element = E_STAR) then
								BoardDamageTile(ix, iy);
							if (Element = E_EMPTY) or (Element = E_BREAKABLE) then begin
								Element := E_BREAKABLE;
								Color := $09 + Random(7);
							end;
						end else begin
							if Element = E_BREAKABLE then
								Element := E_EMPTY;
						end;
						BoardDrawTile(ix, iy);
					end;
				end;
	end;

procedure GamePromptEndPlay;
	begin
		if (World.Info.Health <= 0) and (World.Info.GracePeriod >= XDat.Params[11]) then begin
			GamePlayExitRequested := true;
			BoardDrawBorder;
		end else begin
			GamePlayExitRequested := SidebarPromptYesNo('End this game? ', true);
			if InputKeyPressed = #27 then
				GamePlayExitRequested := false;
		end;
		InputKeyPressed := #0;
	end;

procedure ElementCustomInput(inputC: char);
	var
		i: integer;	
	begin {.INI keyboard inputs - Override defaults}
		i := 0;
		while i < KeyLimit do begin
			if (inputC = UpCase(KeyList[i * 3][1]))
				or (inputC = KeyList[i * 3][1])
			then begin
				GameMove := true;
				if OopSend(0, 'INPUT:' + UpCaseString(KeyList[(i * 3) + 1], false), false) then begin end;
				i := KeyLimit + 1;
			end;
			Inc(i);
			if i = KeyLimit then
				if OopSend(0, 'INPUT:KEYBOARD' + InputC, false) then begin end;
		end;
	end;

procedure ElementCustomDir(shiftPressed: boolean);
	var
		shiftMod: string;
	begin
		if shiftPressed then
			shiftMod := 'SHIFT'
		else
			shiftMod := '';
		if InputDeltaY = -1 then
			if OopSend(0, 'INPUT:' + shiftMod + 'UP', false) then begin end;
		if InputDeltaY = 1 then
			if OopSend(0, 'INPUT:' + shiftMod + 'DOWN', false) then begin end;
		if InputDeltaX = -1 then
			if OopSend(0, 'INPUT:' + shiftMod + 'LEFT', false) then begin end;
		if InputDeltaX = 1 then
			if OopSend(0, 'INPUT:' + shiftMod + 'RIGHT', false) then begin end;
		if (InputKeyPressed = ' ')
			and (InputDeltaX = 0)
			and (InputDeltaY = 0)
			and (shiftMod = '')
		then
			if OopSend(0, 'INPUT:SPACE', false) then begin end;
	end;

procedure ElementTruePlayerTick;
	var
		i: integer;
		bulletCount: integer;
		inputC: char;
	begin
		if NeuromotorAssist then GameMove := false else GameMove := true;
		with Board.Stats[0] do begin

			if P2 = 1 then begin
				InputDeltaX := 0;
				InputDeltaY := 0;
				InputShiftPressed := false;
			end;

			if (World.Info.Health <= 0) then begin
				if World.Info.GracePeriod < XDat.Params[11] then begin
					Inc(World.Info.GracePeriod);
					if World.Info.GracePeriod = XDat.Params[11] - 1 then begin
						InputDeltaX := 0;
						InputDeltaY := 0;
						InputShiftPressed := false;
					end;
				end else begin
					if World.Info.GracePeriod = XDat.Params[11] then begin
						Inc(World.Info.GracePeriod);
						SoundQueue(5, SoundParse(XDat.Configs[39])); {Game over song}
						SoundBlockQueueing := true;
					end;
					InputDeltaX := 0;
					InputDeltaY := 0;
					InputShiftPressed := false;
					if P3 = 0 then
						DisplayMessage(250, XDat.Configs[38]); {"Game Over - Press ESCAPE"}
					TickTimeDuration := 0;
				end;
			end else
				World.Info.GracePeriod := 0;
			if InputShiftPressed or (InputKeyPressed = ' ') then begin
				GameMove := true;

				if InputShiftPressed and ((InputDeltaX <> 0) or (InputDeltaY <> 0)) then begin
					PlayerDirX := InputDeltaX;
					PlayerDirY := InputDeltaY;
				end;					

				if (PlayerDirX <> 0) or (PlayerDirY <> 0) then begin
					if Board.Info.MaxShots = 0 then begin
						if MessageNoShootingNotShown then
							DisplayMessage(200, XDat.Configs[40]); {"Can't Shoot in this place!"}
						MessageNoShootingNotShown := false;
					end else if World.Info.Ammo = 0 then begin
						if MessageOutOfAmmoNotShown then
							DisplayMessage(200, XDat.Configs[41]); {"You don't have any ammo!"}
						MessageOutOfAmmoNotShown := false;
					end else begin
						bulletCount := 0;
						for i := 0 to Board.StatCount do
							if (Board.Tiles[Board.Stats[i].X][Board.Stats[i].Y].Element = E_BULLET)
								and (Board.Stats[i].P1 = SHOT_SOURCE_PLAYER)
							then
								bulletCount := bulletCount + 1;

						if ((bulletCount < Board.Info.MaxShots) or (Board.Info.MaxShots < 0)) then begin
							if BoardShoot(E_BULLET, X, Y, PlayerDirX, PlayerDirY, SHOT_SOURCE_PLAYER) then begin
								World.Info.Ammo := World.Info.Ammo - 1;
								GameUpdateSidebar;

								SoundQueue(2, SoundParse(XDat.Configs[42])); {Player Shoot}

								InputDeltaX := 0;
								InputDeltaY := 0;
							end;
						end;
					end;
				end;
			end else if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
				GameMove := true;

				PlayerDirX := InputDeltaX;
				PlayerDirY := InputDeltaY;

				XDat.EDefs[Enum(Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element)].TouchProc(
					X + InputDeltaX, Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					if SoundEnabled and not SoundIsPlaying and not (XDat.Params[71] = 0) then
{$IFDEF SDL2}
						AudioSimPlayerStep := true;
{$ELSE}
						Sound(110);
{$ENDIF}
					if XDat.EDefs[Enum(Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element)].Walkable then begin
{$IFNDEF SDL2}
						if SoundEnabled and not SoundIsPlaying then
							NoSound;
{$ENDIF}

						MoveStat(0, X + InputDeltaX, Y + InputDeltaY);
					end else if SoundEnabled and not SoundIsPlaying then begin
						{$IFNDEF SDL2} NoSound; {$ENDIF}
					end;
				end;
			end;
			if HasINI then ElementCustomDir(InputShiftPressed);

			inputC := UpCase(InputKeyPressed);
			if (P2 = 1) {Locked players have limited input options}
				and (inputC <> #27) and (inputC <> 'Q')
				and (inputC <> UpCase(XDat.Configs[72][1]))
				and (inputC <> UpCase(XDat.Configs[75][1]))
				and (inputC <> UpCase(XDat.Configs[77][1]))
				and (inputC <> UpCase(XDat.Configs[83][1]))
			then
				inputC := #0;
			if ((inputC = #27) or (inputC = 'Q')) then
				GamePromptEndPlay
			else if inputC = UpCase(XDat.Configs[70][1]) then begin {'T' Torch hotkey}
				GameMove := true;
				if World.Info.TorchTicks = 0 then begin
					if World.Info.Torches > 0 then begin
						if Board.Info.IsDark > 0 then begin
							World.Info.Torches := World.Info.Torches - Board.Info.IsDark;
							World.Info.TorchTicks := XDat.EDefs[E_TORCH].P2;

							TransitionDrawToBoard;
							GameUpdateSidebar;
						end else begin
							if MessageRoomNotDarkNotShown then begin
								DisplayMessage(200, XDat.Configs[44]); {"Don't need torch - room is not dark!"}
								MessageRoomNotDarkNotShown := false;
							end;
						end;
					end else begin
						if MessageOutOfTorchesNotShown then begin
							DisplayMessage(200, XDat.Configs[45]); {"You don't have any torches!"}
							MessageOutOfTorchesNotShown := false;
						end;
					end;
				end;
			end else if inputC = UpCase(XDat.Configs[77][1]) then {'S' Save game hotkey }
				GameWorldSave(XDat.Configs[78] + ':', SavedGameFileName, '.SAV')
			else if inputC = UpCase(XDat.Configs[72][1]) then begin {'B' Sound toggle hotkey}
				SoundEnabled := not SoundEnabled;
				SoundClearQueue;
				GameUpdateSidebar;
				InputKeyPressed := ' ';
			end else if inputC = UpCase(XDat.Configs[75][1]) then begin {'H' Help file hotkey}
				if FileExists(World.Info.Name + '.HLP') then
					TextWindowDisplayFile(World.Info.Name + '.HLP', 'Help for '+ World.Info.Name);
			end else if inputC = UpCase(XDat.Configs[83][1]) then begin {'?' Debug prompt hotkey}
				World.Info.PlayerChar := XDat.EDefs[E_PLAYER].Character;
				World.Info.PlayerColor := XDat.EDefs[E_PLAYER].Color;
				GameDebugPrompt;
				InputKeyPressed := #0;
			end else if (NeuromotorAssist = true) and (inputC = 'P') then
				GameMove := true
			else if (NeuromotorAssist = false)
				and ((inputC = UpCase(XDat.Configs[79][1]))
				and (World.Info.Health > 0))
			then
				GamePaused := true
			else if HasINI and (KeyLimit > 0) then
				ElementCustomInput(inputC);

			if World.Info.TorchTicks > 0 then begin
				if GameMove then
					Dec(World.Info.TorchTicks);
				if World.Info.TorchTicks = 0 then begin
					TransitionDrawToBoard;
					SoundQueue(3, SoundParse(XDat.Configs[30])); {Torch extinguish sound}
				end;
				if XDat.EDefs[E_TORCH].P2 > 10 then {Torch duration}
					if (World.Info.TorchTicks mod (XDat.EDefs[E_TORCH].P2 div 5)) = 0 then
						GameUpdateSidebar;
			end;

			if World.Info.EnergizerTicks > 0 then begin
				if GameMove then
					Dec(World.Info.EnergizerTicks);

				if World.Info.EnergizerTicks = 10 then
					SoundQueue(9, SoundParse(XDat.Configs[11])); {Energizer ending sound}
			end;

			if (Board.Info.TimeLimitSec > 0) and (World.Info.Health > 0) then
				if (GameMove) and (Board.Info.BoardTicks mod 10 = 0) then begin
					Inc(World.Info.BoardTimeSec);

					if (Board.Info.TimeLimitSec - 10) = World.Info.BoardTimeSec then begin
						DisplayMessage(200, XDat.Configs[54]); {"Running out of time!"}
						SoundQueue(3, SoundParse(XDat.Configs[55])); {Time running out sound}
					end else if World.Info.BoardTimeSec > Board.Info.TimeLimitSec then
						DamageStat(0);
					GameUpdateSidebar;
				end;

			if P3 > 0 then begin
				if TickSpeed < 3 then
					i := 9 + ((P3 - 1) div 2) mod 7
				else
					i := 9 + (P3 - 1) mod 7;
				VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, i,
					' '+Board.Info.Message+' ');
				if GameMove then
					Dec(P3);
			end else if Board.Info.Message <> '' then begin
				Board.Info.Message := '';
				BoardDrawRow(BOARD_HEIGHT);
			end;

			if HearingImpaired then begin
				if TopTimer > 0 then begin
					if TopTimer = 16 then
						BoardDrawRow(1);
					VideoWriteText((60 - Length(TopMsg)) div 2, 0, 9 + (TopTimer mod 7),TopMsg + ' ');
					if GameMove then
						Dec(TopTimer);
				end else if TopMsg <> '' then begin
					BoardDrawRow(1);
					TopMsg := '';
				end;
			end;

			if GameMove then begin
				if not GamePaused then
					Inc(Board.Info.BoardTicks);
				if (Board.Info.BoardTicks > 420) then
					Board.Info.BoardTicks := 1;
			end else begin
				CurrentStatTicked := Board.StatCount + 1;
			end;

			BoardDrawTile(X, Y);

		end;
	end;

procedure ElementCloneTick(statId: integer);
	var
		i, e: integer;
		bulletCount: integer;
	begin
		with Board.Stats[statId] do begin
			if InputShiftPressed or (InputKeyPressed = ' ') then begin
				if InputShiftPressed and ((InputDeltaX <> 0) or (InputDeltaY <> 0)) then begin
					PlayerDirX := InputDeltaX;
					PlayerDirY := InputDeltaY;
				end;

				if (PlayerDirX <> 0) or (PlayerDirY <> 0) then begin
					if (Board.Info.MaxShots <> 0) and (World.Info.Ammo > 0) then begin
						bulletCount := 0;
						for i := 0 to Board.StatCount do
							if (Board.Tiles[Board.Stats[i].X][Board.Stats[i].Y].Element = E_BULLET)
								and (Board.Stats[i].P1 = SHOT_SOURCE_PLAYER)
							then
								bulletCount := bulletCount + 1;

						if ((bulletCount < Board.Info.MaxShots) or (Board.Info.MaxShots < 0)) then begin
							if BoardShoot(E_BULLET, X, Y, PlayerDirX, PlayerDirY, SHOT_SOURCE_PLAYER) then begin
								Dec(World.Info.Ammo);
								GameUpdateSidebar;

								SoundQueue(2, #64#1#48#1#32#1);

								InputDeltaX := 0;
								InputDeltaY := 0;
							end;
						end;
					end;
				end;
			end else if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
				PlayerDirX := InputDeltaX;
				PlayerDirY := InputDeltaY;

				XDat.EDefs[Enum(Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element)].TouchProc(
					X + InputDeltaX, Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					if XDat.EDefs[Enum(Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element)].Walkable then
						MoveStat(0, X + InputDeltaX, Y + InputDeltaY);
				end;
			end;

			if World.Info.TorchTicks > 1 then
				Dec(World.Info.TorchTicks);

			if World.Info.EnergizerTicks > 11 then
				Dec(World.Info.EnergizerTicks);

		end;
	end;

procedure ElementPlayerTick(statId: integer);
	begin
		PMouseX := RMouseX;
		PMouseY := RMouseY;
		if HasINI then begin
			if (RMouseButL <> PMouseButL) then begin
				PMouseButL := RMouseButL;
				if RMouseButL then
					if OopSend(0, 'INPUT:LMOUSEB', false) then begin end;
			end;
			if (RMouseButR <> PMouseButR) then begin
				PMouseButR := RMouseButR;
				if RMouseButR then
					if OopSend(0, 'INPUT:RMOUSEB', false) then begin end;
			end;
		end;
		if statId = 0 then
			ElementTruePlayerTick
		else
			ElementCloneTick(statId);
	end;

procedure ElementMonitorTick(statId: integer);
	var
		inputC: char;
	begin
		inputC := UpCase(InputKeyPressed);
		Inc(Board.Info.BoardTicks);
		if (Board.Info.BoardTicks > 420) then
			Board.Info.BoardTicks := 1;
		if QuickStart then GamePlayExitRequested := true;
		if inputC in [#27, 'A', 'E', 'H', 'N', 'P', 'Q', 'R', 'S', 'W', '|'] then
			GamePlayExitRequested := true;
		if HasINI
			and (statId = 0)
			and not (Board.Stats[0].P1 = 1)
		then begin
			ElementCustomInput(inputC);
			ElementCustomDir(InputShiftPressed);
		end;
	end;

procedure ResetMessageNotShownFlags;
	begin
		MessageAmmoNotShown := true;
		MessageOutOfAmmoNotShown := true;
		MessageNoShootingNotShown := true;
		MessageTorchNotShown := true;
		MessageOutOfTorchesNotShown := true;
		MessageRoomNotDarkNotShown := true;
		MessageHintTorchNotShown := true;
		MessageForestNotShown := true;
		MessageFakeNotShown := true;
		MessageGemNotShown := true;
		MessageEnergizerNotShown := true;
		InspectNext := false;
		NoClip := false;
		PMouseButL := false;
		PMouseButR := false;
	end;

function Enum(elem: integer): integer;
	begin
		if elem > MAX_ELEMENT then
			Enum := E_CUSTOMTEXT
		else
			Enum := elem;
	end;

function ElemDefColor(elem: integer): byte;
	begin
		if elem > 127 then
			ElemDefColor := elem - 128
		else if elem > MAX_ELEMENT then
			ElemDefColor := XDat.EDefs[E_CUSTOMTEXT].Color
		else
			ElemDefColor := XDat.EDefs[elem].Color
	end;

procedure InitXDatEDefs;
	var
		i, code: integer;
	begin
		for i := 0 to MAX_ELEMENT do
			with XDat.EDefs[i] do begin
				Character := ' ';
				Color := $00;
				CanShoot := false;
				Pushable := false;
				SeeDark := false;
				CanPut := false;
				Walkable := false;
				HasDrawProc := false;
				Cycle := -1;
				TickProc := ElemDefaultTick;
				DrawProc := ElemDefaultDraw;
				TouchProc := ElemDefaultTouch;
				Name := '';
				P1 := 0;
				P2 := 0;
				P3 := 0;
				ScoreValue := 0;
			end;

		XDat.EDefs[0].Character := ' ';
		XDat.EDefs[0].Color := $70;
		XDat.EDefs[0].Walkable := true;
		XDat.EDefs[0].CanPut := true;
		XDat.EDefs[0].Name := 'EMPTY';

		XDat.EDefs[1].Character := ' ';
		XDat.EDefs[1].TouchProc := ElementBoardEdgeTouch;
		XDat.EDefs[1].Name := 'EDGE';

		XDat.EDefs[2].Character := #176;
		XDat.EDefs[2].Color := $07;
		XDat.EDefs[2].Name := 'DARKNESS';

		XDat.EDefs[3].Character := ' ';
		XDat.EDefs[3].Color := $07;
		XDat.EDefs[3].Cycle := 1;
		XDat.EDefs[3].TickProc := ElementMonitorTick;
		XDat.EDefs[3].Name := 'MONITOR';

		XDat.EDefs[4].Character := #2;
		XDat.EDefs[4].Color := $1F;
		XDat.EDefs[4].CanShoot := true;
		XDat.EDefs[4].Pushable := true;
		XDat.EDefs[4].SeeDark := true;
		XDat.EDefs[4].Cycle := 1;
		XDat.EDefs[4].TickProc := ElementPlayerTick;
		XDat.EDefs[4].HasDrawProc := true;
		XDat.EDefs[4].DrawProc := ElementPlayerDraw;
		XDat.EDefs[4].Name := 'PLAYER';

		XDat.EDefs[5].Character := #132;
		XDat.EDefs[5].Color := $03;
		XDat.EDefs[5].Pushable := true;
		XDat.EDefs[5].TouchProc := ElementAmmoTouch;
		XDat.EDefs[5].Name := 'AMMO';
		XDat.EDefs[5].P1 := 5;

		XDat.EDefs[6].Character := #157;
		XDat.EDefs[6].Color := $06;
		XDat.EDefs[6].TouchProc := ElementTorchTouch;
		XDat.EDefs[6].SeeDark := true;
		XDat.EDefs[6].Name := 'TORCH';
		XDat.EDefs[6].P1 := 1;
		XDat.EDefs[6].P2 := 200;

		XDat.EDefs[7].Character := #4;
		XDat.EDefs[7].Pushable := true;
		XDat.EDefs[7].TouchProc := ElementGemTouch;
		XDat.EDefs[7].CanShoot := true;
		XDat.EDefs[7].Name := 'GEM';
		XDat.EDefs[7].P1 := 1;
		XDat.EDefs[7].P2 := 1;
		XDat.EDefs[7].ScoreValue := 10;

		XDat.EDefs[8].Character := #12;
		XDat.EDefs[8].Pushable := true;
		XDat.EDefs[8].TouchProc := ElementKeyTouch;
		XDat.EDefs[8].HasDrawProc := true;
		XDat.EDefs[8].DrawProc := ElementKeyDraw;
		XDat.EDefs[8].Name := 'KEY';
		XDat.EDefs[8].P1 := 1;

		XDat.EDefs[9].Character := #10;
		XDat.EDefs[9].Color := $0F;
		XDat.EDefs[9].TouchProc := ElementDoorTouch;
		XDat.EDefs[9].HasDrawProc := true;
		XDat.EDefs[9].DrawProc := ElementDoorDraw;
		XDat.EDefs[9].Name := 'DOOR';

		XDat.EDefs[10].Character := #232;
		XDat.EDefs[10].Color := $0F;
		XDat.EDefs[10].TouchProc := ElementScrollTouch;
		XDat.EDefs[10].TickProc := ElementScrollTick;
		XDat.EDefs[10].Pushable := true;
		XDat.EDefs[10].Cycle := 1;
		XDat.EDefs[10].Name := 'SCROLL';

		XDat.EDefs[11].Character := #240;
		XDat.EDefs[11].Color := $0F;
		XDat.EDefs[11].Cycle := 0;
		XDat.EDefs[11].SeeDark := true;
		XDat.EDefs[11].TouchProc := ElementPassageTouch;
		XDat.EDefs[11].Name := 'PASSAGE';

		XDat.EDefs[12].Character := ' ';
		XDat.EDefs[12].Color := $0F;
		XDat.EDefs[12].Cycle := 2;
		XDat.EDefs[12].TickProc := ElementDuplicatorTick;
		XDat.EDefs[12].HasDrawProc := true;
		XDat.EDefs[12].DrawProc := ElementDuplicatorDraw;
		XDat.EDefs[12].Name := 'DUPLICATOR';

		XDat.EDefs[13].Character := #11;
		XDat.EDefs[13].HasDrawProc := true;
		XDat.EDefs[13].DrawProc := ElementBombDraw;
		XDat.EDefs[13].Pushable := true;
		XDat.EDefs[13].Cycle := 6;
		XDat.EDefs[13].TickProc := ElementBombTick;
		XDat.EDefs[13].TouchProc := ElementBombTouch;
		XDat.EDefs[13].Name := 'BOMB';

		XDat.EDefs[14].Character := #127;
		XDat.EDefs[14].Color := $05;
		XDat.EDefs[14].TouchProc := ElementEnergizerTouch;
		XDat.EDefs[14].Name := 'ENERGIZER';
		XDat.EDefs[14].P1 := 75;

		XDat.EDefs[15].Character := ' ';
		XDat.EDefs[15].Color := $0F;
		XDat.EDefs[15].CanShoot := false;
		XDat.EDefs[15].Cycle := 1;
		XDat.EDefs[15].TickProc := ElementStarTick;
		XDat.EDefs[15].TouchProc := ElementDamagingTouch;
		XDat.EDefs[15].HasDrawProc := true;
		XDat.EDefs[15].DrawProc := ElementStarDraw;
		XDat.EDefs[15].Name := 'STAR';
		XDat.EDefs[15].P1 := 1;
		XDat.EDefs[15].P2 := 100;

		XDat.EDefs[16].Character := ' ';
		XDat.EDefs[16].Cycle := 3;
		XDat.EDefs[16].HasDrawProc := true;
		XDat.EDefs[16].TickProc := ElementConveyorCWTick;
		XDat.EDefs[16].DrawProc := ElementConveyorCWDraw;
		XDat.EDefs[16].Name := 'CLOCKWISE';

		XDat.EDefs[17].Character := ' ';
		XDat.EDefs[17].Cycle := 2;
		XDat.EDefs[17].HasDrawProc := true;
		XDat.EDefs[17].DrawProc := ElementConveyorCCWDraw;
		XDat.EDefs[17].TickProc := ElementConveyorCCWTick;
		XDat.EDefs[17].Name := 'COUNTER';

		XDat.EDefs[18].Character := #248;
		XDat.EDefs[18].Color := $0F;
		XDat.EDefs[18].CanShoot := true;
		XDat.EDefs[18].Cycle := 1;
		XDat.EDefs[18].TickProc := ElementBulletTick;
		XDat.EDefs[18].TouchProc := ElementDamagingTouch;
		XDat.EDefs[18].Name := 'BULLET';
		XDat.EDefs[18].P2 := 100;
		XDat.EDefs[18].P3 := 1;

		XDat.EDefs[19].Character := #176;
		XDat.EDefs[19].CanPut := true;
		XDat.EDefs[19].TouchProc := ElementWaterTouch;
		XDat.EDefs[19].Name := 'WATER';

		XDat.EDefs[20].Character := #176;
		XDat.EDefs[20].Color := $20;
		XDat.EDefs[20].Walkable := false;
		XDat.EDefs[20].TouchProc := ElementForestTouch;
		XDat.EDefs[20].Name := 'FOREST';

		XDat.EDefs[21].Character := #219;
		XDat.EDefs[21].Name := 'SOLID';

		XDat.EDefs[22].Character := #178;
		XDat.EDefs[22].Name := 'NORMAL';

		XDat.EDefs[23].Character := #177;
		XDat.EDefs[23].CanShoot := false;
		XDat.EDefs[23].Name := 'BREAKABLE';

		XDat.EDefs[24].Character := #254;
		XDat.EDefs[24].Pushable := true;
		XDat.EDefs[24].TouchProc := ElementPushableTouch;
		XDat.EDefs[24].Name := 'BOULDER';

		XDat.EDefs[25].Character := #18;
		XDat.EDefs[25].TouchProc := ElementPushableTouch;
		XDat.EDefs[25].Name := 'SLIDERNS';

		XDat.EDefs[26].Character := #29;
		XDat.EDefs[26].TouchProc := ElementPushableTouch;
		XDat.EDefs[26].Name := 'SLIDEREW';

		XDat.EDefs[27].Character := #178;
		XDat.EDefs[27].CanPut := true;
		XDat.EDefs[27].Walkable := true;
		XDat.EDefs[27].TouchProc := ElementFakeTouch;
		XDat.EDefs[27].Name := 'FAKE';

		XDat.EDefs[28].Character := ' ';
		XDat.EDefs[28].TouchProc := ElementInvisibleTouch;
		XDat.EDefs[28].Name := 'INVISIBLE';
		XDat.EDefs[28].P1 := 22;

		XDat.EDefs[29].Character := #206;
		XDat.EDefs[29].Cycle := 1;
		XDat.EDefs[29].TickProc := ElementBlinkWallTick;
		XDat.EDefs[29].Name := 'BLINKWALL';

		XDat.EDefs[30].Character := ' ';
		XDat.EDefs[30].TouchProc := ElementTransporterTouch;
		XDat.EDefs[30].HasDrawProc := true;
		XDat.EDefs[30].DrawProc := ElementTransporterDraw;
		XDat.EDefs[30].Cycle := 2;
		XDat.EDefs[30].TickProc := ElementTransporterTick;
		XDat.EDefs[30].Name := 'TRANSPORTER';

		XDat.EDefs[31].Character := ' ';
		XDat.EDefs[31].HasDrawProc := true;
		XDat.EDefs[31].DrawProc := ElementLineDraw;
		XDat.EDefs[31].Name := 'LINE';

		XDat.EDefs[32].Character := '*';
		XDat.EDefs[32].Color := $0A;
		XDat.EDefs[32].Name := 'RICOCHET';

		XDat.EDefs[33].Character := #205;
		XDat.EDefs[33].Name := 'BLINKEW';

		XDat.EDefs[34].Character := #153;
		XDat.EDefs[34].Color := $06;
		XDat.EDefs[34].Cycle := 3;
		XDat.EDefs[34].ScoreValue := 1;
		XDat.EDefs[34].CanShoot := true;
		XDat.EDefs[34].Pushable := true;
		XDat.EDefs[34].TickProc := ElementBearTick;
		XDat.EDefs[34].TouchProc := ElementDamagingTouch;
		XDat.EDefs[34].Name := 'BEAR';

		XDat.EDefs[35].Character := #5;
		XDat.EDefs[35].Color := $0D;
		XDat.EDefs[35].Cycle := 1;
		XDat.EDefs[35].ScoreValue := 2;
		XDat.EDefs[35].CanShoot := true;
		XDat.EDefs[35].Pushable := true;
		XDat.EDefs[35].TickProc := ElementRuffianTick;
		XDat.EDefs[35].TouchProc := ElementDamagingTouch;
		XDat.EDefs[35].Name := 'RUFFIAN';

		XDat.EDefs[36].Character := ' ';
		XDat.EDefs[36].Cycle := 1;
		XDat.EDefs[36].HasDrawProc := true;
		XDat.EDefs[36].DrawProc := ElementObjectDraw;
		XDat.EDefs[36].TickProc := ElementObjectTick;
		XDat.EDefs[36].TouchProc := ElementObjectTouch;
		XDat.EDefs[36].Name := 'OBJECT';

		XDat.EDefs[37].Character := '*';
		XDat.EDefs[37].Cycle := 3;
		XDat.EDefs[37].CanShoot := false;
		XDat.EDefs[37].TickProc := ElementSlimeTick;
		XDat.EDefs[37].TouchProc := ElementSlimeTouch;
		XDat.EDefs[37].Name := 'SLIME';

		XDat.EDefs[38].Character := '^';
		XDat.EDefs[38].Color := $07;
		XDat.EDefs[38].Cycle := 3;
		XDat.EDefs[38].CanShoot := false;
		XDat.EDefs[38].TickProc := ElementSharkTick;
		XDat.EDefs[38].Name := 'SHARK';

		XDat.EDefs[39].Character := ' ';
		XDat.EDefs[39].Cycle := 2;
		XDat.EDefs[39].TickProc := ElementSpinningGunTick;
		XDat.EDefs[39].HasDrawProc := true;
		XDat.EDefs[39].DrawProc := ElementSpinningGunDraw;
		XDat.EDefs[39].Name := 'SPINNINGGUN';

		XDat.EDefs[40].Character := ' ';
		XDat.EDefs[40].HasDrawProc := true;
		XDat.EDefs[40].DrawProc := ElementPusherDraw;
		XDat.EDefs[40].Cycle := 4;
		XDat.EDefs[40].TickProc := ElementPusherTick;
		XDat.EDefs[40].Name := 'PUSHER';

		XDat.EDefs[41].Color := $0C;
		XDat.EDefs[41].Character := #234;
		XDat.EDefs[41].Cycle := 2;
		XDat.EDefs[41].ScoreValue := 1;
		XDat.EDefs[41].CanShoot := true;
		XDat.EDefs[41].Pushable := true;
		XDat.EDefs[41].TickProc := ElementLionTick;
		XDat.EDefs[41].TouchProc := ElementDamagingTouch;
		XDat.EDefs[41].Name := 'LION';

		XDat.EDefs[42].Color := $0B;
		XDat.EDefs[42].Character := #227;
		XDat.EDefs[42].Cycle := 2;
		XDat.EDefs[42].ScoreValue := 2;
		XDat.EDefs[42].CanShoot := true;
		XDat.EDefs[42].Pushable := true;
		XDat.EDefs[42].TickProc := ElementTigerTick;
		XDat.EDefs[42].TouchProc := ElementDamagingTouch;
		XDat.EDefs[42].Name := 'TIGER';

		XDat.EDefs[43].Character := #186;
		XDat.EDefs[43].Name := 'BLINKNS';

		XDat.EDefs[44].Character := #233;
		XDat.EDefs[44].Cycle := 2;
		XDat.EDefs[44].ScoreValue := 1;
		XDat.EDefs[44].CanShoot := true;
		XDat.EDefs[44].TickProc := ElementCentipedeHeadTick;
		XDat.EDefs[44].TouchProc := ElementDamagingTouch;
		XDat.EDefs[44].Name := 'HEAD';

		XDat.EDefs[45].Character := #79;
		XDat.EDefs[45].Cycle := 2;
		XDat.EDefs[45].ScoreValue := 3;
		XDat.EDefs[45].CanShoot := true;
		XDat.EDefs[45].TickProc := ElementCentipedeSegmentTick;
		XDat.EDefs[45].TouchProc := ElementDamagingTouch;
		XDat.EDefs[45].Name := 'SEGMENT';

		XDat.EDefs[46].Color := $08;
		XDat.EDefs[46].Name := 'CUSTOMTEXT';

		XDat.EDefs[47].Color := $1F;
		XDat.EDefs[47].Name := 'BLUETEXT';

		XDat.EDefs[48].Color := $2F;
		XDat.EDefs[48].Name := 'GREENTEXT';

		XDat.EDefs[49].Color := $3F;
		XDat.EDefs[49].Name := 'CYANTEXT';

		XDat.EDefs[50].Color := $4F;
		XDat.EDefs[50].Name := 'REDTEXT';

		XDat.EDefs[51].Color := $5F;
		XDat.EDefs[51].Name := 'PURPLETEXT';

		XDat.EDefs[52].Color := $6F;
		XDat.EDefs[52].Name := 'YELLOWTEXT';

		XDat.EDefs[53].Color := $0F;
		XDat.EDefs[53].Name := 'WHITETEXT';

	end;

procedure ElementMod(e: integer; par: string; op: string; statId: integer);
	var
		v, code: integer;
	begin
		v := ColorNumber(op, statId);
		if (v = -32767) then
			Val(op, v, code);
		if ((op <> 'TRUE') and (op <> 'FALSE')) then
			if v > 0 then
				op := 'TRUE'
			else
				op := 'FALSE';

		if par = 'CHAR' then begin
			if (XDat.EDefs[e].Character = ' ') and XDat.EDefs[e].HasDrawProc then begin
				XDat.EDefs[e].DrawProc := ElemDefaultDraw;
				XDat.EDefs[e].HasDrawProc := false;
			end;
			XDat.EDefs[e].Character := Chr(v);
		end else if par = 'FG' then
			XDat.EDefs[e].Color := AsColor(v, XDat.EDefs[e].Color div 16)
		else if par = 'BG' then
			XDat.EDefs[e].Color := AsColor(XDat.EDefs[e].Color and $0F, v)
		else if par = 'CANSHOOT' then
			XDat.EDefs[e].CanShoot := op = 'TRUE'
		else if par = 'PUSHABLE' then begin
			XDat.EDefs[e].Pushable := op = 'TRUE';
			if op = 'TRUE' then
				XDat.EDefs[e].TouchProc := ElementPushableTouch
			else
				XDat.EDefs[e].TouchProc := ElemDefaultTouch;
		end else if par = 'SEEDARK' then
			XDat.EDefs[e].SeeDark := op = 'TRUE'
		else if par = 'CANPUT' then
			XDat.EDefs[e].CanPut := op = 'TRUE'
		else if par = 'WALKABLE' then
			XDat.EDefs[e].Walkable := op = 'TRUE'
		else if par = 'CYCLE' then
			XDat.EDefs[e].Cycle := v
		else if par = 'P1' then
			XDat.EDefs[e].P1 := v
		else if par = 'P2' then
			XDat.EDefs[e].P2 := v
		else if par = 'P3' then
			XDat.EDefs[e].P3 := v
		else if par = 'SCOREVALUE' then
			XDat.EDefs[e].ScoreValue := v;
	end;

function ElementGet(e: integer; par: string): integer;
	var
		code: integer;
	begin
		if (par = 'CANSHOOT')
			or (par = 'PUSHABLE')
			or (par = 'SEEDARK')
			or (par = 'CANPUT')
			or (par = 'WALKABLE')
		then
			ElementGet := 0
		else
			ElementGet := -32767;
		if par = 'CHAR' then ElementGet := Ord(XDat.EDefs[e].Character)
		else if par = 'FG' then ElementGet := XDat.EDefs[e].Color and $0F
		else if par = 'BG' then ElementGet := XDat.EDefs[e].Color div 16
		else if par = 'COLOR' then ElementGet := Integer(XDat.EDefs[e].Color)
		else if par = 'CYCLE' then ElementGet := XDat.EDefs[e].Cycle
		else if par = 'P1' then ElementGet := XDat.EDefs[e].P1
		else if par = 'P2' then ElementGet := XDat.EDefs[e].P2
		else if par = 'P3' then ElementGet := XDat.EDefs[e].P3
		else if par = 'SCOREVALUE' then ElementGet := XDat.EDefs[e].ScoreValue
		else if (par = 'CANSHOOT') and XDat.EDefs[e].CanShoot then ElementGet := 1
		else if (par = 'PUSHABLE') and XDat.EDefs[e].Pushable then ElementGet := 1
		else if (par = 'SEEDARK') and XDat.EDefs[e].SeeDark then ElementGet := 1
		else if (par = 'CANPUT') and XDat.EDefs[e].CanPut then ElementGet := 1
		else if (par = 'WALKABLE') and XDat.EDefs[e].Walkable then ElementGet := 1;
	end;

function StringConfigs(i: integer): string;
	begin
		case i of
			1: StringConfigs := 'BOMB.MSG.TOUCH';
			2: StringConfigs := 'BOMB.SND.TOUCH';
			3: StringConfigs := 'BOMB.SND.TICK';
			4: StringConfigs := 'BOMB.SND.TOCK';
			5: StringConfigs := 'BOMB.SND.EXPLODE';
			6: StringConfigs := 'ENERGIZER.MSG.TOUCH';
			7: StringConfigs := 'ENERGIZER.SND.SONG1';
			8: StringConfigs := 'ENERGIZER.SND.SONG2';
			9: StringConfigs := 'ENERGIZER.SND.SONG3';
			10: StringConfigs := 'ENERGIZER.SND.SONG4';
			11: StringConfigs := 'ENERGIZER.SND.END';
			12: StringConfigs := 'KEY.MSG.TOUCH1';
			13: StringConfigs := 'KEY.MSG.TOUCH2';
			14: StringConfigs := 'KEY.SND.TOUCH';
			15: StringConfigs := 'KEY.MSG.FAIL1';
			16: StringConfigs := 'KEY.MSG.FAIL2';
			17: StringConfigs := 'KEY.SND.FAIL';
			18: StringConfigs := 'DOOR.MSG.TOUCH1';
			19: StringConfigs := 'DOOR.MSG.TOUCH2';
			20: StringConfigs := 'DOOR.SND.TOUCH';
			21: StringConfigs := 'DOOR.MSG.FAIL1';
			22: StringConfigs := 'DOOR.MSG.FAIL2';
			23: StringConfigs := 'DOOR.SND.FAIL';
			24: StringConfigs := 'AMMO.MSG.TOUCH';
			25: StringConfigs := 'AMMO.SND.TOUCH';
			26: StringConfigs := 'GEM.MSG.TOUCH';
			27: StringConfigs := 'GEM.SND.TOUCH';
			28: StringConfigs := 'TORCH.MSG.TOUCH';
			29: StringConfigs := 'TORCH.SND.TOUCH';
			30: StringConfigs := 'TORCH.SND.END';
			31: StringConfigs := 'INVISIBLE.MSG.TOUCH';
			32: StringConfigs := 'INVISIBLE.SND.TOUCH';
			33: StringConfigs := 'FOREST.MSG.TOUCH';
			34: StringConfigs := 'FOREST.SND.TOUCH';
			35: StringConfigs := 'FAKE.MSG.TOUCH';
			36: StringConfigs := 'WATER.MSG.TOUCH';
			37: StringConfigs := 'WATER.SND.TOUCH';
			38: StringConfigs := 'GAMEOVER.MSG';
			39: StringConfigs := 'GAMEOVER.SND';
			40: StringConfigs := 'CANTSHOOT.MSG';
			41: StringConfigs := 'OUTOFAMMO.MSG';
			42: StringConfigs := 'PLAYERSHOOT.SND';
			43: StringConfigs := 'OBJECTSHOOT.SND';
			44: StringConfigs := 'NOTDARK.MSG';
			45: StringConfigs := 'OUTOFTORCHES.MSG';
			46: StringConfigs := 'DARKBOARD.MSG';
			47: StringConfigs := 'STATDEATH.SND';
			48: StringConfigs := 'PLAYERHURT.MSG';
			49: StringConfigs := 'PLAYERHURT.SND';
			50: StringConfigs := 'DUPLICATOR.SND';
			51: StringConfigs := 'DUPEBLOCKED.SND';
			52: StringConfigs := 'PUSH.SND';
			53: StringConfigs := 'RICOCHET.SND';
			54: StringConfigs := 'LOWTIMER.MSG';
			55: StringConfigs := 'LOWTIMER.SND';
			56: StringConfigs := 'BREAKABLE.SND';
			57: StringConfigs := 'ERROR.MSG';
			58: StringConfigs := 'ERROR.SND';
			59: StringConfigs := 'CHEAT.SND';
			60: StringConfigs := 'SCROLL.SND';
			61: StringConfigs := 'PASSAGE.SND';
			62: StringConfigs := 'TRANSPORTER.SND';
			63: StringConfigs := 'COUNTER.HEALTH';
			64: StringConfigs := 'COUNTER.AMMO';
			65: StringConfigs := 'COUNTER.TORCHES';
			66: StringConfigs := 'COUNTER.GEMS';
			67: StringConfigs := 'COUNTER.SCORE';
			68: StringConfigs := 'COUNTER.KEYS';
			69: StringConfigs := 'COUNTER.TIME';
			70: StringConfigs := 'KEYS.TORCH.BIND';
			71: StringConfigs := 'KEYS.TORCH.LABEL';
			72: StringConfigs := 'KEYS.SOUND.BIND';
			73: StringConfigs := 'KEYS.SOUND.LABEL.ON';
			74: StringConfigs := 'KEYS.SOUND.LABEL.OFF';
			75: StringConfigs := 'KEYS.HELP.BIND';
			76: StringConfigs := 'KEYS.HELP.LABEL';
			77: StringConfigs := 'KEYS.SAVE.BIND';
			78: StringConfigs := 'KEYS.SAVE.LABEL';
			79: StringConfigs := 'KEYS.PAUSE.BIND';
			80: StringConfigs := 'KEYS.PAUSE.LABEL';
			81: StringConfigs := 'SIDEBAR.PAUSE.MSG';
			82: StringConfigs := 'SIDEBAR.TITLEPROMPT';
			83: StringConfigs := 'KEYS.CHEAT.BIND';
			84: StringConfigs := 'DEFAULT.OBJECT.NAME';
			85: StringConfigs := 'DEFAULT.SCROLL.NAME';
			86: StringConfigs := 'SIDEBAR.MOVE.MSG';
			87: StringConfigs := 'SIDEBAR.SHOOT.MSG';
			88: StringConfigs := 'SIDEBAR.SHIFT.MSG';
		else StringConfigs := '_nil' end;
	end;

function DefaultConfigList(i: integer): string;
	begin
		case i of
			1: DefaultConfigList := 'Bomb activated!';
			2: DefaultConfigList := 'tcf+cf+c';
			3: DefaultConfigList := 't5';
			4: DefaultConfigList := 't8';
			5: DefaultConfigList := 't+++c-c-c-c-c-c';
			6: DefaultConfigList := 'Energizer - You are invincible';
			7: DefaultConfigList := 's.-cd#e';
			8: DefaultConfigList := 's.-f+f-fd#c+c-d#ef+f-fd#c+c-d#e';
			9: DefaultConfigList := 's.-f+f-fd#c+c-d#ef+f-fd#c+c-d#e';
			10: DefaultConfigList := 's.-f+f-fd#c+c-d#e';
			11: DefaultConfigList := 's.-c-a#gf#fd#c';
			12: DefaultConfigList := 'You now have the ';
			13: DefaultConfigList := ' key.';
			14: DefaultConfigList := 't+cegcegceg+sc';
			15: DefaultConfigList := 'You already have a ';
			16: DefaultConfigList := ' key!';
			17: DefaultConfigList := 'sc-c';
			18: DefaultConfigList := 'The ';
			19: DefaultConfigList := ' door is now open.';
			20: DefaultConfigList := 'tcgbcgb+ic';
			21: DefaultConfigList := 'The ';
			22: DefaultConfigList := ' door is locked!';
			23: DefaultConfigList := 't--gc';
			24: DefaultConfigList := 'Ammunition - 5 shots per container.';
			25: DefaultConfigList := 'tcc#d';
			26: DefaultConfigList := 'Gems give you Health!';
			27: DefaultConfigList := 't+c-gec';
			28: DefaultConfigList := 'Torch - used for lighting in the underground.';
			29: DefaultConfigList := 'tcase';
			30: DefaultConfigList := 'tc-c-c';
			31: DefaultConfigList := 'You are blocked by an invisible wall.';
			32: DefaultConfigList := 't--dc';
			33: DefaultConfigList := 'A path is cleared through the forest.';
			34: DefaultConfigList := 'ta';
			35: DefaultConfigList := 'A fake wall - secret passage!';
			36: DefaultConfigList := 'Your way is blocked by water.';
			37: DefaultConfigList := 't+c+c';
			38: DefaultConfigList := ' Game over  -  Press ESCAPE';
			39: DefaultConfigList := 's.-cd#g+c-ga#+dgfg#+cf---w3c';
			40: DefaultConfigList := 'Can'#39't shoot in this place!';
			41: DefaultConfigList := 'You don'#39't have any ammo!';
			42: DefaultConfigList := 't+c-c-c';
			43: DefaultConfigList := 'tc-f#';
			44: DefaultConfigList := 'Don'#39't need torch - room is not dark!';
			45: DefaultConfigList := 'You don'#39't have any torches!';
			46: DefaultConfigList := 'Room is dark - you need to light a torch!';
			47: DefaultConfigList := 't+c---c++++c--c';
			48: DefaultConfigList := 'Ouch!';
			49: DefaultConfigList := 't--c+c---c+d#';
			50: DefaultConfigList := 'scdefg';
			51: DefaultConfigList := 't--g#f#';
			52: DefaultConfigList := 't--f';
			53: DefaultConfigList := 't9';
			54: DefaultConfigList := 'Running out of time!';
			55: DefaultConfigList := 'i.+cfc-f+cfq.c';
			56: DefaultConfigList := 't-c';
			57: DefaultConfigList := 'ERR:';
			58: DefaultConfigList := '++w3c';
			59: DefaultConfigList := 'i-g';
			60: DefaultConfigList := 'tc-c+d-d+e-e+f-f+g-g';
			61: DefaultConfigList := 'tcegc#fg#df#ad#ga#eg#+c';
			62: DefaultConfigList := 'tc+d-e+f#-g#+a#c+d';
			63: DefaultConfigList := ' Health:';
			64: DefaultConfigList := '   Ammo:';
			65: DefaultConfigList := 'Torches:';
			66: DefaultConfigList := '   Gems:';
			67: DefaultConfigList := '  Score:';
			68: DefaultConfigList := '   Keys:';
			69: DefaultConfigList := '   Time:';
			70: DefaultConfigList := 'T';
			71: DefaultConfigList := 'Torch';
			72: DefaultConfigList := 'B';
			73: DefaultConfigList := 'Be quiet';
			74: DefaultConfigList := 'Be noisy';
			75: DefaultConfigList := 'H';
			76: DefaultConfigList := 'Help';
			77: DefaultConfigList := 'S';
			78: DefaultConfigList := 'Save game';
			79: DefaultConfigList := 'P';
			80: DefaultConfigList := 'Pause';
			81: DefaultConfigList := 'Pausing...';
			82: DefaultConfigList := 'Pick a command:';
			83: DefaultConfigList := '?';
			84: DefaultConfigList := 'Interaction';
			85: DefaultConfigList := 'Scroll';
			86: DefaultConfigList := ' Move';
			87: DefaultConfigList := ' Shoot';
			88: DefaultConfigList := ' Shift ';
		else DefaultConfigList := '' end;
	end;

procedure InitElementsGame;
	var
		s, l: string;
		k: string[20];
		c: char;
		f: text;
		i, j, v, code: integer;
	begin
		for i := 1 to CONFIG_FILE_COUNT do
			XDat.Configs[i] := DefaultConfigList(i);
		for i := 1 to PARAM_FILE_COUNT do
			XDat.Params[i] := DefaultParamList(i);
		CurrentBlink := true;
		InitXDatEDefs;
		if (World.Info.Name <> '') then begin
			if not FileExists(World.Info.Name + '.CFG') then exit;
			AssignFSysText(f, World.Info.Name + '.CFG');
			Reset(f);
			if IOResult = 0 then begin
				j := 0;
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
						if (Pos('PAL.',k) = 1) then begin
							Delete(k,1,4);
							v := ColorNumber(k, -1);
							if (v <> -32767) or (k = 'LOAD') then begin
								if v < 0 then
									v := 0
								else
									v := v * 3;
								l := '';
								while i <= Length(s) do begin
									if ((s[i] >= '0') and (s[i] <= '9')) then
										l := l + s[i]
									else begin
										if l <> '' then begin
											Val(l, XDat.Params[PALETTE_START + v], code);
											Inc(v);
										end;
										l := '';
									end;
									Inc(i);
								end;
							end;
						end else begin
							for v := 1 to CONFIG_FILE_COUNT do
								if StringConfigs(v) = k then begin
									while (s[i] <> #34) and (i <= Length(s)) do
										Inc(i);
									Inc(i);
									while (s[i] <> #34) and (i <= Length(s)) do begin
										l := l + s[i];
										Inc(i);
									end;
									if l = '' then begin
										XDat.Configs[v] := #1;
										XDat.Configs[v] := '';
									end else
										XDat.Configs[v] := l;
								end;
							while (i <= Length(s)) do begin
								c := UpCase(s[i]);
								if ((c >= 'A') and (c <= 'Z'))
									or ((c >= '0') and (c <= '9'))
									or (c = '-')
								then
									l := l + c;
								Inc(i);
							end;
							if (Pos('OTHER.',k) = 1)
								or (Pos('THEME.',k) = 1)
							then begin
								v := ColorNumber(l, -1);
								if (v = -32767) then
									Val(l, v, code);
								for i := 1 to (PALETTE_START - 1) do
									if ParamConfigs(i) = k then
										XDat.Params[i] := v;
								for i := 71 to (PARAM_FILE_COUNT) do
									if ParamConfigs(i) = k then
										XDat.Params[i] := v;
							end;
							for i := 0 to MAX_ELEMENT do
								if Pos(XDat.EDefs[i].Name + '.', k) = 1 then begin
									Delete(k,1,Length(XDat.EDefs[i].Name) + 1);
									if (l <> '') and (k <> '') then
										ElementMod(i, k, l, -1);
								end;
						end;
					end;
				end;
				Close(f);
			end;
		end;
	end;

begin
end.
