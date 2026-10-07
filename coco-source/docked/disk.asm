; The disk access menu (the original's SVE, on the "@" key in the bay, and the title's Y): load a
; commander, save the commander, the catalogue, delete one. The commanders are in the 18 sectors of
; ELITE.SAV (flight/cmdr.asm); the cartridge has no disk, so there the menu says so.

; a string ended by 0, character by character
PRSTR   LDA ,X+
        BEQ dkp_x
        PSHS X
        JSR CHPR
        PULS X
        BRA PRSTR
dkp_x    RTS

STNODSK FCC "NO DISK"
        FCB 0
STERR   FCC "DISK ERROR"
        FCB 0
STNOFND FCC "NOT FOUND"
        FCB 0
STFULL  FCC "DISK FULL"
        FCB 0
STSAVED FCC "SAVED"
        FCB 0
STDELD  FCC "DELETED"
        FCB 0
STBAD   FCC "NOT A COMMANDER"
        FCB 0
STCAT   FCC "COMMANDERS"
        FCB 0

; the line under the menu: the message in X, a moment to read it
DKMSG   PSHS X
        JSR CLYNS
        PULS X
        JSR PRSTR
        LDY #75
        JMP DELAY

; the menu (token 1)
DISKMENU
        TST medium
        BEQ dk_ok
        JSR DISKTOP
        LDX #STNODSK
        JMP DKMSG
dk_ok   LDA #1
        JSR DETOK
        JSR WAITKEY
        CMPA #'1'
        BEQ DISKLOAD
        CMPA #'2'
        BEQ DISKSAVE
        CMPA #'3'
        LBEQ DISKCAT
        CMPA #'4'
        LBEQ DISKDEL
        RTS

DISKTOP LDA #1                  ; an empty screen with the box
        JMP TT66

; load: ask for the name, find it, take it. Carry set and X = a message when it did not work.
DKLOAD  JSR GTNME
        JSR CMDFIND
        BCS dk_err
        LDA csec
        INCA
        BEQ dk_nf
        DECA
        LDB #2
        JSR DISKRW
        BCS dk_err
        JSR CMDUNPACK
        BCS dk_bad
        JSR CMDAFTER
        ANDCC #$FE
        RTS
dk_nf   LDX #STNOFND
        ORCC #1
        RTS
dk_bad  LDX #STBAD
        ORCC #1
        RTS
dk_err  LDX #STERR
        ORCC #1
        RTS

; the menu's load: the status screen of the new commander
DISKLOAD
        JSR DKLOAD
        BCS dk_say
        LDA #'8'
        STA pendkey
        LDS dmsp
        JMP dm_aft
dk_say  JMP DKMSG

; save: ask for the name (none: the commander's own), find its sector or an empty one, write
DISKSAVE
        JSR GTNME
        LDX #cname              ; the commander is called that from now on
        LDU #na
        LDB #9
dk_cn   LDA ,X+
        STA ,U+
        DECB
        BNE dk_cn
        JSR CMDFIND
        BCS dk_e2
        LDA csec
        INCA
        BNE dk_s1
        LDA cfree               ; a new name: the first empty sector
        INCA
        BEQ dk_full
        DECA
        STA csec
dk_s1   JSR CMDPACK
        LDA csec
        LDB #3
        JSR DISKRW
        BCS dk_e2
        LDX #STSAVED
        BRA dk_say
dk_full LDX #STFULL
        BRA dk_say
dk_e2   LDX #STERR
        BRA dk_say

; the catalogue: the names, three to a row
DISKCAT JSR DISKTOP
        LDX #STCAT
        LDA #11
        STA xc
        LDA #1
        STA yc
        JSR PRSTR
        LDA #3
        STA yc
        CLR cidx
dkc_l    LDA cidx
        LDB #2
        JSR DISKRW
        LBCS dk_e2
        LDD STAGE
        CMPD #'E'*256+'L'
        BNE dkc_n
        LDD STAGE+2
        CMPD #'T'*256+'1'
        BNE dkc_n
        LDA #2
        STA xc
        LDX #STAGE+4
dkc_p    LDA ,X+
        CMPA #13
        BEQ dkc_e
        PSHS X
        JSR CHPR
        PULS X
        BRA dkc_p
dkc_e    LDA #12
        JSR CHPR
dkc_n    INC cidx
        LDA cidx
        CMPA #18
        BLO dkc_l
        JSR WAITKEY
        RTS

; delete: ask for the name, empty its sector
DISKDEL JSR GTNME
        JSR CMDFIND
        LBCS dk_e2
        LDA csec
        INCA
        LBEQ dk_nf2
        LDX #STAGE
        LDB #0
dkd_z    CLR ,X+
        DECB
        BNE dkd_z
        LDA csec
        LDB #3
        JSR DISKRW
        LBCS dk_e2
        LDX #STDELD
        JMP dk_say
dk_nf2  LDX #STNOFND
        JMP dk_say

; a line of text from the keyboard (the jump token MT26): up to rmax (0: 9) characters in
; capitals, DELETE (the left arrow) takes one back, ENTER ends it. The text is at inwk+5, ended
; by a 13, and B is its length.
MT26
        IFDEF FINDTEST          ; test: the name DISO
        LDX #STDISO
        LDU #inwk+5
        LDB #5
mt_t    LDA ,X+
        STA ,U+
        DECB
        BNE mt_t
        LDB #4
        RTS
STDISO  FCC "DISO"
        FCB 13
        ENDC
        LDX #inwk+5
        LDB #0
        CLR dtw4
mt_k    PSHS B,X
        JSR WAITKEY
        PULS B,X
        CMPA #13
        BEQ mt_e
        CMPA #8                 ; the left arrow: delete
        BNE mt_c
        TSTB
        BEQ mt_k
        DECB
        LEAX -1,X
        PSHS B,X
        LDA #127
        JSR CHPR
        PULS B,X
        BRA mt_k
mt_c    CMPA #'a'               ; capitals
        BLO mt_u
        CMPA #'z'
        BHI mt_u
        ANDA #$DF
mt_u    CMPA #33
        BLO mt_k
        CMPA #'Z'
        BHI mt_k
        PSHS A
        LDA rmax
        BNE mt_m
        LDA #9
mt_m    STA tsc
        PULS A
        CMPB tsc
        BHS mt_k
        STA ,X+
        INCB
        PSHS B,X
        JSR CHPR
        PULS B,X
        BRA mt_k
mt_e    LDA #13
        STA ,X
        LDA #12
        PSHS B
        JSR CHPR
        PULS B
        RTS

; "COMMANDER'S NAME? ", a line of up to 7 characters (the commander's own when none): in cname
GTNME
        IFDEF DSKTEST           ; test: always the commander TESTER
        LDX #STTESTER
        LDU #cname
        LDB #9
tg_l    LDA ,X+
        STA ,U+
        DECB
        BNE tg_l
        RTS
STTESTER FCC "TESTER"
        FCB 13,0,0
        ENDC
        JSR DISKTOP
        LDA #1
        STA xc
        LDA #8
        STA yc
        LDA #7
        STA rmax
        LDA #8
        JSR DETOK
        JSR MT26
        CLR rmax
        PSHS B
        LDX #inwk+5             ; what was typed
        LDU #cname
        LDB #9
gn_m1   LDA ,X+
        STA ,U+
        DECB
        BNE gn_m1
        PULS B
        TSTB
        BNE gn_x
        LDX #na                 ; no name: the commander's own
        LDU #cname
        LDB #9
gn_m    LDA ,X+
        STA ,U+
        DECB
        BNE gn_m
gn_x    RTS
