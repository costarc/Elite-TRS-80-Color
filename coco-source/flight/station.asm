; The system's bodies (SOLAR, SOS1), the space station (NWSPS and its appearance near the
; planet), docking (ISDK), and the station making way for the sun again (KS4).
;
; Positions are 24 bits; the original's x_sign byte (bit 7 the sign, bits 0-6 the top of
; the magnitude) is the high byte here, as two's complement: so "z_sign = 3" is a high byte
; of 3, and "z_sign = $81" a high byte of $FF.

; the planet: the block in inwk becomes the planet (SOS1), type 128 or, with a technology
; level with bit 1 set, 130 (a crater instead of an equator); it slowly turns
SOS1    LDA #127
        STA inwk+29
        STA inwk+30
        LDA tek
        ANDA #2
        ORA #$80
        JMP NWSHP

; the planet and the sun of a system (SOLAR), from its seeds
SOLAR   LSR fist
        JSR ZINF
        LDA qq15+1
        ANDA #3
        ADDA #3
        STA inwk+6              ; the planet 3 to 6 * 65536 ahead
        LSRA
        STA inwk                ; and to the side and above
        STA inwk+3
        JSR SOS1
        LDA qq15+3              ; the sun is behind us: 1 to 7 * 65536
        ANDA #7
        NEGA
        STA inwk+6
        LDA qq15+5
        ANDA #3
        STA inwk
        STA inwk+1
        CLR inwk+29
        CLR inwk+30
        LDA #TY_SUN
        JMP NWSHP

; the space station (NWSPS): inwk is the planet's block, moved to the station's orbit and
; turned round; AI on, rolling; the S bulb lights
NWSPS   LDA bulbs
        ORA #2
        STA bulbs
        LDA #$81
        STA inwk+32
        CLR inwk+30
        CLR inwk+35
        LDA #$FF
        STA inwk+29
        LDX #inwk+21            ; nosev the other way
        JSR NEG16
        LDX #inwk+23
        JSR NEG16
        LDX #inwk+25
        JSR NEG16
        LDA #TY_NONE            ; the station takes the sun's slot (1)
        STA slots+SLOTSZ+34
        LDA #TY_SST
        JMP NWSHP

; The sun gives way to the station when we are near the planet, every 32 loops (the part
; of MAIN after MA22): the station goes where the planet's nose points, 2 * nosev away from
; the planet; it appears once that place is within 192 * 256 of us on every axis.
MAINSTATION
        TST mj
        BNE ms2_x
        LDA sspr
        BNE ms2_x
        LDX #slots              ; the planet must be within 64K on every axis
        JSR SUMSQ               ; (this also checks that: carry set when it is not)
        BCS ms2_x
        LDX #slots              ; inwk := the planet's position and orientation
        LDU #inwk
        JSR CPY40
        LDX #inwk               ; + 2 * nosev on each axis
        LDD inwk+21
        JSR ms2_a
        LDX #inwk+3
        LDD inwk+23
        JSR ms2_a
        LDX #inwk+6
        LDD inwk+25
        JSR ms2_a
        LDA #192
        JSR FAROF2
        BCC ms2_x
        JMP NWSPS
ms2_x   RTS
ms2_a   ASLB
        ROLA
        JMP ADD24

        IFDEF ISDKLOG           ; test: a ring entry: the checks of ISDK (200 failed, 201 docked)
DKLOGX  LDX $B640
        CMPX #$B650
        BHS dx_ok
        LDX #$B650
dx_ok   CMPX #$B6F8
        BLO dx_w
        LDX #$B650
dx_w    STA ,X+
        LDA inwk+35
        STA ,X+
        LDA inwk+25
        STA ,X+
        LDA xx15+2
        STA ,X+
        LDA inwk+15
        STA ,X+
        LDA svd
        STA ,X+
        LDA <delta
        STA ,X+
        CLR ,X+
        STX $B640
        RTS
        ENDC

; ---- docking (the ISDK of MAL1) --------------------------------------------------------------
; The station is within 128 of us on every axis. Dock when the station is friendly
; and the approach and slot alignment pass the original ISDK checks. A failed
; approach is a collision; speed then determines whether it is a bump or fatal.
ISDK    LDA inwk+35
        ANDA #4
        BNE is_62
        LDA inwk+25             ; the station's nosev z: -86 or less (towards us)
        CMPA #-86
        BGT is_62
        JSR SPS1                ; original ISDK omits the planet-direction sign check
        LDA xx15+2              ; negative z also passes (returning after launch)
        CMPA #86
        BLO is_62               ; unsigned, as in the original; BLT rejects all negative z
        LDA inwk+15             ; the station's roofv across ours
        BPL is_p
        NEGA
