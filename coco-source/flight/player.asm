; The player's ship: energy, shields, the lasers, the sight and the view's name.
;
; Per frame (the original's main loop): the laser cools (GNTMP -1), every 8th loop the
; shields recharge when the energy is above half and the energy itself goes up; the fire
; key (A) shoots the laser of the current view when it is fitted and not overheated
; (GNTMP < 242): four lines from the sight to the bottom of the view, +8 laser
; temperature and 1 energy (LASLI). A pulse laser fires once a frame here (its 10
; vsync gap is shorter than a frame).

; the defaults of a new commander: full shields and energy, 7.0 light years of fuel, a
; pulse laser in front
PLAYERINIT
        LDA #255
        STA fsh
        STA ash
        STA energy
        STA altit
        LDA #70
        STA qq14
        LDA #30
        STA cabtmp
        CLR gntmp
        CLR bomb
        CLR engy
        CLR dkcmp
        CLR ghyp
        CLR escp
        LDA #22
        STA crgo
        CLR ecma
        CLR ecmp
        CLR ecm
        CLR mj
        CLR bst
        CLR fist
        CLR ev
        CLR tp
        CLR msar
        CLR auto
        LDA #$FF
        STA mstg
        LDA #3                  ; Lave: a democracy
        STA gov
        LDX #qq20               ; an empty hold
        LDB #17
pi_h    CLR ,X+
        DECB
        BNE pi_h
        CLR bulbs
        LDA #3
        STA nomsl
        LDA #15                 ; POW: a pulse laser
        STA laser
        CLR laser+1
        CLR laser+2
        CLR laser+3
        RTS

; one loop of the energy, shield and laser logic
; once a loop of the reference game: the laser cools, every 8th loop the shields and the energy recharge
PLAYREGEN
        LDA gntmp               ; the laser cools
        BEQ ps_a
        DEC gntmp
ps_a    LDA <mcnt
        ANDA #7
        BNE ps_r
        LDA energy              ; above half: the shields recharge (SHD: +1, no wrap)
        BPL ps_e
        LDA ash
        INCA
        BEQ ps_f
        STA ash
ps_f    LDA fsh
        INCA
        BEQ ps_e
        STA fsh
ps_e    LDA energy              ; energy + 1 (+ 1 with an energy unit), no wrap
        ADDA engy
        BCS ps_r
        ADDA #1
        BCS ps_r
        STA energy
ps_r    RTS

; once a frame: the laser (the pulse laser pulses 5 times a second whatever the frame rate, as the
; original's LASCT does; a beam laser fires every frame, and does a loop's worth of heat and damage
; for every loop of the reference game that went by) and the keys that act now
PLAYSTATE
        CLR las
        IFDEF FLYFIRE           ; test: pretend A is held
        LDA #1
        STA <kmat+1
        ENDC
        LDA <kmat+1             ; A: fire
        BITA #1
        BEQ ps_x
        LDA gntmp
        CMPA #242
        BHS ps_x
        LDX #laser
        LDA <view
        LDA A,X
        BEQ ps_x
        LDB #1                  ; (shots: 1 for a pulse laser)
        STB lshots
        TSTA
        BMI ps_b
        LDB <vcnt               ; a pulse laser: 12 vsyncs since the last pulse
        SUBB lastp
        CMPB #12
        BLO ps_x
        LDB <vcnt
        STB lastp
        BRA ps_p
ps_b    LDB fstep               ; a beam laser: a shot for every loop of the reference game
        BNE ps_s
        INCB
ps_s    STB lshots
ps_p    ANDA #$7F
        LDB lshots
        PSHS A
        MUL                     ; the power of all the shots
        TSTA
        BNE ps_m
        CMPB #127
        BLS ps_o
ps_m    LDB #127
ps_o    STB las
        PULS A
        CLRA
        JSR NOISE               ; the sound of our laser
        BRA LASLI
ps_x    JMP PLAYMISS

; the laser beams (LASLI): from a random point near the sight to the bottom of the view
LASLN   MACRO
        LDD lasxy
        STD <lx0
        LDD #\1*256+VIEWH-1
        STD <lx1
        JSR LINE
        ENDM

LASLI   JSR DORND
        ANDA #7
        ADDA #124
        PSHS A
        JSR DORND
        ANDA #7
        ADDA #CY-4
        TFR A,B
        PULS A
        STD lasxy
        LASLN 32
        LASLN 224
        LASLN 48
        LASLN 208
        LDA lshots              ; the heat and the energy of every shot
        LDB #8
        MUL
        ADDB gntmp
        BCC la_h
        LDB #255
la_h    STB gntmp
        LDB lshots
la_e    DEC energy              ; DENGY: not below 1
        BNE la_n
        INC energy
la_n    DECB
        BNE la_e
la_r    RTS

; the sight (TT15, drawn twice by the original, 20 and 10 big, the second erasing the
; middle of the first): a gap at the centre, 10 pixels long arms horizontally, 8 rows
; vertically; only when the view has a laser. EOR, like everything else.
SIGHTX  MACRO
        LDA #\1
        EORA \2,X
        STA \2,X
        ENDM

SIGHT   LDX #laser
        LDA <view
        LDA A,X
        BEQ si_r
        LDX dbp                 ; (O11: slot 23 of the band table: the sight is on this page)
        STA 23,X
        LDX <back
        LEAX 32*CY+13,X         ; the horizontal arms: x 108-117 and 139-148
        SIGHTX $0F,0
        SIGHTX $FC,1
        SIGHTX $1F,4
        SIGHTX $F8,5
        LDX <back
        LEAX 32*(CY-15)+16,X    ; the vertical arms: x = 128
        LDB #8
si_u    LDA ,X
        EORA #$80
        STA ,X
        LEAX 32,X
        DECB
        BNE si_u
        LEAX 15*32,X            ; (the middle, CY-7 .. CY+7, is skipped)
        LDB #8
si_d    LDA ,X
        EORA #$80
        STA ,X
        LEAX 32,X
        DECB
        BNE si_d
si_r    RTS

; "FRONT VIEW" etc. at the top of the view (row 1, column 11 of 8x8 cells)
BANNER  LDA <view               ; (stored whole every frame: O11 need not clear it)
        LDB #70
        MUL
        ADDD #VIEWBANNER
        TFR D,X
        LDU <back
        LEAU 8*32+11,U
        LDB #7
bn_r    LDY ,X++
        STY ,U++
        LDY ,X++
        STY ,U++
        LDY ,X++
        STY ,U++
        LDY ,X++
        STY ,U++
        LDY ,X++
        STY ,U++
        LEAU 22,U
        DECB
        BNE bn_r
        LDY #0                  ; every uppercase banner has a blank bottom row
        STY ,U
        STY 2,U
        STY 4,U
        STY 6,U
        STY 8,U
        LEAU 32,U
        RTS

; ---- altitude and cabin temperature (MA22 of the original's main loop) ---------------
; X -> a slot: A = (xh^2 + yh^2 + zh^2) / 256 (MAS3: xh the middle byte of the position's
; magnitude, the sum saturating at 255), carry clear; carry set when any coordinate is
; 65536 or more away (MAS2).
SQ1     MACRO
        LDA \1,X
        BEQ @p
        INCA
        LBNE sq_far
        LDA \1+1,X
        COMA
        BRA @s
@p      LDA \1+1,X
@s      TFR A,B
        MUL
        ADDA psum
        BCC @n
        LDA #$FF
@n      STA psum
        ENDM

SUMSQ   CLR psum
        SQ1 0
        SQ1 3
        SQ1 6
        LDA psum
        ANDCC #$FE
        RTS
sq_far  ORCC #1
        RTS

; A = type (128 planet, 129 sun): X -> its slot, carry set if there is none
FINDTYPE
        PSHS A
        CLR <slotn
ft_l    LDA <slotn
        JSR SLOTADDR
        LDA 34,X
        CMPA ,S
        BEQ ft_f
ft_n    INC <slotn
        LDA <slotn
        CMPA #NSLOTS
        BLO ft_l
        PULS A
        ORCC #1
        RTS
ft_f    PULS A
        ANDCC #$FE
        RTS

; every 32nd loop (MA22): the station appears (loop 0), the energy warning and the altitude
; (loop 10: crashing into the planet is the end), the docking computer's message (15), the
; cabin temperature from the sun (20: burning up is the end; with fuel scoops near the sun
; they fill the tank). None of it in witchspace.
PLAYCHECK
        IFDEF AUDITSAFE                 ; benchmark: no altitude/heat death in the test scene
        RTS
        ENDC
        TST mj
        BNE pk_x
        LDA <mcnt
        ANDA #31
        CMPA #10
        BNE pk_t
        LDA #50                 ; the energy warning
        CMPA energy
        BLO pk_e
        LDA #100
        JSR MESS
pk_e    LDA #255
        STA altit
        LDA #128
        JSR FINDTYPE
        BCS pk_x
        JSR SUMSQ
        BCS pk_x
        SUBA #37
        BCS pk_c                ; (the 6809 carry is a borrow)
        PSHS A                  ; altitude = sqrt(R * 256 + zh), R = the sum less the planet's size
        LDA 7,X                 ; zh, the magnitude of z's middle byte
        TST 6,X
        BEQ pk_q
        COMA
pk_q    TFR A,B
        PULS A
        JSR ISQRT16
        STB altit
        TSTB
        BNE pk_x
pk_c    JMP DEATH               ; below the surface: the crash
pk_x    RTS
pk_t    CMPA #15
        BNE pk_u
        TST auto
        BEQ pk_x
        LDA #123                ; DOCKING COMPUTERS ON
        JMP MESS
pk_u    CMPA #20
        BEQ pk_h
        TSTA
        BNE pk_x
        JMP MAINSTATION         ; every 32nd loop: is the station near enough to appear?
pk_h    LDA #30
        STA cabtmp
        TST sspr
        BNE pk_x                ; (not inside the station's safe zone)
        LDA #129
        JSR FINDTYPE
        BCS pk_x
        JSR SUMSQ
        BCS pk_x
        COMA                    ; 255 - A + 30, burning at 256
        ADDA #30
        STA cabtmp
        BCS pk_c
        CMPA #224
        BLO pk_x
        TST bst
        BEQ pk_x
        LDA <delta              ; fuel scooping: speed / 8 (and the carry) tenths a time
        LSRA
        LSRA
        LSRA
        ADCA qq14
        CMPA #70
        BLS pk_f
        LDA #70
pk_f    STA qq14
        LDA #160                ; FUEL SCOOPS ON
        JMP MESS

; a new commander (the original's default): JAMESON at Lave with 100 credits, 7 light years
; of fuel, a pulse laser in front and three missiles
NEWCMDR JSR PLAYERINIT
        LDX #DEFNA
        LDU #na
        LDB #9
nc_n    LDA ,X+
        STA ,U+
        DECB
        BNE nc_n
        LDA #20
        STA qq0
        LDA #173
        STA qq1
        STA qq10
        LDA #20
        STA qq9
        LDX #DEFSEED
        LDU #qq21
        LDB #6
nc_s    LDA ,X+
        STA ,U+
        DECB
        BNE nc_s
        LDD #0
        STD cash
        LDD #1000
        STD cash+2
        CLR gcnt
        CLR kills
        CLR kills+1
        IFDEF MISS1             ; test: Competent already
        LDA #1
        STA kills
        ENDC
        IFDEF MISS2
        LDA #6
        STA kills
        LDA #2
        STA tp
        ENDC
        JSR TT111               ; the system nearest to (20, 173) is Lave
        JSR HYP1                ; initialise current economy, government and technology
        JSR GVL                 ; its market
        LDX #qq15
        LDU #qq2
        LDB #6
nc_c    LDA ,X+
        STA ,U+
        DECB
        BNE nc_c
        RTS
DEFNA   FCC "JAMESON"
        FCB 13,0
DEFSEED FCB $4A,$5A,$48,$02,$53,$B7     ; &5A4A, &0248, &B753
