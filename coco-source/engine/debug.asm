; Debug aid: hex dump straight into the page being drawn.
; DBGROW: X = source, B = byte count (<=16), A = character row (0..23)

DBGCH   ; A = nibble, U = screen pointer; draws an 8x8 glyph, U += 1
        PSHS X
        LDX #HEXFONT
        ASLA
        ASLA
        ASLA
        LEAX A,X
        LDB #8
dc_l    LDA ,X+
        STA ,U
        LEAU 32,U
        DECB
        BNE dc_l
        LEAU -255,U
        PULS X
        RTS

DBGROW  PSHS U,Y
        PSHS A,B
        LDA ,S                  ; row
        LDB #32
        MUL                     ; row*32
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA                    ; row*256 (8 pixel rows of 32 bytes)
        ADDD <back
        TFR D,U
        PULS A,B
        TFR B,A
dr_l    PSHS A
        LDA ,X
        LSRA
        LSRA
        LSRA
        LSRA
        JSR DBGCH
        LDA ,X+
        ANDA #$0F
        JSR DBGCH
        PULS A
        DECA
        BNE dr_l
        PULS U,Y
        RTS