is_p    CMPA #80
        BLO is_62
        IFDEF ISDKLOG
        LDA #201
        BSR DKLOGX
        ENDC
        JMP GOIN
is_62   EQU *
        IFDEF ISDKLOG
        LDA #200
        BSR DKLOGX
        ENDC
        LDA svd                 ; (the keys' speed: delta is scaled in the loop) a collision: too fast and it is the end, otherwise a bump
        CMPA #5
        BLO is_67
        JMP DEATH
is_67   LDA #1
        STA <delta
        LDA #5
        JSR OOPS
        JMP EXNO3

; ---- the station leaves, the sun comes back (KS4) ---------------------------------------------
; The station has been killed or left behind (slot 1 is free): the sun again, above us
KS4     JSR ZINF
        LDA #6
        STA inwk+3              ; y = 6 * 65536
        LDA bulbs
        ANDA #$FD
        STA bulbs
        CLR sspr
        LDA #TY_SUN
        JMP NWSHP

; ---- launching and docking --------------------------------------------------------------------

; reset the flight variables and the local universe (the original's RES2)
RES2    CLR escn
        LDD #CY                 ; the 3D view's centre and last row again, and the dashboard
        STD <cyv
        LDD #YMAX
        STD <ymx
        IFNE VIEWH-192
        JSR DASHINIT
        ENDC
        JSR SLOTINIT
        CLR dead
        CLR de                  ; (the original's RES2 clears the workspace up to de)
        CLR mde
        CLR <view
        IFDEF FLYVIEW           ; test: start in this view
        LDA #FLYVIEW
        STA <view
        ENDC
        JSR STARINIT
        CLR <jstx
        CLR <jsty
        CLR <alpha
        CLR <beta
        LDA #255
        STA <mcnt
        CLR ecma
        CLR ecmp
        CLR auto
        JSR TIMERESET
        CLR mj                  ; (witchspace is left)
        CLR hnum
        CLR dly
        LDA bulbs
        ANDA #$FC
        STA bulbs
        LDA #$FF
        STA mstg
        CLR msar
        LDA #3
        STA <delta
        RTS

; launch: the planet ahead, the station just behind us, a new set of ship blueprints
LAUNCH  JSR RES2
        LDA #48
        JSR NOISE               ; the ship launches
        JSR TUNNEL              ; the tunnel out of the hangar
        JSR LOMOD
        JSR ZINF                ; the planet 1 * 65536 ahead
        LDA #1
        STA inwk+6
        JSR SOS1
        JSR ZINF                ; the station 256 behind
        LDD #$FFFF              ; z = -256
        STD inwk+6
        JSR NWSPS
        LDA #12
        STA <delta
        IFDEF FLYSTILL
        CLR <delta
        ENDC
        JSR BAD                 ; carrying contraband makes us wanted
        ORA fist
        STA fist
        CLR docked
        RTS

; the ship blueprints for this system (LOMOD): bit 0 the technology (Coriolis or Dodo station),
; bit 1 the government (the safer ones), bits 2-3 random: one of the original's 16 files A-P
LOMOD   JSR THERE               ; the Constrictor's system has file G
        BCC lm_n
        LDA #6
        JMP SETSHIPSET
lm_n    JSR DORND
        ANDA #3
        ASLA
        LDB gov
        CMPB #3
        BLO lm_a
        ORA #1
lm_a    ASLA
        LDB tek
        CMPB #10
        BLO lm_b
        ORA #1
lm_b    TFR A,B
        LDA tp                  ; with the Thargoid plans on board: a file with Thargoids
        ANDA #$0C
        CMPA #$08
        BNE lm_t
        TFR B,A
        ANDA #1
        ORA #2
        JMP SETSHIPSET
lm_t    TFR B,A
        JMP SETSHIPSET

; we have docked: the flight is over until we launch (GOIN)
GOIN    EQU *
        IFDEF DOCKCNT           ; test: how many times we have docked ($B191), the deaths ($B192)
        INC $B191
        ENDC
        LDA #2
        STA docked
        RTS
