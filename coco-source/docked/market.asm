; The market: the price list (TT167), buying (TT219), selling (TT208), the inventory (TT213),
; and what they share: the price of an item (TT151), its unit (TT152), reading a number
; (gnum), the cargo space (tnpr) and the cash (GCASH, LCASH).
;
; An item of the market table QQ23 is 4 bytes: the base price, a byte with the sign of the
; economic factor (bit 7), the unit (bits 5-6: 0 tonnes, 1 kilograms, 2 grams) and the
; factor's size, then the base quantity and a mask for the random part. The commodities
; are numbered 0-16, and their names are the tokens 208-224.

; ---- unit, price, quantity ----------------------------------------------------------------------

; the unit of the item whose table byte is in mk+1 (TT152)
TT152   LDA mk+1
        ANDA #96
        LBEQ TT160
        CMPA #32
        LBEQ TT161
        BSR TT16a
TT162m  LDA #' '
        JMP TT27
TT160   LDA #'t'
        JSR TT26
        LBRA TT162m
TT161   LDA #'k'
        JSR TT26
TT16a   LDA #'g'
        JMP TT26

; the headers of the table (TT163)
TT163   LDA #17
        STA xc
        LDA #255
        JMP TT27

; item A: its name, unit, price and the quantity for sale, on the line (TT151)
TT151   PSHS A
        STA mk+4
        ASLA
        ASLA
        STA mk
        LDA #1
        STA xc
        PULS A
        ADDA #208
        JSR TT27
        LDA #14
        STA xc
        LDB mk
        LDX #QQ23
        ABX
        LDA 1,X
        STA mk+1
        LDA qq26
        ANDA 3,X
        ADDA ,X
        STA qq24
        JSR TT152
        PSHS X
        JSR VAR
        PULS X
        LDA mk+1
        LBMI t151_5
        LDA qq24
        ADDA mk+3
        LBRA t151_6
t151_5  LDA qq24
        SUBA mk+3
t151_6  STA qq24
        LDB qq24                ; the price * 4, tenths of a credit
        CLRA
        ASLB
        ROLA
        ASLB
        ROLA
        TFR D,X
        ORCC #1
        JSR pr5
        LDB mk+4
        LDX #avl
        ABX
        LDA ,X
        STA qq25
        LBEQ t151_7
        LDB qq25
        CLRA
        TFR D,X
        ANDCC #$FE
        LDA #5
        JSR TT11
        LBRA TT152
t151_7  LDA xc
        ADDA #4
        STA xc
        LDA #'-'
        JMP TT27

; ---- the price list (TT167) ---------------------------------------------------------------------

TT167   LDA #16
        JSR TT66
        LDA #5
        STA xc
        LDA #167
        JSR NLIN3
        LDA #3
        STA yc
        JSR TT163
        CLR qq29
t167_l  LDA #$80
        STA qq17
        LDA qq29
        JSR TT151
        INC yc
        INC qq29
        LDA qq29
        CMPA #17
        LBLO t167_l
        RTS

; ---- cargo space and cash --------------------------------------------------------------------------

; (TNPR and TNPR1, the room in the hold, are in flight/combat.asm: scooping needs them too)

; (Y X) := P * Q * 4 as a 32-bit tenths-of-a-credit amount (GCASH).
; Large quantities of high-priced commodities can exceed a 16-bit total.
GCASH   LDA tsc
        LDB tsc2
        MUL
        TFR D,X
        TFR A,B
        ANDB #$C0                ; product bits 14-15 become bits 0-1 after the *4
        LSRB
        LSRB
        LSRB
        LSRB
        LSRB
        LSRB
        CLRA
        TFR D,Y
        TFR X,D
        ASLB
        ROLA
        ASLB
        ROLA
        TFR D,X
        RTS

; cash := cash - X (LCASH): the equipment shop still uses a 16-bit cost
LCASH   LDD cash+2
        PSHS X
        SUBD ,S++
        LBLO lc_no               ; the low half is short: borrow from the high half
        STD cash+2
        ORCC #1
        RTS
