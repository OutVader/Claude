<#
.SYNOPSIS
  Menú maestro interactivo de Traspaso-Archivos: elige origen, destino y opciones por pantalla y
  lanza Traspasar-Archivos.ps1. También muestra el estado en vivo, lo que falta y los registros.

.DESCRIPTION
  Opciones del menú principal:
    1 Nuevo traspaso (asistente completo, con todas las opciones)
    2 Repetir el último traspaso
    3 Inventario de un origen (archivos y MB por año y mes)
    4 Comparar origen y destino (qué falta y % hecho)
    5 Ver el estado de las transferencias (en vivo: %, hechos, faltan, ETA)
    6 Ver el último registro (resumen por estado y fallos)
    7 Comprobar el móvil (adb devices)
    8 Ayuda completa del motor
    9 Traspaso rápido: origen, destino, fecha desde, fecha hasta y tamaño mínimo en MB
   10 Salir
  Funciona en la consola, con doble clic en 1_LANZAR-Traspaso.bat y en PowerShell ISE (F5).
  Fechas: AAAA-MM-DD, AAAA-MM o DD/MM/AAAA. Tamaño: admite decimales con coma o punto (1,5).
  En cada pregunta, Enter acepta la opción por defecto, que va marcada con *.
  Antes de ejecutar enseña el comando equivalente, para lanzarlo después sin menú si se quiere.
  Guarda la última configuración y los destinos recientes en
  %LOCALAPPDATA%\Traspaso-Archivos\menu.json (solo es una comodidad: si no se puede, sigue igual).

.PARAMETER Motor
  Ruta de Traspasar-Archivos.ps1. Por defecto, el que está junto a este script.

.PARAMETER RutaConfig
  Archivo de configuración del menú. Por defecto %LOCALAPPDATA%\Traspaso-Archivos\menu.json
  (los tests usan uno propio para no tocar el del usuario).

.EXAMPLE
  .\Menu-Traspaso.ps1
  Abre el menú. También se abre con doble clic en 1_LANZAR-Traspaso.bat.

.NOTES
  Versión 3.1.0 (2026-10-20). Windows PowerShell 5.1 y PowerShell 7. UTF-8 con BOM y CRLF.
#>
[CmdletBinding()]
param([string]$Motor, [string]$RutaConfig)

$ErrorActionPreference = 'Continue'
$ES_ISE = ($Host.Name -match 'ISE')
# En ISE (F5) el script corre en la sesión global: sin modo estricto para no dejarlo puesto al salir
if (-not $ES_ISE) { Set-StrictMode -Version 2.0 }
$CARPETA_SCRIPTS = $PSScriptRoot
if (-not $CARPETA_SCRIPTS) { $CARPETA_SCRIPTS = (Get-Location).Path }   # pestaña de ISE sin guardar: la carpeta actual
if (-not $Motor) { $Motor = [IO.Path]::Combine($CARPETA_SCRIPTS, 'Traspasar-Archivos.ps1') }
if (-not (Test-Path -LiteralPath $Motor -PathType Leaf)) { Write-Host "No encuentro el motor: $Motor" -ForegroundColor Red; exit 2 }

$BASE_BK2 = 'D:\GN\BK2'
$CARPETAS_MOVIL = @(
    @{ T = 'Capturas (Pictures/Screenshots)'; Ruta = '/sdcard/Pictures/Screenshots'; Dest = 'ScreenShots' }
    @{ T = 'Capturas (DCIM/Screenshots)'; Ruta = '/sdcard/DCIM/Screenshots'; Dest = 'ScreenShots' }
    @{ T = 'Cámara (DCIM/Camera)'; Ruta = '/sdcard/DCIM/Camera'; Dest = 'Camera' }
    @{ T = 'Twitter'; Ruta = '/sdcard/Pictures/Twitter'; Dest = 'Twitter' }
    @{ T = 'Telegram'; Ruta = '/sdcard/Pictures/Telegram'; Dest = 'Telegram' }
    @{ T = 'Instagram'; Ruta = '/sdcard/Pictures/Instagram'; Dest = 'Instagram' }
    @{ T = 'Collage'; Ruta = '/sdcard/DCIM/Collage'; Dest = 'Collage' }
    @{ T = 'Snapseed'; Ruta = '/sdcard/Pictures/Snapseed'; Dest = 'Snapseed' }
    @{ T = 'Polish'; Ruta = '/sdcard/Pictures/Polish'; Dest = 'Polish' }
    @{ T = 'WhatsApp (Pictures/WhatsApp)'; Ruta = '/sdcard/Pictures/WhatsApp'; Dest = 'WhatsApp' }
    @{ T = 'WhatsApp Images (Android 11+)'; Ruta = '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images'; Dest = 'WhatsApp' }
    @{ T = 'Descargas (Download)'; Ruta = '/sdcard/Download'; Dest = 'Download' }
)
$EXT_IMAGENES = 'jpg,jpeg,png,heic,heif,webp,gif,bmp,dng'
$EXT_VIDEOS = 'mp4,mov,3gp,mkv,avi,m4v,webm'
$ORDEN_PARAMETROS = @('Origen', 'Destino', 'Dispositivo', 'Modo', 'Organizar', 'FechaPor', 'Extensiones', 'Patron', 'Excluir',
    'Anio', 'Desde', 'Hasta', 'MinMB', 'MaxMB', 'Recursivo', 'IncluirOcultos', 'Hash', 'Bloque', 'SinPausa', 'MaxArchivos', 'MaxGB', 'Informe', 'SoloInventario', 'SoloComparar', 'WhatIf')

# ============================== configuración guardada ==============================
$script:RutaCfg = $null
if ($RutaConfig) { $script:RutaCfg = $RutaConfig }
else {
    try {
        $dirLocal = [Environment]::GetFolderPath('LocalApplicationData')
        if ($dirLocal) { $script:RutaCfg = [IO.Path]::Combine($dirLocal, 'Traspaso-Archivos', 'menu.json') }
    }
    catch { $script:RutaCfg = $null }
}

