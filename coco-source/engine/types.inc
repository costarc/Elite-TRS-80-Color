; Ship type numbers: the original's (the type byte of a slot, +34). A blueprint is found
; in the current system's ship set: SHIPTAB entry type-1 (the original's XX21), with the
; set's default NEWB flags at NEWBTAB entry type-1 (the original's E%). Types of 128 and up
; are the planet (128) and the sun (129); $FF marks an empty slot.
TY_MSL  EQU 1           ; missile
TY_SST  EQU 2           ; Coriolis space station
TY_ESC  EQU 3           ; escape pod
TY_PLT  EQU 4           ; alloy plate
TY_OIL  EQU 5           ; cargo canister
TY_BOU  EQU 6           ; boulder
TY_AST  EQU 7           ; asteroid
TY_SPL  EQU 8           ; splinter
TY_SHU  EQU 9           ; shuttle
TY_TRA  EQU 10          ; transporter
TY_CYL  EQU 11          ; Cobra Mk III
TY_PYT  EQU 12          ; Python
TY_BOA  EQU 13          ; Boa
TY_ANA  EQU 14          ; Anaconda
TY_HER  EQU 15          ; rock hermit
TY_COPS EQU 16          ; Viper
TY_SH3  EQU 17          ; Sidewinder
TY_MAM  EQU 18          ; Mamba
TY_KRA  EQU 19          ; Krait
TY_ADA  EQU 20          ; Adder
TY_GEC  EQU 21          ; Gecko
TY_CO1  EQU 22          ; Cobra Mk I
TY_WRM  EQU 23          ; Worm
TY_CYL2 EQU 24          ; Cobra Mk III (pirate)
TY_ASP  EQU 25          ; Asp Mk II
TY_PYT2 EQU 26          ; Python (pirate)
TY_FDL  EQU 27          ; Fer-de-lance
TY_MOR  EQU 28          ; Moray
TY_THG  EQU 29          ; Thargoid
TY_TGL  EQU 30          ; Thargon
TY_CON  EQU 31          ; Constrictor
TY_PLANET EQU 128
TY_SUN  EQU 129
TY_NONE EQU $FF
JL      EQU TY_ESC      ; junk: from the escape pod
JH      EQU TY_SHU+2    ; to before the Cobra Mk III
