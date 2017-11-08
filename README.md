NES Tetris
==========

Reverse engineered from the USA version (NTSC) of Tetris for the Nintendo Entertainment System.

To assemble a ROM file that can be played on an emulator or on an actual NES using an SD/CF card solution (like the EverDrive
or the retroUSB PowerPak), follow these steps:

- Download and install dasm macro assembler: https://sourceforge.net/projects/dasm-dillon/
- Open a command line and make sure ```dasm.exe``` is in the path and can be invoked.
- From the command line execute the following command from the root of the repository:
```
dasm.exe tetris.s -f3 -oTetris.nes
```
- Open ```Tetris.nes``` in your favorite emulator or copy it to the ROM directory on the external media you're intending to use with the NES.