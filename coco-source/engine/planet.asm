; Planets (original PLANET / PROJ / CIRCLE / CIRCLE2 / BLINE), first part: the
; planet's disc. The planet record sits in a slot with type 128; its position is
; 24 bits (the original z_sign:z_hi:z_lo), moved by MVPLAN.
;
;   * not drawn when behind us, z >= 48*65536, or z < 256
;   * centre = 128 + 256*x/z, 96 - 256*y/z (z reduced to 15 bits first)
;   * radius K = 256 * 24576 / z pixels (original DVID3B2 returns 256*N/z)
;   * circle of 64/STP segments from the sine table SNE: STP 8 (K<8), 4 (K<60),
;     else 2; each segment goes through the clipper

; z normalisation shared with LL9's perspective: D = z (>= 256) -> <ps, <pu
ZNORM   CLR <ps
zn_l    TSTA
        BMI zn_d
        ASLB
        ROLA
        INC <ps
        BRA zn_l
zn_d    TFR A,B
        CLRA
        LDX #RECIPU-128
        LDB D,X
        STB <pu
        RTS

; Project the planet at inwk into <pcx,<pcy and its radius into <kr.
; Carry set when it is not to be drawn.
PLANPROJ
        LDA inwk+6
        LBMI pj_no               ; behind us
        CMPA #48
        LBHS pj_no               ; too far
        ORA inwk+7
        LBEQ pj_no               ; closer than 256: too close to show
        LDX #inwk               ; copy x,y,z; shrink all axes together until they fit
        LDU #ppos
        LDY #9
pj_c    LDA ,X+
        STA ,U+
        LEAY -1,Y
        BNE pj_c
        CLR prs
pj_s    LDA ppos+6
        BNE pj_sh
        LDA ppos+7
        BMI pj_sh
        ; x and y must also fit signed 16 bits. Saturating either axis alone
        ; changes its ratio to z and can bring an off-screen planet back.
        ; The top two bytes fit iff adding $0080 leaves the high byte zero.
        LDD ppos
        ADDD #$0080
        TSTA
        BNE pj_sh
        LDD ppos+3
        ADDD #$0080
        TSTA
        BEQ pj_ok
pj_sh   INC prs
        LDX #ppos
        ASR ,X
        ROR 1,X
        ROR 2,X
        LDX #ppos+3
        ASR ,X
        ROR 1,X
        ROR 2,X
        LDX #ppos+6
        ASR ,X
        ROR 1,X
        ROR 2,X
        BRA pj_s
pj_ok   LDA ppos+7              ; extreme off-axis positions can shrink z below 256
        LBEQ pj_no               ; their projected centre is far outside the capped disc
        LDD ppos+7              ; Zt
        JSR ZNORM
        LDD ppos+1             ; x: already fits signed 16 bits
        JSR PERSP
        ADDD #128
        STD pcx
        LDD ppos+4             ; y: already fits signed 16 bits
        JSR PERSP
        JSR SC34                ; y scale 3/4
        JSR NEGD
        ADDD #CY
        STD pcy
        LDD ppos+7              ; use the same jointly scaled z as the projection
        STD <md
        LDD #$0060              ; original projected radius: $600000 / z
        STD <mr
        CLR <mr+2
        CLR <mr+3
        LDB prs                 ; shrink the numerator along with the denominator
        BEQ pj_div
pj_ks   LSR <mr
        ROR <mr+1
        ROR <mr+2
        ROR <mr+3
        DECB
        BNE pj_ks
pj_div  JSR DIV32
        LDD <mr+2
        CLR <pbig
        TSTA
        BEQ pj_radius
        INC <pbig
        LDB #248                ; original PLANET caps radii of 256 or more
pj_radius
        STB kr
        CLRA
        JSR SC34                ; radius is unsigned; SC34A wraps for K >= 128
        STB kry
        ANDCC #$FE
        RTS
pj_no   ORCC #1
        RTS

