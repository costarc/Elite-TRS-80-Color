; Overlay segment SHIPS: the ship blueprints, type tables, sizes and names.
; Assembled on its own (raw) at SHIPSBASE; the resident program learns the symbols
; from gen/segsyms.inc. Loaded into RAM above $8000 by the loader (engine/loader.asm).
        ORG $C000
        INCLUDE "gen/ships.inc"
        END
