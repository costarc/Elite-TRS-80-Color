; Ship movement: the original MVEIT, rebuilt for the 6809.
;
; Each tick, for the ship in inwk:
;   1. TIDY every 16th tick (re-orthonormalise the orientation vectors)
;   2. move forward along nosev:  pos += nosev_hi * speed / 64
;   3. apply the acceleration to the speed, clamped to 0..blueprint maximum
;   4. rotate the position by the player's roll (alpha) and pitch (beta):
;        K2 = y - alpha*x/256   z += beta*K2/256   y = K2 - beta*z/256
;        x += alpha*y/256
;   5. move back by the player's speed:  z -= delta
;   6. rotate the orientation vectors by alpha and beta (MVS4)
;   7. rotate the ship about itself by its own pitch and roll counters (MVS5)
; The 8-bit sign-magnitude arithmetic of the original becomes two's complement
; here; truncation stays toward zero, so the results track the original.

SIDEV   EQU inwk+9
ROOFV   EQU inwk+15
NOSEV   EQU inwk+21

; ---- arithmetic helpers ----------------------------------------------------------

; (24-bit value at ,X) += D (signed 16-bit)
ADD24   PSHS A
        ADDD 1,X
        STD 1,X
        PULS A                  ; hi byte of the original D: its sign extends
        TSTA                    ; (TST leaves the carry from ADDD alone)
        BPL ad_p
        LDA ,X
        ADCA #$FF
        STA ,X
        RTS
ad_p    LDA ,X
        ADCA #0
        STA ,X
        RTS

; <k24 = (signed 24-bit at ,X) * q >> 8, truncated toward zero; q = signed A.
; Positions run to millions (planets), so this keeps the full 24 bits.
MULP24  STA <mq
        LDA ,X
        STA <mg
        ANDA #$80
        STA <msg                ; sign of the position
        LDD 1,X
        STD <mg+1
        TST <msg
        BPL mp_p
        COM <mg                 ; magnitude = -value
        COM <mg+1
        COM <mg+2
        INC <mg+2
        BNE mp_p
        INC <mg+1
        BNE mp_p
        INC <mg
mp_p    LDA <mq
        BPL mp_q
        NEGA
mp_q    STA <qm
        LDA <mq
        EORA <msg
        STA <msg                ; bit 7: product negative
        LDA <mg+2               ; (lo*q) >> 8
        LDB <qm
        MUL
        STA <tlo
        LDA <mg+1               ; + mid*q
        LDB <qm
        MUL
        ADDB <tlo
        ADCA #0
        STD <tmp
        LDA <mg                 ; + (hi*q) << 8
        LDB <qm
        MUL
        STD <tmp2
        LDD <tmp
        STB <k24+2
        ADDA <tmp2+1
        STA <k24+1
        LDA <tmp2
        ADCA #0
        STA <k24
        TST <msg
        BPL mp_r
NEGK24  COM <k24
        COM <k24+1
        COM <k24+2
        INC <k24+2
        BNE mp_r
        INC <k24+1
        BNE mp_r
        INC <k24
mp_r    RTS

; (24-bit value at ,X) += <k24
ADDK24  LDA 2,X
        ADDA <k24+2
        STA 2,X
        LDA 1,X
        ADCA <k24+1
        STA 1,X
        LDA ,X
        ADCA <k24
        STA ,X
        RTS

; D = A * B, both signed 8-bit
SMUL8   STA <mq
        STB <qm
        EORB <mq
        STB <sgnt               ; bit 7: product negative
        LDA <mq
        BPL sm_a
        NEGA
sm_a    LDB <qm
        BPL sm_b
        NEGB
sm_b    MUL
        TST <sgnt
        BPL sm_r
        JSR NEGD
sm_r    RTS

; ---- rotating a ship's orientation ------------------------------------------------

; Original MVS5 on a pair of vectors (X -> a, Y -> b):
;   a' = a - a/512 + b/16        b' = b - b/512 - a/16
ROT2    LDD ,X
        STD <ta
        LDD ,Y
        STD <tb
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        STD <tq                 ; b/16
        LDD <ta
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        STD <tr                 ; a/16
        LDB <ta
        ASRB
        SEX
        STD <tw                 ; a/512
        LDD <ta
        SUBD <tw
        ADDD <tq
        STD ,X
        LDB <tb
        ASRB
        SEX
        STD <tw                 ; b/512
        LDD <tb
        SUBD <tw
        SUBD <tr
        STD ,Y
        RTS

