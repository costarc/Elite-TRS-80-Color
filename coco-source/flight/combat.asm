; Combat: our laser and missiles against the ships, and ships against us: HITCH (is the
; ship in our sight), what a hit does (HITPROC), collisions, the loot of a kill, the
; bounty, missile launch and lock, the E.C.M.

; A = the low byte of the magnitude of the coordinate at X, which is within 256 of us
MAGLO   LDA 2,X
        TST ,X
        BEQ ml_r
        NEGA
ml_r    RTS

; Is the ship in inwk (in the view's frame) in our sights (HITCH)? Carry set when so: in
; front of us, less than 64K away, not exploding, within 256 across and x^2 + y^2 less
; than its blueprint's targetable area.
HITCH   LDA inwk+6
        BNE hi_r                ; behind us or far
        LDA inwk+34
        BMI hi_r                ; (the planet and the sun)
        LDA inwk+31
        ANDA #$20
        BNE hi_r                ; exploding
        LDX #inwk
        JSR MAGHI
        STA tt1
        LDX #inwk+3
        JSR MAGHI
        ORA tt1
        BNE hi_r                ; not within 256
        LDX #inwk
        JSR MAGLO
        TFR A,B
        MUL
        STD <tmp                ; x^2
        LDX #inwk+3
        JSR MAGLO
        TFR A,B
        MUL
        ADDD <tmp
        BCS hi_r                ; more than 16 bits
        LDX <bp
        CMPD 1,X                ; the area: x^2 + y^2 <= area
        BHI hi_r
        ORCC #1
        RTS
hi_r    ANDCC #$FE               ; failed helpers and overflow may have set carry
        RTS

; HITCH said yes: a missile looking for a target locks on; our laser, if it fired, hits
HITPROC LDA msar
        BEQ hp_l
        JSR BEEP
        LDA xsav                ; (ABORT2) the missile has its target
        STA mstg
        CLR msar
hp_l    LDA las
        LBEQ hp_x
        LDA #15
        JSR EXNO
        LDA inwk+34
        CMPA #TY_SST
        BEQ hp_ng               ; the station takes no damage but minds
        CMPA #TY_CON
        BNE hp_b
        LDA las                 ; a Constrictor needs a military laser
        CMPA #23
        BNE hp_x
        LSR las
        LSR las
hp_b    LDA inwk+33             ; the ship's energy less the laser's power
        SUBA las
        BHS hp_s
        PSHS A
        LDA inwk+31             ; dead
        ORA #$80
        STA inwk+31
        LDA inwk+34
        CMPA #TY_AST
        BNE hp_ns
        LDA las
        CMPA #50                ; mining laser: an asteroid breaks into splinters
        BNE hp_ns
        JSR DORND
        ANDA #3
        LDB #TY_SPL
        JSR SPIN2
hp_ns   LDB #TY_PLT
        JSR SPIN
        LDB #TY_OIL
        JSR SPIN
        JSR EXNO2
        PULS A
hp_s    STA inwk+33
hp_ng   LDA inwk+34
        LDX #inwk
        JSR ANGRY
hp_x    RTS


; loot: with a 50% chance, up to (a random number AND the blueprint's first byte AND 15)
; things of type B fly out of the ship in inwk (SPIN); SPIN2 starts with a count in A
SPIN    JSR DORND
        BPL sp_x
        LDX <bp
        ANDA ,X
        ANDA #15
SPIN2   STA tt2
sp_l    LDA tt2
        BEQ sp_x
        LDA #0
        PSHS B
        JSR SFS1
        PULS B
        DEC tt2
        BRA sp_l
sp_x    RTS

; the ship in inwk against us (the collision tests of MAL1): a ship within 64 of us on every
; axis rams us. (Scooping, and the docking tests for the station, come with the cargo and
; the station.)
COLLIDE TST escn
        LBNE cl_x               ; (our escape pod pulling away: nothing collides)
        LDA inwk+31
        ANDA #$A0
        LBNE cl_x                ; killed or exploding
        LDA inwk+34
        LBMI cl_x
        CLRA
        JSR MAS4
        LBNE cl_x                ; not within 256
        LDX #inwk
        JSR MAGLO
        STA tt1
        LDX #inwk+3
        JSR MAGLO
        ORA tt1
        STA tt1
        LDX #inwk+6
        JSR MAGLO
        ORA tt1
        LBMI cl_x                ; 128 or more
        LDB inwk+34
        CMPB #TY_SST
        BEQ cl_dk               ; the station: docking, not yet
        BITA #$C0
        LBNE cl_x                ; 64 or more
        CMPB #TY_MSL
        LBEQ cl_x                ; missiles blow up by themselves
        LDA bst                 ; with fuel scoops, what is below us can be scooped
        ANDA inwk+3
        BPL cl_hit
        CMPB #TY_OIL
        BEQ cl_oil
        LDX <bp                 ; only the Thargon, alloy plate, splinter and escape pod have
        LDA ,X                  ; a market item in the blueprint's high nibble (less 1)
        LSRA
        LSRA
        LSRA
        LSRA
        BEQ cl_hit
        ADCA #1
        BRA cl_sl
cl_oil  JSR DORND               ; a canister holds one of the first eight items
        ANDA #7
cl_sl   STA qq29
        JSR TNPR1
        BCS cl_nr               ; no room: it is lost
        LDB qq29
        LDX #qq20
        ABX
        INC ,X
        LDA qq29
        ADDA #208
        JSR MESS
        LDA inwk+35             ; (the scooped item is gone at once)
        ORA #$80
        STA inwk+35
        BRA cl_gone
cl_nr   JSR EXNO3
cl_gone LDA inwk+31             ; scooped or lost: removed
        ORA #$80
        STA inwk+31
        RTS
cl_hit  LDA inwk+31             ; a collision: it is killed and we take (energy / 2 + 128)
        ORA #$80
        STA inwk+31
        LDA inwk+33
        LSRA
        ORA #$80
        JSR OOPS
        JMP EXNO3
cl_dk   JMP ISDK
cl_x    RTS

; the ship in inwk has exploded for good: a cop's death marks us, the bounty goes to the
; cash (not while a message is up or in witchspace)
KILLED  LDA inwk+35
        ANDA #$40
        ORA fist
        STA fist
        LDA dly
        ORA mj
        BNE kd_x
        LDX <bp
        LDD 10,X                ; the bounty, tenths of a credit
        BEQ kd_x
        JSR MCASH
        LDA #0                  ; (the message with the bounty)
        JSR MESS
kd_x    RTS

; the cash += D
MCASH   ADDD cash+2
        STD cash+2
        BCC mc_r
        LDD cash
        ADDD #1
        STD cash
mc_r    RTS

; Is there no room for A more of item qq29? Carry set when there is not (tnpr): up to crgo-2 tonnes
; of the tonnes items, 199 of one of the kilogram and gram items
TNPR    PSHS A
        LDB qq29
        CMPB #12
        LBHI tn_kg
        LDX #qq20               ; the tonnes items 0-12
        LDB #13
        INCA                    ; (the original's carry in: one more)
tn_l    ADDA ,X+
        DECB
        LBNE tn_l
        CMPA crgo
        PULS A
        LBLO tn_ok
        ORCC #1
        RTS
tn_ok   ANDCC #$FE
        RTS
tn_kg   LDX #qq20
        LDB qq29
        ABX
        ADDA ,X
        CMPA #200
        PULS A
        LBLO tn_ok
        ORCC #1
        RTS

; tnpr for one tonne of the item qq29 (tnpr1)
TNPR1   LDA #1
        LBRA TNPR

; ---- our missiles and the E.C.M. -----------------------------------------------------------------

; launch a ship straight ahead, below the sight: type B (FRS1). Carry set if it was made.
FRS1    PSHS B
        JSR ZINF
        LDD #-28                ; y = -28, z = +14
        STD inwk+4
        LDA #$FF
        STA inwk+3
        LDD #14
        STD inwk+7
        LDA mstg
        ASLA
        ORA #$80
        STA inwk+32
        LDD #$6000              ; nosev points away, sidev flipped to keep it right handed
        STD inwk+25
        LDD #$A000
        STD inwk+9
        LDA <delta
        ASLA
        STA inwk+27
        PULS A
        JMP NWSHP

; M: fire the missile at the target (FRMIS)
FRMIS   LDB #TY_MSL
        JSR FRS1
        BCC fr_j
        LDA mstg
        LDB #SLOTSZ
        MUL
        ADDD #slots
        TFR D,X
        LDA 34,X
        JSR ANGRY               ; the target minds
        JSR ABORT
        DEC nomsl
        LDA #48
        JMP NOISE
fr_j    LDA #201                ; MISSILE JAMMED
        JMP MESS

; the keys of the missiles and the E.C.M. (MA4 .. MA64), and the E.C.M.'s energy drain (MA16)
PLAYMISS
        LDA <kmat+5
        BITA #R2                ; U: unarm
        BEQ pm_t
        LDA nomsl
        BEQ pm_t
        JSR ABORT
        LDA #40
        JSR NOISE
pm_t    LDA mstg                ; T: look for a target for the missile
        BPL pm_m
        LDA <kmat+4
        BITA #R2
        BEQ pm_m
        LDA nomsl
        BEQ pm_m
        LDA #1
        STA msar
pm_m    LDA <kmat+5             ; M: fire it
        BITA #R1
        BEQ pm_e
        LDA mstg
        BMI pm_e
        JSR FRMIS
pm_e    LDA <kmat+2             ; B: the energy bomb (TAB in the original) goes off
        BITA #R0
        BEQ pm_p
        ASL bomb
pm_p    LDA <kmat+2             ; BREAK: the escape pod (ESCAPE in the original)
        BITA #$40
        BEQ pm_c
        TST escp
        BEQ pm_c
        LDA #1
        STA escr
pm_c    LDA <kmat+3             ; C: the docking computer on, P: off
        BITA #R0
        BEQ pm_q
        LDA dkcmp
        BEQ pm_q
        STA auto
pm_q    LDA <kmat
        BITA #R2
        BEQ pm_x2
        CLR auto
pm_x2   LDA <kmat+5             ; E: E.C.M.
        BITA #R0
        BEQ pm_h
        LDA ecm
        BEQ pm_h
        LDA ecma
        BNE pm_h
        DEC ecmp
        JSR ECBLB2
pm_h    LDA <kmat               ; H: hyperspace
        BITA #R1
        BEQ pm_g
        JSR HYP
pm_g    LDA <kmat+7             ; G: the galactic hyperdrive
        BITA #R0
        BEQ pm_d
        JSR GHY
pm_d    RTS

; once a loop of the reference game: the E.C.M. drains the energy and its flash counts down
ECMTICK LDA ecmp                ; the E.C.M. drains the energy
        BEQ pm_a
        DEC energy
        BNE pm_a
        INC energy
        JMP ECMOF
pm_a    LDA ecma
        BEQ pm_x
        DEC ecma
        BNE pm_x
        JMP ECMOF
pm_x    RTS
