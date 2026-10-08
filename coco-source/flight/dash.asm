; The dashboard: the rows below the 3D view (DASHY..), 42 rows of the original's art
; (tools/dash.py, in the DASH segment: DASHIMG and SCANIMG) with the live parts drawn on
; top of it every frame, into the page being drawn:
;
;   the scanner   (the original SCAN) the ships as dots on sticks over the ellipse; the
;                 area is restored from the art first, so nothing has to be erased
;   the gauges    (DIL, DIL2, DILX) bars on the left and right: a bar is 4 bytes, a
;                 pixel being 2 screen pixels, and a marker is one pixel
;
; Coordinates are the original's, the scanner ellipse being centred on x = 123 and the
; vertical ones scaled 3/4 into the 42 rows.

DASHY   EQU VIEWH

; ---- once: the art into both pages --------------------------------------------------
DASHPAGE
        LDD <back
        ADDD #DASHY*32
        TFR D,X
        LDU #DASHIMG
        LDY #42*16
ddp_c    LDD ,U++
        STD ,X++
        LEAY -1,Y
        BNE ddp_c
        IFNE 192-DASHY-42
        LDD #0
        LDY #(192-DASHY-42)*16
ddp_z    STD ,X++
        LEAY -1,Y
        BNE ddp_z
        ENDC
        RTS

DASHINIT
        LDX #gcache
        LDB #26
        LDA #$FF
ddi_gc  STA ,X+
        DECB
        BNE ddi_gc
        CLR cpvalid
        LDX #scdirty
        LDB #12
        LDA #$FF
ddi_sc  STA ,X+
        DECB
        BNE ddi_sc
        LDD <back
        PSHS D
        LDD #$8000
        STD <back
        JSR DASHPAGE
        LDD #$9800
        STD <back
        JSR DASHPAGE
        PULS D
        STD <back
        RTS

; ---- every frame -------------------------------------------------------------------
DASHFRAME
        JSR SCANRESTORE
        JSR SCANSHIPS
        IFNDEF NOCOMPAS         ; test: no compass dot
        JSR COMPAS
        ENDC
        JMP GAUGES

; The scanner area (byte columns 6..25 of every dashboard row) back from the art. PULU
; reads the art upwards and PSHS writes the screen downwards, so the art keeps each row's
; three chunks in reverse order; interrupts are off while S is a data pointer.
SCANRESTORE
        LDX #scdirty
        LDA <back
        CMPA #$80
        BEQ dsr_page
        LEAX 6,X
dsr_page STX scptr
        CLR scrow
        STS <savs
        ORCC #$10
        LDU #SCANIMG
        LDD <back
        ADDD #DASHY*32+26
        TFR D,S
dsr_band LDA scrow
        LDX scptr
        TST A,X
        BEQ dsr_skipband
        LDA #8
        LDB scrow
        CMPB #5
        BNE dsr_count
        LDA #2                  ; final band: only dashboard rows 40 and 41
dsr_count STA sclines
dsr_copy PULU A,B,DP,X,Y
        PSHS A,B,DP,X,Y
        PULU A,B,DP,X,Y
        PSHS A,B,DP,X,Y
        PULU A,B,X,Y
        PSHS A,B,X,Y
        LEAS 52,S
        DEC sclines             ; extended: PULU has changed DP
        BNE dsr_copy
        BRA dsr_nextband
dsr_skipband LDA scrow
        CMPA #5
        BEQ dsr_skiplast
        LEAU 8*20,U
        LEAS 8*32,S
        BRA dsr_nextband
dsr_skiplast LEAU 2*20,U
        LEAS 2*32,S
dsr_nextband INC scrow
        LDA scrow
        CMPA #6
        BNE dsr_band
        LDA #2
        TFR A,DP
        LDS <savs
        ANDCC #$EF
        LDX scptr
        CLRA
        CLRB
        STD ,X
        STD 2,X
        STD 4,X
        RTS

; Mark inclusive dashboard rows A..B on the page being drawn.
; Six 8-row bands cover the scanner, including its last two rows.
SCMARK  PSHS D,X
        LSRA
        LSRA
        LSRA
        LSRB
        LSRB
        LSRB
        PSHS B
        LDX scptr
        LDB #$FF
dsm_l   STB A,X
        INCA
        CMPA ,S
        BLS dsm_l
        LEAS 1,S
        PULS D,X,PC

