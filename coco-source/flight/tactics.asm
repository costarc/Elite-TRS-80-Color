; Ship tactics: the original's TACTICS (all seven parts), its vector helpers, and the
; spawning a ship does of other ships (a missile, an escape pod, a Thargon, a cop).
;
; The original works on sign-magnitude bytes; the dot products here are made in two's
; complement and returned as the original's sign-magnitude byte (bit 7 = negative, bits
; 0-6 the size), so the thresholds of the original code (CNT >= 160 and so on) stay as
; they are. Positions are 24 bits, three bytes high to low; k3 holds three of them.
;
; Orientation vectors: the original's nosev (INWK+9..14) is here at inwk+21, its sidev
; (INWK+21..26) at inwk+9; roofv is the same (inwk+15). A dot product with a vector takes
; the address of its first high byte (a 16-bit entry every 2 bytes).

NOSEHI  EQU inwk+21
ROOFHI  EQU inwk+15
SIDEHI  EQU inwk+9

; ---- vector helpers ---------------------------------------------------------------------

; k3 (three 24-bit coordinates) -> xx15: the same direction, length 96 (TAS2 and NORM3):
; first shifted until the largest coordinate fills a signed byte (>= 64), then scaled
TAS2    LDX #k3
        JSR FITS8
        BCS tas_r
        LDX #k3+3
        JSR FITS8
        BCS tas_r
        LDX #k3+6
        JSR FITS8
        BCC tas_b
tas_r    ASR k3
        ROR k3+1
        ROR k3+2
        ASR k3+3
        ROR k3+4
        ROR k3+5
        ASR k3+6
        ROR k3+7
        ROR k3+8
        BRA TAS2
tas_b    LDA k3+2
        ORA k3+5
        ORA k3+8
        BEQ tas_z                ; the zero vector
        LDA k3+2
        ADDA #64
        BMI tas_d
        LDA k3+5
        ADDA #64
        BMI tas_d
        LDA k3+8
        ADDA #64
        BMI tas_d
        ASL k3+2                ; room to spare: the largest at least 64
        ASL k3+5
        ASL k3+8
        BRA tas_b
tas_d    LDA k3+2
        STA xx15
        LDA k3+5
        STA xx15+1
        LDA k3+8
        STA xx15+2
        LDX #xx15
        JMP NORM3
tas_z    CLR xx15
        CLR xx15+1
        CLR xx15+2
        RTS

; A = (xx15 . vector at X) / 256 as a sign-magnitude byte: 36 when they are the same
; direction (unit vectors are 96 long)
TAS3    LDA ,X
        LDB xx15
        JSR SMUL8
        STD <tmp
        LDA 2,X
        LDB xx15+1
        JSR SMUL8
        ADDD <tmp
        STD <tmp
        LDA 4,X
        LDB xx15+2
        JSR SMUL8
        ADDD <tmp
        TSTA
        BPL tas3_r
        JSR NEGD
        ORA #$80
tas3_r    RTS

TAS3N   LDX #NOSEHI             ; (the original's TAS3-2: the dot with nosev)
        BRA TAS3

; the vector in xx15 points the other way
TAS6    NEG xx15
        NEG xx15+1
        NEG xx15+2
        RTS

; k3 := the ship in inwk less the ship in the slot at vp (VCSUB): the vector from that
; ship to this one
VCSUB   LDX vp
        LDU #k3
        LDY #inwk
        LDB #3
vcs_l   PSHS B
        LDD 1,Y
        SUBD 1,X
        STD 1,U
        LDA ,Y
        SBCA ,X
        STA ,U
        LEAX 3,X
        LEAU 3,U
        LEAY 3,Y
        PULS B
        DECB
        BNE vcs_l
        RTS

; xx15 := the direction from us to the planet (slot 0), length 96 (SPS1)
SPS1    LDX #slots
        LDU #k3
        LDB #9
spp_l    LDA ,X+
        STA ,U+
        DECB
        BNE spp_l
        JMP TAS2

; ---- damage to us and the kill tally -------------------------------------------------------

; A = damage: the shield on the side the ship in inwk is on takes it, the rest our
; energy (OOPS); the cargo may suffer (OUCH)
OOPS    STA tt1
        LDA inwk+6
        BMI oop_a
        LDA fsh
        SUBA tt1
        BLO oop_2
        STA fsh
        RTS
oop_2    CLR fsh
        BRA oop_3
oop_a    LDA ash
        SUBA tt1
        BLO oop_5
        STA ash
        RTS
oop_5    CLR ash
oop_3    ADDA energy             ; the damage the shield could not take is taken off the energy
        STA energy
        BEQ oop_d
        BCS oop_h
oop_d    JMP DEATH
oop_h    JSR EXNO3
        JMP OUCH

; and now and then (OUCH): half the time, in one case in 11, something in the hold or of the
; equipment is lost, if we have it: DESTROYED
OUCH    JSR DORND
        TSTA
        BMI ou_x
        CMPB #22
        BHS ou_x
        TST dly
        BNE ou_x
        STB tsc
        CMPB #17
        BHS ou_e
        LDX #qq20
        ABX
        LDA ,X
        BEQ ou_x
        CLR ,X
        LDA #3
        STA de
        LDA tsc
        ADDA #208               ; the commodity's name
        JMP MESS
ou_e    TFR B,A
        SUBA #17
        ASLA
        LDY #OUEQ
        LDX A,Y
        LDA ,X
        BEQ ou_x
        CLR ,X
        LDA #3
        STA de
        LDB tsc
        LDA #108                ; E.C.M.SYSTEM
        CMPB #17
        BEQ ou_m
        LDA #111                ; FUEL SCOOPS
        CMPB #18
        BEQ ou_m
        TFR B,A
        ADDA #113-19            ; ENERGY BOMB, ENERGY UNIT, DOCKING COMPUTERS
ou_m    JMP MESS
ou_x    RTS
OUEQ    FDB ecm,bst,bomb,engy,dkcmp

; we killed a ship: the tally
EXNO2   INC kills+1
        BNE exn_r
        INC kills
        LDA #101                ; (the rank message)
        JSR MESS
exn_r    LDA #16                 ; the sound of it
        JMP NOISE


; our death: not yet
DEATH   EQU *
        IFDEF DOCKCNT
        INC $B192
        ENDC
        LDA #1
        STA dead
        RTS

; ---- E.C.M. ----------------------------------------------------------------------------------

; set off an E.C.M. (ours or another's): 32 loops, the bulb lit (ECBLB2)
ECBLB2  LDA #32
        STA ecma
        LDA bulbs
        ORA #1
        STA bulbs
        LDA #32*2
        JMP NOISE

; switch the E.C.M. off (ECMOF)
ECMOF   LDA #72
        JSR NOISE
        CLR ecma
        CLR ecmp
        LDA bulbs
        ANDA #$FE
        STA bulbs
        RTS

