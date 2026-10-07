; Ship slots: NSLOTS records of SLOTSZ bytes at <slots, each the inwk layout. A
; slot is in use when bit 7 of its flags byte (+31) is set. The ship being worked
; on is copied into inwk (and its blueprint pointer into <bp), then copied back.

; X = address of slot A
SLOTADDR
        LDB #SLOTSZ
        MUL
        ADDD #slots
        TFR D,X
        RTS

SLOTINIT
        LDA #NSLOTS-1
        STA <cnt
si_l    LDA <cnt
        JSR SLOTADDR
        LDA #TY_NONE
        STA 34,X
        DEC <cnt
        BPL si_l
        LDX #many               ; no ships of any type
        LDB #34+1
        CLRA
si_z    STA ,X+
        DECB
        BNE si_z
        RTS

; A SLOTSZ-byte block copy with PULS/PSHU, 7 bytes per pair of instructions (the
; direct page register is a data register for the duration: nothing here addresses
; the direct page, and it is put back afterwards). S reads the source upwards, U
; writes the destination downwards, so the blocks are taken from the top and S steps
; back over the block it has just read. Interrupts are off while S is a data pointer.
; BLKCPY: X = source, U = destination end (dest + SLOTSZ).
BLKCPY  STS <savs
        ORCC #$10
        LEAS SLOTSZ-5,X         ; the 5 bytes that do not fill a block go first
        PULS A,B,DP,X
        PSHU A,B,DP,X
        LEAS -12,S
        PULS A,B,DP,X,Y
        PSHU A,B,DP,X,Y
        LEAS -14,S
        PULS A,B,DP,X,Y
        PSHU A,B,DP,X,Y
        LEAS -14,S
        PULS A,B,DP,X,Y
        PSHU A,B,DP,X,Y
        LEAS -14,S
        PULS A,B,DP,X,Y
        PSHU A,B,DP,X,Y
        LEAS -14,S
        PULS A,B,DP,X,Y
        PSHU A,B,DP,X,Y
        LDA #2
        TFR A,DP
        LDS <savs
        ANDCC #$EF
        RTS

; copy the slot <slotn into inwk and point <bp at its blueprint
SLOTLOAD
        LDA <slotn
        JSR SLOTADDR
        STX <slotp
        LDU #inwk+SLOTSZ
        JSR BLKCPY
        LDB inwk+34
        BMI sl_np               ; planets and suns (type >= 128) have no blueprint
        DECB
        ASLB
        LDX xx21                ; the ship set's table, entry type-1
        ABX
        LDX ,X
        STX <bp
sl_np   RTS

SLOTSAVE
        LDX <slotp
        LEAU SLOTSZ,X
        LDX #inwk
        JMP BLKCPY

; first free slot -> <slotn, carry clear; carry set if all are in use
SLOTFREE
        CLR <slotn
sf_l    LDA <slotn
        JSR SLOTADDR
        LDA 34,X
        CMPA #TY_NONE
        BEQ sf_f
        INC <slotn
        LDA <slotn
        CMPA #NSLOTS
        BLO sf_l
        ORCC #1
        RTS
sf_f    ANDCC #$FE
        RTS

; Build a new ship in inwk: type A (the original's number), at the 24-bit position
; held in spawn..spawn+8 (x,y,z), facing us (nosev = -z) with unit orientation,
; speed B. The caller sets the counters and then calls SLOTPUT.
NEWSHIP PSHS A,B
        LDX #inwk
        LDD #0
        LDY #SLOTSZ/2
ns_c    STD ,X++
        LEAY -1,Y
        BNE ns_c
        LDX #spawn              ; position
        LDU #inwk
        LDY #9
ns_p    LDA ,X+
        STA ,U+
        LEAY -1,Y
        BNE ns_p
        LDD #$6000              ; sidev x, roofv y unit; nosev -z (towards us)
        STD inwk+9
        STD inwk+17
        LDD #$A000
        STD inwk+25
        PULS A,B
        STB inwk+27             ; speed
        STA inwk+34             ; type
        RTS

; store inwk into slot <slotn
SLOTPUT LDA <slotn
        JSR SLOTADDR
        STX <slotp
        JMP SLOTSAVE
