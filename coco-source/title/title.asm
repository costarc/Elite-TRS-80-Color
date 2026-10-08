; The title screen: a rotating Cobra Mk III, as in the original TITLE/TLL2.
;
;   * orientation vectors unity $6000, rotated by the original MVS5 step
;     (1/16 rad, 1/512 damping) every tick: pitch counter 127 + roll counter 127
;   * z_hi starts at 96 (-DFULLAPPROACH) or, by default, where the ship stops being a dot,
;     and closes by one per tick down to 1; z_lo is 128
;   * the ship stays at the screen centre (x = y = 0)

; MVEIT for the title ship: pitch (roofv/nosev) then roll (roofv/sidev)
TMVEIT  LDX #ROOFV
        LDY #NOSEV
        JSR ROT2
        LDX #ROOFV+2
        LDY #NOSEV+2
        JSR ROT2
        LDX #ROOFV+4
        LDY #NOSEV+4
        JSR ROT2
        LDX #ROOFV
        LDY #SIDEV
        JSR ROT2
        LDX #ROOFV+2
        LDY #SIDEV+2
        JSR ROT2
        LDX #ROOFV+4
        LDY #SIDEV+4
        JMP ROT2

; TITLE set-up: show the Cobra Mk III first (the original title ship)
TITLE   EQU *                   ; as in the original: the 3D view with the dashboard below
        CLR tnames              ; no ship names unless asked for (T)
        CLR tcred               ; nor the credits (C)
        LDA #COBRAIDX
        IFDEF SHIPSEL
        LDA #SHIPSEL            ; test: start on another blueprint
        ENDC
        STA <shipidx

; Show ship <shipidx> of SHIPLIST from the start of the approach:
; sidev=(1,0,0) roofv=(0,1,0) nosev=(0,0,1), z_hi=96 (or the ship's visibility distance
; + 1 when that is closer), z_lo=128
TSETSHIP
        LDX #inwk
        LDD #0
        LDY #20
ti_clr  STD ,X++
        LEAY -1,Y
        BNE ti_clr
        LDD #$6000
        STD SIDEV
        STD ROOFV+2
        STD NOSEV+4
        LDA #128
        STA inwk+8
        LDB <shipidx
        ASLB
        LDX #SHIPLIST
        ABX
        LDX ,X
        STX <bp
        LDA #96                 ; the original starts at z_hi = 96, where the ship is a dot
        IFNDEF FULLAPPROACH     ; for most of the approach and nothing seems to happen: start
        LDB 13,X                ; where it turns from a dot into a wireframe (its visibility
        INCB                    ; distance, one more)
        CMPB #96
        BHS ts_z
        TFR B,A
ts_z    EQU *
        ENDC
        STA inwk+7
        RTS

        IFDEF SKIPTICKS
; test aid: fast-forward SKIPTICKS ticks without drawing
TSKIP   LDY #SKIPTICKS
tsk     LDA inwk+7
        CMPA #1
        BEQ tsk_m
        DEC inwk+7
tsk_m   PSHS Y
        JSR TMVEIT
        PULS Y
        LEAY -1,Y
        BNE tsk
        RTS
        ENDC

; New key presses: SPACE pauses, LEFT shows the next ship, RIGHT the previous
; one (wrapping). A ship change restarts the approach and redraws at once, so
; it also works while paused.
TKEYS   LDA #1
        STA eggarm              ; the IRQ watches for S-H-A-D-E (shaded mode)
        TST eggst
        BNE tk_g
        STA eggst
tk_g    JSR GETKEYS
        TFR A,B
        BITB #K_ENTER           ; ENTER: start the game
        LBNE NEWGAME
        BITB #K_N               ; N: no commander to load: the same
        LBNE NEWGAME
        BITB #K_Y               ; Y: load a commander from the disk, on the way in
        BEQ tk_y
        LDA #1
        STA loadreq
        JMP NEWGAME
tk_y    EQU *
        BITB #K_C               ; C: the credits instead of the ship, or back
        BEQ tk_cr
        LDA tcred
        EORA #1
        STA tcred
        PSHS B
        JSR TDRAW
        PULS B
