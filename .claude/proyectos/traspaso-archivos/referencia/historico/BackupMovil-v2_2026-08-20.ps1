<#
  BackupMovil-v2.ps1
  ------------------------------------------------------------------------------
  Copia + verifica + borra por bloques CUALQUIER carpeta del movil (via ADB) a un
  destino del PC/disco, de la mas VIEJA a la mas nueva, organizando por Anio\Anio-Mes.
  Flujo seguro: PULL -> verificar tamano -> BORRAR del movil.  Reanudable.

  INTERACTIVO: si lo lanzas sin parametros, te PREGUNTA (con valores por defecto):
     - que carpeta del movil quieres respaldar
     - a que carpeta destino
     - cuantos movimientos por ciclo
     - tope de GB por sesion

  INDICE / LEDGER DUPLICADO (para reanudar aunque cambie la ruta):
     - En el DISCO, junto a las fotos:  <destino>\_index\<clave>.index.csv  y  <clave>.moved_ok.log
     - En el MOVIL (fichero NO temporal): /sdcard/MobileBackup/<clave>.index.csv  y  <clave>.moved_ok.log
     Al arrancar se UNEN ambos ledgers, asi que sabe donde se quedo venga de donde venga.

  Parametros (opcionales, para modo desatendido):
     -SourceFolder '/sdcard/Pictures/Screenshots'
     -DestFolder   'D:\GN\BK2\ScreenShots'
     -PerCycle 500
     -MaxGB 0                 (0 = sin tope)
     -AdbPath '...adb.exe'    ('' = autodetectar uno que ejecute)
     -NonInteractive          (usa defaults, no pregunta)
     -DryRun                  (SIMULA: no copia ni borra; procesa 1 ciclo y para)

  Ejemplos:
     .\BackupMovil-v2.ps1
     .\BackupMovil-v2.ps1 -NonInteractive -PerCycle 500
     .\BackupMovil-v2.ps1 -SourceFolder /sdcard/DCIM/Camera -DestFolder D:\GN\BK2\Camera -PerCycle 500
#>
[CmdletBinding()]
param(
  [string]$SourceFolder = '',
  [string]$DestFolder   = '',
  [int]$PerCycle        = 0,
  [double]$MaxGB        = -1,
  [string]$AdbPath      = '',
  [string]$UntilYM      = '',   # limitar hasta ese mes incluido (AAAA-MM). Vacio = toda la carpeta
  [string]$FromYM       = '',   # limitar DESDE ese mes incluido (AAAA-MM). Vacio = desde el principio
  [int]$MaxFiles        = 0,    # tope de archivos a mover esta sesion (0 = sin limite). Util para pruebas
  [int]$MinBatch        = 100,
  [int]$MaxWaitMin      = 30,
  [int]$MaxRetry        = 3,
  [switch]$NonInteractive,
  [switch]$DryRun,
  [switch]$CopyOnly,    # copia y verifica pero NO borra del movil (modo "solo copiar")
  [switch]$FreeCopied,  # borra del movil los archivos YA copiados+verificados en disco (libera espacio)
  [double]$MinFreeGB = 1.0  # margen minimo de espacio libre en destino; por debajo corta limpio
)

# 'Continue' (no 'Stop'): evita que la salida de progreso de adb (por stderr) se trate
# como error terminante al lanzarse con doble clic en Windows PowerShell 5.1.
# La seguridad NO depende de esto: solo se borra del movil tras verificar tamano en disco.
$ErrorActionPreference = 'Continue'
if (Get-Variable PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) { $PSNativeCommandUseErrorActionPreference = $false }

# ===================== VALORES POR DEFECTO (rutas actuales) =====================
$DEF_DESTBASE     = 'D:\GN\BK2'
$DEF_SOURCE       = '/sdcard/Pictures/Screenshots'
$DEF_DESTSUB      = 'ScreenShots'
$DEF_PERCYCLE     = 500
$PHONE_LEDGER_DIR = '/sdcard/MobileBackup'   # carpeta NO temporal en el movil
$ADB_CANDIDATES   = @(
  'D:\GN\BK2\_tools\platform-tools\adb.exe',
  'C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\platform-tools\adb.exe'
)
# ===============================================================================