; draw one segment from the previous circle point to (<cx1,<cy1) and remember it.
; When both ends are inside the viewport (nearly always) it goes straight to LINE
; with the low bytes; otherwise through the clipper.
CIRSEG  CLR pnin
        LDD <cx1
        TSTA
        BNE cs_o1
        CMPB #XMIN
        BLO cs_o1
        CMPB #XMAX
        BHI cs_o1
        LDD <cy1
        TSTA
        BNE cs_o1
        CMPB #YMIN
        BLO cs_o1
        CMPB #YMAX
        BLS cs_in
cs_o1   INC pnin
cs_in   TST pfst
        BNE cs_first
        LDA pin
        ORA pnin
        BNE cs_clip
        LDA pvx+1
        STA <lx0
        LDA pvy+1
        STA <ly0
        LDA <cx1+1
        STA <lx1
        LDA <cy1+1
        STA <ly1
        JSR LINE
        BRA cs_first
cs_clip LDD pvx
        STD <cx0
        LDD pvy
        STD <cy0
        LDD <cy1                ; (CLIPLINE moves the end points onto the view's edge: the
        PSHS D                  ; next segment starts from the point itself, not from there)
        LDD <cx1
        PSHS D
        JSR CLIPLINE
        PULS D
        STD <cx1
        PULS D
        STD <cy1
cs_first
        CLR pfst
        LDD <cx1
        STD pvx
        LDD <cy1
        STD pvy
        LDA pnin
        STA pin
        RTS

; point at circle counter A (0..63): (K*sin, K*cos) offsets in D / <tmp2
; D = K * sin(A) as signed 16
CIRSIN  PSHS A
        ANDA #31
        LDX #SNE
        LDB A,X
        LDA kr
        MUL
        TFR A,B                 ; K * sin / 256
        PULS A
        BITA #32
        BEQ cr_p
        CLRA
        JMP NEGD
cr_p    CLRA
        RTS

; the same with the vertical radius <kry
CIRSINY PSHS A
        ANDA #31
        LDX #SNE
        LDB A,X
        LDA kry
        MUL
        TFR A,B
        PULS A
        BITA #32
        BEQ cy_p
        CLRA
        JMP NEGD
cy_p    CLRA
        RTS

; Carry set if the circle of radius <kr about (pcx,pcy) is entirely off screen
; (the original CHKON, against the viewport 0..255 x 0..191).
CHKON   LDD pcx
        PSHS D
        CLRA
        LDB kr
        STD <tmp
        PULS D
        ADDD <tmp
        BMI ck_off              ; right edge left of the screen
        LDD pcx
        SUBD <tmp
        CMPD #255
        BGT ck_off              ; left edge right of the screen
        CLRA
        LDB kry                 ; the vertical radius for the top and bottom
        STD <tmp
        LDD pcy
        ADDD <tmp
        BMI ck_off
        LDD pcy
        SUBD <tmp
        CMPD #YMAX
        BGT ck_off
        ANDCC #$FE
        RTS
ck_off  ORCC #1
        RTS

; Draw the circle of radius <kr about (pcx,pcy). Carry set if it is off screen.
CIRCLE  JSR CHKON
        BCS ci_off
        JSR CIRCACHE
        LDA #8                  ; step: bigger circles get finer polygons
        LDB kr
        CMPB #8
        BLO ci_s
        LDA #4
        CMPB #60
        BLO ci_s
        LDA #2
ci_s    STA pstp
        LDA #1
        STA pfst
        CLR ccn
        TST ccvalid
        BNE ci_cached
ci_l    LDA ccn                 ; x = cx + K sin
        JSR CIRSIN
        ADDD pcx
        STD <cx1
        LDA ccn                 ; y = cy + 3/4 K cos  (cos = sin shifted by 16)
        ADDA #16
        ANDA #63
        JSR CIRSINY
        ADDD pcy
        STD <cy1
        JSR CIRSEG
        LDA ccn
        ADDA pstp
        STA ccn
        CMPA #65
        BLO ci_l
        ANDCC #$FE
        RTS
