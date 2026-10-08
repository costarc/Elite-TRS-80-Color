; LL9: draw one ship from its blueprint (<bp) and ship record (inwk).
;
; Follows the original's structure - visibility cone, distance dot, detail
; level (XX4), face culling, vertex projection, edge drawing - but each stage
; is rewritten around the 6809:
;   * positions are scaled once per ship into 16-bit units 2^(h-6), where h is
;     the smallest shift that keeps z below 32768, so the whole ship runs in
;     16-bit arithmetic
;   * the rotation matrix is reduced to 8-bit magnitudes (unity 252) and
;     products use MUL on magnitudes with the sign handled separately
;   * perspective divides by normalising z to bit 15 and looking up 2^15/mantissa
;   * only vertices that touch a visible face are projected

; ---- helpers --------------------------------------------------------------

; D = |24-bit value at ,X| (saturated at $FFFF)
ABS24   LDA ,X
        BEQ a24_p
        INCA
        BEQ a24_n
        LDD #$FFFF
        RTS
a24_p   LDD 1,X
        RTS
a24_n   LDD 1,X
        JSR NEGD
        CMPD #0
        BNE a24_r
        LDD #$FFFF
a24_r   RTS

; D = (24-bit value at ,X) * 2^<ksh as a 16-bit signed number (ksh = 6-h)
SCALE1  LDA <ksh
        STA <cnt2
        LDA 2,X
        STA <tlo
        LDD ,X
        TST <cnt2
        BMI sc_r
        BEQ sc_d
sc_l    ASL <tlo
        ROLB
        ROLA
        DEC <cnt2
        BNE sc_l
        BRA sc_d
sc_r    ASRA
        RORB
        ROR <tlo
sc_d    TFR B,A
        LDB <tlo
        RTS

; D >>= <pcnt (unsigned), count >= 0
SHS     TST <pcnt
        BEQ sh_d
sh_r    LSRA
        RORB
        DEC <pcnt
        BNE sh_r
sh_d    RTS

; Orientation vectors (inwk+9, 9 x signed 16, unity $6000) -> mag/sgn:
; |e| * 64 / $6000 = (|e| * 171) >> 16, unity 64 (the original's matrix is
; 8 bit too). The sign masks for TRANSFORM follow (MKMASK, generated).
MKMAT   LDX #inwk+9
        LDY #mag
        LDU #sgn
        LDB #9
        STB <cnt
mk_lp   LDD ,X++
        STA ,U+
        BPL mk_pos
        COMA
        COMB
        ADDD #1
mk_pos  STB <tmp+1
        LDB #171
        MUL
        STD <tmp2
        LDA <tmp+1
        LDB #171
        MUL
        ADDA <tmp2+1
        LDA <tmp2
        ADCA #0
        STA ,Y+
        DEC <cnt
        BNE mk_lp
        BRA MKMASK

        INCLUDE "gen/mkmask.inc"

; <ps64+\2 = P'' . (ship axis \1): ship-space position of the face-test
; vector; \1 = first mag index (0,3,6), \2 = destination byte offset.
PSDOT   MACRO
        LDA <ppsg
        EORA <sgn+\1
        STA <sgnt
        LDA <pp
        LDB <mag+\1
        MUL                     ; exact PROD, inlined for the nine face-view products
        TST <sgnt
        BPL @positive0
        NEGA
        NEGB
        SBCA #0
@positive0 EQU *
        STD <acc
        LDA <ppsg+1
        EORA <sgn+\1+1
        STA <sgnt
        LDA <pp+1
        LDB <mag+\1+1
        MUL                     ; exact PROD, inlined for the nine face-view products
        TST <sgnt
        BPL @positive1
        NEGA
        NEGB
        SBCA #0
@positive1 EQU *
        ADDD <acc
        STD <acc
        LDA <ppsg+2
        EORA <sgn+\1+2
        STA <sgnt
        LDA <pp+2
        LDB <mag+\1+2
        MUL                     ; exact PROD, inlined for the nine face-view products
        TST <sgnt
        BPL @positive2
        NEGA
        NEGB
        SBCA #0
