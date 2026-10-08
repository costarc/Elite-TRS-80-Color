; The shaded mode (the Easter egg): the faces of a ship are filled and lit instead of only
; outlined. Wireframe stays the default; the mode is switched by a hidden key sequence on the
; title (see title/title.asm) and is the byte <shade>.
;
; LL9 calls SHADE after TRANSFORM (the projected vertices) and before DRAWEDGES, which then draws
; the outline over the fill. Per ship: the light direction (in view space, a fixed vector) is
; brought into the ship's own axes with the orientation matrix (9 products), so every face needs
; three products for its brightness: the dot of its (normalised) normal with that. Per visible
; face: the polygon of its outline (a loop of vertices from tools/faceloops.py, after the faces
; in the blueprint) is scan-converted into the arrays XLTAB/XRTAB (left and right end of each
; row, clamped to the screen: faces are convex) and each row is filled with a dither pattern
; of the face's brightness (8 levels, 2-pixel-wide cells so the artifact colours stay grey).
; The faces are drawn in the blueprint's order: for convex ships only the visible faces are
; needed to get the picture right; the odd ship with a notch or slot may show a little overlap.
;
; The loop data after a blueprint's faces (one entry per face): FCB count (0: no polygon),
; then nx, ny, nz (the normal, signed, length 64) and count vertex offsets (vertex * 4 into scr).

shade   EQU SHWORK+$00               ; 1  the mode: 0 wireframe
sd_ls   EQU SHWORK+$01               ; 1  the light along the ship's side axis (signed, unity 64)
sd_lr   EQU SHWORK+$02               ; 1  along its roof axis
sd_ln   EQU SHWORK+$03               ; 1  along its nose axis
sd_f    EQU SHWORK+$04               ; 1  the face being looked at
sd_nf   EQU SHWORK+$05               ; 1  the number of faces
sd_vn   EQU SHWORK+$06               ; 1  vertices in the polygon
sd_vp   EQU SHWORK+$07               ; 2  where its vertex offsets are
sd_nx   EQU SHWORK+$09               ; 3  its normal
sd_lv   EQU SHWORK+$0C               ; 1  its brightness, 1-8
sd_pt   EQU SHWORK+$0D               ; 2  its pattern
sd_r0   EQU SHWORK+$0F               ; 1  first row to fill
sd_r1   EQU SHWORK+$10               ; 1  last row
sd_i    EQU SHWORK+$11               ; 1  counter
sd_ex0  EQU SHWORK+$12               ; 2  the edge: x0
sd_ey0  EQU SHWORK+$14               ; 2  y0
sd_ex1  EQU SHWORK+$16               ; 2  x1
sd_ey1  EQU SHWORK+$18               ; 2  y1
sd_es   EQU SHWORK+$1A               ; 2  slope, signed 8.8
sd_ea   EQU SHWORK+$1C               ; 3  x * 256, signed 24 bits
sd_er   EQU SHWORK+$1F               ; 1  the row
sd_ee   EQU SHWORK+$20               ; 1  the last row of the edge
sd_t    EQU SHWORK+$21               ; 4  scratch
sd_sg   EQU SHWORK+$25               ; 1  sign of the slope
sd_ymn  EQU SHWORK+$26               ; 2  smallest y
sd_ymx  EQU SHWORK+$28               ; 2  largest y
sd_vv   EQU SHWORK+$2A               ; 16 the polygon's vertex offsets
sd_xl   EQU SHWORK+$3A               ; 1  span: left x
sd_xr   EQU SHWORK+$3B               ; 1  right x
sd_pb   EQU SHWORK+$3C               ; 1  pattern byte of the row
sd_lm   EQU SHWORK+$3D               ; 1  left mask
sd_rm   EQU SHWORK+$3E               ; 1  right mask
sd_bl   EQU SHWORK+$3F               ; 1  left byte
sd_br   EQU SHWORK+$40               ; 1  right byte
sd_mx   EQU SHWORK+$41               ; 1  the last row of the screen
XLTAB   EQU $B800               ; 192: left ends
XRTAB   EQU $B8C0               ; 192: right ends