ci_cached LDA ccn                 ; x = cx + K sin
        JSR CIRLOOK
        ADDD pcx
        STD <cx1
        LDA ccn                 ; y = cy + 3/4 K cos  (cos = sin shifted by 16)
        ADDA #16
        ANDA #63
        JSR CIRLOOKY
        ADDD pcy
        STD <cy1
        JSR CIRSEG
        LDA ccn
        ADDA pstp
        STA ccn
        CMPA #65
        BLO ci_cached
        ANDCC #$FE
        RTS
ci_off  ORCC #1
        RTS

; D = scale * sin(counter A / 64 turn) / 256 for a signed 8-bit scale in B
SINSC   STB <mq
        PSHS A
        ANDA #31
        LDX #SNE
        LDB A,X
        LDA <mq
        BPL ss_a
        NEGA
ss_a    MUL
        TFR A,B
        PULS A
        ASLA                    ; bit 5 of the counter = second half = negative
        ASLA
        EORA <mq
        BPL ss_p
        CLRA
        JMP NEGD
ss_p    CLRA
        RTS

; D = signed orientation component A * radius / 96. Preserve X.
; Divide the unsigned 16-bit product by 96 in eight restoring steps; the
; quotient fits a byte, but its signed result needs 16 bits at large radii.
SCALEK  STA <sgnt
        BPL sk_p
        NEGA
sk_p    LDB <kr
        MUL
        PSHS X
        LDX #8
sk_div  ASLB
        ROLA
        CMPA #96
        BLO sk_next
        SUBA #96
        INCB
sk_next LEAX -1,X
        BNE sk_div
        PULS X
        CLRA
        TST <sgnt
        BPL sk_r
        JMP NEGD
sk_r    RTS

; z(c) of the ellipse point at counter c: nz*cos + wz*sin (D, signed)
ZOFC    PSHS A
        LDB <enz
        ADDA #16
        JSR SINSC
        STD <tmp
        PULS A
        LDB <ewz
        JSR SINSC
        ADDD <tmp
        RTS

; first counter of the visible half: the last point still on the far side
; (z >= 0) before z goes negative -> ec0. z(c) is a sinusoid with z(c+32) = -z(c),
; so exactly one down-crossing lies between c = p and p+32, p = 0 or 32 being the
; half where z(p) >= 0; five bisections find it.
FINDST  CLRA
        JSR ZOFC
        TSTA
        BPL fs_a
        LDA #32
        BRA fs_b
fs_a    CLRA
fs_b    STA ec0                 ; lo: z >= 0
        ADDA #32
        STA fhi                 ; hi: z < 0
        LDA #5
        STA <cnt
fs_l    LDA ec0
        ADDA fhi
        LSRA
        STA fmid
        ANDA #63
        JSR ZOFC
        TSTA
        BMI fs_neg
        LDA fmid
        STA ec0
        BRA fs_n
fs_neg  LDA fmid
        STA fhi
fs_n    DEC <cnt
        BNE fs_l
        LDA ec0
        ANDA #63
        STA ec0
        RTS

; Scale orientation component \1 to unsigned pixel magnitude \2 and sign \3.
; Vertical components use the CoCo's 3/4 screen scale. Full ellipses (craters)
; have half the radius of the planet; halve after scaling, as in BBC PL26.
ABSS    MACRO
        LDA <\1
        STA <\3
        JSR SCALEK
        IFNE \4
        JSR SC34
        ENDC
        JSR ELMAG
        STB <\2
        ENDM

; Convert a signed pixel component to magnitude, halving crater axes first.
ELMAG   PSHS D
        LDA <etgt
        CMPA #64
        PULS D
        BNE em_full
        ASRA
        RORB
em_full TSTA
        BPL em_r
        NEGB                    ; only the unsigned magnitude byte is needed
em_r    RTS