function ConvertTo-Tabla {
    # PSCustomObject (de JSON) -> hashtable apta para splatting
    param($Objeto)
    $h = @{}
    if ($null -eq $Objeto) { return $h }
    foreach ($pr in $Objeto.PSObject.Properties) { $h[$pr.Name] = $pr.Value }
    return $h
}

function Read-Config {
    $cfg = @{ Ultimo = $null; Destinos = @(); Origenes = @() }
    if (-not $script:RutaCfg -or -not (Test-Path -LiteralPath $script:RutaCfg)) { return $cfg }
    try {
        $j = Get-Content -LiteralPath $script:RutaCfg -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($j.PSObject.Properties['Ultimo'] -and $j.Ultimo) { $cfg.Ultimo = ConvertTo-Tabla $j.Ultimo }
        if ($j.PSObject.Properties['Destinos']) { $cfg.Destinos = @($j.Destinos | Where-Object { $_ }) }
        if ($j.PSObject.Properties['Origenes']) { $cfg.Origenes = @($j.Origenes | Where-Object { $_ }) }
    }
    catch { Write-Host '  (No se pudo leer la configuración guardada; se empieza de cero.)' -ForegroundColor DarkGray }
    return $cfg
}

function Save-Config {
    param([hashtable]$Cfg)
    if (-not $script:RutaCfg) { return }
    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($script:RutaCfg))
        $txt = [ordered]@{ Ultimo = $Cfg.Ultimo; Destinos = @($Cfg.Destinos | Select-Object -First 8); Origenes = @($Cfg.Origenes | Select-Object -First 8) } | ConvertTo-Json -Depth 4
        [IO.File]::WriteAllText($script:RutaCfg, $txt, (New-Object System.Text.UTF8Encoding($false)))
    }
    catch { Write-Host '  (No se pudo guardar la configuración; no afecta al traspaso.)' -ForegroundColor DarkGray }
}

function Add-Reciente {
    param([object[]]$Lista, [string]$Valor)
    return @(@($Valor) + @($Lista | Where-Object { $_ -and $_ -ne $Valor }))
}

# ============================== preguntas ==============================
function Read-Opcion {
    # $Opciones = lista de @{ T = 'texto'; V = valor }. Devuelve V; con -PermitirVolver, '0' devuelve $null
    param([string]$Titulo, [object[]]$Opciones, [int]$PorDefecto = 1, [switch]$PermitirVolver)
    while ($true) {
        Write-Host ''
        Write-Host $Titulo -ForegroundColor Cyan
        for ($i = 0; $i -lt $Opciones.Count; $i++) {
            $marca = ' '
            if ($i + 1 -eq $PorDefecto) { $marca = '*' }
            Write-Host ("  {0}[{1}] {2}" -f $marca, ($i + 1), $Opciones[$i].T)
        }
        if ($PermitirVolver) { Write-Host '   [0] Volver' -ForegroundColor DarkGray }
        $r = (Read-Host "  Elige (Enter = $PorDefecto)").Trim()
        if ($r -eq '') { return $Opciones[$PorDefecto - 1].V }
        if ($PermitirVolver -and $r -eq '0') { return $null }
        $n = 0
        if ([int]::TryParse($r, [ref]$n) -and $n -ge 1 -and $n -le $Opciones.Count) { return $Opciones[$n - 1].V }
        Write-Host '  Opción no válida, prueba otra vez.' -ForegroundColor Yellow
    }
}

function Read-Texto {
    param([string]$Pregunta, [string]$PorDefecto = '')
    $sufijo = ''
    if ($PorDefecto) { $sufijo = " [Enter = $PorDefecto]" }
    $r = (Read-Host "  $Pregunta$sufijo").Trim().Trim('"')
    if ($r -eq '') { return $PorDefecto }
    return $r
}

function Read-SiNo {
    param([string]$Pregunta, [bool]$PorDefecto = $false)
    $txt = '(s/N)'
    if ($PorDefecto) { $txt = '(S/n)' }
    $r = (Read-Host "  $Pregunta $txt").Trim()
    if ($r -eq '') { return $PorDefecto }
    return ($r -match '^[sSyY]')
}

function ConvertTo-FechaMenu {
    # Texto -> [datetime] (inicio, o final del periodo si -Fin). $null si no es una fecha válida.
    param([string]$Texto, [switch]$Fin)
    $ci = [Globalization.CultureInfo]::InvariantCulture
    $f = [datetime]::MinValue
    $estilo = [Globalization.DateTimeStyles]::None
    if ([datetime]::TryParseExact($Texto, [string[]]@('yyyy-MM-dd', 'yyyy-M-d', 'dd/MM/yyyy', 'd/M/yyyy'), $ci, $estilo, [ref]$f) -and $f.Year -ge 1990 -and $f.Year -le 2100) {
        if ($Fin) { return $f.AddDays(1).AddTicks(-1) }
        return $f
    }
    if ([datetime]::TryParseExact($Texto, [string[]]@('yyyy-MM', 'yyyy-M', 'MM/yyyy', 'M/yyyy'), $ci, $estilo, [ref]$f) -and $f.Year -ge 1990 -and $f.Year -le 2100) {
        if ($Fin) { return $f.AddMonths(1).AddTicks(-1) }
        return $f
    }
    return $null
}

function Read-Mes {
    # Pide una fecha y la devuelve normalizada (AAAA-MM-DD o AAAA-MM), o '' si se deja en blanco
    param([string]$Pregunta)
    while ($true) {
        $r = Read-Texto $Pregunta
        if ($r -eq '') { return '' }
        $f = ConvertTo-FechaMenu $r
        if ($null -ne $f) {
            if ($r -match '^\d{4}-\d{1,2}$' -or $r -match '^\d{1,2}/\d{4}$') { return $f.ToString('yyyy-MM', [Globalization.CultureInfo]::InvariantCulture) }
            return $f.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        }
        Write-Host '  Fecha no válida. Usa AAAA-MM-DD, AAAA-MM o DD/MM/AAAA (ej. 2024-07-01 o 01/07/2024; años 1990-2100).' -ForegroundColor Yellow
    }
}

