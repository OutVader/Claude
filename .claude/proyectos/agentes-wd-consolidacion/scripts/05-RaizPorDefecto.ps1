<#
.SYNOPSIS  Fase 4 — AGENTES_WD como raíz por defecto de Claude Code + migración de la memoria.
.DESCRIPTION
  Claude Code guarda la memoria POR CARPETA DE TRABAJO en ~\.claude\projects\<ruta-codificada>\memory.
  Tu memoria actual vive en la clave de TRACASA\SCRIPTS; si abres Claude en AGENTES_WD sin migrarla,
  "desaparece". Este script:
    1. Copia la memoria de la clave antigua a la de AGENTES_WD (sin sobrescribir) y fusiona MEMORY.md.
    2. Añade la memoria "raíz por defecto" (project_raiz_agentes_wd.md) y su línea en MEMORY.md.
    3. Añade la regla en ~\.claude\CLAUDE.md (memoria de usuario, se carga en todas las sesiones).
    4. Crea la función `cc` en tu perfil de PowerShell (abre claude ya situado en AGENTES_WD).
    5. (opcional, -Acceso) Acceso directo "Claude AGENTES_WD" en el Escritorio.
  Sin -Aplicar: solo muestra lo que haría. Con -Aplicar: copia previa de cada archivo que toca.
.EXAMPLE   .\05-RaizPorDefecto.ps1
.EXAMPLE   .\05-RaizPorDefecto.ps1 -Aplicar -Acceso
#>
[CmdletBinding()]
param([switch]$Aplicar, [switch]$Acceso)
. "$PSScriptRoot\_comun.ps1"

$proyectos = "$env:USERPROFILE\.claude\projects"
$claveVieja = ConvertTo-ClaveProyecto $Fuentes['SCRIPTS'].Origen
$claveNueva = ConvertTo-ClaveProyecto $Raiz
# Si Claude ya creó la carpeta con otra variante, se usa la existente
$existente = Get-ChildItem -LiteralPath $proyectos -Directory -ErrorAction SilentlyContinue | Where-Object Name -eq $claveNueva
$memVieja = Join-Path $proyectos "$claveVieja\memory"
$memNueva = Join-Path $proyectos "$claveNueva\memory"
$hoy = Get-Date -Format 'yyyy-MM-dd'