lc_no   STD knum                ; the result of the low word, wrapped
        LDD cash
        SUBD #1
        LBLO lc_x
        STD cash
        LDD knum
        STD cash+2
        ORCC #1
        RTS
lc_x    ANDCC #$FE
        RTS

; cash := cash - Y:X (LCASH32): the market uses the full GCASH amount
LCASH32 STY knum
        STX knum+2
        LDD cash
        CMPD knum
        BLO lc32_x
        BHI lc_pay
        LDD cash+2
        CMPD knum+2
        BLO lc32_x
lc_pay  LDD cash+2
        SUBD knum+2
        STD cash+2
        LDD cash
        SBCB knum+1
        SBCA knum
        STD cash
        ORCC #1
        RTS
lc32_x  ANDCC #$FE
        RTS

; ---- reading a number (gnum) ---------------------------------------------------------------------
; returns the number in A (and gnr) with carry clear, or carry set when it was more than there is
; (qq25). Digits only; RETURN ends; y is all there is and n is none for the first key; any
; other key gives up and goes to the inventory.
GNUM    CLR gnr
        LDA #12
        STA gnn
gn_l    JSR TT217
        LDB gnr
        LBNE gn_2
        CMPA #'y'
        LBEQ gn_y
        CMPA #'n'
        LBEQ gn_n
gn_2    STA gnq
        SUBA #'0'
        LBLO gn_out
        CMPA #10
        LBHS BAY2
        STA gnd
        LDA gnr
        CMPA #26
        LBHS gn_ov
        ASLA
        STA gnt
        ASLA
        ASLA
        ADDA gnt
        ADDA gnd
        STA gnr
        CMPA qq25
        LBEQ gn_e
        LBHI gn_ov
gn_e    LDA gnq
        JSR TT26
        DEC gnn
        LBNE gn_l
gn_out  LDA gnr
        ANDCC #$FE
        RTS
gn_ov   LDA gnr
        ORCC #1
        RTS
gn_y    JSR TT26
        LDA qq25
        STA gnr
        ANDCC #$FE
        RTS
gn_n    JSR TT26
        CLR gnr
        CLRA
        ANDCC #$FE
        RTS

; ---- buying (TT219) ------------------------------------------------------------------------------------

TT219   LDA #2
        JSR TT66
        JSR TT163
        LDA #$80
        STA qq17
        JSR FLKB
        CLR qq29
t219_i  LDA qq29
        JSR TT151
        LDA qq25
        LBNE TT224
        JMP TT222
TQ4     LDY #176
Tc      JSR TT162
        TFR Y,D
        TFR B,A
        JSR prq
TTX224  JSR dn2
TT224   JSR CLYNS
        LDA #204
        JSR TT27
        LDA qq29
        ADDA #208
        JSR TT27
        LDA #'/'
        JSR TT27
        LDB qq29
        LDX #QQ23
        ASLB
        ASLB
        ABX
        LDA 1,X
        STA mk+1
        JSR TT152
        LDA #'?'
        JSR TT27
        JSR TT67
        JSR GNUM
        LBCS TQ4
        STA tsc                 ; P: the amount
        JSR TNPR
        LDY #206
        LBCS Tc                  ; no room
        LDA qq24
        STA tsc2                ; Q: the price
        JSR GCASH
        JSR LCASH32
        LDY #197
        LBCC Tc                  ; not enough cash
        LDB qq29
        LDX #qq20
        ABX
        LDA gnr
        PSHS A
        ADDA ,X
        STA ,X
        LDX #avl
        LDB qq29
        ABX
        LDA ,X
        SUBA ,S
        STA ,X
        PULS A
        LBEQ TT222
        JSR dn
TT222   LDA qq29
        ADDA #5
        STA yc
        CLR xc
        INC qq29
        LDA qq29
        CMPA #17
        LBHS BAY2
        JMP t219_i

