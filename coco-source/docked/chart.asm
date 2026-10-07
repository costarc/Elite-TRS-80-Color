; The charts: the Long-range (galactic) Chart (TT22) with every system of the galaxy as a dot
; and the fuel range as a circle, and the Short-range Chart (TT23) with the systems within
; 20 light years, their names and sizes; the crosshairs that choose a system (TT15, TT103,
; TT105), moving them (TT16, TT123), and the nearest system under them (hm).
;
; A system is at (x, y) = (qq15+3, qq15+1), the galaxy being 256 x 256 light years; the long
; chart shows it at x, y / 2 + 24, the short chart at 104 + 4 * dx, 90 + 2 * dy about us. The
; screen is 24 rows of 8 lines as in the original. The crosshairs are drawn with EOR, so they
; come off again by drawing them again.

; ---- pixels ----------------------------------------------------------------------------------------

; OR the pixel at (A, B) into the page being drawn; keeps A, B, X
PLOT    PSHS D,X
        PSHS A
        LDA #32
        MUL                     ; y * 32
        ADDD <back
        TFR D,X
        PULS A
        TFR A,B
        LSRA
        LSRA
        LSRA
        LEAX A,X                ; the byte
        ANDB #7
        LDA #$80
chx_pl_s    TSTB
        LBEQ chx_pl_d
        LSRA
        DECB
        LBRA chx_pl_s
chx_pl_d    ORA ,X
        STA ,X
        PULS D,X
        RTS

; a system's dot: one pixel, or two for the nearer ones (the original's PIXEL: the size byte
; is in zz2: from $90 up a dot, below a dash)
STARDOT LBSR PLOT
        PSHS A
        LDA zz2
        CMPA #$90
        PULS A
        LBHS chx_sd_r
        INCA
        LBEQ chx_sd_r
        LBSR PLOT
chx_sd_r    RTS

; a filled disc of radius zz2 (2 or 3) about (A, B): a system's sun on the short chart
DISC    STA dcx
        STB dcy
        LDA zz2
        STA dcr
        NEGA
        STA dcd                 ; dy from -r to r
chx_dc_l    LDA dcd
        LBPL chx_dc_p
        NEGA
chx_dc_p    TFR A,B
        MUL                     ; dy^2
        STD <tmp
        LDA dcr
        TFR A,B
        MUL                     ; r^2
        SUBD <tmp
        JSR ISQRT16             ; B = the half width of this row
        STB dch
        LDA dcy
        ADDA dcd
        TFR A,B                 ; the row
        LDA dcx
        SUBA dch
        STA dcs
        LDA dch
        ASLA
        INCA
        STA dcn                 ; 2 * half + 1 pixels
chx_dc_r    LDA dcs
        LBSR PLOT
        INC dcs
        DEC dcn
        LBNE chx_dc_r
        INC dcd
        LDA dcd
        CMPA dcr
        LBLE chx_dc_l
        RTS

; ---- lines -----------------------------------------------------------------------------------------

; the crosshairs of half size qq19+2 at (qq19, qq19+1), offset down by 24 lines on the long
; chart (TT15)
TT15    LDA #24
        TST qq11
        LBPL tt15a
        CLRA
tt15a   STA qq19+5
        LDA qq19                ; the horizontal line: x - size .. x + size, clamped
        SUBA qq19+2
        LBHS tt15b
        CLRA
tt15b   STA <lx0
        LDA qq19
        ADDA qq19+2
        LBCC tt15c
        LDA #255
tt15c   STA <lx1
        LDA qq19+1
        ADDA qq19+5
        STA <lx0+1
        STA <lx1+1
        JSR LINE
        LDA qq19+1              ; the vertical line: y - size .. y + size
        SUBA qq19+2
        LBHS tt15d
        CLRA
tt15d   ADDA qq19+5
        STA <lx0+1
        LDA qq19+1
        ADDA qq19+2
        ADDA qq19+5
        CMPA #152
        LBLO tt15e
        TST qq11
        LBMI tt15e
        LDA #151
