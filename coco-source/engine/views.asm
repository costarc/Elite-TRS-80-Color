; The four space views: front, rear, left, right.
;
; Stardust (the original STARS6 for the rear view and STARS2 for the left and right
; views) and the axes flip that turns every ship, planet and sun into the view's frame
; (the original PU1/PU2). The front view is engine/stars.asm.
;
; Rear: the dust moves away from us and shrinks towards the centre:
;   z += speed*64   x -= x_hi*q   y -= y_hi*q   (q = 64*speed/z_hi, as in the front)
;   y += alpha*x_hi   x -= alpha*y_hi   x -= 2*(beta*y_hi/256)^2   y += beta*256
; A particle leaving |y_hi| < 110 or reaching z_hi >= 160 is recycled close to us on an
; edge of the screen.
;
; Left and right: the dust crosses the screen sideways (right to left in the left view),
; its z stays; with a = alpha and b = beta (both negated in the right view):
;   x += dx - sign * 256*speed/(z_hi/8)      x += b*y_hi      y -= b*x_hi
;   Q = a*y_hi/256    x -= Q*x_hi    y += Q*y_hi    y += a
; A particle leaving |x_hi| < 116 or |y_hi| < 116 is recycled on the edge it comes from.

; y, x := y, x -+ |hi|*q: the magnitude shrinks (a rear view particle moves away)
GROWM   MACRO
        LDA \1,U
        BPL @p
        NEGA
        LDB <sq
        MUL
        ADDD \1,U
        BRA @s
@p      LDB <sq
        MUL
        STD <tmp
        LDD \1,U
        SUBD <tmp
@s      STD \1,U
        ENDM

; the roll and pitch part of the rear view for the particle at X:
;   y += alpha*x_hi   x -= alpha*y_hi   x -= 2*(beta*y_hi/256)^2   y += beta*256
STARROTR
        LDA <alpha
        LDB ,X
        JSR SMUL8
        LEAU 2,X
        JSR ADDSAT
        LDA <alpha
        LDB 2,X
        JSR SMUL8
        JSR NEGD
        LEAU ,X
        JSR ADDSAT
        LDA <beta
        LDB 2,X
        JSR SMUL8
        TFR A,B
        JSR SMUL8
        ASLB
        ROLA
        JSR NEGD
        LEAU ,X
        JSR ADDSAT
        LDA <beta
        CLRB
        LEAU 2,X
        JMP ADDSAT

; recycle the rear view particle at X: close to us, on an edge of the screen
KILL6   JSR DORND
        ANDA #$7F
        ADDA #10
        STA 4,X                 ; z_hi 10..137
        CLR 5,X
        LSRA
        BCS k6_b
        LSRA                    ; z_hi bit 1 picks the side
        LDA #252
        RORA                    ; +-126 as sign-magnitude
        JSR SMTOS
        STA ,X                  ; on the left or right edge, anywhere along it
        CLR 1,X
        JSR DORND
        JSR SMTOS
        STA 2,X
        CLR 3,X
        RTS
k6_b    JSR DORND               ; anywhere along the top or bottom edge
        PSHS A
        JSR SMTOS
        STA ,X
        CLR 1,X
        PULS A
        LSRA
        LDA #230
        RORA                    ; +-115
        JSR SMTOS
        STA 2,X
        CLR 3,X
        RTS

; one tick of the stardust, rear view
STARS6  LDB <delta
        CLRA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        STD <d64                ; speed * 64
        LDA <alpha
        ORA <beta
        STA sflag
        LDU #stars
        LDA <nostm
        STA <cnt
s6_l    LDB 4,U                 ; q = speed * 64 / z_hi, as in the front view
        LDX #STRHI
        ABX
        LDA <delta
        LDB ,X
        MUL
        STB <sq
        LDA <delta
        LDB 256,X
        MUL
        ADDA <sq
        ORA #1
        STA <sq
        LDD 4,U                 ; z += speed*64
        ADDD <d64
        STD 4,U
        GROWM 2
        GROWM 0
        TST sflag
        BEQ s6_r
        TFR U,X
        PSHS U
        JSR STARROTR
        PULS U
s6_r    LDA 2,U                 ; |y_hi| >= 110 or z_hi >= 160: recycle
        ADDA #109
        CMPA #219
        BHS s6_k
        LDA 4,U
        CMPA #160
        BLO s6_d
s6_k    TFR U,X
        JSR KILL6
s6_d    LDA 4,U
        STA <tlo
        LDA 2,U
        STA <tmp2+1
        TFR A,B
        LDA ,U
        JSR STARPIX
        LEAU 6,U
        DEC <cnt
        LBNE s6_l
        RTS

; one tick of the stardust, left (<view = 2) or right (<view = 3) view
STARS2  CLR <vsg
        LDA <alpha
        STA <ta                 ; a and b, negated for the right view
        LDA <beta
        STA <ta+1
        LDA <view
        CMPA #3
        BNE s2_go
        COM <vsg
        NEG <ta
        NEG <ta+1
s2_go   LDU #stars
        LDA <nostm
        STA <cnt
s2_l    LDA 4,U                 ; dx = 256 * speed / (z_hi / 8)
        STA <tlo
        LSRA
        LSRA
        LSRA
        BNE s2_a
        INCA