function Read-Rango {
    # Pide DESDE y HASTA y comprueba que DESDE no sea posterior a HASTA. Devuelve @(desde, hasta).
    while ($true) {
        $d = Read-Mes 'Fecha DESDE (AAAA-MM-DD, AAAA-MM o DD/MM/AAAA; Enter = desde el principio)'
        $h = Read-Mes 'Fecha HASTA, incluida (Enter = sin límite)'
        if ($d -and $h -and (ConvertTo-FechaMenu $d) -gt (ConvertTo-FechaMenu $h -Fin)) {
            Write-Host '  DESDE es posterior a HASTA: escríbelas otra vez.' -ForegroundColor Yellow
            continue
        }
        return @($d, $h)
    }
}

function Read-MB {
    # Número de MB (admite 1,5 o 1.5). Enter = 0 (sin límite)
    param([string]$Pregunta)
    while ($true) {
        $txt = Read-Texto $Pregunta
        if ($txt -eq '') { return [double]0 }
        if ($txt -match '^[1-9]\d{0,2}(\.\d{3})+$') { Write-Host '  ¿Separador de miles? Escribe el número sin puntos (ej. 1000) y los decimales con coma (1,5).' -ForegroundColor Yellow; continue }
        $r = $txt.Replace(',', '.')
        $n = [double]0
        if ([double]::TryParse($r, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n) -and $n -ge 0 -and $n -le 10000000) { return $n }
        Write-Host '  Escribe un número de MB (ej. 1,5 o 50), o Enter para no filtrar.' -ForegroundColor Yellow
    }
}

function Read-Entero {
    param([string]$Pregunta, [int]$PorDefecto, [int]$Minimo = 1)
    while ($true) {
        $r = Read-Texto $Pregunta "$PorDefecto"
        $n = 0
        if ([int]::TryParse($r, [ref]$n) -and $n -ge $Minimo) { return $n }
        Write-Host "  Escribe un número entero mayor o igual que $Minimo." -ForegroundColor Yellow
    }
}

function Wait-Tecla {
    [void](Read-Host "`n  Pulsa Enter para volver al menú")
}

# ============================== entorno: unidades y móvil ==============================
function Get-Unidades {
    try { return @([IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady }) } catch { return @() }
}

function Format-Unidad {
    param($U)
    $tipo = switch ([string]$U.DriveType) { 'Removable' { 'USB/extraíble' } 'Network' { 'red' } 'Fixed' { 'disco' } default { [string]$U.DriveType } }
    $etiqueta = ''
    try { $etiqueta = $U.VolumeLabel } catch { $etiqueta = '' }
    return ("{0} {1} ({2}, {3:N0} GB libres)" -f $U.Name, $etiqueta, $tipo, ($U.AvailableFreeSpace / 1GB)).Replace('  ', ' ')
}

function Find-Adb {
    $c = Get-Command adb -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Path }
    $rutas = @([IO.Path]::Combine($CARPETA_SCRIPTS, 'platform-tools', 'adb.exe'))
    if ($env:USERPROFILE) { $rutas += [IO.Path]::Combine($env:USERPROFILE, 'Desktop', '0.Escritorio', 'BK2', '_tools', 'platform-tools', 'adb.exe') }
    foreach ($r in $rutas) {
        if (Test-Path -LiteralPath $r -PathType Leaf) { return $r }
    }
    return $null
}

function Get-Moviles {
    $adb = Find-Adb
    if (-not $adb) { return [pscustomobject]@{ Adb = $null; Lista = @() } }
    $lineas = @(& $adb devices 2>$null)
    $lista = @(foreach ($l in $lineas) { if ("$l" -match '^(\S+)\s+(device|unauthorized|offline)\b') { [pscustomobject]@{ Serial = $Matches[1]; Estado = $Matches[2] } } })
    return [pscustomobject]@{ Adb = $adb; Lista = $lista }
}

