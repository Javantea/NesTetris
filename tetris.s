        processor 6502

        include mmc1_registers.s
        include ppu_registers.s
        include control_port_registers.s
        include game_variables.s

        org $8000-$10

        ; ROM file header

        dc.b "NES", $1a
        dc.b $02 ; Size of PRG ROM in 16 KB units
        dc.b $02 ; Size of CHR ROM in 8 KB units
        dc.b $10 ; Flags 6 (Mapper = Nintendo MMC1)
        dc.b $00 ; Flags 7
        dc.b $00 ; Size of PRG RAM in 8 KB units
        dc.b $00 ; Flags 9
        dc.b $00 ; Flags 10 (unofficial)
        dc.b $00, $00, $00, $00, $00 ; Padding

        org $8000

boot
        ldx #$0
        jmp bootContinued
;--------------------
nmiHandler
        pha
        txa
        pha
        tya
        pha

        lda #$0
        sta objectAttributeMemoryIndex
        jsr render
        dec legalScreenCounter1
        lda legalScreenCounter1
        cmp #$ff
        bne lbl_801b
        inc legalScreenCounter1
lbl_801b
        jsr initializeOAM

        lda frameCounterLowByte
        clc
        adc #$1
        sta frameCounterLowByte
        lda #$0
        adc frameCounterHighByte
        sta frameCounterHighByte

        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber

        lda #$0
        sta scrollX
        sta PPUSCROLL
        sta scrollY
        sta PPUSCROLL

        lda #$1
        sta verticalBlankingInterval

        jsr updateControllerVariables

        pla
        tay
        pla
        tax
        pla
irqHandler
        rti
;--------------------
render subroutine
        lda renderMode
        jsr switch
        dc.b <renderLegalTitleScreens, >renderLegalTitleScreens             ; RENDER_MODE_LEGAL_TITLE_SCREENS
        dc.b <renderMenuScreens, >renderMenuScreens                         ; RENDER_MODE_MENU_SCREENS
        dc.b <renderCongratulationsScreens, >renderCongratulationsScreens   ; RENDER_MODE_CONGRATULATIONS_SCREENS
        dc.b <renderPlayAndDemoScreens, >renderPlayAndDemoScreens           ; RENDER_MODE_PLAY_AND_DEMO_SCREENS
        dc.b <renderEndingAnimation, >renderEndingAnimation                 ; RENDER_MODE_ENDING_ANIMATION
;--------------------
bootContinued subroutine
        ldy #>$0600        ; Clear memory from $0000-$06ff
        sty $1
        ldy #<$0600
        sty $0
        lda #$0
lbl_8064
        sta ($0),y
        dey
        bne lbl_8064
        dec $1
        bpl lbl_8064

        ; Verify whether the sequence $123456789a is present at memory starting at $750.

        lda $750
        cmp #$12
        bne lbl_8095
        lda $751
        cmp #$34
        bne lbl_8095
        lda $752
        cmp #$56
        bne lbl_8095
        lda $753
        cmp #$78
        bne lbl_8095
        lda $754
        cmp #$9a
        bne lbl_8095
        jmp .keepHighScores

        ; Copy initial highscore table from ROM to RAM.

        ldx #$0
lbl_8095
        lda initialHighScoreTable,x
        cmp #$ff
        beq lbl_80a3
        sta highScoreTable,x
        inx
        jmp lbl_8095

        ; Write sequence $123456789a in memory starting at $750

lbl_80a3
        lda #$12
        sta $750
        lda #$34
        sta $751
        lda #$56
        sta $752
        lda #$78
        sta $753
        lda #$9a
        sta $754

        ; Initialize random number to $8889.

.keepHighScores
        ldx #$89
        stx randomNumberHighByte
        dex
        stx randomNumberLowByte

        ; Initialize PPU registers.

        ldy #$0                ; scroll X = 0
        sty scrollX
        sty PPUSCROLL
        ldy #$0                ; scroll Y = 0
        sty scrollY
        sty PPUSCROLL
        lda #$90               ; Generate NMI at each vertical blanking interval, background pattern table at $1000
        sta ppuCtrlFlags
        sta PPUCTRL
        lda #$6                ; Show background, show leftmost 8 pixels of background.
        sta PPUMASK

        ; Initialize sound.

        jsr initAudio
        jsr resetAudio

        lda #$c0
        sta $100
        lda #$80
        sta $101
        lda #$35
        sta $103
        lda #$ac
        sta $104

        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI

        lda #$20
        jsr clearVRAM
        lda #$24
        jsr clearVRAM
        lda #$28
        jsr clearVRAM
        lda #$2c
        jsr clearVRAM

        lda #$ef
        ldx #$4
        ldy #$5
        jsr fillMemPage

        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #$e
        sta $34
        lda #$0
        sta playMode
        sta gameMode
        lda #$1
        sta numPlayers
        lda #$0
        sta frameCounterHighByte
mainGameLoop
        jsr advanceGameMode
        cmp playMode
        bne lbl_8142
        jsr waitForVerticalBlankAndClearOAM
lbl_8142
        lda gameMode
        cmp #GAME_MODE_DEMO
        bne notInDemoMode
        lda demoButtonsHighByte
        cmp #$df
        bne notInDemoMode
        lda #>demoButtons
        sta demoButtonsHighByte
        lda #<demoButtons
        sta frameCounterHighByte
        lda #GAME_MODE_TITLE_SCREEN
        sta gameMode
notInDemoMode
        jmp mainGameLoop
;--------------------
gameModePlay subroutine
        jsr advancePlayMode
        rts
;--------------------
advanceGameMode subroutine
        lda gameMode
        jsr switch
        dc.b <gameModeLegalScreen, >gameModeLegalScreen                   ; GAME_MODE_LEGAL_SCREEN
        dc.b <gameModeTitleScreen, >gameModeTitleScreen                   ; GAME_MODE_TITLE_SCREEN
        dc.b <gameModeGameTypeMenu, >gameModeGameTypeMenu                 ; GAME_MODE_GAME_TYPE_MENU
        dc.b <gameModeLevelAndHeightMenu, >gameModeLevelAndHeightMenu     ; GAME_MODE_LEVEL_AND_HEIGHT_MENU
        dc.b <gameModePlay, >gameModePlay                                 ; GAME_MODE_PLAY_HIGH_SCORE_ENDING_PAUSE
        dc.b <gameModePlay, >gameModePlay                                 ; GAME_MODE_DEMO
        dc.b <gameModeInitDemo, >gameModeInitDemo                         ; GAME_MODE_INIT_DEMO
;--------------------
advanceGame subroutine
        jsr recoverGameVariables
        jsr advancePlayState
        jsr showCurrentPiece
        jsr backupGameVariables
        jsr showNextTetrimino
        inc playMode
        rts
;--------------------
advanceGame2 subroutine
        lda numPlayers
        cmp #2
        bne .no2players
        jsr recoverGameVariables2
        jsr advancePlayState2
        jsr showCurrentPiece
        jsr backupGameVariables2
.no2players
        inc playMode
        rts
;--------------------
advancePlayMode subroutine
        lda playMode
        jsr switch
        dc.b <initializePlayBackground, >initializePlayBackground
        dc.b <initializeGame, >initializeGame
        dc.b <checkSelectPressed, >checkSelectPressed
        dc.b <showHighScore, >showHighScore
        dc.b <advanceGame, >advanceGame
        dc.b <advanceGame2, >advanceGame2
        dc.b <checkSoftReset, >checkSoftReset
        dc.b <checkStartPressed, >checkStartPressed
        dc.b <resetPlayMode, >resetPlayMode
;--------------------
advancePlayState subroutine
        lda playState
        jsr switch
        dc.b <unassignOrientationId, >unassignOrientationId    ; PLAY_STATE_UNASSIGN_ORIENTATION_ID
        dc.b <tetriminoActive, >tetriminoActive                ; PLAY_STATE_TETRIMINO_ACTIVE
        dc.b <lockTetrimino, >lockTetrimino                    ; PLAY_STATE_LOCK_TETRIMINO
        dc.b <checkCompletedRows, >checkCompletedRows          ; PLAY_STATE_CHECK_COMPLETED_ROWS
        dc.b <returnPlayState, >returnPlayState                ; PLAY_STATE_LINE_CLEAR_ANIMATION
        dc.b <updateLinesStats, >updateLinesStats              ; PLAY_STATE_UPDATE_LINES_STATS
        dc.b <checkBTypeGoal, >checkBTypeGoal                  ; PLAY_STATE_B_TYPE_GOAL_CHECK
        dc.b <unused2PlayerLogic, >unused2PlayerLogic          ; PLAY_STATE_UNUSED_7
        dc.b <spawnTetrimino, >spawnTetrimino                  ; PLAY_STATE_SPAWN_TETRIMINO
        dc.b <returnPlayState, >returnPlayState                ; PLAY_STATE_UNUSED_9
        dc.b <updateGameOverCurtain, >updateGameOverCurtain    ; PLAY_STATE_GAME_OVER_CURTAIN
        dc.b <incrementPlayState, >incrementPlayState          ; PLAY_STATE_INCREMENT_PLAY_STATE
;--------------------
tetriminoActive subroutine
        jsr shiftTetrimino
        jsr rotateTetrimino
        jsr dropTetrimino
        rts
;--------------------
advancePlayState2 subroutine
        lda playState
        jsr switch
        dc.b <unassignOrientationId, >unassignOrientationId    ; PLAY_STATE_UNASSIGN_ORIENTATION_ID
        dc.b <tetriminoActive2, >tetriminoActive2              ; PLAY_STATE_TETRIMINO_ACTIVE
        dc.b <lockTetrimino, >lockTetrimino                    ; PLAY_STATE_LOCK_TETRIMINO
        dc.b <checkCompletedRows, >checkCompletedRows          ; PLAY_STATE_CHECK_COMPLETED_ROWS
        dc.b <returnPlayState, >returnPlayState                ; PLAY_STATE_LINE_CLEAR_ANIMATION
        dc.b <updateLinesStats, >updateLinesStats              ; PLAY_STATE_UPDATE_LINES_STATS
        dc.b <checkBTypeGoal, >checkBTypeGoal                  ; PLAY_STATE_B_TYPE_GOAL_CHECK
        dc.b <unused2PlayerLogic, >unused2PlayerLogic          ; PLAY_STATE_UNUSED_7
        dc.b <spawnTetrimino, >spawnTetrimino                  ; PLAY_STATE_SPAWN_TETRIMINO
        dc.b <returnPlayState, >returnPlayState                ; PLAY_STATE_UNUSED_9
        dc.b <updateGameOverCurtain, >updateGameOverCurtain    ; PLAY_STATE_GAME_OVER_CURTAIN
        dc.b <incrementPlayState, >incrementPlayState          ; PLAY_STATE_INCREMENT_PLAY_STATE
;--------------------
tetriminoActive2
        jsr shiftTetrimino
        jsr rotateTetrimino
        jsr dropTetrimino
        rts
;--------------------
gameModeLegalScreen    subroutine
        jsr resetAudio
        lda #RENDER_MODE_LEGAL_TITLE_SCREENS
        sta renderMode
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda #$0
        jsr switchCharBank0
        lda #$0
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <copyright_screen_color_palette, >copyright_screen_color_palette
        jsr copyToVRAM
        dc.b <copyright_screen_background, >copyright_screen_background
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #$0
        ldx #$2
        ldy #$2
        jsr fillMemPage
        lda #$ff
        jsr initialLegalScreenWait
        lda #$ff
        sta $a8
.waitForStartPressedOrTimeOut
        lda buttonStateMirror
        cmp #JOYPAD_START
        beq .start
        jsr waitForVerticalBlankAndClearOAM
        dec $a8
        bne .waitForStartPressedOrTimeOut
.start    inc gameMode
        rts
;--------------------
gameModeTitleScreen subroutine
        jsr resetAudio
        lda #$0
        sta renderMode    ; RENDER_MODE_LEGAL_TITLE_SCREENS
        sta recordingMode
        sta nextTetriminoHidden
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda #$0
        jsr switchCharBank0
        lda #$0
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <menu_screen_color_palette, >menu_screen_color_palette
        jsr copyToVRAM
        dc.b <title_screen_background, >title_screen_background
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #$0
        ldx #$2
        ldy #$2
        jsr fillMemPage
        lda #$0
        sta frameCounterHighByte
.waitForStartPressedOrTimeOut
        jsr waitForVerticalBlankAndClearOAM
        lda buttonStateMirror
        cmp #JOYPAD_START
        beq .start
        lda frameCounterHighByte
        cmp #$5
        beq .startDemo
        jmp .waitForStartPressedOrTimeOut
.start    lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        inc gameMode
        rts
.startDemo
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        lda #GAME_MODE_INIT_DEMO
        sta gameMode
        rts
;--------------------
renderLegalTitleScreens
        lda ppuCtrlFlags
        and #$fc
        sta ppuCtrlFlags
        lda #$0
        sta scrollX
        sta PPUSCROLL
        sta scrollY
        sta PPUSCROLL
        rts
;--------------------
        lda #$0
        sta levelMirror
        lda #$0
        sta aType
        lda #GAME_MODE_PLAY_HIGH_SCORE_ENDING_PAUSE
        lda gameMode
        rts
;--------------------
gameModeGameTypeMenu subroutine
        inc MMC1_LOAD       ; Clear MMC1 shift register
        lda #$10
        jsr setMmc1Control
        lda #RENDER_MODE_MENU_SCREENS
        sta renderMode
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        jsr copyToVRAM
        dc.b <menu_screen_color_palette, >menu_screen_color_palette
        jsr copyToVRAM
        dc.b <game_select_screen_background, >game_select_screen_background
        lda #$0
        jsr switchCharBank0
        lda #$0
        jsr switchCharBank1
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        ldx activeMusic
        lda inGameMusics,x
        jsr startMusic
lbl_830b
        lda #$ff
        ldx #$2
        ldy #$2
        jsr fillMemPage
        lda buttonStateMirror
        cmp #JOYPAD_RIGHT
        bne lbl_8326
        lda #$1
        sta aType
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        jmp lbl_8335
lbl_8326
        lda buttonStateMirror
        cmp #JOYPAD_LEFT
        bne lbl_8335
        lda #$0
        sta aType
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
lbl_8335
        lda buttonStateMirror
        cmp #JOYPAD_DOWN
        bne lbl_8350
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda activeMusic
        cmp #$3
        beq lbl_8369
        inc activeMusic
        ldx activeMusic
        lda inGameMusics,x
        jsr startMusic
lbl_8350
        lda buttonStateMirror
        cmp #JOYPAD_UP
        bne lbl_8369
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda activeMusic
        beq lbl_8369
        dec activeMusic
        ldx activeMusic
        lda inGameMusics,x
        jsr startMusic
lbl_8369
        lda buttonStateMirror
        cmp #JOYPAD_START
        bne lbl_8377
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        inc gameMode
        rts
lbl_8377
        lda buttonStateMirror
        cmp #JOYPAD_B
        bne lbl_8389
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        lda #$0
        sta frameCounterHighByte
        dec gameMode
        rts
lbl_8389
        ldy #$0
        lda aType
        asl
        sta $a8
        asl
        adc $a8
        asl
        asl
        asl
        asl
        clc
        adc #$3f
        sta spriteX
        lda #$3f
        sta spriteY
        lda #$1
        sta objectAttributeEntryIndex
        lda frameCounterLowByte
        and #$3
        bne lbl_83ae
        lda #$2
        sta objectAttributeEntryIndex
lbl_83ae
        jsr copyObjectAttributeData
        lda activeMusic
        asl
        asl
        asl
        asl
        clc
        adc #$8f
        sta spriteY
        lda #$53
        sta objectAttributeEntryIndex
        lda #$67
        sta spriteX
        lda frameCounterLowByte
        and #$3
        bne lbl_83ce
        lda #$2
        sta objectAttributeEntryIndex
lbl_83ce
        jsr copyObjectAttributeData
        jsr waitForVerticalBlankAndClearOAM
        jmp lbl_830b
;--------------------
gameModeLevelAndHeightMenu subroutine
        inc MMC1_LOAD       ; Clear MMC1 shift register
        lda #$10
        jsr setMmc1Control
        jsr resetAudio
        lda #RENDER_MODE_MENU_SCREENS
        sta renderMode
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda #$0
        jsr switchCharBank0
        lda #$0
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <menu_screen_color_palette, >menu_screen_color_palette
        jsr copyToVRAM
        dc.b <level_select_screen_background, >level_select_screen_background
        lda aType
        bne lbl_8409
        jsr copyToVRAM
        dc.b <a_type_menu_color_palette_background, >a_type_menu_color_palette_background
lbl_8409        
        jsr copyHighScoreTableToVRAM
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        lda #$0
        sta PPUSCROLL
        lda #$0
        sta PPUSCROLL
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #$0
        sta originalValue
        sta tempSpeed
