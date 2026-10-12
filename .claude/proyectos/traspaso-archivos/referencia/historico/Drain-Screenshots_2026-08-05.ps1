<#
  Drain-Screenshots.ps1  (v2)
  Vacia la carpeta Screenshots del movil por bloques (via Move-Screenshots.ps1),
  del mas viejo al mas nuevo, con robustez:
    - Reintenta hasta 3 veces si un bloque no progresa.
    - Si sigue sin progresar, REDUCE el tamano de bloque (adaptativo) y reintenta.
    - Si tras reducir hasta el minimo sigue fallando -> ALERTA (cambiar cable) y sale.
    - Si el movil se desconecta, espera y reintenta; si no vuelve -> ALERTA y sale.
    - Tope de datos por sesion (-MaxGB) con corte preciso.
    - Limite por mes (-UntilYM AAAA-MM) o por anio (-YearMax AAAA).
    - Escribe % de avance en _index\PROGRESO.txt (para ver en pantalla) y drain.log.

  Uso tipico (primeros 2 meses de 2024, bloques de 500, tope 10 GB):
    .\Drain-Screenshots.ps1 -BatchSize 500 -UntilYM 2024-02 -MaxGB 10
#>
[CmdletBinding()]
param(
  [int]$BatchSize   = 1000,
  [int]$YearMax     = 9999,
  [string]$UntilYM  = '',
  [double]$MaxGB    = 0,     # tope de datos por sesion (0 = sin limite)
  [int]$MinBatch    = 100,   # bloque minimo al reducir
  [int]$MaxWaitMin  = 30,    # espera max por reconexion
  [int]$MaxRetry    = 3      # reintentos sin progreso antes de reducir/abortar
)

$tools  = $PSScriptRoot
$mover  = Join-Path $tools 'Move-Screenshots.ps1'
$adb    = Join-Path $tools 'platform-tools\adb.exe'
$base   = 'C:\Users\D746288\Desktop\0.Escritorio\BK2\ScreenShots'
$idxDir = Join-Path $base '_index'
$index  = Join-Path $idxDir 'index.csv'
$doneLog= Join-Path $idxDir 'moved_ok.log'
$drain  = Join-Path $idxDir 'drain.log'
$prog   = Join-Path $idxDir 'PROGRESO.txt'
$maxBytes = [long]($MaxGB * 1GB)

function Log($m) {
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = "$ts  $m"
  Write-Host $line
  Add-Content -Path $drain -Value $line
}
function Get-DoneSet {
  $h = @{}
  if (Test-Path $doneLog) { foreach ($l in Get-Content $doneLog) { if ($l) { $h[$l] = $true } } }
  return $h
}
function Test-Device {
  $out = & $adb devices 2>$null
  return [bool]($out | Select-String '\bdevice$')
}
function Write-Progress2($pct, $moved, $total, $gb, $etaMin, $extra) {
  $scope = if ($UntilYM) { "hasta $UntilYM" } else { "anio<=$YearMax" }
  $ts = Get-Date -Format 'HH:mm:ss'
  $line = "[{0}] {1}: {2}%  {3}/{4}  {5:N2} GB  ETA ~{6} min  {7}" -f $ts,$scope,$pct,$moved,$total,$gb,$etaMin,$extra
  Set-Content -Path $prog -Value $line -Encoding UTF8
}

# Conjunto objetivo segun filtro
$rows = Import-Csv $index | Where-Object {
  if ($UntilYM) { return ($_.ym -le $UntilYM) }
  return ([int]$_.ym.Substring(0,4) -le $YearMax)
}
$targetNames = $rows.name
$sizeOf = @{}
foreach ($r in $rows) { $sizeOf[$r.name] = [long]$r.size }
$targetTotal = $targetNames.Count

$scopeLabel = if ($UntilYM) { "UntilYM=$UntilYM" } else { "YearMax=$YearMax" }
$capLabel   = if ($maxBytes -gt 0) { "MaxGB=$MaxGB" } else { "sin tope" }
Log "===== DRAIN START ($scopeLabel, batch=$BatchSize, $capLabel, objetivo=$targetTotal) ====="

$doneStart = Get-DoneSet
$curBatch = $BatchSize
$retries  = 0
$swAll = [System.Diagnostics.Stopwatch]::StartNew()

