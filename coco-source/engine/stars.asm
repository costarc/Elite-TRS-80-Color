; Stardust, front view (original STARS1); the rear and side views are in views.asm.
;
; Each particle is a screen-space point (x, y) with a depth z. Per tick, with
; q = 64*speed/z_hi (at least 1, and odd) the dust rushes outward and swings
; with our roll alpha and pitch beta:
;   z -= speed*64
;   y += y_hi*q      x += x_hi*q
;   y -= alpha*x_hi  x += alpha*y_hi          (the same sense as MVEIT)
;   x += 2*(beta*y_hi/256)^2    y -= beta*256
; A particle leaving |x_hi| or |y_hi| >= 120, or with z_hi < 16, is recycled far
; away. The original stores x_hi, y_hi in sign-magnitude; here they are signed.
; Size follows distance: z_hi < 80 a 2x2 square, < 144 a 2-pixel dash, else a dot.

; sign-magnitude byte in A -> signed
SMTOS   TSTA
        BPL sm_p
        ANDA #$7F
        NEGA
sm_p    RTS

; (,U) += D, saturating at +-32767
ADDSAT  ADDD ,U
        BVC as_s
        TSTA
        BMI as_h
        LDD #$8001
        BRA as_s
as_h    LDD #$7FFF
as_s    STD ,U
        RTS

; D = A (signed) * B (unsigned)
SMULU   STA <mq
        TSTA
        BPL su_p
        NEGA
su_p    MUL
        TST <mq
        BPL su_r
        JSR NEGD
su_r    RTS

; a random cloud (original nWq): z_hi >= 8, x and y anywhere
STARINIT
        LDA #18
        STA <nostm
        LDX #stars
        LDA <nostm
        STA <cnt
sn_l    JSR DORND
        ORA #8
        STA 4,X
        JSR DORND
        STB 5,X
        JSR DORND
        JSR SMTOS
        STA ,X
        STB 1,X
        JSR DORND
        JSR SMTOS
        STA 2,X
        STB 3,X
        LEAX 6,X
        DEC <cnt
        BNE sn_l
        RTS

; recycle the particle at X far away, not too near the centre
STARKILL
        JSR DORND
        ORA #4
        JSR SMTOS
        STA 2,X
        JSR DORND
        ORA #8
        JSR SMTOS
        STA ,X
        JSR DORND
        ORA #144
        STA 4,X
        RTS

TWOS2   FCB $C0,$60,$30,$18,$0C,$06,$03,$03

; draw a particle: A = x_hi, B = y_hi (signed), z_hi in <tlo
STARPIX ADDA #128
        STA <lx0
        TFR B,A
        TSTA                    ; (TFR leaves the flags: they were the column's)
        BPL sp_a
        NEGA
sp_a    CMPA #CY*4/3             ; |y_hi| < 96 original lines
        BHS sp_r                ; off the top or bottom
        LDA <tmp2+1             ; y_hi, scaled by 3/4
        JSR SC34A
        STA <tmp
        LDA #CY
        SUBA <tmp               ; screen y = CY - 3/4 y_hi (y_hi saved by the caller)
        STA <ly0
; plot a particle at pixel (<lx0, A = row) sized by distance <tlo (the original PIXEL)
PIXELZ  STA <ly0
        LDB #32
        MUL
        ADDD <back
        TFR D,X
        LDB <lx0
        LSRB
        LSRB
        LSRB
        ABX
        LDA <lx0
        ANDA #7
        LDB <tlo
        CMPB #144
        BHS sp_one
        LDY #TWOS2
        LDB A,Y
        LDA ,X
        STB <tmp
        EORA <tmp
        STA ,X
        JSR DPIX
        LDB <tlo
        CMPB #80
        BHS sp_r                ; a dash is enough
        LDA <ly0                ; a square: second row above, or below on the top
        ANDA #7                 ; row of a character cell (as the original)
        BNE sp_up
        LEAX 32,X
        BRA sp_2
sp_up   LEAX -32,X
sp_2    LDA ,X
        EORA <tmp
        STA ,X
        JMP DPIX
sp_r    RTS
sp_one  LDY #MASKS
        LDB A,Y
        LDA ,X
        STB <tmp
        EORA <tmp
        STA ,X
        JMP DPIX
        RTS

; y += y_hi*q (or x): the magnitude grows away from the centre; saturates
; (a saturated particle is killed by the range test)
GROW    MACRO
        LDA \1,U
        BPL @p
        NEGA
        LDB <sq
        MUL
        STD <tmp
        LDD \1,U
        SUBD <tmp
        BVC @s
        LDD #$8001
        BRA @s
@p      LDB <sq
        MUL
        ADDD \1,U
        BVC @s
        LDD #$7FFF
@s      STD \1,U
        ENDM

; the roll and pitch part for the particle at X (only run while turning):
;   y -= alpha*x_hi   x += alpha*y_hi   x += 2*(beta*y_hi/256)^2   y -= beta*256
STARROT LDA <alpha
        LDB ,X
        JSR SMUL8
        JSR NEGD
        LEAU 2,X
        JSR ADDSAT
        LDA <alpha
        LDB 2,X
        JSR SMUL8
        LEAU ,X
        JSR ADDSAT
        LDA <beta
        LDB 2,X
        JSR SMUL8
        TFR A,B
        JSR SMUL8
        ASLB
        ROLA
        LEAU ,X
        JSR ADDSAT
        LDA <beta
        NEGA
        CLRB
        LEAU 2,X
        JMP ADDSAT

; one tick of the stardust, front view
STARS1  LDB <delta
        CLRA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        STD <d64                ; speed * 64
        LDA <alpha
        ORA <beta
        STA sflag
        LDU #stars
        LDA <nostm
        STA <cnt
st_l    LDB 4,U                 ; q = speed * (64 / z_hi), from the reciprocal tables
        LDX #STRHI
        ABX
        LDA <delta
        LDB ,X
        MUL
        STB <sq                 ; speed * Rhi
        LDA <delta
        LDB 256,X
        MUL
        ADDA <sq                ; + hi(speed * Rlo)
        ORA #1
        STA <sq
        LDD 4,U                 ; z -= speed*64
        SUBD <d64
        STD 4,U
        GROW 2                  ; y += y_hi * q
        GROW 0                  ; x += x_hi * q
        TST sflag
        BEQ st_r
        TFR U,X
        PSHS U
        JSR STARROT
        PULS U
st_r    LDA ,U                  ; still on screen? |x_hi| < 120, |y_hi| < 120, z_hi >= 16
        ADDA #119
        CMPA #239
        BHS st_k
        LDA 2,U
        ADDA #119
        CMPA #239
        BHS st_k
        LDA 4,U
        CMPA #16
        BHS st_d
st_k    TFR U,X
        IFNDEF NOKILL
        JSR STARKILL
        ENDC
st_d    LDA 4,U
        STA <tlo
        LDA 2,U
        STA <tmp2+1
        TFR A,B
        LDA ,U
        IFNDEF NODRAW
        JSR STARPIX
        ENDC
        LEAU 6,U
        DEC <cnt
        LBNE st_l
        RTS
