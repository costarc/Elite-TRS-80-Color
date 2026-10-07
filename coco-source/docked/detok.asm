; Extended text tokens (the original's DETOK, DETOK2, DETOK3 and the jump tokens MTx): the
; texts of menus, descriptions and missions, in TKN1 and RUTOK (gen/tokens.inc).
;
; A token is a string of bytes ended with 0; the table starts with a 0, so the first token
; is number 1. A byte is: 1-31 a jump token (a handler in JMTB), 32-90 a character,
; 91-128 a random token (one of five, MTIN), 129-214 another extended token, 215-255 a
; pair of letters (TKN2). In "standard" mode (dtw3 $FF) the bytes are standard tokens.

; print extended token A of TKN1 (DETOK) / of RUTOK (DETOK3)
DETOK3  PSHS A,B,X,Y,U
        LDX #RUTOK
        LBRA dt_en
DETOK   PSHS A,B,X,Y,U
        LDX #TKN1
dt_en   TFR A,B
dt_s    LDA ,X+                 ; to the start of token B
        LBNE dt_s
        DECB
        LBNE dt_s
dt_p    LDA ,X+
        LBEQ dt_x
        PSHS X
        BSR DETOK2
        PULS X
        LBRA dt_p
dt_x    PULS A,B,X,Y,U
        RTS

; one byte of an extended token (DETOK2)
DETOK2  CMPA #32
        LBLO dt_j
        TST dtw3
        LBPL dt_8
        JMP TT27                ; standard tokens
dt_8    CMPA #'['
        LBLO DTS
        CMPA #129
        LBLO dt_r
        CMPA #215
        LBLO DETOK
        SUBA #215               ; a pair of letters
        ASLA
        LDX #TKN2
        TFR A,B
        ABX
        PSHS X
        LDA ,X
        BSR DTS
        PULS X
        LDA 1,X
DTS     CMPA #'A'
        LBLO dt_9
        TST dtw6
        LBMI dt_10
        TST dtw2
        LBMI dt_5
dt_10   ORA dtw1
dt_5    ANDA dtw8
dt_9    JMP DASC
dt_j    PSHS A                  ; a jump token: its handler, called with the token number
        ASLA
        TFR A,B
        CLRA
        LDX #JMTB-2
        LEAX D,X
        LDX ,X
        PULS A
        PSHS A
        ANDCC #$FE              ; (the original calls its handlers with the carry clear)
        JSR ,X
        PULS A
        RTS
dt_r    PSHS A                  ; a random token: MTIN[t-91] + (0..4)
        JSR DORND2              ; (the 6502 code reaches this with the carry clear, and DORND uses it)
        TFR A,B
        CLRA
        CMPB #51
        LBLO dt_r1
        INCA
dt_r1   CMPB #102
        LBLO dt_r2
        INCA
dt_r2   CMPB #153
        LBLO dt_r3
        INCA
dt_r3   CMPB #204
        LBLO dt_r4
        INCA
dt_r4   TFR A,B
        PULS A
        PSHS B
        SUBA #91
        LDX #MTIN
        TFR A,B
        ABX
        LDA ,X
        ADDA ,S+
        LBRA DETOK

; ---- the jump tokens ----------------------------------------------------------------------------
MT1     CLR dtw1                ; ALL CAPS
        CLR dtw6
        RTS
MT2     LDA #$20                ; Sentence Case
        STA dtw1
        CLR dtw6
        RTS
MT8     LDA #6                  ; tab 6, between words
        STA xc
        LDA #$FF
        STA dtw2
        RTS
MT9     LDA #1                  ; clear the screen
        STA xc
        LDA #1
        JMP TT66
MT13    LDA #$80
        STA dtw6
        LDA #$20
        STA dtw1
        RTS
MT6     LDA #$80                ; standard tokens, Sentence Case
        STA qq17
        LDA #$FF
        STA dtw3
        RTS
MT5     CLR dtw3                ; extended tokens
        RTS
MT14    LDA #$80                ; justified text
        STA dtw4
        CLR dtw5
        RTS
MT15    CLR dtw4                ; left aligned
        CLR dtw5
        RTS
MT17    LDA qq17                ; the selected system's adjective
        ANDA #$BF
        STA qq17
        LDA #3
        JSR TT27
        LDB dtw5
        LBEQ mt_17
        LDX #buf-1
        ABX
        LDA ,X
        BSR VOWEL
        LBCC mt_17
        DEC dtw5                ; a vowel at the end goes: Lave -> Lavian
mt_17   LDA #153
        JMP DETOK
MT18    BSR MT19                ; a random word of up to 4 pairs of letters
        ANDCC #$FE
        JSR DORND
        ANDA #3
        TFR A,B                 ; (not TFR A,Y: the high byte of a 16-bit target is not zero)
        CLRA
        TFR D,Y
mt_18   ANDCC #$FE
        JSR DORND
        ANDA #62
        LDX #TKN2+2
        TFR A,B
        ABX
        LDA ,X
        PSHS X,Y
        JSR DTS
        PULS X,Y
        LDA 1,X
        PSHS Y
        JSR DTS
        PULS Y
        LEAY -1,Y
        CMPY #$FFFF
        LBNE mt_18
        RTS
MT19    LDA #$DF                ; capitalise the next letter
        STA dtw8
        RTS

; carry set when A is a vowel
VOWEL   ORA #$20
        CMPA #'a'
        LBEQ vw_y
        CMPA #'e'
        LBEQ vw_y
        CMPA #'i'
        LBEQ vw_y
        CMPA #'o'
        LBEQ vw_y
        CMPA #'u'
        LBEQ vw_y
        ANDCC #$FE
        RTS
vw_y    ORCC #1
        RTS

; the jump token table (JMTB), tokens 1-32
JMTB    FDB MT1,MT2,TT27,TT27,MT5,MT6,DASC,MT8
        FDB MT9,DASC,NLIN4,DASC,MT13,MT14,MT15,MT16
        FDB MT17,MT18,MT19,DASC,CLYNS,PAUSE,MT23,PAUSE2
        FDB BRIS,MT26,MT27,MT28,MT29,DASC,DASC,DASC
