@echo off

if not exist BIN mkdir BIN
del BIN\*.*

if not exist DIST mkdir DIST
del DIST\*.*
cd DIST
if not exist EXAMPLES mkdir EXAMPLES
del EXAMPLES\*.*
if not exist IMAGES mkdir IMAGES
del IMAGES\*.*
if not exist UTILS mkdir UTILS
del UTILS\*.*
cd..

echo.
echo [ Building ZZT.EXE ]
echo.
TPC /B /EBIN /GD /ISRC_W34 /USRC_W34 /USRC_W34\DOS SRC_W34\ZZT.PAS
if errorlevel 1 goto error
echo.
echo [ Compressing ZZT.EXE ]
echo.
cd BIN
..\TOOLS\UPX.EXE --8086 ZZT.EXE
cd ..

echo.
echo [ Creating DIST/ ]
echo.

copy BIN\ZZT.EXE DIST\ZZT.EXE
copy BIN\ZZT.DAT DIST\ZZT.DAT
copy LICENSE.TXT DIST\LICENSE.TXT
copy OOP-QR.TXT DIST\OOP-QR.TXT
copy THE_WEAVE_MANUAL.TXT DIST\THE_WEAVE_MANUAL.TXT
copy README.TXT DIST\README.TXT
copy EXAMPLES\TEMPLATE.CFG DIST\EXAMPLES\TEMPLATE.CFG
copy EXAMPLES\TEMPLATE.INI DIST\EXAMPLES\TEMPLATE.INI
copy EXAMPLES\USING_~1.HTM DIST\!HOW_TO.HTM
copy EXAMPLES\HOWTO1.png DIST\IMAGES\HOWTO1.png
copy EXAMPLES\HOWTO2.png DIST\IMAGES\HOWTO2.png
copy EXAMPLES\HOWTO3.png DIST\IMAGES\HOWTO3.png
copy TOOLS\LOOMZZT.ZIP DIST\UTILS\LOOMZZT.ZIP
copy TOOLS\WEBWEAVE.ZIP DIST\UTILS\WEBWEAVE.ZIP
copy TOOLS\ZLOOM2.ZIP DIST\UTILS\ZLOOM2.ZIP
goto done
:error
echo.
echo [ Error detected! Stopping. ]
:done
copy DIST\ZZT.EXE DIST\WEAVE3.EXE

