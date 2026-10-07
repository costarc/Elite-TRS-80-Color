; The missions and the jump tokens of their texts. Mission 1: the stolen Constrictor (briefing
; when docked with at least Competent rank in the first two galaxies; killing it completes it);
; mission 2: the Thargoid plans (briefed at Ceerdi, picked up at Birera, delivered at Birera's
; navy). The state is in tp: bit 0 mission 1 in progress, bit 1 completed; bits 2-3 mission 2
; (1 in progress, 2 plans on board, 3 done) -- as the original's TP.

; ---- the jump tokens of the texts ----------------------------------------------------------------

; clear the three text rows at the bottom and start at the first of them (CLYNS)
CLYNS   LDA #$FF
        STA dtw2                ; not in a word
        LDA #20
        STA yc
        JSR TT67
        LDD <back
        ADDD #21*256
        TFR D,X
        LDY #384
        LDD #0
cly_l   STD ,X++
        LEAY -1,Y
        BNE cly_l
        LDA #1
        STA xc
        RTS

MT23    LDA #10                 ; row 10, white, lower case
        BRA mt29b
MT29    LDA #6                  ; row 6
mt29b   STA yc
        JMP MT13

; the captain's name (J27) and the system a ship was last seen at (J28): tokens 217/220 + galaxy
MT27    LDA #217
        BRA mt28b
MT28    LDA #220
mt28b   ADDA gcnt
        JMP DETOK

; a key, after the last has gone up (PAUSE2)
PAUSE2  JMP WAITKEY

; "INCOMING MESSAGE" and two seconds (BRIS)
BRIS    LDA #216
        JSR DETOK
        LDY #100
        JMP DELAY

; (MT26, the line of text, is in disk.asm)

; the text has reached the bottom of the screen (we have 24 rows where the original has 32): a key,
; then the rows from mpg down are cleared and the text goes on there
MORE    PSHS A,B,X,Y,U
        JSR WAITKEY
        LDA mpg
        CLRB
        ADDD <back
        TFR D,X
        LDA #24
        SUBA mpg
        LDB #128
        MUL
        TFR D,Y
        LDD #0
mo_l    STD ,X++
        LEAY -1,Y
        BNE mo_l
        LDA mpg
        STA yc
        LDA #1
        STA xc
        PULS A,B,X,Y,U
        RTS

; ---- the briefing's ship ----------------------------------------------------------------------------

; copy the page on show to the other page
PGCOPY  LDX <back
        LDD <back
        CMPA #$80
        BNE pgc_a
        LDU #$9800
        BRA pgc_b
pgc_a   LDU #$8000
pgc_b   LDY #3072
pgc_l   LDD ,X++
        STD ,U++
        LEAY -1,Y
        BNE pgc_l
        RTS

; the ship at the top of the screen, turning, over the text: until a key (PAUSE)
PAUSE   JSR PGCOPY              ; the text is on both pages; only the top ten rows change
pa_r    JSR KEYSCAN             ; (a key still down from before has to go up first)
        TSTA
        BNE pa_r
        JSR DOCKSETUP           ; draw on the other page now
pa_l    LDX <back
        LDY #1280
        LDD #0
pa_c    STD ,X++
        LEAY -1,Y
        BNE pa_c
        LDD #200                ; (the original WORKBASE: a vsync or so)
        STD <work
        JSR PAS1
        JSR FLIP
        IFDEF DOCKAUTO          ; test: the key comes by itself
        LDA <vcnt
        CMPA #200
        BLO pa_l
        ELSE
        JSR KEYSCAN
        TSTA
        BEQ pa_l
        ENDC
        JMP DOCKSETUP           ; and back to drawing on the page that is shown

; the ship at (0, 112, 512), turning (PAS1)
PAS1    LDA #112
        STA inwk+5
        CLRA
        STA inwk+2
        STA inwk+8
        LDA #2
        STA inwk+7
        JSR LL9
        JMP MVEIT

