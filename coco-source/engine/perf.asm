; Performance helpers loaded once at $EE00, retained across SHIPS/DOCK swaps.
; Must fit two sectors and stay below the ship slots at $F000.

; Cached even-counter sine magnitudes. All CIRCLE steps are even; the
; orientation-dependent planet detail continues to use its own arithmetic.
; A changing radius uses the original path; build only on a repeated key.
CIRCACHE LDA kr
        CMPA cckey
        BNE cc_miss
        LDA kry
        CMPA cckey+1
        BNE cc_miss
        TST ccvalid
        BNE cc_ready
        PSHS U
        LDX perfsin
        LDY #CCOFF
        LDU #CCOFF+16
        LDB #16
        PSHS B
cc_build LDA ,X
        LDB kr
        MUL
        STA ,Y+
        LDA ,X
        LDB kry
        MUL
        STA ,U+
        LEAX 2,X
        DEC ,S
        BNE cc_build
        LEAS 1,S
        INC ccvalid
        PULS U
cc_ready RTS
cc_miss LDA kr
        STA cckey
        LDA kry
        STA cckey+1
        CLR ccvalid
        RTS

CIRLOOK LDX #CCOFF
        BRA cc_lookup
CIRLOOKY LDX #CCOFF+16
cc_lookup PSHS A
        ANDA #31
        LSRA
        LDB A,X
        PULS A
        BITA #32
        BEQ cc_positive
        CLRA
        NEGA
        NEGB
        SBCA #0
        RTS
cc_positive CLRA
        RTS

; Horizontal spans include both endpoints, with the same XOR overlap rule.
; X already addresses the left endpoint; no per-pixel error accumulator.
ln_horizontal LDA <lx0
        ANDA #7
        LDY #HLFIRST
        LDA A,Y
        STA <mask
        LDA <lx0
        LSRA
        LSRA
        LSRA
        STA <tmp
        LDB <lx1
        LSRB
        LSRB
        LSRB
        SUBB <tmp
        BEQ hl_single
        LDA ,X
        EORA <mask
        STA ,X+
        DECB
        BEQ hl_last
hl_full COM ,X+
        DECB
        BNE hl_full
hl_last LDA #$FF
        STA <mask
hl_single LDA <lx1
        ANDA #7
        LDY #HLLAST
        LDA A,Y
        ANDA <mask
        EORA ,X
        STA ,X
        RTS
HLFIRST FCB $FF,$7F,$3F,$1F,$0F,$07,$03,$01
HLLAST  FCB $80,$C0,$E0,$F0,$F8,$FC,$FE,$FF

; X -> a 24-bit coordinate: carry clear if it fits in its low byte as a signed number
FITS8   LDA 2,X
        ROLA
        LDA #0
        SBCA #0
        CMPA ,X
        BNE dfi_n
        CMPA 1,X
        BNE dfi_n
        ANDCC #$FE
        RTS
dfi_n   ORCC #1
        RTS

; A = signed, |A| <= 96: A = A / 10
DIV10S  PSHS A
        BPL dv_p
        NEGA
dv_p    LDB #205
        MUL
        LSRA
        LSRA
        LSRA
        TST ,S+
        BPL dv_r
        NEGA
dv_r    RTS


        INCLUDE "gen/dash.inc"

; qq19+3 := the economy times the size of the item's factor, from the item's table byte mk+1 (var)
VAR     LDA mk+1
        ANDA #31
        STA mk+2
        LDB qq28
        CLRA
va_l    DECB
        LBMI va_d
        ADDA mk+2
        LBRA va_l
va_d    STA mk+3
        RTS

; the tables of ISQRT16 and NORM3, built once at start-up (in the RAM above $8000):
; RTAB[h] = isqrt(h*256+255);  NTH/NTL[n] = 96*256/n, high and low bytes (n 1..255)
MKTABS  LDX #RTAB
        CLR <tmp2               ; r
        CLR <cnt                ; h
mt_r    LDA <tmp2
        INCA
        BEQ mt_s                ; r = 255 is the largest
        TFR A,B
        MUL                     ; (r+1)^2 <= h*256+255 when its high byte <= h
        CMPA <cnt
        BHI mt_s
        INC <tmp2
        BRA mt_r
mt_s    LDA <tmp2
        STA ,X+
        INC <cnt
        BNE mt_r
        LDA #1
        STA <cnt
mt_n    LDD #24576
        STD <mr+2
        LDD #0
        STD <mr
        STA <md
        LDB <cnt
        STB <md+1
        JSR [perfdiv]           ; resident entry supplied by START after loading this segment
        LDX #NTH
        LDB <cnt
        ABX
        LDD <mr+2
        STA ,X
        STB 256,X
        INC <cnt
        BNE mt_n
        RTS

        INCLUDE "engine/rand.asm"
