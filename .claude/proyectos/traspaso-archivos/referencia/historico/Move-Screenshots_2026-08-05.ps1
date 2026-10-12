<#
  Move-Screenshots.ps1  (v2)
  Mueve capturas del movil (OPPO Find X5, via ADB) al PC por bloques,
  empezando por las MAS VIEJAS. Flujo seguro: PULL -> VERIFICAR tamano -> BORRAR del movil.
  Organiza en destino por Anio\Anio-Mes. Reanudable (registro moved_ok.log).

  Parametros:
    -BatchSize N     numero de archivos a mover en esta llamada
    -YearMax AAAA    solo archivos de ese anio o anteriores (p.ej. 2023)
    -UntilYM AAAA-MM solo archivos de ese mes o anteriores (mas fino que YearMax)
    -MaxBytes N      tope de bytes a mover en esta llamada (0 = sin limite)
    -DryRun          simula, no copia ni borra

  Uso:
    .\Move-Screenshots.ps1 -BatchSize 500 -UntilYM 2024-02
#>
[CmdletBinding()]
param(
  [int]$BatchSize  = 100,
  [int]$YearMax    = 9999,
  [string]$UntilYM = '',
  [long]$MaxBytes  = 0,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$adb    = Join-Path $PSScriptRoot 'platform-tools\adb.exe'
$base   = 'C:\Users\D746288\Desktop\0.Escritorio\BK2\ScreenShots'
$idxDir = Join-Path $base '_index'
$index  = Join-Path $idxDir 'index.csv'
$doneLog= Join-Path $idxDir 'moved_ok.log'
$errLog = Join-Path $idxDir 'errors.log'
$remote = '/sdcard/Pictures/Screenshots'

if (-not (Test-Path $adb))   { throw "No encuentro adb en $adb" }
if (-not (Test-Path $index)) { throw "No encuentro el indice $index" }

$dev = & $adb devices | Select-String 'device$'
if (-not $dev) { throw "No hay dispositivo ADB conectado/autorizado. Ejecuta: adb devices" }

# Set de ya-procesados
$done = @{}
if (Test-Path $doneLog) { foreach ($l in Get-Content $doneLog) { if ($l) { $done[$l] = $true } } }

# Filtro por mes (UntilYM) o anio (YearMax)
$all = Import-Csv $index
$pending = $all | Where-Object {
  if ($done.ContainsKey($_.name)) { return $false }
  if ($UntilYM) { return ($_.ym -le $UntilYM) }
  return ([int]$_.ym.Substring(0,4) -le $YearMax)
}
$batch = $pending | Select-Object -First $BatchSize

if ($batch.Count -eq 0) { Write-Host "Nada pendiente en el rango pedido."; return }

Write-Host ("Bloque: {0} archivos  |  Rango {1} -> {2}  |  DryRun={3}" -f `
  $batch.Count, $batch[0].fecha, $batch[-1].fecha, [bool]$DryRun) -ForegroundColor Cyan

$ok = 0; $fail = 0; $bytes = 0L
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($f in $batch) {
  # Tope de datos: cortar antes de superar MaxBytes
  if ($MaxBytes -gt 0 -and ($bytes + [long]$f.size) -gt $MaxBytes) {
    Write-Host ("  Tope de datos alcanzado ({0:N1} MB). Fin del bloque." -f ($bytes/1MB)) -ForegroundColor Yellow
    break
  }
  $year    = $f.ym.Substring(0,4)
  $destDir = Join-Path (Join-Path $base $year) $f.ym
  $destFile= Join-Path $destDir $f.name
  $srcPath = "$remote/$($f.name)"

  if ($DryRun) { Write-Host "  [DRY] $($f.fecha)  ->  $year\$($f.ym)\  $($f.name)"; $ok++; continue }

  New-Item -ItemType Directory -Force $destDir | Out-Null

  # 1) PULL (preserva timestamp con -a)
  & $adb pull -a "$srcPath" "$destFile" *> $null

  # 2) VERIFICAR tamano
  if (Test-Path $destFile) {
    $localSize = (Get-Item $destFile).Length
    if ($localSize -gt 0 -and $localSize -eq [long]$f.size) {
      # 3) BORRAR del movil (nombre escapado para sh)
      $q = $f.name -replace "'", "'\''"
      & $adb shell "rm -f '$remote/$q'" *> $null
      Add-Content -Path $doneLog -Value $f.name
      $ok++; $bytes += $localSize
    } else {
      Add-Content -Path $errLog -Value ("{0}|SIZE_MISMATCH|local={1}|idx={2}|{3}" -f (Get-Date -Format s), $localSize, $f.size, $f.name)
      Remove-Item $destFile -Force
      $fail++
    }
  } else {
    Add-Content -Path $errLog -Value ("{0}|PULL_FAILED|{1}" -f (Get-Date -Format s), $f.name)
    $fail++
  }
}
$sw.Stop()

# Resumen
$movedTotal = ($done.Count + $ok)
$remaining  = $all.Count - $movedTotal
Write-Host ""
Write-Host ("OK: {0}  Fallos: {1}  |  {2:N2} MB  |  {3:N0}s" -f $ok, $fail, ($bytes/1MB), $sw.Elapsed.TotalSeconds) -ForegroundColor Green
Write-Host ("Progreso total: {0} / {1} movidos  |  Quedan: {2}" -f $movedTotal, $all.Count, $remaining) -ForegroundColor Yellow

# ESTADO.md (resumen global que se actualiza)
$estado = Join-Path $idxDir 'ESTADO.md'
$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$pct = if ($all.Count) { [math]::Round(100*$movedTotal/$all.Count,1) } else { 0 }
@"
# Estado de movido de Screenshots

_Actualizado: $now_

- **Total en indice:** $($all.Count)
- **Movidos:** $movedTotal ($pct %)
- **Pendientes:** $remaining
- **Ultimo bloque:** $ok OK / $fail fallos ($([math]::Round($bytes/1MB,1)) MB)

Origen: /sdcard/Pictures/Screenshots (movil OPPO Find X5)
Destino: $base\<Anio>\<Anio-Mes>\
"@ | Set-Content -Path $estado -Encoding UTF8
