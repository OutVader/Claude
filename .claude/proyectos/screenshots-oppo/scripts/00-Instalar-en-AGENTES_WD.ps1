<#
.SYNOPSIS  Crea el proyecto en AGENTES_WD\.claude\Proyectos\Screenshots-OPPO y recupera lo que ya se hizo.
.DESCRIPTION
  - Copia este proyecto (README, CONTEXT, bitácora y scripts) a la carpeta destino.
  - Copia (no mueve) la memoria original project_screenshots_drain.md a docs\memoria-original.md.
  - Busca referencias (screenshot / adb / oppo) en TRACASA\SCRIPTS, en la memoria y en el historial
    de sesiones de Claude, y las lista en docs\referencias.md. Los scripts .ps1/.bat/.md que encuentre
    en SCRIPTS se copian a docs\heredado\ (los originales no se tocan).
  Sin -Aplicar solo muestra lo que haría.
.EXAMPLE   .\00-Instalar-en-AGENTES_WD.ps1
.EXAMPLE   .\00-Instalar-en-AGENTES_WD.ps1 -Aplicar
#>
[CmdletBinding()]
param([switch]$Aplicar)
$ErrorActionPreference = 'Stop'

$Raiz    = 'C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD'
$Dest    = Join-Path $Raiz '.claude\Proyectos\Screenshots-OPPO'
$Scripts = 'C:\Users\D746288\Desktop\0.Escritorio\TRABAJO\TRACASA\SCRIPTS'
$Proyectos = "$env:USERPROFILE\.claude\projects"
$Memoria = Join-Path $Proyectos 'C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md'
$Patron  = 'screenshot|\badb\b|oppo'
$Origen  = Split-Path $PSScriptRoot -Parent

function Paso([string]$t) { Write-Host $(if ($Aplicar) { "  $t" } else { "  [SIM] $t" }) -ForegroundColor $(if ($Aplicar) { 'Green' } else { 'Yellow' }) }

Write-Host "=== Proyecto -> $Dest ===" -ForegroundColor Cyan
Paso "copiar $Origen -> $Dest"
if ($Aplicar) {
    New-Item -ItemType Directory -Path (Join-Path $Dest 'docs\heredado') -Force | Out-Null
    foreach ($e in Get-ChildItem -LiteralPath $Origen -Force) { Copy-Item -LiteralPath $e.FullName -Destination $Dest -Recurse -Force }
}

if (Test-Path -LiteralPath $Memoria) {
    Paso "copiar memoria original -> docs\memoria-original.md"
    if ($Aplicar) { Copy-Item -LiteralPath $Memoria -Destination (Join-Path $Dest 'docs\memoria-original.md') -Force }
    Write-Host "`n--- Memoria original ---" -ForegroundColor Cyan
    Get-Content -LiteralPath $Memoria -Encoding UTF8
} else { Write-Warning "No encuentro $Memoria" }

Write-Host "`n=== Buscando referencias ($Patron) ===" -ForegroundColor Cyan
$refs = New-Object System.Collections.Generic.List[string]
$refs.Add("# Referencias encontradas — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"); $refs.Add('')

# 1) SCRIPTS: nombre o contenido (texto) que coincida
if (Test-Path -LiteralPath $Scripts) {
    $refs.Add('## TRACASA\SCRIPTS')
    $cand = Get-ChildItem -LiteralPath $Scripts -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(\.git|node_modules|\.obsidian)\\' -and $_.Extension -in '.ps1', '.psm1', '.bat', '.cmd', '.md', '.txt', '.py', '.sh' }
    foreach ($f in $cand) {
        $hit = $f.Name -match $Patron
        $lineas = @(Select-String -LiteralPath $f.FullName -Pattern $Patron -AllMatches -ErrorAction SilentlyContinue | Select-Object -First 3)
        if (-not $hit -and -not $lineas.Count) { continue }
        $refs.Add("- ``$($f.FullName)``")
        foreach ($l in $lineas) { $refs.Add("  - L$($l.LineNumber): ``$($l.Line.Trim().Substring(0, [math]::Min(140, $l.Line.Trim().Length)))``") }
        Paso "heredar $($f.Name) -> docs\heredado\"
        if ($Aplicar) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $Dest 'docs\heredado') -Force }
    }
}

# 2) Historial de sesiones de Claude: qué sesiones hablaron de capturas (solo nombre de archivo y nº de coincidencias)
if (Test-Path -LiteralPath $Proyectos) {
    $refs.Add(''); $refs.Add('## Sesiones de Claude Code (~\.claude\projects\*\*.jsonl)')
    foreach ($j in Get-ChildItem -LiteralPath $Proyectos -Recurse -File -Filter *.jsonl -ErrorAction SilentlyContinue) {
        $n = @(Select-String -LiteralPath $j.FullName -Pattern 'screenshots?' -ErrorAction SilentlyContinue).Count
        if ($n) { $refs.Add("- ``$($j.FullName.Substring($Proyectos.Length + 1))`` · $n líneas · $($j.LastWriteTime.ToString('yyyy-MM-dd'))") }
    }
    $refs.Add(''); $refs.Add('Para reabrir una sesión: `claude --resume` (desde la carpeta de ese proyecto) y elegirla por fecha.')
}

$refs | ForEach-Object { Write-Host $_ }
Paso "guardar docs\referencias.md"
if ($Aplicar) { Set-Content -LiteralPath (Join-Path $Dest 'docs\referencias.md') -Value $refs -Encoding UTF8 }
if (-not $Aplicar) { Write-Host "`nNada escrito. Repite con -Aplicar." -ForegroundColor Yellow }