; Original MVS4: rotate the vector at X (x,y,z as 16-bit) through the player's
; roll alpha and pitch beta (small angles, alpha/256 and beta/256 rad):
;   y -= alpha*x_hi   x += alpha*y_hi   y -= beta*z_hi   z += beta*y_hi
MVS4    LDA <alpha
        LDB ,X
        JSR SMUL8
        STD <tmp
        LDD 2,X
        SUBD <tmp
        STD 2,X
        LDA <alpha
        LDB 2,X
        JSR SMUL8
        ADDD ,X
        STD ,X
        LDA <beta
        LDB 4,X
        JSR SMUL8
        STD <tmp
        LDD 2,X
        SUBD <tmp
        STD 2,X
        LDA <beta
        LDB 2,X
        JSR SMUL8
        ADDD 4,X
        STD 4,X
        RTS

; the ship's own pitch counter (roofv/nosev) and roll counter (roofv/sidev):
; the counter is a duration (bit 7 = direction), 127 never runs out
MVOWN   LDA inwk+30
        ANDA #$7F
        BEQ mo_roll
        CMPA #$7F
        BEQ mo_p
        DEC inwk+30
mo_p    LDA inwk+30
        BMI mo_pn
        LDX #ROOFV
        LDY #NOSEV
        JSR ROT2
        LDX #ROOFV+2
        LDY #NOSEV+2
        JSR ROT2
        LDX #ROOFV+4
        LDY #NOSEV+4
        JSR ROT2
        BRA mo_roll
mo_pn   LDX #NOSEV              ; reverse direction = swap the pair
        LDY #ROOFV
        JSR ROT2
        LDX #NOSEV+2
        LDY #ROOFV+2
        JSR ROT2
        LDX #NOSEV+4
        LDY #ROOFV+4
        JSR ROT2
mo_roll LDA inwk+29
        ANDA #$7F
        BEQ mo_x
        CMPA #$7F
        BEQ mo_r
        DEC inwk+29
mo_r    LDA inwk+29
        BMI mo_rn
        LDX #ROOFV
        LDY #SIDEV
        JSR ROT2
        LDX #ROOFV+2
        LDY #SIDEV+2
        JSR ROT2
        LDX #ROOFV+4
        LDY #SIDEV+4
        JMP ROT2
mo_rn   LDX #SIDEV
        LDY #ROOFV
        JSR ROT2
        LDX #SIDEV+2
        LDY #ROOFV+2
        JSR ROT2
        LDX #SIDEV+4
        LDY #ROOFV+4
        JMP ROT2
mo_x    RTS

; ---- MVEIT --------------------------------------------------------------------------

; pos(\2) += nosev_hi(\1) * speed / 64
FWD     MACRO
        LDA \1
        PSHS A
        BPL @p
        NEGA
@p      LDB <tdl
        MUL                     ; the step: trunc(|nosev_hi| * speed*4 / 256) ...
        LDB mvn                 ; ... times the loops: the same as mvn single steps
        MUL
        TST ,S+
        BPL @a
        JSR NEGD
@a      LDX #\2
        JSR ADD24
        ENDM

MVEIT   LDA inwk+27             ; speed * 4
        ASLA
        ASLA
        STA <tdl
        LDB mvn                 ; (once for every loop of the reference game this frame)
        LBEQ mv_f0
        FWD NOSEV,inwk
        FWD NOSEV+2,inwk+3
        FWD NOSEV+4,inwk+6
mv_f0   EQU *
        LDA inwk+27             ; speed += acceleration, within 0..maximum
        ADDA inwk+28
        BPL mv_a
        CLRA
mv_a    LDX <bp
        CMPA 15,X
        BLO mv_b
        LDA 15,X
mv_b    STA inwk+27
        CLR inwk+28
        LDA <alpha              ; our roll and pitch swing the sky round us
        ORA <beta
        BEQ mv_nr
