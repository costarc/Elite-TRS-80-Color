; The text of the docked screens: the original's CHPR (a character at the cursor), TT26 /
; DASC with its justified lines, TT27 (text tokens), DETOK (extended tokens), the jump
; tokens, and the number printing (BPRNT).
;
; The screen is 32 columns by 24 rows of 8 x 8 cells, as in the original; the cursor is
; (xc, yc), a cell's byte is back + yc * 256 + xc (+ 32 per line). Characters are ORed in.
; The tables are in gen/tokens.inc (tools/tokens.py), plain (the original hides them with
; an EOR). All the registers are kept except A and CC.

LL      EQU 30                  ; the width of justified text

; ---- one character at the cursor (CHPR) ---------------------------------------------------------
; A = the character: 7 beep, 10 line feed, 12 newline (back to column 1 on the next row),
; 13 carriage return, 32-126 a glyph, 127 delete. Printing is off when qq17 is $FF. Rows
; past the 24th clear the screen.
CHPR    PSHS B,X,Y,U
        STA tsc
        LDB qq17
        INCB
        LBEQ chp_x                   ; printing is off
        TSTA
        LBEQ chp_x
        LBMI chp_x
        CMPA #7
        LBEQ chp_bp
        CMPA #32
        LBHS chp_g
        CMPA #10
        LBEQ chp_lf
        LDB #1
        STB xc
        CMPA #13
        LBEQ chp_x
chp_lf   INC yc
        LBRA chp_x
chp_bp   JSR BEEP
        LBRA chp_x
chp_g    LDB yc
        CMPB #24
        LBLO chp_ok
        LDB mpg
        LBEQ chp_cl
        JSR MOREENTRY               ; a mission text: a key, then the rest of the text over this one
        LDA tsc
        LBRA chp_g
chp_cl  JSR TTX66                   ; off the bottom: clear and go on at the top
        LDA tsc
        LBRA chp_g
chp_ok   LDB xc
        CMPB #32
        LBHS chp_x                    ; off the right edge: lost
        LDX dbp                     ; (O11: its band)
        LDB yc
        LDA #$FF
        STA B,X
        LDA yc
        CLRB
        ADDD <back
        ADDB xc
        ADCA #0
        TFR D,U                     ; the cell
        LDA tsc
        CMPA #127
        LBNE chp_p
        DEC xc                      ; delete: the cell to the left is cleared
        LEAU -1,U
        CLR ,U
        CLR 32,U
        CLR 64,U
        CLR 96,U
        CLR 128,U
        CLR 160,U
        CLR 192,U
        CLR 224,U
        LBRA chp_x
chp_p    INC xc
        SUBA #32
        LDB #8
        MUL
        ADDD #FONT
        TFR D,X                     ; the glyph's 8 rows
        LDA ,X+
        ORA ,U
        STA ,U
        LDA ,X+
        ORA 32,U
        STA 32,U
        LDA ,X+
        ORA 64,U
        STA 64,U
        LDA ,X+
        ORA 96,U
        STA 96,U
        LDA ,X+
        ORA 128,U
        STA 128,U
        LDA ,X+
        ORA 160,U
        STA 160,U
        LDA ,X+
        ORA 192,U
        STA 192,U
        LDA ,X
        ORA 224,U
        STA 224,U
chp_x    PULS B,X,Y,U
        LDA tsc
        ANDCC #$FE
        RTS

; ---- a character with the word and justification logic (DASC / TT26) ------------------------------
FEED    LDA #12
        LBRA TT26
MT16    LDA dtw7
DASC    EQU *
TT26    PSHS B,X,Y,U
        STA tsc
        LDB #$FF
        STB dtw8                    ; (no capitalising now)
        CMPA #'.'
        LBEQ da_8
        CMPA #':'
        LBEQ da_8
        CMPA #10
        LBEQ da_8
        CMPA #12
        LBEQ da_8
        CMPA #' '
        LBEQ da_8
        INCB                        ; a letter: we are in a word
da_8    STB dtw2
        TST dtw4
        LBMI da_j
        PULS B,X,Y,U
        LDA tsc
        JMP CHPR
da_j    LDA tsc
        CMPA #12
        LBEQ DA1
        LDB dtw5                    ; justified text: into the buffer (which is 64 long: na follows)
        CMPB #63
        LBHS da_f
        LDX #buf
        ABX
        STA ,X
        INC dtw5
da_f    PULS B,X,Y,U
        ANDCC #$FE
        RTS

; the end of a line of justified text: print it, spreading the spaces to fill LL columns
DA1     LDB dtw5
        LBEQ da_e                    ; nothing: only the newline
        CMPB #LL+1
        LBLO da_s                    ; short enough: as it is
        LSR tsc2
da_11   LDA tsc2
        LBMI da_a
        LDA #$40
da_a    STA tsc2
        LDB #LL-1
        STB tyy
da_l1   LDA buf+LL
        CMPA #' '
        LBEQ DA2
