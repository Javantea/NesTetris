# NES Tetris


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

## Romhacks


The ```master``` branch contains the code of the unmodified game.

Other branches modify the original game code to change various aspects of the game. Most of my ROM hacks are training
tools meant to help people improve at the game whilst a few other hacks change how the game plays or sounds.

### Controller input display

Branch: [controller_input_display](https://github.com/jazzthief81/NesTetris/tree/controller_input_display)

Shows the player inputs (A, B and D-pad) in the bottom right of the screen.

![Controller input display ROM hack](https://github.com/jazzthief81/llminxsolver/raw/master/docs/images/controller_input_display.png "Controller input display ROM hack")

### Accommodation stats

Branch: [accomodation_stats](https://github.com/jazzthief81/NesTetris/tree/accomodation_stats)

Shows a graph below the playfield that tells how many pieces (1-7) each column of the stack can accommodate cleanly.

![Accommodation stats ROM hack](https://github.com/jazzthief81/llminxsolver/raw/master/docs/images/accomodation_stats.png "Accommodation stats ROM hack")

### Drought stats

Branch: [drought_stats](https://github.com/jazzthief81/NesTetris/tree/drought_stats)

Uses the statistics panel to show the drought for each individual piece (i.e. how many piece drops ago did the game
spawn that specific piece).

![Drought stats ROM hack](https://github.com/jazzthief81/llminxsolver/raw/master/docs/images/drought_stats.png "Drought stats ROM hack")

### Lock indicator

Branch: [lock_indicator](https://github.com/jazzthief81/NesTetris/tree/lock_indicator)

Highlights the current piece the moment it locks into the playfield. During this time the D-pad can be pressed safely to
affect the direction of the next piece (aka loading DAS).

![Lock indicator ROM hack](https://github.com/jazzthief81/llminxsolver/raw/master/docs/images/lock_indicator.png "Lock indicator ROM hack")

### DAS trainer

Branch: [das_trainer](https://github.com/jazzthief81/NesTetris/tree/das_trainer)

![DAS trainer ROM hack](https://github.com/jazzthief81/llminxsolver/raw/master/docs/images/das_trainer.png "DAS trainer ROM hack")

Gives players feedback on their mastery of the DAS (Delayed Auto Shift) for moving pieces left and right quicker. The 
left hand side of the game screen, where the tetrimino statistics are usually shown in the original game, is instead
occupied by a window that shows detailed DAS statistics for the current piece, previous 4 pieces and aggregate stats for
the whole game.

### Fractional drop speeds

Branch: [fractional_drop_speeds](https://github.com/jazzthief81/NesTetris/tree/fractional_drop_speeds)

Attempts to apply fractional drop speeds (e.g. every 1.25 frames) by alternating between two drop speeds between frames. 
This will give a more gradual speed increase between levels 10-29 instead of having the usual speed jumps at levels 13, 
16, 19 and 29.

### Gameboy music

Branch: [gameboy_music](https://github.com/jazzthief81/NesTetris/tree/gameboy_music)

Replaces music 1 with the Korobeiniki theme from Gameboy tetris.

### Fixed piece set

Branch: [fixed_piece_set](https://github.com/jazzthief81/NesTetris/tree/fixed_piece_set)

Replaces the RNG with a fixed piece sequence embedded in the ROM. This allows other tools to overwrite a specific
section of the ROM to alter the piece sequence as desired.