@positive2 EQU *
        ADDD <acc
        STD <ps64+\2
        ENDM

; |D| >> 7 in A (8-bit), sign byte in <tlo
PP7     CLR <tlo
        TSTA
        BPL pp7a
        JSR NEGD
        COM <tlo
pp7a    ASLB
        ROLA
        RTS

; ---- face visibility (original LL9 part 5) -------------------------------
; A face is shown when n . (P + n/2^X) < 0 in ship space (P = ship position
; reduced to 8 bits, X = blueprint scale + reduction). For X >= 4 the original
; drops the n term. Faces whose own visibility distance is below the current
; detail level (<lod) are always shown.
;
; Only the sign of the dot product matters, so it is done in 8 bits like the
; original: the ship-space position p (ps64) is scaled down by 2^s until its
; largest component is below 64, then every face costs three 8x8 MULs whose
; products go into one of two accumulators by sign: LEAX D,X for the negative
; terms, LEAY D,Y for the positive ones (|sum| <= 3*63*255, inside 16 bits).
;   visible  <=>  neg > pos + thr
; For X < 4 the n term adds thr = |n|^2 * 2^(6-X) / 2^s, built from three more
; MULs and one shift.

; abs of the 16-bit value at ps64+\1 -> pmg+\1
ABSP    MACRO
        LDD <ps64+\1
        BPL @p
        NEGA
        NEGB
        SBCA #0
@p      STD <pmg+\1
        ENDM

; thr in D <<= <fcl, saturating at $FFFF
GSHL    LDX <fcl
gs_l    ASLB
        ROLA
        BCS gs_sat
        LEAX -1,X
        BNE gs_l
        RTS
gs_sat  LDD #$FFFF
        RTS

FACEVIS LDD <xp
        JSR PP7
        STA <pp
        LDA <tlo
        STA <ppsg
        LDD <yp
        JSR PP7
        STA <pp+1
        LDA <tlo
        STA <ppsg+1
        LDD <zp
        JSR PP7
        STA <pp+2
        LDA <tlo
        STA <ppsg+2
        PSDOT 0,0
        PSDOT 3,2
        PSDOT 6,4
        LDA <ps64               ; sign byte: bits 7,6,5 = signs of the three components
        ANDA #$80
        STA <tsg
        LDA <ps64+2
        ANDA #$80
        LSRA
        ORA <tsg
        STA <tsg
        LDA <ps64+4
        ANDA #$80
        LSRA
        LSRA
        ORA <tsg
        STA <tsg
        ABSP 0
        ABSP 2
        ABSP 4
        LDD <pmg                ; common shift s: largest component below 64
        ORA <pmg+2
        ORB <pmg+3
        ORA <pmg+4
        ORB <pmg+5
        CLR <fshw
        CLR <fshw+1
fv_s    CMPD #64
        BLO fv_sd
        LSRA
        RORB
        INC <fshw+1
        BRA fv_s
fv_sd   LDA <fshw+1             ; p7 = |ps64| >> s through the LADU ladder (s <= 7), or the
        CMPA #8                 ; high bytes (s = 8, 9)
        BHS fv_big
        NEGA
        ADDA #7
        ASLA
        CLRB
        EXG A,B
        ADDD #LADU
        TFR D,Y
        LDD <pmg
        JSR ,Y
        STB <p7
        LDD <pmg+2
        JSR ,Y
        STB <p7+1
        LDD <pmg+4
        JSR ,Y
        STB <p7+2
        BRA fv_pd
fv_big  LDA <pmg
        STA <p7
        LDA <pmg+2
        STA <p7+1
        LDA <pmg+4
        STA <p7+2
        LDA <fshw+1
        CMPA #9
        BNE fv_pd
        LSR <p7
        LSR <p7+1
        LSR <p7+2
fv_pd   EQU *
        LDX <bp
        LDA 18,X                ; normals are scaled by 2^scale
        ADDA <hsh
        INCA                    ; X = scale + h + 1
        STA <xsc
        CLR <nmul               ; n term only for X < 4: multiplier 2^(6-X)
        CMPA #4
        BHS fv_nm
        LDB #64