s2_a    ASLA
        LDX #DXT
        LEAX A,X
        LDA <delta
        LDB ,X
        MUL
        STD <tq
        LDA <delta
        LDB 1,X
        MUL
        TFR A,B
        CLRA
        ADDD <tq
        TST <vsg
        BNE s2_p
        JSR NEGD                ; left view: right to left
s2_p    JSR ADDSAT              ; x += dx
        LDA <ta+1               ; x += b*y_hi
        LDB 2,U
        JSR SMUL8
        JSR ADDSAT
        LDA <ta+1               ; y -= b*x_hi
        LDB ,U
        JSR SMUL8
        JSR NEGD
        LEAU 2,U
        JSR ADDSAT
        LEAU -2,U
        LDA <ta                 ; Q = a*y_hi/256
        LDB 2,U
        JSR SMUL8
        STA <tq
        LDA <tq                 ; x -= Q*x_hi
        LDB ,U
        JSR SMUL8
        JSR NEGD
        JSR ADDSAT
        LDA <tq                 ; y += Q*y_hi
        LDB 2,U
        JSR SMUL8
        LEAU 2,U
        JSR ADDSAT
        LEAU -2,U
        LDA <ta                 ; y += a
        CLRB
        LEAU 2,U
        JSR ADDSAT
        LEAU -2,U
        LDA ,U                  ; |x_hi| >= 116: recycle on the edge it comes from
        ADDA #115
        CMPA #231
        BHS s2_kx
        LDA 2,U                 ; |y_hi| >= 116: recycle along the top or bottom
        ADDA #115
        CMPA #231
        BHS s2_ky
s2_d    LDA 4,U
        STA <tlo
        LDA 2,U
        STA <tmp2+1
        TFR A,B
        LDA ,U
        JSR STARPIX
        LEAU 6,U
        DEC <cnt
        LBNE s2_l
        RTS
s2_kx   JSR DORND               ; y anywhere, x on the edge particles come in from
        JSR SMTOS
        STA 2,U
        CLR 3,U
        LDA #115
        TST <vsg
        BEQ s2_x
        NEGA
s2_x    STA ,U
        CLR 1,U
        BRA s2_z
s2_ky   JSR DORND               ; x anywhere; y on the top or bottom edge, by the roll
        JSR SMTOS
        STA ,U
        CLR 1,U
        LDB <jstx
        EORB <vsg
        LDA #110
        TSTB
        BPL s2_y
        NEGA
s2_y    STA 2,U
        CLR 3,U
s2_z    JSR DORND
        ORA #8
        STA 4,U                 ; any distance, not too close
        CLR 5,U
        BRA s2_d

; the stardust for the current view
STARS   LDA <view
        LBEQ STARS1
        DECA
        LBEQ STARS6
        JMP STARS2

; swap the coordinates of every particle (when the view changes)
STARFLIP
        LDU #stars
        LDA <nostm
        STA <cnt
sv_l    LDD ,U
        LDX 2,U
        STX ,U
        STD 2,U
        LEAU 6,U
        DEC <cnt
        BNE sv_l
        RTS

; A = view to show (0 front, 1 rear, 2 left, 3 right)
SETVIEW CMPA <view
        BEQ sv_r
        STA <view
        BRA STARFLIP
sv_r    RTS

; ---- the view's frame for a ship, planet or sun in inwk (the original PU1/PU2) ----
; rear: x and z of the position and of the three vectors change sign; left: x := z,
; z := -x; right: x := -z, z := x.
NEG24   COM ,X
        COM 1,X
        COM 2,X
        INC 2,X
        BNE ng_r
        INC 1,X
        BNE ng_r
        INC ,X
ng_r    RTS

NEG16   COM ,X
        COM 1,X
        INC 1,X
        BNE ng6
        INC ,X
ng6     RTS

; the pair (x at ,X and z at 6,X) of a 24-bit position
PUPAIR24
        LDD ,X
        STD <mg
        LDA 2,X
        STA <mg+2
        LDD 6,X
        STD ,X
        LDA 8,X
        STA 2,X
        LDD <mg
        STD 6,X
        LDA <mg+2
        STA 8,X
        LDA <view
        CMPA #2
        BEQ pp_z
        BRA NEG24               ; right: x = -old z
pp_z    LEAX 6,X                ; left: z = -old x
        BRA NEG24

; the pair (x at ,X and z at 4,X) of a 16-bit vector
PUPAIR16
        LDD ,X
        LDY 4,X
        STY ,X
        STD 4,X
        LDA <view
        CMPA #2
        BEQ pq_z
        BRA NEG16
pq_z    LEAX 4,X
        BRA NEG16

PUVIEW  LDA <view
        BEQ pv_x
        CMPA #1
        BNE pv_s
        LDX #inwk               ; rear
        JSR NEG24
        LDX #inwk+6
        JSR NEG24
        LDX #SIDEV
        JSR NEG16
        LDX #SIDEV+4
        JSR NEG16
        LDX #ROOFV
        JSR NEG16
        LDX #ROOFV+4
        JSR NEG16
        LDX #NOSEV
        JSR NEG16
        LDX #NOSEV+4
        JMP NEG16
pv_s    LDX #inwk               ; left or right
        JSR PUPAIR24
        LDX #SIDEV
        JSR PUPAIR16
        LDX #ROOFV
        JSR PUPAIR16
        LDX #NOSEV
        JMP PUPAIR16
pv_x    RTS
