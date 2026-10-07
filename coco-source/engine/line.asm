; Line drawing and viewport clipping. DP=$02, framebuffer at <back.
;
; CLIPLINE  clips (cx0,cy0)-(cx1,cy1), 16-bit signed, to the viewport with
;           Cohen-Sutherland, then calls LINE. The edge intersections use the
;           exact 16x16->32 multiply and 32/16 divide, so a vertex that is
;           thousands of pixels off screen still gives the right slope.
; LINE      (draws with EOR, like the original: crossings and overlaps invert)
;           Bresenham with an 8-bit error term: SUBB/BCC/ADDB, the borrow is
;           the "step the minor axis" decision. Four specialised loops (major
;           axis x/y, minor direction up/down): constant +-32 row step, no
;           multiply and no stack traffic in the hot paths.
;           Endpoints must already lie inside the viewport.

; <occ = outcode of the 16-bit point at ,X (x) 2,X (y):
;   1 left, 2 right, 4 above, 8 below
OC16    CLR <occ
        LDD ,X
        CMPD #XMIN
        BLT oc_xl
        CMPD #XMAX
        BLE oc_y
        LDA #2
        STA <occ
        BRA oc_y
oc_xl   LDA #1
        STA <occ
oc_y    LDD 2,X
        CMPD #YMIN
        BLT oc_yl
        CMPD <ymx
        BLE oc_done
        LDA <occ
        ORA #8
        STA <occ
        RTS
oc_yl   LDA <occ
        ORA #4
        STA <occ
oc_done RTS

; Move the point at ,X onto the boundary <cbound along its first coordinate
; (offset 0; the other coordinate is at offset 2). U points at the other end.
; The point is outside the boundary and the other end is not, so
; |bound-p| <= |q-p| and the quotient fits 16 bits:
;   p2 += sign(q2-p2) * |bound-p1| * |q2-p2| / |q1-p1|
CLIPAX  LDD ,U
        CMPD ,X
        BGE ca_d1
        LDD ,X
        SUBD ,U
        BRA ca_d2
ca_d1   SUBD ,X
ca_d2   STD <md
        LDD <cbound
        CMPD ,X
        BGE ca_a1
        LDD ,X
        SUBD <cbound
        BRA ca_a2
ca_a1   SUBD ,X
ca_a2   STD <ma
        CLR <csg
        LDD 2,U
        CMPD 2,X
        BGE ca_s1
        LDD 2,X
        SUBD 2,U
        COM <csg
        BRA ca_s2
ca_s1   SUBD 2,X
ca_s2   STD <mb
        JSR MUL16
        JSR DIV32
        LDD <mr+2
        TST <csg
        BPL ca_add
        JSR NEGD
ca_add  ADDD 2,X
        STD 2,X
        LDD <cbound
        STD ,X
        RTS

; swap the x and y words of the points at ,X and ,U (clip along y = clip along
; x on swapped coordinates)
SWAPXY  LDD ,X
        LDY 2,X
        STY ,X
        STD 2,X
        LDD ,U
        LDY 2,U
        STY ,U
        STD 2,U
        RTS

CLIPLINE
cl_next LDX #cx0
        JSR OC16
        LDA <occ
        STA <c0
        LDX #cx1
        JSR OC16
        LDA <occ
        STA <c1
        ORA <c0
        BEQ cl_draw
        LDA <c0
        ANDA <c1
        BNE cl_out              ; both beyond the same edge: nothing to draw
        LDA <c0
        BEQ cl_p1
        LDX #cx0
        LDU #cx1
        LDB <c0
        BRA cl_go
cl_p1   LDX #cx1
        LDU #cx0
        LDB <c1
cl_go   BITB #12
        BEQ cl_xb
        BITB #4
        BEQ cl_ymx
        LDD #YMIN               ; horizontal edge: clip along y
        BRA cl_yb
cl_ymx  LDD <ymx
cl_yb   STD <cbound
        BSR SWAPXY
        JSR CLIPAX
        BSR SWAPXY
        BRA cl_next
cl_xb   BITB #1
        BEQ cl_xmx
        LDD #XMIN
        BRA cl_xb2
cl_xmx  LDD #XMAX
cl_xb2  STD <cbound
        JSR CLIPAX
        BRA cl_next
cl_draw LDA cx0+1               ; inside: the low bytes are the pixel coordinates
        STA <lx0
        LDA cy0+1
        STA <ly0
        LDA cx1+1
        STA <lx1
        LDA cy1+1
        STA <ly1
        BRA LINE
cl_out  RTS

LONGX   EQU 9                    ; shallow lines longer than this use the two-ended loops
LINE    EQU *
        TST dmoff               ; the bands it crosses (O11)
        BNE ln_m
        LDA <ly0
        LSRA
        LSRA
        LSRA
        LDB <ly1
        LSRB
        LSRB
        LSRB
        STB dtmp
        CMPA dtmp
        BLS ln_m1
        STA dtmp
        TFR B,A
ln_m1   LDX dbp
        LEAX A,X
        LDB #$FF