function Say($m,$c='Gray'){ Write-Host $m -ForegroundColor $c }

function Resolve-Adb($preferred) {
  $cands = @()
  if ($preferred) { $cands += $preferred }
  $cands += $ADB_CANDIDATES
  $cands += (Join-Path $PSScriptRoot 'platform-tools\adb.exe')
  foreach ($c in $cands) {
    if ($c -and (Test-Path $c)) {
      try { & $c version *> $null; if ($LASTEXITCODE -eq 0) { return $c } } catch { }
    }
  }
  # Ultimo recurso: copiar platform-tools a ruta local ejecutable (por si D: bloquea exec)
  $local = Join-Path $env:LOCALAPPDATA 'adb-run'
  foreach ($c in $cands) {
    $srcDir = Split-Path $c -ErrorAction SilentlyContinue
    if ($srcDir -and (Test-Path $srcDir)) {
      try {
        New-Item -ItemType Directory -Force $local | Out-Null
        Copy-Item (Join-Path $srcDir '*') $local -Recurse -Force -ErrorAction SilentlyContinue
        $la = Join-Path $local 'adb.exe'
        if (Test-Path $la) { & $la version *> $null; if ($LASTEXITCODE -eq 0) { Say "adb copiado a ruta local ejecutable: $la" 'Yellow'; return $la } }
      } catch { }
    }
  }
  throw "No pude EJECUTAR adb desde ninguna ruta. Revisa permisos o pasa -AdbPath."
}

function Prompt-Default($label,$default){
  if ($NonInteractive) { return $default }
  $v = Read-Host "  $label [$default]"
  if ([string]::IsNullOrWhiteSpace($v)) { return $default }
  return $v
}

function Test-Device($adb){
  $out = & $adb devices 2>$null
  return [bool]($out | Select-String '\bdevice$')
}

function Build-Index($adb,$src,$idxDir,$key,$indexCsv){
  Say "Generando indice de '$src' (una vez)..." 'Yellow'
  $raw = Join-Path $idxDir "$key.raw_listing.txt"
  & $adb shell "find '$src' -maxdepth 1 -type f -printf '%T@|%s|%f\n'" | Out-File -FilePath $raw -Encoding UTF8
  $epoch0 = [datetime]'1970-01-01T00:00:00Z'
  $rows = foreach ($l in Get-Content $raw) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    $p = $l -split '\|', 3
    if ($p.Count -lt 3) { continue }
    $sec = [double]::Parse($p[0], [System.Globalization.CultureInfo]::InvariantCulture)
    $dt  = $epoch0.AddSeconds($sec).ToLocalTime()
    [PSCustomObject]@{ dt=$dt; size=[long]$p[1]; name=$p[2] }
  }
  $sorted = $rows | Sort-Object dt
  $rank = 0
  $sorted | ForEach-Object {
    $rank++
    [PSCustomObject]@{ rank=$rank; fecha=$_.dt.ToString('yyyy-MM-dd HH:mm:ss'); ym=$_.dt.ToString('yyyy-MM'); size=$_.size; name=$_.name }
  } | Export-Csv -Path $indexCsv -NoTypeInformation -Encoding UTF8
  Say ("Indice: {0} archivos" -f $sorted.Count) 'Green'
}

