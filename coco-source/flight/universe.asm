; The local universe: ship sets, new ships, killing ships, and the random encounters of
; the original main loop (the code after M% in TT100: traders and junk, cops, lone
; bounty hunters and pirate packs).

; A = ship set 0-15 (the original's ship files A-P): its blueprint table and default
; NEWB flags
SETSHIPSET
        ASLA
        ASLA
        LDX #SHIPSETTAB
        LEAX A,X
        LDD ,X
        STD xx21
        LDD 2,X
        STD newbt
        RTS

; reset inwk to a ship at the origin that faces us: sidev = x, roofv = y, nosev = -z
ZINF    LDX #inwk
        LDD #0
        LDY #SLOTSZ/2
zi_c    STD ,X++
        LEAY -1,Y
        BNE zi_c
        LDD #$6000
        STD inwk+9
        STD inwk+17
        LDD #$A000
        STD inwk+25
        RTS

; A fairly aggressive ship a fair way off (Ze): the signs of x and y random, 25 * 256 away
; along each axis, AI on, hostile, E.C.M. in 4%. Leaves A random.
Ze      JSR ZINF
        JSR DORND
        STA tt1                 ; x sign
        PSHS B
        LDD #25*256
        LDX #inwk
        JSR PUTPOS
        PULS A
        STA tt1                 ; y sign
        LDD #25*256
        LDX #inwk+3
        JSR PUTPOS
        LDD #25*256
        STD inwk+7              ; z = +25 * 256
        JSR DORND
        CMPA #245
        ROLA
        EORA #1                 ; bit 0: E.C.M. (4%)
        ORA #$C0
        STA inwk+32
        JMP DORND2

; X -> coordinate (hi, mid, lo), D = magnitude, tt1 bit 7 = negative
PUTPOS  TST tt1
        BPL pp_p
        JSR NEGD
        STD 1,X
        LDA #$FF
        TSTB
        BNE pp_s
        TST 1,X
        BNE pp_s
        CLRA
pp_s    STA ,X
        RTS
pp_p    STD 1,X
        CLR ,X
        RTS

; The cargo of an illegal kind, doubled, for the police: slaves + narcotics, doubled, +
; firearms (qq20 holds the hold, one byte per commodity)
BAD     LDA qq20+3
        ADDA qq20+6
        ASLA
        ADDA qq20+10
        RTS

; A = type: put the ship in inwk (position, orientation, AI, counters set by the caller)
; into a free slot. Carry set if it went to <slotn; clear when there was no room or the
; ship set has no such ship. (NWSHP)
NWSHP   PSHS A
        JSR SLOTFREE
        BCS nw_no
        LDA ,S
        BMI nw_pl
        DECA
        ASLA
        LDX xx21
        TFR A,B
        ABX
        LDX ,X
        BEQ nw_no               ; not in this system's ships
        STX <bp
        LDA 14,X                ; its energy
        STA inwk+33
        LDA 19,X                ; its missiles (bits 0-2)
        ANDA #7
        STA inwk+31
        LDA ,S
        CMPA #JL
        BLO nw_c
        CMPA #JH
        BHS nw_c
        INC junk
nw_c    LDX #many
        LDB ,S
        ABX
        INC ,X
        LDX newbt               ; the default NEWB flags of the type
        LDB ,S
        DECB
        ABX
        LDA ,X
        ANDA #$6F
        ORA inwk+35
        STA inwk+35
nw_pl   PULS A
        STA inwk+34
        JSR SLOTPUT
        ORCC #1
        RTS
nw_no   PULS A
        ANDCC #$FE
        RTS

; Remove the ship in slot <slotn: its counts, a missile's lock on it, and its place. (A
; destroyed space station is replaced by the sun: not yet, there is no station.)
KILLSHP LDA <slotn
        STA ksl
        CMPA mstg
        BNE ks_5
        JSR ABORT               ; our missile's target is gone
        LDA #200
        JSR MESS
ks_5    LDA <slotn
        JSR SLOTADDR
        STX <slotp
        LDA 34,X
        CMPA #TY_CON
        BNE ks_l
        LDA tp
        ORA #2
        STA tp
        LDA 34,X
ks_l    CMPA #JL
        BLO ks_7
        CMPA #JH
        BHS ks_7
        DEC junk
ks_7    PSHS A
        LDX #many
        TFR A,B
        ABX
        DEC ,X
        LDX <slotp
        LDA #TY_NONE
        STA 34,X
        PULS A
        CMPA #TY_SST
        BNE ks_ns
        JSR KS4                 ; the station is gone: the sun takes its place
ks_ns   LDA ksl                 ; missiles that had this ship as the target lose it (KS2)
        ASLA
        STA tt1                 ; as a missile's AI byte holds it: slot * 2
        CLR <cnt2
ks2_l   LDA <cnt2
        JSR SLOTADDR
        LDA 34,X
        CMPA #TY_MSL
        BNE ks2_n
        LDA 32,X
        BPL ks2_n               ; no AI
        BITA #$40
        BNE ks2_n               ; hostile to us: its target is us
        ANDA #$3E               ; bits 1-5: the target's slot
        CMPA tt1
        BNE ks2_n
        CLR 32,X
