; Run-time text: 8x8 character cells into the page being drawn (<back).
; Glyphs come from FONT (ASCII 32..126, 8 bytes each).

; Draw the NUL-terminated string at X centred on character row B (0..23).
PRCENT  PSHS Y,U
        STB <cnt                ; row
        TFR X,Y
        CLRA
pc_len  TST ,Y+                 ; length
        BEQ pc_ld
        INCA
        BRA pc_len
pc_ld   NEGA
        ADDA #32
        LSRA                    ; column = (32 - length) / 2
        BRA pc_go

; the same at column A
PRAT    PSHS Y,U
        STB <cnt
pc_go   STA <tmp
        LDY dbp                 ; (O11: its band)
        LDA <cnt
        LDB #$FF
        STB A,Y
        LDA <cnt
        CLRB
        ADDD <back              ; page + row*256
        ADDB <tmp
        ADCA #0
        TFR D,U
pc_ch   LDA ,X+
        BEQ pc_done
        SUBA #32
        CMPA #95
        BHS pc_nx               ; not printable
        LDB #8
        MUL
        ADDD #FONT
        PSHS X
        TFR D,X
        LDA ,X+
        STA ,U
        LDA ,X+
        STA 32,U
        LDA ,X+
        STA 64,U
        LDA ,X+
        STA 96,U
        LDA ,X+
        STA 128,U
        LDA ,X+
        STA 160,U
        LDA ,X+
        STA 192,U
        LDA ,X
        STA 224,U
        PULS X
pc_nx   LEAU 1,U
        BRA pc_ch
pc_done PULS Y,U
        RTS
