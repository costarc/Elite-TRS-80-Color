; Data on System (TT25): the selected system's economy, government, technology, population,
; productivity, radius and its description (PDESC, from the random extended tokens, seeded
; by the system's seeds, so a system always has the same description).

; the distance to the selected system (TT146): DISTANCE: 12.3 LIGHT YEARS, or a blank line
TT146   LDA qq8
        ORA qq8+1
        LBNE t146_a
        INC yc
        RTS
t146_a  LDA #191
        JSR TT68
        LDX qq8
        ORCC #1
        JSR pr5
        LDA #195
        JMP plf

TT25    LDA #1
        JSR TT66
        LDA #9
        STA xc
        LDA #163
        JSR NLIN3
        JSR TTX69
        JSR TT146
        LDA #194                ; ECONOMY: Rich / Average / Poor Industrial / Agricultural
        JSR TT68
        LDA qq3
        ADDA #1
        LSRA
        CMPA #2
        LBEQ TT70
        LDA qq3
        LBHS t25_1               ; (the 6502's carry: set when the shifted value was >= 2)
        LBRA t25_2
t25_1   SUBA #5
t25_2   ADDA #170
        JSR TT27
        LBRA TT72
TT70    LDA #173                ; MAINLY
        JSR TT27
TT72    LDA qq3
        LSRA
        LSRA
        ADDA #168
        JSR TT60
        LDA #162                ; GOVERNMENT:
        JSR TT68
        LDA qq4
        ADDA #177
        JSR TT60
        LDA #196                ; TECH.LEVEL:
        JSR TT68
        LDB qq5
        INCB
        CLRA
        TFR D,X
        ANDCC #$FE
        JSR pr2
        JSR TTX69
        LDA #192                ; POPULATION: 2.5 BILLION (Human Colonials)
        JSR TT68
        LDB qq6
        CLRA
        TFR D,X
        ORCC #1
        JSR pr2
        LDA #198
        JSR TT60
        LDA #'('
        JSR TT27
        LDA qq15+4
        LBMI TT75
        LDA #188                ; HUMAN COLONIAL
        JSR TT27
        LBRA TT76
TT75    LDA qq15+5              ; a species of aliens: size, colour, shape, kind
        LSRA
        LSRA
        PSHS A
        ANDA #7
        CMPA #3
        LBHS TT205
        ADDA #227
        JSR spc
TT205   PULS A
        LSRA
        LSRA
        LSRA
        CMPA #6
        LBHS TT206
        ADDA #230
        JSR spc
TT206   LDA qq15+3
        EORA qq15+1
        ANDA #7
        STA tsc
        CMPA #6
        LBHS TT207
        ADDA #236
        JSR spc
TT207   LDA qq15+5
        ANDA #3
        ADDA tsc
        ANDA #7
        ADDA #242
        JSR TT27
TT76    LDA #'S'
        JSR TT27
        LDA #')'
        JSR TT60
        LDA #193                ; PRODUCTIVITY: 1234 M CR
        JSR TT68
        LDX qq7
        ANDCC #$FE
        JSR pr6
        JSR TT162
        CLR qq17
        LDA #'M'
        JSR TT27
        LDA #226
        JSR TT60
        LDA #250                ; AVERAGE RADIUS: 5000 km
        JSR TT68
        LDA qq15+5
        ANDA #15
        ADDA #11
        TFR A,B
        LDA qq15+3              ; (the radius is that high byte and the x seed byte)
        EXG A,B
        TFR D,X
        ANDCC #$FE
        JSR pr5
        JSR TT162
        LDA #'k'
        JSR TT26
        LDA #'m'
        JSR TT26
        JSR TTX69
        LBRA PDESC

; the description of the selected system (PDESC). The one we are in may have a special text:
; RUPLA says which systems, RUGAL which galaxy, and the mission flag decides.
PDESC   LDA qq8
        ORA qq8+1
        LBNE pd_1
        LDB #25
pd_l    LDX #RUPLA-1
        LDA B,X
        CMPA zz
        LBNE pd_2
        LDX #RUGAL-1
        LDA B,X
        ANDA #$7F
        CMPA gcnt
        LBNE pd_2
        LDA B,X
        LBMI pd_3
        LDA tp
        LSRA
        LBCC pd_1
        PSHS B
        JSR MT14
        PULS B
        LDA #1
        LBRA pd_5
pd_3    LDA #176
pd_5    PSHS B
        JSR DETOK2
        PULS A
        JSR DETOK3
        LDA #177
        LBRA pd_4
pd_2    DECB
        LBNE pd_l
pd_1    LDX #qq15+2             ; seed the random numbers from the system's seeds
        LDU #rand
        LDB #4
pd_k    LDA ,X+
        STA ,U+
        DECB
        LBNE pd_k
        LDA #5
pd_4    JMP DETOK
