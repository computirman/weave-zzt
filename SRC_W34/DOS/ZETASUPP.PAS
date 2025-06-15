{
	Copyright (c) 2020 Adrian Siekierka

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

{ Zeta support extensions for OpenZoo. }

unit ZetaSupp;

interface
	function ZetaDetect: boolean;
	procedure ZetaSetIdleHacks(value: boolean);
	procedure ZetaSleepPit;
	procedure ZetaSleepFrame;
	procedure ZetaDelay(ms: word);

implementation
uses Crt, Dos;

function ZetaDetect: boolean;
	begin
		ZetaDetect := (MemL[$F000:$FFF5] = $6174655A)
			and (MemL[$F000:$FFF9] = $00756D45);
	end;

procedure ZetaSetIdleHacks(value: boolean);
	var
		regs: Registers;
	begin
		if not ZetaDetect then exit;
		regs.AH := $02;
		regs.AL := Byte(value);
		regs.CX := $1515;
		Intr($A5, regs);
	end;

procedure ZetaSleepFrame;
	var
		regs: Registers;
	begin
		if not ZetaDetect then exit;
		regs.AX := $0200;
		regs.CX := $1515;
		Intr($A5, regs);
	end;

procedure ZetaSleepPit;
	var
		regs: Registers;
	begin
		if not ZetaDetect then exit;
		regs.AX := $0201;
		regs.CX := $1515;
		Intr($A5, regs);
	end;

procedure ZetaDelay(ms: word);
	var
		regs: Registers;
	begin
		regs.AH := $03;
		regs.CX := $1515;
		regs.DX := ms;
		Intr($A5, regs);
	end;

begin
end.
