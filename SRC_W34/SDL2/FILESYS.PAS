{
	Copyright (c) 2020, 2021 Adrian Siekierka

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
unit FileSys;

interface
	procedure AssignFSys(var f: file; fn: string);
	procedure AssignFSysText(var f: text; fn: string);
	{ Only available in SDL2/ }
	function FilenameFindIgnoreCase(fn: string): string;

implementation
uses SysUtils;

function FilenameFindIgnoreCase(fn: string): string;
	var
		fileSearchRec: TRawbyteSearchRec;
		startPath: string;
		basePath: string;
		newFn: string;
		fnFilename: string;
	begin
{$IFNDEF WINDOWS}
		{ TODO: Support non-upcase directory names on Linux. }
		fn := UpCase(fn);

		fn := StringReplace(fn, '\', '/', [rfReplaceAll]);
{$ENDIF}
		basePath := ExpandFileName(ExtractFileDir(fn));

		if not DirectoryExists(basePath) then begin
			FilenameFindIgnoreCase := fn;
			exit;
		end;

		fnFilename := UpCase(ExtractFileName(fn));
		newFn := fn;

		GetDir(0, startPath);
		ChDir(basePath);

		FindFirst('*', faAnyFile, fileSearchRec);
		repeat
			if ((fileSearchRec.Attr and faDirectory) = 0) then begin
				if UpCase(fileSearchRec.Name) = fnFilename then begin
					newFn := ExtractRelativePath(
						IncludeTrailingPathDelimiter(startPath),
						ExpandFileName(IncludeTrailingPathDelimiter(basePath) + fileSearchRec.Name)
					);

					break;
				end;
			end;
		until FindNext(fileSearchRec) <> 0;
		FindClose(fileSearchRec);

		ChDir(startPath);
		FilenameFindIgnoreCase := newFn;
	end;

procedure AssignFSys(var f: file; fn: string);
	begin
		fn := FilenameFindIgnoreCase(fn);
		Assign(f, fn);
	end;

procedure AssignFSysText(var f: text; fn: string);
	begin
		fn := FilenameFindIgnoreCase(fn);
		Assign(f, fn);
	end;

end.
