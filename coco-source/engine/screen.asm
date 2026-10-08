; Screen, vertical sync and page flipping.
;
; Two 6144-byte pages in the RAM above $8000 (A $8000, B $9800), which is never
; loaded from disk. The SAM display offset is page/512: A = 64 (F6), B = 76
; (F6,F3,F2), so flipping toggles F2 and F3.

; Tick length. The original has no frame limiter: a pass takes as long as the
; BBC needs to transform and draw the ship, so a distant dot is fast and a close
; Cobra slow (~7-8 passes/s). <work counts that effort in units of ~33us: pixels
; drawn plus VERTCOST per projected vertex plus WORKBASE for the rest of the
; loop; 512 units = one 60Hz frame.
WORKBASE EQU 200
VERTCOST EQU 30

; Redraw the whole page <back as the title background: cleared, the border of the 3D view (a line
; along the top, two pixels at each side) and the three lines of text above the dashboard. Interrupts are masked while
; S is a data pointer.
RESTORE STS <savs
        ORCC #$10
        LDD <back
        ADDD #6144
        TFR D,S
        LDA #192                ; 192 times 32 bytes
        STA <cnt
        LDD #0
        TFR D,X
        TFR D,Y
        TFR D,U
rs_lp   PSHS D,X,Y,U
        PSHS D,X,Y,U
        PSHS D,X,Y,U
        PSHS D,X,Y,U
        DEC <cnt
        BNE rs_lp
        LDS <savs
        ANDCC #$EF
        LDX <back
        LDA #$FF
        LDB #32
rs_t    STA ,X+
        DECB
        BNE rs_t
        LDX <back
        LDB #VIEWH
rs_s    LDA ,X
        ORA #$C0
        STA ,X
        LDA 31,X
        ORA #3
        STA 31,X
        LEAX 32,X
        DECB
        BNE rs_s
        LDX #TXTHEAD
        LDA #6
        LDB #1
        JSR PRAT
        LDX #TXTASK
        LDA #1
        LDB #VIEWH/8-3
        JSR PRAT
        LDX #TXTCOPY
        LDA #7
        LDB #VIEWH/8-1
        JMP PRAT

TXTHEAD FCC "---- E L I T E ----"
        FCB 0
TXTASK  FCC "  Load New Commander (Y/N)?"
        FCB 0
TXTCOPY FCC "(C) Acornsoft 1984"
        FCB 0

; 60Hz field-sync interrupt (PIA0 CB1): the game clock and keyboard scan.
IRQ     LDA $FF02
        INC <vcnt
        LDA <vcnt               ; the keyboard is scanned every other field: 30 Hz is plenty
        ANDA #1
        BNE ir_x
        JSR SCANKEYS
        JSR KLATCH              ; (a tap shorter than a frame is kept for the flight)
        STB <keytmp
        LDA <keys
        COMA
        ANDA <keytmp            ; keys that went down since the last scan
        ORA <kpress
        STA <kpress
        LDA <keytmp
        STA <keys
        JSR EGGSCAN
ir_x    RTI

; Wait for the next vsync.
WAITVS  LDA <vcnt
wv_w    CMPA <vcnt
        BEQ wv_w
        RTS

; Wait until the work done this tick (<work) has taken its time, then show the
; page just drawn and draw into the other one.
FLIP    LDD <work
        ADDD #511
        LSRA                    ; (work + 511) >> 9 vsyncs, at least 1
        BNE fl_t
        LDA #1
fl_t    STA <tmp
        LDA <vcnt
        STA <tmp2               ; always wait for a fresh vsync: the SAM offset
fl_v    CMPA <vcnt              ; must change in the blanking interval, never
        BEQ fl_v                ; mid-frame, or the picture glitches
fl_w    LDA <vcnt
        SUBA <vlast
        CMPA <tmp
        BLO fl_w
        LDA <vcnt
        STA <vlast
        LDD <back
        CMPA #$80
        BNE fl_b
        CLR $FFCA               ; show $8000 (SAM F2,F3 = 0)
        CLR $FFCC
        LDD #$9800
        STD <back
        RTS
fl_b    STA $FFCB               ; show $9800 (SAM F2,F3 = 1)
        STA $FFCD
        LDD #$8000
        STD <back
        RTS