MVROT   LDX #inwk               ; K2 = y - alpha*x/256
        LDA <alpha
        JSR MULP24
        JSR NEGK24
        LDA inwk+3
        STA <k2
        LDD inwk+4
        STD <k2+1
        LDX #k2
        JSR ADDK24
        LDX #k2                 ; z += beta*K2/256
        LDA <beta
        JSR MULP24
        LDX #inwk+6
        JSR ADDK24
        LDX #inwk+6             ; y = K2 - beta*z/256
        LDA <beta
        JSR MULP24
        JSR NEGK24
        LDA <k2
        STA inwk+3
        LDD <k2+1
        STD inwk+4
        LDX #inwk+3
        JSR ADDK24
        LDX #inwk+3             ; x += alpha*y/256
        LDA <alpha
        JSR MULP24
        LDX #inwk
        JSR ADDK24
mv_nr   LDB <delta              ; z -= our speed
        CLRA
        JSR NEGD
        LDX #inwk+6
        JSR ADD24
        LDA inwk+34             ; the sun does not turn about itself
        CMPA #129
        BEQ mv_end
        LDA <alpha
        ORA <beta
        BEQ mv_own
        LDX #NOSEV
        JSR MVS4
        LDX #ROOFV
        JSR MVS4
        LDX #SIDEV
        JSR MVS4
mv_own  LDB mvn                 ; the ship's own turns, as often
        BEQ mv_o0
        PSHS B
mv_o    JSR MVOWN
        DEC ,S
        BNE mv_o
        PULS B,PC
mv_o0   RTS
mv_end  RTS

; planets and suns skip the forward movement and acceleration (original MV3 -> MV40)
MVPLAN  LDA <alpha
        ORA <beta
        BEQ mv_nr
        JMP MVROT

; ---- TIDY -------------------------------------------------------------------------------

; |A| in A
ABSA    TSTA
        BPL ab_r
        NEGA
ab_r    RTS

; signed D / 96 -> B (clamped to +-127), truncated toward zero. Below the clamp |D| < 12288:
; |D|/96 = (|D|>>5)/3 with n = |D|>>5 < 384, and n/3 = n*171>>9 for n < 192 (exact; checked
; for every D), so n >= 192 is taken as 64 + (n-192)/3
SDIV96  STA <sgnt
        TSTA
        BPL sd_p
        JSR NEGD
sd_p    CMPD #12288             ; (unsigned: -32768 negated is 32768 here)
        BHS sd_c
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        CLR <tmp
        CMPD #192
        BLO sd_m
        SUBD #192
        LDA #64
        STA <tmp
sd_m    LDA #171
        MUL
        LSRA
        ADDA <tmp
        TFR A,B
        BRA sd_n
sd_c    LDB #127
sd_n    TST <sgnt
        BPL sd_r
        NEGB
sd_r    RTS

; B = integer square root of D (A = 0; X kept): the largest r with r*r <= D, counted down
; from RTAB[D/256] = isqrt(D/256*256+255) (a step or two; at most 15 below 256)
ISQRT16 STD <tmp
        PSHS X
        LDX #RTAB
        TFR A,B
        ABX
        LDB ,X
        STB <tmp2
is_l    LDA <tmp2
        TFR A,B
        MUL
        CMPD <tmp
        BLS is_d
        DEC <tmp2
        BRA is_l
is_d    LDB <tmp2
        CLRA
        PULS X,PC

SQ      MACRO
        LDA \1,X
        BPL @p
        NEGA
@p      TFR A,B
        MUL
        ADDD <tdk
        STD <tdk
        ENDM

NRM     MACRO                   ; c = c * k / 256, k = 96*256/length
        LDA \1,X
        PSHS A
        BPL @p
        NEGA
@p      PSHS A
        LDB <mr+3
        MUL
        STA <tlo
        LDA ,S+
        LDB <mr+2
        MUL
        ADDB <tlo
        ADCA #0
        TSTA
        BNE @c
        CMPB #127
        BLS @n
@c      LDB #127
@n      TST ,S+
        BPL @s
        NEGB
@s      STB \1,X
        ENDM

; scale the 3 signed bytes at X to length 96
NORM3   LDD #0
        STD <tdk
        SQ 0
        SQ 1
        SQ 2
        LDD <tdk
        LBEQ nm_r
        JSR ISQRT16             ; (X kept)
        TSTB
        LBEQ nm_r
        PSHS X
        LDX #NTH                ; k = 96*256/length in <mr+2 (the table of MKTABS)
        ABX
        LDA ,X
        LDB 256,X
        STD <mr+2
        PULS X
        NRM 0
        NRM 1
        NRM 2
nm_r    RTS

TIDYB   FCB 1,0,0
TIDYC   FCB 2,2,1

