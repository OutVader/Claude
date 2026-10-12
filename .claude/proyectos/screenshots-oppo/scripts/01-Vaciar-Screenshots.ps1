<#
.SYNOPSIS  Pasa las capturas del móvil OPPO al PC por año y por bloques (ADB), con verificación.
.DESCRIPTION
  1. -SoloInventario: cuenta capturas y MB por año en el móvil y termina. No copia nada.
  2. Con -Anio: copia (adb pull -a, conserva la fecha) las capturas de ese año a <Destino>\<Anio>\,
     en bloques de -Bloque archivos, con pausa entre bloques. Verifica el tamaño de cada archivo.
  3. Solo con -Borrar (y escribiendo BORRAR para confirmar): elimina del móvil cada archivo
     DESPUÉS de comprobar que la copia local existe y tiene el mismo tamaño.
  Registro de cada archivo en <Destino>\_registro-screenshots.csv. Es reanudable: lo que ya está
  copiado con el mismo tamaño no se vuelve a descargar.
  El año sale del nombre (Screenshot_AAAA...) y, si no lo lleva, de la fecha del archivo.
.EXAMPLE   .\01-Vaciar-Screenshots.ps1 -SoloInventario
.EXAMPLE   .\01-Vaciar-Screenshots.ps1 -Anio 2023 -Destino 'D:\Fotos\Screenshots-OPPO'
.EXAMPLE   .\01-Vaciar-Screenshots.ps1 -Anio 2023 -Destino 'D:\Fotos\Screenshots-OPPO' -Borrar
#>
[CmdletBinding()]
param(
    [int]$Anio,
    [string]$Destino,
    [string]$Origen,            # carpeta en el móvil; si se omite, se autodetecta
    [int]$Bloque = 200,
    [switch]$SoloInventario,
    [switch]$Borrar,
    [switch]$SinPausa,
    [string]$Adb = 'adb'
)
# 'Continue' a propósito: en PS 5.1 el stderr de adb con 'Stop' se convierte en error terminante.
$ErrorActionPreference = 'Continue'

if (-not $SoloInventario -and (-not $Anio -or -not $Destino)) { throw 'Indica -Anio y -Destino (o usa -SoloInventario).' }
if (-not (Get-Command $Adb -ErrorAction SilentlyContinue)) { throw "No encuentro '$Adb'. Instala platform-tools o pasa -Adb 'C:\ruta\adb.exe'." }

# --- Dispositivo ---
$devs = @(& $Adb devices | Where-Object { $_ -match "`tdevice$" })
if ($devs.Count -ne 1) { throw "Conecta exactamente 1 móvil con depuración USB autorizada (adb devices). Encontrados: $($devs.Count)" }

# --- Carpeta de origen ---
if (-not $Origen) {
    foreach ($c in '/sdcard/DCIM/Screenshots', '/sdcard/Pictures/Screenshots', '/sdcard/DCIM/Screenshot') {
        if (("" + (& $Adb shell "[ -d '$c' ] && echo SI")).Trim() -eq 'SI') { $Origen = $c; break }
    }
    if (-not $Origen) { throw 'No encuentro la carpeta de capturas; indícala con -Origen.' }
}
Write-Host "Móvil: $($devs[0].Split("`t")[0])   Origen: $Origen" -ForegroundColor Cyan

# --- Inventario ---
$crudo = & $Adb shell "cd '$Origen' && stat -c '%Y|%s|%n' * 2>/dev/null"
$items = foreach ($l in $crudo) {
    $p = ("" + $l).Trim() -split '\|', 3
    if ($p.Count -ne 3 -or $p[2] -eq '*') { continue }
    $fecha = [DateTimeOffset]::FromUnixTimeSeconds([long]$p[0]).LocalDateTime
    $a = if ($p[2] -match '^Screenshot_((?:19|20)\d{2})') { [int]$Matches[1] } else { $fecha.Year }
    [pscustomobject]@{ Nombre = $p[2]; Bytes = [long]$p[1]; Fecha = $fecha; Anio = $a }
}
$items = @($items)
$items | Group-Object Anio | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Anio = $_.Name; Capturas = $_.Count; MB = [math]::Round(($_.Group | Measure-Object Bytes -Sum).Sum / 1MB, 1) }
} | Format-Table -AutoSize | Out-Host
if ($SoloInventario) { return }

$sel = @($items | Where-Object Anio -eq $Anio | Sort-Object Fecha)
if (-not $sel.Count) { Write-Host "No hay capturas de $Anio en $Origen." -ForegroundColor Yellow; return }

if ($Borrar) {
    Write-Host "Se BORRARÁN del móvil las capturas de $Anio una vez verificada su copia ($($sel.Count) archivos)." -ForegroundColor Red
    if ((Read-Host 'Escribe BORRAR para confirmar') -cne 'BORRAR') { Write-Host 'Cancelado: se copiará sin borrar.'; $Borrar = $false }
}

$dirAnio = Join-Path $Destino $Anio
New-Item -ItemType Directory -Path $dirAnio -Force | Out-Null
$registro = Join-Path $Destino '_registro-screenshots.csv'
$ok = 0; $fallos = 0; $borrados = 0

for ($i = 0; $i -lt $sel.Count; $i += $Bloque) {
    $fin = [math]::Min($i + $Bloque, $sel.Count) - 1
    Write-Host "`n--- Bloque $([math]::Floor($i / $Bloque) + 1): $($i + 1)-$($fin + 1) de $($sel.Count) ---" -ForegroundColor Cyan
    foreach ($it in $sel[$i..$fin]) {
        $local = Join-Path $dirAnio $it.Nombre
        $estado = 'COPIADO'
        if ((Test-Path -LiteralPath $local) -and (Get-Item -LiteralPath $local).Length -eq $it.Bytes) { $estado = 'YA_EXISTIA' }
        else { & $Adb pull -a "$Origen/$($it.Nombre)" "$local" | Out-Null }
        $verificado = (Test-Path -LiteralPath $local) -and (Get-Item -LiteralPath $local).Length -eq $it.Bytes
        if (-not $verificado) { $estado = 'FALLO_VERIFICACION'; $fallos++ } else { $ok++ }
        if ($Borrar -and $verificado) {
            if ($it.Nombre.Contains("'")) { $estado += '+NO_BORRADO_COMILLA' }
            else {
                & $Adb shell "rm '$Origen/$($it.Nombre)'" | Out-Null
                if ($LASTEXITCODE -eq 0) { $estado += '+BORRADO_MOVIL'; $borrados++ } else { $estado += '+ERROR_BORRADO' }
            }
        }
        [pscustomobject]@{ Fecha = (Get-Date -Format 's'); Anio = $Anio; Archivo = $it.Nombre; Bytes = $it.Bytes; Estado = $estado; Local = $local } |
            Export-Csv -LiteralPath $registro -Append -NoTypeInformation -Encoding UTF8
    }
    Write-Host "  Verificados: $ok · Fallos: $fallos · Borrados del móvil: $borrados"
    if (-not $SinPausa -and $fin -lt $sel.Count - 1) {
        if ((Read-Host 'Siguiente bloque? (S/n)') -match '^[nN]') { break }
    }
}
Write-Host "`nFin $Anio. Verificados: $ok · Fallos: $fallos · Borrados: $borrados · Registro: $registro" -ForegroundColor Green
if ($borrados) { Write-Host 'La galería puede tardar en reflejar el borrado (o hasta reiniciar el móvil).' -ForegroundColor DarkGray }
