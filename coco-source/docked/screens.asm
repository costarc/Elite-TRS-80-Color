; The docked screens: clearing the screen and its box (TT66, TTX66), the lines under titles
; (NLIN), reading keys, and the docked loop with its menu keys.
;
; The docked screens use the whole 256 x 192 screen as 24 rows of 8 x 8 cells (the original
; keeps the dashboard on screen: here the text has the room). They are drawn straight into
; the page on show.

; ---- keys ------------------------------------------------------------------------------------------

; the key matrix (column * 8 + row) as ASCII: the CoCo's keys
KEYTAB  FCB '@','h','p','x','0','8',13,0
        FCB 'a','i','q','y','1','9',12,0
        FCB 'b','j','r','z','2',':',3,0
        FCB 'c','k','s',94,'3',';',0,0
        FCB 'd','l','t',10,'4',',',0,0
        FCB 'e','m','u',8,'5','-',0,0
        FCB 'f','n','v',9,'6','.',0,0
        FCB 'g','o','w',' ','7','/',0,0

; A = the ASCII of a key that is down (the first in matrix order), 0 for none
KEYSCAN LDX #KEYTAB
        LDY #kmat
        LDB #8
ks_c    LDA ,Y+
        LBNE ks_f
        LEAX 8,X
        DECB
        LBNE ks_c
        CLRA
        RTS
ks_f    LDB #8                  ; the lowest row of the column
ks_r    LSRA
        LBCS ks_g
        LEAX 1,X
        DECB
        LBNE ks_r
        CLRA
        RTS
ks_g    LDA ,X
        RTS

; wait for a key to go down (after all have been let go) and return it (TT217 / RDKEY)
WAITKEY JSR WAITVS
        IFDEF KEYSEQ            ; test: keys from a script, one every 20 ticks
        LDX ksq
        BNE wqs_p
        LDX #KEYTXT
wqs_p    LDA ,X
        BEQ wqs_n
        LDA <vcnt
        SUBA ksqt
        CMPA #20
        BLO wqs_w
        LDA <vcnt
        STA ksqt
        LDA ,X+
        STX ksq
        STA lastkey
        RTS
wqs_w    LBRA WAITKEY
wqs_n    STX ksq
        ENDC
        IFDEF DOCKAUTO          ; test: the '0' key after a while (not in the flight screens)
        TST flying
        LBNE wk_n
        LDA <vcnt
        CMPA #200
        LBLO wk_n
        LDA #'0'
        RTS
wk_n    EQU *
        ENDC
        JSR KEYSCAN
        TSTA
        LBNE wk_d
        CLR lastkey
        LBRA WAITKEY
wk_d    CMPA lastkey
        LBEQ WAITKEY
        STA lastkey
        RTS

; ---- the docked loop -------------------------------------------------------------------------------

; draw on the page that is on show, with the whole screen for the text
DOCKSETUP
        LDD <back
        CMPA #$80
        LBNE ds_a
        LDD #$9800
        LBRA ds_b
ds_a    LDD #$8000
ds_b    STD <back
        LDD #96
        STD <cyv
        LDD #191
        STD <ymx
        CLR lastkey
        RTS

; docked: the screens, until we launch. The digits are the original's function keys: 0 launch,
; 1 buy cargo, 2 sell cargo, 3 equip ship, 4 long range chart, 5 short range chart, 6 data on
; system, 7 market prices, 8 status, 9 inventory.
DOCKEDMODE
        CLR flying
        JSR DOCKSETUP
        LDA #1
        STA docked
        CLR pendkey
        CLR dk2d
        TST loadreq             ; the title's Y: a commander to load first
        BEQ dm_nl
        CLR loadreq
        JSR DKLOAD
        BCC dm_nl
        JSR DKMSG
dm_nl
        IFDEF DSKTEST           ; test: load TESTER, or if there is none make him rich and save him
        JSR DKLOAD
        BCC dm_nt
        LDD #7777
        STD cash+2
        JSR DISKSAVE