lbl_8428
        lda levelSelectedMirror
        cmp #$a
        bcc lbl_8436
        sec
        sbc #$a
        sta levelSelectedMirror
        jmp lbl_8428
lbl_8436
        lda #$0
        sta $b7
        lda levelSelectedMirror
        sta levelSelected
        lda bTypeHeightMirror
        sta bTypeHeight
        lda originalValue
        sta levelOrHeightSelected
        lda buttonStateMirror
        sta buttonState
        jsr handleLevelAndHeightInput
        lda levelSelected
        sta levelSelectedMirror
        lda bTypeHeight
        sta bTypeHeightMirror
        lda levelOrHeightSelected
        sta originalValue
        lda buttonStateMirror
        cmp #JOYPAD_START
        bne lbl_8478
        lda heldButtonsMirror
        cmp #(JOYPAD_START+JOYPAD_A)
        bne lbl_846c
        lda levelSelectedMirror
        clc
        adc #$a
        sta levelSelectedMirror
lbl_846c
        lda #$0
        sta playMode
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        inc gameMode
        rts
lbl_8478
        lda buttonStateMirror
        cmp #JOYPAD_B
        bne lbl_8486
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        dec gameMode
        rts
lbl_8486
        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber
        lda randomNumberHighByte
        and #$f
        cmp #$a
        bpl lbl_8486
        sta $7a
lbl_8497
        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber
        lda randomNumberHighByte
        and #$f
        cmp #$a
        bpl lbl_8497
        sta $9a
        jsr waitForVerticalBlankAndClearOAM
        jmp lbl_8436
;--------------------
handleLevelAndHeightInput subroutine
        lda buttonState
        cmp #JOYPAD_RIGHT
        bne lbl_84d0
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda levelOrHeightSelected
        bne lbl_84c8
        lda levelSelected
        cmp #$9
        beq lbl_84d0
        inc levelSelected
        jmp lbl_84d0
lbl_84c8
        lda bTypeHeight
        cmp #$5
        beq lbl_84d0
        inc bTypeHeight
lbl_84d0
        lda buttonState
        cmp #JOYPAD_LEFT
        bne lbl_84ee
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda levelOrHeightSelected
        bne lbl_84e8
        lda levelSelected
        beq lbl_84ee
        dec levelSelected
        jmp lbl_84ee
lbl_84e8
        lda bTypeHeight
        beq lbl_84ee
        dec bTypeHeight
lbl_84ee
        lda buttonState
        cmp #JOYPAD_DOWN
        bne lbl_8517
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda levelOrHeightSelected
        bne lbl_850b
        lda levelSelected
        cmp #$5
        bpl lbl_8517
        clc
        adc #$5
        sta levelSelected
        jmp lbl_8517
lbl_850b
        lda bTypeHeight
        cmp #$3
        bpl lbl_8517
        inc bTypeHeight
        inc bTypeHeight
        inc bTypeHeight
lbl_8517
        lda buttonState
        cmp #JOYPAD_UP
        bne lbl_8540
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda levelOrHeightSelected
        bne lbl_8534
        lda levelSelected
        cmp #$5
        bmi lbl_8540
        sec
        sbc #$5
        sta levelSelected
        jmp lbl_8540
lbl_8534
        lda bTypeHeight
        cmp #$3
        bmi lbl_8540
        dec bTypeHeight
        dec bTypeHeight
        dec bTypeHeight
lbl_8540
        lda aType
        beq lbl_8555
        lda buttonState
        cmp #JOYPAD_A
        bne lbl_8555
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda levelOrHeightSelected
        eor #$1
        sta levelOrHeightSelected
lbl_8555
        lda levelOrHeightSelected
        bne lbl_855f
        lda frameCounterLowByte
        and #$3
        beq lbl_8581
lbl_855f
        ldx levelSelected
        lda levelSelectSpriteY,x
        sta spriteY
        lda #$0
        sta objectAttributeEntryIndex
        ldx levelSelected
        lda levelSelectSpriteX,x
        sta spriteX
        lda $b7
        cmp #$1
        bne lbl_857e
        clc
        lda spriteY
        adc #$50
        sta spriteY
lbl_857e
        jsr copyObjectAttributeData
lbl_8581
        lda aType
        beq lbl_85b1
        lda levelOrHeightSelected
        beq lbl_858f
        lda frameCounterLowByte
        and #$3
        beq lbl_85b1
lbl_858f
        ldx bTypeHeight
        lda heightSelectSpriteY,x
        sta spriteY
        lda #$0
        sta objectAttributeEntryIndex
        ldx bTypeHeight
        lda heightSelectSpriteX,x
        sta spriteX
        lda $b7
        cmp #$1
        bne lbl_85ae
        clc
        lda spriteY
        adc #$50
        sta spriteY
lbl_85ae
        jsr copyObjectAttributeData
lbl_85b1
        rts
;--------------------
levelSelectSpriteY
        dc.b $53, $53, $53, $53, $53, $63, $63, $63, $63, $63
levelSelectSpriteX
        dc.b $34, $44, $54, $64, $74, $34, $44, $54, $64, $74
heightSelectSpriteY
        dc.b $53, $53, $53, $63, $63, $63
heightSelectSpriteX
        dc.b $9c, $ac, $bc, $9c, $ac, $bc
inGameMusics
        dc.b MUSIC_1_MUSIC, MUSIC_2_MUSIC, MUSIC_3_MUSIC, NO_MUSIC
        dc.b MUSIC_1_ALLEGRO_MUSIC, MUSIC_2_ALLEGRO_MUSIC, MUSIC_3_ALLEGRO_MUSIC, NO_MUSIC
;--------------------
renderMenuScreens subroutine
        lda ppuCtrlFlags
        and #$fc
        sta ppuCtrlFlags
        sta PPUCTRL        ;PPU Control Register #1
        lda #$0
        sta scrollX
        sta PPUSCROLL
        sta scrollY
        sta PPUSCROLL
        rts
;--------------------
initializePlayBackground subroutine
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda #$3
        jsr switchCharBank0
        lda #$3
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <ingame_screen_color_palette, >ingame_screen_color_palette
        jsr copyToVRAM
        dc.b <ingame_screen_background, >ingame_screen_background
        lda #$20
        sta PPUADDR
        lda #$83
        sta PPUADDR
        lda aType
        bne lbl_863c
        lda #$a                    ; Draw A in x-TYPE box
        sta PPUDATA
        lda #$20                   ; Draw top A-TYPE score
        sta PPUADDR
        lda #$b8
        sta PPUADDR
        lda highScoresAType
        jsr printTwoDigitNumber
        lda highScoresAType+1
        jsr printTwoDigitNumber
        lda highScoresAType+2
        jsr printTwoDigitNumber
        jmp lbl_8693
lbl_863c
        lda #$b                    ; Draw B in A-TYPE box
        sta PPUDATA
        lda #$20                   ; Draw top B-TYPE score
        sta PPUADDR
        lda #$b8
        sta PPUADDR
        lda highScoresBType
        jsr printTwoDigitNumber
        lda highScoresBType+1
        jsr printTwoDigitNumber
        lda highScoresBType+2
        jsr printTwoDigitNumber
        ldx #$0
lbl_865f
        lda heightBoxGraphics,x    ; Draw height box
        inx
        sta PPUADDR
        lda heightBoxGraphics,x
        inx
        sta PPUADDR
lbl_866d
        lda heightBoxGraphics,x
        inx
        cmp #$fe
        beq lbl_865f
        cmp #$fd
        beq lbl_867f
        sta PPUDATA
        jmp lbl_866d
lbl_867f
        lda #$23
        sta PPUADDR
        lda #$3b
        sta PPUADDR
        lda bTypeHeight
        and #$f
        sta PPUDATA
        jmp lbl_8693
lbl_8693
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #$1
        sta playStateMirror
        sta $88
        lda levelSelectedMirror
        sta levelMirror
        lda $87
        sta $84
        inc playMode
        rts
;--------------------
heightBoxGraphics
        dc.b $22, $f7, $38, $39, $39, $39, $39, $39, $39, $3a, $fe
        dc.b $23, $17, $3b, $11, $0e, $12, $10, $11, $1d, $3c, $fe
        dc.b $23, $37, $3b, $ff, $ff, $ff, $ff, $ff, $ff, $3c, $fe
        dc.b $23, $57, $3d, $3e, $3e, $3e, $3e, $3e, $3e, $3f, $fd
;--------------------
initializeGame subroutine
        lda #$ef
        ldx #$4
        ldy #$4
        jsr fillMemPage
        ldx #$f
        lda #$0
lbl_86e9
        sta tetriminoStats,x
        dex
        bne lbl_86e9
        lda #$5
        sta pieceXMirror
        sta $80
        lda #$0
        sta pieceYMirror
        sta $81
        sta vramRowMirror
        sta $89
        sta fallTimerMirror
        sta $85
        sta $bb
        sta totalGarbage
        sta scoreMirror
        sta scoreMirror+1
        sta scoreMirror+2
        sta $93
        sta $94
        sta $95
        sta linesLowByteMirror
        sta linesHighByteMirror
        sta $90
        sta $91
        sta $a4
        sta $d8
        sta $d9
        sta $da
        sta $db
        sta musicSpeed
        sta heldButtons
        sta repeats
        sta demoIndex
        sta demoButtonsLowByte
        sta nextSpawnId
        lda #$dd
        sta demoButtonsHighByte
        lda #RENDER_MODE_PLAY_AND_DEMO_SCREENS
        sta renderMode
        lda #160
        sta autoRepeatYMirror
        sta $8e
        jsr getNextTetrimino
        sta pieceOrientationMirror
        sta $82
        jsr updateTetriminoStats
        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber
        jsr getNextTetrimino
        sta nextTetrimino
        sta $a6
        lda aType
        beq lbl_8761
        lda #$25
        sta linesLowByteMirror
        sta $90
lbl_8761
        lda #$47
        sta $a3
        jsr waitForVerticalBlankAndClearOAM
        jsr generateInitialGarbage
        ldx activeMusic
        lda inGameMusics,x
        jsr startMusic
        inc playMode
        rts
;--------------------
recoverGameVariables subroutine
        lda #$1
        sta $b7
        lda #$4
        sta leftPlayfield
        lda buttonStateMirror
        sta buttonState
        lda heldButtonsMirror
        sta buttonPressed
        ldx #$1f
.nextVariable
        lda pieceXMirror,x
        sta pieceX,x
        dex
        cpx #$ff
        bne .nextVariable
        rts
;--------------------
recoverGameVariables2 subroutine
        lda #$2
        sta $b7
        lda #$5
        sta leftPlayfield
        lda buttonPressedMirror
        sta buttonState
        lda $f8
        sta buttonPressed
        ldx #$1f
.nextVariable
        lda $80,x
        sta pieceX,x
        dex
        cpx #$ff
        bne .nextVariable
        rts
;--------------------
backupGameVariables subroutine
        ldx #$1f
.nextVariable
        lda pieceX,x
        sta pieceXMirror,x
        dex
        cpx #$ff
        bne .nextVariable
        lda numPlayers
        cmp #$1
        beq .noTwoPlayer
        ldx $bb
        lda totalGarbage
        sta $bb
        stx totalGarbage
.noTwoPlayer
        rts
;--------------------
backupGameVariables2 subroutine
        ldx #$1f
.nextVariable
        lda pieceX,x
        sta $80,x
        dex
        cpx #$ff
        bne .nextVariable
        ldx $bb
        lda totalGarbage
        sta $bb
        stx totalGarbage
        rts
;--------------------
generateInitialGarbage subroutine
        lda aType
        bne lbl_87e3
        jmp lbl_8875
lbl_87e3
        lda #$c
        sta $a8
lbl_87e7
        lda $a8
        beq lbl_884a
        lda #$14
        sec
        sbc $a8
        sta lineIndex
        lda #$0
        sta vramRowMirror
        sta $89
        lda #$9
        sta loopIndex
lbl_87fc
        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber
        lda randomNumberHighByte
        and #$7
        tay
        lda garbageTiles,y
        sta $ab
        ldx lineIndex
        lda playfieldAddresses,x
        clc
        adc loopIndex
        tay
        lda $ab
        sta playfield,y
        lda loopIndex
        beq lbl_8824
        dec loopIndex
        jmp lbl_87fc
lbl_8824
        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber
        lda randomNumberHighByte
        and #$f
        cmp #$a
        bpl lbl_8824
        sta $ac
        ldx lineIndex
        lda playfieldAddresses,x
        clc
        adc $ac
        tay
        lda #$ef
        sta playfield,y
        jsr waitForVerticalBlankAndClearOAM
        dec $a8
        bne lbl_87e7
lbl_884a
        ldx #$c8
lbl_884c
        lda playfield,x
        sta playfield2,x
        dex
        bne lbl_884c
        ldx bTypeHeightMirror
        lda garbageHeight,x
        tay
        lda #$ef
lbl_885d
        sta playfield,y
        dey
        cpy #$ff
        bne lbl_885d
        ldx $99
        lda garbageHeight,x
        tay
        lda #$ef
lbl_886d
        sta playfield2,y
        dey
        cpy #$ff
        bne lbl_886d
lbl_8875
        rts
;--------------------
garbageHeight
        dc.b $c8, $aa, $96, $78, $64, $50
garbageTiles
        dc.b $ef, $7b, $ef, $7c, $7d, $7d, $ef, $ef
;--------------------
checkSelectPressed subroutine        
        lda #$3
        jsr switchCharBank0
        lda #$3
        jsr switchCharBank1
        lda #$0
        sta objectAttributeMemoryIndex
        inc fallTimerMirror
        inc $85
        lda $a4
        beq lbl_889c
        inc $a4
lbl_889c
        lda buttonStateMirror
        and #JOYPAD_SELECT
        beq .selectNotPressed
        lda nextTetriminoHidden
        eor #$1
        sta nextTetriminoHidden
.selectNotPressed
        inc playMode
        rts
;--------------------
rotateTetrimino subroutine
        lda pieceOrientation
        sta originalValue
        clc
        lda pieceOrientation
        asl
        tax
        lda buttonState
        and #JOYPAD_A
        cmp #JOYPAD_A
        bne .aNotPressed
        inx
        lda rotationTable,x
        sta pieceOrientation
        jsr isPositionValid
        bne .restoreOriginalOrientation
        lda #ROTATE_TETRIMINO_SOUND
        sta waveSoundEffect
        jmp .return
.aNotPressed
        lda buttonState
        and #JOYPAD_B
        cmp #JOYPAD_B
        bne .return
        lda rotationTable,x
        sta pieceOrientation
        jsr isPositionValid
        bne .restoreOriginalOrientation
        lda #ROTATE_TETRIMINO_SOUND
        sta waveSoundEffect
        jmp .return
.restoreOriginalOrientation
        lda originalValue
        sta pieceOrientation
.return
        rts
;--------------------
rotationTable
        dc.b $03, $01 ; 00: T up
        dc.b $00, $02 ; 01: T right
        dc.b $01, $03 ; 02: T down (spawn)
        dc.b $02, $00 ; 03: T left

        dc.b $07, $05 ; 04: J left
        dc.b $04, $06 ; 05: J up
        dc.b $05, $07 ; 06: J right
        dc.b $06, $04 ; 07: J down (spawn)

        dc.b $09, $09 ; 08: Z horizontal (spawn)
        dc.b $08, $08 ; 09: Z vertical

        dc.b $0a, $0a ; 0A: O (spawn)
        dc.b $0c, $0c
                      ; 0B: S horizontal (spawn)
        dc.b $0b, $0b ; 0C: S vertical

        dc.b $10, $0e ; 0D: L right
        dc.b $0d, $0f ; 0E: L down (spawn)
        dc.b $0e, $10 ; 0F: L left
        dc.b $0f, $0d ; 10: L up

        dc.b $12, $12 ; 11: I vertical
        dc.b $11, $11 ; 12: I horizontal (spawn)
;--------------------
dropTetrimino subroutine
        lda autoRepeatY
        bpl .playing
        lda buttonState
        and #JOYPAD_DOWN
        beq .incrementAutoRepeatY
        lda #$0				; Player just pressed down, ending startup delay.
        sta autoRepeatY
.playing
        bne .autoRepeating
        lda buttonPressed
        and #(JOYPAD_RIGHT+JOYPAD_LEFT)
        bne .lookupDropSpeed
        lda buttonState
        and #JOYPAD_UP+JOYPAD_DOWN+JOYPAD_RIGHT+JOYPAD_LEFT
        cmp #JOYPAD_DOWN
        bne .lookupDropSpeed
        lda #$1
        sta autoRepeatY
        jmp .lookupDropSpeed