# ============================== INICIO ==============================
$SCRIPT_VERSION = '3.0 (2026-08-20)'
Say "===== BackupMovil-v2  v$SCRIPT_VERSION =====" 'Cyan'
# Normaliza el mes (acepta 2024-6 -> 2024-06); si es invalido, avisa e ignora el filtro
if ($UntilYM) {
  if ($UntilYM -match '^(\d{4})-(\d{1,2})$') { $UntilYM = '{0}-{1:D2}' -f $matches[1], [int]$matches[2] }
  else { Say "AVISO: mes '$UntilYM' no valido (formato AAAA-MM). Se ignora el limite de mes." 'Yellow'; $UntilYM = '' }
}
if ($FromYM) {
  if ($FromYM -match '^(\d{4})-(\d{1,2})$') { $FromYM = '{0}-{1:D2}' -f $matches[1], [int]$matches[2] }
  else { Say "AVISO: mes '$FromYM' no valido (formato AAAA-MM). Se ignora el limite inferior." 'Yellow'; $FromYM = '' }
}
$adb = Resolve-Adb $AdbPath
Say "adb en uso: $adb" 'DarkGray'

$hasDev = Test-Device $adb
if (-not $hasDev -and -not $DryRun) {
  Say "" ; Say "  MOVIL NO DETECTADO. Conecta el cable, desbloquea el movil," 'Red'
  Say "  elige 'Transferir archivos' y acepta la depuracion USB. Luego reintenta." 'Red'
  exit 1
}
if (-not $hasDev) { Say "AVISO: sin movil; en DryRun se usa solo el indice existente." 'Yellow' }

# ---- Configuracion (interactiva con defaults) ----
Say "== Configuracion ==" 'Cyan'
if ($SourceFolder) { $src = $SourceFolder } else { $src = Prompt-Default "Carpeta ORIGEN en el movil" $DEF_SOURCE }
$leaf = ($src.TrimEnd('/') -split '/')[-1]
if ($DestFolder) { $dst = $DestFolder } else {
  $sugg = if ($src -eq $DEF_SOURCE) { Join-Path $DEF_DESTBASE $DEF_DESTSUB } else { Join-Path $DEF_DESTBASE $leaf }
  $dst = Prompt-Default "Carpeta DESTINO en disco" $sugg
}
if ($PerCycle -gt 0) { $per = $PerCycle } else { $per = [int](Prompt-Default "Movimientos por ciclo" $DEF_PERCYCLE) }
if ($MaxGB -ge 0) { $maxgb = $MaxGB } else { $maxgb = [double](Prompt-Default "Tope de GB por sesion (0=sin tope)" 0) }

$key = $leaf -replace '[^A-Za-z0-9_.-]','_'
# ---- Validar DESTINO (unidad disponible) ----
$destRoot = [System.IO.Path]::GetPathRoot($dst)
if ([string]::IsNullOrWhiteSpace($destRoot) -or -not (Test-Path $destRoot)) {
  Say "" ; Say "  DESTINO NO DISPONIBLE: la unidad '$destRoot' no existe." 'Red'
  Say "  Conecta el disco o vuelve a lanzar indicando otra carpeta." 'Red'
  exit 1
}
$idxDir   = Join-Path $dst '_index'
try {
  New-Item -ItemType Directory -Force $dst    | Out-Null
  New-Item -ItemType Directory -Force $idxDir | Out-Null
} catch { throw "No se pudo crear la carpeta de destino '$dst': $($_.Exception.Message)" }
$indexCsv = Join-Path $idxDir "$key.index.csv"
$doneLog  = Join-Path $idxDir "$key.moved_ok.log"
$errLog   = Join-Path $idxDir "$key.errors.log"
$progTxt  = Join-Path $idxDir "$key.PROGRESO.txt"
$runLog   = Join-Path $idxDir "$key.run.log"
$skipLog  = Join-Path $idxDir "$key.skipped.log"