; D = signed (magnitude \1 * sine magnitude \4) / 256.
TERM    MACRO
        LDA <\1
        LDB <\4
        MUL
        TFR A,B
        LDA <\2
        EORA <\3
        JSR TERMSIGN
        ENDM

; Magnitude B, sign in A -> signed 16-bit D (including negative zero).
TERMSIGN
        TSTA
        BPL ts_p
        CLRA
        JMP NEGD
ts_p    CLRA
        RTS

; Draw the ellipse centre + u*cos(c) + v*sin(c) (y negated), c = ec0 .. ec0+etgt
; in steps of pstp, as segments. Every point is four 8x8 MULs: the sine and
; cosine come from the sine table as magnitude and sign. Pixel magnitudes are
; unsigned bytes; signed 16-bit sums keep radii 128..255 from wrapping.
ELLIPSE LDD pcx
        STD ecx
        LDD pcy
        STD ecy
        ABSS evx,avx,svx,0
        ABSS eux,aux,sux,0
        ABSS evy,avy,svy,1
        ABSS euy,auy,suy,1
        LDA #1
        STA pfst
        CLR ecn
el_l    LDA ec0
        ADDA ecn
        ANDA #63
        STA ecc
        ANDA #31                ; |sin c| and its sign (bit 5 of the counter)
        LDX #SNE
        LDB A,X
        STB sm1
        LDA ecc
        ASLA
        ASLA
        STA ss1
        LDA ecc                 ; cos c = sin (c + 16)
        ADDA #16
        ANDA #63
        STA ecc
        ANDA #31
        LDB A,X
        STB sm2
        LDA ecc
        ASLA
        ASLA
        STA ss2
        TERM avx,svx,ss1,sm1
        PSHS D
        TERM aux,sux,ss2,sm2
        ADDD ,S++
        ADDD ecx
        STD <cx1
        TERM avy,svy,ss1,sm1
        PSHS D
        TERM auy,suy,ss2,sm2
        ADDD ,S++
        STD <tmp
        LDD ecy
        SUBD <tmp               ; y is up
        STD <cy1
        JSR CIRSEG
        LDA ecn
        ADDA pstp
        STA ecn
        CMPA etgt
        LBLS el_l
        RTS

; Keep orientation components signed; ELLIPSE scales them to pixel magnitudes.
SETU    LDA ,X
        STA <eux
        LDA 2,X
        STA <euy
        RTS
SETV    LDA ,X
        STA <evx
        LDA 2,X
        STA <evy
        RTS

; Signed D * 222/256: displacement of the crater centre along roofv.
CRATOFF PSHS A
        TSTA
        BPL co_p
        JSR NEGD
co_p    TFR B,A
        LDB #222
        MUL
        TFR A,B
        CLRA
        TST ,S+
        BPL co_r
        JMP NEGD
co_r    RTS

; the planet's equator and meridian (type 128), or its crater (type 130)
PLANDETAIL
        LDA kr
        CMPA #6
        LBLO pd_r               ; too small
        TST <pbig
        LBNE pd_r               ; BBC PL9: no detail when the true radius >= 256
        LDA inwk+34
        CMPA #128
        LBNE pd_crater
        LDX #inwk+21            ; nosev x,y,z hi bytes at +21,+23,+25
        JSR SETU
        LDA inwk+25
        STA <enz
        LDX #inwk+15            ; first meridian: nosev and roofv
        JSR SETV
        LDA inwk+19
        STA <ewz
        JSR FINDST
        LDA #32
        STA etgt
        JSR ELLIPSE
        LDX #inwk+9             ; second meridian, 90 degrees round: nosev and sidev
        JSR SETV
        LDA inwk+13
        STA <ewz
        JSR FINDST
        LDA #32
        STA etgt
        JMP ELLIPSE
