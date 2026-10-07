; Elite CoCo - memory map.
;
;   $0100-$011F   Color BASIC vector jumps (IRQ at $010C is ours)
;   $0200-$02FF   direct page ($02): hot scalars and the 3x3 matrix
;   $0300-$03FF   ship workspace and per-ship arrays
;   $0400-$05FF   stack (the old text screen)
;   $0700           (cartridge boot only) the boot copier, gone once the program runs
;   $0E00-$25FF     the title background (a LOADM segment of its own)
;   $2800-$7EFF     the resident program (LOADM or the cartridge boot copy it here)
;   $7F00-$7FFF     STAGE: the loader's one-sector buffer (engine/loader.asm)
;   $8000-$97FF     screen page A     (SAM offset 64*512)
;   $9800-$AFFF     screen page B     (SAM offset 76*512)
;   $B000-$B6FF     tables and scratch ($B200 MSKTAB, $B300 scrb)
;   $B9F0-$B9F2     message cache state;  $BD00-$BEFF MBUF, the message set in type
;   $BA00-$BCFF     RTAB, NTH, NTL: square roots and 96*256/n (MKTABS, at start-up)
;   $C000-$EFFF     overlay segment SHIPS (blueprints, ship sets, names), loaded at start-up
;   $F000-$F1FF     ship slots; $F200- stars; $F300-$FBFF overlay segment DASH (the
;                   dashboard art); $FC00-$FEFF explosion records
;   Everything from $8000 up is only visible in the SAM all-RAM mode, in which the BASIC
;   ROMs and a cartridge are not: the loader switches modes sector by sector.

; Position and size conventions
;   ship coordinates   24-bit two's complement, big endian (hi,mid,lo), 1 unit
;                      = 1 blueprint unit; z grows into the screen
;   orientation        3 vectors (sidev, roofv, nosev) x 3 axes, 16-bit signed,
;                      unity = $6000, as in the original
;   projection         256 * x / z about the screen centre (128, 96)

        SETDP $02

; ---- system -------------------------------------------------------------
back    EQU $0200       ; 2  page being drawn
vcnt    EQU $0202       ; 1  vsync counter (IRQ)
vlast   EQU $0203       ; 1  vcnt at the last flip
savs    EQU $0204       ; 2  saved S while it is used as a data pointer
cnt     EQU $0206       ; 1  scratch counter
cnt2    EQU $0207       ; 1  scratch counter
paused  EQU $0208       ; 1
keyold  EQU $0209       ; 1
keys    EQU $020A       ; 1  keys down now (K_*), updated by the IRQ
kpress  EQU $020B       ; 1  new presses since the main loop last looked
keytmp  EQU $020C       ; 1
shipidx EQU $020D       ; 1  title: index into SHIPLIST
work    EQU $020E       ; 2  drawing work done this frame (sets the tick length)

; ---- line drawing and clipping -------------------------------------------
lx0     EQU $0210       ; line end points, unsigned pixel bytes (adjacent)
ly0     EQU $0211
lx1     EQU $0212
ly1     EQU $0213
ldx8    EQU $0214
ldy8    EQU $0215
mask    EQU $0216
lup     EQU $0217
fcnt    EQU $028A       ; fast line loop passes
rowp    EQU $028C       ; 2  sun: screen address of the current row
cx0     EQU $0218       ; 16-bit signed clip coordinates: x0,y0,x1,y1
cy0     EQU $021A
cx1     EQU $021C
cy1     EQU $021E
occ     EQU $0220
c0      EQU $0221
c1      EQU $0222
cpri    EQU $0223       ; clip axis offset: 0 = x, 2 = y
cbound  EQU $0224       ; 2
csg     EQU $0226

; ---- arithmetic helpers ----------------------------------------------------
ma      EQU $0228       ; 2
mb      EQU $022A       ; 2
mr      EQU $022C       ; 4  32-bit product / dividend, quotient in mr+2
md      EQU $0230       ; 2  divisor
tmp     EQU $0232       ; 2
tmp2    EQU $0234       ; 2
tlo     EQU $0236       ; 1

