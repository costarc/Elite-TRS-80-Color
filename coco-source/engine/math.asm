; Arithmetic helpers. Everything is built on the 6809's hardware 8x8 MUL.

; <mr(32) = <ma(16) * <mb(16), unsigned. Preserves X, Y, U.
MUL16   LDA <ma+1
        LDB <mb+1
        MUL
        STD <mr+2               ; lo*lo
        LDA <ma
        LDB <mb
        MUL
        STD <mr                 ; hi*hi
        LDA <ma
        LDB <mb+1
        MUL                     ; hi*lo at byte 1
        ADDD <mr+1
        STD <mr+1
        BCC m16_a
        INC <mr
m16_a   LDA <ma+1
        LDB <mb
        MUL                     ; lo*hi at byte 1
        ADDD <mr+1
        STD <mr+1
        BCC m16_b
        INC <mr
m16_b   RTS

; <mr+2(16) = <mr(32) / <md(16), unsigned, restoring. Needs mr(hi16) < md.
; Clobbers Y.
DIV32   LDY #16
        LDD <mr
dv_lp   ASL <mr+3
        ROL <mr+2
        ROLB
        ROLA
        BCS dv_sub
        CMPD <md
        BLO dv_no
dv_sub  SUBD <md
        INC <mr+3
dv_no   LEAY -1,Y
        BNE dv_lp
        RTS

; D = -D
NEGD    NEGA
        NEGB
        SBCA #0
        RTS

; D = D * 3/4 (signed): the screen's y scale. The original's 256-line screen is shown
; on 192 lines, so everything vertical is 3/4 of the original's pixels.
SC34    PSHS D
        ASRA
        RORB
        ASRA
        RORB
        STD <tmp
        PULS D
        SUBD <tmp
        RTS

; A = A * 3/4 (signed 8 bits)
SC34A   PSHS A
        ASRA
        ASRA
        STA <tmp
        PULS A
        SUBA <tmp
        RTS