pd_crater
        LDA inwk+19             ; roofv_z: a crater on the far side is not drawn
        LBMI pd_r
        LDA inwk+15             ; centre = planet centre + 222/256 * K * roofv
        JSR SCALEK
        JSR CRATOFF
        ADDD pcx
        STD pcx
        LDA inwk+17
        JSR SCALEK
        JSR SC34
        JSR CRATOFF
        STD <tmp
        LDD pcy
        SUBD <tmp
        STD pcy
        LDX #inwk+21            ; ELLIPSE halves the crater's scaled vectors
        JSR SETU
        LDX #inwk+9
        JSR SETV
        CLR ec0
        LDA #64
        STA etgt
        JMP ELLIPSE
pd_r    RTS

; ---- the sun ---------------------------------------------------------------
; A filled disc of horizontal lines. Each row's half-width is the integer square
; root of K^2 - V^2 (V = distance from the centre row) plus a random 0..fringe
; each frame, which gives the original's ragged edge: fringe 7 for K >= 96, 3 for
; K >= 40, 1 for K >= 16, else 0. Lines are EORed, as in the original.

LMASK   FCB $FF,$7F,$3F,$1F,$0F,$07,$03,$01
RMASK   FCB $80,$C0,$E0,$F0,$F8,$FC,$FE,$FF

; flip pixels <lx0..<lx1 (0 <= lx0 <= lx1 <= 255) on pixel row A of the page
HLINE   LDB #32
        MUL
        ADDD <back
        TFR D,X
        LDA <lx0
        LSRA
        LSRA
        LSRA
        STA <tmp+1              ; left byte index
        LDB <lx1
        LSRB
        LSRB
        LSRB
        STB <tlo                ; right byte index
        LDB <tmp+1
        ABX
        LDA <lx0
        ANDA #7
        LDY #LMASK
        LDA A,Y
        STA <tmp                ; left mask
        LDA <lx1
        ANDA #7
        LDY #RMASK
        LDA A,Y
        STA <tmp2               ; right mask
        LDA <tlo
        SUBA <tmp+1
        BNE hl_two
        LDA <tmp                ; all inside one byte
        ANDA <tmp2
        EORA ,X
        STA ,X
        RTS
hl_two  DECA
        STA <tlo                ; bytes strictly between
        LDA <tmp
        EORA ,X
        STA ,X+
        LDA <tlo
        BEQ hl_r
hl_m    COM ,X+
        DEC <tlo
        BNE hl_m
hl_r    LDA <tmp2
        EORA ,X
        STA ,X
        RTS

; flip the pixels <lx0..<lx1 (0 <= lx0 <= lx1 <= 255) of the row at U (not changed):
; the end bytes through masks, the bytes between with a jump into a chain of COMs
HROW    LDA <lx0
        LSRA
        LSRA
        LSRA
        LEAX A,U                ; X = left byte
        LDB <lx1
        LSRB
        LSRB
        LSRB
        STA <tmp
        SUBB <tmp               ; B = right byte - left byte
        LDA <lx0
        ANDA #7
        LDY #LMASK
        LDA A,Y
        STA <tmp                ; left mask
        LDA <lx1
        ANDA #7
        LDY #RMASK
        LDA A,Y                 ; right mask
        TSTB
        BNE hr_two
        ANDA <tmp               ; all inside one byte
        EORA ,X
        STA ,X
        RTS
hr_two  PSHS A
        LDA <tmp
        EORA ,X
        STA ,X+
        DECB                    ; bytes strictly between
        BEQ hr_r
        LDY #HRCHAIN
        ASLB
        NEGB
        LEAY B,Y
        JSR ,Y
hr_r    PULS A
        EORA ,X
        STA ,X
        RTS
HRCHAIN_START
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
        COM ,X+
HRCHAIN RTS

; the sun's rows for the fast case (centre column inside the screen): U walks the
; half-width table (step +-1 per row), <rowp the row's screen address, <tb rows to go.
; The row ends are 8-bit saturating sums, and the span goes in as in HROW, inline.
SROW    MACRO
@lp     LDA ,U
        LEAU \1,U
        LDB <srnd               ; fringe: 8-bit LFSR (x^8+x^4+x^3+x^2+1), cheap and
        ASLB                    ; independent of the game's seed
        BCC @q
        EORB #$1D