.autoRepeating
        lda buttonPressed
        and #JOYPAD_UP+JOYPAD_DOWN+JOYPAD_RIGHT+JOYPAD_LEFT
        cmp #JOYPAD_DOWN
        beq .downPressed
        lda #$0
        sta autoRepeatY
        sta holdDownPoints
        jmp .lookupDropSpeed
.downPressed
        inc autoRepeatY
        lda autoRepeatY
        cmp #$3
        bcc .lookupDropSpeed
        lda #$1
        sta autoRepeatY
        inc holdDownPoints
.drop
        lda #$0
        sta fallTimer
        lda pieceY
        sta originalValue
        inc pieceY
        jsr isPositionValid
        beq .return
        lda originalValue
        sta pieceY
        lda #PLAY_STATE_LOCK_TETRIMINO
        sta playState
        jsr updatePlayfield
.return
        rts
.lookupDropSpeed
        lda #1
        ldx level
        cpx #29
        bcs .noTableLookup
        lda framesPerDropTable,x
.noTableLookup
        sta tempSpeed
        lda fallTimer
        cmp tempSpeed
        bpl .drop
        jmp .return
.incrementAutoRepeatY
        inc autoRepeatY
        jmp .return
;--------------------
framesPerDropTable
        dc.b $30, $2b, $26, $21, $1c, $17, $12, $0d, $08, $06, $05, $05, $05, $04, $04, $04
        dc.b $03, $03, $03, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01
;--------------------
shiftTetrimino subroutine
        lda pieceX
        sta originalValue
        lda buttonPressed
        and #JOYPAD_DOWN
        bne .return
        lda buttonState
        and #(JOYPAD_RIGHT+JOYPAD_LEFT)
        bne .resetAutoRepeatX
        lda buttonPressed
        and #(JOYPAD_RIGHT+JOYPAD_LEFT)
        beq .return
        inc autoRepeatX
        lda autoRepeatX         ; Maximum charge reached?
        cmp #$10
        bmi .return
        lda #$a					; Recharge for next shift.
        sta autoRepeatX
        jmp .buttonHeldDown
.resetAutoRepeatX
        lda #$0					; Completely uncharge.
        sta autoRepeatX
.buttonHeldDown
        lda buttonPressed
        and #JOYPAD_RIGHT
        beq .notPressingRight
        inc pieceX
        jsr isPositionValid
        bne .restoreX
        lda #SHIFT_TETRIMINO_SOUND
        sta waveSoundEffect
        jmp .return
.notPressingRight
        lda buttonPressed
        and #JOYPAD_LEFT
        beq .return
        dec pieceX
        jsr isPositionValid
        bne .restoreX
        lda #SHIFT_TETRIMINO_SOUND
        sta waveSoundEffect
        jmp .return
.restoreX
        lda originalValue
        sta pieceX
        lda #$10				; Wall charge
        sta autoRepeatX
.return
        rts
;--------------------
showCurrentPiece subroutine
        lda pieceX
        asl
        asl
        asl
        adc #$60
        sta loopIndex
        lda numPlayers
        cmp #$1
        beq lbl_8a2c
        lda loopIndex
        sec
        sbc #$40
        sta loopIndex
        lda $b7
        cmp #$1
        beq lbl_8a2c
        lda loopIndex
        adc #$6f
        sta loopIndex
lbl_8a2c
        clc
        lda pieceY
        rol
        rol
        rol
        adc #$2f
        sta $ab
        lda pieceOrientation
        sta $ac
        clc
        lda $ac
        rol
        rol
        sta $a8
        rol
        adc $a8
        tax
        ldy objectAttributeMemoryIndex
        lda #$4
        sta lineIndex
lbl_8a4b
        lda orientationTable,x
        asl
        asl
        asl
        clc
        adc $ab
        sta objectAttributeMemory,y
        sta originalValue
        inc objectAttributeMemoryIndex
        iny
        inx
        lda orientationTable,x
        sta objectAttributeMemory,y
        inc objectAttributeMemoryIndex
        iny
        inx
        lda #$2
        sta objectAttributeMemory,y
        lda originalValue
        cmp #$2f
        bcs lbl_8a84
        inc objectAttributeMemoryIndex
        dey
        lda #$ff
        sta objectAttributeMemory,y
        iny
        iny
        lda #$0
        sta objectAttributeMemory,y
        jmp lbl_8a93
lbl_8a84
        inc objectAttributeMemoryIndex
        iny
        lda orientationTable,x
        asl
        asl
        asl
        clc
        adc loopIndex
        sta objectAttributeMemory,y
lbl_8a93
        inc objectAttributeMemoryIndex
        iny
        inx
        dec lineIndex
        bne lbl_8a4b
        rts
;--------------------
        ; Represents the coordinates of the various Tetrimino orientations.

orientationTable
        dc.b $00, $7b, $ff, $00, $7b, $00, $00, $7b, $01, $ff, $7b, $00 ; 00: T up
        dc.b $ff, $7b, $00, $00, $7b, $00, $00, $7b, $01, $01, $7b, $00 ; 01: T right
        dc.b $00, $7b, $ff, $00, $7b, $00, $00, $7b, $01, $01, $7b, $00 ; 02: T down (spawn)
        dc.b $ff, $7b, $00, $00, $7b, $ff, $00, $7b, $00, $01, $7b, $00 ; 03: T left

        dc.b $ff, $7d, $00, $00, $7d, $00, $01, $7d, $ff, $01, $7d, $00 ; 04: J left
        dc.b $ff, $7d, $ff, $00, $7d, $ff, $00, $7d, $00, $00, $7d, $01 ; 05: J up
        dc.b $ff, $7d, $00, $ff, $7d, $01, $00, $7d, $00, $01, $7d, $00 ; 06: J right
        dc.b $00, $7d, $ff, $00, $7d, $00, $00, $7d, $01, $01, $7d, $01 ; 07: J down (spawn)

        dc.b $00, $7c, $ff, $00, $7c, $00, $01, $7c, $00, $01, $7c, $01 ; 08: Z horizontal (spawn)
        dc.b $ff, $7c, $01, $00, $7c, $00, $00, $7c, $01, $01, $7c, $00 ; 09: Z vertical

        dc.b $00, $7b, $ff, $00, $7b, $00, $01, $7b, $ff, $01, $7b, $00 ; 0A: O (spawn)

        dc.b $00, $7d, $00, $00, $7d, $01, $01, $7d, $ff, $01, $7d, $00 ; 0B: S horizontal (spawn)
        dc.b $ff, $7d, $00, $00, $7d, $00, $00, $7d, $01, $01, $7d, $01 ; 0C: S vertical

        dc.b $ff, $7c, $00, $00, $7c, $00, $01, $7c, $00, $01, $7c, $01 ; 0D: L right
        dc.b $00, $7c, $ff, $00, $7c, $00, $00, $7c, $01, $01, $7c, $ff ; 0E: L down (spawn)
        dc.b $ff, $7c, $ff, $ff, $7c, $00, $00, $7c, $00, $01, $7c, $00 ; 0F: L left
        dc.b $ff, $7c, $01, $00, $7c, $ff, $00, $7c, $00, $00, $7c, $01 ; 10: L up

        dc.b $fe, $7b, $00, $ff, $7b, $00, $00, $7b, $00, $01, $7b, $00 ; 11: I vertical
        dc.b $00, $7b, $fe, $00, $7b, $ff, $00, $7b, $00, $00, $7b, $01 ; 12: I horizontal (spawn)

        dc.b $00, $ff, $00, $00, $ff, $00, $00, $ff, $00, $00, $ff, $00 ; 13: Unused

lbl_8b8c        
        lda $a2
        asl
        asl
        sta $a8
        asl
        clc
        adc $a8
        tay
        ldx objectAttributeMemoryIndex
        lda #$4
        sta lineIndex
lbl_8b9d
        lda orientationTable,y
        clc
        asl
        asl
        asl
        adc spriteY
        sta objectAttributeMemory,x
        inx
        iny
        lda orientationTable,y
        sta objectAttributeMemory,x
        inx
        iny
        lda #$2
        sta objectAttributeMemory,x
        inx
        lda orientationTable,y
        clc
        asl
        asl
        asl
        adc spriteX
        sta objectAttributeMemory,x
        inx
        iny
        dec lineIndex
        bne lbl_8b9d
        stx objectAttributeMemoryIndex
        rts
;--------------------
showNextTetrimino subroutine
        lda nextTetriminoHidden
        bne .return
        lda #$c8
        sta spriteX
        lda #$77
        sta spriteY
        ldx nextTetrimino
        lda tetriminoSpriteIndex,x
        sta objectAttributeEntryIndex
        jmp copyObjectAttributeData
.return
        rts
;--------------------
tetriminoSpriteIndex
        dc.b $00, $00, $06, $00, $00, $00, $00, $09, $08, $00, $0b, $07, $00, $00, $0a, $00
        dc.b $00, $00, $0c
        dc.b $00, $00, $0f, $00, $00, $00, $00, $12, $11, $00, $14, $10, $00, $00, $13, $00
        dc.b $00, $00, $15
        dc.b $00, $ff, $fe, $fd, $fc, $fd, $fe, $ff, $00, $01, $02, $03, $04, $05, $06, $07
        dc.b $08, $09, $0a, $0b, $0c, $0d, $0e, $0f, $10, $11, $12, $13
;--------------------
copyObjectAttributeData subroutine
        clc
        lda objectAttributeEntryIndex
        rol
        tax
        lda objectAttributeData,x
        sta objectAttributeEntryBase
        inx
        lda objectAttributeData,x
        sta objectAttributeEntryBase+1
        ldx objectAttributeMemoryIndex
        ldy #0
.nextSprite
        lda (objectAttributeEntryBase),y
        cmp #$ff
        beq .return
        clc
        adc spriteY
        sta objectAttributeMemory,x
        inx
        iny
        lda (objectAttributeEntryBase),y
        sta objectAttributeMemory,x
        inx
        iny
        lda (objectAttributeEntryBase),y
        sta objectAttributeMemory,x
        inx
        iny
        lda (objectAttributeEntryBase),y
        clc
        adc spriteX
        sta objectAttributeMemory,x
        inx
        iny
        lda #4
        clc
        adc objectAttributeMemoryIndex
        sta objectAttributeMemoryIndex
        jmp .nextSprite
.return
        rts
;--------------------
		include object_attribute_data.s
;--------------------
isPositionValid subroutine
        lda pieceY
        asl
        sta $a8
        asl
        asl
        clc
        adc $a8
        adc pieceX
        sta $a8
        lda pieceOrientation
        asl
        asl
        sta lineIndex
        asl
        clc
        adc lineIndex
        tax
        ldy #$0
        lda #$4
        sta loopIndex
lbl_94aa
        lda orientationTable,x
        clc
        adc pieceY
        adc #$2
        cmp #$16
        bcs lbl_94e9
        lda orientationTable,x
        asl
        sta $ab
        asl
        asl
        clc
        adc $ab
        clc
        adc $a8
        sta $ad
        inx
        inx
        lda orientationTable,x
        clc
        adc $ad
        tay
        lda ($b8),y
        cmp #$ef
        bcc lbl_94e9
        lda orientationTable,x
        clc
        adc pieceX
        cmp #$a
        bcs lbl_94e9
        inx
        dec loopIndex
        bne lbl_94aa
        lda #$0
        sta $a8
        rts
lbl_94e9
        lda #$ff
        sta $a8
        rts
;--------------------
renderPlayAndDemoScreens subroutine
        lda playStateMirror
        cmp #$4
        bne lbl_9522
        lda #$4
        sta leftPlayfield
        lda clearColumnIndexMirror
        sta clearColumnIndex
        lda completedRowIndicesMirror
        sta completedRowIndices
        lda completedRowIndicesMirror+1
        sta completedRowIndices+1
        lda completedRowIndicesMirror+2
        sta completedRowIndices+2
        lda completedRowIndicesMirror+3
        sta completedRowIndices+3
        lda playStateMirror
        sta playState
        jsr updateLineClearingAnimation
        lda clearColumnIndex
        sta clearColumnIndexMirror
        lda playState
        sta playStateMirror
        lda #$0
        sta vramRowMirror
        jmp lbl_953a
lbl_9522
        lda vramRowMirror
        sta vramRow
        lda #$4
        sta leftPlayfield
        jsr copyPlayfieldRowToVRAM
        jsr copyPlayfieldRowToVRAM
        jsr copyPlayfieldRowToVRAM
        jsr copyPlayfieldRowToVRAM
        lda vramRow
        sta vramRowMirror
lbl_953a
        lda numPlayers
        cmp #$2
        bne lbl_958c
        lda $88
        cmp #$4
        bne lbl_9574
        lda #$5
        sta leftPlayfield
        lda $92
        sta clearColumnIndex
        lda $8a
        sta completedRowIndices
        lda $8b
        sta completedRowIndices+1
        lda $8c
        sta completedRowIndices+2
        lda $8d
        sta completedRowIndices+3
        lda $88
        sta playState
        jsr updateLineClearingAnimation
        lda clearColumnIndex
        sta $92
        lda playState
        sta $88
        lda #$0
        sta $89
        jmp lbl_958c
lbl_9574
        lda $89
        sta vramRow
        lda #$5
        sta leftPlayfield
        jsr copyPlayfieldRowToVRAM
        jsr copyPlayfieldRowToVRAM
        jsr copyPlayfieldRowToVRAM
        jsr copyPlayfieldRowToVRAM
        lda vramRow
        sta $89
lbl_958c
        lda $a3
        and #$1
        beq lbl_95e3
        lda numPlayers
        cmp #$2
        beq lbl_95b5
        lda #$20
        sta PPUADDR
        lda #$73
        sta PPUADDR
        lda linesHighByteMirror
        sta PPUDATA
        lda linesLowByteMirror
        jsr printTwoDigitNumber
        lda $a3
        and #$fe
        sta $a3
        jmp lbl_95e3
lbl_95b5
        lda #$20
        sta PPUADDR
        lda #$68
        sta PPUADDR
        lda linesHighByteMirror
        sta PPUDATA
        lda linesLowByteMirror
        jsr printTwoDigitNumber
        lda #$20
        sta PPUADDR
        lda #$7a
        sta PPUADDR
        lda $91
        sta PPUDATA
        lda $90
        jsr printTwoDigitNumber
        lda $a3
        and #$fe
        sta $a3
lbl_95e3
        lda $a3
        and #$2
        beq lbl_960e
        lda numPlayers
        cmp #$2
        beq lbl_960e
        ldx levelMirror
        lda levelToBinaryCodedDecimal,x
        sta $a8
        lda #$22
        sta PPUADDR
        lda #$ba
        sta PPUADDR
        lda $a8
        jsr printTwoDigitNumber
        jsr updateLevelColors
        lda $a3
        and #$fd
        sta $a3
lbl_960e
        lda numPlayers
        cmp #$2
        beq lbl_9639
        lda $a3
        and #$4
        beq lbl_9639
        lda #$21
        sta PPUADDR
        lda #$18
        sta PPUADDR
        lda scoreMirror+2
        jsr printTwoDigitNumber
        lda scoreMirror+1
        jsr printTwoDigitNumber
        lda scoreMirror
        jsr printTwoDigitNumber
        lda $a3
        and #$fb
        sta $a3
lbl_9639
        lda numPlayers
        cmp #$2
        beq lbl_9673
        lda $a3
        and #$40
        beq lbl_9673
        lda #$0
        sta $b0
lbl_9649
        lda $b0
        asl
        tax
        lda tetriminoStatsVramAdresses,x
        sta PPUADDR
        lda tetriminoStatsVramAdresses+1,x
        sta PPUADDR
        lda tetriminoStatHighByte,x
        sta PPUDATA
        lda tetriminoStatLowByte,x
        jsr printTwoDigitNumber
        inc $b0
        lda $b0
        cmp #$7
        bne lbl_9649
        lda $a3
        and #$bf
        sta $a3
lbl_9673
        lda #$3f
        sta PPUADDR
        lda #$e
        sta PPUADDR
        ldx #$0
        lda completedLines
        cmp #$4
        bne lbl_9698
        lda frameCounterLowByte
        and #$3
        bne lbl_9698
        ldx #$30
        lda frameCounterLowByte
        and #$7
        bne lbl_9698
        lda #LINE_CLEARING_SOUND
        sta waveSoundEffect
lbl_9698
        stx PPUDATA
        ldy #$0
        sty scrollX
        sty PPUSCROLL
        ldy #$0
        sty scrollY
        sty PPUSCROLL
        rts
;--------------------
tetriminoStatsVramAdresses
        dc.b $21, $86, $21, $c6, $22, $06, $22, $46, $22, $86, $22, $c6, $23, $06
levelToBinaryCodedDecimal
        dc.b $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $10, $11, $12, $13, $14, $15
        dc.b $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29