; X -> a 24-bit coordinate: A = its middle byte, if the coordinate is within -64..63
; (the original's "x_hi, y_hi and z_hi all less than 64"): carry clear; else carry set
SCCOORD LDA 1,X
        ADDA #64
        BMI dsc_bad
        LDA 1,X
        ROLA                    ; the sign into carry: A := the sign extension
        LDA #0
        SBCA #0
        CMPA ,X
        BNE dsc_bad
        LDA 1,X
        ANDCC #$FE
        RTS
dsc_bad  ORCC #1
        RTS

; every ship (not the planet or the sun) near enough, as a dot on a stick (SCAN)
SCANSHIPS
        CLR <slotn
dsc_l    LDA <slotn
        JSR SLOTADDR
        LDA 34,X
        LBMI dsc_n              ; planet, sun or an empty slot
        TFR X,U
        JSR SCCOORD             ; x: the dot's pixel, 123 + x_hi
        LBCS dsc_n
        ADDA #123
        STA dtx
        LEAX 3,U
        JSR SCCOORD             ; y: the stick's length, -y_hi / 2
        LBCS dsc_n
        ASRA
        NEGA
        PSHS A
        LEAX 6,U
        JSR SCCOORD             ; z: the base of the stick, 220 - z_hi / 4
        LBCS dsc_p
        ASRA
        ASRA
        NEGA
        ADDA #220
        STA dtb
        LDB ,S                  ; the dot: base + length, kept within 194..246
        BMI dsc_g
        ADDA ,S
        BCS dsc_h
        BRA dsc_c
dsc_g    ADDA ,S                 ; (a negative length: the carry is always set)
dsc_c    CMPA #194
        BHS dsc_d
        LDA #194
dsc_d    CMPA #247
        BLO dsc_e
dsc_h    LDA #246
dsc_e    SUBA #192               ; to dashboard rows, 3/4 of the lines
        STA dtr
        ASLA
        ADDA dtr
        LSRA
        LSRA
        STA dtr
        LDA dtb
        SUBA #192
        STA dtb
        ASLA
        ADDA dtb
        LSRA
        LSRA
        STA dtb
        LDA dtr
        DECA
        LDB dtr
        INCB                    ; pulse can occupy dot-1..dot+1
        CMPA dtb
        BLS dsc_min
        LDA dtb
dsc_min CMPB dtb
        BHS dsc_max
        LDB dtb
dsc_max JSR SCMARK
        LDA dtr                ; the stick: the rows between its base and the dot
        LDB dtb
        CMPA dtb
        BHS dsc_k
        EXG A,B
dsc_k    PSHS B                  ; A = last row, B = first row
        SUBA ,S
        INCA
        STA <cnt
        PULS A
        LDB #32
        MUL
        ADDD <back
        ADDD #DASHY*32
        TFR D,X
        LDA dtx
        LSRA
        INCA                    ; its pixel: the right one of the dot
        TFR A,B
        LSRA
        LSRA
        LEAX A,X
        ANDB #3
        LDY #STKMASK
        LDB B,Y
        STB dtm
dsc_s    LDA dtm
        ORA ,X
        STA ,X
        LEAX 32,X
        DEC <cnt
        BNE dsc_s
        LDY #DOTMASK            ; ordinary contact: four pixels by two rows
        LDA dtx
        TST 36,U                ; recently fired at us (even outside the 3D view)
        BEQ dsc_dot
        COM 37,U                ; alternate size each scanner redraw; no clock aliasing
        BPL dsc_dot
        SUBA #2                 ; centre the eight-pixel pulse around the normal dot
        LDY #ATTACKMASK
dsc_dot PSHS A
        LDA dtr
        DECA
        LDB #32
        MUL
        ADDD <back
        ADDD #DASHY*32
        TFR D,X
        PULS A
        LSRA
        TFR A,B
        ANDB #3
        ASLB
        LSRA
        LSRA
        LEAX A,X
        LDD B,Y
        TFR D,Y
        ORA ,X
        ORB 1,X
        STD ,X
        TFR Y,D
        ORA 32,X
        ORB 33,X
        STD 32,X
        TST 36,U
        BEQ dsc_p
        TST 37,U
        BPL dsc_p
        TFR Y,D                 ; pulse is three rows high
        ORA 64,X
        ORB 65,X
        STD 64,X
dsc_p    LEAS 1,S
dsc_n    INC <slotn
        LDA <slotn
        CMPA #NSLOTS
        LBLO dsc_l
        RTS

ATTACKMASK FDB $FF00,$3FC0,$0FF0,$03FC

; ---- the gauges --------------------------------------------------------------------
; X = the bar's first byte, A = its length in pixels (up to 16)
CBAR    CMPA ,U+
        BEQ dbr_done
        STA -1,U
BAR     CMPA #16
        BLS dbr_a
        LDA #16
dbr_a    ASLA
        ASLA
        LDY #BARTAB
        LEAY A,Y
        LDD ,Y
        STD ,X
        STD 32,X
        LDD 2,Y
        STD 2,X
        STD 34,X
dbr_done RTS

; X = the marker's first byte, A = its position 0-15
CMARK   CMPA ,U+
        BEQ dmk_done
        STA -1,U
MARK    ASLA
        ASLA
        LDY #MARKTAB
        LEAY A,Y
        LDD ,Y
        STD ,X
        STD 32,X
        STD 64,X
        LDD 2,Y
        STD 2,X
        STD 34,X
        STD 66,X
dmk_done RTS

; a bar in the dashboard's character row \1 (6 rows of 8 lines), byte column \2
GBAR    MACRO
        LDX <back
        LEAX 32*(DASHY+6*\1+2)+\2,X
        JSR CBAR
        ENDM

GMARK   MACRO
        LDX <back
        LEAX 32*(DASHY+6*\1+1)+\2,X
        JSR CMARK
        ENDM

GAUGES  LDU #gcache
        LDA <back
        CMPA #$80
        BEQ dgc_page
        LEAU 13,U
dgc_page LDX scptr
        LDA #$FF                ; scanner restore includes both bulbs, rows 30..34
        STA 3,X
        STA 4,X
        LDA fsh                ; the left side: shields, fuel, temperatures, altitude
        LSRA
        LSRA
        LSRA
        LSRA
        GBAR 0,2
        LDA ash
        LSRA
        LSRA
        LSRA
        LSRA
        GBAR 1,2
        LDA qq14
        LSRA
        LSRA
        GBAR 2,2
        LDA cabtmp
        LSRA
        LSRA
        LSRA
        LSRA
        GBAR 3,2
        LDA gntmp
        LSRA
        LSRA
        LSRA
        LSRA
        GBAR 4,2
        LDA altit
        LSRA
        LSRA
        LSRA
        LSRA
        GBAR 5,2
        LDA <delta              ; the right side: speed
        LSRA
        GBAR 0,26
        LDA <alpha              ; roll: 8 - alpha/4
        BMI dgr_n
        LSRA
        LSRA
        NEGA
        BRA dgr_s
dgr_n    NEGA
        LSRA
        LSRA
dgr_s    ADDA #8
        GMARK 1,26
        LDA <beta               ; pitch: 8 + beta, a step less when pitching
        BEQ dgp_s
        BMI dgp_n
        DECA
        BRA dgp_s
dgp_n    INCA
dgp_s    ADDA #8
        GMARK 2,26
        LDA energy             ; the energy banks, bottom up (energy / 4 = 0-63)
        LSRA
        LSRA
        LDX #bank+4
        LDY #4
dgb_l    TFR A,B
        CMPB #16
        BLS dgb_s
        LDB #16
dgb_s    STB ,-X
        PSHS B
        SUBA ,S+
        LEAY -1,Y
        BNE dgb_l
        LDA bank
        GBAR 3,26
        LDA bank+1
        GBAR 4,26
        LDA bank+2
        GBAR 5,26
        LDA bank+3
        GBAR 6,26
        LDA nomsl               ; the missile indicators (MSBAR): 3 of 4 pixels wide, a gap
        ASLA                    ; between, in the bottom row of the dashboard at byte columns
        ASLA                    ; 2-5, the first missile at the right
        LDY #MSLTAB
        LEAY A,Y
        LDX <back
        LEAX 32*(DASHY+37)+2,X
        LDD ,Y
        STD ,X
        STD 32,X
        STD 64,X
        STD 96,X
        LDD 2,Y
        STD 2,X
        STD 34,X
        STD 66,X
        STD 98,X
        LDY #BULBOFF            ; the E.C.M. bulb (E) and the space station bulb (S)
        LDA bulbs
        BITA #1
        BEQ gb_e
        LDY #BULBE
gb_e    LDX <back
        LEAX 32*(DASHY+30)+7,X
        JSR BULB
        LDY #BULBOFF
        LDA bulbs
        BITA #2
        BEQ gb_s
        LDY #BULBS
gb_s    LDX <back
        LEAX 32*(DASHY+30)+24,X
BULB    LDA ,Y+                 ; 5 rows
        STA ,X
        LDA ,Y+
        STA 32,X
        LDA ,Y+
        STA 64,X
        LDA ,Y+
        STA 96,X
        LDA ,Y
        STA 128,X
        RTS

MSLTAB  FCB 0,0,0,0
        FCB 0,0,0,$FC
        FCB 0,0,$FC,$FC
        FCB 0,$FC,$FC,$FC
        FCB $FC,$FC,$FC,$FC
BULBOFF FCB 0,0,0,0,0
BULBE   FCB $FC,$C0,$FC,$C0,$FC
BULBS   FCB $FC,$C0,$FC,$0C,$FC

; ---- the compass (COMPAS, SP1/SP2, TAS2, NORM) ------------------------------------
; The planet's direction as a dot in the little ellipse: centre (195, 204), the planet's
; vector scaled to length 96 and divided by 10; a 2 row dot when it is in front of us, one
; row when it is behind.

; the dot's two pixels on dashboard row A, x pixel dtx
DOTROW  TFR A,B
        JSR SCMARK
        LDB #32
        MUL
        ADDD <back
        ADDD #DASHY*32
        TFR D,X
        LDA dtx
        LSRA
        TFR A,B
        ANDB #3
        ASLB
        LSRA
        LSRA
        LEAX A,X
        LDY #DOTMASK
        LDD B,Y
        ORA ,X
        ORB 1,X
        STD ,X
        RTS

COMPAS  LDA #TY_PLANET          ; the planet, or the station when we are near it
        TST sspr
        BEQ cp_w
        LDA #TY_SST
cp_w    STA tt2
        CLR <slotn
cp_f    LDA <slotn
        JSR SLOTADDR
        LDA 34,X
        CMPA #TY_SST
        BEQ cp_s
        ANDA #$FD               ; the planet is type 128, or 130 (a crater) with some technology levels
cp_s    CMPA tt2
        BEQ cp_g
cp_n    INC <slotn
        LDA <slotn
        CMPA #NSLOTS
        BLO cp_f
        RTS
cp_g    TST cpvalid
        BEQ cp_copy
        PSHS X
        LDY #cpkey
        LDB #9
cp_cmp  LDA ,X+
        CMPA ,Y+
        BNE cp_miss
        DECB
        BNE cp_cmp
        PULS X
        LBRA cp_plot
cp_miss PULS X
cp_copy CLR cpvalid
        LDU #cv                 ; copy the exact key and working vector in one pass
        LDY #cpkey
        LDB #9
cp_c    LDA ,X+
        STA ,U+
        STA ,Y+
        DECB
        BNE cp_c
cp_a    LDX #cv
        JSR FITS8
        BCS cp_r
        LDX #cv+3
        JSR FITS8
        BCS cp_r
        LDX #cv+6
        JSR FITS8
        BCC cp_b
cp_r    ASR cv
        ROR cv+1
        ROR cv+2
        ASR cv+3
        ROR cv+4
        ROR cv+5
        ASR cv+6
        ROR cv+7
        ROR cv+8
        BRA cp_a
cp_b    LDA cv+2
        ORA cv+5
        ORA cv+8
        BEQ cp_x                ; no direction
        LDA cv+2
        ADDA #64
        BMI cp_d
        LDA cv+5
        ADDA #64
        BMI cp_d
        LDA cv+8
        ADDA #64
        BMI cp_d
        ASL cv+2                ; room to spare: the largest at least 64
        ASL cv+5
        ASL cv+8
        BRA cp_b
cp_d    LDA cv+2
        STA cvb
        LDA cv+5
        STA cvb+1
        LDA cv+8
        STA cvb+2
        LDX #cvb
        JSR NORM3               ; length 96
        INC cpvalid
cp_plot LDA cvb
        JSR DIV10S
        ADDA #195
        STA dtx
        LDA cvb+1
        JSR DIV10S
        PSHS A
        LDA #204-192
        SUBA ,S+                ; line in the dashboard, to rows: 3/4
        STA <tmp
        ASLA
        ADDA <tmp
        LSRA
        LSRA
        STA <tmp
        TST cvb+2
        BMI cp_k
        LDA <tmp
        DECA
        JSR DOTROW
cp_k    LDA <tmp
        JMP DOTROW
cp_x    RTS