; ---- entering the bay: what the missions have to say (DOENTRY's checks) ------------------------

MISSIONS
        LDA tp
        ANDA #3
        BNE mi_1
        LDA kills               ; below Competent: nothing; and only in the first two galaxies
        BEQ mi_x
        LDA gcnt
        LSRA
        BNE mi_x
        JMP BRIEF
mi_1    CMPA #3
        BNE mi_2
        JMP DEBRIEF
mi_2    LDA tp
        ANDA #15
        CMPA #2
        BNE mi_3
        LDA kills               ; mission 2 asks for rank 3/8 of the way to Deadly
        CMPA #5
        BLO mi_x
        LDA gcnt
        CMPA #2
        BNE mi_x
        JMP BRIEF2
mi_3    CMPA #6
        BNE mi_5
        LDA gcnt
        CMPA #2
        BNE mi_x
        LDA qq0
        CMPA #215
        BNE mi_x
        LDA qq1
        CMPA #84
        BNE mi_x
        JMP BRIEF3
mi_5    CMPA #10
        BNE mi_x
        LDA gcnt
        CMPA #2
        BNE mi_x
        LDA qq0
        CMPA #63
        BNE mi_x
        LDA qq1
        CMPA #72
        BNE mi_x
        JMP DEBRIEF2
mi_x    RTS

BRIEF2  LDA tp                  ; mission 2 is in progress, no plans yet
        ORA #4
        STA tp
        LDA #11
BRP     JMP DETOK
BRIEF3  LDA tp                  ; the plans are on board
        ANDA #$F0
        ORA #$0A
        STA tp
        LDA #222
        LBRA BRP
DEBRIEF2
        LDA tp                  ; mission 2 is done: the navy's energy unit and 256 kills
        ORA #4
        STA tp
        LDA #2
        STA engy
        INC kills
        LDA #223
        LBRA BRP
DEBRIEF LDA tp                  ; mission 1 is done: 256 kills and 5000 Cr
        ANDA #$FE
        STA tp
        INC kills
        LDD #50000
        JSR MCASH
        LDA #15
        LBRA BRP

; the Constrictor turning on the screen, rising, then the message (BRIEF)
BRIEF   LDA tp
        ORA #1
        STA tp
        JSR BRIS
        JSR DOCKSETUP           ; draw on the page that is not shown, flipping
        JSR ZINF
        LDX #DKCON              ; (no ship set is in: the blueprint comes with this overlay)
        STX <bp
        LDA #TY_CON
        STA inwk+34
        LDA #1
        STA xc
        STA inwk+7              ; z = 256
        CLR <alpha
        CLR <beta
        CLR <delta              ; (we are not flying: the ship stays where it is put)
        LDA #64
        STA <mcnt
br_1    LDA #$7F
        STA inwk+29
        STA inwk+30
        JSR BRSHOW
        JSR MVEIT
        DEC <mcnt
        BNE br_1
br_2    LSR inwk+2              ; it moves to the middle and away, and up
        INC inwk+8
        BEQ br_3
        INC inwk+8
        BEQ br_3
        LDA inwk+5
        INCA
        CMPA #112
        BLO br_y
        LDA #112
br_y    STA inwk+5
        JSR BRSHOW
        JSR MVEIT
        BRA br_2
br_3    INC inwk+7
        JSR DOCKSETUP           ; the text goes on the page that is shown
        LDA #10
        STA mpg                 ; (the text goes on below the ship, page by page)
        LDA #10
        JSR BRP
        CLR mpg
        RTS

; one frame of the briefing ship: a clear screen with its frame, the ship, shown
BRSHOW  LDA #1
        JSR TT66
        LDD #200                ; (the original WORKBASE: a vsync or so)
        STD <work
        JSR LL9
        JMP FLIP

; the Constrictor's blueprint for the briefing
        INCLUDE "gen/con.inc"