fv_sh   LSRB
        DECA
        BNE fv_sh
        STB <nmul
        LDA <fshw+1             ; thr shift c = s + X - 8: right by c, or left by -c
        ADDA <xsc
        SUBA #8
        BMI fv_gl
        NEGA                    ; ladder rung 7-c (rungs are two bytes)
        ADDA #7
        ASLA
        CLRB
        EXG A,B
        ADDD #LADU
        STD fv_gs+1
        BRA fv_nm
fv_gl   NEGA
        STA <fcl+1
        CLR <fcl
        LDD #GSHL
        STD fv_gs+1
fv_nm   LDA 12,X
        LSRA
        LSRA
        STA <nf
        LDA 17,X
        LDB 4,X
        ADDD <bp
        TFR D,U                 ; U = face data
        CLR <cnt
        LDA #1
        STA visible+15          ; face 15 = always visible
fv_lp   LDA ,U
        STA <fs
        ANDA #31
        CMPA <lod
        LBLO fv_show            ; far away: no test
        LDA <fs
        EORA <tsg               ; term sign bits: n sign xor p sign
        STA <fs
        LDX #0                  ; X = negative terms, Y = positive terms
        LDY #0
        LDA 1,U
        BEQ fv_x2              ; zero normal contributes exactly zero
        LDB <p7
        MUL
        TST <fs
        BPL fv_x1
        LEAX D,X
        BRA fv_x2
fv_x1   LEAY D,Y
fv_x2   ASL <fs                 ; advance sign even when the term is zero
        LDA 2,U
        BEQ fv_y2
        LDB <p7+1
        MUL
        TST <fs
        BPL fv_y1
        LEAX D,X
        BRA fv_y2
fv_y1   LEAY D,Y
fv_y2   ASL <fs
        LDA 3,U
        BEQ fv_z2
        LDB <p7+2
        MUL
        TST <fs
        BPL fv_z1
        LEAX D,X
        BRA fv_z2
fv_z1   LEAY D,Y
fv_z2   TST <nmul
        BNE fv_near
        STX <tmp                ; visible when neg > pos
        CMPY <tmp
        BLO fv_show
fv_hide CLRA
        BRA fv_st
fv_near LDA 1,U                 ; thr = (sum n^2 / 4) shifted by c
        TFR A,B
        MUL
        LSRA
        RORB
        LSRA
        RORB
        STD <tmp
        LDA 2,U
        TFR A,B
        MUL
        LSRA
        RORB
        LSRA
        RORB
        ADDD <tmp
        STD <tmp
        LDA 3,U
        TFR A,B
        MUL
        LSRA
        RORB
        LSRA
        RORB
        ADDD <tmp
fv_gs   JSR >LADU               ; patched: right shift ladder rung or GSHL
        STD <tmp
        STX <tmp2
        LDD <tmp2
        SUBD <tmp               ; neg - thr (borrow: hidden)
        BLS fv_hide
        STD <tmp2
        CMPY <tmp2              ; visible when neg - thr > pos
        BHS fv_hide
fv_show LDA #1
fv_st   LDX #visible
        LDB <cnt
        STA B,X
        LEAU 4,U
        INC <cnt
        LDA <cnt
        CMPA <nf
        LBLO fv_lp
        RTS

