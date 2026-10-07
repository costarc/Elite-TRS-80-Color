; The ship loop: the original's main loop over the ships (MAL1 .. MA27), in the order of
; its parts. For every ship in use:
;   - the planet and sun move (MV40) and are drawn;
;   - a ship is tidied (every 16th loop), its tactics run (a missile every loop, any other
;     ship with AI every 8th), it moves (MVEIT), then it is tested against us (collisions,
;     scooping, docking: COLLIDE), flipped into the view's frame, tested against our laser and
;     missile (HITCH), drawn, and removed once it has exploded or flown too far.
; The loop index is <xsav; <slotn is the slot the data in inwk belongs to (a ship that
; spawns another changes it, so it is put back after the tactics).

; carry set if (A * 256) is further than every coordinate of inwk (FAROF2); FAROF = 224
FAROF   LDA #224
FAROF2  STA tt1
        LDX #inwk
        JSR MAGHI
        CMPA tt1
        BHS fa_far
        LDX #inwk+3
        JSR MAGHI
        CMPA tt1
        BHS fa_far
        LDX #inwk+6
        JSR MAGHI
        CMPA tt1
        BHS fa_far
        ORCC #1
        RTS
fa_far  ANDCC #$FE
        RTS

; A = the magnitude's high byte of the 24-bit coordinate at X (255 when 64K or more)
MAGHI   LDA ,X
        BEQ mh_p
        INCA
        BNE mh_big
        LDA 1,X
        COMA
        TST 2,X                 ; (-256 is 256, not 255)
        BNE mh_r
        INCA
        BNE mh_r
        LDA #255
mh_r    RTS
mh_p    LDA 1,X
        RTS
mh_big  LDA #255
        RTS

; A | the magnitude high bytes of x, y and z of inwk (MAS4): zero when the ship is within
; 256 of us on every axis
MAS4    PSHS A
        LDX #inwk
        JSR MAGHI
        ORA ,S
        STA ,S
        LDX #inwk+3
        JSR MAGHI
        ORA ,S
        STA ,S
        LDX #inwk+6
        JSR MAGHI
        ORA ,S+
        RTS

; copy the part of inwk that the drawing does not change (+27 .. +39) back to the slot
SLOTUPD LDX <slotp
        LDD inwk+27
        STD 27,X
        LDD inwk+29
        STD 29,X
        LDD inwk+31
        STD 31,X
        LDD inwk+33
        STD 33,X
        LDD inwk+35
        STD 35,X
        LDD inwk+37
        STD 37,X
        LDA inwk+39
        STA 39,X
        RTS

SHIPLOOP
        CLR xsav
sh_l    LDA xsav
        STA <slotn
        JSR SLOTADDR
        LDA 34,X
        CMPA #TY_NONE
        LBEQ sh_n
        JSR SLOTLOAD
        LDA inwk+31             ; a killed or exploding ship is not tidied and has no tactics
        ANDA #$A0
        BNE sh_pt
        LDA xsav                ; every 16th loop, by slot
        ANDA #15
        ASLA
        LDX #BITS16
        LDD A,X
        ANDA duem
        STA <tmp
        ANDB duem+1
        ORB <tmp
        BEQ sh_pt
        JSR TIDY
sh_pt   LDA inwk+34
        LBPL sh_ship
        JSR MVPLAN              ; the planet and the sun (type >= 128)
        JSR SLOTSAVE
        JSR PUVIEW              ; into the view's frame, for drawing only
        IFNDEF SKIPPLAN
        JSR PLANET
        ENDC
        LBRA sh_n
sh_ship LDA inwk+31
        ANDA #$A0
        BNE sh_mv
        LDA inwk+32
        BPL sh_mv               ; no AI
        LDA inwk+34
        CMPA #TY_MSL
        BEQ sh_tc               ; a missile thinks every loop
        LDA xsav                ; and the tactics every 8th, by slot
        ANDA #7
        ASLA
        LDX #BITS16
        LDD A,X
        ORA 16,X
        ORB 17,X
        ANDA duem
        STA <tmp
        ANDB duem+1
        ORB <tmp
        BEQ sh_mv
sh_tc   JSR TACTICS
        LDA xsav                ; (a ship that spawned another has changed <slotn)
        STA <slotn
        JSR SLOTADDR
        STX <slotp
sh_mv   LDA inwk+31
        BITA #$A0               ; dead or exploding: stop highlighting
        BNE sh_ac
        BITA #$40               ; latch the shot before LL9 consumes it, in any view
        BEQ sh_at
        LDA #SCANHOLD
        BRA sh_as
sh_at   LDA inwk+36
        SUBA ftick              ; hold duration follows game time, not render rate
        BCC sh_as
sh_ac   CLRA
sh_as   STA inwk+36
        JSR MVEIT
        JSR COLLIDE
        TST bomb
        BPL sh_nb               ; the energy bomb kills what is not the station or exploding already
        LDA inwk+34
        CMPA #TY_SST
        BEQ sh_nb
        LDA inwk+31
        BITA #$20
        BNE sh_nb
        ORA #$80
        STA inwk+31
        JSR EXNO2
sh_nb   LDA inwk+35             ; docked or scooped: gone, without an explosion
        LBMI sh_gk
        JSR SLOTSAVE
        LDA inwk+31             ; killed: the explosion starts now
        BPL sh_dr
        BITA #$20
        BNE sh_dr
        ANDA #$3F
        STA inwk+31
        CLR inwk+28
        CLR inwk+30
        JSR EXPSTART
        JSR SLOTSAVE
sh_dr   JSR PUVIEW
        JSR HITCH               ; in our sight: our laser hits it, our missile locks on
        BCC sh_nh
        JSR HITPROC
sh_nh   EQU *
        CLR expdone
        IFDEF FLYSWEEP
        LDD <work
        PSHS D
        ENDC
        JSR LL9
        IFDEF FLYSWEEP
        PULS D
        JSR SWEEPLOG
        ENDC
        LDA expdone
        BEQ sh_up
        LDA inwk+31
        ORA #$A0                ; the cloud has gone: it is dead for good
        STA inwk+31
sh_up   JSR SLOTUPD
        LDA inwk+31
        BPL sh_fa
        BITA #$20
        BEQ sh_fa
        JSR KILLED              ; its bounty, our legal status
        BRA sh_kl
sh_fa   JSR FAROF               ; too far away: gone
        BCS sh_n
sh_gk    JSR SLOTSAVE
sh_kl   LDA xsav
        STA <slotn
        JSR KILLSHP
sh_n    INC xsav
        LDA xsav
        CMPA #NSLOTS
        LBLO sh_l
        TST bomb
        BPL sh_x
        ASL bomb                ; the bomb stays on a few loops, the view flashes
        JSR DFULLC
        LDX <back
        LDY #VIEWH*16
sh_f    LDD ,X
        COMA
        COMB
        STD ,X++
        LEAY -1,Y
        BNE sh_f
sh_x    RTS
