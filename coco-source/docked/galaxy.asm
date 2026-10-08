; The galaxy: the seeds and the systems made from them (TT54, TT20, TT24), their names,
; and the commander's name, cash and fuel in the text (cmn, csh, fwl, tal, ypl, cpl).
;
; The seeds are three 16-bit words, six bytes: qq15 is the selected system, qq2 the one we
; are in. One twist: (s0, s1, s2) := (s1, s2, s0 + s1 + s2).

; a twist of the seeds at qq15
TT54    LDA qq15
        ADDA qq15+2
        TFR A,B                 ; B = low of s0 + s1
        LDA qq15+1
        ADCA qq15+3             ; A = high
        PSHS D
        LDD qq15+2              ; s0 := s1
        STD qq15
        LDD qq15+4              ; s1 := s2
        STD qq15+2
        PULS D                  ; s2 := s1 (the new one) + s0 + s1 (old): (D) + s2 new
        ADDB qq15+2
        ADCA qq15+3
        STB qq15+4
        STA qq15+5
        RTS

; four twists (TT20)
TT20    BSR TT54
        BSR TT54
        BSR TT54
        LBRA TT54

; the data of the system of the seeds in qq15: economy qq3 (0 rich industrial .. 7 poor
; agricultural), government qq4, technology qq5, population qq6, productivity qq7 (TT24)
TT24    LDA qq15+1
        ANDA #7
        STA qq3
        LDA qq15+2
        LSRA
        LSRA
        LSRA
        ANDA #7
        STA qq4
        LSRA
        LBNE t24_a
        LDA qq3                 ; an anarchy or a feudal system: the economy is at least 2
        ORA #2
        STA qq3
t24_a   LDA qq3
        EORA #7
        STA qq5
        LDA qq15+3
        ANDA #3
        ADDA qq5
        STA qq5
        LDA qq4
        LSRA
        ADCA qq5                ; BBC LSR/ADC: carry rounds odd governments UP
        STA qq5                 ; technology = (economy EOR 7) + (s1 high AND 3) + ceil(government / 2)
        ASLA
        ASLA
        ADDA qq3
        ADDA qq4
        ADDA #1
        STA qq6                 ; population = 4 * technology + economy + government + 1
        LDA qq3
        EORA #7
        ADDA #3
        LDB qq4
        ADDB #4
        MUL                     ; (3 + (economy EOR 7)) * (4 + government)
        TFR B,A                 ; its low byte
        LDB qq6
        MUL                     ; * population
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        STD qq7                 ; * 8: the productivity (big endian here)
        RTS

; swap the seeds of the selected and the current system (TT62)
TT62    LDX #qq15
        LDY #qq2
        LDB #6
t62_l   LDA ,X
        PSHS A
        LDA ,Y
        STA ,X+
        PULS A
        STA ,Y+
        DECB
        LBNE t62_l
        RTS

; the name of the selected system (cpl): three or four pairs of letters from the seeds
cpl     LDX #qq15               ; keep the seeds
        LDY #qq19
        LDB #6
cpn_s    LDA ,X+
        STA ,Y+
        DECB
        LBNE cpn_s
        LDB #3
        LDA qq15
        BITA #$40
        LBNE cpn_n
        DECB
cpn_n    STB tsc2
cpn_p    LDA qq15+5
        ANDA #$1F
        LBEQ cpn_z
        ORA #$80
        JSR TT27
cpn_z    JSR TT54
        DEC tsc2
        LBPL cpn_p
        LDX #qq19               ; and put them back
        LDY #qq15
        LDB #6
cpn_b    LDA ,X+
        STA ,Y+
        DECB
        LBNE cpn_b
        RTS

; the name of the system we are in (ypl)
ypl     JSR TT62
        JSR cpl
        LBRA TT62

; the commander's name (cmn)
cmn     LDA #$DF
        STA dtw8                ; (MT19: the first letter capital)
        LDY #0
cmn_l    LDA na,Y
        CMPA #13
        LBEQ cmn_r
        JSR TT26
        LEAY 1,Y
        LBNE cmn_l
cmn_r    RTS

; the galaxy number (tal)
tal     LDB gcnt
        INCB
        CLRA
        TFR D,X
        ANDCC #$FE
        JMP pr2

; FUEL: 7.0 LIGHT YEARS and a newline, then CASH: and the amount (fwl)
fwl     LDA #105
        JSR TT68
        LDB qq14
        CLRA
        TFR D,X
        ORCC #1
        JSR pr2
        LDA #195
        JSR plf
        LDA #119
        JMP TT27

; the cash and CR, and a newline (csh)
csh     LDX #cash
        LDY #knum
        LDB #4
cs_c    LDA ,X+
        STA ,Y+
        DECB
        LBNE cs_c
        LDA #9
        STA ptw
        ORCC #1
        JSR BPRNT
        LDA #226
        JMP plf

; the selected system's seeds := those of system 0 of the galaxy (TT81)
TT81    LDX #qq21
        LDY #qq15
        LDB #6
