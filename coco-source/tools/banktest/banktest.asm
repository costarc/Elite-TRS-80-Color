        ORG $C000
        ORCC #$50
        LDX #RAMCODE
        LDU #$2000
cp      LDA ,X+
        STA ,U+
        CMPX #RAMEND
        BNE cp
        JMP $2000
RAMCODE
top     LDX #$0400
        CLRB
lp      STB $FF40
        LDA $C100
        STA ,X+
        INCB
        CMPB #8
        BNE lp
        BRA top
RAMEND
        ORG $C100
        FCB 'A'