playfieldAddresses           ; playfieldAddress = 10 * vramRow
        dc.b $00, $0a, $14, $1e, $28, $32, $3c, $46, $50, $5a, $64, $6e, $78, $82, $8c, $96
        dc.b $a0, $aa, $b4, $be
vramPlayfieldRows
        dc.b $c6, $20, $e6, $20, $06, $21, $26, $21, $46, $21, $66, $21, $86, $21, $a6, $21
        dc.b $c6, $21, $e6, $21, $06, $22, $26, $22, $46, $22, $66, $22, $86, $22, $a6, $22
        dc.b $c6, $22, $e6, $22, $06, $23, $26, $23
printTwoDigitNumber
        sta $a8
        and #$f0
        lsr
        lsr
        lsr
        lsr
        sta PPUDATA
        lda $a8
        and #$f
        sta PPUDATA
        rts
;--------------------
copyPlayfieldRowToVRAM subroutine
        ldx vramRow
        cpx #$15
        bpl lbl_977e
        lda playfieldAddresses,x
        tay
        txa
        asl
        tax
        inx
        lda vramPlayfieldRows,x
        sta PPUADDR
        dex
        lda numPlayers
        cmp #$1
        beq lbl_975e
        lda leftPlayfield
        cmp #$5
        beq lbl_9752
        lda vramPlayfieldRows,x
        sec
        sbc #$2
        sta PPUADDR
        jmp lbl_9767
lbl_9752
        lda vramPlayfieldRows,x
        clc
        adc #$c
        sta PPUADDR
        jmp lbl_9767
lbl_975e
        lda vramPlayfieldRows,x
        clc
        adc #$6
        sta PPUADDR
lbl_9767
        ldx #$a
lbl_9769
        lda ($b8),y
        sta PPUDATA
        iny
        dex
        bne lbl_9769
        inc vramRow
        lda vramRow
        cmp #$14
        bmi lbl_977e
        lda #$20
        sta vramRow
lbl_977e
        rts
;--------------------
updateLineClearingAnimation subroutine
        lda frameCounterLowByte
        and #$3
        bne lbl_97fd
        lda #$0
        sta loopIndex
lbl_9789
        ldx loopIndex
        lda completedRowIndices,x
        beq lbl_97eb
        asl
        tay
        lda vramPlayfieldRows,y
        sta $a8
        lda numPlayers
        cmp #$1
        bne lbl_97a6
        lda $a8
        clc
        adc #$6
        sta $a8
        jmp lbl_97bd
lbl_97a6
        lda leftPlayfield
        cmp #$4
        bne lbl_97b6
        lda $a8
        sec
        sbc #$2
        sta $a8
        jmp lbl_97bd
lbl_97b6
        lda $a8
        clc
        adc #$c
        sta $a8
lbl_97bd
        iny
        lda vramPlayfieldRows,y
        sta lineIndex
        sta PPUADDR
        ldx clearColumnIndex
        lda leftColumns,x
        clc
        adc $a8
        sta PPUADDR
        lda #$ff
        sta PPUDATA
        lda lineIndex
        sta PPUADDR
        ldx clearColumnIndex
        lda rightColumns,x
        clc
        adc $a8
        sta PPUADDR
        lda #$ff
        sta PPUDATA
lbl_97eb
        inc loopIndex
        lda loopIndex
        cmp #$4
        bne lbl_9789
        inc clearColumnIndex
        lda clearColumnIndex
        cmp #$5
        bmi lbl_97fd
        inc playState
lbl_97fd
        rts
;--------------------
leftColumns
        dc.b $04, $03, $02, $01, $00
rightColumns
        dc.b $05, $06, $07, $08, $09
;--------------------
updateLevelColors subroutine
        lda levelMirror         ; Calculate last digit of level.
.isBelow10
        cmp #10
        bmi .copyLevelColors
        sec
        sbc #10
        jmp .isBelow10
.copyLevelColors
        asl
        asl
        tax
        lda #$0
        sta $a8
.nextPaletteRange        
        lda #$3f
        sta PPUADDR
        lda #$8
        clc
        adc $a8
        sta PPUADDR
        lda levelColors,x
        sta PPUDATA
        lda levelColors+1,x
        sta PPUDATA
        lda levelColors+2,x
        sta PPUDATA
        lda levelColors+3,x
        sta PPUDATA
        lda $a8
        clc
        adc #$10
        sta $a8
        cmp #$20
        bne .nextPaletteRange
        rts
;--------------------
levelColors
        dc.b $0f, $30, $21, $12
        dc.b $0f, $30, $29, $1a
        dc.b $0f, $30, $24, $14
        dc.b $0f, $30, $2a, $12
        dc.b $0f, $30, $2b, $15
        dc.b $0f, $30, $22, $2b
        dc.b $0f, $30, $00, $16
        dc.b $0f, $30, $05, $13
        dc.b $0f, $30, $16, $12
        dc.b $0f, $30, $27, $16
;--------------------
doNothing subroutine
        rts
        inc vramRowMirror
        lda vramRowMirror
        cmp #$14
        bmi lbl_9881
        lda #$20
        sta vramRowMirror
lbl_9881
        inc $89
        lda $89
        cmp #$14
        bmi lbl_988d
        lda #$20
        sta $89
lbl_988d
        rts
;--------------------
spawnTetrimino subroutine
        lda vramRow
        cmp #$20
        bmi .return
        lda numPlayers
        cmp #$1
        beq .skipTwoPlayer
        lda $a4
        cmp #$0
        bne lbl_98ae
        inc $a4
        lda $b7
        sta $a5
        jsr getNextTetrimino
        sta $a6
        jmp .return
lbl_98ae
        lda $a5
        cmp $b7
        bne .return
        lda $a4
        cmp #$1c
        bne .return
.skipTwoPlayer
        lda #$0
        sta $a4
        sta fallTimer
        sta pieceY
        lda #PLAY_STATE_TETRIMINO_ACTIVE
        sta playState
        lda #$5
        sta pieceX
        ldx nextTetrimino
        lda spawnOrientations,x
        sta pieceOrientation
        jsr updateTetriminoStats
        lda numPlayers
        cmp #$1
        beq lbl_98e1
        lda $a6
        sta nextTetrimino
        jmp .resetAutoRepeatY
lbl_98e1
        jsr getNextTetrimino
        sta nextTetrimino
.resetAutoRepeatY
        lda #$0
        sta autoRepeatY
.return
        rts
;--------------------
getNextTetrimino subroutine
        lda gameMode
        cmp #GAME_MODE_DEMO
        bne .notInDemoMode
        ldx demoIndex
        inc demoIndex
        lda demoPieceSpawns,x
        lsr
        lsr
        lsr
        lsr
        and #$7
        tax
        lda spawnTable,x
        rts
.notInDemoMode
        jsr generateRandomTetrimino
        rts
;--------------------
generateRandomTetrimino subroutine
        inc spawnCount
        lda randomNumberHighByte
        clc
        adc spawnCount
        and #$7
        cmp #$7
        beq .rerollRandomNumber
        tax
        lda spawnTable,x
        cmp nextSpawnId
        bne .keepSpawnId
.rerollRandomNumber
        ldx #randomNumberHighByte
        ldy #$2
        jsr generateRandomNumber
        lda randomNumberHighByte
        and #$7
        clc
        adc nextSpawnId
.subtract7
        cmp #$7
        bcc .smallerThan7
        sec
        sbc #$7
        jmp .subtract7
.smallerThan7
        tax
        lda spawnTable,x
.keepSpawnId
        sta nextSpawnId
        rts
;--------------------
tetriminoTypes
        dc.b $00, $00, $00, $00    ; T
        dc.b $01, $01, $01, $01    ; J
        dc.b $02, $02              ; Z
        dc.b $03                   ; O
        dc.b $04, $04              ; S
        dc.b $05, $05, $05, $05    ; L
        dc.b $06, $06              ; I
spawnTable
        dc.b $02    ; Td
        dc.b $07    ; Jd
        dc.b $08    ; Zh
        dc.b $0a    ; O
        dc.b $0b    ; Sh
        dc.b $0e    ; Ld
        dc.b $12    ; Ih
        dc.b $02    ; Td
spawnOrientations
        dc.b $02, $02, $02, $02    ; Td
        dc.b $07, $07, $07, $07    ; Jd
        dc.b $08, $08              ; Zh
        dc.b $0a                   ; O
        dc.b $0b, $0b              ; Sh
        dc.b $0e, $0e, $0e, $0e    ; Ld
        dc.b $12, $12              ; Ih
;--------------------
        ; Updates the Tetrimino stats based on the orientation ID in register A.
updateTetriminoStats subroutine
        tax
        lda tetriminoTypes,x
        asl
        tax
        lda tetriminoStatLowByte,x
        clc
        adc #$1
        sta $a8
        and #$f
        cmp #$a
        bmi lbl_9996
        lda $a8
        clc
        adc #$6
        sta $a8
        cmp #$a0
        bcc lbl_9996
        clc
        adc #$60
        sta $a8
        lda tetriminoStatHighByte,x
        clc
        adc #$1
        sta tetriminoStatHighByte,x
lbl_9996
        lda $a8
        sta tetriminoStatLowByte,x
        lda $a3
        ora #$40
        sta $a3
        rts
;--------------------
lockTetrimino subroutine
        jsr isPositionValid
        beq lbl_99b8
        lda #GAME_OVER_CURTAIN_SOUND
        sta noiseSoundEffect
        lda #PLAY_STATE_GAME_OVER_CURTAIN
        sta playState
        lda #$f0
        sta curtainRow
        jsr resetAudio
        rts
lbl_99b8
        lda vramRow
        cmp #$20
        bmi lbl_9a10
        lda pieceY
        asl
        sta $a8
        asl
        asl
        clc
        adc $a8
        adc pieceX
        sta $a8
        lda pieceOrientation
        asl
        asl
        sta lineIndex
        asl
        clc
        adc lineIndex
        tax
        ldy #$0
        lda #$4
        sta loopIndex
lbl_99dd        
        lda orientationTable,x
        asl
        sta $ab
        asl
        asl
        clc
        adc $ab
        clc
        adc $a8
        sta $ad
        inx
        lda orientationTable,x
        sta $ac
        inx
        lda orientationTable,x
        clc
        adc $ad
        tay
        lda $ac
        sta ($b8),y
        inx
        dec loopIndex
        bne lbl_99dd
        lda #$0
        sta completedLineIndex
        jsr updatePlayfield
        jsr updateMusicSpeed
        inc playState
lbl_9a10
        rts
;--------------------
updateGameOverCurtain subroutine
        lda curtainRow
        cmp #20
        beq .endGame
        lda frameCounterLowByte
        and #$3
        bne lbl_9a46
        ldx curtainRow
        bmi lbl_9a3e
        lda playfieldAddresses,x
        tay
        lda #$0
        sta loopIndex
        lda #$13
        sta pieceOrientation
lbl_9a2d
        lda #$4f
        sta ($b8),y
        iny
        inc loopIndex
        lda loopIndex
        cmp #$a
        bne lbl_9a2d
        lda curtainRow
        sta vramRow
lbl_9a3e
        inc curtainRow
        lda curtainRow
        cmp #$14
        bne lbl_9a46
lbl_9a46
        rts
.endGame
        lda numPlayers
        cmp #$2
        beq .advancePlayState
        lda scoreMirror+2	; Score >= 30000?
        cmp #$3
        bcc .noEnding
        lda #$80
        jsr initialLegalScreenWait
        jsr showEndingAnimation
        jmp .advancePlayState
.noEnding
        lda buttonStateMirror
        cmp #JOYPAD_START
        bne lbl_9a6a
.advancePlayState
        lda #$0
        sta playState            ; PLAY_STATE_UNASSIGN_ORIENTATION_ID
        sta buttonStateMirror
lbl_9a6a
        rts
;--------------------
checkCompletedRows subroutine
        lda vramRow
        cmp #$20
        bpl lbl_9a74
        jmp lbl_9b02
lbl_9a74
        lda pieceY
        sec
        sbc #$2
        bpl lbl_9a7d
        lda #$0
lbl_9a7d
        clc
        adc completedLineIndex
        sta lineIndex
        asl
        sta $a8
        asl
        asl
        clc
        adc $a8
        sta $a8
        tay
        ldx #$a
lbl_9a8f
        lda ($b8),y
        cmp #$ef
        beq lbl_9acc
        iny
        dex
        bne lbl_9a8f
        lda #LINE_COMPLETED_SOUND
        sta waveSoundEffect
        inc completedLines
        ldx completedLineIndex
        lda lineIndex
        sta completedRowIndices,x
        ldy $a8
        dey
lbl_9aa9        
        lda ($b8),y
        ldx #$a
        stx $b8
        sta ($b8),y
        lda #$0
        sta $b8
        dey
        cpy #$ff
        bne lbl_9aa9
        lda #$ef
        ldy #$0
lbl_9abe        
        sta ($b8),y
        iny
        cpy #$a
        bne lbl_9abe
        lda #$13
        sta pieceOrientation
        jmp lbl_9ad2
lbl_9acc
        ldx completedLineIndex
        lda #$0
        sta completedRowIndices,x
lbl_9ad2
        inc completedLineIndex
        lda completedLineIndex
        cmp #$4
        bmi lbl_9b02
        ldy completedLines
        lda garbageLines,y
        clc
        adc totalGarbage
        sta totalGarbage
        lda #$0
        sta vramRow
        sta clearColumnIndex
        lda completedLines
        cmp #$4
        bne lbl_9af5
        lda #TETRIS_ACHIEVED_SOUND
        sta waveSoundEffect
lbl_9af5
        inc playState
        lda completedLines
        bne lbl_9b02
        inc playState
        lda #LOCK_TETRIMINO_SOUND
        sta waveSoundEffect
lbl_9b02
        rts
;--------------------
unused2PlayerLogic subroutine
        lda numPlayers
        cmp #$1
        beq lbl_9b50
        ldy $bb
        beq lbl_9b50
        lda vramRow
        cmp #$20
        bmi lbl_9b52
        lda playfieldAddresses,y
        sta lineIndex
        lda #$0
        sta $a8
lbl_9b1c
        ldy lineIndex
        lda ($b8),y
        ldy $a8
        sta ($b8),y
        inc $a8
        inc lineIndex
        lda lineIndex
        cmp #$c8
        bne lbl_9b1c
        iny
        ldx #$0
lbl_9b31
        cpx $5a
        beq lbl_9b3a
        lda #$78
        jmp lbl_9b3c
lbl_9b3a
        lda #$ff
lbl_9b3c
        sta ($b8),y
        inx
        cpx #$a
        bne lbl_9b45
        ldx #$0
lbl_9b45
        iny
        cpy #$c8
        bne lbl_9b31
        lda #$0
        sta $bb
        sta vramRow
lbl_9b50
        inc playState
lbl_9b52
        rts
;--------------------
garbageLines
        dc.b $00, $00, $01, $02, $04
;--------------------
updateLinesStats subroutine
        jsr updateMusicSpeed
        lda completedLines
        bne lbl_9b62
        jmp lbl_9bfe
lbl_9b62
        tax
        dex
        lda $d8,x
        clc
        adc #$1
        sta $d8,x
        and #$f
        cmp #$a
        bmi lbl_9b78
        lda $d8,x
        clc
        adc #$6
        sta $d8,x
lbl_9b78
        lda $a3
        ora #$1
        sta $a3
        lda aType
        beq lbl_9ba6
        lda completedLines
        sta $a8
        lda linesLowByte
        sec
        sbc $a8
        sta linesLowByte
        bpl lbl_9b96
        lda #$0
        sta linesLowByte
        jmp lbl_9bfe
lbl_9b96
        and #$f
        cmp #$a
        bmi lbl_9bfe
        lda linesLowByte
        sec
        sbc #$6
        sta linesLowByte
        jmp lbl_9bfe
lbl_9ba6
        ldx completedLines
lbl_9ba8
        inc linesLowByte
        lda linesLowByte
        and #$f
        cmp #$a
        bmi lbl_9bc7
        lda linesLowByte
        clc
        adc #$6
        sta linesLowByte
        and #$f0
        cmp #$a0
        bcc lbl_9bc7
        lda linesLowByte
        and #$f
        sta linesLowByte
        inc linesHighByte
lbl_9bc7
        lda linesLowByte
        and #$f
        bne lbl_9bfb
        jmp lbl_9bd0
lbl_9bd0
        lda linesHighByte
        sta lineIndex
        lda linesLowByte
        sta $a8
        lsr lineIndex
        ror $a8
        lsr lineIndex
        ror $a8
        lsr lineIndex
        ror $a8
        lsr lineIndex
        ror $a8
        lda level
        cmp $a8
        bpl lbl_9bfb
        inc level
        lda #LEVEL_UP_SOUND
        sta waveSoundEffect
        lda $a3
        ora #$2
        sta $a3