; (LMASK and RMASK, the masks of the bits from and up to a pixel in a byte, are in planet.asm)

; one term of the light dot: the matrix magnitude at X (and its sign byte at U) times |L| \1, the
; sign flipped when the light component is negative (\2 = $80)
LTERM   MACRO
        LDA ,X+
        LDB #\1
        MUL
        PSHS D
        LDA ,U+
        EORA #\2
        PULS D
        BPL @p
        COMA
        COMB
        ADDD #1
@p      ADDD sd_t
        STD sd_t
        ENDM

; the light (view space, towards it: left, up, and towards us) along the ship's three axes
SHLIGHT LDX #mag
        LDU #sgn
        LDY #sd_ls
        LDA #3
        STA sd_i
sdl_v    CLR sd_t
        CLR sd_t+1
        LTERM 26,$80
        LTERM 35,$00
        LTERM 47,$80
        LDD sd_t
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
        STB ,Y+
        DEC sd_i
        BNE sdl_v
        RTS

; the shaded faces of the ship in inwk, before its edges
SHADE   JSR SHLIGHT
        LDA <ymx+1
        STA sd_mx
        LDX <bp
        LDA 17,X                ; the loops follow the faces: bp + face offset + 4 * faces
        LDB 4,X
        ADDB 12,X
        ADCA #0
        ADDD <bp
        TFR D,U
        LDA 12,X
        LSRA
        LSRA
        STA sd_nf
        CLR sd_f
sd_fl   LDA ,U+
        BEQ sd_nxt
        STA sd_vn
        LDA ,U+
        STA sd_nx
        LDA ,U+
        STA sd_nx+1
        LDA ,U+
        STA sd_nx+2
        STU sd_vp
        LDB sd_vn
        LEAU B,U
        LDB sd_f
        LDX #visible
        TST B,X
        BEQ sd_nxt
        PSHS U
        BSR SHFACE
        PULS U
sd_nxt  INC sd_f
        LDA sd_f
        CMPA sd_nf
        BLO sd_fl
        RTS

; the brightness of the face and its polygon
SHFACE  LDA sd_nx
        LDB sd_ls
        JSR SMUL8
        STD <tmp
        LDA sd_nx+1
        LDB sd_lr
        JSR SMUL8
        ADDD <tmp
        STD <tmp
        LDA sd_nx+2
        LDB sd_ln
        JSR SMUL8
        ADDD <tmp
        ASRA                    ; / 64: the cosine, -64 to 64
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
        CMPB #64                ; (the sum of rounded products can stray a little)
        BLE sdf_h
        LDB #64
sdf_h    CMPB #-64
        BGE sdf_l
        LDB #-64
sdf_l    ADDB #64                ; 0 to 128
        LSRB
        LSRB
        LSRB
        LSRB
        INCB
        CMPB #8
        BLS sdf_b
        LDB #8
sdf_b    STB sd_lv
        DECB
        ASLB
        ASLB
        CLRA
        ADDD #SHPAT
        STD sd_pt
        LDD <work               ; (a polygon costs a few thousand cycles)
        ADDD #20
        STD <work

; ---- the polygon ---------------------------------------------------------------------------------
; vertices, the range of rows, the arrays, the edges, the rows
        LDU sd_vp
        LDX #sd_vv
        LDB sd_vn
        STB sd_i
sdp_c    LDA ,U+
        STA ,X+
        DEC sd_i
        BNE sdp_c
        LDD #$7FFF
        STD sd_ymn
        LDD #$8000
        STD sd_ymx
        LDU #sd_vv
        LDA sd_vn
        STA sd_i
sdp_y    LDB ,U+
        LDX #scr
        ABX
        LDD 2,X
        CMPD sd_ymn
        BGE sdp_a
        STD sd_ymn
sdp_a    CMPD sd_ymx
        BLE sdp_b
        STD sd_ymx
sdp_b    DEC sd_i
        BNE sdp_y
        LDD sd_ymx              ; wholly above or below the screen
        LBMI sdp_x
        LDD sd_ymn
        BPL sdp_a2
        LDD #0
        BRA sdp_a3