t81_l   LDA ,X+
        STA ,Y+
        DECB
        LBNE t81_l
        RTS

; The system nearest to the point (qq9, qq10) becomes the selected one (TT111): every one of
; the 256 systems is made by twisting the galaxy's seeds, its distance from the point (half
; the x distance plus half the y distance) measured, and the best kept. Then qq9, qq10 are
; its place, qq8 the distance from where we are, in tenths of a light year, and TT24 gives
; its data.
TT111   JSR TT81
        LDA #127
        STA tsc2                ; the best distance so far
        CLR tyy                 ; the system number
t11_l   LDA qq15+3
        SUBA qq9
        LBHS t11_a
        NEGA
t11_a   LSRA
        STA tsc
        LDA qq15+1
        SUBA qq10
        LBHS t11_b
        NEGA
t11_b   LSRA
        ADDA tsc
        CMPA tsc2
        LBHS t11_c
        STA tsc2
        LDX #qq15
        LDY #qq19
        LDB #6
t11_s   LDA ,X+
        STA ,Y+
        DECB
        LBNE t11_s
        LDA tyy
        STA zz
t11_c   JSR TT20
        INC tyy
        LBNE t11_l
        LDX #qq19
        LDY #qq15
        LDB #6
t11_r   LDA ,X+
        STA ,Y+
        DECB
        LBNE t11_r
        LDA qq15+1
        STA qq10
        LDA qq15+3
        STA qq9
        SUBA qq0
        LBHS t11_d
        NEGA
t11_d   TFR A,B
        MUL
        STD <tmp                ; dx^2
        LDA qq10
        SUBA qq1
        LBHS t11_e
        NEGA
t11_e   LSRA
        TFR A,B
        MUL
        ADDD <tmp               ; + (dy/2)^2
        JSR ISQRT16
        CLRA
        ASLB                    ; * 4
        ROLA
        ASLB
        ROLA
        STD qq8
        JMP TT24

; the market table (QQ23): 17 items of price, sign|unit|factor, quantity, mask (see docked/market.asm)
QQ23
        FCB 19,130,6,1
        FCB 20,129,10,3
        FCB 65,131,2,7
        FCB 40,133,226,31
        FCB 83,133,251,15
        FCB 196,8,54,3
        FCB 235,29,8,120
        FCB 154,14,56,3
        FCB 117,6,40,7
        FCB 78,1,17,31
        FCB 124,13,29,7
        FCB 176,137,220,63
        FCB 32,129,53,3
        FCB 97,161,66,7
        FCB 171,162,55,31
        FCB 45,193,250,15
        FCB 53,15,192,7

; qq19+3 := the economy times the size of the item's factor, from the item's table byte mk+1 (var)
VAR     LDA mk+1
        ANDA #31
        STA mk+2
        LDB qq28
        CLRA
va_l    DECB
        LBMI va_d
        ADDA mk+2
        LBRA va_l
va_d    STA mk+3
        RTS

; the market of the system we have arrived at: its economy, a random price variation, and what
; is for sale (GVL: the quantity is the base plus a random part, less the economic factor)
GVL     LDA qq3
        STA qq28
        JSR DORND
        STA qq26
        CLR tyy                 ; the item
gv_l    LDB tyy
        ASLB
        ASLB
        LDX #QQ23
        ABX
        LDA 1,X
        STA mk+1
        PSHS X
        JSR VAR
        PULS X
        LDA qq26
        ANDA 3,X
        ADDA 2,X
        LDB mk+1
        LBMI gv_7
        SUBA mk+3               ; (a negative result is none)
        LBRA gv_8
gv_7    ADDA mk+3
gv_8    TSTA
        LBPL gv_9
        CLRA
gv_9    ANDA #$3F
        LDB tyy
        LDX #avl
        ABX
        STA ,X
        INC tyy
        LDA tyy
        CMPA #17
        LBLO gv_l
        RTS

; the tables of ISQRT16 and NORM3, built once at start-up (in the RAM above $8000):
; RTAB[h] = isqrt(h*256+255);  NTH/NTL[n] = 96*256/n, high and low bytes (n 1..255)
MKTABS  LDX #RTAB
        CLR <tmp2               ; r
        CLR <cnt                ; h
mt_r    LDA <tmp2
        INCA
        BEQ mt_s                ; r = 255 is the largest
        TFR A,B
        MUL                     ; (r+1)^2 <= h*256+255 when its high byte <= h
        CMPA <cnt
        BHI mt_s
        INC <tmp2
        BRA mt_r
mt_s    LDA <tmp2
        STA ,X+
        INC <cnt
        BNE mt_r
        LDA #1
        STA <cnt
mt_n    LDD #24576
        STD <mr+2
        LDD #0
        STD <mr
        STA <md
        LDB <cnt
        STB <md+1
        JSR DIV32
        LDX #NTH
        LDB <cnt
        ABX
        LDD <mr+2
        STA ,X
        STB 256,X
        INC <cnt
        BNE mt_n
        RTS
