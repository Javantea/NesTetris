randomNumberHighByte equ $17
randomNumberLowByte equ $18
nextSpawnId equ $19
spawnCount equ $1a

verticalBlankingInterval equ $33
pieceX equ $40
pieceY equ $41
pieceOrientation equ $42
level equ $44
fallTimer equ $45
autoRepeatX equ $46

playState equ $48

PLAY_STATE_UNASSIGN_ORIENTATION_ID equ $00
PLAY_STATE_TETRIMINO_ACTIVE equ $01
PLAY_STATE_LOCK_TETRIMINO equ $02
PLAY_STATE_CHECK_COMPLETED_ROWS equ $03
PLAY_STATE_LINE_CLEAR_ANIMATION equ $04
PLAY_STATE_UPDATE_LINES_STATS equ $05
PLAY_STATE_B_TYPE_GOAL_CHECK equ $06
PLAY_STATE_UNUSED_7 equ $07
PLAY_STATE_SPAWN_TETRIMINO equ $08
PLAY_STATE_UNUSED_9 equ $09
PLAY_STATE_GAME_OVER_CURTAIN equ $0a
PLAY_STATE_INCREMENT_PLAY_STATE equ $0b

vramRow  equ $49
completedRowIndices equ $4a ; $4a-$4d
autoRepeatY  equ $4e
linesLowByte equ $50
linesHighByte equ $51
clearColumnIndex equ $52
linesLowByteCopy equ $70
linesHighByteCopy equ $71

playMode equ $a7
lineIndex equ $a9
originalValue equ $ae
tempSpeed equ $af

frameCounterLowByte equ $b1
frameCounterHighByte equ $b2

renderMode equ $bd

RENDER_MODE_LEGAL_TITLE_SCREENS equ $00
RENDER_MODE_MENU_SCREENS equ $01
RENDER_MODE_CONGRATULATIONS_SCREENS equ $02
RENDER_MODE_PLAY_AND_DEMO_SCREENS equ $03
RENDER_MODE_ENDING_ANIMATION equ $04

numPlayers equ $be
nextTetrimino equ $bf

gameMode equ $c0
bType equ $c1

GAME_MODE_LEGAL_SCREEN equ $00
GAME_MODE_TITLE_SCREEN equ $01
GAME_MODE_GAME_TYPE_MENU equ $02
GAME_MODE_LEVEL_AND_HEIGHT_MENU equ $03
GAME_MODE_PLAY_HIGH_SCORE_ENDING_PAUSE equ $04
GAME_MODE_DEMO equ $05
GAME_MODE_INIT_DEMO equ $06

legalScreenCounter1 equ $c3
ending equ $c4

recordingMode equ $d0
demoButtonsLowByte equ $d1
demoButtonsHighByte equ $d2
demoIndex equ $d3

buttonsPressed1 equ $f5
buttonsPressed2 equ $f6
scrollY equ $fc
scrollX equ $fd
ppuMaskFlags equ $fe
ppuCtrlFlags equ $ff

tetriminoStatLowByte equ $3f0
tetriminoStatHighByte equ $3f1

noiseSoundEffect equ $6f0

GAME_OVER_CURTAIN_SOUND	equ $02
ENDING_ROCKET_SOUND equ $03

waveSoundEffect equ $6f1

MENU_OPTION_SELECT_SOUND equ $01
MENU_SCREEN_SELECT_SOUND equ $02
SHIFT_TETRIMINO_SOUND equ $03
TETRIS_ACHIEVED_SOUND equ $04
ROTATE_TETRIMINO_SOUND equ $05
LEVEL_UP_SOUND equ $06
LOCK_TETRIMINO_SOUND equ $07
CHIRP_CHIRP_SOUND equ $08
LINE_CLEARING_SOUND equ $09
LINE_COMPLETED_SOUND equ $0a