sdp_a2   CMPD <ymx
        LBGT sdp_x
sdp_a3   STB sd_r0
        LDD sd_ymx
        CMPD <ymx
        BLE sdp_t
        LDB sd_mx
sdp_t    STB sd_r1
        LDB sd_r0               ; the arrays: nothing yet
sdp_i    LDX #XLTAB
        ABX
        LDA #255
        STA ,X
        LDX #XRTAB
        ABX
        CLR ,X
        CMPB sd_r1
        BEQ sdp_e
        INCB
        BRA sdp_i
sdp_e    CLR sd_i                ; the edges: vertex i to vertex i + 1 (the last to the first)
sdp_el   LDX #sd_vv
        LDB sd_i
        ABX
        LDB ,X
        LDX #scr
        ABX
        LDD ,X
        STD sd_ex0
        LDD 2,X
        STD sd_ey0
        LDB sd_i
        INCB
        CMPB sd_vn
        BLO sdp_w
        CLRB
sdp_w    LDX #sd_vv
        ABX
        LDB ,X
        LDX #scr
        ABX
        LDD ,X
        STD sd_ex1
        LDD 2,X
        STD sd_ey1
        BSR SHEDGE
        INC sd_i
        LDA sd_i
        CMPA sd_vn
        BLO sdp_el
        LDA sd_r0               ; the rows
        STA sd_er
sdp_r    JSR SHSPAN
        LDA sd_er
        CMPA sd_r1
        BEQ sdp_x
        INC sd_er
        BRA sdp_r
sdp_x    RTS

; the edge (sd_ex0, sd_ey0) - (sd_ex1, sd_ey1): its x on each row it crosses into XLTAB/XRTAB
SHEDGE  LDD sd_ey0
        CMPD sd_ey1
        LBEQ sde_h
        BLE sde_o
        LDD sd_ex0              ; the upper end first
        LDX sd_ex1
        STX sd_ex0
        STD sd_ex1
        LDD sd_ey0
        LDX sd_ey1
        STX sd_ey0
        STD sd_ey1
sde_o    LDD sd_ey1              ; wholly off the screen above or below
        LBMI sde_x
        LDD sd_ey0
        BMI sde_n
        CMPD <ymx
        LBGT sde_x
sde_n    LDD sd_ey1              ; dy
        SUBD sd_ey0
        STD <md
        LDD sd_ex1              ; dx and its sign
        SUBD sd_ex0
        CLR sd_sg
        TSTA
        BPL sde_p
        COM sd_sg
        JSR NEGD
sde_p    STD sd_t                ; |dx|
        TFR A,B                 ; the quotient |dx| * 256 / dy, if it fits 15 bits
        CLRA
        CMPD <md
        BHS sde_sat
        CLR <mr
        LDA sd_t
        STA <mr+1
        LDA sd_t+1
        STA <mr+2
        CLR <mr+3
        JSR DIV32
        LDD <mr+2
        BPL sde_s
sde_sat  LDD #$7FFF
sde_s    TST sd_sg
        BEQ sde_q
        JSR NEGD
sde_q    STD sd_es
        LDD sd_ey0              ; the first row on the screen, and how far the edge is from it
        BPL sde_r
        LDD #0
sde_r    STB sd_er
        SUBD sd_ey0             ; t = row - y0 (>= 0)
        STD <ma
        LDD sd_es               ; s * t
        BPL sde_m
        JSR NEGD
sde_m    STD <mb
        JSR MUL16
        LDD <mr+1               ; (the middle three bytes of the 32 bit product: 24 bits)
        STD sd_t
        LDA <mr+3
        STA sd_t+2
        LDA <mr
        STA sd_t+3
        LDD sd_ex0              ; x0 * 256
        STD sd_ea
        CLR sd_ea+2
        TST sd_es
        BPL sde_a
        LDA sd_ea+2             ; minus the product
        LDD sd_ea+1
        SUBD sd_t+1
        STD sd_ea+1
        LDA sd_ea
        SBCA sd_t
        STA sd_ea
        BRA sde_l0