@q      STB <srnd
        ANDB sfr
        STB <tmp
        ADDA <tmp               ; h = half-width + fringe
        BCC @h
        LDA #255
@h      STA <tmp
        LDA <pxl
        SUBA <tmp
        BCC @a
        CLRA
@a      STA <lx0
        LDA <pxl
        ADDA <tmp
        BCC @b
        LDA #255
@b      STA <lx1
        LDX <rowp
        LDA <lx0                ; the span: left byte, bytes between, right byte
        LSRA
        LSRA
        LSRA
        LEAX A,X
        LDB <lx1
        LSRB
        LSRB
        LSRB
        STA <tmp
        SUBB <tmp
        LDA <lx0
        ANDA #7
        LDY #LMASK
        LDA A,Y
        STA <tmp                ; left mask
        LDA <lx1
        ANDA #7
        LDY #RMASK
        LDA A,Y                 ; right mask
        TSTB
        BNE @two
        ANDA <tmp
        EORA ,X
        STA ,X
        BRA @nx
@two    PSHS A
        LDA <tmp
        EORA ,X
        STA ,X+
        DECB
        BEQ @r
        LDY #HRCHAIN
        ASLB
        NEGB
        LEAY B,Y
        JSR ,Y
@r      PULS A
        EORA ,X
        STA ,X
@nx     LDX <rowp
        LEAX 32,X
        STX <rowp
        DEC <tb
        LBNE @lp
        ENDM

SUN     JSR CHKON
        LBCS sun_x
        LDA #0                  ; fringe size from the radius
        LDB kr
        CMPB #96
        BLO su_f1
        LDA #7
        BRA su_f
su_f1   CMPB #40
        BLO su_f2
        LDA #3
        BRA su_f
su_f2   CMPB #16
        BLO su_f
        LDA #1
