if not exist "BUILD" mkdir BUILD
del W34WIN32\Weave_Win32.exe
cd SRC_W34
fpc @fpc.sdl2.cfg ZZT.PAS
copy ZZT.EXE ..\W34WIN32\Weave_Win32.exe