lbl_9bfb
        dex
        bne lbl_9ba8
lbl_9bfe
        lda holdDownPoints
        cmp #$2
        bmi lbl_9c2d
        clc
        dec score
        adc score
        sta score
        and #$f
        cmp #$a
        bcc lbl_9c18
        lda score
        clc
        adc #$6
        sta score
lbl_9c18
        lda score
        and #$f0
        cmp #$a0
        bcc lbl_9c27
        clc
        adc #$60
        sta score
        inc score+1
lbl_9c27
        lda $a3
        ora #$4
        sta $a3
lbl_9c2d
        lda #$0
        sta holdDownPoints
        lda level
        sta $a8
        inc $a8
lbl_9c37        
        lda completedLines
        asl
        tax
        lda scoreTable,x
        clc
        adc score
        sta score
        cmp #$a0
        bcc lbl_9c4e
        clc
        adc #$60
        sta score
        inc score+1
lbl_9c4e
        inx
        lda scoreTable,x
        clc
        adc score+1
        sta score+1
        and #$f
        cmp #$a
        bcc lbl_9c64
        lda score+1
        clc
        adc #$6
        sta score+1
lbl_9c64
        lda score+1
        and #$f0
        cmp #$a0
        bcc lbl_9c75
        lda score+1
        clc
        adc #$60
        sta score+1
        inc score+2
lbl_9c75
        lda score+2
        and #$f
        cmp #$a
        bcc lbl_9c84
        lda score+2
        clc
        adc #$6
        sta score+2
lbl_9c84
        lda score+2
        and #$f0
        cmp #$a0
        bcc lbl_9c94
        lda #$99
        sta score
        sta score+1
        sta score+2
lbl_9c94
        dec $a8
        bne lbl_9c37
        lda $a3
        ora #$4
        sta $a3
        lda #$0
        sta completedLines
        inc playState
        rts
;--------------------
scoreTable
        dc.b $00, $00 ; 0 lines
        dc.b $40, $00 ; 1 line
        dc.b $00, $01 ; 2 lines
        dc.b $00, $03 ; 3 lines
        dc.b $00, $12 ; 4 lines
;--------------------
updatePlayfield subroutine
        ldx pieceY
        dex
        dex
        txa
        bpl lbl_9cb8
        lda #$0
lbl_9cb8
        cmp vramRow
        bpl lbl_9cbe
        sta vramRow
lbl_9cbe
        rts
;--------------------
showHighScore
        lda #$5
        sta lineIndex
        lda playStateMirror
        cmp #$0
        beq lbl_9cd9
        lda numPlayers
        cmp #$1
        beq .increasePlayMode
        lda #$4
        sta lineIndex
        lda $88
        cmp #$0
        bne .increasePlayMode
lbl_9cd9
        lda numPlayers
        cmp #$1
        beq lbl_9ce4
        lda #$9
        sta playMode
        rts
lbl_9ce4
        lda #RENDER_MODE_PLAY_AND_DEMO_SCREENS
        sta renderMode
        lda numPlayers
        cmp #$1
        bne lbl_9cf1
        jsr checkHighScore
lbl_9cf1
        lda #$1
        sta playStateMirror
        sta $88
        lda #$ef
        ldx #$4
        ldy #$5
        jsr fillMemPage
        lda #$0
        sta vramRowMirror
        sta $89
        lda #$1
        sta playStateMirror
        sta $88
        jsr waitForVerticalBlankAndClearOAM
        lda #GAME_MODE_LEVEL_AND_HEIGHT_MENU
        sta gameMode
        rts
.increasePlayMode
        inc playMode
        rts
;--------------------
updateMusicSpeed subroutine
        ldx #$5
        lda playfieldAddresses,x
        tay
        ldx #$a
.nextColumn
        lda ($b8),y
        cmp #$ef
        bne .speedUp
        iny
        dex
        bne .nextColumn
        lda musicSpeed
        beq .return
        lda #MUSIC_SPEED_MODERATO
        sta musicSpeed
        ldx activeMusic
        lda inGameMusics,x
        jsr startMusic
        jmp .return
.speedUp
        lda musicSpeed
        bne .return
        lda #MUSIC_SPEED_ALLEGRO
        sta musicSpeed
        lda activeMusic
        clc
        adc #$4
        tax
        lda inGameMusics,x
        jsr startMusic
.return
        rts
;--------------------
updateControllerVariables subroutine
        lda gameMode
        cmp #GAME_MODE_DEMO
        beq .inDemoMode
        jsr pollController
        rts
.inDemoMode
        lda recordingMode
        cmp #$ff
        beq lbl_9db0
        jsr pollController
        lda buttonStateMirror
        cmp #JOYPAD_START
        beq .exitDemo
        lda repeats
        beq lbl_9d73
        dec repeats
        jmp lbl_9d9a
lbl_9d73
        ldx #$0
        lda (demoButtonsLowByte,x)
        sta $a8
        jsr advanceDemoButtons
        lda heldButtons
        eor $a8
        and $a8
        sta buttonStateMirror
        lda $a8
        sta heldButtons
        ldx #$0
        lda (demoButtonsLowByte,x)
        sta repeats
        jsr advanceDemoButtons
        lda demoButtonsHighByte
        cmp #$df
        beq lbl_9da2
        jmp lbl_9d9e
lbl_9d9a
        lda #$0
        sta buttonStateMirror
lbl_9d9e
        lda heldButtons
        sta heldButtonsMirror
lbl_9da2
        rts
.exitDemo
        lda #>demoButtons
        sta demoButtonsHighByte
        lda #<demoButtons
        sta frameCounterHighByte
        lda #GAME_MODE_TITLE_SCREEN
        sta gameMode
        rts
lbl_9db0
        jsr pollController
        lda gameMode
        cmp #GAME_MODE_DEMO
        bne lbl_9de7
        lda recordingMode
        cmp #$ff
        bne lbl_9de7
        lda heldButtonsMirror
        cmp heldButtons
        beq lbl_9de4
        ldx #$0
        lda heldButtons
        sta (demoButtonsLowByte,x)
        jsr advanceDemoButtons
        lda repeats
        sta (demoButtonsLowByte,x)
        jsr advanceDemoButtons
        lda demoButtonsHighByte
        cmp #$df
        beq lbl_9de7
        lda heldButtonsMirror
        sta heldButtons
        lda #$0
        sta repeats
        rts
lbl_9de4
        inc repeats
        rts
lbl_9de7
        rts
;--------------------
advanceDemoButtons subroutine
        lda demoButtonsLowByte
        clc
        adc #$1
        sta demoButtonsLowByte
        lda #$0
        adc demoButtonsHighByte
        sta demoButtonsHighByte
        rts
;--------------------
gameModeInitDemo subroutine
        lda #$0
        sta aType
        sta levelSelectedMirror
        sta playMode
        sta playStateMirror
        lda #GAME_MODE_DEMO
        sta gameMode
        jmp gameModePlay
;--------------------
startMusic subroutine
        sta backgroundMusic
        lda gameMode
        cmp #GAME_MODE_DEMO
        bne .dontMute
        lda #NO_MUSIC
        sta backgroundMusic
.dontMute
        rts
;--------------------
checkSoftReset subroutine
        lda heldButtonsMirror
        cmp #(JOYPAD_START+JOYPAD_SELECT+JOYPAD_B+JOYPAD_A)
        beq .softReset
        inc playMode
        rts
.softReset
        jsr resetAudio
        lda #GAME_MODE_LEGAL_SCREEN
        sta gameMode
        rts
;--------------------
resetPlayMode subroutine
        lda #$2
        sta playMode
        jsr doNothing
        rts
;--------------------
unassignOrientationId subroutine
        lda #$13
        sta pieceOrientation
        rts
;--------------------
        inc playMode
        rts
;--------------------
incrementPlayState
        inc playState
returnPlayState
        rts
;--------------------
showEndingAnimation subroutine
        lda #$2
        sta $a2
        lda #RENDER_MODE_ENDING_ANIMATION
        sta renderMode
        lda aType
        bne .showBTypeEnding
        jmp showATypeEnding
.showBTypeEnding
        ldx levelMirror
        lda levelToBinaryCodedDecimal,x
        and #$f
        sta level
        lda #$0
        sta totalScore+2
        sta totalScore+1
        sta totalScore
        lda level
        asl
        asl
        asl
        asl
        sta bTypeLevelBonus
        lda bTypeHeightMirror
        asl
        asl
        asl
        asl
        sta bTypeHeightBonus
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda level
        cmp #$9
        bne lbl_9e88
        lda #$1
        jsr switchCharBank0
        lda #$1
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <b_type_ending_lvl9_screen_background, >b_type_ending_lvl9_screen_background
        jmp lbl_9ea4
lbl_9e88
        ldx #$3
        lda level
        cmp #$2
        beq lbl_9e96
        cmp #$6
        beq lbl_9e96
        ldx #$2
lbl_9e96
        txa
        jsr switchCharBank0
        lda #$2
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <b_type_ending_screen_background, >b_type_ending_screen_background
lbl_9ea4        
        jsr copyToVRAM
        dc.b <ending_screen_color_palette, >ending_screen_color_palette
        jsr chooseEndingByLevelAndHeight
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #RENDER_MODE_ENDING_ANIMATION
        sta renderMode
        lda #ENDINGS_MUSIC
        jsr startMusic
        lda #$80
        jsr advanceAnimationMultipleFrames
        lda scoreMirror
        sta totalScore
        lda scoreMirror+1
        sta totalScore+1
        lda scoreMirror+2
        sta totalScore+2
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        lda #$0
        sta scoreMirror
        sta scoreMirror+1
        sta scoreMirror+2
        lda #$40
        jsr advanceAnimationMultipleFrames
        lda bTypeLevelBonus
        beq lbl_9f12
lbl_9ee8
        dec bTypeLevelBonus
        lda bTypeLevelBonus
        and #$f
        cmp #$f
        bne lbl_9efa
        lda bTypeLevelBonus
        and #$f0
        ora #$9
        sta bTypeLevelBonus
lbl_9efa
        lda bTypeLevelBonus
        jsr addBonusPoint
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda #$2
        jsr advanceAnimationMultipleFrames
        lda bTypeLevelBonus
        bne lbl_9ee8
        lda #$40
        jsr advanceAnimationMultipleFrames
lbl_9f12
        lda bTypeHeightBonus
        beq .waitForStartPressed
lbl_9f16
        dec bTypeHeightBonus
        lda bTypeHeightBonus
        and #$f
        cmp #$f
        bne lbl_9f28
        lda bTypeHeightBonus
        and #$f0
        ora #$9
        sta bTypeHeightBonus
lbl_9f28
        lda bTypeHeightBonus
        jsr addBonusPoint
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda #$2
        jsr advanceAnimationMultipleFrames
        lda bTypeHeightBonus
        bne lbl_9f16
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        lda #$40
        jsr advanceAnimationMultipleFrames
.waitForStartPressed
        jsr advanceAnimationSingleFrame
        jsr waitForVerticalBlankAndClearOAM
        lda buttonStateMirror
        cmp #JOYPAD_START
        bne .waitForStartPressed
        lda levelMirror
        sta level
        lda totalScore
        sta score
        lda totalScore+1
        sta score+1
        lda totalScore+2
        sta score+2
        rts
;--------------------
addBonusPoint subroutine
        lda #$1
        clc
        adc totalScore+1
        sta totalScore+1
        and #$f
        cmp #$a
        bcc lbl_9f76
        lda totalScore+1
        clc
        adc #$6
        sta totalScore+1
lbl_9f76
        and #$f0
        cmp #$a0
        bcc lbl_9f85
        lda totalScore+1
        clc
        adc #$60
        sta totalScore+1
        inc totalScore+2
lbl_9f85
        lda totalScore+2
        and #$f
        cmp #$a
        bcc lbl_9f94
        lda totalScore+2
        clc
        adc #$6
        sta totalScore+2
lbl_9f94
        rts
;--------------------
renderEndingAnimation subroutine
        lda #$20
        sta PPUADDR
        lda #$8e
        sta PPUADDR
        lda scoreMirror+2
        jsr printTwoDigitNumber
        lda scoreMirror+1
        jsr printTwoDigitNumber
        lda scoreMirror
        jsr printTwoDigitNumber
        lda aType
        beq lbl_9fe9
        lda #$20
        sta PPUADDR
        lda #$b0
        sta PPUADDR
        lda bTypeLevelBonus
        jsr printTwoDigitNumber
        lda #$20
        sta PPUADDR
        lda #$d0
        sta PPUADDR
        lda bTypeHeightBonus
        jsr printTwoDigitNumber
        lda #$21
        sta PPUADDR
        lda #$2e
        sta PPUADDR
        lda totalScore+2
        jsr printTwoDigitNumber
        lda totalScore+1
        jsr printTwoDigitNumber
        lda totalScore
        jsr printTwoDigitNumber
lbl_9fe9
        ldy #$0
        sty PPUSCROLL
        sty PPUSCROLL
        rts
;--------------------
copyHighScoreTableToVRAM subroutine
        lda numPlayers
        cmp #$1
        beq .onePlayerMode
        jmp .return
.onePlayerMode
        jsr copyToVRAM
        dc.b <highscore_table_background, >highscore_table_background
        lda #$0
        sta lineIndex
        lda aType
        beq .nextEntry
        lda #$4
        sta lineIndex
.nextEntry
        lda lineIndex
        and #$3
        asl
        tax
        lda highScoreVramAddresses,x
        sta PPUADDR
        lda lineIndex
        and #$3
        asl
        tax
        inx
        lda highScoreVramAddresses,x
        sta PPUADDR
        lda lineIndex
        asl
        sta $a8
        asl
        clc
        adc $a8
        tay
        ldx #$6
.nextCharacter
        lda highScoreTable,y
        sty $a8
        tay
        lda highScoreEntryCharacters,y
        ldy $a8
        sta PPUDATA
        iny
        dex
        bne .nextCharacter
        lda #$ff
        sta PPUDATA
        lda lineIndex
        sta $a8
        asl
        clc
        adc $a8
        tay
        lda highScoresAType,y
        jsr printTwoDigitNumber
        iny
        lda highScoresAType,y
        jsr printTwoDigitNumber
        iny
        lda highScoresAType,y
        jsr printTwoDigitNumber
        lda #$ff
        sta PPUDATA
        ldy lineIndex
		lda highScoreLevelsAType,y
        tax
        lda binaryToBinaryCodedDecimal,x
        jsr printTwoDigitNumber
        inc lineIndex
        lda lineIndex
        cmp #$3
        beq .return
        cmp #$7
        beq .return
        jmp .nextEntry
.return
        rts
;--------------------
highScoreVramAddresses
        dc.b $22, $89, $22, $c9, $23, $09
highScoreEntryCharacters
        dc.b $24, $0a, $0b, $0c, $0d, $0e, $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18
        dc.b $19, $1a, $1b, $1c, $1d, $1e, $1f, $20, $21, $22, $23, $00, $01, $02, $03, $04
        dc.b $05, $06, $07, $08, $09, $25, $4f, $5e, $5f, $6e, $6f, $ff, $00, $00, $00, $00
binaryToBinaryCodedDecimal
        dc.b $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $10, $11, $12, $13, $14, $15
        dc.b $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31
        dc.b $32, $33, $34, $35, $36, $37, $38, $39, $40, $41, $42, $43, $44, $45, $46, $47
        dc.b $48, $49
;--------------------
checkHighScore subroutine
        lda #$00
        sta $d5
        lda aType
        beq lbl_a0fa
        lda #$4
        sta highScoreTableIndex
lbl_a0fa
        lda highScoreTableIndex
        sta lineIndex
        asl
        clc
        adc lineIndex
        tay
        lda highScoresAType,y
        cmp scoreMirror+2
        beq lbl_a10e
        bcs lbl_a124
        bcc lbl_a134
lbl_a10e
        iny
        lda highScoresAType,y
        cmp scoreMirror+1
        beq lbl_a11a
        bcs lbl_a124
        bcc lbl_a134
lbl_a11a
        iny
        lda highScoresAType,y
        cmp scoreMirror
        beq lbl_a134
        bcc lbl_a134
lbl_a124
        inc highScoreTableIndex
        lda highScoreTableIndex
        cmp #$3
        beq lbl_a133
        cmp #$7
        beq lbl_a133
        jmp lbl_a0fa
lbl_a133
        rts
lbl_a134
        lda highScoreTableIndex
        and #$3
        cmp #$2
        bpl .stopShiftingDown
        lda #$6
        jsr shiftHighScoreNameDown
        lda #$3
        jsr shiftHighScoreDown
        lda #$1
        jsr shiftHighScoreLevelDown
        lda highScoreTableIndex
        and #$3
        bne .stopShiftingDown
        lda #$0
        jsr shiftHighScoreNameDown
        lda #$0
        jsr shiftHighScoreDown
        lda #$0
        jsr shiftHighScoreLevelDown