; ---- vertices ----------------------------------------------------------------
; scr[i] = (sx, sy) 16-bit for every vertex that touches a visible face.
;
; Per vertex: the rotation is nine 8x8 MULs on magnitudes (matrix unity 64, so a
; product is already in 1/64 units); the signs ride on XOR masks from MSKTAB
; (one's complement instead of a negate, the missing +1 is far below a pixel).
; The h shift is a patched ladder of ASRA/RORB, and the perspective is one
; 16x8 multiply by a mantissa reciprocal followed by a jump into a second
; ladder (LADU) that does the remaining 7-ps shifts.

; D (signed) >>= h : JSR here lands on the right rung (patched per ship)
SHLAD   ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
        ASRA
        RORB
SHLADE  RTS

; D (unsigned) >>= 7-ps : entered at LADU+2*ps
LADU    LSRA
        RORB
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
        LSRA
        RORB
        RTS

; D saturated after a signed overflow (N is the wrong way round)
SATV    TSTA
        BMI sv_p
        LDD #$8000
        RTS
sv_p    LDD #$7FFF
        RTS

; one row of  M . (vertex): \1 = row k, mask pattern in Y
ROW     MACRO
        LDA <vax
        LDB <mag+\1
        MUL
        EORA \1,Y
        EORB \1,Y
        STD <acc
        LDA <vay
        LDB <mag+3+\1
        MUL
        EORA 3+\1,Y
        EORB 3+\1,Y
        ADDD <acc
        STD <acc
        LDA <vaz
        LDB <mag+6+\1
        MUL
        EORA 6+\1,Y
        EORB 6+\1,Y
        ADDD <acc
        ENDM

; signed D (Xt) -> screen offset 256 * Xt / Zt, saturated at +-$4000 (PERSP1 pu for x;
; PERSP1 pu3 for y, whose scale is 3/4: see YSCALE).
;   pu = T ~ 2^15/mantissa, X = ladder entry for the remaining shifts:
;   offset = (|Xt| * T) >> (15-ps)
PERSP1  MACRO
        STA <psign
        BPL @p
        NEGA
        NEGB
        SBCA #0
@p      STB <pm+1
        STA <pm
        LDA <\1
        MUL                     ; |lo| * T
        STA <p2h
        LDA <pm
        LDB <\1
        MUL                     ; |hi| * T
        ADDB <p2h
        ADCA #0
        JSR ,X
        BITA #$40               ; saturate at $4000
        BEQ @s
        LDD #$4000
@s      TST <psign
        BPL @r
        NEGA
        NEGB
        SBCA #0
@r      EQU *
        ENDM

; matrix entry \1 scaled by the centre's multiplier: |mag| * T >> 7 (<= 127)
SCM     MACRO
        LDA <mag+\1
        LDB <pu
        MUL
        ASLB
        ROLA
        STA <mag+\1
        ENDM

        IFDEF WEAKPERSP
SRALAD  ASRA
        ASRA
        ASRA
        ASRA
        ASRA
        ASRA
        ASRA
SRAE    RTS

; The far-ship path: rows 0 and 1 of the matrix times T give R = 2^(h-ps+8) * offset
; in pixels (offset from the centre), so a vertex needs no perspective. Also the
; centre's screen position cx, cy.
WEAKSET SCM 0
        SCM 1
        SCM 3
        SCM 4
        SCM 6
        SCM 7
        LDA <hsh                ; rung of the ASRA ladder: h - ps shifts
        SUBA <ps
        STA <tmp
        LDD #SRAE
        SUBB <tmp
        SBCA #0
        STD tw_s1+1
        STD tw_s2+1
        LDX ladw
        LDD <xp
        PERSP1 pu
        ADDD #128
        STD cxw
        LDD <yp
        PERSP1 pu
        STD <tmp
        LDD <cyv
        SUBD <tmp
        STD cyw
        RTS
        ENDC

TRANSFORM
        LDX <bp
        LDA inwk+31
        BITA #$40
        BEQ tv_init
        LDB 6,X                 ; gun vertex * 4: mark it unprojected for this ship
        LDX #scr
        ABX
        LDD #$7FFF              ; outside the projection range, never a real sx
        STD ,X
        LDX <bp
tv_init EQU *
        LDA 8,X
        LDB #43                 ; n = verts*6/6 via *43/256 (exact below 128)
        MUL
        STA <nv
        LEAU 20,X
        LDD #scr
        STD <vptr
tv_lp   LDA 3,U
        ANDA #31
        CMPA <lod
        LBLO tv_skip
        LDX #visible
        LDA 4,U
        ANDA #$0F
        TST A,X
        BNE tv_do
        LDA 4,U
        LSRA
        LSRA
        LSRA
        LSRA
        TST A,X
        BNE tv_do
        LDA 5,U
        ANDA #$0F
        TST A,X
        BNE tv_do
        LDA 5,U
        LSRA
        LSRA
        LSRA
        LSRA
        TST A,X
        LBEQ tv_skip
tv_do   LDD <work
        BEQ tv_nowork           ; flight has no synthetic frame limiter
        ADDD #VERTCOST
        STD <work
tv_nowork EQU *
        LDA ,U
        STA <vax
        LDA 1,U
        STA <vay
        LDA 2,U
        STA <vaz
        LDB 3,U                 ; sign pattern * 32 = offset into MSKTAB
        ANDB #$E0
        LDA #MSKTAB/256
        TFR D,Y
        IFDEF WEAKPERSP
        TST <wk
        BEQ tv_full
        ROW 0                   ; far ship: two rows against the scaled matrix give the
tw_s1   JSR >SRAE               ; pixel offsets directly (patched: ASRA x (h - ps))
        TFR A,B
        SEX
        ADDD cxw
        STD <tmp                ; sx
        ROW 1
tw_s2   JSR >SRAE
        TFR A,B
        SEX
        STD <tmp2
        LDD cyw                 ; sy = cy - offset
        SUBD <tmp2
        LBRA tv_st
        ENDC
tv_full LDA <vay
        BNE tv_general
        JSR VERTY0
        LBRA tv_s3
tv_general ROW 0
tv_s1   JSR >SHLADE             ; patched: >> h
        ADDD <xp
        BVC tv_x1
        JSR SATV
tv_x1   STD <xr                 ; Xt
        ROW 1
tv_s2   JSR >SHLADE
        ADDD <yp
        BVC tv_y1
        JSR SATV
tv_y1   STD <yr                 ; Yt
        ROW 2
tv_s3   JSR >SHLADE
        TSTA
        BPL tv_zp
        ADDD <zp                ; Zt = zp - |z offset|: carry set while still >= 0
        BCS tv_zc
        LDD #256
        BRA tv_zk
tv_zp   ADDD <zp                ; zp + z offset: below 65536 by construction
tv_zc   CMPD #256
        BHS tv_zk
        LDD #256
tv_zk   LDX #LADU               ; normalise: shift left until bit 15, ladder entry X
        TSTA
        BMI tv_nd
tv_n1   ASLB
        ROLA
        LEAX 2,X
        BPL tv_n1
tv_nd   TFR A,B                 ; mantissa 128..255 -> multiplier T
        CLRA
        LDY #RT8-128
        LDB D,Y
        STB <pu
        LDA #192                ; the y scale is 3/4 of x: T3 = T * 192 / 256
        MUL
        STA <pu3
        LDD <xr
        PERSP1 pu
        ADDD #128
        STD <tmp                ; sx
        LDD <yr
        PERSP1 pu3
        STD <tmp2
        LDD <cyv                 ; sy = CY - offset
        SUBD <tmp2
tv_st   LDY <vptr
        STD 2,Y
        STB scrb-scr+1,Y        ; byte record: sx low, sy low, outcode
        TSTA                    ; inside the viewport (nearly always): the 8-bit tests
        BNE tv_yo2
        CMPB #YMIN
        BLO tv_yo2
        CMPB <ymx+1
        BHI tv_yo2
        CLR <occ
        BRA tv_xs
tv_yo2  CMPD #YMIN              ; outside: which side
        BLT tv_ya
        LDA #8
        BRA tv_yf
tv_ya   LDA #4
tv_yf   STA <occ
tv_xs   LDD <tmp
        STD ,Y
        STB scrb-scr,Y
        TSTA
        BNE tv_xo2
        CMPB #XMIN
        BLO tv_xo2
        CMPB #XMAX
        BHI tv_xo2
        LDA <occ
        BRA tv_xe
tv_xo2  CMPD #XMIN
        BLT tv_xa
        LDA #2
        BRA tv_xf
tv_xa   LDA #1
tv_xf   ORA <occ
tv_xe   STA scrb-scr+2,Y
tv_skip LEAU 6,U
        LDD <vptr
        ADDD #4
        STD <vptr
        DEC <nv
        LBNE tv_lp
        RTS

; ---- the original-style perspective (planets, distant dots) ----
; signed Xt in D -> screen offset in D (256 * Xt / Zt, saturated +-$4000)
;   Zt = normalised by <ps shifts; T = 128+<pu ~ 2^15/mantissa;
;   off = (|Xt| * T) >> (15-ps), done as (M >> (8-ps)) + (V >> (7-ps)),
;   V = M*u / 256.
PERSP   CLR <psign
        TSTA
        BPL pe_pos
        JSR NEGD
        COM <psign
pe_pos  STD <pm
        LDA <pm+1
        LDB <pu
        MUL
        STA <p2h
        LDA <pm
        LDB <pu
        MUL
        ADDB <p2h
        ADCA #0
        STD <ptmp
        LDA #7
        SUBA <ps
        STA <pcnt
        LDD <ptmp
        JSR SHS
        STD <ptmp
        LDA #8
        SUBA <ps
        STA <pcnt
        LDD <pm
        JSR SHS
        ADDD <ptmp
        BCS pe_sat
        CMPD #$4000
        BLS pe_sg
pe_sat  LDD #$4000
pe_sg   TST <psign
        BEQ pe_ret
        JSR NEGD
pe_ret  RTS

; ---- edges ----------------------------------------------------------------------
DRAWEDGES
        LDX <bp
        LDA 16,X
        LDB 3,X
        ADDD <bp
        TFR D,U
        LDA 9,X
        STA <cnt
de_lp   LDA ,U
        CMPA <lod
        BLO de_next             ; detail level not reached yet
        LDB 1,U
        TFR B,A
        ANDB #$0F
        LDY #visible
        TST B,Y
        BNE de_draw
        LSRA
        LSRA
        LSRA
        LSRA
        TST A,Y
        BEQ de_next
de_draw LDX #scrb               ; both ends inside the viewport: straight to LINE
        LDB 3,U
        ABX
        LDA 2,X
        LDY ,X
        LDX #scrb
        LDB 2,U
        ABX
        ORA 2,X
        BNE de_clip
        LDD ,X
        STD <lx0
        STY <lx1
        JSR LINE
        BRA de_next
de_clip LDX #scr                ; partly outside: the 16-bit coordinates and the clipper
        LDB 2,U
        ABX
        LDD ,X
        STD <cx0
        LDD 2,X
        STD <cy0
        LDX #scr
        LDB 3,U
        ABX
        LDD ,X
        STD <cx1
        LDD 2,X
        STD <cy1
        PSHS U
        JSR CLIPLINE
        PULS U
de_next LEAU 4,U
        DEC <cnt
        BNE de_lp
        RTS

; A firing ship's beam starts at its projected gun vertex (blueprint byte 6).
; TRANSFORM leaves a sentinel when that vertex fails the face/detail tests.
; As in the original LL9 part 9, aim at the opposite screen edge, with z_lo
; moving the endpoint vertically. CLIPLINE keeps the beam in the 3D viewport.
DRAWLASER
        LDA inwk+31
        BITA #$40
        BEQ dl_ret
        LDX <bp
        LDB 6,X
        LDX #scr
        ABX
        LDD ,X
        CMPD #$7FFF
        BEQ dl_ret
        TST scrb-scr+2,X        ; an off-screen gun must not send a beam into the view
        BNE dl_ret
        STD <cx0
        LDD 2,X
        STD <cy0
        CLRA
        CLRB                    ; positive x: beam towards the left screen edge
        TST inwk
        BPL dl_edge
        LDB #255                ; negative x: beam towards the right screen edge
dl_edge STD <cx1
        CLRA
        LDB inwk+8              ; z_lo in the CoCo's signed 24-bit position
        JSR SC34                ; original vertical pixels -> CoCo rows
        STD <cy1
        JMP CLIPLINE
dl_ret  RTS

; EXPERIMENTAL, off by default (assemble with -DWEAKPERSP): perspective from the
; ship's centre for every vertex of a distant ship, which saves the z row, the
; normalisation and the lookup per vertex (about 7% of the six-ship frame). It is
; NOT exact: a ship away from the screen centre is sheared by its depth (the
; parallax between its near and far vertices): measured on the real blueprints with
; random orientations, 16 radii away the error is 2 px rms and up to 8 px, and still
; 5 px at 23 radii. Fidelity first, so the exact per-vertex path is the default.
; (A first-order depth correction per vertex would make it sub-pixel; not done.)
; Conditions: 16 * zhi >= radius, and h >= ps so that the shift after the rows is
; not negative. Then <wk is set and WEAKSET prepares TRANSFORM's cheap path.
        IFDEF WEAKPERSP
WEAKQ   CLR <wk
        IFNDEF WEAKPERSP
        RTS
        ENDC
        LDX #SHIPSIZE
        LDB inwk+34
        ABX
        LDB ,X
        STB <tmp
        IFNDEF FORCEWEAK
        LDA <zhi
        LDB #16
        MUL
        TSTA
        BNE wq_y
        CMPB <tmp
        BLO wq_n
        ENDC
wq_y    LDD <zp
        CMPD #256
        BHS wq_z
        LDD #256
wq_z    CLR <ps
        LDX #LADU
        TSTA
        BMI wq_nd
wq_n1   INC <ps
        ASLB
        ROLA
        LEAX 2,X
        BPL wq_n1
wq_nd   LDB <hsh
        CMPB <ps
        BLO wq_n                ; the shift after the rows would be negative
        STX ladw
        TFR A,B
        CLRA
        LDY #RT8-128
        LDB D,Y
        STB <pu
        LDA #$FF
        STA <wk
wq_n    RTS
        ENDC

; Carry set when the ship's bounding sphere (radius R = 2 * the byte before the blueprint, taken
; 1.5 times over) lies wholly beyond a plane 1/16 outside an edge of the view: |x| > 9z/16 (the
; edge is at |x| = z/2) or |y| > 7z/16 (the edge at 3z/8), and every point is at z >= 512. Then
; every vertex projects at least 16 pixels beyond the same edge, every edge is clipped away and
; LL9 would draw nothing: matrix, faces and vertices are skipped. (z < 49152 and |x|, |y| < z here.)
VIEWOUT LDX <bp
        LDB -1,X
        CLRA
        ASLB
        ROLA
        STD <tmp                ; R
        LDD inwk+7
        SUBD <tmp
        BLO vo_in
        CMPD #512
        BLO vo_in               ; near: the projection's clamp could bring a vertex back
        LDD <tmp
        LSRA
        RORB
        ADDD <tmp
        STD <tmp                ; 1.5 R
        LDD inwk+7
        LSRA
        RORB
        PSHS D                  ; z/2
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        PSHS D                  ; z/16
        ADDD 2,S                ; |x| > z/2 + z/16 + 1.5R + 3 (the floors cost at most 2)
        ADDD <tmp
        ADDD #3
        STD <tmp2
        LDX #inwk
        JSR ABS24
        CMPD <tmp2
        BHI vo_out
        LDD 2,S                 ; |y| > z/2 - z/16 + 1.5R + 2
        SUBD ,S
        ADDD <tmp
        ADDD #2
        STD <tmp2
        LDX #inwk+3
        JSR ABS24
        CMPD <tmp2
        BHI vo_out
        LEAS 4,S
