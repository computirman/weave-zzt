#!/bin/sh
if [ ! -d BUILD ]; then
	mkdir BUILD
fi
if [ ! -d W34UNIX ]; then
	mkdir W34UNIX
fi
rm -r W34UNIX/*
cd SRC_W34
fpc @fpc.sdl2.cfg ZZT.PAS
cp ZZT ../W34UNIX/Weave"$1"
cd ..

cp -aR EXAMPLES W34UNIX/EXAMPLES
cp LICENSE.TXT W34UNIX/
cp OOP-QR.txt W34UNIX/
cp README.MD W34UNIX/
cp THE_WEAVE_MANUAL.txt W34UNIX/
cp W-START.CFG W34UNIX/
cp W-START.zzt W34UNIX/
cp WEAVE.CFG W34UNIX/

mkdir W34UNIX/UTILS
cp TOOLS/*.zip W34UNIX/UTILS/
