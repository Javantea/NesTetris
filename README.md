NES Tetris - DAS Trainer
========================

Reverse engineered from the USA version (NTSC) of Tetris for the Nintendo Entertainment System and modified to include a
DAS Trainer.

This is a modification gives players feedback on their mastery of the DAS (Delayed Auto Shift) for moving pieces left
and right quicker.

The left hand side of the game screen, where the tetrimino statistics are usually shown in the original game, is instead
occupied by a window that shows the following information:

- Active
	- The current DAS counter of the piece in play (going from 0 to 16).
	- The start DAS of the piece in play at the moment the piece spawned at the top and an indicator that shows the
		quality of the DAS (see Statistics below).
- Previous
	- The start DAS of the previous 4 pieces and an indicator that shows the quality of the DAS for those pieces (see
	  Statistics below).
- Statistics
	- Green heart: the number of pieces that had perfect DAS (start DAS between 15 and 16 and carried over successfully).
	- Yellow heart: the number of pieces that had good DAS (start DAS between 10 and 14 and carried over successfully).
	- Orange heart: the number of pieces that had bad DAS (start DAS between 0 and 9 and carried over successfully).
	- Red cross: the number of pieces that had no DAS (start DAS was not carried over successfully and DAS counter reset
				 during play).

In addition to the DAS window, some minor modifications are made to the game to make it more practice-friendly:

- The legal screen can be skipped at any time by pressing the START button instead of having to wait 4 seconds,
  allowing faster resets.
- Pausing the game keeps the game screen visible, allowing the player to analyze the board and inspect the DAS window
  during the game.
- If the game ends with a score of at least 30000, the game waits until the player presses START before the ending
  screen is shown, allowing the player to inspect the DAS window at the end of the game.
- Controller inputs (left, right, down, A and B buttons) are visualized on the bottom right.


To assemble a ROM file that can be played on an emulator or on an actual NES using an SD/CF card solution (like the EverDrive
or the retroUSB PowerPak), follow these steps:

- Download and install dasm macro assembler: https://sourceforge.net/projects/dasm-dillon/
- Open a command line and make sure ```dasm.exe``` is in the path and can be invoked.
- From the command line execute the following command from the root of the repository:
```
dasm.exe tetris.s -f3 -oTetris.nes
```
- Open ```Tetris.nes``` in your favorite emulator or copy it to the ROM directory on the external media you're intending to use with the NES.