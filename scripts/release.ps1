# release.ps1 - Varianten bauen, die .jic nach bin\ legen, changelog fortschreiben.
#
#   .\release.ps1 -Note "kurz, was diese Version aendert"
#   .\release.ps1 -Note "..." -Variants plus_hw21x_cyclone_10
#   .\release.ps1 -Note "..." -Force        vorhandene Datei ueberschreiben
#
# Die Versionsnummer setzt sich zusammen aus variants\<n>\variant.psd1 (BoardId,
# zweistellig, identisch mit BOARD_ID in variant_pkg.vhd) und lib_common\version_pkg.vhd
# (SW_SUB). Ein Release aendert genau EINE Ziffer in version_pkg.vhd, alle Boards folgen:
#   bin\<BinFolder>\GottFA80_PLuS_v<BoardId><SW_SUB>.jic
#
# bin\ ist (Stand 11/2026) NICHT im Git-Repo - die Releases liegen nur auf dem
# Netzlaufwerk und auf lisy.dev/swrep.
param(
    [Parameter(Mandatory)][string]$Note,
    [string[]]$Variants,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarRoot   = Join-Path $RepoRoot 'variants'
$BinRoot   = Join-Path $RepoRoot 'bin'
$Project   = 'SYS80'
$Product   = 'GottFA80_PLuS'

$verSrc = Get-Content (Join-Path $RepoRoot 'lib_common\version_pkg.vhd') -Raw
if ($verSrc -notmatch "SW_SUB\s*:\s*character\s*:=\s*'(\d)'") { throw 'SW_SUB nicht in lib_common\version_pkg.vhd gefunden' }
$sub = $Matches[1]

$dirs = Get-ChildItem $VarRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'variant.psd1') }
if ($Variants) { $dirs = $dirs | Where-Object { $Variants -contains $_.Name } }
else {
    $dirs = $dirs | Where-Object {
        $m = Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')
        -not $m.Dormant
    }
}
if (-not $dirs) { throw 'keine Varianten zu releasen' }

$done = @()
foreach ($dir in $dirs) {
    $meta = Import-PowerShellDataFile (Join-Path $dir.FullName 'variant.psd1')
    $pkg  = Get-Content (Join-Path $dir.FullName 'variant_pkg.vhd') -Raw
    if ($pkg -notmatch 'BOARD_ID\s*:\s*string\(1 to 2\)\s*:=\s*"(\d\d)"') { throw "BOARD_ID fehlt in $($dir.Name)\variant_pkg.vhd" }
    if ($Matches[1] -ne $meta.BoardId) { throw "$($dir.Name): BoardId in variant.psd1 ($($meta.BoardId)) <> variant_pkg.vhd ($($Matches[1]))" }

    $ver  = "$($meta.BoardId)$sub"
    $ext  = $meta.ReleaseArtifact
    $target = Join-Path $BinRoot ($meta.BinFolder -replace '/', '\')
    if (-not (Test-Path $target)) { New-Item -ItemType Directory $target | Out-Null }
    $dest = Join-Path $target "${Product}_v$ver.$ext"

    if ((Test-Path $dest) -and -not $Force) {
        throw "$dest gibt es schon. SW_SUB in lib_common\version_pkg.vhd hochziehen oder -Force benutzen."
    }

    & (Join-Path $ScriptDir 'build.ps1') $dir.Name
    $src = Join-Path $dir.FullName "output_files\$Project.$ext"
    if (-not (Test-Path $src)) { throw "Artefakt fehlt: $src" }
    Copy-Item $src $dest -Force

    $sha = (Get-FileHash $dest -Algorithm SHA256).Hash.Substring(0, 16)
    $done += [pscustomobject]@{ Variant = $dir.Name; Version = $ver; File = "$($meta.BinFolder)/$(Split-Path $dest -Leaf)"; Sha = $sha }
}

# Ein Changelog fuer alle PLuS-Varianten. Die aelteren Eintraege stehen in
# bin\PLuS\HW2.1x\changelog.txt.
$log   = Join-Path $BinRoot 'PLuS\changelog.txt'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$head  = (($done | Sort-Object Version | ForEach-Object { "v$($_.Version)" }) -join '/')
$lines = @('', "-- $head $Note", "   $stamp")
foreach ($d in ($done | Sort-Object Variant)) {
    $lines += "   {0,-22} {1,-4} {2}  sha256:{3}" -f $d.Variant, $d.Version, $d.File, $d.Sha
}
Add-Content -Path $log -Value $lines -Encoding UTF8

$done | Format-Table -AutoSize
Write-Host "In $log fortgeschrieben." -ForegroundColor Green
Write-Host "Nicht vergessen: in VARIANTEN.md eintragen, welche Variante tatsaechlich auf Hardware getestet wurde." -ForegroundColor Yellow
