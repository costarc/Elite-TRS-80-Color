; Immutable sound-effect parameters, retained in GEOM across overlay swaps.
SNDTAB  FCB 0                   ; 0  our laser: a chirp down
        FDB 20,4,30
        FCB 0
        FCB 1                   ; 8  we are hit: a short burst
        FDB 0,5,420
        FCB 0
        FCB 1                   ; 16 a hit or a kill
        FDB 0,14,520
        FCB 0
        FCB 1                   ; 24 a long one: our death
        FDB 0,30,800
        FCB 0
        FCB 0                   ; 32 a short high beep
        FDB 22,0,20
        FCB 0
        FCB 0                   ; 40 a long low beep
        FDB 170,0,26
        FCB 0
        FCB 1                   ; 48 a missile or a ship launched: a dull burst
        FDB 0,40,260
        FCB 0
        FCB 0                   ; 56 hyperspace: a rising chirp
        FDB 200,-2,80
        FCB 0
        FCB 0                   ; 64 the E.C.M. on: a buzz
        FDB 70,0,60
        FCB 0
        FCB 0                   ; 72 off: nothing
        FDB 1,0,0
        FCB 0