function Log($m){ $ts=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; $line="$ts  $m"; Write-Host $line; Add-LogSafe $runLog $line }
function Get-FreeGB($path){ try { $r=[System.IO.Path]::GetPathRoot($path); return [math]::Round((New-Object System.IO.DriveInfo($r)).AvailableFreeSpace/1GB,2) } catch { return 999 } }
# Escritura de log BLINDADA: reintenta si el fichero esta bloqueado y NUNCA tumba el proceso
function Add-LogSafe($path,$text){
  for($i=0;$i -lt 5;$i++){
    try { Add-Content -Path $path -Value $text -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds (60*($i+1)) }
  }
}
# ---- STOP: parada segura solicitada por el usuario (crea STOP.flag via 3_PARAR.bat) ----
$STOP_FLAGS = @('C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\STOP.flag','D:\GN\BK2\_tools\STOP.flag')
function Stop-Requested { foreach($p in $STOP_FLAGS){ if(Test-Path $p){ return $true } }; return $false }
function Clear-StopFlags { foreach($p in $STOP_FLAGS){ if(Test-Path $p){ Remove-Item $p -Force -ErrorAction SilentlyContinue } } }
# Al arrancar, limpia una STOP antigua para no pararnos nada mas empezar
Clear-StopFlags

Say "Origen : $src"        'White'
Say "Destino: $dst"        'White'
Say "Ciclo  : $per  |  Tope: $maxgb GB  |  Clave: $key" 'White'
$modeLabel = if ($CopyOnly) { 'SOLO-COPIAR (no borra del movil)' } else { 'MOVER (copia y borra del movil)' }
Say "Modo   : $modeLabel" 'White'
Log "===== START src=$src dst=$dst per=$per maxGB=$maxgb dryrun=$([bool]$DryRun) modo=$modeLabel ====="

# ---- Migracion de ledger antiguo (Screenshots ya empezado en v1) ----
$legacyDone = Join-Path $idxDir 'moved_ok.log'
$legacyIdx  = Join-Path $idxDir 'index.csv'
if (-not (Test-Path $doneLog)  -and (Test-Path $legacyDone)) { Copy-Item $legacyDone $doneLog;  Log "Migrado ledger antiguo -> $key.moved_ok.log" }
if (-not (Test-Path $indexCsv) -and (Test-Path $legacyIdx))  { Copy-Item $legacyIdx  $indexCsv; Log "Migrado indice antiguo -> $key.index.csv" }

# ---- Traer ledger del movil y UNIR con el del disco ----
$doneSet = @{}
if (Test-Path $doneLog) { foreach ($l in Get-Content $doneLog) { if ($l) { $doneSet[$l]=$true } } }
if ($hasDev) {
  & $adb shell "mkdir -p '$PHONE_LEDGER_DIR'" *> $null
  $tmpPull = Join-Path $env:TEMP "$key.phone.moved_ok.log"
  if (Test-Path $tmpPull) { Remove-Item $tmpPull -Force }
  & $adb pull "$PHONE_LEDGER_DIR/$key.moved_ok.log" "$tmpPull" *> $null
  if (Test-Path $tmpPull) {
    $before = $doneSet.Count
    foreach ($l in Get-Content $tmpPull) { if ($l) { $doneSet[$l]=$true } }
    Log "Unido ledger del movil (+$($doneSet.Count - $before) nuevos)."
  }
}
# reescribir ledger unido en disco (fuente de verdad)
$doneSet.Keys | Sort-Object | Set-Content -Path $doneLog -Encoding UTF8

# ---- Cargar set de archivos APARTADOS (fallo repetido) ----
$skipSet = @{}
if (Test-Path $skipLog) { foreach ($l in Get-Content $skipLog) { $n=($l -split '\|')[-1]; if ($n) { $skipSet[$n]=$true } } }

# ---- Indice: cargar o generar ----
if (-not (Test-Path $indexCsv)) {
  if (-not $hasDev) { throw "No hay indice para '$key' y no hay movil para generarlo." }
  Build-Index $adb $src $idxDir $key $indexCsv
}
$rows = Import-Csv $indexCsv
$scopeRows = $rows
if ($FromYM)  { $scopeRows = $scopeRows | Where-Object { $_.ym -ge $FromYM } }
if ($UntilYM) { $scopeRows = $scopeRows | Where-Object { $_.ym -le $UntilYM } }
$totalScope = $scopeRows.Count
if ($FromYM -or $UntilYM) { Log "Filtro activo: $(if($FromYM){"desde $FromYM "})$(if($UntilYM){"hasta $UntilYM "})($totalScope archivos en el rango)." }