tt15e   STA <lx1+1
        LDA qq19
        STA <lx0
        STA <lx1
        JMP LINE

; the circle of the fuel range about us (TT14, TT126)
TT14    TST qq11
        LBMI TT126
        LDA qq14
        LSRA
        LSRA
        STA kc                  ; the radius in pixels
        LDA qq0
        STA qq19
        LDA qq1
        LSRA
        STA qq19+1
        LDA #7
        STA qq19+2
        JSR TT15
        LDA qq19+1
        ADDA #24
        STA qq19+1
        LBRA TT128
TT126   LDA #104                ; short chart: about the centre
        STA qq19
        LDA #90
        STA qq19+1
        LDA #16
        STA qq19+2
        JSR TT15
        LDA qq14
        STA kc
; a circle of radius kc about (qq19, qq19+1) from 32 segments (TT128)
TT128   LDA kc
        STA kr
        STA kry
        CLRA
        STA ccn
        LDA #1
        STA cfst
chx_cc_l    LDA ccn
        JSR CIRSIN
        TFR D,X
        CLRA
        LDB qq19
        LEAX D,X
        STX <cx1
        LDA ccn
        ADDA #16
        ANDA #63
        JSR CIRSINY
        TFR D,X
        CLRA
        LDB qq19+1
        LEAX D,X
        STX <cy1
        TST cfst
        LBNE chx_cc_f
        LDD cpvx
        STD <cx0
        LDD cpvy
        STD <cy0
        JSR CLIPLINE
chx_cc_f    CLR cfst
        LDD <cx1
        STD cpvx
        LDD <cy1
        STD cpvy
        LDA ccn
        ADDA #2
        STA ccn
        CMPA #65
        LBLO chx_cc_l
        RTS

; the selected system's crosshairs (TT103, TT105)
TT103   TST qq11
        LBMI TT105
        LDA qq9
        STA qq19
        LDA qq10
        LSRA
        STA qq19+1
        LDA #4
        STA qq19+2
        JMP TT15
TT105   LDA qq9                 ; the short chart: 4 times the distance from us, if in range
        SUBA qq0
        CMPA #38
        LBLO tt105a
        CMPA #230
        LBLO tt105r
tt105a  ASLA
        ASLA
        ADDA #104
        STA qq19
        LDA qq10
        SUBA qq1
        CMPA #38
        LBLO tt105b
        CMPA #220
        LBLO tt105r
tt105b  ASLA
        ADDA #90
        STA qq19+1
        LDA #8
        STA qq19+2
        JMP TT15
tt105r  RTS

; ---- moving the crosshairs -------------------------------------------------------------------------

; A + the signed delta in qq19+3, saturating at 0 and 255: the result in qq19+4 (TT123)
TT123   STA qq19+4
        ADDA qq19+3
        LDB qq19+3
        LBMI t123n
        LBCC t123s               ; a positive delta: no carry, the sum stands
        RTS
t123n   LBCS t123s               ; a negative delta: a carry means we did not go below 0
        RTS
t123s   STA qq19+4
        RTS

; move the crosshairs by (A, B) = (dx, dy), signed (TT16)
TT16    PSHS D
        JSR TT103
        PULS D
        STB cdy
        STA qq19+3
        LDA qq9
        LBSR TT123
        LDA qq19+4
        STA qq9
        LDA cdy
        STA qq19+3
        LDA qq10
        LBSR TT123
        LDA qq19+4
        STA qq10
        JMP TT103

; our position as the selected one (ping)
ping    LDA qq0
        STA qq9
        LDA qq1
        STA qq10
        RTS

; the nearest system to the crosshairs becomes the selected one (hm)
hm      JSR TT103
        JSR TT111
        JSR TT103
        JMP CLYNS

; the name and distance of the nearest system, at the bottom (T95)
T95     JSR hm
        CLR qq17
        JSR cpl
        LDA #$80
        STA qq17
        LDA #1
        STA xc
        INC yc
        JMP TT146

; ---- the long-range chart -------------------------------------------------------------------------------

