# build.ps1 - eine Variante voll compilieren und die .jic erzeugen.
#
#   .\build.ps1 plus_hw21x_cyclone_iv
#   .\build.ps1 plus_hw21x_cyclone_10 -NoJic
#
# quartus_cpf laeuft mit dem VARIANTENORDNER als Arbeitsverzeichnis - deshalb sind
# die Pfade in SYS80.cof relativ dazu (output_files/SYS80.sof). Die alten flachen
# Projektordner hatten gar keine .cof (die .jic entstand in der IDE); die .cof der
# 80S-Variante zeigte absolut auf ihren eigenen Ordner - beim Kopieren haette man damit
# die .sof des falschen Boards gebrannt.
param(
    [Parameter(Mandatory, Position = 0)][string]$Variant,
    [switch]$NoGen,
    [switch]$NoJic
)

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$VarDir     = Join-Path (Join-Path $RepoRoot 'variants') $Variant
$QuartusBin = 'C:\intelFPGA_lite\22.1std\quartus\bin64'
$Project    = 'SYS80'

if (-not (Test-Path $VarDir)) { throw "unbekannte Variante: $Variant" }

if (-not $NoGen) { & (Join-Path $ScriptDir 'gen_qsf.ps1') -Variants $Variant -Quiet }

$meta = Import-PowerShellDataFile (Join-Path $VarDir 'variant.psd1')
Write-Host "Baue $Variant - $($meta.Title)" -ForegroundColor Cyan

Push-Location $VarDir
try {
    # KEIN 2>&1 auf quartus_*.exe (PowerShell 5.1 macht aus der TBBmalloc-Notiz auf
    # stderr einen Fehler). $LASTEXITCODE ist die verlaessliche Auskunft.
    & "$QuartusBin\quartus_sh.exe" --flow compile $Project
    if ($LASTEXITCODE -ne 0) { throw "quartus_sh --flow compile ist fehlgeschlagen ($LASTEXITCODE)" }

    $sof = Join-Path $VarDir "output_files\$Project.sof"
    if (-not (Test-Path $sof)) { throw "keine .sof erzeugt: $sof" }
    "  {0}  {1:N0} Byte" -f (Split-Path $sof -Leaf), (Get-Item $sof).Length

    if (-not $NoJic -and $meta.ReleaseArtifact -eq 'jic') {
        & "$QuartusBin\quartus_cpf.exe" -c "$Project.cof"
        if ($LASTEXITCODE -ne 0) { throw "quartus_cpf ist fehlgeschlagen ($LASTEXITCODE)" }
        $jic = Join-Path $VarDir "output_files\$Project.jic"
        if (-not (Test-Path $jic)) { throw "keine .jic erzeugt: $jic" }
        # Geraetetypische Groesse (EPCS16): Cyclone IV 2.097.375 B, Cyclone 10 2.097.377 B.
        "  {0}  {1:N0} Byte" -f (Split-Path $jic -Leaf), (Get-Item $jic).Length
    }
}
finally { Pop-Location }

Write-Host "fertig." -ForegroundColor Green
