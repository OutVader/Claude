<#
.SYNOPSIS
  Comprueba el entorno, mide la velocidad, simula y, SI TODO SALE LIMPIO, mueve una tanda de vídeos
  (los más pesados primero, hasta 10 GB) del móvil al disco. Pensado para pegar o lanzar desde ISE.
.DESCRIPTION
  Se para (sin mover nada) si cualquier paso falla:
    1. La versión del motor no es la esperada.
    2. Los tests fallan (se aceptan 0 = todo verde y 3 = algún caso omitido, como T32 en Windows).
    3. No hay exactamente un móvil listo, o no está la unidad del destino.
    4. La simulación (-WhatIf) no termina con código 0.
  Después mueve con -ConfirmarBorrado BORRAR: el borrado en el móvil sigue siendo SOLO de lo
  verificado por SHA256. Con -Modo Copiar no borra nada del móvil (copia y verifica por SHA256);
  si luego se relanza con Mover, lo ya copiado sale YA_EXISTIA (comprobado por SHA256) y solo se borra. La medición de velocidad copia un vídeo a %TEMP% y lo borra del PC, nunca
  del móvil.
.EXAMPLE
  & '...\Traspaso-Archivos\Prueba-y-Tanda.ps1'
.EXAMPLE
  & '...\Traspaso-Archivos\Prueba-y-Tanda.ps1' -Destino 'E:\Videos' -MaxGB 20 -SinTests
.EXAMPLE
  & '...\Traspaso-Archivos\Prueba-y-Tanda.ps1' -Modo Copiar -MaxGB 1
  Prueba pequeña de verdad: copia ~1 GB de los vídeos más pesados sin tocar el móvil.
#>
[CmdletBinding()]
param(
    [string]$Origen = 'adb:/sdcard/DCIM/Camera',
    [string]$Destino = 'D:\BK\Honor\Bideoak',
    [double]$MaxGB = 10,
    [ValidateSet('Copiar', 'Mover')][string]$Modo = 'Mover',
    [string]$Extensiones = 'mp4,mov,3gp,mkv,avi,m4v,webm',
    [switch]$SinTests,
    [switch]$SoloSimular
)
$ErrorActionPreference = 'Continue'
$proyecto = $PSScriptRoot
if (-not $proyecto) { $proyecto = (Get-Location).Path }
$motor = [IO.Path]::Combine($proyecto, 'scripts', 'Traspasar-Archivos.ps1')
$adb = [IO.Path]::Combine($env:USERPROFILE, 'Desktop', '0.Escritorio', 'BK2', '_tools', 'platform-tools', 'adb.exe')

function Write-Paso { param([string]$Texto) Write-Host "`n=== $Texto ===" -ForegroundColor Cyan }
function Stop-Prueba { param([string]$Texto) Write-Host "PARADO: $Texto (no se ha movido nada)." -ForegroundColor Red; exit 1 }

Write-Paso '1/6 Versión del motor'
if (-not (Test-Path -LiteralPath $motor)) { Stop-Prueba "no encuentro $motor" }
if (-not (Select-String -LiteralPath $motor -Pattern "VERSION_SCRIPT = '3.2.2'" -Quiet)) { Stop-Prueba 'el motor no es la v3.2.2: vuelve a descargarlo' }
Write-Host '  v3.2.2 OK'

Write-Paso '2/6 Tests (unos minutos)'
if ($SinTests) { Write-Host '  Omitidos por -SinTests.' -ForegroundColor Yellow }
else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ([IO.Path]::Combine($proyecto, 'tests', 'Probar-Traspaso.ps1')) | Select-String -Pattern 'FALLO\]|OMITIDO\]|RESULTADO' | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
    $codigoTests = $LASTEXITCODE
    if ($codigoTests -ne 0 -and $codigoTests -ne 3) { Stop-Prueba "los tests fallan (código $codigoTests)" }
}

