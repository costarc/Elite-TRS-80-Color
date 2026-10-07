; The ship hangar (HALL): after the docking tunnel, a hangar with one or three ships standing
; on the floor: a back wall of 15 vertical lines, a floor of 11 horizontal lines in
; perspective that stop where a ship (or an earlier line) is in the way. It is shown for
; a moment before the docked screens (the original's DOENTRY). It runs with the ship blueprints
; still in, from the flight side, and draws on the page that is not shown, then shows it.

; the seven hangar ships (types 1-7 of HAS1): canister, shuttle, transporter, Cobra Mk III,
; python, viper, krait
HANGTAB FDB SHIP_CANISTER,SHIP_SHUTTLE,SHIP_TRANSPORTER,SHIP_COBRA_MK_3,SHIP_PYTHON,SHIP_VIPER,SHIP_KRAIT

; the groups of three ships: type, x_lo (bit 0 also adds to z_hi), z_lo (bit 0 the sign of x)
HATB    FCB 2,%01010100,%00111011       ; a shuttle and a transporter
        FCB 3,%10000010,%10110000
        FCB 0,0,0
        FCB 1,%01010000,%00010001       ; three cargo canisters
        FCB 1,%11010001,%00101000
        FCB 1,%01000000,%00000110
        FCB 3,%01100000,%10010000       ; a transporter and a Cobra Mk III
        FCB 4,%00010000,%11010001
        FCB 0,0,0
        FCB 6,%01010001,%11111000       ; a viper and a krait
        FCB 7,%01100000,%01110101
        FCB 0,0,0

HALL    LDD #96                 ; the whole screen is the view
        STD <cyv
        LDD #191
        STD <ymx
        CLRA
        JSR TT66                ; clear the page, the box
        JSR DORND
        BPL ha_7
        ANDA #3                 ; a group of three: 9 * (0-3)
        LDB #9
        MUL
        LDX #HATB
        ABX
        LDA #3
        STA hcnt
ha_8    LDA ,X+                 ; XX15+2 = the type, XX15+1 = x_lo, XX15 = z_lo
        STA xx15+2
        LDA ,X+
        STA xx15+1
        LDA ,X+
        STA xx15
        PSHS X
        BSR HAS1
        PULS X
        DEC hcnt
        BNE ha_8
        LDA #$80                ; (ships between the lines too)
        BRA ha_9
ha_7    LSRA                    ; one ship: x_lo 0-63, z_lo and the sign at random, a type 0-7
        STA xx15+1
        JSR DORND
        STA xx15
        JSR DORND
        ANDA #7
        STA xx15+2
        BSR HAS1
        CLRA
ha_9    STA hmul
        JSR HANGER
        JSR FLIP
        LDA #44                 ; shown for 44 fiftieths of a second
ha_d    STA hcnt
        JSR WAITVS
        LDA hcnt
        DECA
        BNE ha_d
        RTS

; one ship of the hangar from xx15 (HAS1): placed, spun to a random heading, drawn
HAS1    JSR ZINF
        LDA xx15                ; z_lo
        STA inwk+8
        LDB xx15+1              ; x_lo: x = + or - it, the sign from bit 0 of z_lo
        CLRA
        LSR xx15
        BCC ha_xp
        NEGB                    ; (x_lo is not 0 for the ships that are drawn: -x_lo = $FFxx)
        LDA #$FF
        TSTB
        BNE ha_xs
        CLRA
ha_xs   STA inwk
        STA inwk+1
        BRA ha_xz
ha_xp   CLRA
        STA inwk
        STA inwk+1
ha_xz   STB inwk+2
        LDA xx15+1              ; z_hi = 1 + bit 0 of x_lo
        ANDA #1
        INCA
        STA inwk+7
        LDA #$FF                ; y is negative: a ship stands on the floor
        STA inwk+3
        STA inwk+4
        JSR DORND               ; a random number of small turns about the vertical
        STA tt2
ha_y    LDX #SIDEV
        LDY #NOSEV
        JSR ROT2
        LDX #SIDEV+2
        LDY #NOSEV+2
        JSR ROT2
        LDX #SIDEV+4
        LDY #NOSEV+4
        JSR ROT2
        DEC tt2
        BNE ha_y
        LDB xx15+2              ; no ship (type 0)
        BEQ ha_r
        DECB
        ASLB
        LDX #HANGTAB
        ABX
        LDX ,X
        STX <bp
        LDD 1,X                 ; the targetable area: y = (100 - sqrt(area)) / 2 below the middle
        JSR ISQRT16
        TFR B,A
        LDB #100
        PSHS A
        SUBB ,S+
        LSRB
        NEGB
        STB inwk+5
        JSR TIDY
        LDD #200
        STD <work
        JMP LL9
ha_r    RTS

; the background (HANGER): the floor lines from the edges (and from the middle when there are
; several ships), then the wall
HANGER  LDA #2
        STA hlin
hg_f    LDA #130                ; the line is 130 / n below the middle (n = 2 .. 12)
        LDB hlin
        JSR DIV8
        ADDA #96
        STA hrow
        CLRB                    ; from the left edge to the right
        JSR HGLINE
        LDB #255
        JSR HGLINEL
        TST hmul
        BEQ hg_n
        LDB #128                ; and from the middle both ways
        JSR HGLINE
        LDB #127
        JSR HGLINEL
hg_n    INC hlin
        LDA hlin
        CMPA #13
        BLO hg_f
        LDA #16                 ; the wall: 15 lines from the top down to the first lit pixel
hg_w    STA hx
        LDB #1
        STB hrow
hg_v    JSR HPIX
        BCS hg_x
        INC hrow
        LDA hrow
        BNE hg_v
hg_x    LDA hx
        ADDA #16
        BNE hg_w
        RTS

; A = A / B (unsigned, the quotient)
DIV8    PSHS B
        CLRB
        STB tt1
dv8_l   CMPA ,S
        BLO dv8_x
        SUBA ,S
        INC tt1
        BRA dv8_l
dv8_x   LEAS 1,S
        LDA tt1
        RTS

; the pixel (hx, hrow): carry clear and the pixel now set if it was clear, else carry set
HPIX    LDA hrow
        LDB #32
        MUL
        ADDD <back
        TFR D,X
        LDA hx
        LSRA
        LSRA
        LSRA
        LEAX A,X
        LDA hx
        ANDA #7
        LDB #$80
        TSTA
        BEQ hgp_m
hgp_s    LSRB
        DECA
        BNE hgp_s
hgp_m    LDA ,X
        PSHS B
        BITA ,S
        BNE hgp_lit
        ORA ,S+
        STA ,X
        ANDCC #$FE
        RTS
hgp_lit  LEAS 1,S
        ORCC #1
        RTS

; a floor line along hrow from x = B rightwards / leftwards until a pixel is lit
HGLINE   STB hx
hgl_r    JSR HPIX
        BCS hgl_x
        INC hx
        BNE hgl_r
hgl_x    RTS
HGLINEL  STB hx
hgl_l    JSR HPIX
        BCS hgl_x
        DEC hx
        LDA hx
        CMPA #255
        BNE hgl_l
        RTS