# ---- MODO -FreeCopied: liberar del movil lo YA copiado+verificado en disco ----
if ($FreeCopied) {
  if (-not $hasDev) { Say "  Necesitas el movil conectado para liberar espacio." 'Red'; exit 1 }
  $freed=0; $nover=0
  foreach ($f in $scopeRows) {
    if (-not $doneSet.ContainsKey($f.name)) { continue }
    $df = Join-Path (Join-Path (Join-Path $dst $f.ym.Substring(0,4)) $f.ym) $f.name
    if ((Test-Path $df) -and ((Get-Item $df).Length -eq [long]$f.size)) {
      $q=$f.name -replace "'","'\''"; & $adb shell "rm -f '$remote/$q'" *> $null; $freed++
    } else { $nover++ }
  }
  Log "FreeCopied: liberados $freed del movil; $nover no verificados en disco (no tocados)."
  Say "Liberados del movil: $freed  |  No verificados: $nover" 'Green'
  exit 0
}

# ---- Aviso de espacio libre en destino ----
$freeGB = Get-FreeGB $dst
Say ("Espacio libre en destino: {0} GB" -f $freeGB) 'DarkGray'
if ($freeGB -lt $MinFreeGB) { Say "  DISCO CASI LLENO ($freeGB GB < $MinFreeGB GB). Libera espacio antes de continuar." 'Red'; "[$(Get-Date -Format HH:mm:ss)] ${key}: ALERTA_DISCO_LLENO (libre $freeGB GB)" | Set-Content $progTxt -Encoding UTF8; exit 4 }

# ---- Copiar indice al movil (no temporal) ----
if ($hasDev) { & $adb push "$indexCsv" "$PHONE_LEDGER_DIR/$key.index.csv" *> $null }

function Sync-PhoneLedger($adb){
  if ($hasDev) { & $adb push "$doneLog" "$PHONE_LEDGER_DIR/$key.moved_ok.log" *> $null }
}
function Write-Prog($pct,$moved,$total,$gb,$extra){
  $ts=Get-Date -Format 'HH:mm:ss'
  "[{0}] {1}: {2}%  {3}/{4}  {5:N2} GB  {6}" -f $ts,$key,$pct,$moved,$total,$gb,$extra | Set-Content -Path $progTxt -Encoding UTF8
}

# ============================== BUCLE ==============================
$curBatch = $per
$retries  = 0
$sessBytes = 0L
$sessFiles = 0
$stopCap = $false
$stopMax = $false
$userStop = $false
$failCount = @{}
$swSess = [System.Diagnostics.Stopwatch]::StartNew()
$remote = $src.TrimEnd('/')

