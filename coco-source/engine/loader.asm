; The loader: overlay segments from the medium into RAM above $8000.
;
; The program is bigger than Disk BASIC's LOADM can load (it fails at $8000), and the
; RAM above $8000 is only visible in the SAM's all-RAM mode, in which the BASIC ROMs
; and a cartridge are not. So a segment comes in sector by sector: a medium driver reads
; one 256-byte sector into STAGE (low RAM, in ROM mode), then the all-RAM mode is
; switched back on and the sector is copied to its destination. Two media:
;
;   disk       Disk BASIC's DSKCON ($C004 vector) reads logical sector n of ELITE.DAT,
;              the file written first on the disk (tools/diskinfo.py gives its granules,
;              DISKGRAN).
;              DSKCON wants the direct page at 0 and the interrupts off. The blob sector
;              number is mapped through the file's granule chain.
;   cartridge  a Super Program Pak style ROM: 16K pages selected by writing the page
;              number to $FF40, seen at $C000-$FEFF in ROM mode (63 sectors a page) (tools/mkcart.py builds
;              the image, boot/cartboot.asm starts it).
;
; The medium is told by <medium: the disk entry START clears it, the cartridge entry
; STARTC sets it.


DCOPC   EQU $EA                 ; DSKCON's parameters in Disk BASIC's direct page
DCDRV   EQU $EB
DCTRK   EQU $EC
DCSEC   EQU $ED
DCBPT   EQU $EE
DCSTA   EQU $F0
DSKVEC  EQU $C004               ; [DSKVEC] = DSKCON

; A = segment number (SEG_xxx): load it. All-RAM mode, DP $02 on entry and exit.
; Carry set if the medium could not be read.
LOADSEG LDB #5
        MUL
        ADDD #SEGTAB
        TFR D,X
        LDU ,X                  ; where it goes
        LDB 2,X
        STB <cnt                ; sectors
        LDY 3,X                 ; first sector in the blob
ls_l    TFR Y,D
        PSHS U,Y
        JSR SEGSEC
        PULS U,Y
        BCS ls_x
        LDX #STAGE              ; the sector, to its place
        LDB #128
ls_c    LDA ,X+
        STA ,U+
        LDA ,X+
        STA ,U+
        DECB
        BNE ls_c
        LEAY 1,Y
        DEC <cnt
        BNE ls_l
        ANDCC #$FE
ls_x    TST <medium             ; the disk motor is not Disk BASIC's to stop now (our IRQ has
        BNE ls_r                ; replaced its timer): stop it
        PSHS CC
        CLR $FF40
        PULS CC
ls_r    RTS

; D = sector of the blob: read it into STAGE. All-RAM mode on exit; carry set on error.
SEGSEC  PSHS CC
        STA $FFDE               ; ROM mode: the BASIC ROMs / the cartridge are visible
        TST medium
        BNE sc_cart
        LDX #0                  ; the blob sector -> granule index (9 sectors a granule) and
sc_dv   CMPD #9                 ; sector within it
        BLO sc_dd
        SUBD #9
        LEAX 1,X
        BRA sc_dv
sc_dd   PSHS B                  ; k
        TFR X,D
        LDY #DISKGRAN           ; the file's granules, in order
        LDA B,Y
        PSHS A                  ; g
        LSRA                    ; track = g / 2, and the directory track 17 is not a data track
        CMPA #17
        BLO sc_t
        INCA
sc_t    TFR A,B
        PULS A
        ANDA #1                 ; odd granule: second half of the track
        BEQ sc_s
        LDA #9
sc_s    ADDA ,S+
        INCA                    ; sector 1..18; A = sector, B = track
        ORCC #$50
        PSHS A,B
        CLRA                    ; DSKCON works in direct page 0
        TFR A,DP
        SETDP 0
        PULS A,B
        STB <DCTRK
        STA <DCSEC
        LDA #2                  ; read sector
        STA <DCOPC
        CLR <DCDRV
        LDX #STAGE
        STX <DCBPT
        JSR [DSKVEC]
        LDA <DCSTA
        PSHS A
        LDA #2
        TFR A,DP
        SETDP $02
        PULS A
        STA $FFDF
        TSTA
        BNE sc_err
        PULS CC
        ANDCC #$FE
        RTS
sc_err  PULS CC
        ORCC #1
        RTS

sc_cart ADDD #CARTSEC           ; sector -> page and sector in it (63 to a page: the top 256
        LDX #0                  ; bytes of a 16K page are behind the I/O area)
sc_cv   CMPD #63
        BLO sc_cd
        SUBD #63
        LEAX 1,X
        BRA sc_cv
sc_cd   PSHS B
        TFR X,D
        STB $FF40               ; the page
        PULS A
        ADDA #$C0
        CLRB
        TFR D,X                 ; $C000 + 256 * sector
        LDY #STAGE
        CLRB                    ; 256 bytes
sc_cp   LDA ,X+
        STA ,Y+
        DECB
        BNE sc_cp
        STA $FFDF
        PULS CC
        ANDCC #$FE
        RTS

; ---- the commander file (ELITE.SAV: 18 sectors, one saved commander each) ----------------------------

; A = sector 0-17 of ELITE.SAV, B = 2 to read it into STAGE or 3 to write it from STAGE: carry set
; when it failed (and always on the cartridge, which has no disk)
DISKRW  TST medium
        BNE dr_no
        PSHS CC,B
        LDB #0                  ; granule index and the sector in it (9 sectors a granule)
dr_dv   CMPA #9
        BLO dr_dd
        SUBA #9
        INCB
        BRA dr_dv
dr_dd   PSHS A                  ; k
        LDX #SAVEGRAN
        LDA B,X                 ; g
        PSHS A
        LSRA                    ; track = g / 2, and the directory track 17 is not a data track
        CMPA #17
        BLO dr_t
        INCA
dr_t    TFR A,B
        PULS A
        ANDA #1                 ; odd granule: second half of the track
        BEQ dr_s
        LDA #9
dr_s    ADDA ,S+
        INCA                    ; sector 1..18; A = sector, B = track
        ORCC #$50
        PSHS A,B
        CLRA                    ; DSKCON works in direct page 0
        TFR A,DP
        SETDP 0
        PULS A,B
        STB <DCTRK
        STA <DCSEC
        LDA 1,S                 ; the operation
        STA <DCOPC
        STA $FFDE               ; ROM mode: Disk BASIC is visible
        CLR <DCDRV
        LDX #STAGE
        STX <DCBPT
        JSR [DSKVEC]
        LDA <DCSTA
        PSHS A
        LDA #2
        TFR A,DP
        SETDP $02
        PULS A
        STA $FFDF
        TSTA
        BNE dr_err
        PULS CC
        LEAS 1,S                ; (the operation)
        CLR $FF40               ; the drive motor off
        ANDCC #$FE
        RTS
dr_err  PULS CC
        LEAS 1,S
        CLR $FF40
dr_no   ORCC #1
        RTS
