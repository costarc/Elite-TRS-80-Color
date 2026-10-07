; The original's random number generator (DORND): two coupled Fibonacci-style
; sequences held in <rand..rand+3.
;   feeder:  f2 = (f1 << 1) + C      f3 = f0 + f2 + carry from the shift
;   main:    m2 = m0 + m1 + carry from the feeder
; Returns A = m2 and B = m1 (the original's A and X). The carry on entry takes
; part, as in the original.
DORND   LDA <rand
        ROLA
        TFR A,B
        ADCA <rand+2
        STA <rand
        STB <rand+2
        LDA <rand+1
        TFR A,B
        ADCA <rand+3
        STA <rand+1
        STB <rand+3
        RTS
