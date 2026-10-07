; Hyperspace and the in-flight messages: the H key counts down 15 and jumps (TT18) to the
; system the crosshairs of the charts chose, spending the distance in fuel; now and then the
; jump goes wrong into witchspace (MJP); the galactic hyperdrive moves to the next galaxy
; (Ghy); messages show at the bottom of the view for a while (MESS).

; ---- in-flight messages (MESS) -----------------------------------------------------------------

; message token A, shown at the bottom of the view for 12 loops
MESS    STA mch
        LDA #9
        STA mcol
        CLR mvalid              ; a new text: set in type again
        LDA #22                 ; (loops of the reference game, as the original)
        STA dly
        LDA de
        STA mde
        CLR de
        RTS


; ---- the H key (hyp) ---------------------------------------------------------------------------------

; start the countdown to the system the crosshairs are on (or the nearest to them), if it is
; another system, near enough for the fuel
HYP     LDA hnum
        BNE hy_r
        TST docked
        BNE hy_r
        JSR TT111               ; (the crosshairs' position qq9, qq10: the nearest system)
        LDA qq8
        ORA qq8+1
        BEQ hy_r                ; where we are already
        LDA qq8
        BNE hy_far              ; 25.6 light years or more
        LDA qq14
        CMPA qq8+1
        BLO hy_far              ; not enough fuel
        JSR wW
hy_r    RTS
hy_far  LDA #202                ; RANGE
        JMP MESS

; the countdown from 15 (wW)
wW      LDA #56
        JSR NOISE               ; the hyperspace drive
        LDA #15
        STA hnum
        LDA <vcnt
        STA hlast
        RTS

; one frame of the countdown: a step every 20 vsyncs; at the end the jump (TT102's part)
HYPTICK LDA hnum
        BEQ ht_r
        LDA <vcnt
        SUBA hlast
        CMPA #20
        BLO ht_r
        LDA <vcnt
        STA hlast
        DEC hnum
        BNE ht_r
        JMP TT18
ht_r    RTS

; ---- the jump (TT18, hyp1, MJP) ------------------------------------------------------------------

TT18    LDA qq14                ; the fuel for the distance
        SUBA qq8+1
        STA qq14
        JSR TUNNEL
        JSR DORND
        CMPA #253
        BHS MJP                 ; 3 in 256: a mis-jump
        JSR HYP1                ; our place is the system's now
        JSR RES2
        JSR SOLAR
        JSR LOMOD
        CLR <view
        RTS

; arrive in the system of the seeds in qq15: its place, its data, no extra vessels yet (hyp1+3)
HYP1    LDA qq9
        STA qq0
        LDA qq10
        STA qq1
        LDX #qq15
        LDU #qq2
        LDB #6
hy1_l   LDA ,X+
        STA ,U+
        DECB
        BNE hy1_l
        CLR ev
        LDA qq3
        STA qq28
        LDA qq4
        STA gov
        RTS

; a mis-jump into witchspace: three Thargoids and nothing else (MJP)
MJP     LDA #3
        JSR SETSHIPSET
        JSR RES2
        LDA #$FF
        STA mj
mj_l    JSR GTHG
        LDA many+TY_THG
        CMPA #3
        BLO mj_l
        CLR <view
        LDA qq1                 ; and our place has moved
        EORA #$1F
        STA qq1
        RTS

; ---- the galactic hyperdrive (Ghy) --------------------------------------------------------------

; the next galaxy: the seeds' bytes each turn one bit left, the crosshairs go to the middle of
; it, and we jump to the nearest system there
GHY     TST ghyp
        BEQ gh_r
        TST hnum
        BNE gh_r
        TST docked
        BNE gh_r
        CLR ghyp                ; used up
        CLR fist                ; and it clears our name
        JSR wW
        INC gcnt
        LDA gcnt
        ANDA #7
        STA gcnt
        LDX #qq21
        LDB #6
gh_l    LDA ,X
        ASLA
        ROL ,X+
        DECB
        BNE gh_l
        LDA #96
        STA qq9
        STA qq10
        JSR TT111
        CLR qq8
        CLR qq8+1
        LDA #116                ; GALACTIC HYPERSPACE
        JMP MESS
gh_r    RTS

; ---- the tunnel (LL164, HFS2) -----------------------------------------------------------------------

; rings rushing out from the middle of the view, for a second or two
TUNNEL  CLR tunf
        JSR DINIT               ; (the view is cleared whole: no banner in the tunnel)
tn_f    JSR VIEWCLR
        LDD #128
        STD pcx
        LDD #CY
        STD pcy
        CLR tunr
tn_r    LDA tunf                ; ring radius: (frame * 9 + ring * 19) mod 120 + 4
        LDB #9
        MUL
        STB tsc
        LDA tunr
        LDB #19
        MUL
        ADDB tsc
        TFR B,A
tn_m    CMPA #120
        BLO tn_k
        SUBA #120
        BRA tn_m
tn_k    ADDA #4
        STA kr
        JSR SC34A
        STA kry
        JSR CIRCLE
        INC tunr
        LDA tunr
        CMPA #8
        BLO tn_r
        JSR FLIP
        INC tunf
        LDA tunf
        CMPA #10
        BLO tn_f
        RTS

; ---- keys: no tap is lost between two frames ------------------------------------------------------
; The flight reads the keys once a frame (a quarter of a second in a busy scene), so a key pressed
; and let go inside one frame was never seen. Every scan (the IRQ) adds the keys down to KLAT; the
; frame takes them into the matrix and clears it. The scan itself keeps B (the IRQ's key byte).
KLATCH  PSHS B,X,Y
        LDX #kmat
        LDY #klat
        LDB #8
kl_l    LDA ,X+
        ORA ,Y
        STA ,Y+
        DECB
        BNE kl_l
        PULS B,X,Y,PC

KMERGE  ORCC #$10
        LDX #kmat
        LDY #klat
        LDB #8
km_l    LDA ,Y
        ORA ,X
        STA ,X+
        CLR ,Y+
        DECB
        BNE km_l
        ANDCC #$EF
        RTS

KCLEAR  LDX #klat
        LDB #8
kc_l    CLR ,X+
        DECB
        BNE kc_l
        RTS
