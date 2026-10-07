; The docked state. (A placeholder until the docked screens: a message and the launch key.)

; clear the whole page being drawn
CLRBACK LDX <back
        LDY #192*16
        LDD #0
cb_l    STD ,X++
        LEAY -1,Y
        BNE cb_l
        RTS

DOCKEDDRAW
        JSR CLRBACK
        LDX #TXTDOCK
        LDB #8
        JSR PRCENT
        LDX #TXTLAUNCH
        LDB #12
        JSR PRCENT
        RTS

TXTDOCK FCC "DOCKED"
        FCB 0
TXTLAUNCH
        FCC "PRESS L TO LAUNCH"
        FCB 0

; docked: wait for L (launch)
DOCKEDMODE
        JSR DOCKEDDRAW
        JSR FLIP
        JSR DOCKEDDRAW
        JSR FLIP
dm_l    JSR WAITVS
        LDA <kmat+4
        BITA #R1                ; L
        BEQ dm_l
        RTS
