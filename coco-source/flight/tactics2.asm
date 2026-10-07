; Ship tactics, part 2: spawning from a ship, and TACTICS itself (the original's seven
; parts). See tactics.asm for the conventions.

; ---- spawning from a ship --------------------------------------------------------------------

; copy SLOTSZ bytes from X to U
CPY40   LDY #SLOTSZ
cpy_l    LDA ,X+
        STA ,U+
        LEAY -1,Y
        BNE cpy_l
        RTS

; The ship whose slot is at <slotp spawns a ship of type B with AI byte A (SFS1): the new
; ship starts where its parent is (a space station's children start clear of it). Carry
; set if it was made. inwk, <slotn, <slotp and <bp are as before.
SFS1    STA sfai
        STB sfty
        LDX #inwk               ; the parent's working copy away
        LDU #sfsbuf
        JSR CPY40
        LDD <slotp
        PSHS D
        LDA <slotn
        PSHS A
        LDD <bp
        PSHS D
        LDX <slotp              ; the parent as it is in its slot, to be made into the child
        LDU #inwk
        JSR CPY40
        LDA inwk+35
        ANDA #$1C
        STA inwk+35
        LDA inwk+34
        CMPA #TY_SST
        BNE sfs_rx
        LDA #32                 ; a station's children are put out along its nose
        STA inwk+27
        LDX #inwk
        LDA NOSEHI
        JSR SFS2
        LDX #inwk+3
        LDA NOSEHI+2
        JSR SFS2
        LDX #inwk+6
        LDA NOSEHI+4
        JSR SFS2
sfs_rx   LDA sfai
        STA inwk+32
        LDA inwk+29
        ANDA #$FE
        STA inwk+29
        LDA sfty
        CMPA #TY_SPL+1
        BHS sfs_ni
        CMPA #TY_PLT
        BLO sfs_ni
        JSR DORND               ; a plate, canister or rock is thrown out tumbling
        ASLA
        STA inwk+30
        LDA sfty
        ANDA #15
        STA inwk+27
        LDA #$FF
        STA inwk+29
sfs_ni   LDA sfty
        JSR NWSHP
        TFR CC,B
        STB sfcc
        PULS D
        STD <bp
        PULS A
        STA <slotn
        PULS D
        STD <slotp
        LDX #sfsbuf
        LDU #inwk
        JSR CPY40
        LDB sfcc
        TFR B,CC
        RTS

; the coordinate at X moves by twice the signed byte A
SFS2    TFR A,B
        SEX
        ASLB
        ROLA
        JMP ADD24

; an escape pod, no AI (SESCP)
SESCP   LDB #TY_ESC
        LDA #$FE
        LBRA SFS1

; an enemy missile aimed at us (SFRMIS)
SFRMIS  LDB #TY_MSL
        LDA #$FE
        JSR SFS1
        BCC sfm_x
        LDA #120                ; INCOMING MISSILE
        JSR MESS
        LDA #48
        JMP NOISE
sfm_x    RTS

; The ship at X (of type A) has been attacked: it turns hostile (ANGRY). The station
; becomes hostile itself when it is the one attacked, or an innocent ship is.
ANGRY   CMPA #TY_SST
        BEQ ang_2
        PSHS A
        LDA 35,X
        ANDA #$20               ; an innocent: the station minds too
        BEQ ang_a
        PSHS X
        BSR ang_2
        PULS X
ang_a    LDA 32,X
        BEQ ang_r                ; no AI: nothing to turn on
        ORA #$80
        STA 32,X
        LDA #2
        STA 28,X
        ASLA
        STA 30,X
        LDA ,S
        CMPA #TY_CYL
        BLO ang_r
        LDA 35,X
        ORA #4
        STA 35,X
ang_r    PULS A
        RTS
ang_2    LDA slots+SLOTSZ+35
        ORA #4
        STA slots+SLOTSZ+35
        LDA inwk+34             ; (and the working copy, if this is the station)
        CMPA #TY_SST
        BNE ang_q
        LDA inwk+35
        ORA #4
        STA inwk+35
ang_q   RTS

; ---- TACTICS ----------------------------------------------------------------------------------

; The ship in inwk (AI on) decides what to do: a missile homes in or blows up, the station
; spawns cops or shuttles, others heal, aim at us (or the planet), spawn missiles and
; pods, fire their lasers, and set their pitch, roll and acceleration to turn.
TACTICS LDA #3
        STA trat
        INCA
        STA trat2
        LDA #22
        STA tcnt2
        LDB inwk+34
        CMPB #TY_MSL
        LBEQ TA18
        CMPB #TY_SST
        BNE TA13
        LDA inwk+35             ; the station
        ANDA #4
        BNE TN5
        LDA many+TY_SHU+1       ; calm: now and then a shuttle or a transporter
        BNE TA1
        JSR DORND
        CMPA #253
        BLO TA1
        ANDA #1
        ADDA #TY_SHU
        TFR A,B
        LBRA TN6
TN5     JSR DORND               ; hostile: cops
        CMPA #240
        BLO TA1
        LDA many+TY_COPS
        CMPA #4
        BHS TA1
        LDB #TY_COPS
TN6     LDA #$F1                ; E.C.M., AI on, very aggressive
        JMP SFS1
TA13    LDX <bp                 ; recharge the ship's energy by 1
        LDA inwk+33
        CMPA 14,X
        BHS TA21
        INC inwk+33
TA21    LDB inwk+34
        CMPB #TY_TGL
        BNE TA14
        LDA many+TY_THG         ; a Thargon without its mothership drifts
        BNE TA14
        LSR inwk+32
        ASL inwk+32
        LSR inwk+27
TA1     RTS
TA14    JSR DORND
        LDA inwk+35
        BITA #1                 ; a trader: 61% do nothing
        BEQ TN1
        CMPB #100
        BHS TA1
TN1     BITA #2                 ; a bounty hunter turns on a criminal
        BEQ TN2
        LDB fist
        CMPB #40
        BLO TN2
        ORA #4
        STA inwk+35
TN2     BITA #4
        BNE TN3                 ; hostile: go for us
        BITA #$10
        BEQ GOPL
        JMP DOCKIT              ; docking: the station
GOPL    JSR SPS1                ; otherwise: towards the planet
        JMP TA151
TN3     BITA #8                 ; a pirate near the station calms down
        BEQ TN4
        LDA sspr
        BEQ TN4
        LDA inwk+32
        ANDA #$81
        STA inwk+32
TN4     LDX #inwk               ; k3 = the ship's position
        LDU #k3
        LDB #9
tnc_l    LDA ,X+
        STA ,U+
        DECB
        BNE tnc_l
TA19    JSR TAS2
        JSR TAS3N
        STA tcnt
        LDA inwk+34
        CMPA #TY_MSL
        LBEQ TA20
        CMPA #TY_ANA
        BNE TN7
        JSR DORND               ; an Anaconda sometimes throws out a Worm
        CMPA #200
        BLO TN7
        LDB #TY_WRM
        LBRA TN6
TN7     JSR DORND               ; and 2% of the time starts to tumble
        CMPA #250
        BLO TA7
        JSR DORND
        ORA #104
        STA inwk+29
TA7     LDX <bp                 ; badly hurt: launch an escape pod (a ship with one)
        LDA 14,X
        LSRA
        CMPA inwk+33
        BLO TA3
        LSRA
        LSRA
        CMPA inwk+33
        BLO ta3
        JSR DORND
        CMPA #230
        BLO ta3
        LDX newbt
        LDB inwk+34
        DECB
        ABX
        LDA ,X
        BPL ta3
        CLR inwk+32
        JMP SESCP
ta3     LDA inwk+31             ; launch a missile?
        ANDA #7
        BEQ TA3
        STA tt1
        JSR DORND
        ANDA #31
        CMPA tt1
        BHS TA3
        LDA ecma
        BNE TA3
        DEC inwk+31
        LDA inwk+34
        CMPA #TY_THG
        BNE TA16
        LDB #TY_TGL             ; (a Thargoid: a Thargon instead)
        LDA inwk+32
        JMP SFS1
TA16    JMP SFRMIS
TA3     CLRA                    ; fire the laser? only when close, aimed, and armed
        JSR MAS4
        ANDA #$E0
        BNE TA4
        LDA tcnt
        CMPA #160
        BLO TA4
        LDX <bp
        LDA 19,X
        ANDA #$F8
        BEQ TA4
        LDA inwk+31
        ORA #$40
        STA inwk+31
        LDA tcnt
        CMPA #163
        BLO TA4
        LDX <bp
        LDA 19,X
        LSRA
        JSR OOPS
        DEC inwk+28
        LDA ecma
        BNE TA9r
        LDA #8
        JMP NOISE
TA9r    RTS
TA4     LDX #inwk+6             ; right on top of us: carry on turning; otherwise at random
        JSR MAGHI               ; turn away instead
        CMPA #3
        BHS TA5
        LDX #inwk
        JSR MAGHI
        STA tt1
        LDX #inwk+3
        JSR MAGHI
        ORA tt1
        ANDA #$FE
        BEQ TA15
TA5     JSR DORND
        ORA #$80
        CMPA inwk+32
        BHS TA15
TA20    JSR TAS6
        LDA tcnt
        EORA #$80
TA152   STA tcnt
TA15    LDX #ROOFHI             ; pitch to aim: the dot with roofv
        JSR TAS3
        TFR A,B
        BSR nroll
        STA inwk+30
        LDA inwk+29
        ASLA
        CMPA #32
        BHS TA6
        LDX #SIDEHI             ; roll to aim
        JSR TAS3
        TFR A,B
        EORA inwk+30
        BSR nroll
        STA inwk+29
TA6     LDA tcnt                ; accelerate when aimed, slow down for a big turn
        BMI TA9
        CMPA tcnt2
        BLO TA9
PH10E   LDA #3
        STA inwk+28
        RTS
TA9     ANDA #$7F
        CMPA #18
        BLO TA10
        LDA #$FF
        LDB inwk+34
        CMPB #TY_MSL
        BNE TA9s
        ASLA
TA9s    STA inwk+28
TA10    RTS
TA151   JSR TAS3N               ; towards the planet: tighten up when nearly aimed
        CMPA #$98
        BLO ttt
        CLR trat2
ttt     JMP TA152

; A = a dot product (sign-magnitude), B = the same: a pitch or roll counter that turns the
; ship the right way, strong when the dot product is big
nroll   EORA #$80
        ANDA #$80
        STA tt1
        TFR B,A
        ASLA
        CMPA trat2
        BLO nroll2
        LDA trat
        ORA tt1
        RTS
nroll2  LDA tt1
        RTS

; ---- missiles (part 1) ---------------------------------------------------------------------------

TA34    CLRA                    ; a hostile missile: within 256 of us it has hit
        JSR MAS4
        BEQ TA3a
        LBRA TA21
TA3a    LDA inwk+31             ; it hit: it is killed, and we take 250
        ORA #$80
        STA inwk+31
        JSR EXNO3
        LDA #250
        JMP OOPS
TA18    LDA ecma                ; E.C.M. destroys missiles
        BNE TA35
        LDA inwk+32
        ASLA
        BMI TA34                ; bit 6: hostile
        LSRA                    ; (slot * 2): the target
        LDB #SLOTSZ/2
        MUL                     ; slot * 2 * SLOTSZ/2
        ADDD #slots
        STD vp
        JSR VCSUB               ; k3: from the target to the missile
        LDX #k3
        JSR MAGHI
        STA tt1
        LDX #k3+3
        JSR MAGHI
        ORA tt1
        STA tt1
        LDX #k3+6
        JSR MAGHI
        ORA tt1
        BNE TA64                ; not there yet
        LDA inwk+32
        CMPA #$82
        BEQ TA35                ; the target is the station: it is blown up
        LDX vp
        LDA 31,X
        BITA #$20
        BNE TA35                ; the target is already exploding
        ORA #$80
        STA 31,X                ; the target is killed too
TA35    LDA inwk+2              ; blown up on top of us: we feel it
        ORA inwk+5
        ORA inwk+8
        BNE TA87
        LDA #80
        JSR OOPS
TA87    JSR EXNO2
        LDA inwk+31
        ORA #$80
        STA inwk+31
        RTS
TA64    JSR DORND
        CMPA #16
        BHS TA19s
        LDX vp                  ; (6%) a target with E.C.M. sets it off
        LDA 32,X
        LSRA
        BCC TA19s
        JMP ECBLB2
TA19s   JMP TA19

; ---- docking: a ship, or our docking computer, flies to the station's slot (DOCKIT) ---------------
; The ship in inwk steers by the station (slot 1): far away it heads for the planet; near, to
; the ideal place 4 * nosev in front of the slot, then in line with it, and when lined up
; with the slot and its roll it docks (bit 7 of NEWB: removed). For our docking computer
; inwk is a ship at the origin with type $A0, steered the same way (AUTODOCK).
STNOSE  EQU slots+SLOTSZ+21
STROOF  EQU slots+SLOTSZ+15

DKP     MACRO                   ; test (DOCKLOG): which way DOCKIT went
        IFDEF DOCKLOG
        LDA #\1
        STA dkpath
        ENDC
        ENDM

DOCKIT  EQU *
        DKP 1
        LDA #6
        STA trat2
        LSRA
        STA trat
        LDA #29
        STA tcnt2
        LDA sspr
        LBEQ GOPL               ; no station near: towards the planet
        JSR VCSU1
        LDA k3                  ; further than 65535 on any axis: towards the planet
        ADDA #1
        STA tt1
        LDA k3+3
        ADDA #1
        ORA tt1
        STA tt1
        LDA k3+6
        ADDA #1
        ORA tt1
        ANDA #$FE
        LBNE GOPL
        DKP 2
        JSR KLEN                ; K = the distance, before TAS2 shifts the vector
        JSR TAS2
        LDX #STNOSE
        JSR TAS3                ; xx15 . the station's nosev
        TSTA
        BMI PH1
        CMPA #35
        BLO PH1
        JSR TAS3N               ; and our nosev
        CMPA #$A2
        BHS PH3
        LDA kdis
        CMPA #157
        BLO PH2                 ; too close: turn away
        LDA inwk+34
        BMI PH3
PH2
        DKP 3
        JSR TAS6
        JSR TA151
PH22    EQU *
        DKP 6
        CLR inwk+28
        LDA #1
        STA inwk+27
        RTS
PH1     EQU *
        DKP 4
        JSR VCSU1               ; fly to the place 4 * nosev in front of the station
        JSR DCS1
        JSR DCS1
        JSR TAS2
        JSR TAS6
        JMP TA151
TN11
        DKP 7
        INC inwk+28
        LDA #$7F
        STA inwk+29
        BRA TN13
PH3
        DKP 5
        IFDEF DOCKLOG           ; (the station-to-ship vector, before PH32 uses xx15 for the sidev)
        LDA xx15
        STA $B194
        LDA xx15+1
        STA $B195
        LDA xx15+2
        STA $B196
        ENDC
        CLR trat2
        CLR inwk+30
        LDA inwk+34
        BPL PH32
        EORA xx15               ; our docking computer: roll and pitch towards the station
        EORA xx15+1
        ASLA
        LDA #2
        RORA
        STA inwk+29
        LDA xx15                ; |ship_x| * 2 (the vector is in two's complement here)
        BPL ph_x
        NEGA
ph_x    ASLA
        CMPA #12
        BHS PH22
        LDA xx15+1
        ASLA
        LDA #2
        RORA
        STA inwk+30
        LDA xx15+1
        BPL ph_y
        NEGA
ph_y    ASLA
        CMPA #12
        LBHS PH22
PH32
        DKP 8
        CLR inwk+29
        LDA inwk+9              ; our sidev
        STA xx15
        LDA inwk+11
        STA xx15+1
        LDA inwk+13
        STA xx15+2
        LDX #STROOF
        JSR TAS3                ; against the station's roofv: lined up with its slot?
        IFDEF DOCKLOG
        STA $B193
        ENDC
        ASLA
        CMPA #66
        LBHS TN11
        JSR PH22
TN13    JSR DORND               ; (the original: unless a stray byte is non-zero) it has docked
        TSTA
        BMI TNRTS
        LDA inwk+35
        ORA #$80
        STA inwk+35
TNRTS   RTS

; the original's K: the length of the vector in k3 made of its high bytes halved (TA2: x_hi/2,
; y_hi/2, z_hi/2, the bytes of the magnitude above the low one, with the sign apart), which is what
; K3 in 256s is worth: distance / 512. A = |24 bit coordinate at X| / 512 (up to 127)
KAX     LDA ,X
        BNE ka_n
        LDA 1,X
        LSRA
        RTS
ka_n    LDD 1,X
        COMA
        COMB
        ADDD #1
        BNE ka_p
        LDA #$FF
ka_p    LSRA
        RTS

KLEN    LDX #k3
        BSR KAX
        TFR A,B
        MUL
        STD <tmp
        LDX #k3+3
        BSR KAX
        TFR A,B
        MUL
        ADDD <tmp
        STD <tmp
        LDX #k3+6
        BSR KAX
        TFR A,B
        MUL
        ADDD <tmp
        JSR ISQRT16
        STB kdis
        RTS

; k3 := the ship in inwk less the station (VCSU1)
VCSU1   LDX #slots+SLOTSZ
        STX vp
        JMP VCSUB

; k3 := k3 less twice the station's nosev (DCS1 does it for each axis, and is called twice)
DCS1    LDA STNOSE
        CLRB
        BSR TAS7
        LDA STNOSE+2
        LDB #3
        BSR TAS7
        LDA STNOSE+4
        LDB #6
        BSR TAS7
        LDA STNOSE
        CLRB
        BSR TAS7
        LDA STNOSE+2
        LDB #3
        BSR TAS7
        LDA STNOSE+4
        LDB #6
; the k3 coordinate at offset B less twice the signed byte A
TAS7    PSHS B
        TFR A,B
        SEX
        ASLB
        ROLA
        STD <tmp
        LDB <tmp
        ASLB                    ; the sign of the 16 bit number, as a byte
        LDB #0
        SBCB #0
        STB tt1
        PULS B
        LDX #k3
        ABX
        LDD 1,X
        SUBD <tmp
        STD 1,X
        LDA ,X
        SBCA tt1
        STA ,X
        RTS