sde_a    LDD sd_ea+1
        ADDD sd_t+1
        STD sd_ea+1
        LDA sd_ea
        ADCA sd_t
        STA sd_ea
sde_l0   LDD sd_ey1              ; the last row
        CMPD <ymx
        BLE sde_e
        LDB sd_mx
sde_e    STB sd_ee
sde_l    LDA sd_ea               ; x, clamped to the screen
        BMI sde_c0
        BEQ sde_cm
        LDA #255
        BRA sde_cx
sde_c0   CLRA
        BRA sde_cx
sde_cm   LDA sd_ea+1
sde_cx   LDB sd_er
        BSR SHPUT
        LDD sd_ea+1             ; x += slope (the sign extended over the top byte)
        ADDD sd_es
        STD sd_ea+1
        LDA sd_es
        BPL sde_ap
        LDA sd_ea
        ADCA #$FF
        BRA sde_as
sde_ap   LDA sd_ea
        ADCA #0
sde_as   STA sd_ea
        LDA sd_er
        CMPA sd_ee
        LBEQ sde_x
        INC sd_er
        BRA sde_l
sde_h    LDD sd_ey0              ; a level edge: its two ends on its row
        LBMI sde_x
        CMPD <ymx
        LBGT sde_x
        STB sd_er
        LDA sd_ex0
        LDB sd_ex0+1
        BSR SHCLAMP
        LDB sd_er
        BSR SHPUT
        LDA sd_ex1
        LDB sd_ex1+1
        BSR SHCLAMP
        LDB sd_er
        BRA SHPUT
sde_x    RTS

; A = x clamped to 0-255 from the 16-bit number A:B
SHCLAMP TSTA
        BMI sdc_0
        BEQ sdc_m
        LDA #255
        RTS
sdc_0   CLRA
        RTS
sdc_m   TFR B,A
        RTS

; the row B has the x A: the left end gets smaller, the right end bigger
SHPUT   LDX #XLTAB
        ABX
        CMPA ,X
        BHS sdq_r
        STA ,X
sdq_r   LDX #XRTAB
        ABX
        CMPA ,X
        BLS sdq_x
        STA ,X
sdq_x   RTS

; the row sd_er from XLTAB to XRTAB with the face's pattern
SHSPAN  LDB sd_er
        LDX #XLTAB
        ABX
        LDA ,X
        STA sd_xl
        LDX #XRTAB
        ABX
        LDA ,X
        CMPA sd_xl
        BLO sds_x                ; nothing on this row
        STA sd_xr
        LDA sd_er               ; the pattern byte: row mod 4 of the face's pattern
        ANDA #3
        LDX sd_pt
        LDA A,X
        STA sd_pb
        LDA sd_er               ; the row in the screen
        LDB #32
        MUL
        ADDD <back
        TFR D,U
        LDA sd_xl
        LSRA
        LSRA
        LSRA
        STA sd_bl
        LDA sd_xr
        LSRA
        LSRA
        LSRA
        STA sd_br
        LDA sd_xl
        ANDA #7
        LDX #LMASK
        LDA A,X
        STA sd_lm
        LDA sd_xr
        ANDA #7
        LDX #RMASK
        LDA A,X
        STA sd_rm
        LDB sd_bl
        LEAY B,U                ; the first byte
        LDA sd_bl
        CMPA sd_br
        BNE sds_m
        LDA sd_lm               ; all in one byte
        ANDA sd_rm
        BRA SHMERGE
sds_m    LDA sd_lm               ; the first byte, the whole bytes, the last
        BSR SHMERGE
        LDB sd_br
        SUBB sd_bl
        DECB
        BEQ sds_l
        LDA sd_pb
sds_f    STA ,Y+
        DECB
        BNE sds_f
sds_l    LDA sd_rm
        BRA SHMERGE
sds_x    RTS

; the bits of mask A at ,Y take the pattern: old ^ ((old ^ pattern) & mask); Y moves on
SHMERGE PSHS A
        LDA ,Y
        EORA sd_pb
        ANDA ,S+
        EORA ,Y
        STA ,Y+
        RTS