dm_nt   EQU *
        ENDC
        JSR MISSIONS            ; a mission has something to say, perhaps
        JSR STATUS              ; the first screen, as at the original's BAY
        IFDEF DOCKKEY           ; test: this key first
        LDA #DOCKKEY
        STA pendkey
        ENDC
dm_k    LDA pendkey
        LBEQ dm_w
        CLR pendkey
        LBRA dm_d
dm_w    JSR WAITKEYC
dm_d    TST flying
        LBEQ dm_g
        CMPA #'0'               ; in flight the digits 0-3 take us back to a space view
        LBLO dm_t
        CMPA #'3'
        LBHI dm_t
        SUBA #'0'
        RTS
dm_t    CMPA #'h'               ; and H starts the hyperspace countdown, back in the space view
        LBNE dm_tt
        JSR HYP
        CLRA
        RTS
dm_tt   LBRA dm_u
dm_g    CMPA #'0'
        LBEQ dm_x               ; launch
dm_u    EQU *
        LDX #DMTAB
dm_s    LDB ,X+
        LBEQ dm_k
        LDY ,X++
        CMPA -3,X
        LBNE dm_s
        STS dmsp                ; (BAY2 comes back here)
        JSR ,Y
dm_aft
        IFDEF DOCKKEY2          ; test: this key after the first has been dealt with
        TST dk2d
        BNE dm_n2
        INC dk2d
        LDA #DOCKKEY2
        STA pendkey
dm_n2   EQU *
        ENDC
        LBRA dm_k
dm_x    RTS

; a screen of the flight: A = the key of the first (4-9), back with the space view to show in A
FSCREEN STA pendkey
        LDA #1
        STA flying
        JSR DOCKSETUP
        LBRA dm_k

; the keys of the docked screens: key, then the routine
DMTAB   FCB '@'
        FDB DISKMENU
        FCB '1'
        FDB TT219
        FCB '2'
        FDB TT208
        FCB '3'
        FDB EQSHP
        FCB '4'
        FDB TT22
        FCB '5'
        FDB TT23
        FCB 'o'
        FDB CHOME
        FCB 'd'
        FDB CHDIST
        FCB 'f'
        FDB CHFIND
        FCB '6'
        FDB DATA6
        FCB '7'
        FDB TT167
        FCB '8'
        FDB STATUS
        FCB '9'
        FDB TT213
        FCB 0