CRS     MACRO                   ; tds+\5 = (n\1*r\2 - n\3*r\4) / 96
        LDA <tdn+\1
        LDB <tdr+\2
        JSR SMUL8
        STD <tdk
        LDA <tdn+\3
        LDB <tdr+\4
        JSR SMUL8
        STD <tmp
        LDD <tdk
        SUBD <tmp
        JSR SDIV96
        STB <tds+\5
        ENDM

; put hi byte A at \1 and zero its low byte
PUTV    MACRO
        STA \1
        CLR \1+1
        ENDM

; Re-orthonormalise: nosev to length 96; roofv made perpendicular to it (solving
; for the component along the axis where nosev is largest) and normalised;
; sidev = roofv x nosev. Works on the hi bytes (96 = 1) as the original does.
TIDY    LDA NOSEV
        STA <tdn
        LDA NOSEV+2
        STA <tdn+1
        LDA NOSEV+4
        STA <tdn+2
        LDX #tdn
        JSR NORM3
        LDA ROOFV
        STA <tdr
        LDA ROOFV+2
        STA <tdr+1
        LDA ROOFV+4
        STA <tdr+2
        CLR <tdl                ; axis a of the largest |nosev| component
        LDA <tdn
        JSR ABSA
        STA <tdk
        LDA <tdn+1
        JSR ABSA
        CMPA <tdk
        BLS ti_1
        STA <tdk
        LDA #1
        STA <tdl
ti_1    LDA <tdn+2
        JSR ABSA
        CMPA <tdk
        BLS ti_2
        LDA #2
        STA <tdl
ti_2    LDB <tdl
        LDX #TIDYB
        LDA B,X
        STA <tdv                ; b
        LDX #TIDYC
        LDA B,X
        STA <tdv+1              ; c
        LDX #tdn                ; S = n_b*r_b + n_c*r_c
        LDY #tdr
        LDB <tdv
        LDA B,X
        PSHS A
        LDA B,Y
        TFR A,B
        PULS A
        JSR SMUL8
        STD <tdk
        LDX #tdn
        LDY #tdr
        LDB <tdv+1
        LDA B,X
        PSHS A
        LDA B,Y
        TFR A,B
        PULS A
        JSR SMUL8
        ADDD <tdk               ; D = S
        STD <tmp
        LDX #tdn
        LDB <tdl
        LDA B,X                 ; n_a
        STA <qm
        LDA <tmp
        EORA <qm
        COMA
        STA <sgnt               ; bit 7: -S/n_a negative when S and n_a share a sign
        LDA <qm
        JSR ABSA
        CLR <md
        STA <md+1
        BEQ ti_d0
        LDD <tmp
        TSTA
        BPL ti_sp
        JSR NEGD
ti_sp   STD <mr+2               ; |S| / |n_a|: 127 when the quotient would be 128 or more,
        LDA <md+1               ; else eight steps of a 16/8 division (the high byte is
        LDB #128                ; below the divisor, which is at most 128: no carry)
        MUL
        CMPD <mr+2
        BLS ti_cl
        LDD <mr+2
        LDA #8                  ; (the step count in <tmp)
        STA <tmp
        LDA <mr+2
ti_dv   ASLB
        ROLA
        CMPA <md+1
        BLO ti_dn
        SUBA <md+1
        INCB
ti_dn   DEC <tmp
        BNE ti_dv
        BRA ti_ok
ti_cl   LDB #127
ti_ok   TST <sgnt
        BPL ti_st
        NEGB
ti_st   TFR B,A
        LDB <tdl
        LDX #tdr
        STA B,X                 ; roofv_a
ti_d0   LDX #tdr
        JSR NORM3
        CRS 2,1,1,2,0           ; sidev = roofv x nosev  (/96)
        CRS 0,2,2,0,1
        CRS 1,0,0,1,2
        LDA <tdn
        PUTV NOSEV
        LDA <tdn+1
        PUTV NOSEV+2
        LDA <tdn+2
        PUTV NOSEV+4
        LDA <tdr
        PUTV ROOFV
        LDA <tdr+1
        PUTV ROOFV+2
        LDA <tdr+2
        PUTV ROOFV+4
        LDA <tds
        PUTV SIDEV
        LDA <tds+1
        PUTV SIDEV+2
        LDA <tds+2
        PUTV SIDEV+4
        RTS