.stopShiftingDown
        ldx highScoreTableIndex
        lda highScoreTableNameOffsets,x
        tax
        ldy #$6
        lda #$0
lbl_a16a
        sta highScoreTable,x
        inx
        dey
        bne lbl_a16a
        ldx highScoreTableIndex
        lda highScoreTableScoreOffsets,x
        tax
        lda scoreMirror+2
        sta highScoresAType,x
        inx
        lda scoreMirror+1
        sta highScoresAType,x
        inx
        lda scoreMirror
        sta highScoresAType,x
        ldx highScoreTableIndex
        lda levelMirror
        sta highScoreLevelsAType,x
        jmp enterHighScoreName
;--------------------
shiftHighScoreNameDown subroutine
        sta $a8
        lda aType
        beq .aType
        lda #$18
        clc
        adc $a8
        sta $a8
.aType
        lda #$5
        sta lineIndex
lbl_a1a3
        lda $a8
        clc
        adc lineIndex
        tax
        lda highScoreTable,x
        sta loopIndex
        txa
        clc
        adc #$6
        tax
        lda loopIndex
        sta highScoreTable,x
        dec lineIndex
        lda lineIndex
        cmp #$ff
        bne lbl_a1a3
        rts
;--------------------
shiftHighScoreDown subroutine
        tax
        lda aType
        beq lbl_a1cb
        txa
        clc
        adc #$c
        tax
lbl_a1cb
        lda highScoresAType,x
        sta highScoresAType+3,x
        inx
        lda highScoresAType,x
        sta highScoresAType+3,x
        inx
        lda highScoresAType,x
        sta highScoresAType+3,x
        rts
;--------------------
shiftHighScoreLevelDown subroutine
        tax
        lda aType
        beq lbl_a1ea
        txa
        clc
        adc #$4
        tax
lbl_a1ea
        lda highScoreLevelsAType,x
        sta highScoreLevelsAType+1,x
        rts
;--------------------
highScoreTableNameOffsets
        dc.b $00, $06, $0c, $12, $18, $1e, $24, $2a
highScoreTableScoreOffsets
        dc.b $00, $03, $06, $09, $0c, $0f, $12, $15
;--------------------
enterHighScoreName
        inc MMC1_LOAD       ; Clear MMC1 shift register
        lda #$10
        jsr setMmc1Control
        lda #CONGRATULATIONS_SCREEN_MUSIC
        jsr startMusic
        lda #RENDER_MODE_CONGRATULATIONS_SCREENS
        sta renderMode
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda #$0
        jsr switchCharBank0
        lda #$0
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <menu_screen_color_palette, >menu_screen_color_palette
        jsr copyToVRAM
        dc.b <highscore_screen_background, >highscore_screen_background
        lda #$20
        sta PPUADDR
        lda #$6d
        sta PPUADDR
        lda #$a
        clc
        adc aType
        sta PPUDATA
        jsr copyHighScoreTableToVRAM
        lda #RENDER_MODE_CONGRATULATIONS_SCREENS
        sta renderMode
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda highScoreTableIndex
        asl
        sta $a8
        asl
        clc
        adc $a8
        sta highScoreNameStartOffset
        lda #$0
        sta highScoreNameCharacterIndex
        sta objectAttributeMemory
        lda highScoreTableIndex
        and #$3
        tax
        lda highScoreNameSpriteY,x
        sta spriteY
lbl_a26d
        lda #$0
        sta objectAttributeMemory
        ldx highScoreNameCharacterIndex
        lda highScoreNameSpriteX,x
        sta spriteX
        lda #$e
        sta objectAttributeEntryIndex
        lda frameCounterLowByte
        and #$3
        bne lbl_a287
        lda #$2
        sta objectAttributeEntryIndex
lbl_a287
        jsr copyObjectAttributeData
        lda buttonStateMirror
        and #JOYPAD_START
        beq lbl_a298
        lda #MENU_SCREEN_SELECT_SOUND
        sta waveSoundEffect
        jmp lbl_a337
lbl_a298
        lda buttonStateMirror
        and #(JOYPAD_RIGHT+JOYPAD_A)
        beq lbl_a2af
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        inc highScoreNameCharacterIndex
        lda highScoreNameCharacterIndex
        cmp #$6
        bmi lbl_a2af
        lda #$0
        sta highScoreNameCharacterIndex
lbl_a2af
        lda buttonStateMirror
        and #(JOYPAD_LEFT+JOYPAD_B)
        beq lbl_a2c4
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        dec highScoreNameCharacterIndex
        lda highScoreNameCharacterIndex
        bpl lbl_a2c4
        lda #$5
        sta highScoreNameCharacterIndex
lbl_a2c4
        lda heldButtonsMirror
        and #JOYPAD_DOWN
        beq lbl_a2f2
        lda frameCounterLowByte
        and #$7
        bne lbl_a2f2
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda highScoreNameStartOffset
        sta $a8
        clc
        adc highScoreNameCharacterIndex
        tax
        lda highScoreTable,x
        sta $a8
        dec $a8
        lda $a8
        bpl lbl_a2ed
        clc
        adc #$2c
        sta $a8
lbl_a2ed
        lda $a8
        sta highScoreTable,x
lbl_a2f2
        lda heldButtonsMirror
        and #JOYPAD_UP
        beq lbl_a322
        lda frameCounterLowByte
        and #$7
        bne lbl_a322
        lda #MENU_OPTION_SELECT_SOUND
        sta waveSoundEffect
        lda highScoreNameStartOffset
        sta $a8
        clc
        adc highScoreNameCharacterIndex
        tax
        lda highScoreTable,x
        sta $a8
        inc $a8
        lda $a8
        cmp #$2c
        bmi lbl_a31d
        sec
        sbc #$2c
        sta $a8
lbl_a31d
        lda $a8
        sta highScoreTable,x
lbl_a322
        lda highScoreNameStartOffset
        clc
        adc highScoreNameCharacterIndex
        tax
        lda highScoreTable,x
        sta $d7
        lda #$80
        sta $a3
        jsr waitForVerticalBlankAndClearOAM
        jmp lbl_a26d
lbl_a337
        jsr waitForVerticalBlankAndClearOAM
        rts
;--------------------
highScoreNameSpriteY
        dc.b $9f, $af, $bf
highScoreNameSpriteX
        dc.b $48, $50, $58, $60, $68, $70
;--------------------
renderCongratulationsScreens subroutine
        lda $a3
        and #$80
        beq .return
        lda highScoreTableIndex
        and #$3
        asl
        tax
        lda highScoreVramAddresses,x
        sta PPUADDR
        lda highScoreTableIndex
        and #$3
        asl
        tax
        inx
        lda highScoreVramAddresses,x
        sta $a8
        clc
        adc highScoreNameCharacterIndex
        sta PPUADDR
        ldx $d7
        lda highScoreEntryCharacters,x
        sta PPUDATA
        lda #$0
        sta scrollX
        sta PPUSCROLL
        sta scrollY
        sta PPUSCROLL
        sta $a3
.return
        rts
;--------------------
checkStartPressed subroutine
        lda gameMode
        cmp #GAME_MODE_DEMO
        bne .demoNotExited
        lda buttonStateMirror
        cmp #JOYPAD_START
        bne .demoNotExited
        lda #GAME_MODE_TITLE_SCREEN
        sta gameMode
        jmp .nextPlayMode
.demoNotExited
        lda renderMode
        cmp #RENDER_MODE_PLAY_AND_DEMO_SCREENS
        bne .nextPlayMode
        lda buttonStateMirror
        and #JOYPAD_START
        bne lbl_a3a1
        jmp .nextPlayMode
lbl_a3a1
        lda playStateMirror
        cmp #$a
        bne lbl_a3aa
        jmp .nextPlayMode
lbl_a3aa
        lda #$5
        sta $68d
        lda #RENDER_MODE_LEGAL_TITLE_SCREENS
        sta renderMode
        jsr waitForVerticalBlankingInterval
        lda #$16
        sta PPUMASK
        lda #$ff
        ldx #$2
        ldy #$2
        jsr fillMemPage
lbl_a3c4
        lda #linesLowByteMirror
        sta spriteX
        lda #$77
        sta spriteY
        lda #$5
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
        lda buttonStateMirror
        cmp #JOYPAD_START
        beq lbl_a3df
        jsr waitForVerticalBlankAndClearOAM
        jmp lbl_a3c4
lbl_a3df
        lda #$1e
        sta PPUMASK
        lda #$0
        sta $68d
        sta vramRowMirror
        lda #RENDER_MODE_PLAY_AND_DEMO_SCREENS
        sta renderMode
.nextPlayMode
        inc playMode
        rts
;--------------------
checkBTypeGoal subroutine
        lda aType
        beq .goalNotAchieved
        lda linesLowByte
        bne .goalNotAchieved
        lda #B_TYPE_GOAL_ACHIEVED_MUSIC
        jsr startMusic
        ldy #$46
        ldx #$0
.nextCharacter
        lda successMessageGraphics,x
        cmp #$80
        beq .endMessage
        sta ($b8),y
        inx
        iny
        jmp .nextCharacter
.endMessage
        lda #$0
        sta vramRowMirror
        jsr shortSleep
        lda #RENDER_MODE_LEGAL_TITLE_SCREENS
        sta renderMode
        lda #$80
        jsr initialLegalScreenWait
        jsr showEndingAnimation
        lda #PLAY_STATE_UNASSIGN_ORIENTATION_ID
        sta playState
        inc playMode
        rts
.goalNotAchieved
        inc playState
        rts
;--------------------
successMessageGraphics
        dc.b $38, $39, $39, $39, $39, $39, $39, $39, $39, $3a, $3b, $1c, $1e, $0c, $0c, $0e
        dc.b $1c, $1c, $28, $3c, $3d, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3f, $80
;--------------------
shortSleep subroutine
        lda #20
        sta legalScreenCounter1
.nextFrame
        jsr waitForVerticalBlankAndClearOAM
        lda legalScreenCounter1
        bne .nextFrame
        rts
;--------------------
initialLegalScreenWait
        sta legalScreenCounter1
.waitForTimeOut
        jsr waitForVerticalBlankAndClearOAM
        lda legalScreenCounter1
        bne .waitForTimeOut
        rts
;--------------------
chooseEndingByLevelAndHeight subroutine
        lda #$0
        sta ending
        sta $c5
        sta $cd
        lda #$2
        sta $a2
        lda level
        cmp #$9
        bne .notLevel9
        lda bTypeHeightMirror
        clc
        adc #$1
        sta ending
        jsr chooseEndingByHeight
        lda #$0
        sta ending
        sta $c7
        lda lbl_a73d
        sta $c8
        lda lbl_a73d+1
        sta $c9
        lda lbl_a73d+2
        sta $ca
        lda lbl_a73d+3
        sta $cb
        rts
.notLevel9
        ldx level
        lda lbl_a767,x
        sta $c7
        sta $c8
        sta $c9
        sta $ca
        sta $cb
        ldx level
        lda lbl_a75d,x
        sta $c6
        rts
;--------------------
chooseEndingByHeight subroutine
        lda ending
        jsr switch
        dc.b <lbl_a4c4, >lbl_a4c4
        dc.b <lbl_a4cf, >lbl_a4cf
        dc.b <lbl_a4da, >lbl_a4da
        dc.b <lbl_a4e5, >lbl_a4e5
        dc.b <lbl_a4f0, >lbl_a4f0
        dc.b <lbl_a4fb, >lbl_a4fb
        dc.b <lbl_a506, >lbl_a506
lbl_a4c4
        lda #$a8
        sta $15
        lda #$22
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a4cf
        lda #$a8
        sta $15
        lda #$34
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a4da
        lda #$a8
        sta $15
        lda #$4a
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a4e5
        lda #$a8
        sta $15
        lda #$62
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a4f0
        lda #$a8
        sta $15
        lda #$7a
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a4fb
        lda #$a8
        sta $15
        lda #$96
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a506
        rts
;--------------------
copyEndingGraphicsToVRAM subroutine
        ldy #$0
.nextAddress
        lda ($14),y
        sta PPUADDR
        iny
        lda ($14),y
        sta PPUADDR
        iny
.nextData
        lda ($14),y
        iny
        cmp #$fe
        beq .nextAddress
        cmp #$fd
        beq .return
        sta PPUDATA
        jmp .nextData
.return
        rts
;--------------------
advanceAnimationSingleFrame
        lda aType
        bne .bType
        jmp advanceATypeAnimation
.bType
        lda level
        cmp #$9
        beq .advanceBTypeLevel9Animation
        jmp advanceBTypeLowerLevelAnimation
.advanceBTypeLevel9Animation
        jsr advanceBTypeLevel9Animation
        rts
;--------------------
advanceBTypeLevel9Animation subroutine
        lda bTypeHeightMirror
        jsr switch
        dc.b <advanceBTypeLevel9Height0Animation, >advanceBTypeLevel9Height0Animation
        dc.b <advanceBTypeLevel9Height1Animation, >advanceBTypeLevel9Height1Animation
        dc.b <advanceBTypeLevel9Height2Animation, >advanceBTypeLevel9Height2Animation
        dc.b <advanceBTypeLevel9Height3Animation, >advanceBTypeLevel9Height3Animation
        dc.b <advanceBTypeLevel9Height4Animation, >advanceBTypeLevel9Height4Animation
        dc.b <advanceBTypeLevel9Height5Animation, >advanceBTypeLevel9Height5Animation
;--------------------
advanceBTypeLevel9Height5Animation
        lda #200
        sta spriteX
        lda #$47
        sta spriteY
        lda frameCounterLowByte
        and #$8
        lsr
        lsr
        lsr
        clc
        adc #$21
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
        lda #$a0
        sta spriteX
        lda #$27
        sta objectAttributeEntryIndex
        lda frameCounterLowByte
        and #$18
        lsr
        lsr
        lsr
        tax
        lda lbl_a80a,x
        sta spriteY
        cmp #$97
        beq lbl_a580
        lda #$28
        sta objectAttributeEntryIndex
lbl_a580
        jsr copyObjectAttributeData
lbl_a583
        lda #$c0
        sta spriteX
        lda ending
        lsr
        lsr
        lsr
        cmp #$a
        bne lbl_a599
        lda #$0
        sta ending
        inc $c5
        jmp lbl_a583
lbl_a599
        tax
        lda lbl_a80e,x
        sta spriteY
        lda lbl_a818,x
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
        inc ending
advanceBTypeLevel9Height4Animation
        lda #$30
        sta spriteX
        lda #$a7
        sta spriteY
        lda frameCounterLowByte
        and #$10
        lsr
        lsr
        lsr
        lsr
        clc
        adc #$1f
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
advanceBTypeLevel9Height3Animation
        lda #$40
        sta spriteX
        lda #$77
        sta spriteY
        lda frameCounterLowByte
        and #$10
        lsr
        lsr
        lsr
        lsr
        clc
        adc #$1d
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
advanceBTypeLevel9Height2Animation
        lda #$a8
        sta spriteX
        lda #$d7
        sta spriteY
        lda frameCounterLowByte
        and #$10
        lsr
        lsr
        lsr
        lsr
        clc
        adc #$1a
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
advanceBTypeLevel9Height1Animation
        lda #$c8
        sta spriteX
        lda #$d7
        sta spriteY
        lda frameCounterLowByte
        and #$10
        lsr
        lsr
        lsr
        lsr
        clc
        adc #$18
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
advanceBTypeLevel9Height0Animation
        lda #$28
        sta spriteX
        lda #$77
        sta spriteY
        lda frameCounterLowByte
        and #$10
        lsr
        lsr
        lsr
        lsr
        clc
        adc #$16
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
        jsr lbl_a6bc
        rts
advanceBTypeLowerLevelAnimation
        jsr lbl_a690
        inc $cd
        lda #$0
        sta $cc
lbl_a62e
        ldx level
        lda lbl_a767,x
        sta $a8
        ldx $cc
        lda $c6,x
        cmp $a8
        beq lbl_a675
        sta spriteX
        jsr lbl_a6ae
        lda lbl_a7b7,x
        sta spriteY
        jsr copyObjectAttributeData
        ldx level
        lda lbl_a753,x
        cmp $cd
        bne lbl_a675
        ldx level
        lda lbl_a771,x
        clc
        adc spriteX
        sta spriteX
        ldx $cc
        sta $c6,x
        jsr lbl_a6ae
        lda lbl_a77b,x
        cmp spriteX
        bne lbl_a675
        ldx level
        lda lbl_a75d,x
        ldx $cc
        inx
        sta $c6,x
