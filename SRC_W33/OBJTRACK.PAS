{
	Copyright (c) 2022 Adrian Siekierka
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

unit ObjTrack;

interface
	uses GameVars;
	type
		TStatTrack = record
			Index: integer;
			Stat: ^TStat;
		end;
		PTStatTrack = ^TStatTrack;
	function TrackPushStat(statId: integer): PTStatTrack;
	procedure TrackPopStat;
	procedure TrackOnRemoveStat(statId: integer);

implementation
const
	STAT_TRACK_MAX = 4;
var
	StatTrackers: array[1 .. STAT_TRACK_MAX] of TStatTrack;
	StatTrackerPos: byte;

function TrackPushStat(statId: integer): PTStatTrack;
begin
	if StatTrackerPos >= STAT_TRACK_MAX then RunError(321);
	Inc(StatTrackerPos);
	with StatTrackers[StatTrackerPos] do begin
		Index := statId;
		Stat := @Board.Stats[statId];
	end;
	TrackPushStat := @StatTrackers[StatTrackerPos];
end;

procedure TrackPopStat;
begin
	if StatTrackerPos = 0 then RunError(321);
	Dec(StatTrackerPos);
end;

procedure TrackOnRemoveStat(statId: integer);
var
	i: byte;
begin
	for i := 1 to StatTrackerPos do begin
		with StatTrackers[i] do begin
			if Index > statId then begin
				Dec(Index);
				Stat := @Board.Stats[Index];
			end else if Index = statId then begin
				Index := -1;
				Stat := @Board.Stats[Index];
			end;
		end;
	end;
end;

begin
	StatTrackerPos := 0;
end.