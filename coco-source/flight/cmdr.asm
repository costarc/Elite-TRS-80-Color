; The saved commander: what is packed into a sector, and the search through the 18 sectors of
; ELITE.SAV (the disk only; the cartridge has no room for them). A record is "ELT1", the data
; of CMDTAB in order, and a 16-bit checksum; the name comes first, so a sector's name is at
; STAGE+4, ended by a 13.

CMDTAB  FDB na
        FCB 9
        FDB cash
        FCB 4
        FDB qq14
        FCB 1
        FDB gcnt
        FCB 1
        FDB laser
        FCB 4
        FDB crgo
        FCB 1
        FDB qq20
        FCB 17
        FDB ecm
        FCB 1
        FDB bst
        FCB 1
        FDB bomb
        FCB 1
        FDB engy
        FCB 1
        FDB dkcmp
        FCB 1
        FDB ghyp
        FCB 1
        FDB escp
        FCB 1
        FDB nomsl
        FCB 1
        FDB fist
        FCB 1
        FDB kills
        FCB 2
        FDB tp
        FCB 1
        FDB qq0
        FCB 1
        FDB qq1
        FCB 1
        FDB qq21
        FCB 6
        FDB 0

; the commander into STAGE
CMDPACK LDX #STAGE
        LDB #0
cm_z    CLR ,X+
        DECB
        BNE cm_z
        LDX #STAGE
        LDD #'E'*256+'L'
        STD ,X
        LDD #'T'*256+'1'
        STD 2,X
        LDU #STAGE+4
        LDY #CMDTAB
cm_l    LDX ,Y++
        BEQ cm_e
        LDB ,Y+
cm_c    LDA ,X+
        STA ,U+
        DECB
        BNE cm_c
        BRA cm_l
cm_e    BSR cm_sum
        STD ,U
        RTS

; D = the checksum of the data from STAGE+4 to U
cm_sum  PSHS U
        LDX #STAGE+4
        LDD #$5A5A
cm_s    CMPX ,S
        BEQ cm_k
        ADDB ,X+
        BCC cm_s
        INCA
        BRA cm_s
cm_k    PULS U
        RTS

; STAGE into the commander if it is one that was saved: carry set when it is not
CMDUNPACK
        LDX #STAGE
        LDD ,X
        CMPD #'E'*256+'L'
        BNE cu_bad
        LDD 2,X
        CMPD #'T'*256+'1'
        BNE cu_bad
        LDU #STAGE+4            ; where the data end
        LDY #CMDTAB
cu_p    LDX ,Y++
        BEQ cu_q
        LDB ,Y+
        LEAU B,U
        BRA cu_p
cu_q    BSR cm_sum
        CMPD ,U
        BNE cu_bad
        LDU #STAGE+4
        LDY #CMDTAB
cu_l    LDX ,Y++
        BEQ cu_e
        LDB ,Y+
cu_c    LDA ,U+
        STA ,X+
        DECB
        BNE cu_c
        BRA cu_l
cu_e    ANDCC #$FE
        RTS
cu_bad  ORCC #1
        RTS

; the sector of the commander named in cname (9 bytes, ended by a 13): csec = its number or $FF,
; cfree = the first empty sector or $FF. Carry set on a disk error.
CMDFIND LDA #$FF
        STA csec
        STA cfree
        CLR cidx
cf_l    LDA cidx
        LDB #2
        JSR DISKRW
        BCS cf_x
        LDD STAGE
        CMPD #'E'*256+'L'
        BNE cf_f
        LDD STAGE+2
        CMPD #'T'*256+'1'
        BNE cf_f
        LDX #cname              ; the names
        LDU #STAGE+4
        LDB #9
cf_n    LDA ,X+
        CMPA ,U+
        BNE cf_o
        CMPA #13
        BEQ cf_h
        DECB
        BNE cf_n
cf_h    LDA cidx
        STA csec
        BRA cf_d
cf_f    LDA cfree               ; an empty sector (the first one is remembered)
        INCA
        BNE cf_o
        LDA cidx
        STA cfree
cf_o    INC cidx
        LDA cidx
        CMPA #18
        BLO cf_l
cf_d    ANDCC #$FE
cf_x    RTS

; the commander and the system around him after a load (the market, the seeds of the system)
CMDAFTER
        LDA qq0
        STA qq9
        LDA qq1
        STA qq10
        JSR TT111
        JSR HYP1
        JSR GVL
        LDA #255
        STA fsh
        STA ash
        STA energy
        RTS