su_f    STA sfr
        LDA kr                  ; the table only changes with the radius
        CMPA hwk
        LBEQ su_have
        STA hwk
        LDX #hwt                ; half-width table HW[v] = floor(sqrt(K^2 - dy^2)), v = 0..kry,
        LDA kr                  ; where row v is dy = floor((4v+1)/3) original lines from the
        STA ,X+                 ; centre (the screen is 3/4 of the original's height). Stepped:
        STA sw                  ; r = K^2 - dy^2 - w^2 drops by d*(2*dy+d) as dy grows by d
        CLRA                    ; (1, or 2 every third row), and w shrinks (r += 2w-1) while r < 0
        CLRB
        STD <ta                 ; r
        CLR <tv2                ; dy
        LDA #1
        STA <tr                 ; v mod 3 of the next row
        LDA kry
        STA <cnt
su_v    CLRA
        LDB <tv2                ; d = 2 on every third row (v mod 3 = 2), else 1
        ASLB
        ROLA                    ; 2*dy + 1: keep the high byte for large suns
        ADDD #1
        STD <tmp
        LDA <tr
        CMPA #2
        BNE su_d1
        LDD <tmp
        ADDD #1
        ASLB                    ; d*(2dy+d) = 2*(2dy+2)
        ROLA
        BRA su_d2
su_d1   LDD <tmp
su_d2   STD <tmp                ; the drop in r
        LDD <ta
        SUBD <tmp
        STD <ta
        LDA <tr                 ; dy += d
        CMPA #2
        BNE su_e1
        INC <tv2
su_e1   INC <tv2
        LDA <tr                 ; v mod 3
        INCA
        CMPA #3
        BLO su_e2
        CLRA
su_e2   STA <tr
        TST <ta
        BPL su_s
su_w    LDB sw
        BEQ su_s                ; below the circle's bottom (the 3/4 rounding): width 0
        CLRA
        ASLB
        ROLA                    ; 2*w - 1, including w >= 128
        SUBD #1
        ADDD <ta
        STD <ta
        DEC sw
        TST <ta
        BMI su_w
su_s    LDA sw
        STA ,X+
        DEC <cnt
        BNE su_v
su_have CLRA                    ; rows cy-kry .. cy+kry, kept inside 1..YMAX
        LDB kry
        STD <tmp
        LDD pcy
        SUBD <tmp
        CMPD #1
        BGE su_t
        LDD #1
su_t    CMPD #YMAX
        LBGT sun_x
        STB sy
        LDD pcy
        ADDD <tmp
        CMPD #1
        LBLT sun_x
        CMPD #YMAX
        BLE su_b
        LDD #YMAX
su_b    STB sy1
        LDA sy                  ; (O11: the bands of rows sy .. sy1)
        LSRA
        LSRA
        LSRA
        LSRB
        LSRB
        LSRB
        STB dtmp
        LDX dbp
        LEAX A,X
        LDB #$FF
su_m    STB ,X+
        INCA
        CMPA dtmp
        BLS su_m
        LDA sy                  ; address of the first row
        LDB #32
        MUL
        ADDD <back
        STD <rowp
        TFR D,U
        LDD pcx                 ; centre inside x = 0..255: 8-bit arithmetic, ends saturated
        TSTA
        LBNE su_row
        STB <pxl
        LDA sy1                 ; rows in all
        SUBA sy
        INCA
        STA <ta
        CLRA
        LDB sy
        STD <tmp
        LDD pcy
        SUBD <tmp               ; cy - first row: the upper rows run up to the centre
        LBLT su_dnonly
        STB <tq                 ; v at the first row
        INCB
        CMPB <ta
        BLS su_nu
        LDB <ta
su_nu   STB <tb                 ; upper rows: min(rows, v+1)
        LDA <ta
        SUBA <tb
        STA <tr                 ; rows below the centre
        LDB <tq
        CLRA
        ADDD #hwt
        TFR D,U
        SROW -1
        LDA <tr
        LBEQ sun_x
        STA <tb
        LDU #hwt+1
        BRA su_dnrows
su_dnonly
        NEGA                    ; the centre is above the first row: v = row - cy, growing
        NEGB
        SBCA #0
        CLRA
        ADDD #hwt
        TFR D,U
        LDA <ta
        STA <tb
su_dnrows
        SROW 1
        RTS
su_row  LDB sy                  ; v = |cy - y|
        CLRA
        STD <tmp
        LDD pcy
        SUBD <tmp
        BPL su_a
        NEGA
        NEGB
        SBCA #0
su_a    LDX #hwt
        ABX
        LDA ,X
        LDB srnd                ; fringe: 8-bit LFSR (x^8+x^4+x^3+x^2+1), cheap and
        ASLB                    ; independent of the game's seed
        BCC su_q
        EORB #$1D
su_q    STB srnd
        ANDB sfr
        STB <tmp
        ADDA <tmp               ; h = half-width + fringe
        BCC su_h
        LDA #255
su_h    TFR A,B
        CLRA
        STD <tmp
        LDD pcx
        ADDD <tmp               ; x2 = cx + h
        BMI su_n                ; entirely left of the screen
        CMPD #255
        BLE su_g
        LDD #255
su_g    STB <lx1
        LDD pcx
        SUBD <tmp               ; x1 = cx - h
        CMPD #255
        BGT su_n                ; entirely right
        TSTA
        BPL su_l
        CLRB
su_l    STB <lx0
        JSR HROW
su_n    LEAU 32,U
        INC sy
        LDA sy
        CMPA sy1
        BLS su_row
sun_x   RTS

; the planet or sun in inwk
PLANET  JSR PLANPROJ
        BCS pl_x
        LDA inwk+34
        CMPA #129
        BEQ pl_sun
        JSR CIRCLE
        BCS pl_x
        JMP PLANDETAIL
pl_sun  JMP SUN
pl_x    RTS