TT22    LDA #64
        JSR TT66
        LDA #7
        STA xc
        JSR TT81
        LDA #199
        JSR TT27
        JSR NLIN
        LDA #152
        JSR NLIN2
        JSR TT14
        CLR sysn
t83     LDA qq15+4
        ORA #$50
        STA zz2
        LDA qq15+1
        LSRA
        ADDA #24
        TFR A,B
        LDA qq15+3
        JSR STARDOT
        JSR TT20
        INC sysn
        LBNE t83
        LDA qq9
        STA qq19
        LDA qq10
        LSRA
        STA qq19+1
        LDA #4
        STA qq19+2
        JMP TT15

; ---- the short-range chart ------------------------------------------------------------------------------

TT23    LDA #128
        JSR TT66
        LDA #7
        STA xc
        LDA #190
        JSR NLIN3
        JSR TT14
        JSR TT103
        JSR TT81
        CLR sysn
        LDX #chartocc           ; no names yet on any row
        LDB #26
tt23z   CLR ,X+
        DECB
        LBNE tt23z
t182    LDA qq15+3
        SUBA qq0
        LBHS t184
        NEGA
t184    CMPA #20
        LBHS t187
        LDA qq15+1
        SUBA qq1
        LBHS t186
        NEGA
t186    CMPA #38
        LBHS t187
        LDA qq15+3              ; its place: 104 + 4 dx
        SUBA qq0
        ASLA
        ASLA
        ADDA #104
        STA tx12
        LSRA
        LSRA
        LSRA
        STA xc
        INC xc
        LDA qq15+1              ; 90 + 2 dy
        SUBA qq1
        ASLA
        ADDA #90
        STA ty
        LSRA
        LSRA
        LSRA
        TFR A,B                 ; the row of its name
        LDX #chartocc
        ABX
        LDA ,X
        LBEQ ee4
        LDA 1,X
        LBEQ ee4x
        LDA -1,X
        LBNE ee1
        DECB
        LBRA ee4
ee4x    INCB
ee4     STB yc
        CMPB #3
        LBLO t187
        LDX #chartocc
        ABX
        LDA #$FF
        STA ,X
        LDA #$80
        STA qq17
        JSR cpl
ee1     LDA qq15+5              ; its sun: a disc of radius 2 or 3
        ANDA #1
        ADDA #2
        STA zz2
        LDA tx12
        LDB ty
        JSR DISC
t187    JSR TT20
        INC sysn
        LBNE t182
        RTS

; ---- find a system by name (HME2, the F key on a chart) ------------------------------------------

; "PLANET NAME?", then through the 256 systems of the galaxy for that name; the crosshairs go to
; the one found, or UNKNOWN PLANET
HME2    LDA #14                 ; (clears the bottom of the screen, reads the line into inwk+5)
        JSR DETOK
        JSR TT103               ; (the crosshairs come off)
        JSR TT81                ; system 0's seeds
        CLR sysn
hme3    JSR MT14                ; the name into the buffer of justified text
        LDA #$80                ; (all in lower case, as the typed name is made)
        STA qq17
        JSR cpl
        LDX #buf
        LDB dtw5
        ABX
        LDX #inwk+5
        LDB dtw5
        ABX
        LDA ,X                  ; the typed name must end where this one does
        CMPA #13
        BNE hme6
        LDB dtw5
hme4    DECB
        LBMI hme5
        LDX #inwk+5
        ABX
        LDA ,X
        ORA #$20
        LDX #buf
        ABX
        PSHS A
        LDA ,X
        ORA #$20                ; (the name's first letter is a capital)
        CMPA ,S+
        BEQ hme4
hme6    JSR TT20
        INC sysn
        BNE hme3
        JSR TT111               ; nothing found: the crosshairs where they were
        JSR TT103
        LDA #40
        JSR NOISE
        JSR MT15                ; (justified text off)
        LDA #215
        JMP DETOK
hme5    LDA qq15+3
        STA qq9
        LDA qq15+1
        STA qq10
        JSR TT111
        JSR TT103
        JSR MT15
        JMP T95