; ---- ship drawing ----------------------------------------------------------
bp      EQU $0238       ; 2  blueprint pointer
zhi     EQU $023A       ; 1  ship z >> 8
lod     EQU $023B       ; 1  detail level (original XX4)
hsh     EQU $023C       ; 1  position scale shift h
ksh     EQU $023D       ; 1  6-h (signed)
xsc     EQU $023E       ; 1  face normal shift X
nv      EQU $023F       ; 1  vertices
ne      EQU $0240       ; 1  edges
nf      EQU $0241       ; 1  faces
sgnt    EQU $0242       ; 1
vax     EQU $0243       ; 3  vertex/normal magnitudes
vay     EQU $0244
vaz     EQU $0245
vsx     EQU $0246       ; 3  matching sign bytes (bit 7), shifted per axis
vsy     EQU $0247
vsz     EQU $0248
acc     EQU $0249       ; 2
xp      EQU $024B       ; 2  scaled ship position (units 2^(h-6))
yp      EQU $024D       ; 2
zp      EQU $024F       ; 2
xr      EQU $0251       ; 2  rotated vertex, 1/64 unit
yr      EQU $0253       ; 2
zr      EQU $0255       ; 2
ps      EQU $0257       ; 1  normalisation shift
pn      EQU $0258       ; 1
pu      EQU $0259       ; 1
psign   EQU $025A       ; 1
pm      EQU $025B       ; 2
ptmp    EQU $025D       ; 2
pcnt    EQU $025F       ; 1
p2h     EQU $0275       ; 1
vidx    EQU $0260       ; 1  vertex index * 4
pp      EQU $0261       ; 3  |P''| (face test position, 8-bit)
ppsg    EQU $0264       ; 3  sign bytes
ps64    EQU $0267       ; 6  ship-space position, 1/64 units (3 x 16)
tt      EQU $026D       ; 6  t_i for the current face (3 x 16)
fvis    EQU $0273       ; 1
nmul    EQU $0278       ; 1  face normal multiplier 2^(6-X), 0 for X >= 4
dacc    EQU $027A       ; 3  24-bit dot product accumulator
t24     EQU $027D       ; 3  24-bit term

; ---- original title / ship motion ----------------------------------------
ta      EQU $0280       ; 2
tb      EQU $0282       ; 2
tq      EQU $0284       ; 2
tr      EQU $0286       ; 2
tw      EQU $0288       ; 2

; ---- projection matrix (from the orientation vectors) ---------------------
mag     EQU $02A0       ; 9 magnitudes, unity 64, order sidev xyz, roofv xyz, nosev xyz
sgn     EQU $02A9       ; 9 sign bytes (bit 7)