function Backup-Archivo([string]$Ruta) {
    if (Test-Path -LiteralPath $Ruta) {
        $d = Join-Path $Backups ('raiz\' + (Split-Path $Ruta -Leaf) + '.' + (Get-Date -Format 'HHmmss') + '.bak')
        New-Carpeta (Split-Path $d -Parent); Copy-Item -LiteralPath $Ruta -Destination $d -Force
    }
}
function Add-SiFalta([string]$Ruta, [string]$Marca, [string]$Bloque) {
    $actual = if (Test-Path -LiteralPath $Ruta) { Get-Content -LiteralPath $Ruta -Raw -Encoding UTF8 } else { '' }
    if ($actual -and $actual.Contains($Marca)) { Write-Host "  ya presente en $Ruta" -ForegroundColor DarkGray; return }
    if (-not $Aplicar) { Write-Host "  [SIM] añadiría a ${Ruta}:`n$Bloque" -ForegroundColor Yellow; return }
    Backup-Archivo $Ruta; New-Carpeta (Split-Path $Ruta -Parent)
    Add-Content -LiteralPath $Ruta -Value "`r`n$Bloque" -Encoding UTF8
    Write-Host "  añadido a $Ruta" -ForegroundColor Green
}

Write-Fase "1. Memoria  $claveVieja  ->  $claveNueva  (carpeta nueva existe: $([bool]$existente))"
if (-not (Test-Path -LiteralPath $memVieja)) { Write-Warning "No hay memoria en $memVieja" }
else {
    $rcArgs = @($memVieja, $memNueva, '*.md', '/XC', '/XN', '/XO', '/XF', 'MEMORY.md', '/R:1', '/W:1', '/NP')
    if (-not $Aplicar) { $rcArgs += '/L' }
    robocopy @rcArgs | Select-Object -Last 8
    $lineasViejas = @(Get-Content -LiteralPath (Join-Path $memVieja 'MEMORY.md') -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*-\s*\[' })
    $idxNuevo = Join-Path $memNueva 'MEMORY.md'
    $lineasNuevas = @(Get-Content -LiteralPath $idxNuevo -Encoding UTF8 -ErrorAction SilentlyContinue)
    $faltan = @($lineasViejas | Where-Object { $_ -notin $lineasNuevas })
    Write-Host "  MEMORY.md: $($faltan.Count) entradas por fusionar"
    if ($Aplicar -and $faltan.Count) { Backup-Archivo $idxNuevo; New-Carpeta $memNueva; Add-Content -LiteralPath $idxNuevo -Value $faltan -Encoding UTF8 }
}

Write-Fase '2. Memoria "raíz por defecto"'
$memRaiz = Join-Path $memNueva 'project_raiz_agentes_wd.md'
$contenido = @"
---
name: project-raiz-agentes-wd
description: "Raíz por defecto de trabajo: AGENTES_WD (Claude en .claude, Codex en .codex)"
metadata:
  type: project
  modified: $hoy
---

Raíz por defecto de trabajo de Iñaki: ``$Raiz``.
- Carpeta de Claude: ``$Raiz\.claude`` (Proyectos\, _indices\, _home\ = copia ordenada de ~\.claude).
- Carpeta de Codex: ``$Raiz\.codex`` (_home\ = copia de ~\.codex).
- TRACASA\SCRIPTS consolidado en ``$($Fuentes['SCRIPTS'].Destino)``.
- Índices: ``$Indices\INDICE-GENERAL.md``. Leerlos antes de buscar archivos.
**Why:** consolidación $hoy; un único hogar para agentes, proyectos e índices.
**How to apply:** abrir sesiones en esta raíz (función ``cc``); rutas nuevas en documentación; no volver a la ruta antigua.
"@
if (Test-Path -LiteralPath $memRaiz) { Write-Host "  ya existe $memRaiz" -ForegroundColor DarkGray }
elseif ($Aplicar) { New-Carpeta $memNueva; Set-Content -LiteralPath $memRaiz -Value $contenido -Encoding UTF8; Write-Host "  creado $memRaiz" -ForegroundColor Green }
else { Write-Host "  [SIM] crearía $memRaiz" -ForegroundColor Yellow }
Add-SiFalta (Join-Path $memNueva 'MEMORY.md') 'project_raiz_agentes_wd.md' `
    '- [Raíz por defecto AGENTES_WD](project_raiz_agentes_wd.md) — trabajar siempre en AGENTES_WD; índices en .claude\_indices'

Write-Fase '3. Memoria de usuario (~\.claude\CLAUDE.md)'
Add-SiFalta "$env:USERPROFILE\.claude\CLAUDE.md" '## Raíz por defecto (AGENTES_WD)' @"
## Raíz por defecto (AGENTES_WD)
- Raíz de trabajo por defecto: ``$Raiz``. Si la sesión se abre en otra carpeta, avisar y proponer trabajar allí.
- Claude: ``$Raiz\.claude`` · Codex: ``$Raiz\.codex`` · Índices: ``$Indices``.
- Antes de buscar archivos, leer ``$Indices\INDICE-GENERAL.md``.
"@

Write-Fase '4. Función cc en el perfil de PowerShell'
Add-SiFalta $PROFILE '# AGENTES_WD: cc' @"
# AGENTES_WD: cc  -> abre Claude Code situado en la raíz por defecto
function cc { Set-Location -LiteralPath '$Raiz'; claude @args }
"@

if ($Acceso) {
    Write-Fase '5. Acceso directo en el Escritorio'
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Claude AGENTES_WD.lnk'
    if (-not $Aplicar) { Write-Host "  [SIM] crearía $lnk" -ForegroundColor Yellow }
    else {
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $sc.TargetPath = 'powershell.exe'
        $sc.Arguments = '-NoExit -Command claude'
        $sc.WorkingDirectory = $Raiz
        $sc.Save(); Write-Host "  creado $lnk" -ForegroundColor Green
    }
}

if (-not $Aplicar) { Write-Host "`n[SIMULACIÓN] Nada se ha escrito. Repite con -Aplicar." -ForegroundColor Yellow }
else { Write-Host "`nHecho. Abre una consola nueva y escribe:  cc   (y en Claude: /memory para comprobarlo)" -ForegroundColor Green }
