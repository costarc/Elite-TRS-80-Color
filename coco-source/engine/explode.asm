; Explosion clouds (original DOEXP). A destroyed ship is replaced by a cloud of
; particles around each of its first n projected vertices. The cloud grows with a
; counter that ticks 4 per frame and shrinks with distance:
;   size = 8 * counter / distance (as 256*counter/distance, x8, at most 254)
;   particles per vertex = (counter < 128 ? counter : ~counter) / 8, at least 1
; Each vertex has its own fixed random seeds, so the particles stay in the same
; places as the cloud grows. Particle size follows a random "distance" (PIXELZ).

DORND2  ANDCC #$FE              ; DORND with the carry cleared
        JMP DORND

; address of the explosion record of slot <slotn -> X
EXPADDR LDA <slotn
        LDB #EXPSZ
        MUL
        ADDD #expl
        TFR D,X
        RTS

; the ship in slot <slotn (inwk, blueprint <bp) starts to explode
EXPSTART
        JSR EXPADDR
        LDA #18
        STA 1,X                 ; cloud counter
        LDY <bp
        LDA 7,Y                 ; explosion count: 4*n + 6
        SUBA #6
        LSRA
        LSRA
        STA 2,X                 ; n
        JSR DORND
        STA 3,X
        JSR DORND
        STA 4,X
        JSR DORND
        STA 5,X
        JSR DORND
        STA 6,X
        LDA inwk+31
        ORA #$20
        STA inwk+31
        RTS

; (D = centre) -> D = centre +- random * size / 256 (the original EXS1)
EXS1    STD <tmp
        JSR DORND2
        ASLA                    ; carry = sign choice, A = random * 2
        PSHS CC
        LDB exs
        MUL
        TFR A,B
        CLRA
        PULS CC
        BCS ex_s
        ADDD <tmp
        RTS
ex_s    JSR NEGD
        ADDD <tmp
        RTS

; draw the cloud of the exploding ship in inwk; sets <expdone when it has ended.
; The first n projected vertices are in <scr.
DOEXP   JSR EXPADDR
        STX expp
        CLR expdone
        LDA inwk+7              ; distance
        CMPA #32
        BHS ex_far
        LDD inwk+7
        ASLB
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        ORA #1
        BRA ex_q
ex_far  LDA #254
ex_q    STA exq
        LDX expp
        LDA 1,X
        ADDA #4
        BCC ex_c
        LDA #1
        STA expdone             ; the cloud has run its course
        RTS
ex_c    STA 1,X
        STA <tlo
        LDA exq                 ; 256 * counter / distance
        CLR <md
        STA <md+1
        LDA <tlo
        CLRB
        STD <mr+2
        LDD #0
        STD <mr
        JSR DIV32
        LDD <mr+2
        TSTA
        BEQ ex_s1
        CMPA #28
        BHS ex_big
ex_s1   ASLB                    ; (P R) * 8, high byte = size
        ROLA
        ASLB
        ROLA
        ASLB
        ROLA
        BRA ex_sz
ex_big  LDA #254
ex_sz   STA exs
        LDX expp
        STA ,X
        LDA 1,X                 ; particles per vertex
        BPL ex_u
        COMA
ex_u    LSRA
        LSRA
        LSRA
        ORA #1
        STA exu
        LDA 2,X
        STA exn
        PSHS X                  ; this frame's projected vertices become the cloud centres
        LEAX 7,X
        LDU #scr
        LDA exn
        ASLA
        ASLA
        STA <cnt
ex_cp   LDA ,U+
        STA ,X+
        DEC <cnt
        BNE ex_cp
        PULS X
        LDA <rand+1
        PSHS A
        LDA #0
        STA exi
        LEAX 7,X
        STX exv
ex_vl   LDX expp                ; seeds, different for every vertex
        LDA 3,X
        EORA exi
        STA <rand
        LDA 4,X
        EORA exi
        STA <rand+1
        LDA 5,X
        EORA exi
        STA <rand+2
        LDA 6,X
        EORA exi
        STA <rand+3
        LDA exu
        STA <cnt2
ex_pl   JSR DORND2              ; the particle's own distance
        STA <tlo
        LDX exv                 ; y = vertex y +- random
        LDD 2,X
        JSR EXS1
        TSTA
        BNE ex_y
        CMPB #YMAX
        BHI ex_y
        STB <ly0
        LDX exv                 ; x = vertex x +- random
        LDD ,X
        JSR EXS1
        TSTA
        BNE ex_nx
        STB <lx0
        LDA <ly0
        JSR PIXELZ
ex_nx   DEC <cnt2
        BPL ex_pl
        BRA ex_nv
ex_y    JSR DORND2              ; keep the random sequence in step (the original EX11)
        BRA ex_nx
ex_nv   LDD exv
        ADDD #4
        STD exv
        INC exi
        LDA exi
        CMPA exn
        BLO ex_vl
        PULS A
        STA <rand+1
        RTS