ln_ml   STB ,X+
        INCA
        CMPA dtmp
        BLS ln_ml
ln_m    EQU *
        IFDEF CULLCHECK
        TST cullf
        BEQ ln_cc
CULLFAIL NOP
ln_cc   EQU *
        ENDC
        LDA <lx1                ; order the end points left to right
        SUBA <lx0
        BHS ln_ok
        NEGA                    ; dx = old lx0 - old lx1
        STA <ldx8
        LDD <lx0
        LDX <lx1
        STD <lx1
        STX <lx0
        BRA ln_o2
ln_ok   STA <ldx8               ; dx
ln_o2   EQU *
        LDA <ly1
        SUBA <ly0
        BHS ln_dn
        NEGA
        LDB #1
        BRA ln_dy
ln_dn   CLRB
ln_dy   STA <ldy8               ; |dy|
        STB <lup
        LDA <ly0                ; screen address of the start
        LDB #32
        MUL
        ADDD <back
        TFR D,X
        LDB <lx0
        LSRB
        LSRB
        LSRB
        ABX
        LDA <ldx8
        CMPA <ldy8
        LBLO ln_ymaj
        CMPA #LONGX
        LBLS ln_slowx           ; short: the plain loop is as quick
        LDB <lx1                ; shallow: from both ends, a byte count each
        LSRB
        LSRB
        LSRB
        LDA <lx0
        LSRA
        LSRA
        LSRA
        STA <tmp
        SUBB <tmp               ; d = last byte - first byte
        LBEQ ln_slowx           ; all in one byte: the plain loop
        STB <tmp
        ADDB #2
        LSRB                    ; left half: (d+2)/2 bytes
        STB <fcnt
        LDA <tmp
        INCA
        SUBA <fcnt
        STA <fcnt2              ; right half: the rest
        LDA <lx0
        ANDA #7
        ASLA
        TST <lup
        BNE ln_fu
        LDY #FDENT
        LDY A,Y                 ; entry point for the start bit
        LDB <ldx8
        LSRB                    ; error = dx/2
        CLRA
        JMP ,Y
ln_fu   LDY #FUENT
        LDY A,Y
        LDB <ldx8
        LSRB
        CLRA
        JMP ,Y
ln_right
        LDA <ly1                ; the right half: from the end point leftwards
        LDB #32
        MUL
        ADDD <back
        TFR D,X
        LDB <lx1
        LSRB
        LSRB
        LSRB
        ABX
        LDA <fcnt2
        STA <fcnt
        LDA <lx1
        ANDA #7
        ASLA
        TST <lup
        BNE ln_ru
        LDY #RDENT
        BRA ln_rj
ln_ru   LDY #RUENT
ln_rj   LDY A,Y
        LDB <ldx8
        LSRB
        CLRA
        JMP ,Y
ln_slowx
        LDA <lx0                ; start bit mask
        ANDA #7
        LDY #MASKS
        LDA A,Y
        STA <mask
        CLRA                    ; x major: dx+1 pixels
        LDB <ldx8
        TFR D,Y
        LEAY 1,Y
        LSRB                    ; error = dx/2
        TST <lup
        BNE xl_up
xl_dn   LDA ,X
        EORA <mask
        STA ,X
        LEAY -1,Y
        BEQ ln_done
        LSR <mask
        BCC xd_s
        LDA #$80
        STA <mask
        LEAX 1,X
xd_s    SUBB <ldy8
        BCC xl_dn
        ADDB <ldx8
        LEAX 32,X
        BRA xl_dn
xl_up   LDA ,X
        EORA <mask
        STA ,X
        LEAY -1,Y
        BEQ ln_done
        LSR <mask
        BCC xu_s
        LDA #$80
        STA <mask
        LEAX 1,X
xu_s    SUBB <ldy8
        BCC xl_up
        ADDB <ldx8
        LEAX -32,X
        BRA xl_up
ln_done RTS
ln_ymaj
        LDA <lx0                ; start bit mask
        ANDA #7
        LDY #MASKS
        LDA A,Y
        STA <mask
        CLRA                    ; y major: dy+1 pixels
        LDB <ldy8
        TFR D,Y
        LEAY 1,Y
        LSRB
        TST <lup
        BNE yl_up
yl_dn   LDA ,X
        EORA <mask
        STA ,X
        LEAY -1,Y
        BEQ ln_done
        LEAX 32,X
        SUBB <ldx8
        BCC yl_dn
        ADDB <ldy8
        LSR <mask
        BCC yl_dn
        LDA #$80
        STA <mask
        LEAX 1,X
        BRA yl_dn
yl_up   LDA ,X
        EORA <mask
        STA ,X
        LEAY -1,Y
        BEQ ln_done
        LEAX -32,X
        SUBB <ldx8
        BCC yl_up
        ADDB <ldy8
        LSR <mask
        BCC yl_up
        LDA #$80
        STA <mask
        LEAX 1,X
        BRA yl_up
MASKS   FCB $80,$40,$20,$10,$08,$04,$02,$01


        INCLUDE "gen/linefast.inc"
