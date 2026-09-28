# Weave 4.1

Weave is the definitive way to mod the classic 1991 MS-DOS game, ZZT. This version produces binaries for the following platforms:
* Win32 and Win64
* Linux AArch64 and x86_64
* MS-DOS for native or emulation

### What is it?

Weave is a system for playing original and modified ZZT games. If you run your ZZT 3.2 compatible games with Weave it will play them as 3.2 does, with some bugfixes:

 - Bugs that crash the game are fixed.
 - Out-of-bounds movement is prohibited.
 - Conveyors no longer "eat" the player or other stats.
 - Placing stats, e.g. "#put <dir> lion", no longer leaves a hole in the floor.
 - Nested #bind commands no longer corrupt memory.
 - Overly large boards or worlds no longer crash the runtime.
    
Overall the experience is nicer. If you are making a game and want to modify some of ZZT's functionality, read on!

### What should I watch out for?

There are a couple potential roadblocks, both related to the DOS version:

- Weave attempts to load your ZZT files into EMS/XMS.
    - If your machine or emulator does not have those, Weave will probably not work.
- Weave can be resource intensive.
    - If you insist on emulating ZZT with a non-preferred emulator such as DOSBox, set your emulation speed to maximum.
    - Some Weave games will not perform well on original hardware.

### What can I do with it?

There are a few ways to learn what Weave can do for you:

- For a sampling of what you can do with Weave, check out the included WEAVEDMO.ZZT file.
- There is a quick reference guide, OOP-QR.TXT, with information about the new commands in ZZT-OOP.
- There is a complete manual, "THE WEAVE MANUAL.TXT", with detailed information.
- For information on supported MegaZeux .PAL and .CHR formats, seek out resources for MegaZeux.

### Okay, but WHAT CAN I DO WITH IT?

You can enhance your ZZT game with additional files. Here are the filetypes you can add to your game project:

- CFG: Adding a .CFG file lets you change the following and more:
    - ZZT's default messages and sounds.
    - The look of default items, terrains, text and the UI.
    - How many objects can be on screen at one time (the Stat Limit).
    - The 16 colors in ZZT's palette.
    - The list of counters you can modify with #GIVE and #TAKE.
    - The number of flags you can modify with #SET and #CLEAR.
    - The look of the sidebar and text windows.
    - The keybinds for built-in and custom operations.
- WEAVE.CFG: The WEAVE.CFG file is where you select options that apply before the game starts:
    - Default game speed and starting world.
    - Accessibility options.
    - Release and WebRelease modes for distribution.
- OBJ: You can do the following with .OBJ files:
    - Load or run ZZT-OOP code during gameplay.
    - Append functions to objects and call them with the #RUN command.
    - Retrieve saved board data.
- CHR and PAL:
    - MegaZeux .CHR and .PAL formats can be loaded.

For further explanation about any of the above, see the learning resources from the prior question.

### Anything else?

Weave provides tools for creating Weave and Web-playable ZZT games. They are in the TOOLS folder as follows:

- LOOMZZT.ZIP
    - A hacked version of KevEdit to make Weave 3 game creation easier.
    - Adds extra syntax highlighting.
    - Raises stat and board limits.
    - Supports custom text.
- WEBWEAVE.ZIP
    - A drag-and-drop utility to turn Weave files into web-playable content.
    - IF you want to use it, you will need to update the WEBWEAVESOURCE/ZZT.ZIP executable to the latest MS-DOS binary.
- ZLOOM2.ZIP
    - A hacked version of zedit2 with custom text support.
- UPX.EXE
    - Used during compilation to shrink ZZT.EXE's filesize.

### I want to compile my own. How do I do this?

- Native Windows
    - git pull --recurse-submodules (the SDL2 headers are in a Git submodule),
    - Install a fairly recent version of Free Pascal (tested with 3.2.2),
    - navigate to SRC_W34
    - Building for 32 bit (i386)
        - Run "fpc @fpc.sdl2.cfg ZZT.PAS"
    - Building for 64 bit (x86_64)
        - Run "fpc -Px86_64 @fpc.sdl2.cfg ZZT.PAS"
    - On Windows, provide SDL2.dll alongside the EXE
        - Make sure to provide a 32 or 64 bit SDL2.dll as appropriate.
- Native Linux
    - Please make use of the GitHub Actions associated with this respository.

- DOS build
    - Acquire the TPC.EXE and TURBO.TPL files from a legally acquired copy of Turbo Pascal 5.5.
    - Place those files in the same directory as the BUILDW34.BAT file.
    - Either on native hardware or in a DOS emulator, run BUILDW34.BAT.

### What Software License does this use?

With the exception of LOOMZZT, Weave 4 is MIT licensed. See LICENSE.TXT for details.

LOOMZZT is GPL-licensed. For details about its license, see the README.MD file included in the LOOMZZT source, provided with the program.