while ($true) {
  $pending = $scopeRows | Where-Object { -not $doneSet.ContainsKey($_.name) -and -not $skipSet.ContainsKey($_.name) }
  $pend = $pending.Count
  $skipN = $skipSet.Count
  $moved = $totalScope - $pend - $skipN
  $pct = if ($totalScope) { [math]::Round(100*$moved/$totalScope,1) } else { 100 }
  Write-Prog $pct $moved $totalScope ($sessBytes/1GB) $(if($skipN){"($skipN apartados)"}else{""})

  if ($pend -le 0) { $ex=if($skipN){" ($skipN apartados por fallo)"}else{""}; Log "COMPLETADO: $moved/$totalScope movidos$ex."; Write-Prog 100 $moved $totalScope ($sessBytes/1GB) "COMPLETADO$ex"; break }

  # STOP solicitado por el usuario (entre ciclos)
  if (Stop-Requested) { Clear-StopFlags; Log "STOP solicitado: parada segura."; Write-Prog $pct $moved $totalScope ($sessBytes/1GB) "PARADA_OK - YA PUEDES DESCONECTAR EL MOVIL"; Say "" ; Say "  PARADA COMPLETADA. YA PUEDES DESCONECTAR EL MOVIL." 'Green'; $userStop=$true; break }

  # Aviso de espacio en disco por ciclo (#4)
  $freeGB = Get-FreeGB $dst
  if ($freeGB -lt $MinFreeGB) { Log "DISCO CASI LLENO ($freeGB GB < $MinFreeGB GB). Corto limpio; libera espacio y relanza."; Write-Prog $pct $moved $totalScope ($sessBytes/1GB) "ALERTA_DISCO_LLENO ($freeGB GB)"; break }

  # Esperar dispositivo
  if (-not $DryRun) {
    if (-not (Test-Device $adb)) {
      Log "Sin dispositivo. Esperando (max $MaxWaitMin min)..."
      $w=0
      while (-not (Test-Device $adb)) {
        Start-Sleep -Seconds 20; $w+=20
        if ($w -ge $MaxWaitMin*60) { Log "ALERTA: sin dispositivo. DESCONECTA/RECONECTA EL CABLE."; Write-Prog $pct $moved $totalScope ($sessBytes/1GB) "ALERTA_RECONECTAR_CABLE"; exit 2 }
      }
      Log "Reconectado."; & $adb start-server *> $null
    }
  }

  $batch = $pending | Select-Object -First $curBatch
  Log "Ciclo bloque=$curBatch  pendientes=$pend  ($moved/$totalScope, $pct%, sesion $([math]::Round($sessBytes/1GB,2)) GB)"
  $movedThis = 0

  foreach ($f in $batch) {
    if ($maxgb -gt 0 -and ($sessBytes + [long]$f.size) -gt ($maxgb*1GB)) { Log ("TOPE {0} GB alcanzado ({1:N2} GB). Relanza para seguir." -f $maxgb, ($sessBytes/1GB)); $stopCap=$true; break }
    $year = $f.ym.Substring(0,4)
    $destDir = Join-Path (Join-Path $dst $year) $f.ym
    $destFile= Join-Path $destDir $f.name
    $srcPath = "$remote/$($f.name)"

    if ($DryRun) { Say "  [DRY] $($f.fecha) -> $year\$($f.ym)\ $($f.name)"; $movedThis++; continue }

    New-Item -ItemType Directory -Force $destDir | Out-Null
    & $adb pull -a "$srcPath" "$destFile" *> $null
    if (-not (Test-Path $destFile)) {   # reintento inmediato: absorbe microcortes (#2)
      Start-Sleep -Milliseconds 400
      & $adb pull -a "$srcPath" "$destFile" *> $null
    }
    if (Test-Path $destFile) {
      $ls = (Get-Item $destFile).Length
      if ($ls -gt 0 -and $ls -eq [long]$f.size) {
        if (-not $CopyOnly) {
          $q = $f.name -replace "'", "'\''"
          & $adb shell "rm -f '$remote/$q'" *> $null
        }
        Add-LogSafe $doneLog $f.name
        $doneSet[$f.name] = $true
        $movedThis++; $sessBytes += $ls; $sessFiles++
        if ($MaxFiles -gt 0 -and $sessFiles -ge $MaxFiles) { $stopMax = $true; break }
      } else {
        Add-LogSafe $errLog ("{0}|SIZE_MISMATCH|local={1}|idx={2}|{3}" -f (Get-Date -Format s), $ls, $f.size, $f.name)
        Remove-Item $destFile -Force
      }
    } else {
      # Fallo tras reintento. Movil desconectado a mitad? -> corte limpio (#1)
      if (-not (Test-Device $adb)) { Log "Movil desconectado a mitad de bloque; corto y paso a esperar reconexion."; break }
      # Movil presente pero el archivo insiste en fallar: apartar tras 3 (#3)
      $failCount[$f.name] = 1 + ([int]$failCount[$f.name])
      if ($failCount[$f.name] -ge 3) {
        Add-LogSafe $skipLog ("{0}|SKIP_3FALLOS|{1}" -f (Get-Date -Format s), $f.name)
        $skipSet[$f.name] = $true
        Log "Archivo apartado tras 3 fallos (sigue el proceso): $($f.name)"
      } else {
        Add-LogSafe $errLog ("{0}|PULL_FAILED|{1}" -f (Get-Date -Format s), $f.name)
      }
    }
    if (Stop-Requested) { $userStop=$true; break }
    # Corte por DISCO LLENO dentro del bloque (cada 25 archivos), evita ráfagas de fallos
    if (($movedThis % 25) -eq 0) {
      if ((Get-FreeGB $dst) -lt $MinFreeGB) { Log "DISCO CASI LLENO a mitad de bloque. Corto limpio."; $stopCap=$true; break }
    }
  }

  Sync-PhoneLedger $adb
  $moved2 = ($scopeRows | Where-Object { -not $doneSet.ContainsKey($_.name) -and -not $skipSet.ContainsKey($_.name) }).Count
  $movedNow = $totalScope - $moved2 - $skipSet.Count
  $pct2 = if ($totalScope) { [math]::Round(100*$movedNow/$totalScope,1) } else { 100 }
  Write-Prog $pct2 $movedNow $totalScope ($sessBytes/1GB) ""
  Log ("Ciclo +{0}  ->  {1}/{2} ({3}%)  sesion {4:N2} GB" -f $movedThis, $movedNow, $totalScope, $pct2, ($sessBytes/1GB))

  if ($userStop) { Clear-StopFlags; Log "STOP: parada segura tras completar el archivo actual."; Write-Prog $pct2 $movedNow $totalScope ($sessBytes/1GB) "PARADA_OK - YA PUEDES DESCONECTAR EL MOVIL"; Say "" ; Say "  PARADA COMPLETADA. YA PUEDES DESCONECTAR EL MOVIL CON SEGURIDAD." 'Green'; break }
  if ($DryRun) { Log "DryRun: 1 ciclo simulado, fin."; break }
  if ($stopCap) { Write-Prog $pct2 $movedNow $totalScope ($sessBytes/1GB) "TOPE_GB"; break }
  if ($stopMax) { Log "Tope de $MaxFiles archivos (prueba) alcanzado."; break }

  if ($movedThis -le 0) {
    $retries++
    Log "Sin progreso (reintento $retries/$MaxRetry) con bloque=$curBatch. Ledger guardado (disco+movil)."
    if ($retries -ge $MaxRetry) {
      if ($curBatch -gt $MinBatch) { $curBatch = [math]::Max($MinBatch,[int]($curBatch/2)); $retries=0; Log "ALTERNATIVA: reduzco bloque a $curBatch." }
      else { Log "ALERTA: sin progreso tras $MaxRetry reintentos con bloque minimo. REQUIERE ACCION: cambia/reconecta cable."; Write-Prog $pct2 $movedNow $totalScope ($sessBytes/1GB) "ALERTA_CAMBIAR_CABLE"; exit 3 }
    }
    Start-Sleep -Seconds 12
  } else { $retries = 0 }
}

$secs = [math]::Max($swSess.Elapsed.TotalSeconds,1)
$fpm = [math]::Round($sessFiles/($secs/60),0)
$mbs = [math]::Round(($sessBytes/1MB)/$secs,2)
Log ("===== FIN ($key)  {0} archivos / {1:N2} GB en {2:N0}s  |  {3} arch/min  |  {4} MB/s =====" -f $sessFiles, ($sessBytes/1GB), $secs, $fpm, $mbs)