; Hardware setup: PIAs, SAM graphics mode G6R (256x192 mono), IRQ vector.
INITHW  LDD #CY                 ; the flight view's centre and last row
        STD <cyv
        LDD #YMAX
        STD <ymx
        CLR $FF01
        CLR $FF00
        CLR $FF03
        LDA #$FF
        STA $FF02
        LDA #$3C                ; CA2 an output, high: sound source select bit A = 1
        STA $FF01
        LDA #$3D                ; CB2 high: select source 3 (none); CB1 (field sync) raises IRQ
        STA $FF03
        CLR $FF23
        LDA #$F8                ; VDG: graphics, GM = 111, CSS 1
        STA $FF22
        LDA #$34                ; CB2 output, low: keep the sound mux disabled between effects
        STA $FF23
        CLR $FF21               ; the DAC on port A: bits 2-7 outputs, then CA2 low as Color BASIC
        LDA #$FC
        STA $FF20
        LDA #$34
        STA $FF21
        LDA #$F8
        STA $FF22
        CLR $FFC0               ; SAM V = 6
        STA $FFC3
        STA $FFC5
        CLR $FFC6               ; display offset $8000 = 64*512: only F6 set
        CLR $FFC8
        CLR $FFCA
        CLR $FFCC
        CLR $FFCE
        CLR $FFD0
        STA $FFD3
        STA $FFDF               ; TY = 1: all RAM ($8000 and up included)
        LDA #$7E                ; IRQ vector, as Color BASIC routes it
        STA $010C
        LDX #IRQ
        STX $010D
        LDA #$A5
        STA <srnd
        CLR hwk
        CLR <vcnt
        CLR <vlast
        CLR <keys
        CLR <kpress
        LDD #$8000
        STD <back
        JSR RESTORE
        LDD #$9800
        STD <back
        JSR RESTORE
        RTS

; Flight view background: empty page with the original's border (a line along the
; top, 2-pixel bars down both sides), built in place.
; Clear the 3D view of the page <back (O11): what was drawn on this page two frames ago is
; on record - the bytes the stars and particles changed (a list) and the bands of 8 rows that
; lines, text, the sun and the sight crossed - and only those are cleared. The whole view is
; cleared after a screen, a bomb, in the shaded mode, and for 8 frames when 12 bands or more
; were drawn (a busy scene: the records would cost more than they save).
VIEWCLR CLR dtmp                ; the page: 0 A ($8000), 1 B
        LDA <back
        CMPA #$80
        BEQ vw_a
        INC dtmp
vw_a    LDD dsp                 ; the other page was drawn last: its list ends here
        LDX #dsend
        TST dtmp
        BNE vw_b
        STD 2,X
        BRA vw_c
vw_b    STD ,X
vw_c    LDB dtmp                ; this page's band table and list
        LDA #32
        MUL
        ADDD #DTAB
        STD dbp
        LDB dtmp
        LDA #128
        MUL
        ADDD #DLIST
        TFR D,U
        ADDD #128
        STD dse
        TST shade
        LBNE vw_full
        LDA dmoff
        BEQ vw_m
        DEC dhold
        LBNE vw_full
        CLR dmoff               ; records again: both pages whole this once
        LDD #$FFFF
        STD dfull
        LBRA vw_full
vw_m    LDX #dfull
        LDB dtmp
        TST B,X
        LBNE vw_full
        LDX #dsend              ; the list's bytes back to the background
        ASLB
        LDX B,X
        STX <tmp2
vw_e    CMPU <tmp2
        BHS vw_ed
        LDY ,U++
        TFR Y,D
        ANDB #31
        BEQ vw_e0
        CMPB #31
        BEQ vw_e3
        CLR ,Y
        BRA vw_e
vw_e0   LDA #$C0
        STA ,Y
        BRA vw_e
vw_e3   LDA #3
        STA ,Y
        BRA vw_e
vw_ed   LDX dbp                 ; the sight, if it is on this page
        TST 23,X
        BEQ vw_ns
        CLR 23,X
        LDX <back
        LEAX 32*CY+13,X
        CLR ,X
        CLR 1,X
        CLR 4,X
        CLR 5,X
        LEAX -15*32+3,X         ; the vertical arms: x = 128, CY-15 .. CY-8 and CY+8 .. CY+15
        LDB #8
vw_s1   CLR ,X
        CLR 23*32,X
        LEAX 32,X
        DECB
        BNE vw_s1
vw_ns   CLR <cnt2               ; the bands, from the bottom one up
        LDD dbp
        ADDD #18
        STD <tmp
        LDD <back
        ADDD #VIEWH*32
        STD <tmp2
        STS <savs
        ORCC #$10
vw_bl   LDX <tmp
        LDA ,-X
        STX <tmp
        TSTA
        BEQ vw_bn
        CLR ,X
        INC <cnt2
        LDS <tmp2
        LDD #0
        LDX #0
        LDY #0
        LDA #4                  ; two rows a pass
        STA <cnt
        CLRA