da_l2   DEC tyy
        LBMI da_11
        LBEQ da_11
        LDB tyy
        LDX #buf
        ABX
        LDA ,X
        CMPA #' '
        LBNE da_l2
        ASL tsc2
        LBMI da_l2
        LDA tyy
        STA tsc                     ; where the extra space goes
        LDB dtw5                    ; open it up: shift the rest right
        CMPB #63                    ; (unless the buffer is full: na follows it, and the
        LBHS DA2                    ; shift would push the text's end into the name)
da_l6   LDX #buf
        ABX
        LDA ,X
        STA 1,X
        DECB
        CMPB tsc
        LBHS da_l6
        INC dtw5
        STB tyy
        LDA #' '
da_l3   LDB tyy
        LBMI da_11
        LDX #buf
        ABX
        CMPA ,X
        LBNE da_l1
        DEC tyy
        LBRA da_l3
DA2     LDB #LL
        JSR DAS1
        LDA #12
        JSR CHPR
        LDA dtw5                    ; (the original's SBC with the carry CHPR clears: one more)
        SUBA #LL+1
        STA dtw5
        LBEQ da_e
        TFR A,B
        INCB
        LDU #buf+LL+1
        LDX #buf
da_l4   LDA ,U+
        STA ,X+
        DECB
        LBNE da_l4
        LBRA DA1
da_s    JSR DAS1                    ; print B characters from the buffer
da_e    CLR dtw5
        PULS B,X,Y,U
        LDA #12
        JMP CHPR

DAS1    LDX #buf
da_p    LDA ,X+
        PSHS B,X
        JSR CHPR
        PULS B,X
        DECB
        LBNE da_p
        RTS

; ---- text tokens (TT27) --------------------------------------------------------------------------
; A = the token: 0-9 special (0 cash, 1 galaxy number, 2 this system, 3 the selected system,
; 4 commander, 5 fuel and cash, 6 sentence case, 8 normal, 9 tab and a colon), 10-13 control
; characters, 14-31 tokens 128-145, 32-95 characters, 96-127 recursive tokens, 128-159 pairs
; of letters, 160 and up recursive tokens
TT27    PSHS A
        TSTA
        LBEQ tk_0
        LBMI TT43
        CMPA #1
        LBEQ tk_1
        CMPA #2
        LBEQ tk_2
        CMPA #3
        LBEQ tk_3
        CMPA #4
        LBEQ tk_4
        CMPA #5
        LBEQ tk_5
        CMPA #6
        LBEQ tk_6
        CMPA #8
        LBEQ tk_8
        CMPA #9
        LBEQ tk_9
        CMPA #96
        LBHS tk_ex
        CMPA #14
        LBLO tk_c
        CMPA #32
        LBLO tk_q
tk_c    LDB qq17                    ; a character: with the case rules
        LBEQ TT74
        LBMI TT41
        BITB #$40
        LBNE TT46
TT42    CMPA #'A'
        LBLO TT44
        CMPA #'Z'+1
        LBHS TT44
        ADDA #32
TT44    JMP tk_pr
TT41    BITB #$40
        LBNE TT45
        CMPA #'A'
        LBLO TT74
        PSHS A                      ; the first letter of a word in capitals: the rest lower case
        LDB qq17
        ORB #$40
        STB qq17
        PULS A
        LBRA TT44
tk_q    ADDA #114                   ; 14-31: the tokens 128-145
        LBRA tk_ex
TT45    CMPB #255
        LBEQ tk_ret
        CMPA #'A'
        LBHS TT42
TT46    PSHS A
        LDB qq17
        ANDB #$BF
        STB qq17
        PULS A
TT74    EQU *
tk_pr   JSR TT26
tk_ret  PULS A
        RTS
tk_0    JSR csh
        PULS A
        RTS
tk_1    JSR tal
        PULS A
        RTS
tk_2    JSR ypl
        PULS A
        RTS
tk_3    JSR cpl
        PULS A
        RTS
tk_4    JSR cmn
        PULS A
        RTS
tk_5    JSR fwl
        PULS A
        RTS
tk_6    LDA #$80
        STA qq17
        PULS A
        RTS
tk_8    CLR qq17
        PULS A
        RTS
tk_9    LDA #21
        STA xc
        JSR TT73
        PULS A
        RTS
TT43    CMPA #160                   ; 128-159: two letters
        LBHS TT47
        ANDA #127
        ASLA
        LDX #QQ16
        TFR A,B
        ABX
        LDA ,X
        PSHS X
        JSR TT27
        PULS X
        LDA 1,X
        CMPA #'?'
        LBEQ tk_ret
        JSR TT27
        LBRA tk_ret
TT47    SUBA #160
tk_ex   BSR ex                      ; a recursive token
        LBRA tk_ret

; print recursive token A (0-148): scan to it in QQ18 and print each of its characters
ex      PSHS A,X
        LDX #QQ18
        TSTA
        LBEQ txe_p
        TFR A,B
txe_s    LDA ,X+
        LBNE txe_s
        DECB
        LBNE txe_s
txe_p    LDA ,X+
        LBEQ txe_r
        EORA #$23               ; (the table is hidden with the original's EOR)
        PSHS X
        JSR TT27
        PULS X
        LBRA txe_p
txe_r    PULS A,X
        RTS

TT73    LDA #':'
        JMP TT27

TT67    LDA #12
        JMP TT27

crlf    LDA #21
        STA xc
        LBRA TT73

; text token A and a newline
plf     JSR TT27
        JMP TT67

; token A and a colon
TT68    JSR TT27
        LBRA TT73

; ---- numbers (BPRNT) --------------------------------------------------------------------------
; The 32-bit number in knum (big endian) printed in a field of tw digits (tw includes the decimal
; point if carry was set: the number is then tenths); leading zeros are spaces.
; BPRNT: carry set for one decimal.
BPRNT   LDA #0
        ROLA
        STA pdec
        LDX #pdig+11                ; the digits, least significant last
        LDY #11
bp_d    JSR DIV10K                  ; knum := knum / 10, remainder in A
        ADDA #'0'
        STA ,-X
        LEAY -1,Y
        LBNE bp_d
        LDA pdec                    ; the first digit to print: skip the leading zeros but keep
        LDB #10                     ; one digit (two, with a decimal point) of the number
        TSTA
        LBEQ bp_k
        LDB #9
bp_k    STB tsc2                    ; the last index allowed to be a leading zero
        CLRB
        LDX #pdig
bp_z    CMPB tsc2
        LBHS bp_f
        LDA B,X
        CMPA #'0'
        LBNE bp_f
        INCB
        LBRA bp_z
bp_f    STB pfirst                  ; digits pfirst .. 10 are printed
        LDA #11
        SUBA pfirst
        ADDA pdec                   ; their width, with the point
        STA tsc2
        LDA ptw                     ; spaces to fill the field
        SUBA tsc2
        LBLS bp_n
        TFR A,B
bp_sp   LDA #' '
        JSR TT26
        DECB
        LBNE bp_sp
bp_n    LDB pfirst
bp_p    LDX #pdig
        LDA B,X
        PSHS B
        JSR TT26
        PULS B
        INCB
        CMPB #10
        LBNE bp_q
        TST pdec
        LBEQ bp_q
        LDA #'.'
        PSHS B
        JSR TT26
        PULS B
bp_q    CMPB #11
        LBLO bp_p
        RTS

; knum := knum / 10, A = the remainder
DIV10K  CLRA
        LDB knum
        BSR d10
        STB knum
        LDB knum+1
        BSR d10
        STB knum+1
        LDB knum+2
        BSR d10
        STB knum+2
        LDB knum+3
        BSR d10
        STB knum+3
        RTS
; (A:B) / 10: B = the quotient, A = the remainder (A < 10)
d10     PSHS Y
        LDY #8
d10_l   ASLB
        ROLA
        CMPA #10
        LBLO d10_n
        SUBA #10
        INCB
d10_n   LEAY -1,Y
        LBNE d10_l
        PULS Y
        RTS

; X = the number (Y the high byte, 0 for 8-bit), A = digits: print it (TT11 / pr2 / pr5)
; carry set: with one decimal
pr2     LDA #3
TT11    STA ptw
        PSHS CC                     ; (the carry says: with a decimal point)
        CLR knum
        CLR knum+1
        TFR X,D
        STA knum+2
        STB knum+3
        PULS CC
        LBRA BPRNT
pr6     ANDCC #$FE
pr5     LDA #5
        LBRA TT11

; ---- the screen ---------------------------------------------------------------------------------

; A = the view type (qq11): clear the screen and draw the box (TT66)
TT66    STA qq11
TTX66   LDA #$20                ; Sentence Case (MT2)
        STA dtw1
        CLR dtw6
        CLR dtw4                ; (no justified text left over from a screen that ended in it)
        CLR dtw5
        LDA #$80
        STA qq17
        STA dtw2
        LDX <back               ; clear the 24 rows
        LDY #192*16
        LDD #0
tx_c    STD ,X++
        LEAY -1,Y
        LBNE tx_c
        LDA #1
        STA yc
        CLR qq17
        LDD #$0000              ; the box: the top, and the sides
        STD <lx0
        LDD #$FF00
        STD <lx1
        JSR LINE
        LDD #$0001
        STD <lx0
        LDD #$00BF
        STD <lx1
        JSR LINE
        LDD #$FF01
        STD <lx0
        LDD #$FFBF
        STD <lx1
        JMP LINE

; a text token, then a line under the row (NLIN3), under row 1 (NLIN4), the row at A (NLIN2)
NLIN3   JSR TT27
NLIN4   LDA #19
        LBRA NLIN2
NLIN    LDA #23
        INC yc
NLIN2   STA lny
        LDA #2
        STA <lx0
        LDA #254
        STA <lx1
        LDA lny
        STA <lx0+1
        STA <lx1+1
        JMP LINE

