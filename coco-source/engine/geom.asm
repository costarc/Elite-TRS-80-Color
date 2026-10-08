; Exact planar-vertex transform and immutable view banners. Loaded once at $B600.
; Y points at the vertex/matrix sign masks. U and Y are preserved.
GYROW   MACRO
        LDA <vax
        LDB <mag+\1
        MUL
        EORA \1,Y
        EORB \1,Y
        STD <acc
        TST 3+\1,Y              ; zero Y still contributes $FFFF for a negative mask
        BEQ @zero
        LDD <acc
        SUBD #1
        STD <acc
@zero   LDA <vaz
        LDB <mag+6+\1
        MUL
        EORA 6+\1,Y
        EORB 6+\1,Y
        ADDD <acc
        ENDM

VERTY0  GYROW 0
        JSR [gshptr]
        ADDD <xp
        BVC gy_x
        BSR gy_sat
gy_x    STD <xr
        GYROW 1
        JSR [gshptr]
        ADDD <yp
        BVC gy_y
        BSR gy_sat
gy_y    STD <yr
        GYROW 2                 ; caller applies the original Z shift/clamp/perspective
        RTS

gy_sat  TSTA
        BMI gy_positive
        LDD #$8000
        RTS
gy_positive LDD #$7FFF
        RTS

        INCLUDE "gen/viewbanner.inc"
