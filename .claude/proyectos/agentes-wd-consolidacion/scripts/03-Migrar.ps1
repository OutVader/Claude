<#
.SYNOPSIS  Fase 2 — COPIA ordenada de las fuentes a AGENTES_WD (robocopy).
.DESCRIPTION
  Sin -Aplicar: robocopy /L (simulación, no escribe nada) y deja el log en _indices.
  Con -Aplicar: copia real. NUNCA mueve ni borra el origen (sin /MOV ni /MIR).
  Exclusiones: credenciales (no se tocan), junctions (/XJ) y cachés regenerables
  (las cachés solo en CLAUDE_HOME/CODEX_HOME; en SCRIPTS solo node_modules).
  Requiere haber ejecutado antes 01-Indexar.ps1 (los índices se guardan antes de copiar).
.PARAMETER Solo       Limita a uno o varios alias: CLAUDE_HOME, CODEX_HOME, SCRIPTS.
.PARAMETER SinHistorial  No copia el historial de sesiones (*.jsonl de projects/ y sessions/).
.EXAMPLE   .\03-Migrar.ps1                       # simulación de todo
.EXAMPLE   .\03-Migrar.ps1 -Solo SCRIPTS -Aplicar
#>
[CmdletBinding()]
param([switch]$Aplicar, [string[]]$Solo, [switch]$SinHistorial)
. "$PSScriptRoot\_comun.ps1"

if (-not (Test-Path -LiteralPath (Join-Path $Indices 'INDICE-GENERAL.md'))) {
    throw "Falta el índice. Ejecuta primero .\01-Indexar.ps1 (regla: índices antes de mover nada)."
}

$xf = @('.credentials.json', 'auth.json', '*.key', '*.pem', '*.pfx', '.env', '.env.*', '*token*', '*secret*', 'Thumbs.db', 'desktop.ini')
$xdComun = @('node_modules', '.cache', 'cache', 'statsig', 'shell-snapshots', 'tmp', 'temp')
$log = Join-Path $Indices ("robocopy-" + (Get-Date -Format 'yyyyMMdd-HHmm') + $(if ($Aplicar) { '' } else { '-SIMULACION' }) + '.log')

foreach ($alias in $Fuentes.Keys) {
    if ($Solo -and $alias -notin $Solo) { continue }
    $f = $Fuentes[$alias]
    if (-not (Test-Path -LiteralPath $f.Origen)) { Write-Warning "No existe: $($f.Origen)"; continue }
    Write-Fase "$alias : $($f.Origen)  ->  $($f.Destino)"

    $xd = if ($alias -eq 'SCRIPTS') { @('node_modules') } else { @($xdComun) }
    $xfAlias = @($xf)
    if ($SinHistorial -and $alias -ne 'SCRIPTS') { $xfAlias += '*.jsonl'; $xd += 'sessions' }

    $rcArgs = @($f.Origen, $f.Destino, '/E', '/XJ', '/COPY:DAT', '/DCOPY:DAT', '/R:1', '/W:1',
              '/NP', '/TEE', "/LOG+:$log", '/XF') + $xfAlias + @('/XD') + $xd
    if (-not $Aplicar) { $rcArgs += '/L' }
    if ($Aplicar) { New-Carpeta $f.Destino }

    robocopy @rcArgs | Select-Object -Last 12
    $rc = $LASTEXITCODE
    if ($rc -ge 8) { Write-Warning "robocopy $alias terminó con código $rc (fallo). Revisa $log"; continue }
    Write-Host "  robocopy código $rc (OK < 8)" -ForegroundColor Green
}

if (-not $Aplicar) { Write-Host "`n[SIMULACIÓN] Nada se ha escrito. Revisa $log y repite con -Aplicar." -ForegroundColor Yellow }
else { Write-Host "`nCopia hecha. Los ORÍGENES siguen intactos; se retiran solo en la fase 5, con tu OK." -ForegroundColor Green }
