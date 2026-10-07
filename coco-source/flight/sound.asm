; Sound: the CoCo has no sound chip, only a 6-bit DAC ($FF20, bits 2-7) the program has to
; feed by hand. The effects are played at once, by the program itself, and are short: a
; chirp (a square wave whose half period changes a step with every wave) or a burst of noise.
; The numbers are the original's: NOISE is called with A = 0 our laser, 8 we are hit by a
; laser, 16 and 24 kills and our death, 32 a short high beep, 40 a long low beep, 48 a missile
; or a ship launched, 56 the hyperspace drive, 64 the E.C.M. on, 72 it off. The Q key goes
; from full sound (snd 1) to short combat sounds (2: they stop the game for a quarter of the
; time) to no sound (0).
;
; SNDTAB entry (8 bytes): type (0 chirp, 1 noise); chirp: half period, step (signed), waves
; (each a count of 8-cycle loops); noise: unused, delay count per sample, samples.

DAC     EQU $FF20
SNDHI   EQU $A8                 ; the two levels of the wave (6 bits in bits 2-7)
SNDLO   EQU $54

SNDTAB  FCB 0                   ; 0  our laser: a chirp down
        FDB 20,4,30
        FCB 0
        FCB 1                   ; 8  we are hit: a short burst
        FDB 0,5,420
        FCB 0
        FCB 1                   ; 16 a hit or a kill
        FDB 0,14,520
        FCB 0
        FCB 1                   ; 24 a long one: our death
        FDB 0,30,800
        FCB 0
        FCB 0                   ; 32 a short high beep
        FDB 22,0,20
        FCB 0
        FCB 0                   ; 40 a long low beep
        FDB 170,0,26
        FCB 0
        FCB 1                   ; 48 a missile or a ship launched: a dull burst
        FDB 0,40,260
        FCB 0
        FCB 0                   ; 56 hyperspace: a rising chirp
        FDB 200,-2,80
        FCB 0
        FCB 0                   ; 64 the E.C.M. on: a buzz
        FDB 70,0,60
        FCB 0
        FCB 0                   ; 72 off: nothing
        FDB 1,0,0
        FCB 0

; A = the sound number (8 * the original's sound): play it now
NOISE   TST snd
        BEQ no_x
        PSHS A,B,X,Y,U,CC
        LDB #8
        LSRA
        LSRA
        LSRA
        MUL
        ADDD #SNDTAB
        TFR D,U
        LDD 5,U
        BEQ no_r                ; no waves: silence
        TFR D,Y                 ; waves, or samples
        LDA snd                 ; short combat sounds (snd 2): a quarter of our laser, a hit
        CMPA #2                 ; or a kill
        BNE no_f
        LDA 1,S
        CMPA #24
        BHS no_f
        TFR Y,D
        LSRA
        RORB
        LSRA
        RORB
        TFR D,Y
no_f    EQU *
        LDX 1,U                 ; the half period / (the noise's) not used
        TST ,U
        BNE no_n
no_c    LDA #SNDHI              ; a chirp: a high half, a low half, each X * 8 + 20 cycles
        STA DAC
        PSHS X
no_h    LEAX -1,X
        BNE no_h
        PULS X
        LDA #SNDLO
        STA DAC
        PSHS X
no_l    LEAX -1,X
        BNE no_l
        PULS X
        LDD 3,U
        LEAX D,X                ; the next wave is longer or shorter
        LEAY -1,Y
        BNE no_c
        BRA no_r
no_n    LDX #$ACE1              ; noise: a 16-bit shift register picks the level of each sample
no_ns   TFR X,D
        LSRA
        RORB
        BCC no_nb
        EORA #$B4               ; (taps 16 14 13 11)
no_nb   TFR D,X
        LDA #SNDHI
        BCS no_nh
        LDA #SNDLO
no_nh   STA DAC
        LDD 3,U                 ; the delay between samples
        PSHS X
        TFR D,X
no_nd   LEAX -1,X
        BNE no_nd
        PULS X
        LEAY -1,Y
        BNE no_ns
no_r    LDA #$80                ; the DAC back to the middle
        STA DAC
        PULS A,B,X,Y,U,CC
no_x    RTS

BEEP    LDA #32
        LBRA NOISE
EXNO    LDA #8                  ; (a laser hit of ours)
        LBRA NOISE
EXNO3   LDA #16                 ; (a collision, an explosion)
        LBRA NOISE