tk_cr   EQU *
        BITB #K_T               ; T: show or hide the ship names
        BEQ tk_s
        LDA tnames
        EORA #1
        STA tnames
        PSHS B
        JSR TDRAW
        PULS B
tk_s    EQU *
        BITB #K_SPACE
        BEQ tk_l
        LDA <paused
        EORA #1
        STA <paused
tk_l    BITB #K_LEFT
        BEQ tk_r
        LDA <shipidx
        INCA
        CMPA #SHIPCOUNT
        BLO tk_set
        CLRA
        BRA tk_set
tk_r    BITB #K_RIGHT
        BEQ tk_x
        LDA <shipidx
        BNE tk_p
        LDA #SHIPCOUNT
tk_p    DECA
tk_set  STA <shipidx
        JSR TSETSHIP
        IFDEF SKIPTICKS
        JSR TSKIP
        ENDC
        JMP TDRAW
tk_x    RTS

; the credits (C): the text where the ship was (the ship goes on turning unseen). The heading is the title's own,
; row 1; the text is centred under it. Per line: row, column, the text, 0.
CREDITS LDX #CRTXT
tcr_l    LDB ,X+
        CMPB #255
        BEQ tcr_d
        LDA ,X+
        JSR PRAT
        BRA tcr_l
tcr_d    JMP FLIP

CRTXT
        FCB 4,2
        FCC "Original game and code by"
        FCB 0
        FCB 5,2
        FCC "Ian Bell and David Braben"
        FCB 0
        FCB 6,2
        FCC "(C) Acornsoft 1984"
        FCB 0
        FCB 8,2
        FCC "TRS-80 Color Computer version"
        FCB 0
        FCB 9,2
        FCC "Rewritten in 6809 assembly"
        FCB 0
        FCB 10,2
        FCC "from the original's logic and"
        FCB 0
        FCB 11,2
        FCC "data (annotated source by"
        FCB 0
        FCB 12,2
        FCC "Mark Moxon)"
        FCB 0
        FCB 14,2
        FCC "Programmed by Ronivon Costa"
        FCB 0
        FCB 15,2
        FCC "with AI assistance (Claude),"
        FCB 0
        FCB 16,2
        FCC "2026, v1.0.2"
        FCB 0
        FCB 255

; one TLL2 pass: approach, rotate, draw
TTICK   LDA inwk+7
        CMPA #1
        BEQ tt_nodec
        DEC inwk+7              ; bring the ship a bit closer
tt_nodec
        JSR TMVEIT
        LDA #128
        STA inwk+8              ; z_lo = 128: closest approach z_hi=1, z_lo=128
TDRAW   JSR RESTORE
        JSR DASHPAGE            ; the dashboard art under the view
        LDD #WORKBASE
        STD <work
        TST tcred
        LBNE CREDITS
        TST tnames              ; the ship name under the heading, when asked for
        BEQ td_n
        LDB <shipidx
        ASLB
        LDX #SHIPNAMES
        ABX
        LDX ,X
        LDB #3
        JSR PRCENT
td_n    EQU *
        JSR LL9
        IFDEF DEBUG
        JSR DBGDUMP
        ENDC
        JMP FLIP

        IFDEF DEBUG
DBGDUMP LDX #visible
        LDB #16
        LDA #0
        JSR DBGROW
        LDX #mag
        LDB #16
        LDA #1
        JSR DBGROW
        LDX #xp
        LDB #12
        LDA #2
        JSR DBGROW
        LDX #scr
        LDB #16
        LDA #3
        JSR DBGROW
        LDX #scr+16
        LDB #16
        LDA #4
        JSR DBGROW
        LDX #scr+32
        LDB #16
        LDA #5
        JSR DBGROW
        LDX #scr+48
        LDB #16
        LDA #6
        JSR DBGROW
        LDX #scr+64
        LDB #16
        LDA #7
        JSR DBGROW
        RTS
        ENDC
