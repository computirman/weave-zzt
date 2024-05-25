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

unit GameVars;

interface
	uses ExtMem;
	const
		FOOTER_VERSION = 3316;
		MAX_STAT = 254;
		TSTAT_OFFSET = 33;
		MAX_ELEMENT = 53;
		MAX_BOARD = 250;
		MAX_FLAG = 10;
		MAX_EXTENDEDFLAG = 99;
		BOARD_WIDTH = 60;
		BOARD_HEIGHT = 25;
		BOARD_TILE_COUNT = BOARD_WIDTH * BOARD_HEIGHT;
		WORLD_FILE_HEADER_SIZE = 512;
		OOP_TOKEN_LENGTH = 20;
{$IFDEF SDL2}
		IO_BUFFER_DEFAULT_SIZE = 65535;
		IO_BUFFER_MAXIMUM_SIZE = 65535;
{$ELSE}
		IO_BUFFER_DEFAULT_SIZE = 20000;
		IO_BUFFER_MAXIMUM_SIZE = 65500;
{$ENDIF}
		IO_BUFFER_SIZE_INCREMENT = 500;
		{.OBJ FILES}
		LOAD_OBJ_LENGTH = 40960;
		{.CFG FILE}
		CONFIG_FILE_COUNT = 88;
		THEME_START = 13;
		THEME_BLINK = 20;
		PALETTE_START = 23;
		PARAM_FILE_COUNT = 72;
		{.INI FILE}
		CUSTOM_KEY_COUNT = 24;
		CUSTOM_LOCAL_OFFSET = CUSTOM_KEY_COUNT + 7;
		CUSTOM_OBJ_OFFSET = CUSTOM_LOCAL_OFFSET + 6;
		CUSTOM_COUNTER_OFFSET = CUSTOM_OBJ_OFFSET + 1;
		CUSTOM_FLAG_OFFSET = CUSTOM_COUNTER_OFFSET + 1;
		CUSTOM_COUNTER_COUNT = 114;
		CUSTOM_FLAG_COUNT = 128;
	type
		TString50 = string[50];
		TString20 = string[20];
		TString8 = string[8];
{$IFDEF SDL2}
		TFilenameString = string;
{$ELSE}
		TFilenameString = string[128];
{$ENDIF}
		TCoord = record
			X: integer;
			Y: integer;
		end;
		TTile = record
			Element: byte;
			Color: byte;
		end;
		TMatchTile = record
			Element: byte;
			Color: byte;
			SetFG: boolean;
			SetBG: boolean;
		end;
		TPalette = array[0..47] of integer;
		TElementDrawProc = procedure(x, y: integer; var ch: byte);
		TElementTickProc = procedure(statId: integer);
		TElementTouchProc = procedure(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
		TElemDef = record
			Character: char;
			Color: byte;
			CanShoot: boolean;
			Pushable: boolean;
			SeeDark: boolean;
			CanPut: boolean;
			Walkable: boolean;
			HasDrawProc: boolean;
			DrawProc: TElementDrawProc;
			Cycle: integer;
			TickProc: TElementTickProc;
			TouchProc: TElementTouchProc;
			Name: string[20];
			P1: byte;
			P2: byte;
			P3: byte;
			ScoreValue: integer;
		end;
		TStat = record
			X, Y: byte;
			StepX, StepY: integer;
			Cycle: integer;
			P1, P2, P3: byte;
			Follower: integer;
			Leader: integer;
			Under: TTile;
			ObjArray: integer;
			elseCheck: boolean;
			Unused: byte;
			DataPos: integer;
			DataLen: integer;
			ObjLocal: array[1 .. 4] of integer;
{$IFDEF FPC}
			Data: ^char;
{$ELSE}
			Data: ^string;
{$ENDIF}
		end;
		TRleTile = record
			Count: byte;
			Tile: TTile;
		end;
		TBoardInfo = record
			MaxShots: shortint;
			IsDark: shortint;
			NeighborBoards: array[0 .. 3] of byte;
			ReenterWhenZapped: boolean;
			Message: string[58];
			StartPlayerX: byte;
			StartPlayerY: byte;
			TimeLimitSec: integer;
			BoardTicks: integer;
			Local: array[1 .. 7] of integer;
		end;
		TWorldInfo = record
			Ammo: integer;
			Gems: integer;
			Keys: array [1..7] of shortint;
			Health: integer;
			CurrentBoard: integer;
			Torches: integer;
			TorchTicks: integer;
			EnergizerTicks: integer;
			PlayerColor: byte;
			PlayerChar: char;
			Score: integer;
			Name: string[20];
			Flags: array[1 .. MAX_FLAG] of string[20];
			BoardTimeSec: integer;
			BoardTimeHsec: integer;
			IsSave: shortint;
			GracePeriod: byte;
			CustomCounters: array[1 .. CUSTOM_COUNTER_COUNT] of integer;
			CustomFlags: array[0..3] of longint;
		end;
		TBoard = record
			Name: TString50;
			Tiles: array[0 .. BOARD_WIDTH + 1] of array[0 .. BOARD_HEIGHT + 1] of TTile;
			StatCount: integer;
{$IFDEF SDL2}
			Stats: array[-1 .. MAX_STAT + 1] of TStat;
{$ELSE}
			Stats: array[0 .. MAX_STAT + 1] of TStat;
{$ENDIF}
			Info: TBoardInfo;
		end;
		TWorld = record
			BoardCount: integer;
			BoardData: array[0 .. MAX_BOARD] of TExtMemBlock;
			BoardLen: array[0 .. MAX_BOARD] of word;
			Info: TWorldInfo;
		end;
		THighScoreEntry = record
			Name: TString50;
			Score: integer;
		end;
		TExtendedData = record
			Version: integer;
			Flags: array[MAX_FLAG + 1 .. MAX_EXTENDEDFLAG] of TString20;
			Params: array[1 .. PARAM_FILE_COUNT] of integer;
			CurrentPalette: TPalette;
			EDefs: array[0 .. MAX_ELEMENT] of TElemDef;
			Configs: array[1 .. CONFIG_FILE_COUNT] of string[80];
		end;
		THighScoreList = array[1 .. 30] of THighScoreEntry;
		TCustomCounterList = array[1 .. CUSTOM_COUNTER_COUNT] of TString20;
		TCustomFlagList = array[1 .. CUSTOM_FLAG_COUNT] of TString20;
		TCustomBoardList = array[1 .. 7] of TString20;
		TCustomObjList = array[1 .. 6] of TString20;
		TCustomKeyList = array[0 .. CUSTOM_KEY_COUNT - 1] of TString20;
		TSearchArea = array[-7 .. 7] of array[-7 .. 7] of shortint;
		TSidebar = record
			Disp: TString8;
			Ident: shortint;
			Elmt: shortint;
		end;
		TBoardNames = array[0 .. MAX_BOARD] of TString50;
	var
		PlayerDirX: integer;
		PlayerDirY: integer;
		PMouseX, PMouseY, TickSpeed, TickTimeDuration: shortint;
		PMouseButL, PMouseButR: boolean;

		LoadedGameFileName: TString50;
		SavedGameFileName: TString50;
		StartupWorldFileName: TString50;
		Board: TBoard;
		World: TWorld;
		MessageAmmoNotShown: boolean;
		MessageOutOfAmmoNotShown: boolean;
		MessageNoShootingNotShown: boolean;
		MessageTorchNotShown: boolean;
		MessageOutOfTorchesNotShown: boolean;
		MessageRoomNotDarkNotShown: boolean;
		MessageHintTorchNotShown: boolean;
		MessageForestNotShown: boolean;
		MessageFakeNotShown: boolean;
		MessageGemNotShown: boolean;
		MessageEnergizerNotShown: boolean;
		NeuromotorAssist: boolean;
		HearingImpaired: boolean;
		Diffkeys: boolean;
		SkipToTitle: boolean;
		IsRelease: boolean;
		IsWebRelease: boolean;
		IsSpeedForced: boolean;
		GameMove: boolean;
		CurrentBlink: boolean;
		HasINI: boolean;
		HasCustomSidebar: boolean;
		HasCHR: boolean;
		LastLoadedCHR: TString8;
		SelUnder: boolean;
		QuickStart: boolean;
		QStartBoard: integer;
		IoTmpBufSize: word;
		FileWorldCachedLinePos: integer; 
		FileSaveCachedLinePos: integer;

		InspectNext: boolean;
		NoClip: boolean;

		GameTitleExitRequested: boolean;
		GamePlayExitRequested: boolean;
		GameStateElement: integer;
		ReturnBoardId: integer;
		GlobalArg: integer;

		IoTmpBuf: pointer;
		ObjTmpBuf: pointer;
		PathTmpBuf: ^string;

		{OUTPUT}
		OutTmpPos: pointer;

		CurrentTick: integer;
		CurrentStatTicked: integer;
		OopFuncReturn: integer;
		GamePaused: boolean;
		TickTimeCounter: integer;
		WorldMenuChar: char;
		SpeedMenuChar: char;
		HighScoreChar: char;
		QuitMenuChar: char;
		PlayMenuChar: char;
		RestoreMenuChar: char;
		KeyLimit: integer;

		InitialTextAttr: byte;

		OopChar: char;
		OopWord: string[20];
		OopValue: integer;
		CurrentSave: string[8];
		CurrentFile: string[8];
		CurFileLen: word;

		DebugEnabled: boolean;

		CustomCounterList: TCustomCounterList;
		CustomFlagList: TCustomFlagList;
		CustomBoardList: TCustomBoardList;
		CustomObjList: TCustomObjList;
		KeyList: TCustomKeyList;
		SearchArea: TSearchArea;
		HighScoreList: THighScoreList;
		JustStarted: boolean;
		ConfigWorldFile: TString50;
		Accessibility: array[1..8] of TString50;
		XDat: TExtendedData;

		BoardNames: ^TBoardNames;
		CustomSidebar: array[3..24] of TSidebar;
	const
		E_EMPTY = 0;
		E_BOARD_EDGE = 1;
		E_DARKNESS = 2;
		E_MONITOR = 3; { State - Title screen }
		E_PLAYER = 4; { State - Playing }
		E_AMMO = 5;
		E_TORCH = 6;
		E_GEM = 7;
		E_KEY = 8;
		E_DOOR = 9;
		E_SCROLL = 10;
		E_PASSAGE = 11;
		E_DUPLICATOR = 12;
		E_BOMB = 13;
		E_ENERGIZER = 14;
		E_STAR = 15;
		E_CONVEYOR_CW = 16;
		E_CONVEYOR_CCW = 17;
		E_BULLET = 18;
		E_WATER = 19;
		E_FOREST = 20;
		E_SOLID = 21;
		E_NORMAL = 22;
		E_BREAKABLE = 23;
		E_BOULDER = 24;
		E_SLIDER_NS = 25;
		E_SLIDER_EW = 26;
		E_FAKE = 27;
		E_INVISIBLE = 28;
		E_BLINK_WALL = 29;
		E_TRANSPORTER = 30;
		E_LINE = 31;
		E_RICOCHET = 32;
		E_BLINK_RAY_EW = 33;
		E_BEAR = 34;
		E_RUFFIAN = 35;
		E_OBJECT = 36;
		E_SLIME = 37;
		E_SHARK = 38;
		E_SPINNING_GUN = 39;
		E_PUSHER = 40;
		E_LION = 41;
		E_TIGER = 42;
		E_BLINK_RAY_NS = 43;
		E_CENTIPEDE_HEAD = 44;
		E_CENTIPEDE_SEGMENT = 45;
		E_CUSTOMTEXT = 46;
		E_TEXT_BLUE = 47;
		E_TEXT_GREEN = 48;
		E_TEXT_CYAN = 49;
		E_TEXT_RED = 50;
		E_TEXT_PURPLE = 51;
		E_TEXT_YELLOW = 52;
		E_TEXT_WHITE = 53;
		{}
		E_TEXT_MIN = 46;
		{}
		E_TEXT_ALLCOLORS = 127;
		{}
		CATEGORY_ITEM = 1;
		CATEGORY_CREATURE = 2;
		CATEGORY_TERRAIN = 3;
		{}
		SHOT_SOURCE_PLAYER = 0;
		SHOT_SOURCE_ENEMY = 1;

implementation

begin
{$IFDEF SDL2}
	with Board.Stats[-1] do begin
		X := 0;
		Y := 1;
		StepX := 256;
		StepY := 256;
		Cycle := 256;
		P1 := 0;
		P2 := 1;
		P3 := 0;
		Follower := 1;
		Leader := 1;
		Under.Element := E_BOARD_EDGE;
		Under.Color := $00;
		DataPos := 1;
		DataLen := 1;
	end;
{$ENDIF}
end.