vo_in   ANDCC #$FE
        RTS
vo_out  LEAS 4,S
        ORCC #1
        RTS

; ---- entry --------------------------------------------------------------------------
; Consume the shot even if the ship is behind us, culled, distant or exploding.
; SLOTUPD copies the cleared flag back after rendering in the selected view.
LL9     JSR LL9SHIP
        LDA inwk+31
        ANDA #$BF
        STA inwk+31
        RTS

LL9SHIP LDA inwk+6
        BNE ll_gone             ; behind us or beyond 65535
        LDA inwk+7
        STA <zhi
        CMPA #192
        BHS ll_gone
        LDX #inwk
        JSR ABS24
        CMPD inwk+7
        BHS ll_gone             ; |x| >= z: outside the 45 degree cone
        LDX #inwk+3
        JSR ABS24
        CMPD inwk+7
        BHS ll_gone
        LDA <zhi
        CMPA #16
        BHS ll_far
        ASLA
        INCA                    ; detail level = z >> 7
        STA <lod
        BRA ll_draw
ll_far  LDA #31
        STA <lod
        LDX <bp
        LDA 13,X                ; visibility distance
        CMPA <zhi
        BHS ll_draw
        LDA inwk+31             ; an exploding ship is never shown as a dot
        BITA #$20
        BNE ll_draw
        LBRA ll_dot
