; Keyboard. The CoCo matrix is scanned by strobing a column low on PIA0 port B
; ($FF02) and reading the rows on port A ($FF00). The IRQ scans the whole matrix
; every vsync into <kmat (one byte per column, bit = row, 1 = down), so held keys
; can be read directly and a short tap is never missed: <keys is the K_* subset
; for the title, <kpress collects its new presses until the main loop takes them.
;
;   row 0:  @ A B C D E F G        row 3:  X Y Z UP DOWN LEFT RIGHT SPACE
;   row 1:  H I J K L M N O        row 4:  0 1 2 3 4 5 6 7
;   row 2:  P Q R S T U V W        row 5:  8 9 : ; , - . /
;   (columns 0-7 left to right)    row 6:  ENTER CLEAR BREAK ALT CTRL F1 F2 SHIFT

K_SPACE EQU $01
K_LEFT  EQU $02
K_RIGHT EQU $04
K_ENTER EQU $08
K_T     EQU $10
K_Y     EQU $20
K_N     EQU $40
K_C     EQU $80

; test a key in <kmat: LDA <kmat+column / BITA #1<<row (non-zero = down)

SCANMAT
        LDA #$FE
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+0
        LDA #$FD
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+1
        LDA #$FB
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+2
        LDA #$F7
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+3
        LDA #$EF
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+4
        LDA #$DF
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+5
        LDA #$BF
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+6
        LDA #$7F
        STA $FF02
        LDB $FF00
        COMB
        ANDB #$7F
        STB <kmat+7
        LDA #$FF
        STA $FF02
        RTS

; B = K_* bits for the keys now down
SCANKEYS
        JSR SCANMAT
        CLRB
        LDA <kmat+7
        BITA #R3
        BEQ sk1
        ORB #K_SPACE
sk1     LDA <kmat+5
        BITA #R3
        BEQ sk2
        ORB #K_LEFT
sk2     LDA <kmat+6
        BITA #R3
        BEQ sk3
        ORB #K_RIGHT
sk3     LDA <kmat+0
        BITA #$40               ; ENTER: row 6, column 0
        BEQ sk4
        ORB #K_ENTER
sk4     LDA <kmat+4
        BITA #$04               ; T: row 2, column 4
        BEQ sk5
        ORB #K_T
sk5     LDA <kmat+1
        BITA #R3                ; Y: row 3, column 1
        BEQ sk6
        ORB #K_Y
sk6     LDA <kmat+6
        BITA #R1                ; N: row 1, column 6
        BEQ sk7
        ORB #K_N
sk7     LDA <kmat+3
        BITA #R0                ; C: row 0, column 3
        BEQ sk8
        ORB #K_C
sk8     RTS

; Hidden key sequence S-H-A-D-E (title only: armed by TKEYS, disarmed by NEWGAME)
; toggles the shaded mode. Run from the IRQ after the matrix scan, so a quick tap
; is never missed. Letter codes 1-5 = S H A D E; eggst = the code expected next.
EGGSCAN LDA eggarm
        BEQ eg_x
        CLRB
        LDA <kmat+3
        BITA #R2                ; S
        BEQ eg1
        LDB #1
        BRA eg_k
eg1     LDA <kmat
        BITA #R1                ; H
        BEQ eg2
        LDB #2
        BRA eg_k
eg2     LDA <kmat+1
        BITA #R0                ; A
        BEQ eg3
        LDB #3
        BRA eg_k
eg3     LDA <kmat+4
        BITA #R0                ; D
        BEQ eg4
        LDB #4
        BRA eg_k
eg4     LDA <kmat+5
        BITA #R0                ; E
        BEQ eg_k
        LDB #5
eg_k    TSTB
        BNE eg_d
        CLR eghold              ; no letter down
eg_x    RTS
eg_d    TST eghold              ; still the same press
        BNE eg_x
        INC eghold
        CMPB eggst
        BNE eg_bad
        INC eggst
        LDA eggst
        CMPA #6
        BLO eg_x
        LDA shade               ; complete: toggle
        EORA #1
        STA shade
        BRA eg_r
eg_bad  CMPB #1                 ; a wrong letter restarts, an S counts as the first
        BNE eg_r
        LDA #2
        STA eggst
        RTS
eg_r    LDA #1
        STA eggst
        RTS

; take the new presses (K_* bits) in A
GETKEYS ORCC #$10
        LDA <kpress
        CLR <kpress
        ANDCC #$EF
        RTS