vw_lp   EQU *
        LDU #3                  ; row = 4 blocks of 8 bytes, pushed from its end: the last
        PSHS U,Y,X,D            ; byte is the right border bar ($03) ...
        LDU #0
        PSHS U,Y,X,D
        PSHS U,Y,X,D
        LDA #$C0                ; ... and the first the left bar ($C0)
        PSHS U,Y,X,D
        CLRA
        LDU #3
        PSHS U,Y,X,D
        LDU #0
        PSHS U,Y,X,D
        PSHS U,Y,X,D
        LDA #$C0
        PSHS U,Y,X,D
        CLRA
        DEC <cnt
        BNE vw_lp
vw_bn   LDD <tmp2
        SUBD #256
        STD <tmp2
        LDD <tmp
        CMPD dbp
        BNE vw_bl
        LDS <savs
        ANDCC #$EF
        IFDEF DIRTYCHECK
        JSR DCHECK
        ENDC
        LDA <cnt2
        CMPA #12
        BLO vw_top
        LDA #1
        STA dmoff
        LDA #30
        STA dhold
        BRA vw_top
vw_full STS <savs               ; the whole view
        ORCC #$10
        LDD <back
        ADDD #VIEWH*32
        TFR D,S
        LDD #0
        LDX #0
        LDY #0
        LDA #VIEWH/2            ; two rows a pass
        STA <cnt
        CLRA
vc_lp   EQU *
        LDU #3                  ; row = 4 blocks of 8 bytes, pushed from its end: the last
        PSHS U,Y,X,D            ; byte is the right border bar ($03) ...
        LDU #0
        PSHS U,Y,X,D
        PSHS U,Y,X,D
        LDA #$C0                ; ... and the first the left bar ($C0)
        PSHS U,Y,X,D
        CLRA
        LDU #3
        PSHS U,Y,X,D
        LDU #0
        PSHS U,Y,X,D
        PSHS U,Y,X,D
        LDA #$C0
        PSHS U,Y,X,D
        CLRA
        DEC <cnt
        BNE vc_lp
        LDS <savs
        ANDCC #$EF
        LDX dbp                 ; no records for this page
        LDB #32
vw_fz   CLR ,X+
        DECB
        BNE vw_fz
        LDX #dfull
        LDB dtmp
        CLR B,X
vw_top  LDB dtmp                ; the list starts again
        LDA #128
        MUL
        ADDD #DLIST
        STD dsp
        LDX <back               ; the border's top line
        LDD #$FFFF
        STD ,X
        STD 2,X
        STD 4,X
        STD 6,X
        STD 8,X
        STD 10,X
        STD 12,X
        STD 14,X
        STD 16,X
        STD 18,X
        STD 20,X
        STD 22,X
        STD 24,X
        STD 26,X
        STD 28,X
        STD 30,X
        RTS

; X = a byte of the view a star or particle changed: on the list (or its band if it is full)
DPIX    TST dmoff
        BNE dx_r
        LDY dsp
        CMPY dse
        BHS dx_b
        STX ,Y++
        STY dsp
dx_r    RTS
dx_b    PSHS X
        TFR X,D
        SUBD <back
        ANDA #31
        LDX dbp
        LDB #$FF
        STB A,X
        PULS X,PC

; the view's records reset: both pages cleared whole next time
DINIT   LDD #DTAB
        STD dbp
        LDD #DLIST
        STD dsp
        STD dsend
        STD dsend+2
        ADDD #128
        STD dse
        LDD #$FFFF
        STD dfull
        CLR dmoff
        RTS

; the page being drawn is cleared whole next time (the bomb's flash)
DFULLC  LDX #dfull
        LDA <back
        CMPA #$80
        BEQ dfc_a
        LEAX 1,X
dfc_a   LDA #$FF
        STA ,X
        RTS

        IFDEF DIRTYCHECK
; test: after a partial clear every byte of the view (rows 1..) must be the background;
; DIRTYFAIL is passed for a page that was not, DIRTYOK for one that was (counted in a trace)
DCHECK  LDX <back               ; (rows 8-15, the banner's band, are not tested)
        LEAX 32,X
        LDB #VIEWH-1
dk_r    CMPB #VIEWH-15
        BLO dk_t
        CMPB #VIEWH-8
        BLS dk_nx
dk_t    LDA ,X
        CMPA #$C0
        BNE dk_f
        LDA 31,X
        CMPA #3
        BNE dk_f
        LDY #30
        LEAU 1,X
dk_b    TST ,U+
        BNE dk_f
        LEAY -1,Y
        BNE dk_b
dk_nx   LEAX 32,X
        DECB
        BNE dk_r
DIRTYOK NOP
        RTS
dk_f    EQU *
DIRTYFAIL NOP
        RTS
        ENDC
