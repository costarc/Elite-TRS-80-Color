# Build the disk (build\elite.dsk) and the cartridge image (build\elite.rom):
#   .\mk.ps1 [-Skip n] [-Define NAME,NAME ...]
# The disk holds the resident program (ELITE.BIN, loaded with LOADM) and the overlay
# blob (ELITE.DAT, read by the loader); the cartridge image holds the same things for
# a Super Program Pak style banked ROM (see engine/loader.asm).
param(
    [int]$Skip = 0,
    [string[]]$Define = @(),
    [string]$OriginalSource = $env:ELITE_ORIGINAL_SOURCE,
    [string]$Assembler = 'lwasm',
    [string]$Decb = 'decb',
    [string]$Python = 'python.exe'
)
$ErrorActionPreference = 'Stop'
if (-not $OriginalSource) {
    throw 'Set ELITE_ORIGINAL_SOURCE or pass -OriginalSource with the external BBC Elite repository path. See README.md.'
}
$OriginalSource = (Resolve-Path $OriginalSource).Path
foreach ($required in @('1-source-files/main-sources/elite-ships-a.asm', '1-source-files/main-sources/elite-text-tokens.asm', '1-source-files/images/P.DIALS.bin')) {
    if (-not (Test-Path (Join-Path $OriginalSource $required))) { throw "Missing original asset: $required" }
}
$env:ELITE_ORIGINAL_SOURCE = $OriginalSource
$sourceDir = Join-Path $OriginalSource '1-source-files/main-sources'
function Invoke-Python {
    & $Python @args
    if ($LASTEXITCODE -ne 0) { throw 'Python build step failed.' }
}
Set-Location $PSScriptRoot
$Define = @($Define | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # also from a batch file: -Define A,B
$asm = $Assembler
$decb = $Decb
New-Item -ItemType Directory -Force build, coco-source\gen | Out-Null
# test keys (KEYSEQ build define): the text in $env:KEYSEQ, ~ is ENTER, typed by the docked screens' WAITKEY
$ks = $env:KEYSEQ
$kb = '0'
if ($ks) { $kb = (($ks.ToCharArray() | ForEach-Object { if ($_ -eq [char]'~') { 13 } else { [int]$_ } }) -join ',') + ',0' }
"KEYTXT FCB $kb" | Set-Content coco-source\gen\keyseq.inc
Invoke-Python coco-source\tools\assets.py
Invoke-Python coco-source\tools\linegen.py
Invoke-Python coco-source\tools\dash.py
Invoke-Python coco-source\tools\tokens.py $sourceDir coco-source\gen\tokens.inc | Out-Null
Invoke-Python coco-source\tools\ships.py $sourceDir coco-source\gen\ships.inc coco-source\gen\con.inc | Out-Null

# overlay segments: assembled on their own (raw) and packed into the blob
& $asm @('-9', '--format=raw', '-Icoco-source', '-obuild\ships.bin', '--map=build\ships.map') coco-source\seg\ships.asm
if ($LASTEXITCODE) { exit 1 }
& $asm @('-9', '--format=raw', '-Icoco-source', '-obuild\dash.bin', '--map=build\dash.map') coco-source\seg\dash.asm
if ($LASTEXITCODE) { exit 1 }
& $asm @('-9', '--format=raw', '-Icoco-source', '-obuild\perf.bin', '--map=build\perf.map') coco-source\seg\perf.asm
if ($LASTEXITCODE) { exit 1 }
& $asm @('-9', '--format=raw', '-Icoco-source', '-obuild\geom.bin', '--map=build\geom.map') coco-source\seg\geom.asm
if ($LASTEXITCODE) { exit 1 }
Invoke-Python coco-source\tools\segs.py

# The resident program is assembled twice: the first time for its labels, which the docked
# overlay needs; the second time when the overlay (and so the blob and its place on the disk)
# is known. Nothing in the program depends on the size of what is added in between.
$asmargs = @('-9', '--format=decb', '-Icoco-source', '-obuild\elite.bin', '--list=build\elite.lst', '--map=build\elite.map')
if ($Skip -gt 0) { $asmargs += "-DSKIPTICKS=$Skip" }
foreach ($d in $Define) { $asmargs += "-D$d" }
if (-not (Test-Path coco-source\gen\disksec.inc)) { "DISKGRAN FCB 0`nSAVEGRAN FCB 0" | Set-Content coco-source\gen\disksec.inc }
& $asm @asmargs coco-source\main.asm
if ($LASTEXITCODE) { exit 1 }
Invoke-Python coco-source\tools\mainsyms.py
$dockargs = @('-9', '--format=raw', '-Icoco-source', '-obuild\dock.bin', '--map=build\dock.map')
foreach ($d in $Define) { $dockargs += "-D$d" }
& $asm @dockargs coco-source\seg\dock.asm
if ($LASTEXITCODE) { exit 1 }
Invoke-Python coco-source\tools\segs.py

# the disk: the blob is the first file, so its place is known before the program is assembled
Remove-Item build\elite.dsk -ErrorAction SilentlyContinue
& $decb dskini build\elite.dsk | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Disk image step failed." }
& $decb copy -2 -b build\elite.dat build\elite.dsk,ELITE.DAT | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Disk image step failed." }
[System.IO.File]::WriteAllBytes("$PWD\build\elite.sav", (New-Object byte[] 4608))   # room for saved commanders
& $decb copy -2 -b build\elite.sav build\elite.dsk,ELITE.SAV | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Disk image step failed." }
Invoke-Python coco-source\tools\diskinfo.py build\elite.dsk ELITE DAT ELITE SAV

& $asm @asmargs coco-source\main.asm
if ($LASTEXITCODE) { exit 1 }
& $decb copy -2 -b build\elite.bin build\elite.dsk,ELITE.BIN | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Disk image step failed." }

# the cartridge image
if (Test-Path coco-source\tools\mkcart.py) { Invoke-Python coco-source\tools\mkcart.py $asm }
"built build\elite.dsk ($((Get-Item build\elite.bin).Length) bytes)"