Write-Paso '3/6 Móvil y disco'
if (-not (Test-Path -LiteralPath $adb)) { Stop-Prueba "no encuentro adb en $adb" }
$moviles = @(& $adb devices 2>$null | Where-Object { "$_" -match "`tdevice$" })
if ($moviles.Count -ne 1) { Stop-Prueba "hay $($moviles.Count) móviles listos (debe haber 1, desbloqueado y con la depuración USB aceptada)" }
Write-Host "  Móvil: $(("$($moviles[0])" -split "`t")[0])"
$raiz = [IO.Path]::GetPathRoot($Destino)
if (-not $raiz -or -not (Test-Path -LiteralPath $raiz)) { Stop-Prueba "la unidad de $Destino no está conectada" }
try {
    $vol = Get-Volume -DriveLetter $raiz.Substring(0, 1) -ErrorAction Stop
    Write-Host ("  Disco {0} {1} ({2}): {3:N1} GB libres de {4:N0} GB" -f $raiz, $vol.FileSystemLabel, $vol.FileSystemType, ($vol.SizeRemaining / 1GB), ($vol.Size / 1GB))
}
catch { Write-Host '  (no se pudo leer la información del volumen; sigue)' -ForegroundColor DarkGray }

Write-Paso '4/6 Velocidad real (copia un vídeo a %TEMP% con y sin compresión; no toca el móvil)'
$rutaMovil = $Origen.Substring(4).TrimEnd('/') + '/'
$video = @(& $adb shell "find '$rutaMovil' -type f -name '*.mp4' -size +100M 2>/dev/null | head -n 1" 2>$null | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
if ($video.Count -eq 0) { Write-Host '  No hay vídeos de más de 100 MB para medir; se sigue.' -ForegroundColor Yellow }
else {
    $tmp = [IO.Path]::Combine($env:TEMP, 'prueba-velocidad-traspaso.mp4')
    foreach ($modo in @(@{ N = 'con -Z (sin compresión)'; A = @('pull', '-Z', $video[0], $tmp) }, @{ N = 'sin -Z (con compresión)'; A = @('pull', $video[0], $tmp) })) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
        $t = Measure-Command { & $adb @($modo.A) 2>&1 | Out-Null }
        if (Test-Path -LiteralPath $tmp) {
            $mb = (Get-Item -LiteralPath $tmp).Length / 1MB
            Write-Host ("  {0}: {1:N0} MB en {2:N1} s = {3:N1} MB/s" -f $modo.N, $mb, $t.TotalSeconds, ($mb / [math]::Max($t.TotalSeconds, 0.1)))
        }
        else { Write-Host "  $($modo.N): la copia de prueba falló (si es 'con -Z', tu adb no lo admite y el motor no lo usará)." -ForegroundColor Yellow }
    }
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    Write-Host '  Referencia: ~30-40 MB/s = el puerto del móvil es USB 2.0; >100 MB/s = USB 3 (entonces el disco de cabezales puede ser el límite).' -ForegroundColor DarkGray
}

$parametros = @{
    Origen = $Origen; Destino = $Destino; Recursivo = $true; Modo = $Modo; Extensiones = $Extensiones
    OrdenPor = 'Tamano'; MaxGB = $MaxGB; Informe = 'Html'; SinPausa = $true
}
if ($Modo -eq 'Copiar') { $parametros.Hash = $true }   # copiar también con SHA256

Write-Paso "5/6 Simulación: los vídeos más pesados, hasta $MaxGB GB (no copia ni borra nada)"
& $motor @parametros -WhatIf
if ($LASTEXITCODE -ne 0) { Stop-Prueba "la simulación terminó con código $LASTEXITCODE" }
if ($SoloSimular) { Write-Host "`nSolo simulación (-SoloSimular): no se mueve nada." -ForegroundColor Yellow; exit 0 }

if ($Modo -eq 'Mover') {
    Write-Paso '6/6 MOVER de verdad (solo lo verificado por SHA256 se borra del móvil)'
    & $motor @parametros -ConfirmarBorrado 'BORRAR'
}
else {
    Write-Paso '6/6 COPIAR de verdad (verificado por SHA256; no se borra nada del móvil)'
    & $motor @parametros
}
$codigo = $LASTEXITCODE
switch ($codigo) {
    0 { Write-Host "`nTANDA TERMINADA SIN FALLOS. Para la siguiente, vuelve a lanzar este script." -ForegroundColor Green }
    1 { Write-Host "`nTanda con fallos o interrumpida (código 1): mira el resumen y el registro. Relanzar no repite lo hecho." -ForegroundColor Red }
    default { Write-Host "`nCódigo $codigo." -ForegroundColor Yellow }
}
exit $codigo