ks2_n   INC <cnt2
        LDA <cnt2
        CMPA #NSLOTS
        BLO ks2_l
        RTS

; unarm / untarget the missile (ABORT)
ABORT   LDA #$FF
        STA mstg
        CLR msar
        RTS


; are we in the Constrictor's system (galaxy 2, 144,33)? Carry set if so (THERE)
THERE   LDA gcnt
        CMPA #1
        BNE th_n
        LDA qq0
        CMPA #144
        BNE th_n
        LDA qq1
        CMPA #33
        BNE th_n
        ORCC #1
        RTS
th_n    ANDCC #$FE
        RTS

; a Thargoid and a Thargon
GTHG    JSR Ze
        LDA #$FF
        STA inwk+32
        LDA #TY_THG
        JSR NWSHP
        LDA #TY_TGL
        JMP NWSHP

; ---- the random encounters (the end of TT100 after the ships have moved) -----------------
; Called once every 256 loops. Traders and junk, cops, then a lone bounty hunter or a pack
; of pirates; nothing in witchspace, and no cops or pirates near a station.
MAINSPAWN
        TST mj
        LBNE ms_x
        JSR DORND
        CMPA #35
        LBHS ms_1
        LDA junk
        CMPA #3
        LBHS ms_1
        JSR ZINF
        LDA #38
        STA inwk+7              ; z_hi = 38
        JSR DORND
        STA tt2                 ; x_lo
        STA tt1                 ; x sign
        PSHS B                  ; y_lo
        LDA <rand
        ANDA #2                 ; x_hi: 0 or 2 (the original rolls a random carry into bit 1)
        LDB tt2
        LDX #inwk
        JSR PUTPOS
        PULS B
        STB tt1                 ; y sign
        CLRA
        LDX #inwk+3
        JSR PUTPOS
        JSR DORND
        STB tt2                 ; (the original's X)
        BITA #$40
        BEQ ms_t
        JSR DORND               ; MTT4: a trader (Cobra Mk III, Python, Boa, Anaconda)
        LSRA
        STA inwk+32
        STA inwk+29
        ANDA #15
        ORA #16
        STA inwk+27
        JSR DORND
        TSTA
        BMI ms_nd
        LDA inwk+32
        ORA #$C0
        STA inwk+32
        LDA #$10
        STA inwk+35
ms_nd   JSR DORND
        ANDA #3
        ADDA #TY_CYL
        JSR NWSHP
        BRA ms_1
ms_t    ORA #$6F                ; junk, tumbling
        STA inwk+29
        LDA sspr
        BNE ms_1
        LDA tt2
        BITA #$40
        BEQ ms_3
        ORA #$7F
        STA inwk+30
        BRA ms_j
ms_3    ANDA #31
        ORA #16
        STA inwk+27
ms_j    JSR DORND               ; a canister, a boulder or an asteroid
        TFR A,B
        ANDA #1
        CMPB #10
        BLO ms_o
        INCA
ms_o    ADDA #TY_OIL
        JSR NWSHP
ms_1    LDA sspr                ; MTT1: nothing more near the station
        LBNE ms_x
        JSR BAD                 ; the police come for the guilty
        ASLA
        LDB many+TY_COPS
        BEQ ms_2
        ORA fist
ms_2    STA tt1
        JSR Ze
        CMPA tt1
        BHS ms_4
        LDA #TY_COPS
        JSR NWSHP
ms_4    LDA many+TY_COPS
        LBNE ms_x
        DEC ev
        LBPL ms_x
        INC ev
        LDA tp                  ; the Thargoid mission
        ANDA #$0C
        CMPA #$08
        BNE ms_np
        JSR DORND
        CMPA #200
        BLO ms_np
        JSR GTHG
ms_np   JSR DORND
        LDB gov
        BEQ ms_g
        CMPA #120
        LBHS ms_x
        ANDA #7
        CMPA gov
        LBLO ms_x
ms_g    JSR Ze
        CMPA #100
        BHS ms_pk
        INC ev                  ; a lone bounty hunter: Cobra Mk III, Asp, Python or Fer-de-lance
        ANDA #3
        ADDA #TY_CYL2
        TFR A,B
        JSR THERE
        BCC ms_nc
        LDA #$F9
        STA inwk+32
        LDA tp
        ANDA #3
        LSRA
        BCC ms_nc
        ORA many+TY_CON
        BNE ms_nc
        LDB #TY_CON
ms_nc   TFR B,A
        JMP NWSHP
ms_pk   ANDA #3                 ; a pack of pirates, up to four
        STA ev
        STA tt2
ms_m3   JSR DORND
        STA tt1
        JSR DORND
        ANDA tt1
        ANDA #7
        STA cpir
ms_mr   LDA cpir
        ADDA #TY_SH3
        JSR NWSHP
        BCS ms_nx
        DEC cpir
        BPL ms_mr
ms_nx   DEC tt2
        BPL ms_m3
ms_x    RTS