lbl_a675
        lda $cc
        sta $a8
        cmp bTypeHeight
        beq lbl_a682
        inc $cc
        jmp lbl_a62e
lbl_a682
        ldx level
        lda lbl_a753,x
        cmp $cd
        bne lbl_a68f
        lda #$0
        sta $cd
lbl_a68f
        rts
;--------------------
lbl_a690
        inc ending
        ldx level
        lda lbl_a749,x
        cmp ending
        bne lbl_a6a5
        lda $c5
        eor #$1
        sta $c5
        lda #$0
        sta ending
lbl_a6a5
        lda typeBLowerLevelSpriteIndex,x
        clc
        adc $c5
        sta objectAttributeEntryIndex
        rts
;--------------------
lbl_a6ae
        lda level
        asl
        sta $a8
        asl
        clc
        adc $a8
        clc
        adc $cc
        tax
        rts
;--------------------
lbl_a6bc
        ldx #$0
lbl_a6be
        lda lbl_a735,x
        cmp $c5
        bne lbl_a6d0
        lda $c8,x
        beq lbl_a6d0
        sec
        sbc #$1
        sta $c8,x
        inc $c5
lbl_a6d0
        inx
        cpx #$4
        bne lbl_a6be
        lda #$0
        sta $cc
lbl_a6d9
        ldx $cc
        lda $c8,x
        beq lbl_a72c
        sta $a8
        lda lbl_a73d,x
        cmp $a8
        beq lbl_a6f7
        lda #ENDING_ROCKET_SOUND
        sta noiseSoundEffect
        dec $a8
        lda $a8
        cmp #$a0
        bcs lbl_a6f7
        dec $a8
lbl_a6f7
        lda $a8
        sta $c8,x
        sta spriteY
        lda cathedralDomeSpriteX,x
        sta spriteX
        lda cathedralDomeSpriteIndex,x
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
        ldx $cc
        lda $c8,x
        sta $a8
        lda lbl_a73d,x
        cmp $a8
        beq lbl_a72c
        lda cathedralDomeBurnerSpriteOffsetX,x
        clc
        adc spriteX
        sta spriteX
        lda frameCounterLowByte
        and #$2
        lsr
        clc
        adc #$51
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
lbl_a72c
        inc $cc
        lda $cc
        cmp #$4
        bne lbl_a6d9
        rts
;--------------------
lbl_a735
        dc.b $05, $07, $09, $0b
cathedralDomeSpriteX
        dc.b $60, $90, $70, $7e
lbl_a73d
        dc.b $bc, $b8, $bc, $b3
cathedralDomeSpriteIndex
        dc.b $4d, $50, $4e, $4f
cathedralDomeBurnerSpriteOffsetX
        dc.b $00, $00, $00, $02
lbl_a749
        dc.b $02, $04, $06, $03, $10, $03, $05, $06, $02, $05
lbl_a753
        dc.b $03, $01, $01, $01, $02, $05, $01, $02, $01, $01
lbl_a75d
        dc.b $02, $02, $fe, $fe, $02, $fe, $02, $02, $fe, $02
lbl_a767
        dc.b $00, $00, $00, $02, $f0, $10, $f0, $f0, $20, $f0
lbl_a771
        dc.b $01, $01, $ff, $fc, $01, $ff, $02, $02, $fe, $02
lbl_a77b
        dc.b $3a, $24, $0a, $4a, $3a, $ff, $22, $44, $12, $32, $4a, $ff, $ae, $6e, $8e, $6e
        dc.b $1e, $02, $42, $42, $42, $42, $42, $02, $22, $0a, $1a, $04, $0a, $ff, $ee, $de
        dc.b $fc, $fc, $f6, $02, $80, $80, $80, $80, $80, $ff, $e8, $e8, $e8, $e8, $48, $ff
        dc.b $80, $ae, $9e, $90, $80, $02, $80, $80, $80, $80, $80, $ff
lbl_a7b7
        dc.b $98, $a8, $c0, $a8, $90, $b0, $b0, $b8, $a0, $b8, $a8, $a0, $c8, $c8, $c8, $c8
        dc.b $c8, $c8, $30, $20, $40, $28, $a0, $80, $a8, $88, $68, $a8, $48, $78, $58, $68
        dc.b $18, $48, $78, $38, $c8, $c8, $c8, $c8, $c8, $c8, $90, $58, $70, $a8, $40, $38
        dc.b $68, $88, $78, $18, $48, $a8, $c8, $c8, $c8, $c8, $c8, $c8
typeBLowerLevelSpriteIndex
        dc.b $2c, $2e, $54, $32, $34, $36, $4b, $38, $3a, $4b
;--------------------
		; Advance the animation for the amount of frames specified in register A.

advanceAnimationMultipleFrames subroutine
        sta legalScreenCounter1
.nextFrame
        jsr advanceAnimationSingleFrame
        jsr waitForVerticalBlankAndClearOAM
        lda legalScreenCounter1
        bne .nextFrame
        rts
;--------------------
lbl_a80a
        dc.b $97, $8f, $87, $8f
lbl_a80e
        dc.b $97, $8f, $87, $87, $8f, $97, $8f, $87, $87, $8f
lbl_a818
        dc.b $29, $29, $29, $2a, $2a, $2a, $2a, $2a, $29, $29
        dc.b $21, $a5, $ff, $ff, $ff, $fe
        dc.b $21, $c5, $ff, $ff, $ff, $fe, $21, $e5, $ff, $ff, $ff, $fd, $23, $1a, $ff, $fe
        dc.b $23, $39, $ff
        dc.b $ff, $ff, $fe, $23, $59, $ff, $ff, $ff, $fe, $23, $79, $ff, $ff, $ff, $fd, $23
        dc.b $15, $ff, $ff, $ff, $fe, $23, $35, $ff, $ff, $ff, $fe, $23, $55, $ff, $ff, $ff
        dc.b $fe, $23, $75, $ff, $ff, $ff, $fd, $21, $88, $ff, $ff, $ff, $fe, $21, $a8, $ff
        dc.b $ff, $ff, $fe, $21, $c8, $ff, $ff, $ff, $fe, $21, $e8, $ff, $ff, $ff, $fd, $22
        dc.b $46, $ff, $ff, $ff, $ff, $fe, $22, $66, $ff, $ff, $ff, $ff, $fe, $22, $86, $ff
        dc.b $ff, $ff, $ff, $fe, $22, $a6, $ff, $ff, $ff, $ff, $fd, $20, $f9, $ff, $ff, $ff
        dc.b $fe, $21, $19, $ff, $ff, $ff, $fe, $21, $39, $ff, $ff, $ff, $fd, $23, $35, $ff
        dc.b $ff, $ff, $fe, $23, $55, $ff, $ff, $ff, $fe, $23, $75, $ff, $ff, $ff, $fd, $23
        dc.b $39, $ff, $ff, $ff, $fe, $23, $59, $ff, $ff, $ff, $fe, $23, $79, $ff, $ff, $ff
        dc.b $fd, $22, $58, $ff, $fe, $22, $75, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $22, $94
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $22, $b4, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $fe, $22, $d4, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $22
        dc.b $f4, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $23, $14, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $fe, $23, $34, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe
        dc.b $22, $ca, $46, $47, $fe, $22, $ea, $56, $57, $fd, $fc
;--------------------
showATypeEnding subroutine
        jsr disableBackgroundAndSprites
        jsr disableVerticalBlankingNMI
        lda #$2
        jsr switchCharBank0
        lda #$2
        jsr switchCharBank1
        jsr copyToVRAM
        dc.b <type_a_ending_screen_background, >type_a_ending_screen_background
        jsr copyToVRAM
        dc.b <ending_screen_color_palette, >ending_screen_color_palette
        jsr chooseATypeEnding
        jsr enableVerticalBlankingNMI
        jsr waitForVerticalBlankAndClearOAM
        jsr enableBackgroundAndSprites
        jsr waitForVerticalBlankAndClearOAM
        lda #RENDER_MODE_ENDING_ANIMATION
        sta renderMode
        lda #ENDINGS_MUSIC
        jsr startMusic
        lda #$80
        jsr advanceAnimationMultipleFrames
lbl_a95d
        jsr advanceAnimationSingleFrame
        jsr waitForVerticalBlankAndClearOAM
        lda $c5
        bne lbl_a95d
        lda buttonStateMirror   ; Start pressed.
        cmp #JOYPAD_START
        bne lbl_a95d
        rts
;--------------------
chooseATypeEnding subroutine
        lda #$0
        sta ending
        lda scoreMirror+2
        cmp #$5
        bcc lbl_a9a5
        lda #$1
        sta ending
        lda scoreMirror+2
        cmp #$7
        bcc lbl_a9a5
        lda #$2
        sta ending
        lda scoreMirror+2
        cmp #$10
        bcc lbl_a9a5
        lda #$3
        sta ending
        lda scoreMirror+2
        cmp #$12
        bcc lbl_a9a5
        lda #$4
        sta ending
        lda #$a8
        sta $15
        lda #$cc
        sta $14
        jsr copyEndingGraphicsToVRAM
lbl_a9a5
        ldx ending
        lda rocketSpriteY,x
        sta $c5
        lda #$0
        sta $c6
        rts
;--------------------
advanceATypeAnimation
        lda $c5
        cmp #$0
        beq .return
        sta spriteY
        lda #$58
        ldx ending
        lda rocketSpriteX,x
        sta spriteX
        lda rocketSpriteId,x
        sta objectAttributeEntryIndex
        jsr copyObjectAttributeData
        lda ending
        asl
        sta $a8
        lda frameCounterLowByte
        and #$2
        lsr
        clc
        adc $a8
        tax
        lda rocketBurnerSpriteId,x
        sta objectAttributeEntryIndex
        ldx ending
        lda rocketBurnerSpriteOffsetX,x
        clc
        adc spriteX
        sta spriteX
        jsr copyObjectAttributeData
        lda $c6
        cmp #$f0
        bne lbl_aa0e
        lda $c5
        cmp #$b0
        bcc lbl_a9fc
        lda frameCounterLowByte
        and #$1
        bne lbl_aa0b
lbl_a9fc
        lda #ENDING_ROCKET_SOUND
        sta noiseSoundEffect
        dec $c5
        lda $c5
        cmp #$80
        bcs lbl_aa0b
        dec $c5
lbl_aa0b
        jmp .return
lbl_aa0e
        inc $c6
.return
        rts
;--------------------
rocketSpriteId
        dc.b $3e, $41, $44, $47, $4a
rocketBurnerSpriteId
        dc.b $3f, $40, $42, $43, $45, $46, $48, $49, $23, $24
rocketBurnerSpriteOffsetX
        dc.b $00, $00, $00, $00, $00
rocketSpriteX
        dc.b $54, $54, $50, $48, $a0
rocketSpriteY
        dc.b $bf, $bf, $bf, $bf, $c7
;--------------------
waitForVerticalBlankAndClearOAM
        jsr advanceAudio
        lda #$0
        sta verticalBlankingInterval
        nop
lbl_aa37
        lda verticalBlankingInterval
        beq lbl_aa37
        lda #$ff
        ldx #$2
        ldy #$2
        jsr fillMemPage
        rts
;--------------------
waitForVerticalBlankingInterval
        jsr advanceAudio
        lda #$0
        sta verticalBlankingInterval
        nop
lbl_aa4d
        lda verticalBlankingInterval
        beq lbl_aa4d
        rts
;--------------------
disableBackgroundAndSprites
        jsr waitForVerticalBlankingInterval
        lda ppuMaskFlags    ; Disable background and sprites
        and #$e1
setPpuMask
        sta PPUMASK
        sta ppuMaskFlags
        rts
;--------------------
enableBackgroundAndSprites
        jsr waitForVerticalBlankingInterval
        jsr resetPpuScrollAndCtrlFlags
        lda ppuMaskFlags
        ora #$1e            ; Enable background and sprites
        bne setPpuMask
;--------------------
enableVerticalBlankingNMI
        lda PPUSTATUS       ; Wait for vertical blank
        and #$80
        bne enableVerticalBlankingNMI
        lda ppuCtrlFlags
        ora #$80
        bne setPpuCtrl
disableVerticalBlankingNMI
        lda ppuCtrlFlags
        and #$7f
setPpuCtrl
        sta PPUCTRL
        sta ppuCtrlFlags
        rts
;--------------------
clearVRAM
        ldx #$ff
        ldy #$0
        jsr fillVRAM
        rts
;--------------------
resetPpuScrollAndCtrlFlags
        lda #$0
        sta PPUSCROLL
        sta PPUSCROLL
        lda ppuCtrlFlags
        sta PPUCTRL
        rts
;--------------------
copyToVRAM
        jsr patchReturnAddress
        jmp lbl_aaf2
;--------------------
lbl_aa9e
        pha
        sta PPUADDR
        iny
        lda ($0),y
        sta PPUADDR
        iny
        lda ($0),y
        asl
        pha
        lda ppuCtrlFlags
        ora #$4
        bcs lbl_aab5
        and #$fb
lbl_aab5
        sta PPUCTRL
        sta ppuCtrlFlags
        pla
        asl
        php
        bcc lbl_aac2
        ora #$2
        iny
lbl_aac2
        plp
        clc
        bne lbl_aac7
        sec
lbl_aac7
        ror
        lsr
        tax
lbl_aaca
        bcs lbl_aacd
        iny
lbl_aacd
        lda ($0),y
        sta PPUDATA
        dex
        bne lbl_aaca
        pla
        cmp #$3f
        bne lbl_aae6
        sta PPUADDR
        stx PPUADDR
        stx PPUADDR
        stx PPUADDR
lbl_aae6
        sec
        tya
        adc $0
        sta $0
        lda #$0
        adc $1
        sta $1
lbl_aaf2
        ldx PPUSTATUS
        ldy #$0
        lda ($0),y
        bpl lbl_aafc
        rts
lbl_aafc
        cmp #$60
        bne lbl_ab0a
        pla
        sta $1
        pla
        sta $0
        ldy #$2
        bne lbl_aae6
lbl_ab0a
        cmp #$4c
        bne lbl_aa9e
        lda $0
        pha
        lda $1
        pha
        iny
        lda ($0),y
        tax
        iny
        lda ($0),y
        sta $1
        stx $0
        bcs lbl_aaf2

        ; Modify return address on the stack based on the 2 bytes following the jump into this routine.

patchReturnAddress
        tsx            ; Store original return address in $5-$6.
        lda $103,x
        sta $5
        lda $104,x
        sta $6
        ldy #$1        ; Store 2 bytes following the original return address in $0-$1.
        lda ($5),y
        sta $0
        iny
        lda ($5),y
        sta $1
        clc            ; Add 2 to the return address and copy back to stack.
        lda #$2
        adc $5
        sta $103,x
        lda #$0
        adc $6
        sta $104,x
        rts
;--------------------

        ; Generates a new pseudo random value at the memory address contained in register X and with length contained
        ; in register Y.

generateRandomNumber subroutine
        lda $0,x        ; extract bit 1
        and #$2
        sta $0
        lda $1,x        ; extract bit 9
        and #$2
        eor $0          ; XOR bits 1 and 9 and set/clear carry accordingly
        clc
        beq lbl_ab57
        sec
lbl_ab57                ; right shift, shift in the XORed value
        ror $00,x
        inx
        dey
        bne lbl_ab57
        rts
;--------------------
initializeOAM subroutine
        lda #$0
        sta OAMADDR
        lda #$2
        sta OAMDMA
        rts
;--------------------
readControllerButtons subroutine
        ldx controllerStrobeValue	; Strobe the bit 0 of the JOYPAD1 register to reload
        inx							; the button state.
        stx JOYPAD1
        dex
        stx JOYPAD1
        ldx #$8
.nextButton
        lda JOYPAD1
        lsr
        rol buttonStateMirror
        lsr
        rol $00
        lda JOYPAD2
        lsr
        rol buttonPressedMirror
        lsr
        rol $01
        dex
        bne .nextButton
        rts
;--------------------
updateButtonState
        lda $0
        ora buttonStateMirror
        sta buttonStateMirror
        lda $1
        ora buttonPressedMirror
        sta buttonPressedMirror
        rts
;--------------------
        jsr readControllerButtons
        beq lbl_abbd
;--------------------
pollController subroutine
        jsr readControllerButtons
        jsr updateButtonState
        lda buttonStateMirror
        sta lineIndex
        lda buttonPressedMirror
        sta loopIndex
        jsr readControllerButtons
        jsr updateButtonState
        lda buttonStateMirror
        and lineIndex
        sta buttonStateMirror
        lda buttonPressedMirror
        and loopIndex
        sta buttonPressedMirror
lbl_abbd
        ldx #$1
