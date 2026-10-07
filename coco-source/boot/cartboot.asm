; Cartridge boot: the first sector of the ROM image, started by BASIC at $C000.
;
; The ROM is seen at $C000-$FEFF in ROM mode, one 16K page at a time (write the page
; number to $FF40; the top 256 bytes of a page are hidden behind the I/O area, so a page
; holds 63 sectors). The resident program has to be copied to RAM, and the code doing the
; copying must itself be in RAM, as it switches the page under its own feet. So: copy the
; copier to RAM and run it; it copies the entries of BOOTLIST (destination, sectors,
; first sector of the image, as in SEGTAB) and starts the program at its cartridge entry.
        ORG $C000
CPYRAM  EQU $0700
V_PG    EQU $06E0
V_SEC   EQU $06E1
V_CNT   EQU $06E2
V_DST   EQU $06E3

CBOOT   ORCC #$50
        LDS #$0500
        LEAX CPYSRC,PCR
        LDU #CPYRAM
        LDB #CPYLEN
cb_c    LDA ,X+
        STA ,U+
        DECB
        BNE cb_c
        JMP CPYRAM

; ---- runs from RAM (position independent) ----
CPYSRC  LEAU BOOTLIST,PCR
cp_it   LDX ,U++                ; destination, 0 = end of the list
        BEQ cp_go
        STX V_DST
        LDA ,U+
        STA V_CNT               ; sectors
        LDD ,U++                ; first sector -> page, sector in page (63 to a page)
        LDX #0
cp_dv   CMPD #63
        BLO cp_dd
        SUBD #63
        LEAX 1,X
        BRA cp_dv
cp_dd   STB V_SEC
        TFR X,D
        STB V_PG
cp_s    LDA V_PG
        STA $FF40
        LDA V_SEC
        ADDA #$C0
        CLRB
        TFR D,X                 ; $C000 + 256 * sector
        LDY V_DST
        CLRB
cp_b    LDA ,X+
        STA ,Y+
        DECB
        BNE cp_b
        STY V_DST
        INC V_SEC
        LDA V_SEC
        CMPA #63
        BLO cp_n
        CLR V_SEC
        INC V_PG
cp_n    DEC V_CNT
        BNE cp_s
        BRA cp_it
cp_go   JMP $2803               ; the program's cartridge entry (STARTC)
        INCLUDE "gen/bootlist.inc"
CPYEND
CPYLEN  EQU CPYEND-CPYSRC