; the data on the system at the crosshairs: chosen first (the original's f6 key: TT111, TT25),
; as a chart leaves the seeds of the last system it looked at
DATA6   JSR TT111
        JMP TT25

; the chart keys: O puts the crosshairs on us, D names the system nearest to them
CHOME   LDA qq11
        ANDA #$C0
        BEQ ch_r
        JSR TT103
        JSR ping
        JSR TT103
ch_r    RTS
CHFIND  LDA qq11
        ANDA #$C0
        BEQ ch_r
        JMP HME2
CHDIST  LDA qq11
        ANDA #$C0
        BEQ ch_r
        JMP T95

; wait for a key; on a chart the arrow keys move the crosshairs meanwhile (the original's TT17 and
; TT16; SHIFT makes the steps 4 times as long)
WAITKEYC
        LDA qq11
        ANDA #$C0
        LBEQ wkc_n
wkc_l   JSR WAITVS
        CLR tsc
        LDA <kmat+6             ; RIGHT
        BITA #R3
        BEQ wkc_a
        INC tsc
wkc_a   LDA <kmat+5             ; LEFT
        BITA #R3
        BEQ wkc_b
        DEC tsc
wkc_b   CLR tsc2
        LDA <kmat+4             ; DOWN
        BITA #R3
        BEQ wkc_c
        INC tsc2
wkc_c   LDA <kmat+3             ; UP
        BITA #R3
        BEQ wkc_d
        DEC tsc2
wkc_d   LDA tsc
        ORA tsc2
        BEQ wkc_k
        LDA <kmat+7             ; SHIFT: row 6 of column 7
        BITA #$40
        BEQ wkc_s
        ASL tsc
        ASL tsc
        ASL tsc2
        ASL tsc2
wkc_s   LDA tsc
        LDB tsc2
        JSR TT16
wkc_k
        IFDEF KEYSEQ            ; test: the script's next key on a chart too, every 20 ticks
        LDX ksq
        BNE wkq_p
        LDX #KEYTXT
wkq_p   LDA ,X
        BEQ wkq_n
        LDA <vcnt
        SUBA ksqt
        CMPA #20
        LBLO wkq_n
        LDA <vcnt
        STA ksqt
        LDA ,X+
        STX ksq
        STA lastkey
        RTS
wkq_n   EQU *
        ENDC
        JSR KEYSCAN
        CMPA #94                ; the arrows are not keys here
        BEQ wkc_z
        CMPA #10
        BEQ wkc_z
        CMPA #8
        BEQ wkc_z
        CMPA #9
        BEQ wkc_z
        TSTA
        BNE wkc_y
wkc_z   CLR lastkey
        LBRA wkc_l
wkc_y   CMPA lastkey
        LBEQ wkc_l
        STA lastkey
        RTS
wkc_n   JMP WAITKEY

; the Status Mode screen (STATUS)
STATUS  LDA #8
        JSR TT66
        JSR TT111
        LDA #7
        STA xc
        LDA #126
        JSR NLIN3
        LDA #205
        JSR DETOK
        JSR TT67
        LDA #125                ; LEGAL STATUS: clean, an offender or a fugitive
        JSR spc
        LDA #19
        LDB fist
        LBEQ sts_5
        INCA
        CMPB #50
        LBLO sts_5
        INCA
sts_5    JSR plf
        LDA #16                 ; RATING: from the kill tally
        JSR spc
        LDA kills
        LBNE sts_4
        LDB #0
        LDA kills+1
        LSRA
        LSRA
sts_5l   INCB
        LSRA
        LBNE sts_5l
sts_3    TFR B,A
        ADDA #21
        JSR plf
        LDA #18                 ; EQUIPMENT:
        JSR plf2
        LDA crgo
        CMPA #26
        LBLO sts_a
        LDA #107
        JSR plf2
sts_a    LDA bst
        LBEQ sts_b
        LDA #111
        JSR plf2
sts_b    LDA ecm
        LBEQ sts_c
        LDA #108
        JSR plf2
sts_c    LDA #113
        STA tsc2
sts_qv   LDB tsc2
        LDX #bomb-113
        ABX
        LDB ,X
        LBEQ sts_d
        LDA tsc2
        JSR plf2
sts_d    INC tsc2
        LDA tsc2
        CMPA #117
        LBLO sts_qv
        CLR tsc2                ; the lasers: FRONT PULSE LASER, ...
sts_l    LDB tsc2
        LDX #laser
        ABX
        LDB ,X
        LBEQ sts_1
        LDA tsc2
        ADDA #96
        JSR spc
        LDA #103
        LDX #laser
        LDB tsc2
        ABX
        LDB ,X
        CMPB #128+15
        LBNE sts_e
        LDA #104
sts_e    CMPB #151
        LBNE sts_f
        LDA #117
sts_f    CMPB #50
        LBNE sts_g
        LDA #118
sts_g    JSR plf2
sts_1    INC tsc2
        LDA tsc2
        CMPA #4
        LBLO sts_l
        RTS
sts_4    LDB #9                  ; 256 kills or more: Elite (25 x 256), Deadly (10), Dangerous (2), Competent
        CMPA #25
        LBHS sts_3
        DECB
        CMPA #10
        LBHS sts_3
        DECB
        CMPA #2
        LBHS sts_3
        DECB
        LBRA sts_3

; token A, a space
spc     JSR TT27
TT162   LDA #' '
        JMP TT27

; token A, a newline and an indent of 6
plf2    JSR plf
        LDA #6
        STA xc
        RTS

