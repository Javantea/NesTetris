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
levelSelected equ $47

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
holdDownPoints equ $4f
linesLowByte equ $50
linesHighByte equ $51
clearColumnIndex equ $52
score equ $53 ; $53-$55
completedLines equ $56
completedLineIndex equ $57
curtainRow equ $58
bTypeHeight equ $59   
pieceXMirror equ $60
pieceYMirror equ $61
pieceOrientationMirror equ $62
levelMirror equ $64
fallTimerMirror equ $65
autoRepeatXMirror equ $66
levelSelectedMirror equ $67
playStateMirror equ $68
vramRowMirror equ $69
completedRowIndicesMirror equ $6a ; $6a-$6d
autoRepeatYMirror equ $6e
holdDownPointsMirror equ $6f
linesLowByteMirror equ $70
linesHighByteMirror equ $71
clearColumnIndexMirror equ $72
scoreMirror equ $73 ; $73-$75
completedLinesMirror equ $76
completedLineIndexMirror equ $77
curtainRowMirror equ $78
bTypeHeightMirror equ $79

playMode equ $a7
lineIndex equ $a9
loopIndex equ $aa
originalValue equ $ae
tempSpeed equ $af

frameCounterLowByte equ $b1
frameCounterHighByte equ $b2
buttonState equ $b5
buttonPressed equ $b6
leftPlayfield equ $b9
totalGarbage equ $bc
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
heldButtons equ $ce
repeats equ $cf

recordingMode equ $d0
demoButtonsLowByte equ $d1
demoButtonsHighByte equ $d2
demoIndex equ $d3

buttonStateMirror equ $f5
buttonPressedMirror equ $f6
heldButtonsMirror equ $f7
scrollY equ $fc
scrollX equ $fd
ppuMaskFlags equ $fe
ppuCtrlFlags equ $ff

tetriminoStats equ $3ef ; base address used in loops
tetriminoStatLowByte equ $3f0 ; $3f0-$3fd
tetriminoStatHighByte equ $3f1

playfield equ $400 ; $400-$4ff
playfield2 equ $500 ; $500-$5ff

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

backgroundMusic equ $6f5

UNUSED_TITLE_SCREEN_MUSIC equ $01
B_TYPE_GOAL_ACHIEVED_MUSIC equ $02
MUSIC_1_MUSIC equ $03
MUSIC_2_MUSIC equ $04
MUSIC_3_MUSIC equ $05
MUSIC_1_ALLEGRO_MUSIC equ $06
MUSIC_2_ALLEGRO_MUSIC equ $07
MUSIC_3_ALLEGRO_MUSIC equ $08
CONGRATULATIONS_SCREEN_MUSIC equ $09
ENDINGS_MUSIC equ $0a
B_TYPE_GOAL_ACHIEVED_2_MUSIC equ $0b
NO_MUSIC equ $ff

highScoreTable equ $700
highScoresAType equ $730
highScoresBType equ $73c
highScoreLevelsAType equ $748