while ($true) {
  $done = Get-DoneSet
  # pendientes y bytes de esta sesion
  $pending = 0; $sessBytes = 0L; $nextSize = 0L; $foundNext = $false
  foreach ($n in $targetNames) {
    if ($done.ContainsKey($n)) {
      if (-not $doneStart.ContainsKey($n)) { $sessBytes += $sizeOf[$n] }
    } else {
      $pending++
      if (-not $foundNext) { $nextSize = $sizeOf[$n]; $foundNext = $true }
    }
  }
  $moved = $targetTotal - $pending
  $mins = [math]::Max($swAll.Elapsed.TotalMinutes, 0.01)
  $rate = [math]::Round($sessBytes / 1MB / $mins, 0)
  $pct  = if ($targetTotal) { [math]::Round(100*$moved/$targetTotal,1) } else { 100 }
  $etaMin = if ($rate -gt 0 -and $nextSize -gt 0) { [math]::Round(($pending*($nextSize/1MB))/$rate,0) } else { 0 }
  Write-Progress2 $pct $moved $targetTotal ($sessBytes/1GB) $etaMin ""

  if ($pending -le 0) {
    Log "COMPLETADO ($scopeLabel): $moved/$targetTotal movidos."
    Write-Progress2 100 $moved $targetTotal ($sessBytes/1GB) 0 "COMPLETADO"
    break
  }
  # Tope de datos por sesion
  if ($maxBytes -gt 0 -and ($maxBytes - $sessBytes) -lt $nextSize) {
    Log ("TOPE DE {0} GB alcanzado esta sesion ({1:N2} GB movidos). Relanza para continuar." -f $MaxGB, ($sessBytes/1GB))
    Write-Progress2 $pct $moved $targetTotal ($sessBytes/1GB) 0 "TOPE_GB_ALCANZADO"
    break
  }

  # Esperar dispositivo
  if (-not (Test-Device)) {
    Log "Dispositivo no disponible. Esperando (max $MaxWaitMin min)..."
    $waited = 0
    while (-not (Test-Device)) {
      Start-Sleep -Seconds 20; $waited += 20
      if ($waited -ge $MaxWaitMin*60) {
        Log "ALERTA: sin dispositivo tras $MaxWaitMin min. DESCONECTA Y RECONECTA EL CABLE."
        Write-Progress2 $pct $moved $targetTotal ($sessBytes/1GB) 0 "ALERTA_RECONECTAR_CABLE"
        exit 2
      }
    }
    Log "Dispositivo reconectado. Reanudando."
    & $adb start-server *> $null
  }

  Log "Bloque=$curBatch  pendientes=$pending  ($moved/$targetTotal, $pct%, sesion $([math]::Round($sessBytes/1GB,2)) GB)"
  $remain = if ($maxBytes -gt 0) { $maxBytes - $sessBytes } else { 0 }
  try {
    & $mover -BatchSize $curBatch -UntilYM $UntilYM -YearMax $YearMax -MaxBytes $remain *>> $drain
  } catch {
    Log "WARN: excepcion en bloque: $($_.Exception.Message)"
  }

  # Progreso tras el bloque
  $done2 = Get-DoneSet
  $pending2 = 0
  foreach ($n in $targetNames) { if (-not $done2.ContainsKey($n)) { $pending2++ } }
  $gained = $pending - $pending2

  if ($gained -gt 0) {
    $retries = 0
  } else {
    $retries++
    Log "Sin progreso (reintento $retries/$MaxRetry) con bloque=$curBatch. Progreso guardado en moved_ok.log."
    if ($retries -ge $MaxRetry) {
      if ($curBatch -gt $MinBatch) {
        $curBatch = [math]::Max($MinBatch, [int]($curBatch/2))
        $retries = 0
        Log "ALTERNATIVA: reduzco tamano de bloque a $curBatch y reintento."
      } else {
        Log "ALERTA: sin progreso tras $MaxRetry reintentos con bloque minimo ($MinBatch). REQUIERE ACCION: cambia/reconecta el cable (prueba el USB4 C-C)."
        Write-Progress2 $pct $moved $targetTotal ($sessBytes/1GB) 0 "ALERTA_CAMBIAR_CABLE"
        exit 3
      }
    }
    Start-Sleep -Seconds 12
  }
}

$swAll.Stop()
Log ("===== DRAIN FIN ($scopeLabel)  |  duracion {0:hh\:mm\:ss} =====" -f $swAll.Elapsed)
