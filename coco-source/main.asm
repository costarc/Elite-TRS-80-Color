; Elite for the TRS-80 Color Computer: native 6809 rewrite.
; Development target: DECB BIN loaded at $2800 (see mk.ps1); 64K RAM, DP $02.
        INCLUDE "engine/vars.inc"
        INCLUDE "engine/types.inc"
        INCLUDE "gen/segsyms.inc"       ; the overlay segments' symbols
        INCLUDE "gen/medium.inc"

        IFDEF DEBUG
DEBUGFONT EQU 1
        ELSE
        IFDEF DIAG
DEBUGFONT EQU 1
        ENDC
        ENDC

        ORG $2800
        JMP START               ; $2800: from a disk (LOADM, EXEC)
        JMP STARTC              ; $2803: from the cartridge (boot/cartboot.asm)

START   ORCC #$50
        LDS #$0600              ; stack in the old text screen ($0400-$05FF)
        LDA #2
        TFR A,DP
        CLR <medium             ; disk
        BRA st_go
STARTC  ORCC #$50
        LDS #$0600
        LDA #2
        TFR A,DP
        LDA #1
        STA <medium             ; cartridge
st_go   STA $FFDF               ; all RAM: the segments go above $8000
        CLR ccvalid
        CLR cckey
        CLR cckey+1
        LDA #SEG_PERF
        JSR LOADSEG
        LBCS ld_err
        LDD #DIV32
        STD perfdiv
        LDD #SNE
        STD perfsin
        JSR MKTABS              ; the arithmetic tables
        JSR DINIT               ; the view's clearing records
        LDA #1
        STA snd                 ; sound on (cartridge RAM is not zero at power-up)
        CLR eggarm
        CLR eggst
        CLR eghold
        CLR shade               ; wireframe, until the Easter egg is found
        IFDEF SHADEON           ; test: shaded from the start
        INC shade
        ENDC
        LDA #SEG_SHIPS          ; the ship blueprints
        JSR LOADSEG
        BCS ld_err
        LDA #SEG_DASH           ; the dashboard art
        JSR LOADSEG
        BCS ld_err
restart  LDS #$0600
        CLR loadreq
        CLR rmax
        CLR ksq
        CLR ksq+1
        CLRA
        STA <paused
        JSR INITHW
        JSR KCLEAR
        CLR escn                ; (the cartridge's RAM is not zero at power-up: a stray escape
        CLR escr                ; pod countdown switches the collisions and the docking off)
        CLR scrreq
        LDA #1
        STA mvn
        STA fstep
        IFDEF SEGTEST
        CLR segdn
        ENDC
        IFDEF BENCH
        JSR BENCHGO
        ENDC
        IFDEF FLYTEST
        JSR FLYINIT
        IFDEF TESTDOCK         ; test: straight into the docked screens
        JSR NEWCMDR
        JSR GODOCKED
        JSR LAUNCH
td_h     JSR FLYFRAME
        BRA td_h
        ENDC
        IFDEF TUNTEST           ; test: the hyperspace tunnel, over and over
        LDD #$9800
        STD <back
        ANDCC #$EF
tt_l    JSR TUNNEL
        BRA tt_l
        ENDC
        IFDEF FLYLAUNCH         ; test: just launched, the station behind
        JSR LAUNCH
        IFDEF DOCKSET
        JSR SETDOCK
        ENDC
        ELSE
        JSR FLYSHIPS
        ENDC
        LDD #$9800
        STD <back
        ANDCC #$EF
flyl    JSR FLYFRAME
        TST dead
        BEQ flyl
        JSR DEATHSEQ
        JMP restart
        ENDC
        JSR TITLE
        LDD #$9800              ; draw into $9800 first; page $8000 is shown
        STD <back
        ANDCC #$EF              ; interrupts on: the vsync clock runs
        IFDEF SKIPTICKS
        JSR TSKIP
        ENDC
        IFDEF FREEZE
        LDA #1
        STA <paused             ; hold: only keys redraw
        JSR TDRAW
        ENDC
main    EQU *
        IFDEF SEGTEST           ; test: at run time wipe the ship data and load it again
        TST segdn
        BNE sg_n
        LDA <vcnt
        CMPA #120
        BLO sg_n
        INC segdn
        LDX #SHIPSBASE
sg_w    CLR ,X+
        CMPX #SHIPSBASE+$2000
        BNE sg_w
        IFNDEF SEGBAD
        LDA #SEG_SHIPS
        JSR LOADSEG
        BCS ld_err
        ENDC
sg_n    EQU *
        ENDC
        TST <paused
        BNE m_hold
        JSR TTICK
        BRA m_keys
m_hold  JSR WAITVS              ; hold the current page while paused
m_keys  EQU *
        IFDEF AUTOGAME           ; test: start the game after 150 ticks
        LDA <vcnt
        CMPA #150
        LBHS NEWGAME
        ENDC
        IFDEF AUTOCRED          ; test: credits on
        LDA #1
        STA tcred
        ENDC
        IFDEF AUTONAMES         ; test: names on
        LDA #1
        STA tnames
        ENDC
        JSR TKEYS
        BRA main


ld_err  BRA ld_err             ; the medium could not be read

        INCLUDE "engine/loader.asm"
        INCLUDE "engine/math.asm"
        INCLUDE "engine/line.asm"
        INCLUDE "engine/ll9.asm"
        INCLUDE "engine/shade.asm"
        INCLUDE "engine/screen.asm"
        INCLUDE "engine/keys.asm"
        INCLUDE "engine/text.asm"
        INCLUDE "engine/slots.asm"
        INCLUDE "engine/mveit.asm"
        INCLUDE "engine/stars.asm"
        INCLUDE "engine/views.asm"
        INCLUDE "engine/planet.asm"
        INCLUDE "engine/explode.asm"
        IFDEF DEBUGFONT
        INCLUDE "engine/debug.asm"
        ENDC
        INCLUDE "title/title.asm"
        INCLUDE "flight/flight.asm"
        INCLUDE "flight/shiploop.asm"
        INCLUDE "docked/text.asm"
        INCLUDE "flight/player.asm"
        INCLUDE "flight/dash.asm"
        IFDEF BENCH
        INCLUDE "flight/bench.asm"
        ENDC

        INCLUDE "gen/segtab.inc"
        INCLUDE "gen/disksec.inc"
        INCLUDE "gen/assets.inc"
        INCLUDE "gen/tokens.inc"
RESEND  EQU *
        IFGT RESEND-STAGE
        ERROR Resident program overlaps STAGE
        ENDC

        ORG $0E00               ; low resident code, above disk BASIC buffers
        INCLUDE "flight/universe.asm"
        INCLUDE "flight/tactics.asm"
        INCLUDE "flight/tactics2.asm"
        INCLUDE "flight/combat.asm"
        INCLUDE "flight/station.asm"
        INCLUDE "flight/jump.asm"
        INCLUDE "flight/sound.asm"
        INCLUDE "flight/hangar.asm"
        INCLUDE "flight/cmdr.asm"
        INCLUDE "docked/galaxy.asm"
LOWEND  EQU *
        IFGT LOWEND-$2600
        ERROR Low segment overlaps Disk BASIC workspace
        ENDC
        END START
