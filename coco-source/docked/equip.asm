; The equipment shop (EQSHP): fuel, missiles, a large cargo bay, an E.C.M., lasers, fuel
; scoops, an escape pod, an energy bomb and unit, a docking computer, a galactic hyperdrive.
; The higher the technology of the system the more it sells. Prices are in tenths of a credit.

; the equipment prices (PRXS): 0 fuel (set by what we need), 1 missile, 2 large cargo bay,
; 3 E.C.M., 4 pulse laser, 5 beam laser, 6 fuel scoops, 7 escape pod, 8 energy bomb,
; 9 energy unit, 10 docking computer, 11 galactic hyperdrive, 12 military laser, 13 mining laser
PRXS    FDB 1,300,4000,6000,4000,10000,5250,10000,9000,15000,10000,50000,60000,8000

; X = the price of equipment A (prx)
PRX     ASLA
        LDX #PRXS
        TFR A,B
        ABX
        LDX ,X
        RTS

; pay for equipment A (eq): carry set if we could; otherwise CASH? and back to the status screen
EQ      PSHS A
        JSR PRX
        JSR LCASH
        LBCS eq_ok
        PULS A
        LDA #197
        JSR prq
        JMP ERR
eq_ok   PULS A
        RTS

; the docking bay: the status screen (BAY)
BAY     LDA #'8'
        STA pendkey
        LDS dmsp
        JMP dm_aft

; an error: a pause, then the docking bay
ERR     JSR dn2
        JMP BAY

; the equipment already fitted: the money back, "<item> PRESENT" (pres)
PRES    STY gnq                 ; the item's token
        LDA gnt                 ; its price index
        JSR PRX
        TFR X,D
        JSR MCASH
        LDA gnq
        JSR spc
        LDA #31
        JSR TT27
        JMP ERR

; which view for a laser: the four views to choose from, X = 0-3 (qv)
QV      LDA tek
        CMPA #8
        LBLO qv_a
        LDA #32
        JSR TT66
qv_a    LDA #16
        STA yc
qv_1    LDA #12
        STA xc
        LDA yc
        ADDA #'0'-16
        JSR spc
        LDA yc
        ADDA #80
        JSR TT27
        INC yc
        LDA yc
        CMPA #20
        LBLO qv_1
        JSR CLYNS
qv_2    LDA #175
        JSR prq
        JSR TT217
        SUBA #'0'
        CMPA #4
        LBLO qv_3
        JSR CLYNS
        LBRA qv_2
qv_3    TFR A,B
        CLRA
        TFR D,X
        RTS

; a new laser of power A in view X, paying back the old one (refund)
REFUND  STA tsc
        TFR X,D                 ; the view
        STB eqy
        LDX #laser
        ABX
        LDA ,X
        LBEQ rf_3
        LDB #4                  ; what the old one was worth
        CMPA #15
        LBEQ rf_1
        LDB #5
        CMPA #128+15
        LBEQ rf_1
        LDB #12
        CMPA #151
        LBEQ rf_1
        LDB #13
rf_1    TFR B,A
        JSR PRX
        TFR X,D
        JSR MCASH
rf_3    LDB eqy
        LDX #laser
        ABX
        LDA tsc
        STA ,X
        RTS

; ---- the screen -------------------------------------------------------------------------------------

EQSHP   LDA #32
        JSR TT66
        JSR FLKB
        LDA #12
        STA xc
        LDA #207
        JSR spc
        LDA #185
        JSR NLIN3
        LDA #$80
        STA qq17
        INC yc
        LDA tek                 ; the items up to technology level + 3 (14 at most)
        ADDA #3
        CMPA #12
        LBLO eqs_a
        LDA #14
eqs_a   STA eqq
        STA qq25
        INC eqq
        LDA #70                 ; fuel: what we need costs twice the missing tenths
        SUBA qq14
        ASLA
        CLRB
        TFR D,X
        STX PRXS
        LDA #1
        STA eqx
eqs_l   JSR TT67
        LDB eqx
        CLRA
        TFR D,X
        ANDCC #$FE
        JSR pr2
        JSR TT162
        LDA eqx
        ADDA #104
        JSR TT27
        LDA eqx
        DECA
        JSR PRX
        ORCC #1
        LDA #25
        STA xc
        LDA #6
        JSR TT11
        INC eqx
        LDA eqx
        CMPA eqq
        LBLO eqs_l
        JSR CLYNS
        LDA #127
        JSR prq
        JSR GNUM
        LBEQ BAY
        LBCS BAY
        DECA                    ; the item, 0 up
        LDX #2
        STX xc
        INC yc
        PSHS A
        STA gnt                 ; (its price index)
        JSR EQ
        PULS A
        TSTA
        LBNE et0
        LDB #70                 ; fuel
        STB qq14
et0     CMPA #1
        LBNE et1
        LDB nomsl               ; a missile
        INCB
        LDY #124
        CMPB #5
        LBHS PRES
        STB nomsl
et1     LDY #107
        CMPA #2
        LBNE et2
        LDB #37                 ; the large cargo bay
        CMPB crgo
        LBEQ PRES
        STB crgo
et2     CMPA #3
        LBNE et3
        LEAY 1,Y                     ; an E.C.M.
        TST ecm
        LBNE PRES
        DEC ecm
et3     CMPA #4
        LBNE et4
        JSR QV                  ; a pulse laser
        LDA #15
        JSR REFUND
        LDA #4
et4     CMPA #5
        LBNE et5
        JSR QV                  ; a beam laser
        LDA #128+15
        JSR REFUND
et5     LDY #111
        CMPA #6
        LBNE et6
        TST bst                 ; fuel scoops
        LBEQ ed9
        JMP PRES
ed9     DEC bst
et6     LEAY 1,Y
        CMPA #7
        LBNE et7
        TST escp                ; an escape pod
        LBNE PRES
        DEC escp
et7     LEAY 1,Y
        CMPA #8
        LBNE et8
        TST bomb                ; an energy bomb
        LBNE PRES
        LDB #$7F
        STB bomb
et8     LEAY 1,Y
        CMPA #9
        LBNE etA
        TST engy                ; an energy unit
        LBNE PRES
        INC engy
etA     LEAY 1,Y
        CMPA #10
        LBNE etB
        TST dkcmp               ; a docking computer
        LBNE PRES
        DEC dkcmp
etB     LEAY 1,Y
        CMPA #11
        LBNE et9
        TST ghyp                ; a galactic hyperdrive
        LBNE PRES
        DEC ghyp
et9     LEAY 1,Y
        CMPA #12
        LBNE et10
        JSR QV                  ; a military laser
        LDA #151
        JSR REFUND
et10    LEAY 1,Y
        CMPA #13
        LBNE et11
        JSR QV                  ; a mining laser
        LDA #50
        JSR REFUND
et11    JSR dn
        JMP EQSHP
