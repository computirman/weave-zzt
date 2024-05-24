# WeaveZZT 3.3

With Weave 3.3, all previous recommendations for Weave have been addressed and the design specifications are frozen. It is the culmination of the Weave project.
We are experimenting with a couple possible final tweaks while spinning up work on a SuperZZT version of Weave.

Designed with the full scope of the ZZTer audience in mind, this version hopes to supply the needs of anyone that wants to tweak something about ZZT. Weave 2 made use of several accessory files to allow ZZTers to enhance their game's experience without diving into the Pascal code. Weave 3 restricts this to just two, with the following goals:

 - .CFG file weaving: To make cosmetic and rule changes about ZZT without expanding ZZT-OOP.
 - .INI file weaving: To expand ZZT-OOP with more counters, commands, and keybind inputs.

In the absence of any accompanying .CFG or .INI file, WEAVE3.EXE is designed to play normal ZZT games with sufficiently faithful accuracy that players won't be able to tell the difference. The exception is the removal of bugs that crash or softlock the game (as opposed to bugs frequently abused by adept ZZTers).

## Using

With your own copy of Turbo Pascal 5.5, you can compile WEAVE3.EXE yourself using the BUILDW30.BAT file provided in the WEAVE_30 subdirectory. Just make sure the TPC.EXE and TURBO.TPL files are in the same directory as the BUILDW30.BAT file. (These are DOS executables you will need a DOS emulator to compile.)

## Types of weaving

There are two primary types of weaving, as noted above. These center around the .CFG and .INI files that can accompany a Weave game.

For examples of .CFG weaving, look at the TEMPLATE.CFG example file in the WEAVE_30/SRC_W30 subdirectory.

For examples of .INI weaving, look at the TEMPLATE.INI file in the WEAVE_30/SRC_W30 subdirectory. Additionally, the inclusion of a .INI file unlocks new ZZT-OOP commands, some of which allow you to use other external files. For examples of those, have a look at the .OBJ files in that same subdirectory.
## File types in this project:

There are a few different kinds of files found in this project:

* PAS files:
    * The Turbo Pascal 5.5 source files for Weave.
* CFG files:
    * Custom strings.
    * Custom sounds.
    * Custom colors.
    * Custom element parameters.
    * Custom game settings.
    * WEAVEZZT.CFG includes custom startup behavior.
* INI files:
    * Custom flags and counters.
    * Custom keybinds.
* BAT files:
    * Used to compile Weave in DOS or DOSBox.
* TXT, DOC, PNG and HTM files:
    * Documents designed to be shipped with Weave.
* OBJ files:
    * ZZT-OOP code to be loaded into objects.
* ZZT files
    * Demonstration ZZT worlds for Weave.
* EXE files
    * LZEXE.EXE is the tool used to compress the weave EXE.
* ZIP files
    * Additional tools are provided to help newcomers with Weave.
    * The source code to produce these is also available.

## Files in this project:

Below are listed the files in the various folders of the project.

### WEAVE_30 directory

* TOOLS
    * UPX.EXE
        * For shrinking ZZT.EXE.
    * LOOMZZT.zip
        * For editing ZZT files with Weave 3 considerations.
        * Modification of cknave's KevEdit: https://github.com/cknave/kevedit
        * Source is included.
    * WEBWEAVE.zip
        * For distributing WeaveZZT worlds on the web.
        * Instructions are included.
    * WEBZZT32.ZIP
        * Uses a very slightly modified ZZT.EXE to distribute ZZT 3.2 worlds on the web.
    * ZLOOM2.zip
        * For editing ZZT files with Weave 3 considerations.
        * Modification of DrLancer-X's zedit2: https://github.com/DrLancer-X/zedit2
        * Source is included in the parent directory under zloom2-source.
* SRC_W33
    * ALL .PAS FILES (ELEMENTS.PAS, EXTMEM.PAS, etc.)
        * Forked from the ZZT Reconstruction and ClassicZoo.
        * Reconstruction: github.com/asiekierka/reconstruction-of-zzt
        * ClassicZoo: github.com/OpenZoo/ClassicZoo
    * ALL .OBJ FILES (ANGRY.OBJ, WONKY.OBJ, etc.)
        * Example objects and code used in the WeaveZZT demo.
    * WEAVEDMO.CFG
        * Element parameters for the WeaveZZT demo.
    * TEMPLATE.CFG
        * Parameters file with configuration options.
    * WEAVEDMO.INI
        * Counters and Keybinds for the WeaveZZT demo.
    * TEMPLATE.INI
        * Standard Counters and Keybinds template file.
    * Using_Weave_with_Zeta.htm
        * A simple tutorial to get you started using Weave with Zeta. Included with the Weave 2 download.
    * howto1.png, howto2.png, howto3.png
        * Companion images to the above tutorial.
* BUILDW33.BAT
    * Used in DOS or DOSBox to build Weave from source.
* LICENSE.TXT
    * MIT License, required by reconstruction-of-zzt.
* README.TXT
    * A brief explanation of Weaving.
* WEAVEDMO.ZZT
    * The WeaveZZT demo file.

## Questions

Hit me up in the ZZT Discord if you've got feedback or there's something to add. I'm not married to anything here so if there's a better way to do something, please ping the discord in #zzt-programs and throw a suggestion in there. You may have also seen a FIX_F10 directory in the source code; this is for FixWeave, a project that has stalled and whose future is uncertain. A companion page for FixWeave is available on Itch at **meangirls dot itch dot io slash fixweave-2**

Discord of ZZT Link: **museumofzzt dot com slash discord**
