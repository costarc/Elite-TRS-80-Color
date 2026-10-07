; Overlay segment DOCK: the docked screens (and, for now, all the text of the extended
; tokens). It is brought into the RAM above $8000 where the ship blueprints are, while
; we are docked (the blueprints are read back on launch). The resident program's labels
; come from gen/mainsyms.inc (tools/mainsyms.py, from the previous assembly).
        INCLUDE "engine/vars.inc"
        INCLUDE "engine/types.inc"
        INCLUDE "gen/mainsyms.inc"
        ORG $C000
        JMP DOCKEDMODE          ; $C000: the entry from the docked loop
        JMP FSCREEN             ; $C003: a screen in flight
        JMP MORE                ; $C006: a text that has filled the screen
        INCLUDE "docked/detok.asm"
        INCLUDE "docked/screens.asm"
        INCLUDE "docked/market.asm"
        INCLUDE "docked/equip.asm"
        INCLUDE "docked/system.asm"
        INCLUDE "docked/chart.asm"
        INCLUDE "docked/mission.asm"
        INCLUDE "docked/disk.asm"
        INCLUDE "gen/keyseq.inc"
        INCLUDE "gen/tokens_dock.inc"
        END
