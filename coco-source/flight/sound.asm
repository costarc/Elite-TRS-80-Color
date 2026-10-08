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

; A = the sound number (8 * the original's sound): play it now
NOISE   TST snd
        LBEQ no_x
        PSHS A,B,X,Y,U,CC
        ANDA #$F8               ; round to the original eight-byte table entry
        TFR A,B
        CLRA
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
no_f    LDA #$34                ; CA2 low: select the DAC as the sound source
        STA $FF01
        LDA #$35                ; CB2 low: select the DAC; keep CB1 field-sync IRQ enabled
        STA $FF03
        LDA #$3C                ; CB2 high: connect the DAC during the effect
        STA $FF23
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
        LDA #$3C                ; CA2 high: select source bit A = 1
        STA $FF01
        LDA #$3D                ; CB2 high: source 3 (none); keep CB1 field-sync IRQ enabled
        STA $FF03
        LDA #$34                ; CB2 low: disable the sound mux between effects
        STA $FF23
        PULS A,B,X,Y,U,CC
no_x    RTS

BEEP    LDA #32
        LBRA NOISE
EXNO    LDA #8                  ; (a laser hit of ours)
        LBRA NOISE
EXNO3   LDA #16                 ; (a collision, an explosion)
        LBRA NOISE
