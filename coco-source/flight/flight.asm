; Flight: the player's controls and the ship loop (first version, test scene).
;
; Player controls follow the original: LEFT/RIGHT roll and UP/DOWN pitch by
; changing the rates jstx/jsty (+7 roll, +14 pitch per tick, centring by 2 / 1),
; SPACE faster (max 40), '/' slower (min 1). The rates become the small angles
; alpha and beta that MVEIT uses to swing the sky around us.

; (A) signed rate in A moves one step toward 0 -> A
CNTR    TSTA
        BEQ cn_r
        BMI cn_u
        DECA
        RTS
cn_u    INCA
cn_r    RTS

; A = rate, B = step: A = clamp(A + B, -127, 127)
BUMPR   STB <tmp
        TFR A,B
        SEX                     ; D = rate (sign extended)
        STD <tmp2
        LDA <tmp
        TFR A,B
        SEX                     ; D = step (signed)
        ADDD <tmp2
        CMPD #127
        BLE br_a
        LDB #127
        BRA br_c
br_a    CMPD #-127
        BGE br_c
        LDB #-127
br_c    TFR B,A
        RTS

; |jstx| / 8 below 32, / 4 above;  alpha = -sign(jstx) * that
PLAYERANG
        LDA <jstx
        PSHS A
        BPL pa_x
        NEGA
pa_x    LSRA
        LSRA
        CMPA #8
        BHS pa_y
        LSRA
pa_y    TST ,S+
        BMI pa_z                ; negative rate (left): alpha positive
        NEGA                    ; positive rate (right): alpha negative
pa_z    STA <alpha
        LDA <jsty               ; beta = sign(jsty) * (|jsty|+4) / 16, halved below 3
        PSHS A
        BPL pb_x
        NEGA
pb_x    ADDA #4
        LSRA
        LSRA
        LSRA
        LSRA
        CMPA #3
        BHS pb_y
        LSRA
pb_y    TST ,S+
        BPL pb_z
        NEGA
pb_z    STA <beta
        RTS

; one tick of player input (original order: centre, set angles, then keys)
PLAYERTICK
        IFDEF FLYROLL                   ; test: pretend RIGHT is held
        LDA #R3
        STA <kmat+6
        ENDC
        IFDEF FLYPITCH                  ; test: pretend UP is held
        LDA #R3
        STA <kmat+3
        ENDC
        LDA <jstx
        JSR CNTR
        JSR CNTR
        STA <jstx
        LDA <jsty
        JSR CNTR
        STA <jsty
        JSR PLAYERANG
        TST auto
        BEQ pt_m
        JSR AUTODOCK            ; the docking computer flies
        LBRA pt_6
pt_m    LDA <kmat+1             ; Q: the sound full, short, off
        BITA #R2
        BEQ pt_q0
        TST qlast
        BNE pt_q1
        LDA snd                 ; full, short combat sounds, off, in turn
        INCA
        CMPA #3
        BLO pt_qs
        CLRA
pt_qs   STA snd
        LDA #1
        STA qlast
        BRA pt_q1
pt_q0   CLR qlast
pt_q1   LDA <kmat+6             ; RIGHT: roll right
        BITA #R3
        BEQ pt_1
        LDA <jstx
        LDB #7
        JSR BUMPR
        STA <jstx
pt_1    LDA <kmat+5             ; LEFT: roll left
        BITA #R3
        BEQ pt_2
        LDA <jstx
        LDB #-7
        JSR BUMPR
        STA <jstx
pt_2    LDA <kmat+3             ; UP: pitch up
        BITA #R3
        BEQ pt_3
        LDA <jsty
        LDB #14
        JSR BUMPR
        STA <jsty
pt_3    LDA <kmat+4             ; DOWN: pitch down
        BITA #R3
        BEQ pt_4
        LDA <jsty
        LDB #-14
        JSR BUMPR
        STA <jsty
pt_4    LDA <kmat+7             ; SPACE: faster
        BITA #R3
        BEQ pt_5
        LDA <delta
        CMPA #40
        BHS pt_5
        INC <delta
pt_5    LDA <kmat+7             ; '/': slower
        BITA #R5
        BEQ pt_6
        DEC <delta
        BNE pt_6
        INC <delta