; ---- keyboard, player and movement ------------------------------------------
kmat    EQU $02B2       ; 8 key matrix columns (bit = row)
delta   EQU $02C0       ; 1  player speed
alpha   EQU $02C1       ; 1  roll angle this frame (signed, |alpha| <= 31)
beta    EQU $02C2       ; 1  pitch angle this frame (signed, |beta| <= 8)
jstx    EQU $02C3       ; 1  roll rate (signed, +right)
jsty    EQU $02C4       ; 1  pitch rate (signed, +up)
mcnt    EQU $02C5       ; 1  main loop counter
mq      EQU $02C6       ; 1
msg     EQU $02C7       ; 1
qm      EQU $02C8       ; 1
mm      EQU $02C9       ; 2
k2      EQU $02CB       ; 3  24-bit scratch
slotn   EQU $02CE       ; 1  current slot
slotp   EQU $02CF       ; 2  pointer to the current slot
rand    EQU $02E4       ; 4  random seed (the original's RAND)
tdn     EQU $02D3       ; 3  TIDY: nosev (signed 8-bit hi bytes)
tdr     EQU $02D6       ; 3  TIDY: roofv
tds     EQU $02D9       ; 3  TIDY: sidev
tdv     EQU $02DC       ; 2
tdl     EQU $02DE       ; 1
tdk     EQU $02DF       ; 2
spawn   EQU $B120       ; 9  spawn scratch (x,y,z, 24-bit each)

; ---- stardust ----------------------------------------------------------------
nostm   EQU $02F0       ; 1  number of dust particles (18 in space, 3 in witchspace)
sq      EQU $02F1       ; 1  per-frame q
d64     EQU $02F2       ; 2  player speed * 64
sflag   EQU $B113       ; 1  turning flag for this frame (stars)

k24     EQU $02F4       ; 3  24-bit signed result (MULP24)
mg      EQU $02F7       ; 3  24-bit magnitude scratch

eux     EQU $02FA       ; ellipse vectors in pixels (signed): u = (eux,euy), v = (evx,evy)
euy     EQU $02FB
evx     EQU $02FC
evy     EQU $02FD
enz     EQU $02FE       ; z components (signed hi bytes) of the two ellipse vectors
ewz     EQU $02FF

; ---- extended-addressed workspace ------------------------------------------
inwk    EQU $0300       ; ship record
;  +0  x (3)   +3  y (3)   +6  z (3)
;  +9  sidev xyz, +15 roofv xyz, +21 nosev xyz   (16-bit signed each)
;  +27 speed  +28 acceleration  +29 roll counter  +30 pitch counter  +31 flags
;  +32 AI  +33 energy  +34 type (the original's number; $FF = empty slot)  +35 NEWB flags   [counters: bit 7 sign, bits 0-6 duration, 127 = endless]
visible EQU $0330       ; 16 face flags (index = face number)
scr     EQU $0340       ; 40 vertices x (sx hi,lo, sy hi,lo)

; ---- screen constants ----------------------------------------------------
; The screen is the original's 256 x 256 shown on 256 x 192: every vertical size is 3/4
; of the original's. So the 3D view (192 lines in the original) is the top VIEWH = 144
; rows and the dashboard (64 lines) the 48 below; and a vertical distance of y original
; pixels is 3y/4 here (SC34, the y perspective multiplier pu3, the planet's vertical
; radius kry, the sun's rows, the stars).
        IFNDEF VIEWH
VIEWH   EQU 144
        ENDC
CY      EQU VIEWH/2
XMIN    EQU 2
XMAX    EQU 253
YMIN    EQU 1
YMAX    EQU VIEWH-1
cyv     EQU $02E8       ; 2  screen row of the projection's centre (CY; the title screen's is 96)
ymx     EQU $02EA       ; 2  last row a line may reach (YMAX; the title screen's is 191)

; ---- the local universe and the player's ship (extended addressing) -------------
many    EQU $B400       ; 34 ships of each type in the local bubble (index = type)
sspr    EQU many+2      ;    the space station is present (the count of type 2)
junk    EQU $B422       ; 1  junk in the bubble (escape pods, plates, canisters, rocks, ...)
auto    EQU $B423       ; 1  docking computer on
ecmp    EQU $B424       ; 1  our E.C.M. is on, draining energy
ecma    EQU $B425       ; 1  an E.C.M. is going off (the countdown)
mj      EQU $B426       ; 1  in witchspace
fist    EQU $B427       ; 1  legal status (the original's FIST)
bst     EQU $B428       ; 1  fuel scoops fitted
mstg    EQU $B429       ; 1  slot of the missile target, $FF none
msar    EQU $B42A       ; 1  the missile is looking for a target
dly     EQU $B42B       ; 1  in-flight message countdown
mch     EQU $B42C       ; 1  message being shown
tp      EQU $B42D       ; 1  mission flags
cash    EQU $B430       ; 4  credits x 10, big endian
kills   EQU $B434       ; 2  kill tally
xx21    EQU $B440       ; 2  the ship set's blueprint table (the original's XX21)
newbt   EQU $B442       ; 2  and its default NEWB flags (E%)
k3      EQU $B450       ; 10 three 24-bit coordinates (hi,mid,lo) and a spare byte
xx15    EQU $B460       ; 3  a vector, three signed bytes, length 96
tcnt    EQU $B463       ; 1  tactics: the aim, a signed dot product (the original's CNT)
tcnt2   EQU $B464       ; 1  tactics: the largest angle that keeps full speed
trat    EQU $B465       ; 1  tactics: the size of a turn
trat2   EQU $B466       ; 1  tactics: below this twice the dot product, no turn
tt1     EQU $B467       ; 1  scratch
tt2     EQU $B468       ; 1  scratch
vp      EQU $B469       ; 2  pointer to another ship's slot
xsav    EQU $B46B       ; 1  the slot being processed
cpir    EQU $B46C       ; 1  pirate pack: the type being tried
ev      EQU $B46D       ; 1  extra vessels spawned recently (the original's EV)
gov     EQU $B46E       ; 1  the system's government, 0-7
qq20    EQU $B470       ; 17 the cargo hold, one byte per commodity
sfsbuf  EQU $B480       ; 40 the spawning ship's working copy while it makes a child
sfai    EQU $B4A8       ; 1  the child's AI byte
sfty    EQU $B4A9       ; 1  the child's type
sfcc    EQU $B4AA       ; 1  the carry of NWSHP
ecm     EQU $B4AB       ; 1  an E.C.M. system is fitted
dcnt    EQU $B4AD       ; 1  death sequence frames left
docked  EQU $B4AE       ; 1  docked at a station
qq15    EQU $B4B0       ; 6  the current system's seeds
tek     EQU qq5         ; the technology level - 1 of the system we are in
ksl     EQU $B4B7       ; 1  KILLSHP: the slot
; ---- text (docked/text.asm) ----------------------------------------------------------
xc      EQU $B4C0       ; 1  the text cursor: column 0-31
yc      EQU $B4C1       ; 1  row 0-23
qq17    EQU $B4C2       ; 1  case flags: $FF printing off, bit 7 sentence case, bit 6 lower case
dtw1    EQU $B4C3       ; 1  %00100000: lower case the rest of a word (extended tokens)
dtw2    EQU $B4C4       ; 1  0 in a word, $FF between words
dtw3    EQU $B4C5       ; 1  $FF: standard tokens in extended text
dtw4    EQU $B4C6       ; 1  bit 7: justify (buffer the line)
dtw5    EQU $B4C7       ; 1  characters in the justify buffer
dtw6    EQU $B4C8       ; 1  bit 7: lower case
dtw7    EQU $B4C9       ; 1  the character MT16 prints
dtw8    EQU $B4CA       ; 1  a mask: capitalise the next letter ($DF) or not ($FF)
tsc     EQU $B4CB       ; 1  scratch
tsc2    EQU $B4CC       ; 1  scratch
tyy     EQU $B4CD       ; 1  scratch
pdec    EQU $B4CE       ; 1  BPRNT: with a decimal point
ptw     EQU $B4CF       ; 1  BPRNT: field width
pfirst  EQU $B4D0       ; 1  BPRNT: first digit printed
knum    EQU $B4D1       ; 4  the 32-bit number to print / a work number
pdig    EQU $B4D5       ; 12 its digits
vv      EQU $B4E1       ; 2  token pointer
buf     EQU $B500       ; 64 the justified text buffer
; ---- the galaxy and the commander ----------------------------------------------------
qq2     EQU $B4E3       ; 6  the current system's seeds (qq15 is the selected one)
qq19    EQU $B4E9       ; 6  scratch seeds
qq3     EQU $B4EF       ; 1  economy
qq4     EQU $B4F0       ; 1  government
qq5     EQU $B4F1       ; 1  technology level - 1
qq6     EQU $B4F2       ; 1  population
qq7     EQU $B4F3       ; 2  productivity (big endian)
qq8     EQU $B4F5       ; 2  distance to the selected system, tenths of a light year (big endian)
qq9     EQU $B4F7       ; 1  the selected system's x
qq10    EQU $B4F8       ; 1  and y
qq0     EQU $B4F9       ; 1  the current system's x
qq1     EQU $B4FA       ; 1  and y
gcnt    EQU $B4FB       ; 1  galaxy number 0-7
qq11    EQU $B4FC       ; 1  the view: 0 space, else a docked screen
na      EQU $B540       ; 9  the commander's name, ended with a 13
qq21    EQU $B4B8       ; 6  the galaxy's seeds (system 0)
zz      EQU $B4BE       ; 1  the number of the selected system
lny     EQU $B4BF       ; 1  scratch: a line's row
lastkey EQU $B560       ; 1  the key last returned by WAITKEY
STAGE   EQU $7F00         ; 256 bytes of low RAM: a disk sector on its way (the loader, the saved commanders)
DOCKENTRY EQU $C000     ; the docked overlay's entries (seg/dock.asm)
FSCRENTRY EQU $C003
MOREENTRY EQU $C006
; the equipment: four flags together (the status screen prints them in turn)
bomb    EQU $B550       ; 1  an energy bomb
engy    EQU $B551       ; 1  an energy unit (energy recharges twice as fast)
dkcmp   EQU $B552       ; 1  a docking computer
ghyp    EQU $B553       ; 1  a galactic hyperdrive
escp    EQU $B554       ; 1  an escape pod
crgo    EQU $B555       ; 1  the cargo capacity in tonnes (22, 35 with the large bay)
; ---- the market (docked/market.asm) ---------------------------------------------------
qq24    EQU $B565       ; 1  the price of the item
qq25    EQU $B566       ; 1  the quantity for sale / the number we can give
qq26    EQU $B567       ; 1  the random price variation of this visit
qq28    EQU $B568       ; 1  the economy of the market (qq3 on arrival)
qq29    EQU $B569       ; 1  the item being dealt with
avl     EQU $B56A       ; 17 the quantity for sale of each item
mk      EQU $B57C       ; 5  work: the item's table offset, flags, factor, qq19+3, number
gnr     EQU $B581       ; 1  gnum: the number typed
gnn     EQU $B582       ; 1  digits left
gnq     EQU $B583       ; 1  the key
gnd     EQU $B584       ; 1  its digit
gnt     EQU $B585       ; 1  work
pendkey EQU $B586       ; 1  a key the docked loop has to take next (BAY2)
dmsp     EQU $B587      ; 2  the docked loop's stack
eqq     EQU $B589       ; 1  the equipment shop: items offered + 1
eqx     EQU $B58A       ; 1  the item being listed
eqy     EQU $B58B       ; 1  the laser's view
; key matrix rows: LDA <kmat+column / BITA #R<row> (non-zero = down)
R0      EQU $01
R1      EQU $02
R2      EQU $04
R3      EQU $08
R4      EQU $10
R5      EQU $20

; ---- the charts (docked/chart.asm) ------------------------------------------------------
zz2     EQU $B590       ; 1  a system's size byte
tx12    EQU $B591       ; 1  its x on the short chart
ty      EQU $B592       ; 1  its y
kc      EQU $B593       ; 1  radius of the fuel circle
dcx     EQU $B594       ; 1  disc: centre x
dcy     EQU $B595       ; 1  y
dcr     EQU $B596       ; 1  radius
dcd     EQU $B597       ; 1  the row offset
dch     EQU $B598       ; 1  half width
dcs     EQU $B599       ; 1  start x
dcn     EQU $B59A       ; 1  pixels left
sysn    EQU $B59B       ; 1  the system being drawn
cdy     EQU $B59C       ; 1  crosshairs: dy
cfst    EQU $B59D       ; 1  circle: first point
cpvx    EQU $B59E       ; 2  circle: the previous point
cpvy    EQU $B5A0       ; 2
chartocc EQU $B5A2      ; 26 the short chart: rows that have a name
; ---- hyperspace and messages (flight/jump.asm) ------------------------------------------
hnum    EQU $B5C0       ; 1  the hyperspace countdown, 15 to 1; 0 none
hlast   EQU $B5C1       ; 1  the vsync count at the last step
scrreq  EQU $B5C2       ; 1  a screen key pressed in flight
flying  EQU $B5C3       ; 1  the overlay is showing a screen for the flight (not docked)
fscr    EQU $B5C4       ; 1  the view to go back to ($FF none)
tunf    EQU $B5C5       ; 1  tunnel frame
tunr    EQU $B5C6       ; 1  tunnel ring
de      EQU $B5C7       ; 1  the next message gets " DESTROYED" after it (the original's de)
mde     EQU $B5C8       ; 1  the message being shown has it
escn    EQU $B5C9       ; 1  escape pod: frames left
escr    EQU $B5CA       ; 1  the escape pod key was pressed
cname   EQU $B5E0       ; 9  a commander's name being typed or looked for, ended by a 13
cfree   EQU $B5E9       ; 1  the first empty save sector
csec    EQU $B5EA       ; 1  the sector of the name looked for ($FF none)
cidx    EQU $B5EB       ; 1  the sector being looked at
ksq     EQU $B5F0       ; 2  test keys: the next one
ksqt    EQU $B5F2       ; 1  test keys: the tick of the last
dk2d    EQU $B5EE       ; 1  test: the second key has been sent
rmax    EQU $B5ED       ; 1  the longest line MT26 reads (0: 9)
loadreq EQU $B5EC       ; 1  the title's Y: load a commander on entering the bay
eggarm  EQU $B5CF       ; 1  the title is showing: the S-H-A-D-E sequence is watched
eghold  EQU $B5DE       ; 1  a sequence letter is being held
eggst   EQU $B5DF       ; 1  the next letter expected (1-5), 0 before the first arming
hcnt    EQU $B5D0      ; hangar: scratch counter
hmul    EQU $B5D1       ; hangar: several ships
hlin    EQU $B5D2       ; hangar: floor line number
hrow    EQU $B5D3       ; hangar: pixel row
hx      EQU $B5D4       ; hangar: pixel column
qlast   EQU $B5CE       ; 1  the Q key was down
snd     EQU $B5CD       ; 1  sound: 1 full, 2 short combat sounds, 0 off (the Q key)
mpg     EQU $B5CC       ; 1  text that fills the screen waits for a key and goes on from this row (0: clears it all)
kdis    EQU $B5CB       ; 1  docking: the length of the vector to the station before scaling
dead    EQU $B4AC       ; 1  we have died: the death sequence runs

; ---- ship slots (all-RAM mode: $8000 and up is RAM) ----------------------------
stars   EQU $F200       ; stardust: 6 bytes each (x hi,lo  y hi,lo  z hi,lo), x and y signed
slots   EQU $F000       ; NSLOTS ship records of SLOTSZ bytes: the inwk layout
SLOTSZ  EQU 40          ;  +32 AI  +33 energy  +34 type (the original's number; $FF = empty slot)  +35 NEWB flags
; Slot +36: scanner attack hold (vsync ticks); +37: pulse phase (0/$FF).
; NEWSHIP clears both; neither changes the ship's 3D appearance.
SCANHOLD EQU 90         ; 1.5 seconds at the 60Hz game clock
NSLOTS  EQU 12          ;  +31 flags: bit 7 = slot in use

; ---- planet / sun drawing scratch ------------------------------------------------
; Direct page, overlaid on the ship drawing scratch (vax..zr, pp..fvis, pmg/t24):
; a ship and a planet are never drawn inside one another, so they never share a moment.
ppos    EQU $03E0       ; 9  scaled x,y,z of the planet (24-bit each)
prs     EQU $03E9       ; 1  shift applied to bring z below 32768
pcx     EQU $0268       ; 2  circle centre, screen x
pcy     EQU $026A       ; 2  circle centre, screen y
pvx     EQU $0264       ; 2  previous circle point
pvy     EQU $0266       ; 2
kr      EQU $0256       ; 1  circle radius
pstp    EQU $0254       ; 1  circle step (of 64)
ccn     EQU $0271       ; 1  circle counter
pfst    EQU $0255       ; 1  first point flag
ec0     EQU $0251       ; 1  ellipse start counter
etgt    EQU $0252       ; 1  ellipse length in counter units (32 half, 64 full)
ecn     EQU $0253       ; 1
ecx     EQU $0260       ; 2  ellipse centre
ecy     EQU $0262       ; 2
efp     EQU $026C       ; 2  previous z value (FINDST)
MBUF    EQU $BD00       ; 256 the in-flight message set in type (+256 spill for a line feed: $BE00-$BEFF)
DTAB    EQU $B980       ; 2 x 32 the bands (8 rows) drawn on each page since its last clear (O11): 32, so a row of
                        ; 192-255 (a docked screen) cannot reach the variables after it
dbp     EQU $B9C0       ; 2  the band table of the page being drawn
dsp     EQU $B9C2       ; 2  the next free entry of its pixel list
dse     EQU $B9C4       ; 2  the end of that list
dsend   EQU $B9C6       ; 2 x 2  where each page's pixel list ended
dfull   EQU $B9CA       ; 2  per page: clear it all next time
dmoff   EQU $B9CC       ; 1  no marking: every page is cleared whole (a busy scene)
dhold   EQU $B9CD       ; 1  frames left in that mode
dtmp    EQU $B9CE       ; 1  scratch of the marking
DLIST   EQU $BF00       ; 2 x 64 x 2 per page: the bytes the stars and particles changed
mvalid  EQU $B9F0       ; 1  MBUF: 0 to be set, 1 kept, $FF drawn every frame
mxc     EQU $B9F1       ; 1  MBUF: xc after the text (its columns 9..mxc-1)
mq17    EQU $B9F2
ftick   EQU $B9F3       ; 1  the vsyncs since the last frame (TIMESTEP), at most REFTICKS*FSTEPMAX
srem    EQU $B9F4       ; 3  SCALEON: the remainders of roll, pitch and speed (1/REFTICKS)
cullf   EQU $B9F8       ; 1  test (CULLCHECK): the ship being drawn was found outside the view       ; 1  MBUF: qq17 after the text
RTAB    EQU $BA00       ; 256 isqrt(h*256+255) (ISQRT16)
NTH     EQU $BB00       ; 256 high bytes of 96*256/n (NORM3); NTL = NTH+256 the low bytes
hwt     EQU $B000       ; sun: half-width per scaled row, 0..kry (193 bytes; below expp)
ssq     EQU $027E       ; 2  sun: K*K
sv      EQU $027D       ; 1
sw      EQU $027C       ; 1
sfr     EQU $0274       ; 1  fringe mask
sy      EQU $027A       ; 1  current row
sy1     EQU $027B       ; 1  last row

; ---- explosions -------------------------------------------------------------------
expl    EQU $FC00       ; per-slot explosion record, EXPSZ bytes each:
EXPSZ   EQU 64          ;  +0 cloud size  +1 cloud counter  +2 vertices  +3..6 seeds
                        ;  +7.. screen (x,y) of the first vertices, 4 bytes each
expp    EQU $B0D0       ; 2  record pointer
expdone EQU $B0D2       ; 1  set when the cloud has run its course
exq     EQU $B0D3       ; 1  distance
exs     EQU $B0D4       ; 1  cloud size
exu     EQU $B0D5       ; 1  particles per vertex - 1
exi     EQU $B0D6       ; 1  vertex index
exn     EQU $B0D7       ; 1  vertices
exc     EQU $B0D8       ; 2  centre scratch
exv     EQU $B0DA       ; 2  vertex pointer

; ---- benchmark -----------------------------------------------------------------------
bres    EQU $B100       ; 16 results (vsync ticks per run)
bcnt    EQU $B110       ; 1
bt0     EQU $B111       ; 1
cnt3    EQU $B112       ; 1


MSKTAB  EQU $B200       ; 8 sign patterns x 32 bytes: XOR masks (see MKMASK)
vptr    EQU $0290       ; 2  TRANSFORM output pointer
p7      EQU $0292       ; 3  ship-space viewer position, |.| < 64 (FACEVIS)
tsg     EQU $0295       ; 1  its signs (bits 7,6,5)
fs      EQU $0296       ; 1  face sign bits
fshw    EQU $0297       ; 2  its scale shift s
fcl     EQU $0299       ; 2  left shift of the n term
pmg     EQU $027A       ; 6  |ps64|
scrb    EQU $B300       ; 40 vertices x (sx low, sy low, outcode, -)
kq      EQU $026E       ; 1  256 * K / 96
pin     EQU $026F       ; 1  previous circle point outside the viewport
pnin    EQU $0270       ; 1  this one
avx     EQU $0243       ; |ellipse vectors| (v then u) and their sign bytes
aux     EQU $0244
avy     EQU $0245
auy     EQU $0246
svx     EQU $0247
sux     EQU $0248
svy     EQU $0249
suy     EQU $024A
sm1     EQU $024B       ; |sin|, |cos| of this point
sm2     EQU $024C
ss1     EQU $024D       ; their signs (bit 7)
ss2     EQU $024E
ecc     EQU $024F
fhi     EQU $0272
fmid    EQU $0273
tm1     EQU $0250
srnd    EQU $029E       ; 1  sun fringe LFSR state
tv2     EQU $029B       ; 1  2v+1 (sun half-width table)
pxl     EQU $029C       ; 1  sun: centre x low byte
fcnt2   EQU $029D       ; 1  passes of the right half of a shallow line
hwk     EQU $B0F4       ; 1  radius the sun's half-width table was built for
wk      EQU $029F       ; 1  $FF: perspective from the ship's centre (far ships), else per vertex
ladw    EQU $B0F5       ; 2  LADU rung for the centre perspective
cxw     EQU $B0F7       ; 2  far ship: screen position of the centre
cyw     EQU $B0F9       ; 2
medium  EQU $0258       ; 1  0 = disk, 1 = cartridge (engine/loader.asm)
SHIPSBASE EQU $C000     ; the SHIPS segment
segdn   EQU $B141       ; 1  SEGTEST: the run-time reload has happened
; player state shown on the dashboard (the flight loop proper will own these)
fsh     EQU $B150       ; 1  forward shield 0-255
ash     EQU $B151       ; 1  aft shield
qq14    EQU $B152       ; 1  fuel 0-70 (tenths of a light year)
cabtmp  EQU $B153       ; 1  cabin temperature
gntmp   EQU $B154       ; 1  laser temperature
altit   EQU $B155       ; 1  altitude
energy  EQU $B156       ; 1  energy 0-255
bank    EQU $B157       ; 4  energy bank levels 0-16 (top bank first)
dtx     EQU $B15B       ; 1  scanner: x of the dot
dtb     EQU $B15C       ; 1  scanner: row of the stick's base
dtr     EQU $B15D       ; 1  scanner: row of the dot
dtm     EQU $B15E       ; 1  scanner: ship's slot address work
laser   EQU $B170       ; 4  laser fitted per view (front, rear, left, right): 0 none, else the
                        ;    power (bit 7: a beam laser)
las     EQU $B174       ; 1  power of the laser fired this loop
lasxy   EQU $B175       ; 2  where this shot's beams start
nomsl   EQU $B178       ; 1  missiles carried (0-4)
bulbs   EQU $B179       ; 1  bit 0: the E.C.M. bulb (E) is lit, bit 1: the station bulb (S)
psum    EQU $B17A       ; 1  SUMSQ accumulator
tnames  EQU $B16C       ; 1  title: show the ship names (T toggles)
tcred   EQU $B16D       ; 1  title: show the credits instead of the ship (C toggles)
cv      EQU $B160       ; 9  compass: the planet's vector, shifted down to a byte
cvb     EQU $B169       ; 3  and as 3 signed bytes
view    EQU $0276       ; 1  space view: 0 front, 1 rear, 2 left, 3 right
vsg     EQU $0277       ; 1  side-view dust: $FF for the right view
pu3     EQU $029A       ; 1  y perspective multiplier: 3/4 of pu (overlaid on fcl)
kry     EQU $0299       ; 1  planet: vertical radius, 3/4 of kr (overlaid on fcl)

; game time independent of the frame rate: the frame's length in vsyncs is turned into loops of the
; reference game (REFTICKS vsyncs each), and what moves is moved that many loops' worth
tpre    EQU $B17B       ; 1  vcnt at the last frame
tacc    EQU $B17C       ; 1  vsyncs left over (less than one reference loop)
fstep   EQU $B17D       ; 1  reference loops this frame (1-FSTEPMAX)
mvn     EQU $B17E       ; 1  the same for MVEIT's forward movement and the ships' own turns (1 outside the flight)
sva     EQU $B17F       ; 1  the roll, pitch and speed the player's keys made, while the scaled ones are in use
svb     EQU $B180       ; 1
svd     EQU $B181       ; 1
sca     EQU $B182       ; 1  the scaled ones, to tell whether the loop changed them
scb     EQU $B183       ; 1
scd     EQU $B184       ; 1
REFTICKS EQU 6          ; the reference game's loop: 10 a second
FSTEPMAX EQU 8
tlog    EQU $B185       ; 5  TIMELOG test counters
duem    EQU $B18A       ; 2  bit n: the loop count with mcnt & 15 = n went by since the ships last looked
lastp   EQU $B18C       ; 1  vcnt at the last pulse of our pulse laser
lshots  EQU $B18D       ; 1  shots of the laser fired this frame (reference loops, for a beam laser)
mcol    EQU $B18E       ; 1  the column an in-flight message starts at (centred)
dkpath  EQU $B18F       ; 1  test (DOCKLOG): the branch DOCKIT took
dklast  EQU $B190       ; 1  test (DOCKLOG): the last branch logged
klat    EQU $B1A0       ; 8  the keys that went down since the flight last looked (KLATCH, KMERGE)