# ============================== elegir origen y destino ==============================
function Select-Origen {
    param([hashtable]$Cfg)
    $tipo = Read-Opcion 'ORIGEN: ¿de dónde copias?' @(
        @{ T = 'Móvil por cable USB (ADB)'; V = 'adb' }
        @{ T = 'Carpeta del PC, disco externo o USB'; V = 'local' }
        @{ T = 'Carpeta de red (\\servidor\recurso)'; V = 'unc' }
    ) -PermitirVolver
    if ($null -eq $tipo) { return $null }
    if ($tipo -eq 'adb') {
        $m = Get-Moviles
        if (-not $m.Adb) { Write-Host '  No encuentro adb.exe (platform-tools). Instálalo o cópialo en BK2\_tools\platform-tools.' -ForegroundColor Red; return $null }
        $listos = @($m.Lista | Where-Object { $_.Estado -eq 'device' })
        if ($listos.Count -eq 0) {
            Write-Host '  No hay ningún móvil listo. Conéctalo, desbloquéalo, elige "Transferir archivos" y acepta la depuración USB.' -ForegroundColor Red
            if (@($m.Lista | Where-Object { $_.Estado -eq 'unauthorized' }).Count -gt 0) { Write-Host '  (Hay un móvil sin autorizar: mira la pantalla del móvil.)' -ForegroundColor Yellow }
            return $null
        }
        $serial = ''
        if ($listos.Count -gt 1) { $serial = Read-Opcion 'Hay varios móviles. ¿Cuál?' @($listos | ForEach-Object { @{ T = $_.Serial; V = $_.Serial } }) }
        $ops = @($CARPETAS_MOVIL | ForEach-Object { @{ T = "$($_.T)   $($_.Ruta)"; V = $_ } })
        $ops += @{ T = 'Otra ruta del móvil (escribirla)'; V = 'otra' }
        $elegida = Read-Opcion 'CARPETA DEL MÓVIL' $ops -PermitirVolver
        if ($null -eq $elegida) { return $null }
        if ($elegida -is [string]) {
            $ruta = Read-Texto 'Ruta del móvil (ej. /sdcard/DCIM/Camera)'
            if (-not $ruta.StartsWith('/')) { Write-Host '  La ruta debe empezar por /' -ForegroundColor Yellow; return $null }
            $hoja = ($ruta.TrimEnd('/') -split '/')[-1]
            return @{ Origen = "adb:$ruta"; Dispositivo = $serial; Hoja = $hoja; EsAdb = $true }
        }
        return @{ Origen = "adb:$($elegida.Ruta)"; Dispositivo = $serial; Hoja = $elegida.Dest; EsAdb = $true }
    }
    $ops = New-Object System.Collections.Generic.List[object]
    if ($tipo -eq 'local') {
        foreach ($o in @($Cfg.Origenes | Where-Object { $_ -notlike 'adb:*' -and $_ -notlike '\\*' })) { $ops.Add(@{ T = "Reciente: $o"; V = $o }) }
        if (Test-Path -LiteralPath $BASE_BK2) {
            foreach ($d in @(Get-ChildItem -LiteralPath $BASE_BK2 -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '_*' })) { $ops.Add(@{ T = "BK2: $($d.FullName)"; V = $d.FullName }) }
        }
        foreach ($esp in @('MyPictures', 'Desktop', 'MyVideos', 'MyDocuments')) {
            try { $r = [Environment]::GetFolderPath($esp); if ($r) { $ops.Add(@{ T = "$esp`: $r"; V = $r }) } } catch { Write-Verbose "Sin carpeta $esp" }
        }
        foreach ($u in (Get-Unidades | Where-Object { [string]$_.DriveType -eq 'Removable' })) { $ops.Add(@{ T = "Unidad $(Format-Unidad $u)"; V = $u.RootDirectory.FullName }) }
    }
    else {
        foreach ($o in @($Cfg.Origenes | Where-Object { $_ -like '\\*' })) { $ops.Add(@{ T = "Reciente: $o"; V = $o }) }
        foreach ($u in (Get-Unidades | Where-Object { [string]$_.DriveType -eq 'Network' })) { $ops.Add(@{ T = "Unidad de red $(Format-Unidad $u)"; V = $u.RootDirectory.FullName }) }
    }
    $ops.Add(@{ T = 'Escribir la ruta a mano'; V = '' })
    while ($true) {
        $ruta = Read-Opcion 'CARPETA DE ORIGEN' $ops.ToArray() -PermitirVolver
        if ($null -eq $ruta) { return $null }
        if ($ruta -eq '') { $ruta = Read-Texto 'Ruta de la carpeta de origen' }
        if ($ruta -and (Test-Path -LiteralPath $ruta -PathType Container)) {
            $hoja = (Split-Path -Leaf $ruta.TrimEnd('\')) -replace '[:\\]', ''
            if (-not $hoja) { $hoja = 'Traspaso' }
            return @{ Origen = $ruta; Dispositivo = ''; Hoja = $hoja; EsAdb = $false }
        }
        Write-Host "  '$ruta' no existe o no es una carpeta." -ForegroundColor Yellow
    }
}

function Select-Destino {
    param([hashtable]$Cfg, [string]$Hoja)
    if (-not $Hoja) { $Hoja = 'Traspaso' }
    $ops = New-Object System.Collections.Generic.List[object]
    foreach ($d in @($Cfg.Destinos)) { $ops.Add(@{ T = "Reciente: $d"; V = $d }) }
    if (Test-Path -LiteralPath 'D:\') { $ops.Add(@{ T = "Disco BK2: $BASE_BK2\$Hoja"; V = "$BASE_BK2\$Hoja" }) }
    try { $img = [Environment]::GetFolderPath('MyPictures'); if ($img) { $ops.Add(@{ T = "Imágenes: $img\Traspaso\$Hoja"; V = "$img\Traspaso\$Hoja" }) } } catch { Write-Verbose 'Sin carpeta Imágenes' }
    foreach ($u in (Get-Unidades | Where-Object { [string]$_.DriveType -in @('Removable', 'Network') -or ([string]$_.DriveType -eq 'Fixed' -and $_.Name -notlike 'C:*') })) {
        $ops.Add(@{ T = "Unidad $(Format-Unidad $u) -> $($u.Name)Traspaso\$Hoja"; V = "$($u.RootDirectory.FullName)Traspaso\$Hoja" })
    }
    $ops.Add(@{ T = 'Escribir la ruta a mano (local, USB o \\servidor\recurso)'; V = '' })
    while ($true) {
        $ruta = Read-Opcion 'DESTINO: ¿dónde lo guardas? (se crea si no existe)' $ops.ToArray() -PermitirVolver
        if ($null -eq $ruta) { return $null }
        if ($ruta -eq '') { $ruta = Read-Texto 'Ruta de destino' }
        if (-not $ruta) { continue }
        $raiz = $null
        try { $raiz = [IO.Path]::GetPathRoot($ruta) } catch { $raiz = $null }
        if ($raiz -and (Test-Path -LiteralPath $raiz)) { return $ruta }
        Write-Host "  La unidad o el recurso de '$ruta' no está disponible. Conéctalo o elige otro." -ForegroundColor Yellow
    }
}

# ============================== ejecutar el motor ==============================
function Format-Comando {
    param([hashtable]$P)
    $partes = New-Object System.Collections.Generic.List[string]
    $partes.Add('.\Traspasar-Archivos.ps1')
    foreach ($k in $ORDEN_PARAMETROS) {
        if (-not $P.ContainsKey($k)) { continue }
        $v = $P[$k]
        if ($null -eq $v -or "$v" -eq '') { continue }
        if ($v -is [bool]) { if ($v) { $partes.Add("-$k") }; continue }
        if ($v -is [array]) { $partes.Add("-$k " + ((@($v) | ForEach-Object { "'" + ([string]$_).Replace("'", "''") + "'" }) -join ',')); continue }
        $partes.Add("-$k '" + ([string]$v).Replace("'", "''") + "'")
    }
    return ($partes -join ' ')
}

function Get-ParametrosLimpios {
    # Quita vacíos y claves internas antes de llamar al motor
    param([hashtable]$P)
    $h = @{}
    foreach ($k in $P.Keys) {
        if ($ORDEN_PARAMETROS -notcontains $k) { continue }
        $v = $P[$k]
        if ($null -eq $v -or "$v" -eq '') { continue }
        if ($v -is [bool] -and -not $v) { continue }
        $h[$k] = $v
    }
    return $h
}

function Invoke-Motor {
    param([hashtable]$P)
    $limpios = Get-ParametrosLimpios $P
    Write-Host "`n  Comando: $(Format-Comando $limpios)" -ForegroundColor DarkGray
    $global:LASTEXITCODE = 0
    & $Motor @limpios
    $codigo = $global:LASTEXITCODE
    switch ($codigo) {
        0 { Write-Host "`n  Terminado sin fallos (código 0)." -ForegroundColor Green }
        1 { Write-Host "`n  Terminado CON FALLOS o AVISOS (código 1): mira los mensajes de arriba y, si se llegó a copiar, el registro (opción 6). Al relanzar, lo hecho no se repite." -ForegroundColor Red }
        3 { Write-Host "`n  Cancelado por ti entre bloques (código 3). Lo hecho está verificado; repite para seguir." -ForegroundColor Yellow }
        default { Write-Host "`n  No se ejecutó (código $codigo): revisa el mensaje de error de arriba." -ForegroundColor Yellow }
    }
    return $codigo
}

function Invoke-ConSimulacion {
    param([hashtable]$P, [hashtable]$Cfg)
    $accion = Read-Opcion '¿QUÉ HACEMOS?' @(
        @{ T = 'Simular primero (-WhatIf: no copia ni borra nada) y luego decidir'; V = 'simular' }
        @{ T = 'Ejecutar ya'; V = 'ejecutar' }
        @{ T = 'Solo comparar: qué falta por pasar y % hecho'; V = 'comparar' }
    ) -PermitirVolver
    if ($null -eq $accion) { return }
    $Cfg.Ultimo = $P
    $Cfg.Destinos = Add-Reciente $Cfg.Destinos $P.Destino
    $Cfg.Origenes = Add-Reciente $Cfg.Origenes $P.Origen
    Save-Config $Cfg
    if ($accion -eq 'comparar') {
        $c = $P.Clone(); $c.Remove('Modo'); $c['SoloComparar'] = $true
        [void](Invoke-Motor $c); return
    }
    if ($accion -eq 'simular') {
        $s = $P.Clone(); $s['WhatIf'] = $true
        $codigo = Invoke-Motor $s
        if ($codigo -ne 0) { return }
        if (-not (Read-SiNo '¿Ejecutar ahora de verdad?' $false)) { Write-Host '  Cancelado: no se ha tocado nada.' -ForegroundColor Yellow; return }
    }
    if ($P.Modo -eq 'Mover') { Write-Host '  Modo MOVER: el motor te pedirá escribir BORRAR antes de borrar nada del origen.' -ForegroundColor Red }
    [void](Invoke-Motor $P)
}

# ============================== asistente ==============================
function New-Traspaso {
    param([hashtable]$Cfg)
    $o = Select-Origen $Cfg
    if ($null -eq $o) { return }
    $destino = Select-Destino $Cfg $o.Hoja
    if ($null -eq $destino) { return }
    $p = @{ Origen = $o.Origen; Destino = $destino }
    if ($o.Dispositivo) { $p.Dispositivo = $o.Dispositivo }

    $p.Modo = Read-Opcion 'MODO' @(
        @{ T = 'Copiar (no toca el origen)'; V = 'Copiar' }
        @{ T = 'Mover (copia, verifica y BORRA del origen lo verificado; pide escribir BORRAR)'; V = 'Mover' }
    )
    $p.Organizar = Read-Opcion 'ORGANIZACIÓN EN EL DESTINO' @(
        @{ T = 'Año y mes: <Destino>\2024\2024-07\  (como BK2)'; V = 'AnioMes' }
        @{ T = 'Solo año: <Destino>\2024\'; V = 'Anio' }
        @{ T = 'Todo junto en <Destino>'; V = 'Ninguna' }
        @{ T = 'Conservar las subcarpetas del origen'; V = 'Original' }
    )
    if ($p.Organizar -in @('AnioMes', 'Anio')) {
        $p.FechaPor = Read-Opcion 'FECHA QUE DECIDE LA CARPETA' @(
            @{ T = 'La del nombre (Screenshot_2024-07-..., IMG_20240705...); si no la lleva, la de modificación'; V = 'Nombre' }
            @{ T = 'La de modificación (criterio de BK2, para seguir igual que antes)'; V = 'Modificacion' }
        )
    }
    $tipos = Read-Opcion 'QUÉ ARCHIVOS' @(
        @{ T = 'Todos'; V = '' }
        @{ T = "Imágenes ($EXT_IMAGENES)"; V = $EXT_IMAGENES }
        @{ T = "Vídeos ($EXT_VIDEOS)"; V = $EXT_VIDEOS }
        @{ T = 'Imágenes y vídeos'; V = "$EXT_IMAGENES,$EXT_VIDEOS" }
        @{ T = 'Escribir las extensiones (ej. pdf,docx)'; V = 'manual' }
    )
    if ($tipos -eq 'manual') { $tipos = Read-Texto 'Extensiones separadas por comas' }
    if ($tipos) { $p.Extensiones = $tipos }
    $rango = Read-Opcion 'QUÉ FECHAS O NOMBRES' @(
        @{ T = 'Todo'; V = 'todo' }
        @{ T = 'Un año'; V = 'anio' }
        @{ T = 'Desde / hasta un mes o día (AAAA-MM)'; V = 'rango' }
        @{ T = 'Por nombre (comodín, ej. Screenshot_2024*; o re:expresión)'; V = 'patron' }
    )
    switch ($rango) {
        'anio' { $p.Anio = @(Read-Entero 'Año (ej. 2024)' ((Get-Date).Year - 1) 1990) }
        'rango' { $dh = Read-Rango; if ($dh[0]) { $p.Desde = $dh[0] }; if ($dh[1]) { $p.Hasta = $dh[1] } }
        'patron' { $p.Patron = Read-Texto 'Patrón' }
        default { }
    }
    $p.Recursivo = Read-SiNo '¿Incluir subcarpetas del origen?' (-not $o.EsAdb)
    if (Read-SiNo '¿Opciones avanzadas (excluir patrones, incluir ocultos)?' $false) {
        $ex = Read-Texto 'Patrones a excluir, separados por comas (ej. *.tmp,_index/*; Enter = ninguno)'
        if ($ex) { $p.Excluir = @($ex -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        $p.IncluirOcultos = Read-SiNo '¿Incluir ocultos (.trashed-* = papelera de Android, .thumbnails, Thumbs.db)?' $false
        $mb = Read-MB 'Solo archivos de cuántos MB o más (Enter = todos)'
        if ($mb -gt 0) { $p.MinMB = $mb }
    }
    $p.Hash = (Read-Opcion 'VERIFICACIÓN' @(
            @{ T = 'Tamaño (rápido). Al MOVER se usa SHA256 siempre, elijas lo que elijas'; V = $false }
            @{ T = 'Tamaño + SHA256 también al copiar (más lento, máxima seguridad)'; V = $true }
        ))
    $ritmo = Read-Opcion 'RITMO' @(
        @{ T = 'Bloques de 200 con pausa entre bloques'; V = @(200, $false) }
        @{ T = 'Bloques de 500 con pausa'; V = @(500, $false) }
        @{ T = 'Bloques de 1000 sin pausa'; V = @(1000, $true) }
        @{ T = 'Todo seguido sin pausa'; V = @(500, $true) }
    )
    $p.Bloque = [int]$ritmo[0]
    $p.SinPausa = [bool]$ritmo[1]
    $tope = Read-Opcion 'TOPE PARA ESTA VEZ' @(
        @{ T = 'Sin tope'; V = 'no' }
        @{ T = 'Un número de archivos'; V = 'n' }
        @{ T = 'Un máximo de GB'; V = 'gb' }
    )
    if ($tope -eq 'n') { $p.MaxArchivos = Read-Entero 'Cuántos archivos' 500 }
    if ($tope -eq 'gb') { $p.MaxGB = Read-Entero 'Cuántos GB' 10 }
    $p.Informe = Read-Opcion 'INFORME (el registro CSV se guarda siempre en <Destino>\_traspaso)' @(
        @{ T = 'Solo CSV (se abre con Excel)'; V = '' }
        @{ T = 'CSV + HTML (para verlo en el navegador)'; V = @('Html') }
        @{ T = 'CSV + JSON'; V = @('Json') }
        @{ T = 'CSV + HTML + JSON'; V = @('Html', 'Json') }
    )
    Write-Host "`n  RESUMEN: $($p.Origen)  ->  $($p.Destino)  ·  $($p.Modo)  ·  $($p.Organizar)" -ForegroundColor White
    Invoke-ConSimulacion $p $Cfg
}

function New-TraspasoRapido {
    # Solo lo esencial: origen, destino, desde, hasta y tamaño mínimo. El resto, valores recomendados.
    param([hashtable]$Cfg)
    Write-Host "`n  TRASPASO RÁPIDO: origen, destino, fechas y tamaño (el resto con los valores recomendados)." -ForegroundColor Cyan
    $o = Select-Origen $Cfg
    if ($null -eq $o) { return }
    $destino = Select-Destino $Cfg $o.Hoja
    if ($null -eq $destino) { return }
    $p = @{ Origen = $o.Origen; Destino = $destino; Organizar = 'AnioMes'; FechaPor = 'Nombre'; Bloque = 500; SinPausa = $true }
    if ($o.Dispositivo) { $p.Dispositivo = $o.Dispositivo }
    $p.Recursivo = Read-SiNo '¿Incluir subcarpetas del origen?' (-not $o.EsAdb)
    $dh = Read-Rango
    if ($dh[0]) { $p.Desde = $dh[0] }
    if ($dh[1]) { $p.Hasta = $dh[1] }
    $mb = Read-MB 'Solo archivos de cuántos MB o más (ej. 1,5; Enter = todos)'
    if ($mb -gt 0) { $p.MinMB = $mb }
    $p.Modo = Read-Opcion 'MODO' @(
        @{ T = 'Copiar (no toca el origen)'; V = 'Copiar' }
        @{ T = 'Mover (copia, verifica por SHA256 y BORRA del origen; pide escribir BORRAR)'; V = 'Mover' }
    )
    $txtD = 'el principio'; if ($p.ContainsKey('Desde')) { $txtD = $p.Desde }
    $txtH = 'sin límite'; if ($p.ContainsKey('Hasta')) { $txtH = $p.Hasta }
    $txtMB = 'cualquier tamaño'; if ($p.ContainsKey('MinMB')) { $txtMB = "$($p.MinMB) MB o más" }
    Write-Host "`n  RESUMEN: $($p.Origen)  ->  $($p.Destino)  ·  $($p.Modo)  ·  de $txtD a $txtH  ·  $txtMB" -ForegroundColor White
    Write-Host '  (Carpetas <Destino>\AAAA\AAAA-MM, fecha del nombre, bloques de 500 sin pausa, CSV en <Destino>\_traspaso)' -ForegroundColor DarkGray
    Invoke-ConSimulacion $p $Cfg
}

function Get-OrigenDestino {
    param([hashtable]$Cfg, [switch]$SinDestino)
    if ($Cfg.Ultimo -and $Cfg.Ultimo.ContainsKey('Origen')) {
        $txt = "El último: $($Cfg.Ultimo.Origen)"
        if (-not $SinDestino) { $txt += "  ->  $($Cfg.Ultimo.Destino)" }
        $usar = Read-Opcion '¿QUÉ ORIGEN?' @(@{ T = $txt; V = $true }, @{ T = 'Elegir otro'; V = $false }) -PermitirVolver
        if ($null -eq $usar) { return $null }
        if ($usar) {
            $r = @{ Origen = $Cfg.Ultimo.Origen; Destino = $Cfg.Ultimo.Destino }
            foreach ($k in @('Dispositivo', 'Extensiones', 'Patron', 'Excluir', 'Anio', 'Desde', 'Hasta', 'MinMB', 'MaxMB', 'Recursivo', 'IncluirOcultos', 'Organizar', 'FechaPor')) { if ($Cfg.Ultimo.ContainsKey($k)) { $r[$k] = $Cfg.Ultimo[$k] } }
            return $r
        }
    }
    $o = Select-Origen $Cfg
    if ($null -eq $o) { return $null }
    $r = @{ Origen = $o.Origen; Recursivo = (Read-SiNo '¿Incluir subcarpetas?' (-not $o.EsAdb)) }
    if ($o.Dispositivo) { $r.Dispositivo = $o.Dispositivo }
    if (-not $SinDestino) {
        $d = Select-Destino $Cfg $o.Hoja
        if ($null -eq $d) { return $null }
        $r.Destino = $d
    }
    return $r
}

# ============================== estado y registros ==============================
function Select-CarpetaDestino {
    param([hashtable]$Cfg)
    $ops = New-Object System.Collections.Generic.List[object]
    $vistos = @{}
    foreach ($d in @($Cfg.Destinos)) { if (-not $vistos.ContainsKey($d.ToLowerInvariant())) { $vistos[$d.ToLowerInvariant()] = $true; $ops.Add(@{ T = "Reciente: $d"; V = $d }) } }
    if (Test-Path -LiteralPath $BASE_BK2) {
        foreach ($e in @(Get-ChildItem -Path "$BASE_BK2\*\_traspaso\ESTADO.json" -ErrorAction SilentlyContinue)) {
            $d = $e.Directory.Parent.FullName
            if (-not $vistos.ContainsKey($d.ToLowerInvariant())) { $vistos[$d.ToLowerInvariant()] = $true; $ops.Add(@{ T = "BK2: $d"; V = $d }) }
        }
    }
    $ops.Add(@{ T = 'Escribir la carpeta de destino'; V = '' })
    $r = Read-Opcion '¿DE QUÉ DESTINO?' $ops.ToArray() -PermitirVolver
    if ($null -eq $r) { return $null }
    if ($r -eq '') { $r = Read-Texto 'Carpeta de destino' }
    return $r
}

function Show-Barra {
    param([double]$Porcentaje)
    $n = [int][math]::Floor([math]::Max(0, [math]::Min(100, $Porcentaje)) / 5)
    return '[' + ('#' * $n) + ('-' * (20 - $n)) + ']'
}

function Show-EstadoUnaVez {
    param([string]$Destino)
    $json = [IO.Path]::Combine($Destino, '_traspaso', 'ESTADO.json')
    $hay = $false
    if (Test-Path -LiteralPath $json) {
        $hay = $true
        try {
            $e = Get-Content -LiteralPath $json -Raw -Encoding UTF8 | ConvertFrom-Json
            $color = 'White'
            if ($e.Estado -like '*FALLOS*' -or $e.Estado -eq 'INTERRUMPIDO') { $color = 'Red' } elseif ($e.Estado -eq 'TERMINADO') { $color = 'Green' }
            Write-Host ("  {0}  {1}%   {2}" -f (Show-Barra ([double]$e.Porcentaje)), $e.Porcentaje, $e.Estado) -ForegroundColor $color
            Write-Host ("  Hechos {0} de {1} · faltan {2} · {3} de {4} MB · ETA {5} min · actualizado {6}" -f $e.Procesados, $e.Total, $e.Faltan, $e.MBHechos, $e.MBTotal, $(if ($null -eq $e.EtaMin) { '-' } else { $e.EtaMin }), $e.Actualizado)
            Write-Host ("  Copiados {0} · Ya existían {1} · Renombrados {2} · Fallos {3} · Borrados en origen {4} · Errores de borrado {5}" -f $e.Copiados, $e.YaExistian, $e.Conflictos, $e.Fallos, $e.BorradosOrigen, $e.ErroresBorrado)
            Write-Host "  Origen: $($e.Origen)  ·  Modo: $($e.Modo)" -ForegroundColor DarkGray
        }
        catch { Write-Host "  No se pudo leer $json (puede estar escribiéndose; reintenta)." -ForegroundColor Yellow }
    }
    foreach ($pr in @(Get-ChildItem -LiteralPath ([IO.Path]::Combine($Destino, '_index')) -Filter '*.PROGRESO.txt' -ErrorAction SilentlyContinue)) {
        $hay = $true
        Write-Host "  BK2 (herramienta anterior): $(Get-Content -LiteralPath $pr.FullName -Raw -Encoding UTF8)".TrimEnd() -ForegroundColor DarkCyan
    }
    if (-not $hay) { Write-Host "  No hay estado en '$Destino' (aún no se ha traspasado nada ahí)." -ForegroundColor Yellow }
}

function Show-Estado {
    param([hashtable]$Cfg)
    $d = Select-CarpetaDestino $Cfg
    if (-not $d) { return }
    $vivo = -not $ES_ISE
    if ($vivo) { try { [void][Console]::KeyAvailable } catch { $vivo = $false } }
    if (-not $vivo) {
        # ISE (o sin consola): se actualiza a petición
        while ($true) {
            Write-Host ("`n  --- {0} ---" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
            Show-EstadoUnaVez $d
            if ((Read-Host '  Enter = actualizar · n = volver al menú').Trim() -match '^[nN]') { return }
        }
    }
    Write-Host "`n  Estado en vivo de $d (se actualiza cada 5 s; pulsa cualquier tecla para salir)" -ForegroundColor Cyan
    while ($true) {
        Write-Host ("`n  --- {0} ---" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
        Show-EstadoUnaVez $d
        for ($i = 0; $i -lt 50; $i++) {
            Start-Sleep -Milliseconds 100
            if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); return }
        }
    }
}

function Show-UltimoRegistro {
    param([hashtable]$Cfg)
    $d = Select-CarpetaDestino $Cfg
    if (-not $d) { return }
    $dir = [IO.Path]::Combine($d, '_traspaso')
    $f = Get-ChildItem -LiteralPath $dir -Filter 'registro_*.csv' -ErrorAction SilentlyContinue | Sort-Object -Property Name | Select-Object -Last 1
    if (-not $f) { Write-Host "  No hay registros en $dir." -ForegroundColor Yellow; Wait-Tecla; return }
    $filas = @(Import-Csv -LiteralPath $f.FullName -Delimiter ';' -Encoding UTF8)
    Write-Host "`n  Registro: $($f.FullName)  ($($filas.Count) filas)" -ForegroundColor Cyan
    $filas | Group-Object -Property Resultado | ForEach-Object { Write-Host ("    {0,-22} {1,8}" -f $_.Name, $_.Count) }
    $filas | Group-Object -Property EstadoOrigen | ForEach-Object { Write-Host ("    {0,-22} {1,8}" -f $_.Name, $_.Count) }
    $mal = @($filas | Where-Object { $_.Resultado -eq 'FALLO' -or $_.EstadoOrigen -eq 'ERROR_BORRADO' })
    if ($mal.Count -gt 0) {
        Write-Host "`n  Para revisar ($($mal.Count)), primeros 20:" -ForegroundColor Red
        $mal | Select-Object -First 20 | ForEach-Object { Write-Host "    $($_.Resultado)/$($_.EstadoOrigen)  $($_.RutaOrigen)  ·  $($_.Detalle)" }
    }
    $html = Get-ChildItem -LiteralPath $dir -Filter 'informe_*.html' -ErrorAction SilentlyContinue | Sort-Object -Property Name | Select-Object -Last 1
    if ($html -and (Read-SiNo "¿Abrir el informe HTML ($($html.Name)) en el navegador?" $false)) { Invoke-Item -LiteralPath $html.FullName }
    elseif (Read-SiNo '¿Abrir la carpeta _traspaso en el Explorador?' $false) { Invoke-Item -LiteralPath $dir }
    Wait-Tecla
}

function Show-Movil {
    $m = Get-Moviles
    if (-not $m.Adb) { Write-Host '  No encuentro adb.exe (Android platform-tools).' -ForegroundColor Red; Wait-Tecla; return }
    Write-Host "`n  adb: $($m.Adb)" -ForegroundColor DarkGray
    if ($m.Lista.Count -eq 0) { Write-Host '  Ningún móvil. Conéctalo, desbloquéalo, elige "Transferir archivos" y acepta la depuración USB.' -ForegroundColor Yellow }
    foreach ($x in $m.Lista) {
        $color = 'Green'
        $nota = 'listo'
        if ($x.Estado -eq 'unauthorized') { $color = 'Yellow'; $nota = 'sin autorizar: acepta el aviso en el móvil' }
        elseif ($x.Estado -ne 'device') { $color = 'Red'; $nota = $x.Estado }
        Write-Host "  $($x.Serial)  ->  $nota" -ForegroundColor $color
    }
    Wait-Tecla
}

# ============================== menú principal ==============================
$cfg = Read-Config
while ($true) {
    Write-Host "`n================  TRASPASO DE ARCHIVOS  (v3)  ================" -ForegroundColor Cyan
    $hayUltimo = ($null -ne $cfg.Ultimo -and $cfg.Ultimo.ContainsKey('Origen'))
    $textoUltimo = 'Repetir el último traspaso'
    if ($hayUltimo) { $textoUltimo += "  ($($cfg.Ultimo.Origen) -> $($cfg.Ultimo.Destino))" }
    $opcion = Read-Opcion 'MENÚ PRINCIPAL' @(
        @{ T = 'Nuevo traspaso (asistente completo)'; V = 'nuevo' }
        @{ T = $textoUltimo; V = 'repetir' }
        @{ T = 'Inventario de un origen (archivos y MB por año y mes)'; V = 'inventario' }
        @{ T = 'Comparar origen y destino (qué falta y % hecho)'; V = 'comparar' }
        @{ T = 'Ver el estado de las transferencias (en vivo)'; V = 'estado' }
        @{ T = 'Ver el último registro (resumen y fallos)'; V = 'registro' }
        @{ T = 'Comprobar el móvil (adb devices)'; V = 'movil' }
        @{ T = 'Ayuda completa del motor'; V = 'ayuda' }
        @{ T = 'Traspaso rápido (origen, destino, desde, hasta y MB mínimos)'; V = 'rapido' }
        @{ T = 'Salir'; V = 'salir' }
    )
    switch ($opcion) {
        'rapido' { New-TraspasoRapido $cfg }
        'nuevo' { New-Traspaso $cfg }
        'repetir' {
            if (-not $hayUltimo) { Write-Host '  Aún no hay ningún traspaso guardado.' -ForegroundColor Yellow }
            else { Write-Host "`n  Último: $(Format-Comando (Get-ParametrosLimpios $cfg.Ultimo))" -ForegroundColor White; Invoke-ConSimulacion $cfg.Ultimo $cfg }
        }
        'inventario' {
            $od = Get-OrigenDestino $cfg -SinDestino
            if ($od) { $od.Remove('Destino'); $od.SoloInventario = $true; [void](Invoke-Motor $od); Wait-Tecla }
        }
        'comparar' {
            $od = Get-OrigenDestino $cfg
            if ($od) { $od.SoloComparar = $true; [void](Invoke-Motor $od); Wait-Tecla }
        }
        'estado' { Show-Estado $cfg }
        'registro' { Show-UltimoRegistro $cfg }
        'movil' { Show-Movil }
        'ayuda' { Get-Help $Motor -Full | Out-String -Width 120 | Write-Host; Wait-Tecla }
        'salir' { exit 0 }
        default { Write-Host '  Opción no válida.' -ForegroundColor Yellow }
    }
}
