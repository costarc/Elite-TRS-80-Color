; Micro-benchmarks (build with BENCH). Each routine runs N times between two
; vsync counter reads; the result is the number of 1/60 s ticks, shown as hex in
; the order of the table below. Time per call = ticks * 16.67 ms / N.
;
; 13 calibration: 200 x 224 cycles = 44800 cycles
;  0 LL9 whole ship, z=3000   (N=10)    8 SUN K=35         (N=20)
;  1 LL9 whole ship, z=400    (N=10)    9 32 lines ~60 px  (N=10)
;  2 MKMAT                    (N=100)  10 MVEIT            (N=50)
;  3 FACEVIS                  (N=20)   11 VIEWCLR          (N=10)
;  4 TRANSFORM                (N=20)   12 TIDY             (N=50)
;  5 DRAWEDGES                (N=20)
;  6 STARS                    (N=20)
; 14 FLYDRAW, whole frame   (N=5)
;  7 PLANET K=20              (N=20)

BRUN    MACRO
        JSR WAITVS
        LDA <vcnt
        STA bt0
        LDA #\2
        STA bcnt
@l      JSR \3
        DEC bcnt
        BNE @l
        LDA <vcnt
        SUBA bt0
        STA bres+\1
        ENDM

; the Cobra at (0,0,\1) turned a bit, in inwk
BSHIP   MACRO
        JSR SLOTINIT
        SETPOS 0,0,\1
        LDA #TY_CYL
        LDB #0
        JSR NEWSHIP
        LDX #SHIP_COBRA_MK_3
        STX <bp
        LDA #20
        STA cnt3
@t      JSR TMVEIT
        DEC cnt3
        BNE @t
        ENDM

; calibration: 100 NOPs = 200 cycles
CAL1    FILL $12,100
        RTS

BLINES  LDA #32
        STA cnt3
bl_l    LDA cnt3               ; 32 lines of different slopes about the centre
        ASLA
        ASLA
        ASLA
        STA <lx1
        LDA #128
        STA <lx0
        LDA #60
        STA <ly0
        LDA cnt3
        ASLA
        ADDA #40
        STA <ly1
        JSR LINE
        DEC cnt3
        BNE bl_l
        RTS

BENCHGO LDD #$4953
        STD <rand
        LDD #$4844
        STD <rand+2
        JSR STARINIT
        LDA #8
        STA <delta
        CLR <alpha
        CLR <beta
        LDD #$8000
        STD <back
        ANDCC #$EF
        IFDEF LNTEST
        JSR VIEWCLR
        LDD #$0A14              ; (10,20) - (120,50)
        STD <lx0
        LDD #$7832
        STD <lx1
        JSR LINE
        LDD #$0A64              ; (10,100) - (100,100)
        STD <lx0
        LDD #$6464
        STD <lx1
        JSR LINE
        LDD #$1478              ; (20,120) - (60,130)
        STD <lx0
        LDD #$3C82
        STD <lx1
        JSR LINE
        LDD #$C8A0              ; (200,160) - (150,100) up
        STD <lx0
        LDD #$9664
        STD <lx1
        JSR LINE
        LDD #$0A9B              ; (10,155) - (120,125) shallow up
        STD <lx0
        LDD #$787D
        STD <lx1
        JSR LINE
        LDD #$C814              ; (200,20) - (250,10) shallow up, short
        STD <lx0
        LDD #$FA0A
        STD <lx1
        JSR LINE
        LDD #$0632
        STD <lx0
        LDD #$0932
        STD <lx1
        JSR LINE
        LDD #$073C
        STD <lx0
        LDD #$083C
        STD <lx1
        JSR LINE
        LDD #$0546
        STD <lx0
        LDD #$0C48
        STD <lx1
        JSR LINE
        LDD #$FA50
        STD <lx0
        LDD #$FD51
        STD <lx1
        JSR LINE
        LDD #$645A
        STD <lx0
        LDD #$675A
        STD <lx1
        JSR LINE
        LDD #$655F
        STD <lx0
        LDD #$685F
        STD <lx1
        JSR LINE
        LDD #$0F1E
        STD <lx0
        LDD #$181E
        STD <lx1
        JSR LINE
        JSR FLIP
ln_t    BRA ln_t
        ENDC
        IFDEF BFLY
        LBRA bn_fly
        ENDC
        BSHIP 3000
        LDA #$80
        STA inwk+31
        BRUN 0,10,LL9
        BSHIP 400
        BRUN 1,10,LL9
        BSHIP 3000
        BRUN 2,100,MKMAT
        JSR LL9                 ; leaves scale, positions, faces and vertices ready
        BRUN 3,20,FACEVIS
        BRUN 4,20,TRANSFORM
        BRUN 5,20,DRAWEDGES
        IFDEF ONESTAR
        LDA #SN
        STA <nostm
        BRUN 6,100,STARS
        ELSE
        IFDEF N40
        BRUN 6,40,STARS
        ELSE
        BRUN 6,20,STARS
        ENDC
        ENDC
        SETPOS 400,150,1500
        LDA #0
        LDB #0
        JSR NEWSHIP
        LDA #128
        STA inwk+34
        LDA #20
        STA cnt3
        BRUN 7,20,PLANET
        SETPOS -250,-150,700
        LDA #0
        LDB #0
        JSR NEWSHIP
        LDA #129
        STA inwk+34
        BRUN 8,20,PLANET
        BRUN 9,10,BLINES
        BSHIP 3000
        LDA #3
        STA <alpha
        LDA #1
        STA <beta
        BRUN 10,50,MVEIT
        BRUN 11,10,VIEWCLR
        BSHIP 3000
        BRUN 12,50,TIDY
        BRUN 13,200,CAL1
bn_fly  JSR FLYINIT
        JSR FLYSHIPS
        ;             ; the six ship test scene, whole frames without the flip
        LDA #8
        STA <delta
        IFDEF PROFLOOP
pl_l    JSR FLYDRAW
        BRA pl_l
        ENDC
        BRUN 14,5,FLYDRAW
bn_show JSR VIEWCLR             ; one bar per result: length = ticks (pixels)
        CLR cnt3
bn_b    LDX #bres
        LDB cnt3
        ABX
        LDA ,X
        CMPA #240
        BLS bn_c
        LDA #240
bn_c    ADDA #8
        STA <lx1
        LDA #8
        STA <lx0
        LDA cnt3
        ASLA
        ASLA
        ASLA
        ADDA #20
        JSR HLINE
        INC cnt3
        LDA cnt3
        CMPA #15
        BLO bn_b
        JSR FLIP
        BRA bn_show
