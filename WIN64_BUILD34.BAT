if not exist "BUILD" mkdir BUILD
del W34WIN64\Weave_Win64.exe
cd SRC_W34
fpc -Px86_64 @fpc.sdl2.cfg ZZT.PAS
copy ZZT.EXE ..\W34WIN64\Weave_Win64.exe