ll_gone RTS
ll_draw LDA inwk+31             ; (an explosion's cloud and the shaded faces are not tested)
        BITA #$20
        BNE ll_mk
        TST shade
        BNE ll_mk
        IFDEF CULLCHECK                 ; test: draw it anyway; LINE marks CULLFAIL if it draws
        CLR cullf
        JSR VIEWOUT
        BCC ll_mk
        INC cullf
CULLHIT NOP
        ELSE
        JSR VIEWOUT
        BCS ll_gone             ; the whole hull is outside the view: nothing would be drawn
        ENDC
ll_mk   JSR MKMAT
        LDA <zhi                ; h = smallest shift with z < 512 * 2^h
        CLRB
ll_h    CMPA #2
        BLO ll_hd
        LSRA
        INCB
        BRA ll_h
ll_hd   STB <hsh
        LDA #6
        SUBA <hsh
        STA <ksh
        LDB <hsh                ; patch TRANSFORM's shift ladder entry: SHLADE - 2h
        ASLB
        CLRA
        STD <tmp
        LDD #SHLADE
        SUBD <tmp
        STD tv_s1+1
        STD tv_s2+1
        STD tv_s3+1
        STD gshptr
        LDX #inwk
        JSR SCALE1
        STD <xp
        LDX #inwk+3
        JSR SCALE1
        STD <yp
        LDX #inwk+6
        JSR SCALE1
        STD <zp
        LDA inwk+31
        BITA #$20
        BNE ll_ex               ; exploding: a cloud instead of the wireframe
        JSR FACEVIS
        IFDEF WEAKPERSP
        JSR WEAKQ
        TST <wk
        BEQ ll_nw
        JSR WEAKSET
        ENDC
ll_nw   JSR TRANSFORM
        TST shade               ; the shaded mode (the Easter egg): the faces first
        BEQ ll_ns
        JSR SHADE
ll_ns   JSR DRAWLASER
        IFDEF CULLCHECK
        JSR DRAWEDGES
        CLR cullf
        RTS
        ELSE
        JMP DRAWEDGES
        ENDC
ll_ex   EQU *
        IFDEF WEAKPERSP
        CLR <wk
        ENDC
        LDX #visible            ; every face and vertex counts (detail level 0)
        LDB #16
        LDA #1
ll_exf  STA ,X+
        DECB
        BNE ll_exf
        CLR <lod
        JSR TRANSFORM
        JMP DOEXP

; far away: a 4x2 dot at the projected centre
ll_dot  LDA <zhi
        CLRB
ld_h    CMPA #2
        BLO ld_hd
        LSRA
        INCB
        BRA ld_h
ld_hd   STB <hsh
        LDA #6
        SUBA <hsh
        STA <ksh
        LDX #inwk
        JSR SCALE1
        STD <xr
        LDX #inwk+3
        JSR SCALE1
        STD <yr
        LDX #inwk+6
        JSR SCALE1
        CMPD #256
        BHS ld_z
        LDD #256
ld_z    CLR <ps
ld_nz   TSTA
        BMI ld_nd
        ASLB
        ROLA
        INC <ps
        BRA ld_nz
ld_nd   TFR A,B
        CLRA
        LDX #RECIPU-128
        LDB D,X
        STB <pu
        LDD <xr
        JSR PERSP
        ADDD #128
        STD <xr                 ; dot x
        LDD <yr
        JSR PERSP
        JSR SC34                ; the y scale is 3/4
        JSR NEGD
        ADDD <cyv
        STD <yr                 ; dot y
        LDD <xr
        STD <cx0
        ADDD #3
        STD <cx1
        LDD <yr
        STD <cy0
        STD <cy1
        JSR CLIPLINE
        LDD <xr
        STD <cx0
        ADDD #3
        STD <cx1
        LDD <yr
        ADDD #1
        STD <cy0
        STD <cy1
        JMP CLIPLINE