pt_6    LDA <kmat               ; the digits: 0-3 front, rear, left, right view (the original's
        BITA #R4                ; f0-f3), 4-9 the charts, data, market, status, inventory
        BEQ pt_v1
        CLRA
        JMP SETVIEW
pt_v1   LDA <kmat+1
        BITA #R4
        BEQ pt_v2
        LDA #1
        JMP SETVIEW
pt_v2   LDA <kmat+2
        BITA #R4
        BEQ pt_v3
        LDA #2
        JMP SETVIEW
pt_v3   LDA <kmat+3
        BITA #R4
        BEQ pt_v4
        LDA #3
        JMP SETVIEW
pt_v4   LDA <kmat+4
        BITA #R4
        BEQ pt_s5
        LDA #'4'
        STA scrreq
pt_s5   LDA <kmat+5
        BITA #R4
        BEQ pt_s6
        LDA #'5'
        STA scrreq
pt_s6   LDA <kmat+6
        BITA #R4
        BEQ pt_s7
        LDA #'6'
        STA scrreq
pt_s7   LDA <kmat+7
        BITA #R4
        BEQ pt_s8
        LDA #'7'
        STA scrreq
pt_s8   LDA <kmat
        BITA #R5
        BEQ pt_s9
        LDA #'8'
        STA scrreq
pt_s9   LDA <kmat+1
        BITA #R5
        BEQ pt_sx
        LDA #'9'
        STA scrreq
pt_sx   RTS

; ---- the docking computer (the original's auton, in DOKEY) -------------------------------------
; A ship at the origin pointing along z, as the player's ship is, goes through DOCKIT; what
; it answers (speed, acceleration, roll and pitch counters) becomes our speed and the same
; steps the roll and pitch keys would make.
; (the steps are the keys' 7 and 14, with the original's auto-recentre: BUMPA)
ADROLL  EQU 7
ADPITCH EQU 14
AUTODOCK
        JSR ZINF
        LDA #96
        STA inwk+25             ; nosev along z
        LDA #$A0
        STA inwk+9              ; sidev along -x
        STA inwk+34             ; type -96: not a ship of the universe
        LDA <delta
        STA inwk+27
        JSR DOCKIT
        IFDEF DOCKLOG
        IFNDEF DOCKLOGALL
        LDA dkpath              ; (only when the branch changes)
        CMPA dklast
        BEQ dl_skip
        STA dklast
        ENDC
        ENDC
        IFDEF DOCKLOG           ; test: 8 bytes a call at $B650 (a ring to $B6F8): path, K, xx15, delta, roll, pitch counters; $B640 the pointer
        LDX $B640
        CMPX #$B650
        BHS dl_ok
        LDX #$B650
dl_ok   CMPX #$B6F8
        BLO dl_w
        LDX #$B650
dl_w    LDA dkpath
        STA ,X+
        LDA $B193
        STA ,X+
        LDA $B194
        STA ,X+
        LDA $B195
        STA ,X+
        LDA $B196
        STA ,X+
        LDA <jstx
        STA ,X+
        LDA <jsty
        STA ,X+
        LDA <alpha
        STA ,X+
        STX $B640
dl_skip  EQU *
        ENDC
        LDA inwk+27             ; at most 22 while docking
        CMPA #22
        BLO ad_s
        LDA #22
ad_s    STA <delta
        LDA inwk+28
        BEQ ad_r
        BMI ad_d
        LDA <delta              ; accelerating: one faster
        CMPA #40
        BHS ad_r
        INC <delta
        BRA ad_r
ad_d    DEC <delta
        BNE ad_r
        INC <delta
ad_r    LDA inwk+29             ; the roll counter becomes a roll step (or 64, a firm roll)
        BEQ ad_r0
        ASLA                    ; carry: negative
        TFR CC,B
        TSTA
        BPL ad_rs
        LDA #-64                ; the original's firm roll (its rate 64): measured on our station, -64 holds the
        BRA ad_rj               ; roll of the station (ROLLTEST), +64 doubled it and lost the slot
ad_rs   LDA <jstx
        BITB #1
        BNE ad_rn
        LDB #-ADROLL
        BRA ad_rb
ad_rn   LDB #ADROLL
ad_rb   JSR BUMPA
ad_rj   STA <jstx
        BRA ad_q
ad_r0   CLR <jstx
ad_q    LDA inwk+30             ; and the pitch counter a pitch step
        BEQ ad_q0
        ASLA
        TFR CC,B
        LDA <jsty
        BITB #1
        BNE ad_qn
        LDB #-ADPITCH
        BRA ad_qb
ad_qn   LDB #ADPITCH
ad_qb   JSR BUMPA
        STA <jsty
        RTS
ad_q0   CLR <jsty
        RTS

; the original's BUMP2/REDU2 with the keyboard auto-recentre it has on by default (DJD = 0): A = rate,
; B = step; a step that does not carry the rate over to the side the step points to sets it to zero (a
; key against the rate we have centres it at once). This is what keeps the docking computer from
; thrashing: when its counter changes sign the rate is zero, and builds up again from there
BUMPA   PSHS B
        JSR BUMPR
        TST ,S+
        BMI bu_n
        TSTA
        BPL bu_x
        CLRA
        RTS
bu_n    TSTA
        BMI bu_x
        CLRA
bu_x    RTS

; ---- test scene --------------------------------------------------------------------

; position (x,y,z) of a test ship as signed 16-bit values, sign-extended to
; 24 bits in the spawn scratch
SETPOS  MACRO
        LDD #\1
        STD spawn+1
        LDA #0
        TST spawn+1
        BPL @p1
        LDA #$FF
@p1     STA spawn+0
        LDD #\2
        STD spawn+4
        LDA #0
        TST spawn+4
        BPL @p2
        LDA #$FF
@p2     STA spawn+3
        LDD #\3
        STD spawn+7
        LDA #0
        TST spawn+7
        BPL @p3
        LDA #$FF
@p3     STA spawn+6
        ENDM

; ADDT type, speed, roll counter, pitch counter  (position already in spawn)
ADDT    MACRO
        LDA #\1
        LDB #\2
        JSR NEWSHIP
        LDA #\3
        STA inwk+29
        LDA #\4
        STA inwk+30
        LDA #\1
        JSR NWSHP
        ENDM

FLYINIT JSR DINIT
        LDA #1
        IFDEF SNDSHORT                  ; test: short combat sounds
        LDA #2
        ENDC
        STA snd
        LDA #1
        IFDEF FLYSWEEP
        CLR swn
        CLR swt
        ENDC
        CLR dead                ; (the test scenes start alive)
        CLR de                  ; no " DESTROYED" pending (RAM is not clear at power-up)
        CLR mde
        IFDEF SHADEON           ; test: the shaded mode
        STA shade
        ENDC
        LDD #CY
        STD <cyv
        LDD #YMAX
        STD <ymx
        CLRA
        JSR SETSHIPSET          ; ship set A (Lave's)
        JSR SLOTINIT
        IFNE VIEWH-192
        JSR DASHINIT            ; the dashboard rows, once
        ENDC
        CLR <view
        IFDEF FLYVIEW           ; test: start in this view
        LDA #FLYVIEW
        STA <view
        ENDC
        LDD #$4953              ; the original seed
        STD <rand
        LDD #$4844
        STD <rand+2
        JSR STARINIT
        LDA #8
        STA <delta
        JSR PLAYERINIT
        CLR <jstx
        CLR <jsty
        CLR <mcnt
        LDD #$4953              ; the original seed
        STD <rand
        LDD #$4844
        STD <rand+2
        IFDEF FLYALT                    ; test: far enough for an altitude
        SETPOS 400,150,30000
        ELSE
        SETPOS 400,150,1500       ; the planet: type 128 in a slot of its own
        ENDC
        LDA #TY_PLANET
        LDB #0
        JSR NEWSHIP
        LDA #TY_PLANET
        JSR NWSHP
        SETPOS -250,-150,700      ; the sun: type 129
        LDA #TY_SUN
        LDB #0
        JSR NEWSHIP
        LDA #TY_SUN
        JSR NWSHP
        RTS

; the six ship test scene's ships (and some values to see on the dashboard, a laser in
; every view)
FLYSHIPS
        LDA #200
        STA ash
        LDA #210
        STA energy
        LDA #40
        STA cabtmp
        LDA #15
        STA laser+1
        STA laser+2
        STA laser+3
        LDA #3
        STA bulbs
        IFDEF FLYDIE                    ; test: weak, so the ships kill us
        CLR fsh
        CLR ash
        LDA #12
        STA energy
        ENDC
        IFDEF FLYGRID                   ; test: five Cobras round the screen at the same depth
        SETPOS 400,0,1000
        ADDT TY_CYL,0,0,0
        SETPOS -400,0,1000
        ADDT TY_CYL,0,0,0
        SETPOS 0,300,1000
        ADDT TY_CYL,0,0,0
        SETPOS 0,-300,1000
        ADDT TY_CYL,0,0,0
        SETPOS 280,280,1000
        ADDT TY_CYL,0,0,0
        ENDC
        IFDEF FLYGRID9                  ; test: nine Cobras on a 3 x 3 grid, 2048 away
        SETPOS 0,0,2048
        ADDT TY_CYL,0,0,0
        SETPOS 150,0,2048
        ADDT TY_CYL,0,0,0
        SETPOS -150,0,2048
        ADDT TY_CYL,0,0,0
        SETPOS 0,150,2048
        ADDT TY_CYL,0,0,0
        SETPOS 0,-150,2048
        ADDT TY_CYL,0,0,0
        SETPOS 150,150,2048
        ADDT TY_CYL,0,0,0
        SETPOS -150,-150,2048
        ADDT TY_CYL,0,0,0
        SETPOS 150,-150,2048
        ADDT TY_CYL,0,0,0
        SETPOS -150,150,2048
        ADDT TY_CYL,0,0,0
        ENDC
        IFDEF FLYTUMBLE                 ; test: one Cobra that tumbles in place, 2048 ahead of us (we stand still)
        SETPOS FLYHX,FLYHY,2048
        ADDT TY_CYL,0,$7F,$7F
        CLR <delta
        ENDC
        IFDEF FLYHORZ                   ; test: one Cobra at FLYHX,FLYHY,1000 (to roll past)
        SETPOS FLYHX,FLYHY,FLYHDEP*256
        ADDT TY_CYL,0,0,0
        ENDC
        IFNDEF FLYMIN
        SETPOS 0,0,3500
        ADDT TY_CYL,3,$7F,$00
        SETPOS -1500,400,5000
        ADDT TY_COPS,10,$00,$FF
        SETPOS 1800,-300,6000
        ADDT TY_PYT,3,$00,$7F
        SETPOS 600,900,2500
        ADDT TY_KRA,6,$FF,$00
        SETPOS -900,-500,4000
        ADDT TY_MAM,8,$00,$FF
        SETPOS 200,-200,1800
        ADDT TY_SH3,0,$7F,$7F
        ENDC
        IFDEF FLYAI                     ; test: the ships are hostile, with AI
        LDA #NSLOTS-1
        STA <cnt
fa_l    LDA <cnt
        JSR SLOTADDR
        LDA 34,X
        BMI fa_n
        LDA #$E0
        STA 32,X
        LDA 35,X
        ORA #4
        STA 35,X
fa_n    DEC <cnt
        BPL fa_l
        ENDC
        IFDEF FLYSTILL                  ; test: nothing moves but the sky
        CLR <delta
        LDA #NSLOTS-1
        STA <cnt
fy_l    LDA <cnt
        JSR SLOTADDR
        CLR 27,X
        CLR 29,X
        CLR 30,X
        DEC <cnt
        BPL fy_l
        ENDC
        RTS

; A new game: Cobra Mk III in space, the planet and the sun (the docked start, the
; launch and the station come later), then the flight, forever.
NEWGAME LDS #$0600
        CLR eggarm
        CLR <paused
        CLR dead
        JSR FLYINIT
        LDD #$9800
        STD <back
        ANDCC #$EF
        JSR NEWCMDR             ; Jameson, docked at Lave
        LDA #1
        STA docked
ng_l    TST docked
        BNE ng_k
        JSR FLYFRAME
        LDA scrreq
        BEQ ng_q
        CLR scrreq
        JSR FLIGHTSCR
ng_q    TST escr
        BEQ ng_e
        CLR escr
        JSR ESCAPE
ng_e    EQU *
        TST dead
        BEQ ng_l
        JSR DEATHSEQ
        JMP restart
ng_k    LDA docked              ; 2: we flew in (the tunnel), 1: the game starts docked
        CMPA #2
        BNE ng_t
        JSR RES2
        JSR TUNNEL
        LDA #1
        STA docked
ng_t    JSR HALL                ; the hangar, with the ships still loaded
        JSR GODOCKED            ; docked until we launch
        JSR LAUNCH
        BRA ng_l

; docked: bring in the docked screens (over the ship blueprints), run them, and read the blueprints
; back (the original loads its docked and flight code in turn too)
GODOCKED
        JSR GVL                 ; the market of the day
        LDA #SEG_DOCK
        JSR LOADSEG
        BCC gd_o
gd_h    BRA gd_h
gd_o    JSR DOCKENTRY
        LDA #SEG_SHIPS
        JSR LOADSEG
        BCS gd_h
        RTS

; a screen in flight (the keys 4-9): bring in the screens, show them until the digits 0-3 or
; the H key, then read the blueprints back. The flight waits meanwhile.
FLIGHTSCR
        PSHS A
        LDA #SEG_DOCK
        JSR LOADSEG
        BCS gd_h
        PULS A
        JSR FSCRENTRY
        PSHS A
        LDA #SEG_SHIPS
        JSR LOADSEG
        BCS gd_h
        LDD #CY                 ; the 3D view's centre and last row, the dashboard on both pages
        STD <cyv
        LDD #YMAX
        STD <ymx
        IFNE VIEWH-192
        JSR DASHINIT
        ENDC
        LDD <back               ; (what was drawn on is on show: draw on the other page)
        CMPA #$80
        BNE fls_a
        LDD #$9800
        BRA fls_b
fls_a    LDD #$8000
fls_b    STD <back
        JSR TIMERESET
        PULS A
        JMP SETVIEW

; the escape pod (ESCAPE): our Cobra flies off without us, we lose the cargo, the fuel tank is
; full on delivery, and we are in the docking bay
ESCAPE  JSR RES2
        LDB #TY_CYL
        JSR FRS1
        BCS es_1
        LDB #TY_CYL2
        JSR FRS1
es_1    BCC es_d
        JSR SLOTLOAD
        LDA #8
        STA inwk+27
        LDA #194
        STA inwk+30
        CLR inwk+32
        JSR SLOTSAVE
es_d    LDA #48
        STA escn
es_l    JSR FLYFRAME
        DEC escn
        BNE es_l
        CLRA
        LDX #qq20
        LDB #17
es_c    STA ,X+
        DECB
        BNE es_c
        CLR fist
        CLR escp
        LDA #70
        STA qq14
        JMP GOIN

TXTOVER FCC "GAME OVER"
        FCB 0

; the death (DEATH, DEATH2): the dashboard is gone, GAME OVER, a few things flying out of
; the wreck, for about 5 seconds; then the title screen again
DEATHSEQ
        JSR EXNO3
        ASL <delta
        ASL <delta
        LDD #$8000              ; clear the dashboard rows of both pages
        BSR dq_c
        LDD #$9800
        BSR dq_c
        LDA #3
        STA tt2
dq_s    JSR ZINF                ; a canister or plate close by, tumbling
        JSR DORND
        STA tt1
        LSRA
        LSRA
        TFR A,B
        CLRA
        LDX #inwk
        JSR PUTPOS
        JSR DORND
        STA tt1
        LSRA
        LSRA
        EORA #$2A
        TFR A,B
        CLRA
        LDX #inwk+3
        JSR PUTPOS
        JSR DORND
        LSRA
        LSRA
        ORA #$50
        STA inwk+8
        JSR DORND
        ANDA #$8F
        STA inwk+29
        RORA
        ANDA #$87
        STA inwk+30
        TFR B,A
        ANDA #$0F
        STA inwk+27
        LDA tt2
        ANDA #1
        ADDA #TY_PLT
        JSR NWSHP
        DEC tt2
        BNE dq_s
        LDA #24
        STA dcnt
dq_l    JSR FLYFRAME
        DEC dcnt
        BNE dq_l
        RTS
dq_c    ADDD #DASHY*32
        TFR D,X
        LDY #(192-DASHY)*16
        LDD #0
dq_z    STD ,X++
        LEAY -1,Y
        BNE dq_z
        RTS

        IFDEF FLYSWEEP
; stress test: every loop the Cobra in slot 2 goes to a random place well inside the view
; (|x|, |y| <= z/4, z 6..37 * 256) while it tumbles; SWEEPLOG notes every time LL9 drew nothing
swn     EQU $B640               ; 1 failures logged
swz     EQU $B641               ; 1 z_hi of the ship now
swt     EQU $B642               ; 1 loops tested
SWBASE  EQU slots+2*SLOTSZ
SWEEPSET JSR DORND
        ANDA #31
        ADDA #2
        STA swz
        CLR SWBASE+6
        STA SWBASE+7
        CLR SWBASE+8
        JSR DORND
        LDB swz
        JSR SMULU
        ASRA
        RORB
        STD SWBASE+1
        LDA #0
        TST SWBASE+1
        BPL sws_1
        LDA #$FF
sws_1   STA SWBASE
        JSR DORND
        LDB swz
        JSR SMULU
        ASRA
        RORB
        STD SWBASE+4
        LDA #0
        TST SWBASE+4
        BPL sws_2
        LDA #$FF
sws_2   STA SWBASE+3
        INC swt
        RTS

; D = <work before LL9; if it is the same now, nothing was drawn: log position, orientation
SWEEPLOG LDA inwk+34
        CMPA #TY_CYL
        BNE swl_x
        CMPD <work
        BNE swl_x
        LDA swn
        CMPA #12
        BHS swl_x
        LDB #14
        MUL
        ADDD #$B650
        TFR D,U
        LDX #inwk
        LDD 1,X
        STD ,U++
        LDD 4,X
        STD ,U++
        LDA 7,X
        STA ,U+
        LDA inwk+9
        STA ,U+
        LDA inwk+11
        STA ,U+
        LDA inwk+13
        STA ,U+
        LDA inwk+15
        STA ,U+
        LDA inwk+17
        STA ,U+
        LDA inwk+19
        STA ,U+
        LDA inwk+21
        STA ,U+
        INC swn
swl_x   RTS
        ENDC

; ---- game time (the frame rate does not change how fast the game runs) --------------------------
; fstep = how many loops of the reference game (REFTICKS vsyncs each) went by since the last
; frame: 0 to FSTEPMAX; the remainder is carried to the next frame
TIMESTEP
        LDA <vcnt
        TFR A,B
        SUBA tpre
        STB tpre
        CMPA #REFTICKS*FSTEPMAX
        BHS ts_max
        STA ftick               ; the vsyncs themselves, for the motion (SCALEON)
        ADDA tacc
        CLRB
ts_d    CMPA #REFTICKS
        BLO ts_e
        SUBA #REFTICKS
        INCB
        BRA ts_d
ts_e    STA tacc
ts_s    STB fstep
        IFDEF TIMELOG           ; test: $B185 = the ticks passed, $B187 = the reference loops given (16 bits each)
        PSHS B
        LDA #0
        LDB tpre
        SUBB tlog+4
        PSHS B
        LDB tpre
        STB tlog+4
        PULS B
        ADDD tlog
        STD tlog
        PULS B
        CLRA
        ADDD tlog+2
        STD tlog+2
        ENDC
        RTS
ts_max  CLR tacc
        LDA #REFTICKS*FSTEPMAX
        STA ftick
        LDB #FSTEPMAX
        BRA ts_s

; with the docking computer on, a frame is one loop of the game (as the computer was made for): it
; reads the station's place once a frame and steers by it, so the loops that went by since cannot be
; steered, and its corrections overshoot (it missed the slot and circled)
AUTOTIME
        TST auto
        BEQ at_x
        LDA #REFTICKS
        STA ftick
        LDA #1
        STA fstep
        CLR tacc
at_x    RTS

; start the clock again (after a screen, a launch or a jump)
TIMERESET
        JSR KCLEAR
        JSR DINIT               ; (after a screen: the view is cleared whole on both pages)
        LDA <vcnt
        STA tpre
        CLR tacc
        RTS

; A = signed rate per loop -> the motion of this frame: rate * ftick / REFTICKS (the vsyncs
; that went by, so the view moves on every frame, not only on the frames a loop of the game
; went by), within +-<tmp; the remainder (in 1/6 of a unit) is carried at ,X, so the motion
; adds up to rate * loops exactly. <tmp2 = the clamp * 6.
SCT     TSTA
        BEQ sq_z
        PSHS A
        BPL sq_p
        NEGA
sq_p    LDB ftick
        MUL
        ADDB ,X
        ADCA #0
        CMPD <tmp2
        BHS sq_c
        LDY #8                  ; D / 6 (the high byte is below 6: eight steps of a 16/8
                                ; division)
sq_d    ASLB
        ROLA
        CMPA #REFTICKS
        BLO sq_n
        SUBA #REFTICKS
        INCB
sq_n    LEAY -1,Y
        BNE sq_d
        STA ,X
        TFR B,A
        BRA sq_s
sq_c    CLR ,X
        LDA <tmp
sq_s    TST ,S+
        BPL sq_r
        NEGA
sq_r    RTS
sq_z    CLR ,X
        RTS

; roll, pitch and speed as they move the sky and the ships in one frame (the keys' values
; are kept in sva, svb, svd; ISDK and the like go by those)
SCALEON LDD #127*REFTICKS
        STD <tmp2
        LDA #127
        STA <tmp
        LDX #srem
        LDA <alpha
        STA sva
        BSR SCT
        STA <alpha
        STA sca
        LDX #srem+1
        LDA <beta
        STA svb
        BSR SCT
        STA <beta
        STA scb
        LDD #160*REFTICKS
        STD <tmp2
        LDA #160
        STA <tmp
        LDX #srem+2
        LDA <delta
        STA svd
        BSR SCT
        STA <delta
        STA scd
        LDA fstep
        STA mvn
        RTS

; the keys' values back, unless the loop changed them (a bump, a new start)
SCALEOFF
        LDA <alpha
        CMPA sca
        BNE sf_1
        LDA sva
        STA <alpha
sf_1    LDA <beta
        CMPA scb
        BNE sf_2
        LDA svb
        STA <beta
sf_2    LDA <delta
        CMPA scd
        BNE sf_3
        LDA svd
        STA <delta
sf_3    LDA #1
        STA mvn
        CLR duem
        CLR duem+1
        RTS

        IFDEF DOCKSET
; test: the station 1500 ahead, its nose (the slot's side) towards us, its roof across, the planet far
; behind it: the computer's ideal approach, to see whether it can dock from it
SETDOCK LDX #slots+SLOTSZ
        LDB #27
sd_z    CLR ,X+
        DECB
        BNE sd_z
        LDX #slots+SLOTSZ
        LDA #5
        STA 7,X
        LDA #$DC
        STA 8,X
        IFEQ DOCKSET-2          ; 2: seen from the side: its nose points to the left, the planet is on the right
        LDA #96
        STA 17,X                ; roofv y
        LDA #$A0
        STA 21,X                ; nosev x = -1
        STA 13,X                ; sidev z (roofv x nosev)
        LDX #slots
        CLR 6,X
        LDA #$17
        STA 1,X
        LDA #$70
        STA 2,X
        LDA #5
        STA 7,X
        LDA #$DC
        STA 8,X
        ELSE
        LDA #96
        STA 15,X
        LDA #$A0
        STA 11,X
        STA 25,X
        LDX #slots
        CLR 6,X
        LDA #$2E
        STA 7,X
        LDA #$E0
        STA 8,X
        ENDC
        LDA #12
        STA <delta
        RTS
        ENDC

; one frame of the test scene
FLYFRAME
        JSR FLYDRAW
        LDD #0                  ; (game time is the vsyncs: no minimum frame time in flight)
        STD <work
        JMP FLIP

; everything but the page flip (also run by the benchmark)
FLYDRAW
        JSR VIEWCLR
        IFDEF FLYSWEEP          ; SWEEPLOG still uses the vertex work counter
        LDD #WORKBASE
        ELSE
        LDD #0
        ENDC
        STD <work
        IFDEF FLYBOOM                   ; test: a Cobra (slot 2) appears and blows up, repeatedly
        LDA <mcnt
        ANDA #127
        BNE fb_1
        LDA #2
        STA <slotn
        SETPOS 0,0,2000
        LDA #TY_CYL
        LDB #0
        JSR NEWSHIP
        JSR SLOTPUT
        BRA fb_n
fb_1    CMPA #24
        BNE fb_n
        LDA #2
        STA <slotn
        JSR SLOTLOAD
        JSR EXPSTART
        JSR SLOTSAVE
fb_n    EQU *
        ENDC
        IFDEF FLYSCR            ; test: a screen key after a few loops
        LDA <mcnt
        SUBA #FLYSCRAT
        CMPA fstep
        BHS fs_t1
        LDA #FLYSCR
        STA scrreq
fs_t1   EQU *
        ENDC
        IFDEF FLYBOMB           ; test: an energy bomb goes off
        LDA <mcnt
        SUBA #FLYBOMB
        CMPA fstep
        BHS fs_t3
        LDA #$7F
        STA bomb
        ASL bomb
fs_t3   EQU *
        ENDC
        IFDEF FLYAUTO           ; test: the docking computer comes on
        LDA <mcnt
        SUBA #FLYAUTO
        CMPA fstep
        BHS fs_t5
        LDA #$FF
        STA dkcmp
        STA auto
fs_t5   EQU *
        ENDC
        IFDEF FLYMSG            ; test: the in-flight message token FLYMSG (with DESTROYED if FLYMDE)
        LDA <mcnt
        SUBA #2
        CMPA fstep
        BHS fs_tm
        IFDEF FLYMDE
        LDA #3
        STA de
        ENDC
        LDA #FLYMSG
        JSR MESS
fs_tm   EQU *
        ENDC
        IFDEF FLYGHY            ; test: the galactic hyperdrive
        LDA <mcnt
        SUBA #FLYGHY
        CMPA fstep
        BHS fs_t6
        LDA #$FF
        STA ghyp
        JSR GHY
fs_t6   EQU *
        ENDC
        IFDEF FLYESC            ; test: the escape pod
        LDA <mcnt
        SUBA #FLYESC
        CMPA fstep
        BHS fs_t4
        LDA #$FF
        STA escp
        LDA #1
        STA escr
fs_t4   EQU *
        ENDC
        IFDEF FLYJUMP           ; test: a jump to a neighbouring system
        LDA <mcnt
        SUBA #6
        CMPA fstep
        BHS fs_t2
        LDA qq0
        ADDA #FLYJUMP
        STA qq9
        LDA qq1
        STA qq10
        JSR HYP
fs_t2   EQU *
        ENDC
        JSR SIGHT
        JSR TIMESTEP
        JSR AUTOTIME
        JSR KMERGE
        LDB fstep               ; the controls: a step for every loop of the reference game, so
        BEQ pt_k0               ; the rates build up as fast whatever the frame rate; a frame
pt_lp   PSHS B                  ; with no loop only reads the view and screen keys
        JSR PLAYERTICK
        PULS B
        DECB
        BNE pt_lp
        BRA pt_kd
pt_k0   JSR pt_6
pt_kd   EQU *
        JSR PLAYSTATE
        LDB fstep               ; what the loops of the reference game do, once for each
        BEQ lt_x
lt_l    PSHS B
        JSR LOOPTICK
        PULS B
        DECB
        BNE lt_l
lt_x    EQU *
        IFDEF ROLLTEST          ; test: a fixed roll rate, and a log of the station's orientation
        LDA #ROLLTEST
        STA <jstx
        JSR PLAYERANG
        ENDC
        JSR SCALEON
        IFNDEF SKIPSTARS
        JSR STARS
        ENDC
        IFDEF FLYSWEEP
        JSR SWEEPSET
        ENDC
        JSR SHIPLOOP
        JSR SCALEOFF
        IFDEF ROLLTEST
        LDX $B640
        CMPX #$B650
        BHS rl_ok
        LDX #$B650
rl_ok   CMPX #$B6F8
        BLO rl_w
        LDX #$B650
rl_w    LDA #210
        STA ,X+
        LDA slots+SLOTSZ+15
        STA ,X+
        LDA slots+SLOTSZ+17
        STA ,X+
        LDA slots+SLOTSZ+19
        STA ,X+
        LDA slots+SLOTSZ+9
        STA ,X+
        LDA slots+SLOTSZ+25
        STA ,X+
        LDA <alpha
        STA ,X+
        LDA <jstx
        STA ,X+
        STX $B640
        ENDC
        TST dead
        BNE fd_dd
        JSR BANNER
        IFNE VIEWH-192
        JSR DASHFRAME
        ENDC
        BRA fd_ok
fd_dd   JSR DFULLC              ; (no banner over the old one: the view is cleared whole)
        LDX #TXTOVER            ; we are dead: no dashboard, GAME OVER
        LDB #12
        JSR PRCENT
fd_ok   EQU *
        JSR MSGDRAW
        JSR HYPTICK
        IFDEF DIAG                      ; test ROM: ship slots 2-5 and the player's motion in hex on the view
        LDX #slots+2*SLOTSZ
        LDB #9
        LDA #1
        JSR DBGROW
        LDX #slots+2*SLOTSZ+31
        LDB #5
        LDA #2
        JSR DBGROW
        LDX #slots+3*SLOTSZ
        LDB #9
        LDA #3
        JSR DBGROW
        LDX #slots+3*SLOTSZ+31
        LDB #5
        LDA #4
        JSR DBGROW
        LDX #slots+4*SLOTSZ
        LDB #9
        LDA #5
        JSR DBGROW
        LDX #slots+4*SLOTSZ+31
        LDB #5
        LDA #6
        JSR DBGROW
        LDX #slots+5*SLOTSZ
        LDB #9
        LDA #7
        JSR DBGROW
        LDX #slots+5*SLOTSZ+31
        LDB #5
        LDA #8
        JSR DBGROW
        LDX #delta
        LDB #6
        LDA #9
        JSR DBGROW
        ENDC
        IFDEF DEBUG
        LDX #mcnt
        LDB #1
        LDA #0
        JSR DBGROW
        LDX #work
        LDB #2
        LDA #1
        JSR DBGROW
        ENDC
        RTS

; one loop of the reference game: the counter, what is recharged, cooled and counted down, the
; checks every 32nd loop, the encounters when the counter wraps; the ships' schedule (the bit of
; duem for this count) is taken by SHIPLOOP
LOOPTICK
        INC <mcnt
        LDA <mcnt
        ANDA #15
        ASLA
        LDX #BITS16
        LDD A,X
        ORA duem
        ORB duem+1
        STD duem
        JSR PLAYREGEN
        JSR PLAYCHECK
        JSR ECMTICK
        LDA dly
        BEQ lk_d
        DEC dly
lk_d    EQU *
        IFDEF FLYSPAWN                  ; test: the encounters every 16 loops
        LDA <mcnt
        ANDA #15
        ELSE                            ; the original: when the loop counter wraps
        LDA <mcnt
        ENDC
        BNE lk_x
        JSR MAINSPAWN
lk_x    RTS

BITS16  FDB $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080
        FDB $0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000

; ---- the in-flight messages on the view (MESS is in flight/jump.asm) ----------------------------
; draw the message that is up, and the hyperspace countdown, into the view (every frame).
; The message is set in type once, into MBUF (row 17 of a page whose <back points there; a
; line feed would spill into the next 256 bytes, and such a text is drawn every frame
; instead), and from then on the columns it used are ORed into the view: the glyphs are ORed
; as well, so the picture is the same; a beep in the text sounds once, as in the original
MSGDRAW LDA dly
        LBEQ md_h
        LDA mvalid
        BMI md_d                ; not to be kept: drawn every frame
        BNE md_c
        LDX #MBUF               ; set it in type
        LDD #0
mg_z    STD ,X++
        CMPX #MBUF+256
        BNE mg_z
        LDD <back
        PSHS D
        LDD #MBUF-17*256
        STD <back
        LBSR MSGTXT
        PULS D
        STD <back
        LDA yc
        CMPA #17
        BEQ mg_ok
        LDA #$FF                ; it left its row
        STA mvalid
md_d    LBSR MSGTXT
        LBRA md_h
mg_ok   LBSR MSGCEN
        LDA xc
        STA mxc
        LDA qq17
        STA mq17
        LDA #1
        STA mvalid
md_c    LDX dbp                 ; (O11: band 17)
        LDA #$FF
        STA 17,X
        LDA mxc                 ; OR columns mcol .. mxc-1 of the 8 rows into the view
        SUBA mcol
        BLS mg_n
        STA <tmp
        LDX #MBUF
        LDB mcol
        ABX
        LDD <back
        ADDD #17*256
        TFR D,U
        LDB mcol
        LEAU B,U
        LDA #8
        STA <cnt
mg_r    LDB <tmp
mg_b    LDA ,X+
        ORA ,U
        STA ,U+
        DECB
        BNE mg_b
        LDB #32
        SUBB <tmp
        ABX
        LEAU B,U
        DEC <cnt
        BNE mg_r
mg_n    LDA mxc                 ; the text state as the drawing leaves it
        STA xc
        LDA #17
        STA yc
        LDA mq17
        STA qq17
md_h    LDA hnum
        BEQ md_r
        LDA #1                  ; the countdown, top left
        STA xc
        STA yc
        CLR qq17
        LDB hnum
        CLRA
        TFR D,X
        ANDCC #$FE
        LDA #2
        JSR TT11
        LDA #7                  ; HYPERSPACE -NAME at the bottom
        STA xc
        LDA #16
        STA yc
        CLR qq17
        LDA #189
        JSR TT27
        LDA #'-'
        JSR TT27
        JSR cpl
md_r    RTS

; the message, set in type at column 9, moved to the middle of the 32 columns (a beep in it has
; sounded once already): xc leaves with the column after its end
MSGCEN  LDA xc
        SUBA #9
        BLS mq_x
        CMPA #30
        BHS mq_x
        STA <tmp                ; its length
        LDA #32
        SUBA <tmp
        LSRA
        STA mcol
        SUBA #9
        BEQ mq_x
        STA <tmp2               ; how far it moves (signed)
        LDA #8
        STA <cnt
        LDX #MBUF+9
mq_r    LDA <tmp2
        BMI mq_l
        LEAU A,X                ; to the right: the last byte first
        LDB <tmp
mq_d    DECB
        LDA B,X
        STA B,U
        TSTB
        BNE mq_d
        LDB <tmp2               ; and the bytes it left clear
mq_c    DECB
        CLR B,X
        TSTB
        BNE mq_c
        BRA mq_n
mq_l    LEAU A,X                ; to the left: the first byte first
        CLRB
mq_m    LDA B,X
        STA B,U
        INCB
        CMPB <tmp
        BNE mq_m
        LDA <tmp2
        NEGA
mq_e    DECB
        CLR B,X
        DECA
        BNE mq_e
mq_n    LEAX 32,X
        DEC <cnt
        BNE mq_r
        LDA xc
        ADDA <tmp2
        STA xc
mq_x    RTS

; the message's text at column mcol, row 17 of <back
MSGTXT  CLR qq17
        LDA mcol
        STA xc
        LDA #17
        STA yc
        LDA mch
        JSR TT27
        TST mde
        BEQ mx_r
        LDA #253                ; DESTROYED
        JMP TT27
mx_r    RTS