; ---- selling and the inventory (TT208, TT210, TT213) -------------------------------------------------

TT208   LDA #4
        JSR TT66
        LDA #10
        STA xc
        JSR FLKB
        LDA #205
        JSR TT27
        LDA #206
        JSR NLIN3
        JSR TT67
; the list of what is in the hold (TT210): in the sell screen, each is offered for sale
TT210   CLRB
t211    STB qq29
t211b   LDX #qq20
        ABX
        LDA ,X
        LBEQ TT212
        PSHS A
        JSR TT69
        LDA qq29
        ADDA #208
        JSR TT27
        LDA #14
        STA xc
        PULS A
        STA qq25
        LDB qq29
        LDX #QQ23
        ASLB
        ASLB
        ABX
        LDA 1,X
        STA mk+1
        LDB qq25
        CLRA
        TFR D,X
        ANDCC #$FE
        JSR pr2
        JSR TT152
        LDA qq11
        CMPA #4
        LBNE TT212
        LDA #205
        JSR TT27
        LDA #206
        JSR DETOK
        JSR GNUM
        LBEQ TT212              ; none
        LBCS NWDAV4
        LDA qq29
        LDB #$FF
        STB qq17
        JSR TT151
        LDB qq29
        LDX #qq20
        ABX
        LDA ,X
        SUBA gnr
        STA ,X
        LDA gnr
        STA tsc
        LDA qq24
        STA tsc2
        JSR GCASH
        JSR MCASHX
        CLR qq17
TT212   LDB qq29
        INCB
        CMPB #17
        LBLO t211
        LDA qq11
        CMPA #4
        LBNE tt212r
        JSR dn2
        JMP BAY2
tt212r  RTS
NWDAV4  JSR TT67
        LDA #176
        JSR prq
        JSR dn2
        LDB qq29
        JMP t211b

; the cash += Y:X (the full GCASH amount)
MCASHX  STY knum
        STX knum+2
        LDD cash+2
        ADDD knum+2
        STD cash+2
        BCC mcx_hi
        LDD cash
        ADDD knum
        ADDD #1
        STD cash
        RTS
mcx_hi  LDD cash
        ADDD knum
        STD cash
        RTS

TT213   LDA #8
        JSR TT66
        LDA #11
        STA xc
        LDA #164
        JSR TT60
        JSR NLIN4
        JSR fwl
        LDA crgo
        CMPA #26
        LBLO tt213a
        LDA #107
        JSR TT27
tt213a  JMP TT210

; ---- small things ----------------------------------------------------------------------------------------

; a token and a paragraph break (TT60), a newline in sentence case (TT69, TT67)
TT60    JSR TT27
TTX69   INC yc
TT69    LDA #$80
        STA qq17
        JMP TT67

; the token A and a question mark (prq)
prq     JSR TT27
        LDA #'?'
        JMP TT27

; money left, a beep and a pause (dn, dn2)
dn      JSR TT162
        LDA #119
        JSR spc
dn2     JSR BEEP
        LDY #50
        JMP DELAY

; wait Y fiftieths of a second (DELAY)
DELAY   JSR WAITVS
        LEAY -1,Y
        LBNE DELAY
        RTS

; flush the keyboard: wait until no key is down (FLKB)
FLKB    JSR KEYSCAN
        TSTA
        LBNE FLKB
        CLR lastkey
        RTS

; wait for a key and return it as the original's keyboard table gives it (TT217)
TT217   JSR WAITKEY
        RTS

; a question with a Y/N answer (TT214): carry set for yes
TT214   JSR TT27
        LDA #206
        JSR DETOK
        JSR TT217
        ORA #$20
        CMPA #'y'
        LBEQ tt218
        LDA #'n'
        JMP TT26
tt218   JSR TT26
        ORCC #1
        RTS

; back to the inventory (BAY2: the original forces the f9 key)
BAY2    LDA #'9'
        STA pendkey
        LDS dmsp                ; out of whatever screen we were in, to the docked loop
        JMP dm_aft