lbl_abbf
        lda buttonStateMirror,x
        tay
        eor heldButtonsMirror,x
        and buttonStateMirror,x
        sta buttonStateMirror,x
        sty heldButtonsMirror,x
        dex
        bpl lbl_abbf
        rts
;--------------------
        jsr readControllerButtons
;--------------------
lbl_abd1
        ldy buttonStateMirror
        lda buttonPressedMirror
        pha
        jsr readControllerButtons
        pla
        cmp buttonPressedMirror
        bne lbl_abd1
        cpy buttonStateMirror
        bne lbl_abd1
        beq lbl_abbd
        jsr readControllerButtons
        jsr updateButtonState
lbl_abea
        ldy buttonStateMirror
        lda buttonPressedMirror
        pha
        jsr readControllerButtons
        jsr updateButtonState
        pla
        cmp buttonPressedMirror
        bne lbl_abea
        cpy buttonStateMirror
        bne lbl_abea
        beq lbl_abbd
        jsr readControllerButtons
        lda $0
        sta heldButtonsMirror
        lda $1
        sta $f8
        ldx #$3
lbl_ac0d
        lda buttonStateMirror,x
        tay
        eor $f1,x
        and buttonStateMirror,x
        sta buttonStateMirror,x
        sty $f1,x
        dex
        bpl lbl_ac0d
        rts
;--------------------
fillVRAM
        sta $0
        stx $1
        sty $2

        lda PPUSTATUS

        lda ppuCtrlFlags    ; Disable background
        and #controllerStrobeValue
        sta PPUCTRL
        sta ppuCtrlFlags

        lda $0
        sta PPUADDR
        ldy #$0
        sty PPUADDR
        ldx #$4
        cmp #$20
        bcs lbl_ac40
        ldx $2
lbl_ac40
        ldy #$0
        lda $1
lbl_ac44
        sta PPUDATA
        dey
        bne lbl_ac44
        dex
        bne lbl_ac44
        ldy $2
        lda $0
        cmp #$20
        bcc lbl_ac67
        adc #$2
        sta PPUADDR
        lda #$c0
        sta PPUADDR
        ldx #$40
lbl_ac61
        sty PPUDATA
        dex
        bne lbl_ac61
lbl_ac67
        ldx $1
        rts
;--------------------

        ; Fills the memory with the value in register A. Start page in register X, end page in register Y.

fillMemPage
        pha
        txa
        sty $1
        clc
        sbc $1
        tax
        pla
        ldy #$0
        sty $0
lbl_ac77
        sta ($0),y
        dey
        bne lbl_ac77
        dec $1
        inx
        bne lbl_ac77
        rts
;--------------------
switch
        asl
        tay
        iny
        pla
        sta $0
        pla
        sta $1
        lda ($0),y
        tax
        iny
        lda ($0),y
        sta $1
        stx $0
        jmp ($0)
;--------------------
        sei
        inc MMC1_LOAD       ; Clear MMC1 shift register
        lda #$1a
        jsr setMmc1Control
        rts
;--------------------
        rts
;--------------------
setMmc1Control
        sta MMC1_CONTROL
        lsr
        sta MMC1_CONTROL
        lsr
        sta MMC1_CONTROL
        lsr
        sta MMC1_CONTROL
        lsr
        sta MMC1_CONTROL
        rts
;--------------------
switchCharBank0
        sta MMC1_CHR_BANK_0
        lsr
        sta MMC1_CHR_BANK_0
        lsr
        sta MMC1_CHR_BANK_0
        lsr
        sta MMC1_CHR_BANK_0
        lsr
        sta MMC1_CHR_BANK_0
        rts
;--------------------
switchCharBank1
        sta MMC1_CHR_BANK_1
        lsr
        sta MMC1_CHR_BANK_1
        lsr
        sta MMC1_CHR_BANK_1
        lsr
        sta MMC1_CHR_BANK_1
        lsr
        sta MMC1_CHR_BANK_1
        rts
;--------------------
switchPrgBank
        sta MMC1_PRG_BANK
        lsr
        sta MMC1_PRG_BANK
        lsr
        sta MMC1_PRG_BANK
        lsr
        sta MMC1_PRG_BANK
        lsr
        sta MMC1_PRG_BANK
        rts
;--------------------

        ; Color palettes

ingame_screen_color_palette
        dc.b $3f, $00, $20
        dc.b $0f, $30, $12, $16, $0f, $20, $12, $18, $0f, $2c, $16, $29, $0f, $3c, $00, $30
        dc.b $0f, $35, $15, $22, $0f, $35, $29, $26, $0f, $2c, $16, $29, $0f, $3c, $00, $30
        dc.b $ff

copyright_screen_color_palette
        dc.b $3f, $00, $10
        dc.b $0f, $27, $2a, $2b, $0f, $3c, $2a, $22, $0f, $27, $2c, $29, $0f, $30, $3a, $15
        dc.b $ff

menu_screen_color_palette
        dc.b $3f, $00, $14
        dc.b $0f, $30, $38, $00, $0f, $30, $16, $00, $0f, $30, $21, $00, $0f, $16, $2a, $28
        dc.b $0f, $30, $29, $27
        dc.b $ff

ending_screen_color_palette
        dc.b $3f, $00, $20
        dc.b $12, $0f, $29, $37, $12, $0f, $30, $27, $12, $0f, $17, $27, $12, $0f, $15, $37
        dc.b $12, $0f, $29, $37, $12, $0f, $30, $27, $12, $0f, $17, $27, $12, $0f, $15, $37
        dc.b $ff

initialHighScoreTable
        dc.b $08, $0f, $17, $01, $12, $04 ; A-Type #1 name: HOWARD
        dc.b $0f, $14, $01, $13, $01, $0e ; A-Type #2 name: OTASAN
        dc.b $0c, $01, $0e, $03, $05, $2b ; A-Type #3 name: LANCE
        dc.b $00, $00, $00, $00, $00, $00
        dc.b $01, $0c, $05, $18, $2b, $2b ; B-Type #1 name: ALEX
        dc.b $14, $0f, $0e, $19, $2b, $2b ; B-Type #2 name: TONY
        dc.b $0e, $09, $0e, $14, $05, $0e ; B-Type #3 name: NINTEN
        dc.b $00, $00, $00, $00, $00, $00
        dc.b $01, $00, $00 ; A-Type #1 score
        dc.b $00, $75, $00 ; A-Type #2 score
        dc.b $00, $50, $00 ; A-Type #3 score
        dc.b $00, $00, $00
        dc.b $00, $20, $00 ; B-Type #1 score
        dc.b $00, $10, $00 ; B-Type #2 score
        dc.b $00, $05, $00 ; B-Type #3 score
        dc.b $00, $00, $00
        dc.b $09, $05, $00, $00 ; A-Type levels
        dc.b $09, $05, $00, $00 ; B-Type levels
        dc.b $ff

        ; Screen background data

copyright_screen_background
        incbin backgrounds/copyright_screen.bin

title_screen_background
        incbin backgrounds/title_screen.bin

game_select_screen_background
        incbin backgrounds/game_select_screen.bin

level_select_screen_background
        incbin backgrounds/level_select_screen.bin

ingame_screen_background
        incbin backgrounds/ingame_screen.bin

highscore_screen_background
        incbin backgrounds/highscore_screen.bin

highscore_table_background
        incbin backgrounds/highscore_table.bin

a_type_menu_color_palette_background
        dc.b $3f, $0a, $01, $16
        dc.b $20, $6d, $01, $0a, $20, $f3, $48, $ff, $21, $13, $48, $ff, $21, $33, $48, $ff
        dc.b $21, $53, $47, $ff, $21, $73, $47, $ff, $21, $93, $47, $ff, $21, $b3, $47, $ff
        dc.b $21, $d3, $47, $ff, $22, $33, $48, $ff, $22, $53, $48, $ff, $22, $73, $48, $ff
        dc.b $22, $93, $47, $ff, $22, $b3, $47, $ff, $22, $d3, $47, $ff, $22, $f3, $47, $ff
        dc.b $23, $13, $47, $ff
        dc.b $ff

b_type_ending_lvl9_screen_background
        incbin backgrounds/b_type_ending_lvl9_screen.bin

b_type_ending_screen_background
        incbin backgrounds/b_type_ending_screen.bin

type_a_ending_screen_background
        incbin backgrounds/a_type_ending_screen.bin

        ; Padding

        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02
        dc.b $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00
        dc.b $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $80
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $08, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $10, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $04, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $40, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $10, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $04, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $c0, $60, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $f7, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fb
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $7f, $ff, $df, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $df, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $fb, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $fe, $ff, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00

demoButtons

        ; Demo game controller inputs

        dc.b $00, $31, $40, $06, $00, $04, $40, $07, $00, $5d, $04, $2e
        dc.b $00, $05, $01, $08, $81, $05, $80, $00, $00, $04, $80, $04
        dc.b $81, $01, $01, $1c, $00, $00, $04, $2d, $00, $06, $02, $02
        dc.b $42, $06, $02, $04, $42, $04, $00, $1b, $02, $00, $00, $18
        dc.b $02, $0b, $00, $05, $04, $2e, $00, $01, $02, $04, $42, $09
        dc.b $02, $0a, $00, $11, $04, $2a, $00, $48, $02, $05, $82, $07
        dc.b $02, $18, $00, $04, $04, $2a, $00, $03, $01, $06, $81, $0c
        dc.b $01, $11, $00, $01, $04, $2d, $00, $08, $01, $0a, $00, $04
        dc.b $01, $01, $00, $3d, $04, $1a, $00, $01, $02, $05, $00, $08
        dc.b $04, $12, $00, $14, $02, $03, $42, $0b, $02, $03, $00, $10
        dc.b $04, $2d, $00, $1c, $02, $12, $82, $16, $02, $02, $00, $06
        dc.b $04, $28, $00, $07, $01, $0f, $00, $08, $01, $05, $00, $09
        dc.b $04, $2f, $00, $2f, $04, $07, $00, $0a, $04, $26, $00, $04
        dc.b $02, $03, $82, $0b, $02, $03, $00, $10, $02, $04, $00, $05
        dc.b $04, $2f, $00, $5f, $04, $16, $00, $17, $04, $18, $00, $02
        dc.b $02, $0a, $82, $18, $02, $02, $00, $03, $04, $2a, $00, $02
        dc.b $01, $07, $81, $02, $01, $02, $81, $02, $01, $05, $00, $36
        dc.b $40, $07, $00, $06, $04, $30, $00, $03, $02, $0d, $00, $04
        dc.b $01, $0d, $81, $05, $01, $05, $00, $11, $04, $2a, $00, $04
        dc.b $02, $03, $42, $0b, $02, $07, $00, $11, $04, $2f, $00, $21
        dc.b $04, $26, $00, $1a, $02, $04, $42, $12, $02, $12, $00, $10
        dc.b $04, $24, $00, $07, $01, $06, $81, $05, $01, $02, $00, $14
        dc.b $01, $0a, $00, $1c, $01, $05, $00, $04, $04, $26, $00, $05
        dc.b $02, $05, $00, $16, $04, $27, $00, $69, $81, $03, $01, $04
        dc.b $00, $16, $04, $20, $00, $03, $02, $14, $00, $0d, $02, $05
        dc.b $00, $09, $04, $0f, $00, $09, $04, $19, $00, $1b, $02, $05
        dc.b $00, $31, $04, $1e, $00, $43, $01, $02, $81, $08, $00, $09
        dc.b $01, $05, $00, $11, $04, $24, $00, $05, $02, $03, $82, $0e
        dc.b $02, $06, $00, $0b, $02, $04, $00, $1e, $04, $21, $00, $1d
        dc.b $02, $01, $42, $11, $02, $1a, $00, $13, $01, $11, $81, $0c
        dc.b $01, $14, $80, $06, $00, $09, $01, $04, $00, $09, $04, $20
        dc.b $00, $01, $01, $05, $41, $1d, $01, $04, $00, $01, $04, $31
        dc.b $00, $1c, $02, $2a, $00, $16, $04, $28, $00, $18, $02, $09
        dc.b $00, $4b, $02, $0b, $42, $0b, $02, $0c, $00, $07, $04, $1f
        dc.b $00, $0b, $02, $08, $00, $04, $02, $07, $00, $17, $04, $26
        dc.b $00, $05, $01, $02, $81, $03, $80, $00, $00, $12, $02, $03
        dc.b $00, $08, $04, $2a, $00, $02, $01, $08, $41, $12, $01, $14
        dc.b $00, $00, $04, $30, $00, $34, $02, $08, $00, $09, $02, $03
        dc.b $00, $21, $04, $28, $00, $2a, $04, $2e, $00, $06, $01, $13
        dc.b $81, $07, $01, $13, $00, $02, $04, $2d, $00, $29, $41, $0c
        dc.b $01, $00, $00, $21, $04, $2c, $00, $29, $01, $07, $41, $16
        dc.b $01, $0e, $00, $09, $04, $2b, $00, $0d, $01, $05, $81, $05
        dc.b $01, $06, $00, $0b, $01, $05, $00, $1d

demoPieceSpawns

        ; Demo game piece spawns

        dc.b $00, $14, $8a, $45, $22, $11, $88, $44, $22, $91, $48, $a4, $52, $29, $14, $0a
        dc.b $85, $c2, $e1, $70, $38, $9c, $4e, $a7, $53, $a9, $d4, $6a, $b5, $5a, $ad, $d6
        dc.b $6b, $35, $1a, $8d, $c6, $e3, $71, $38, $9c, $ce, $e7, $73, $b9, $dc, $ee, $f7
        dc.b $fb, $fd, $fe, $7f, $3f, $9f, $cf, $67, $33, $19, $0c, $86, $43, $21, $90, $c8
        dc.b $e4, $f2, $f9, $7c, $be, $5f, $af, $d7, $eb, $f5, $fa, $fd, $7e, $3f, $1f, $0f
        dc.b $07, $03, $81, $c0, $60, $b0, $d8, $ec, $f6, $7b, $3d, $1e, $8f, $c7, $e3, $f1
        dc.b $78, $bc, $de, $ef, $77, $3b, $1d, $8e, $c7, $e3, $f1, $f8, $fc, $fe, $7f, $bf
        dc.b $5f, $2f, $17, $8b, $c5, $62, $31, $98, $cc, $e6, $73, $39, $9c, $4e, $27, $93
        dc.b $c9, $64, $b2, $59, $2c, $16, $0b, $05, $82, $c1, $60, $b0, $58, $2c, $96, $4b
        dc.b $a5, $d2, $e9, $74, $3a, $9d, $4e, $27, $13, $89, $c4, $62, $b1, $d8, $6c, $b6
        dc.b $5b, $2d, $16, $8b, $45, $22, $91, $48, $a4, $d2, $e9, $f4, $fa, $fd, $fe, $ff
        dc.b $ff, $ff, $7f, $bf, $df, $6f, $b7, $5b, $2d, $96, $4b, $25, $92, $49, $a4, $d2
        dc.b $69, $34, $9a, $4d, $26, $13, $89, $44, $a2, $d1, $68, $b4, $5a, $2d, $96, $cb
        dc.b $e5, $f2, $f9, $7c, $3e, $1f, $8f, $47, $23, $91, $c8, $64, $32, $19, $8c, $c6
        dc.b $63, $31, $18, $0c, $06, $03, $81, $40, $a0, $d0, $68, $34, $1a, $0d, $86, $c3
        dc.b $78, $bc, $de, $ef, $77, $3b, $1d, $8e, $c7, $e3, $f1, $f8, $fc, $fe, $7f, $bf

        ; Sound routines

advanceAudio
        jmp $e216
resetAudio
        jmp $e244
initAudio
        jmp $e1d8

        incbin sound_routines.bin

resetHandler
        cld
        sei
        ldx    #$0
        stx PPUCTRL
        stx PPUMASK
lbl_ff0a
        lda PPUSTATUS
        bpl lbl_ff0a
lbl_ff0f
        lda PPUSTATUS
        bpl lbl_ff0f
        dex
        txs
        inc $ff00
        lda #$10
        jsr setMmc1Control
        lda #$0
        jsr switchCharBank0
        lda #$0
        jsr switchCharBank1
        lda #$0
        jsr switchPrgBank
        jmp boot

        ; Padding

        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $bf, $ff, $ff, $ff, $ef, $ff
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $ff
        dc.b $ef, $7f, $ff, $ff, $ff, $ff, $7d, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $ff, $ff, $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fb, $ff, $ff
        dc.b $ff, $ff, $bf, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
        dc.b $bf, $ff, $ff, $7f, $ff, $ff, $ff, $ff, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
        dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

        ; Interrupt vectors

        dc.b <nmiHandler, >nmiHandler        ; NMI vector
        dc.b <resetHandler, >resetHandler    ; Reset vector
        dc.b <irqHandler, >irqHandler        ; IRQ/BRK vector

        incbin pattern_tables.bin