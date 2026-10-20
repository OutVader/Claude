<#
.SYNOPSIS
  Pruebas de Traspasar-Archivos.ps1 con un móvil simulado (adb-falso.ps1) y carpetas locales.
.DESCRIPTION
  Todo ocurre en una carpeta temporal de pruebas (%TEMP%\traspaso-pruebas-*), que se borra al
  terminar salvo con -Conservar. No toca el móvil real ni ninguna carpeta del usuario.
  Termina con exit 0 si todo pasa, exit 1 si falla algún caso y exit 3 si no falla nada pero
  algún caso no se pudo probar en este equipo (OMITIDO: p. ej. sin permiso para crear enlaces).
.EXAMPLE
  .\Probar-Traspaso.ps1
.EXAMPLE
  .\Probar-Traspaso.ps1 -Conservar     # deja la carpeta de pruebas para inspeccionarla
#>
[CmdletBinding()]
param([switch]$Conservar)
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version 2.0

$motor = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Traspasar-Archivos.ps1'
$menu = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Menu-Traspaso.ps1'
$falso = Join-Path $PSScriptRoot 'adb-falso.ps1'
if (-not (Test-Path -LiteralPath $motor)) { $motor = [IO.Path]::Combine((Split-Path $PSScriptRoot -Parent), 'scripts', 'Traspasar-Archivos.ps1') }
if (-not (Test-Path -LiteralPath $menu)) { $menu = [IO.Path]::Combine((Split-Path $PSScriptRoot -Parent), 'scripts', 'Menu-Traspaso.ps1') }
$base = [IO.Path]::Combine([IO.Path]::GetTempPath(), ('traspaso-pruebas-' + [guid]::NewGuid().ToString('N').Substring(0, 8)))
[void][IO.Directory]::CreateDirectory($base)
$resultados = New-Object System.Collections.Generic.List[object]
$S = [IO.Path]::DirectorySeparatorChar

function P {
    # Une segmentos de ruta con el separador del sistema
    param([string[]]$Partes)
    $r = $Partes[0]
    foreach ($x in ($Partes | Select-Object -Skip 1)) { $r = [IO.Path]::Combine($r, $x) }
    return $r
}

function New-Archivo {
    param([string]$Ruta, [int]$Bytes, [datetime]$Fecha, [int]$Semilla = 1)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Ruta))
    $b = New-Object byte[] $Bytes
    (New-Object System.Random $Semilla).NextBytes($b)
    [IO.File]::WriteAllBytes($Ruta, $b)
    [IO.File]::SetLastWriteTime($Ruta, $Fecha)
}

function New-Movil {
    # Crea el "móvil" en <base>\<nombre>\sdcard\Pictures\Screenshots y devuelve su raíz
    param([string]$Nombre)
    $raiz = P @($base, $Nombre)
    $ss = P @($raiz, 'sdcard', 'Pictures', 'Screenshots')
    New-Archivo (P @($ss, 'Screenshot_2023-03-15-10-20-30-123_com.app.jpg')) 1500 ([datetime]'2023-03-15 10:20:30') 1
    New-Archivo (P @($ss, 'Screenshot_2023-12-31-23-59-59-000_com.app.png')) 1600 ([datetime]'2024-01-01 00:00:30') 2
    New-Archivo (P @($ss, 'Screenshot_20240705-101010.png')) 1700 ([datetime]'2024-07-05 10:10:10') 3
    New-Archivo (P @($ss, 'IMG_20240706_101010 con espacio.jpg')) 1800 ([datetime]'2024-07-06 10:10:10') 4
    New-Archivo (P @($ss, 'Captura añadida ñandú.png')) 1900 ([datetime]'2022-05-10 12:00:00') 5
    New-Archivo (P @($ss, "O'Brien_20240801_120000.jpg")) 2000 ([datetime]'2024-08-01 12:00:00') 6
    New-Archivo (P @($ss, '.trashed-1700000000-Screenshot_2023-01-01.jpg')) 2100 ([datetime]'2023-01-01') 7
    New-Archivo (P @($ss, 'VID_20240710_111111.mp4')) 2200 ([datetime]'2024-07-10 11:11:11') 8
    if ($HAY_RARO) { New-Archivo (P @($ss, 'raro:nombre_20240101_000000.png')) 2300 ([datetime]'2024-01-01') 9 }
    New-Archivo (P @($ss, 'sub', 'Screenshot_2024-02-02-02-02-02.jpg')) 2400 ([datetime]'2024-02-02 02:02:02') 10
    return $raiz
}
# Un nombre con ':' solo se puede crear fuera de Windows (en NTFS no es válido); en Windows ese caso no aplica
$HAY_RARO = ($env:OS -ne 'Windows_NT')
$EXTRA_RARO = [int]$HAY_RARO
$ARCHIVOS_VISIBLES = 7 + $EXTRA_RARO   # en la carpeta raíz, sin el oculto ni la subcarpeta
$TOTAL_MOVIL = 9 + $EXTRA_RARO         # todo lo que hay en la carpeta (también el oculto y la subcarpeta)

function Invoke-Motor {
    param([hashtable]$Parametros)
    $global:LASTEXITCODE = 99
    $salida = & $motor @Parametros *>&1 | Out-String
    return [pscustomobject]@{ Codigo = $global:LASTEXITCODE; Salida = $salida }
}

function Get-Registro {
    param([string]$Destino)
    $dir = P @($Destino, '_traspaso')
    $f = Get-ChildItem -LiteralPath $dir -Filter 'registro_*.csv' -ErrorAction SilentlyContinue | Sort-Object -Property Name | Select-Object -Last 1
    if (-not $f) { return @() }
    return @(Import-Csv -LiteralPath $f.FullName -Delimiter ';' -Encoding UTF8)
}

function Get-Archivos {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force | Where-Object { $_.FullName -notlike "*${S}_traspaso${S}*" })
}

function Test-Caso {
    param([string]$Nombre, [scriptblock]$Prueba)
    $ok = $false; $msg = ''; $r = $null
    try {
        $r = & $Prueba
        if ($r -is [array]) { $r = $r[-1] }
        if ($r -is [string] -and $r -eq 'OMITIDO') { $ok = $true }
        elseif ($r -eq $true) { $ok = $true } else { $msg = "devolvió: $r" }
    }
    catch { $msg = $_.Exception.Message }
    if ($r -is [string] -and $r -eq 'OMITIDO') {
        $resultados.Add([pscustomobject]@{ Caso = $Nombre; OK = $false; Omitido = $true; Detalle = 'no se puede probar en este equipo' })
        Write-Host "  [OMITIDO] $Nombre (no se puede probar en este equipo: NO cuenta como verde)" -ForegroundColor Yellow
        return
    }
    $resultados.Add([pscustomobject]@{ Caso = $Nombre; OK = $ok; Omitido = $false; Detalle = $msg })
    if ($ok) { Write-Host "  [OK]    $Nombre" -ForegroundColor Green } else { Write-Host "  [FALLO] $Nombre :: $msg" -ForegroundColor Red }
}

function Assert {
    param([bool]$Condicion, [string]$Mensaje)
    if (-not $Condicion) { throw $Mensaje }
}

$env:ADB_FALSO_DISPOSITIVOS = $null
$env:ADB_FALSO_FALLAR_PULL = $null
$env:ADB_FALSO_FALLAR_RM = $null
$env:ADB_FALSO_LOG = $null
$env:ADB_FALSO_FALLAR_FIND = $null
$env:ADB_FALSO_ARGMAX = $null
$ORIGEN_ADB = 'adb:/sdcard/Pictures/Screenshots'
Write-Host "Pruebas de Traspasar-Archivos · carpeta: $base" -ForegroundColor Cyan

# ---------------------------------------------------------------- análisis estático
Test-Caso 'T00 Sintaxis sin errores (motor, menú, tests y adb falso)' {
    foreach ($f in @($motor, $menu, $falso, $PSCommandPath)) {
        $tok = $null; $err = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tok, [ref]$err)
        Assert (@($err).Count -eq 0) "$f : $(@($err) -join ' | ')"
    }
    $true
}
Test-Caso 'T01 Codificación UTF-8 con BOM y CRLF en los .ps1' {
    foreach ($f in @($motor, $menu, $falso, $PSCommandPath)) {
        $b = [IO.File]::ReadAllBytes($f)
        Assert ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) "$f sin BOM"
        $t = [Text.Encoding]::UTF8.GetString($b)
        Assert (($t -split "`n").Count -eq ($t -split "`r`n").Count) "$f con saltos LF sueltos"
    }
    $true
}
Test-Caso 'T02 Ayuda completa (Get-Help -Full) con 6+ ejemplos' {
    $h = Get-Help $motor -Full
    Assert (@($h.examples.example).Count -ge 6) "ejemplos: $(@($h.examples.example).Count)"
    Assert ($h.Synopsis -like '*Copia o mueve*') 'sinopsis'
    Assert (@($h.parameters.parameter).Count -ge 20) 'parámetros documentados'
    $true
}

# ---------------------------------------------------------------- inventario y errores
$movil = New-Movil 'movil1'
$env:ADB_FALSO_RAIZ = $movil
Test-Caso 'T03 Inventario ADB por año (sin ocultos, no crea destino)' {
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    Assert ($r.Salida -match "$ARCHIVOS_VISIBLES tras los filtros") 'número de archivos'
    Assert ($r.Salida -match '2022') 'año 2022 (fecha de modificación)'
    Assert ($r.Salida -match 'Discrepan') 'columna Discrepan'
    $true
}
Test-Caso 'T04 Errores de entrada: código 2 y sin "ok"' {
    $r1 = Invoke-Motor @{ Origen = 'adb:/sdcard/NoExiste'; SoloInventario = $true; Adb = $falso }
    Assert ($r1.Codigo -eq 2) "origen adb inexistente: $($r1.Codigo)"
    $r2 = Invoke-Motor @{ Origen = (P @($base, 'no-existe')); Destino = (P @($base, 'd')); Adb = $falso }
    Assert ($r2.Codigo -eq 2) "origen local inexistente: $($r2.Codigo)"
    $r3 = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = (P @($base, 'd')); Desde = '2024-13'; Adb = $falso }
    Assert ($r3.Codigo -eq 2) "fecha mala: $($r3.Codigo)"
    $r4 = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = (P @($base, 'd')); Patron = 're:(['; Adb = $falso }
    Assert ($r4.Codigo -eq 2) "regex mala: $($r4.Codigo)"
    $env:ADB_FALSO_DISPOSITIVOS = '-'
    $r5 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
    $env:ADB_FALSO_DISPOSITIVOS = 'A1:device,B2:device'
    $r6 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
    $r7 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso; Dispositivo = 'B2' }
    $env:ADB_FALSO_DISPOSITIVOS = 'X9:unauthorized'
    $r8 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
    $env:ADB_FALSO_DISPOSITIVOS = $null
    Assert ($r5.Codigo -eq 2) "sin móvil: $($r5.Codigo)"
    Assert ($r6.Codigo -eq 2 -and $r6.Salida -match 'Dispositivo') "varios móviles: $($r6.Codigo)"
    Assert ($r7.Codigo -eq 0) "con -Dispositivo: $($r7.Codigo)"
    Assert ($r8.Codigo -eq 2 -and $r8.Salida -match 'autorizado') "sin autorizar: $($r8.Codigo)"
    $r11 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso; MinMB = -1 }
    Assert ($r11.Codigo -eq 2) "MinMB negativo: $($r11.Codigo)"
    $r14 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso; Hasta = '9999-12' }
    Assert ($r14.Codigo -eq 2) "año 9999: $($r14.Codigo)"
    $r13 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso; MinMB = 1e20 }
    Assert ($r13.Codigo -eq 2) "MinMB enorme: $($r13.Codigo)"
    $r12 = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso; MinMB = 5; MaxMB = 1 }
    Assert ($r12.Codigo -eq 2 -and $r12.Salida -match 'mayor que') "MinMB > MaxMB: $($r12.Codigo)"
    $r9 = Invoke-Motor @{ Origen = 'NOEXISTE:\fotos'; Destino = (P @($base, 'd')); SinPausa = $true }
    Assert ($r9.Codigo -eq 2 -and $r9.Salida -match 'no está disponible') "unidad de origen inexistente: $($r9.Codigo) $($r9.Salida)"
    $r10 = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = 'NOEXISTE:\copia'; Adb = $falso; SinPausa = $true }
    Assert ($r10.Codigo -eq 2 -and $r10.Salida -match 'no está disponible') "unidad de destino inexistente: $($r10.Codigo) $($r10.Salida)"
    Assert (-not (Test-Path -LiteralPath (P @($base, 'd')))) 'no debe crear el destino'
    foreach ($r in @($r1, $r2, $r3, $r4, $r5, $r6, $r8, $r9, $r10)) { Assert ($r.Salida -notmatch 'RESUMEN \(TERMINADO\)') 'no debe decir que terminó bien' }
    $true
}

# ---------------------------------------------------------------- -WhatIf
$dest1 = P @($base, 'destino1')
Test-Caso 'T05 -WhatIf no escribe nada (ni destino, ni CSV) y sale con 0' {
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $dest1; Adb = $falso; WhatIf = $true; SinPausa = $true }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    Assert ($r.Salida -match 'SIMULACIÓN') 'mensaje de simulación'
    Assert (-not (Test-Path -LiteralPath $dest1)) 'no debe crear el destino'
    $true
}

# ---------------------------------------------------------------- copia ADB
Test-Caso 'T06 Copiar ADB -> AAAA\AAAA-MM, tamaños iguales, origen intacto, nombres raros' {
    $env:ADB_FALSO_LOG = P @($base, 'adb-log1.txt')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $dest1; Adb = $falso; SinPausa = $true }
    $env:ADB_FALSO_LOG = $null
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    Assert (Test-Path -LiteralPath (P @($dest1, '2023', '2023-03', 'Screenshot_2023-03-15-10-20-30-123_com.app.jpg'))) 'fecha por nombre 2023-03'
    Assert (Test-Path -LiteralPath (P @($dest1, '2023', '2023-12', 'Screenshot_2023-12-31-23-59-59-000_com.app.png'))) 'nombre manda sobre modificación (2023-12)'
    Assert (Test-Path -LiteralPath (P @($dest1, '2022', '2022-05', 'Captura añadida ñandú.png'))) 'sin fecha en el nombre -> modificación (2022-05), con tildes'
    Assert (Test-Path -LiteralPath (P @($dest1, '2024', '2024-08', "O'Brien_20240801_120000.jpg"))) 'comilla simple'
    if ($HAY_RARO) { Assert (Test-Path -LiteralPath (P @($dest1, '2024', '2024-01', 'raro_nombre_20240101_000000.png'))) 'carácter no válido en Windows -> _' }
    Assert (Test-Path -LiteralPath (P @($dest1, '2024', '2024-07', 'IMG_20240706_101010 con espacio.jpg'))) 'espacios'
    $copias = Get-Archivos $dest1
    Assert ($copias.Count -eq $ARCHIVOS_VISIBLES) "copias: $($copias.Count)"
    Assert (@($copias | Where-Object { $_.Name -like '.trashed*' }).Count -eq 0) 'no copia ocultos'
    $reg = Get-Registro $dest1
    Assert (@($reg | Where-Object { $_.Resultado -eq 'COPIADO' }).Count -eq $ARCHIVOS_VISIBLES) 'CSV: todos COPIADO'
    Assert (@(Get-Archivos (P @($movil, 'sdcard', 'Pictures', 'Screenshots'))).Count -eq $TOTAL_MOVIL) 'el origen sigue intacto'
    $orig = P @($movil, 'sdcard', 'Pictures', 'Screenshots', 'Screenshot_20240705-101010.png')
    $copia = P @($dest1, '2024', '2024-07', 'Screenshot_20240705-101010.png')
    Assert ((Get-Item -LiteralPath $copia).LastWriteTime -eq (Get-Item -LiteralPath $orig).LastWriteTime) 'pull -a conserva la fecha'
    $pulls = @(Get-Content -LiteralPath (P @($base, 'adb-log1.txt')) -Encoding UTF8 | Where-Object { $_ -match '(^|¦ )pull ¦' })
    Assert ($pulls.Count -lt $ARCHIVOS_VISIBLES) "pull por lotes (llamadas: $($pulls.Count))"
    $est = Get-Content -LiteralPath (P @($dest1, '_traspaso', 'ESTADO.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($est.Estado -eq 'TERMINADO' -and $est.Porcentaje -eq 100 -and $est.Faltan -eq 0) "ESTADO.json: $($est.Estado) $($est.Porcentaje)"
    $true
}
Test-Caso 'T07 Reanudación: 2.ª pasada todo YA_EXISTIA, nada nuevo' {
    $antes = (Get-Archivos $dest1).Count
    Start-Sleep -Seconds 1
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $dest1; Adb = $falso; SinPausa = $true }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    $reg = Get-Registro $dest1
    Assert (@($reg | Where-Object { $_.Resultado -eq 'YA_EXISTIA' }).Count -eq $ARCHIVOS_VISIBLES) "YA_EXISTIA: $(@($reg | Where-Object { $_.Resultado -eq 'YA_EXISTIA' }).Count)"
    Assert ((Get-Archivos $dest1).Count -eq $antes) 'no crea archivos nuevos'
    $true
}
Test-Caso 'T08 -SoloComparar: 100 % y 0 faltan; tras añadir uno, falta 1' {
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $dest1; Adb = $falso; SoloComparar = $true }
    Assert ($r.Codigo -eq 0 -and $r.Salida -match '100% hecho' -and $r.Salida -match 'faltan 0') "comparar: $($r.Salida)"
    New-Archivo (P @($movil, 'sdcard', 'Pictures', 'Screenshots', 'Screenshot_2025-01-01-01-01-01.png')) 1234 ([datetime]'2025-01-01') 11
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $dest1; Adb = $falso; SoloComparar = $true }
    Assert ($r.Salida -match 'faltan 1') 'falta 1'
    Assert (@(Get-ChildItem -LiteralPath (P @($dest1, '_traspaso')) -Filter 'faltantes_*.csv').Count -ge 1) 'CSV de faltantes'
    Remove-Item -LiteralPath (P @($movil, 'sdcard', 'Pictures', 'Screenshots', 'Screenshot_2025-01-01-01-01-01.png'))
    $true
}

# ---------------------------------------------------------------- conflictos
Test-Caso 'T09 Conflicto: mismo nombre y distinto contenido -> "nombre (2)"; sin (3) al repetir' {
    $d = P @($base, 'destino-conflicto')
    $ajeno = P @($d, '2024', '2024-07', 'Screenshot_20240705-101010.png')
    New-Archivo $ajeno 999 ([datetime]'2020-01-01') 42
    $hashAjeno = (Get-FileHash -LiteralPath $ajeno).Hash
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Anio = 2024 }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    Assert ((Get-FileHash -LiteralPath $ajeno).Hash -eq $hashAjeno) 'NUNCA sobrescribe el existente'
    Assert (Test-Path -LiteralPath (P @($d, '2024', '2024-07', 'Screenshot_20240705-101010 (2).png'))) 'copia renombrada (2)'
    Assert (@(Get-Registro $d | Where-Object { $_.Resultado -eq 'CONFLICTO_RENOMBRADO' }).Count -eq 1) 'CSV CONFLICTO_RENOMBRADO'
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Anio = 2024 }
    Assert (-not (Test-Path -LiteralPath (P @($d, '2024', '2024-07', 'Screenshot_20240705-101010 (3).png')))) 'no crea (3)'
    Assert (@(Get-Registro $d | Where-Object { $_.Resultado -ne 'YA_EXISTIA' }).Count -eq 0) '2.ª pasada: todo YA_EXISTIA'
    $true
}

# ---------------------------------------------------------------- filtros y organización
Test-Caso 'T10 Filtros: extensiones, patrón, regex, año, desde/hasta, excluir' {
    $chk = {
        param([hashtable]$Extra, [int]$Esperado)
        $p = @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
        foreach ($k in $Extra.Keys) { $p[$k] = $Extra[$k] }
        $r = Invoke-Motor $p
        Assert ($r.Salida -match "(^|\D)$Esperado tras los filtros") "filtro $(($Extra.Keys) -join ',') esperado $Esperado :: $($r.Salida)"
    }
    & $chk @{ Extensiones = 'png' } (3 + $EXTRA_RARO)
    & $chk @{ Extensiones = @('jpg', 'mp4') } 4
    & $chk @{ Patron = 'Screenshot_*' } 3
    & $chk @{ Patron = 're:^IMG_\d{8}' } 1
    & $chk @{ Anio = 2023 } 2
    & $chk @{ Anio = @(2022, 2023) } 3
    & $chk @{ Desde = '2024-07'; Hasta = '2024-07' } 3
    & $chk @{ Desde = '2024-07-06'; Hasta = '2024-08-01' } 3
    & $chk @{ Excluir = @('*.mp4', 'O*') } (5 + $EXTRA_RARO)
    & $chk @{ Recursivo = $true } (8 + $EXTRA_RARO)
    & $chk @{ Recursivo = $true; Excluir = 'sub/*' } (7 + $EXTRA_RARO)
    & $chk @{ IncluirOcultos = $true } (8 + $EXTRA_RARO)
    & $chk @{ MinMB = 0.0019 } (2 + $EXTRA_RARO)              # >= 1993 bytes (redondeo hacia arriba): 2000, 2200 (y 2300)
    & $chk @{ MaxMB = 0.0017 } 3                     # <= 1782 bytes (redondeo hacia abajo): 1500, 1600, 1700
    & $chk @{ MinMB = 0.0015; MaxMB = 0.0018 } 3     # 1573..1887 bytes: 1600, 1700, 1800
    & $chk @{ MinMB = (1500 / 1MB); MaxMB = (1500 / 1MB) } 1   # límite exacto incluido: solo el de 1500 bytes
    & $chk @{ MaxMB = 0.0000005 } 0                  # máximo de menos de 1 byte: no deja pasar nada (no es "sin máximo")
    $true
}
Test-Caso 'T11 -FechaPor Modificacion (criterio BK2) cambia el mes' {
    $d = P @($base, 'destino-mod')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; FechaPor = 'Modificacion'; Patron = 'Screenshot_2023-12*' }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    Assert (Test-Path -LiteralPath (P @($d, '2024', '2024-01', 'Screenshot_2023-12-31-23-59-59-000_com.app.png'))) 'va a 2024-01 por modificación'
    $true
}
$local = P @($base, 'origen-local')
New-Archivo (P @($local, 'a', 'IMG_20230101_101010.jpg')) 3000 ([datetime]'2023-01-01') 21
New-Archivo (P @($local, 'a', 'b', "nota d'Iñaki á.txt")) 3100 ([datetime]'2021-06-06') 22
New-Archivo (P @($local, 'raíz [1].png')) 3200 ([datetime]'2022-02-02') 23
Test-Caso 'T12 Organizar Ninguna / Anio / Original (local, recursivo)' {
    $d1 = P @($base, 'org-ninguna'); $d2 = P @($base, 'org-anio'); $d3 = P @($base, 'org-original')
    $r1 = Invoke-Motor @{ Origen = $local; Destino = $d1; Organizar = 'Ninguna'; Recursivo = $true; SinPausa = $true }
    $r2 = Invoke-Motor @{ Origen = $local; Destino = $d2; Organizar = 'Anio'; Recursivo = $true; SinPausa = $true }
    $r3 = Invoke-Motor @{ Origen = $local; Destino = $d3; Organizar = 'Original'; Recursivo = $true; SinPausa = $true }
    Assert ($r1.Codigo -eq 0 -and $r2.Codigo -eq 0 -and $r3.Codigo -eq 0) "códigos $($r1.Codigo) $($r2.Codigo) $($r3.Codigo)"
    Assert (Test-Path -LiteralPath (P @($d1, 'raíz [1].png'))) 'Ninguna'
    Assert (Test-Path -LiteralPath (P @($d2, '2023', 'IMG_20230101_101010.jpg'))) 'Anio'
    Assert (Test-Path -LiteralPath (P @($d2, '2021', "nota d'Iñaki á.txt"))) 'Anio (modificación)'
    Assert (Test-Path -LiteralPath (P @($d3, 'a', 'b', "nota d'Iñaki á.txt"))) 'Original conserva subcarpetas'
    $true
}
Test-Caso 'T13 Seguridad de rutas: destino dentro del origen (recursivo) y origen dentro del destino -> código 2' {
    $r1 = Invoke-Motor @{ Origen = $local; Destino = (P @($local, 'copia')); Recursivo = $true; SinPausa = $true }
    $r2 = Invoke-Motor @{ Origen = (P @($local, 'a')); Destino = $local; SinPausa = $true }
    $r3 = Invoke-Motor @{ Origen = $local; Destino = $local; SinPausa = $true }
    Assert ($r1.Codigo -eq 2 -and $r2.Codigo -eq 2 -and $r3.Codigo -eq 2) "códigos $($r1.Codigo) $($r2.Codigo) $($r3.Codigo)"
    Assert (-not (Test-Path -LiteralPath (P @($local, 'copia')))) 'no crea nada'
    # Alias físico: el origen es un enlace que apunta DENTRO del destino (como una unidad mapeada o subst)
    $dAlias = P @($base, 'destino-alias')
    New-Archivo (P @($dAlias, '2024', '2024-03', 'IMG_20240303_101010.jpg')) 640 ([datetime]'2024-03-03') 51
    $alias = P @($base, 'alias-al-destino')
    try { New-Item -ItemType SymbolicLink -Path $alias -Target (P @($dAlias, '2024')) -ErrorAction Stop | Out-Null }
    catch { return 'OMITIDO' }
    $r4 = Invoke-Motor @{ Origen = $alias; Destino = $dAlias; Recursivo = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; SinPausa = $true }
    Assert ($r4.Codigo -eq 2 -and $r4.Salida -match 'físicamente') "alias dentro del destino: $($r4.Codigo) $($r4.Salida)"
    Assert (Test-Path -LiteralPath (P @($dAlias, '2024', '2024-03', 'IMG_20240303_101010.jpg'))) 'el archivo sigue'
    $true
}
Test-Caso 'T14 Enlaces simbólicos / junctions: no se siguen' {
    $real = P @($base, 'fuera-del-origen')
    New-Archivo (P @($real, 'secreto_20240101_000000.jpg')) 500 ([datetime]'2024-01-01') 31
    $orig = P @($base, 'origen-con-enlace')
    New-Archivo (P @($orig, 'normal_20240101_000000.jpg')) 600 ([datetime]'2024-01-01') 32
    try { New-Item -ItemType SymbolicLink -Path (P @($orig, 'enlace')) -Target $real -ErrorAction Stop | Out-Null }
    catch { return 'OMITIDO' }   # sin permiso para crear enlaces (Windows sin modo desarrollador)
    $r = Invoke-Motor @{ Origen = $orig; SoloInventario = $true; Recursivo = $true }
    Assert ($r.Salida -match '1 tras los filtros' -and $r.Salida -match 'enlaces/junctions saltados: 1') $r.Salida
    $true
}

# ---------------------------------------------------------------- Mover
Test-Caso 'T15 Mover sin escribir BORRAR exacto -> solo copia, origen intacto' {
    $m = New-Movil 'movil-mover0'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-mover0')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'borrar' }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    Assert (@(Get-Archivos (P @($m, 'sdcard', 'Pictures', 'Screenshots'))).Count -eq $TOTAL_MOVIL) 'origen intacto'
    Assert (@(Get-Registro $d | Where-Object { $_.EstadoOrigen -ne 'CONSERVADO' }).Count -eq 0) 'nada borrado'
    $true
}
Test-Caso 'T16 Mover ADB con BORRAR: borra lo verificado (también con comillas) y nada más' {
    $m = New-Movil 'movil-mover1'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-mover1')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; Bloque = 3 }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    $quedan = @(Get-Archivos (P @($m, 'sdcard', 'Pictures', 'Screenshots')))
    Assert ($quedan.Count -eq 2) "quedan $($quedan.Count) (deben quedar el oculto y el de la subcarpeta)"
    Assert ((Get-Archivos $d).Count -eq $ARCHIVOS_VISIBLES) 'todas las copias en destino'
    Assert (@(Get-Registro $d | Where-Object { $_.EstadoOrigen -eq 'BORRADO_ORIGEN' }).Count -eq $ARCHIVOS_VISIBLES) 'CSV BORRADO_ORIGEN'
    $true
}
Test-Caso 'T17 Mover con archivo previo del mismo tamaño y distinto contenido -> no se pierde nada' {
    $m = New-Movil 'movil-mover2'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-mover2')
    $previo = P @($d, '2024', '2024-07', 'VID_20240710_111111.mp4')
    New-Archivo $previo 2200 ([datetime]'2024-07-10') 77    # mismo tamaño, otro contenido
    $hPrevio = (Get-FileHash -LiteralPath $previo).Hash
    $hOrigen = (Get-FileHash -LiteralPath (P @($m, 'sdcard', 'Pictures', 'Screenshots', 'VID_20240710_111111.mp4'))).Hash
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; Patron = 'VID_*' }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    Assert ((Get-FileHash -LiteralPath $previo).Hash -eq $hPrevio) 'el previo no se toca'
    $nuevo = P @($d, '2024', '2024-07', 'VID_20240710_111111 (2).mp4')
    Assert ((Test-Path -LiteralPath $nuevo) -and (Get-FileHash -LiteralPath $nuevo).Hash -eq $hOrigen) 'el del móvil está a salvo como (2)'
    $fila = @(Get-Registro $d)[0]
    Assert ($fila.Resultado -eq 'CONFLICTO_RENOMBRADO' -and $fila.EstadoOrigen -eq 'BORRADO_ORIGEN') "fila: $($fila.Resultado) $($fila.EstadoOrigen)"
    $true
}
Test-Caso 'T18 Mover con copia previa idéntica en otra carpeta (BK2) -> YA_EXISTIA por SHA256 y se borra' {
    $m = New-Movil 'movil-mover3'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-mover3')
    $src = P @($m, 'sdcard', 'Pictures', 'Screenshots', 'Screenshot_2023-12-31-23-59-59-000_com.app.png')
    $bk2 = P @($d, '2024', '2024-01', 'Screenshot_2023-12-31-23-59-59-000_com.app.png')   # BK2 lo puso por modificación
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bk2)); [IO.File]::Copy($src, $bk2)
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; Patron = 'Screenshot_2023-12*' }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    $fila = @(Get-Registro $d)[0]
    Assert ($fila.Resultado -eq 'YA_EXISTIA' -and $fila.EstadoOrigen -eq 'BORRADO_ORIGEN' -and $fila.RutaDestino -eq $bk2) "fila: $($fila.Resultado) $($fila.EstadoOrigen) $($fila.RutaDestino)"
    Assert (-not (Test-Path -LiteralPath (P @($d, '2023', '2023-12')))) 'no duplica en 2023-12'
    Assert (-not (Test-Path -LiteralPath $src)) 'borrado del móvil'
    $true
}
Test-Caso 'T19 Fallo de descarga simulado -> FALLO, exit 1, sin borrar ese archivo ni dejar copia a medias' {
    $m = New-Movil 'movil-fallo'
    $env:ADB_FALSO_RAIZ = $m
    $env:ADB_FALSO_FALLAR_PULL = 'VID_'
    $d = P @($base, 'destino-fallo')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR' }
    $env:ADB_FALSO_FALLAR_PULL = $null
    Assert ($r.Codigo -eq 1) "código $($r.Codigo)"
    Assert (Test-Path -LiteralPath (P @($m, 'sdcard', 'Pictures', 'Screenshots', 'VID_20240710_111111.mp4'))) 'sigue en el móvil'
    Assert (-not (Test-Path -LiteralPath (P @($d, '2024', '2024-07', 'VID_20240710_111111.mp4')))) 'sin copia a medias'
    Assert (-not (Test-Path -LiteralPath (P @($d, '2024', '2024-07', '.traspaso_parcial')))) 'sin restos temporales'
    $fila = @(Get-Registro $d | Where-Object { $_.RutaOrigen -like '*VID_*' })[0]
    Assert ($fila.Resultado -eq 'FALLO' -and $fila.Detalle -like 'TAMANO*' -and $fila.EstadoOrigen -eq 'CONSERVADO') "fila: $($fila.Resultado) $($fila.Detalle)"
    $est = Get-Content -LiteralPath (P @($d, '_traspaso', 'ESTADO.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($est.Estado -eq 'TERMINADO_CON_FALLOS') "estado $($est.Estado)"
    # Reanudación tras arreglar el fallo: se copia lo que faltaba
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR' }
    Assert ($r.Codigo -eq 0 -and -not (Test-Path -LiteralPath (P @($m, 'sdcard', 'Pictures', 'Screenshots', 'VID_20240710_111111.mp4')))) 'reanuda y termina'
    $true
}
Test-Caso 'T20 Fallo de borrado simulado -> ERROR_BORRADO y exit 1' {
    $m = New-Movil 'movil-rm'
    $env:ADB_FALSO_RAIZ = $m
    $env:ADB_FALSO_FALLAR_RM = 'IMG_'
    $d = P @($base, 'destino-rm')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR' }
    $env:ADB_FALSO_FALLAR_RM = $null
    Assert ($r.Codigo -eq 1) "código $($r.Codigo)"
    $fila = @(Get-Registro $d | Where-Object { $_.RutaOrigen -like '*IMG_*' })[0]
    Assert ($fila.EstadoOrigen -eq 'ERROR_BORRADO') "fila: $($fila.EstadoOrigen)"
    Assert (@(Get-Registro $d | Where-Object { $_.EstadoOrigen -eq 'BORRADO_ORIGEN' }).Count -eq ($ARCHIVOS_VISIBLES - 1)) 'los demás sí'
    $true
}
Test-Caso 'T21 -Hash: SHA256 en CSV (ADB y local) y coincide con el origen' {
    $m = New-Movil 'movil-hash'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-hash')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Hash = $true; Informe = @('Html', 'Json') }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    foreach ($f in (Get-Registro $d)) {
        Assert ($f.SHA256 -match '^[0-9a-f]{64}$') "sin hash: $($f.RutaOrigen)"
        Assert ($f.SHA256 -eq (Get-FileHash -LiteralPath $f.RutaDestino).Hash.ToLowerInvariant()) "hash distinto: $($f.RutaDestino)"
    }
    Assert (@(Get-ChildItem -LiteralPath (P @($d, '_traspaso')) -Filter 'informe_*.html').Count -eq 1) 'informe HTML'
    $j = Get-ChildItem -LiteralPath (P @($d, '_traspaso')) -Filter 'informe_*.json' | Select-Object -First 1
    Assert ($null -ne $j -and ((Get-Content -LiteralPath $j.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).Cuentas.COPIADO -eq $ARCHIVOS_VISIBLES)) 'informe JSON'
    $d2 = P @($base, 'destino-hash-local')
    $r = Invoke-Motor @{ Origen = $local; Destino = $d2; Recursivo = $true; Hash = $true; SinPausa = $true }
    Assert ($r.Codigo -eq 0 -and @(Get-Registro $d2 | Where-Object { $_.SHA256 -match '^[0-9a-f]{64}$' }).Count -eq 3) 'hash local'
    $true
}
Test-Caso 'T22 Mover local (nombres con espacios, tildes, comillas y [ ]) y topes -MaxArchivos' {
    $o = P @($base, 'origen-mover-local')
    New-Archivo (P @($o, "uno d'a [x] ñ.jpg")) 700 ([datetime]'2024-03-03') 41
    New-Archivo (P @($o, 'dos 20240404_101010.jpg')) 800 ([datetime]'2024-04-04') 42
    New-Archivo (P @($o, 'tres.jpg')) 900 ([datetime]'2024-05-05') 43
    $d = P @($base, 'destino-mover-local')
    $r = Invoke-Motor @{ Origen = $o; Destino = $d; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; SinPausa = $true; MaxArchivos = 2 }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    Assert (@(Get-ChildItem -LiteralPath $o -File).Count -eq 1) 'queda 1 por el tope'
    Assert (Test-Path -LiteralPath (P @($d, '2024', '2024-03', "uno d'a [x] ñ.jpg"))) 'nombre raro movido'
    $r = Invoke-Motor @{ Origen = $o; Destino = $d; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; SinPausa = $true }
    Assert ($r.Codigo -eq 0 -and @(Get-ChildItem -LiteralPath $o -File).Count -eq 0) 'segunda tanda'
    $true
}
Test-Caso 'T23 adb nativo (ejecutable real que llama al simulado): espacios, tildes y comillas' {
    if ($env:OS -eq 'Windows_NT') { return $true }   # en Windows se usa el .ps1 directo
    $m = New-Movil 'movil-nativo'
    $env:ADB_FALSO_RAIZ = $m
    $envoltorio = P @($base, 'adb')
    $pw = (Get-Process -Id $PID).Path
    [IO.File]::WriteAllText($envoltorio, "#!/bin/sh`nexec '$pw' -NoProfile -File '$falso' `"`$@`"`n")
    & chmod +x $envoltorio
    $d = P @($base, 'destino-nativo')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $envoltorio; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; Hash = $true }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    Assert ((Get-Archivos $d).Count -eq $ARCHIVOS_VISIBLES) 'copias'
    Assert (@(Get-Archivos (P @($m, 'sdcard', 'Pictures', 'Screenshots'))).Count -eq 2) 'borrados del móvil'
    $true
}

Test-Caso 'T24 Mover: si la "copia" previa es físicamente el mismo archivo (enlace duro), NO se borra' {
    $o = P @($base, 'origen-duro')
    $f = P @($o, 'IMG_20240909_090909.jpg')
    New-Archivo $f 1111 ([datetime]'2024-09-09') 61
    $d = P @($base, 'destino-duro')
    [void][IO.Directory]::CreateDirectory((P @($d, '2024', '2024-09')))
    try { New-Item -ItemType HardLink -Path (P @($d, '2024', '2024-09', 'IMG_20240909_090909.jpg')) -Target $f -ErrorAction Stop | Out-Null }
    catch { return 'OMITIDO' }
    $r = Invoke-Motor @{ Origen = $o; Destino = $d; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; SinPausa = $true }
    Assert ($r.Codigo -eq 1) "código $($r.Codigo)"
    Assert (Test-Path -LiteralPath $f) 'el original sigue'
    $fila = @(Get-Registro $d)[0]
    Assert ($fila.EstadoOrigen -eq 'ERROR_BORRADO' -and $fila.Detalle -like 'NO_BORRADO*') "fila: $($fila.EstadoOrigen) $($fila.Detalle)"
    $true
}
Test-Caso 'T25 Candado: con otro traspaso en curso sobre el mismo destino -> código 2 y no toca nada' {
    $d = P @($base, 'destino-candado')
    [void][IO.Directory]::CreateDirectory((P @($d, '_traspaso')))
    $c = [IO.File]::Open((P @($d, '_traspaso', 'EN_CURSO.lock')), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try { $r = Invoke-Motor @{ Origen = $local; Destino = $d; Recursivo = $true; SinPausa = $true } }
    finally { $c.Dispose() }
    Assert ($r.Codigo -eq 2 -and $r.Salida -match 'otro traspaso') "código $($r.Codigo) $($r.Salida)"
    Assert (@(Get-Archivos $d).Count -eq 0) 'no copia nada'
    $r = Invoke-Motor @{ Origen = $local; Destino = $d; Recursivo = $true; SinPausa = $true }
    Assert ($r.Codigo -eq 0 -and -not (Test-Path -LiteralPath (P @($d, '_traspaso', 'EN_CURSO.lock')))) 'libera el candado al terminar'
    $true
}
Test-Caso 'T26 Mover sin -Hash verifica igualmente las copias por SHA256' {
    $m = New-Movil 'movil-mover-hash'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-mover-hash')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR' }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo)"
    $filas = @(Get-Registro $d)
    Assert (@($filas | Where-Object { $_.EstadoOrigen -eq 'BORRADO_ORIGEN' -and $_.SHA256 -match '^[0-9a-f]{64}$' }).Count -eq $ARCHIVOS_VISIBLES) 'todas con SHA256'
    $true
}
Test-Caso 'T27 Menú: navegación, opción no válida, ayuda y salir (entrada simulada)' {
    $pw = (Get-Process -Id $PID).Path
    $salida = @('x', '8', '', '10') | & $pw -NoProfile -File $menu -RutaConfig (P @($base, 'cfg-menu1.json')) 2>&1 | Out-String
    $codigo = $LASTEXITCODE
    Assert ($codigo -eq 0) "código $codigo $salida"
    Assert ($salida -match 'MENÚ PRINCIPAL' -and $salida -match 'Opción no válida' -and $salida -match 'SYNOPSIS|SINOPSIS') $salida
    $true
}
Test-Caso 'T28 Menú: repetir el último -> simular (no escribe) -> no ejecutar; y luego ejecutar de verdad' {
    $pw = (Get-Process -Id $PID).Path
    $d = P @($base, 'destino-menu')
    $rutaCfg = P @($base, 'cfg-menu2.json')
    $cfg = [ordered]@{ Ultimo = [ordered]@{ Origen = $local; Destino = $d; Modo = 'Copiar'; Organizar = 'AnioMes'; Recursivo = $true; SinPausa = $true; Bloque = 50 }; Destinos = @($d); Origenes = @($local) }
    [IO.File]::WriteAllText($rutaCfg, ($cfg | ConvertTo-Json -Depth 4))
    $salida = @('2', '1', 'n', '10') | & $pw -NoProfile -File $menu -RutaConfig $rutaCfg 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $salida -match 'SIMULACIÓN' -and $salida -match 'Comando: \.\\Traspasar-Archivos\.ps1 -Origen') $salida
    Assert (-not (Test-Path -LiteralPath $d)) 'la simulación no crea el destino'
    $salida = @('2', '2', '10') | & $pw -NoProfile -File $menu -RutaConfig $rutaCfg 2>&1 | Out-String
    Assert ($salida -match 'Terminado sin fallos') $salida
    Assert (@(Get-Archivos $d).Count -eq 3) "copias: $(@(Get-Archivos $d).Count)"
    $true
}
Test-Caso 'T29 Restos de un corte (.traspaso_parcial): no cuentan como copiados, se limpian y se copia bien' {
    $m = New-Movil 'movil-corte'
    $env:ADB_FALSO_RAIZ = $m
    $d = P @($base, 'destino-corte')
    $resto = P @($d, '2024', '2024-07', '.traspaso_parcial', 'VID_20240710_111111.mp4')
    New-Archivo $resto 2200 ([datetime]'2024-07-10') 8    # mismo tamaño y contenido que el del móvil
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Patron = 'VID_*' }
    Assert ($r.Codigo -eq 0) "código $($r.Codigo) $($r.Salida)"
    $fila = @(Get-Registro $d)[0]
    Assert ($fila.Resultado -eq 'COPIADO') "no debe darlo por existente: $($fila.Resultado)"
    Assert (-not (Test-Path -LiteralPath (P @($d, '2024', '2024-07', '.traspaso_parcial')))) 'restos limpiados'
    Assert (Test-Path -LiteralPath (P @($d, '2024', '2024-07', 'VID_20240710_111111.mp4'))) 'copia con su nombre'
    Assert (-not (Test-Path -LiteralPath (P @($d, '2024', '2024-07', 'VID_20240710_111111 (2).mp4')))) 'sin (2)'
    $true
}
Test-Caso 'T30 Lectura parcial del móvil (find con error) -> exit 1 y TERMINADO_CON_FALLOS' {
    $m = New-Movil 'movil-lectura'
    $env:ADB_FALSO_RAIZ = $m
    $env:ADB_FALSO_FALLAR_FIND = '1'
    $d = P @($base, 'destino-lectura')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true }
    $ri = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
    $env:ADB_FALSO_FALLAR_FIND = $null
    Assert ($r.Codigo -eq 1 -and $r.Salida -match 'no se pudo leer parte') "código $($r.Codigo) $($r.Salida)"
    Assert ($ri.Codigo -eq 1) "inventario: $($ri.Codigo)"
    $est = Get-Content -LiteralPath (P @($d, '_traspaso', 'ESTADO.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($est.Estado -eq 'TERMINADO_CON_FALLOS') "estado $($est.Estado)"
    $true
}
Test-Caso 'T31 Cancelar entre bloques (responder n) -> código 3, lo hecho queda verificado' {
    $pw = (Get-Process -Id $PID).Path
    $d = P @($base, 'destino-cancelar')
    $salida = @('n') | & $pw -NoProfile -File $motor -Origen $local -Destino $d -Recursivo -Bloque 1 2>&1 | Out-String
    $codigo = $LASTEXITCODE
    Assert ($codigo -eq 3) "código $codigo $salida"
    $filas = @(Get-Registro $d)
    Assert ($filas.Count -eq 1 -and $filas[0].Resultado -eq 'COPIADO') "filas: $($filas.Count)"
    $est = Get-Content -LiteralPath (P @($d, '_traspaso', 'ESTADO.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($est.Estado -eq 'CANCELADO' -and $est.Faltan -eq 2) "estado $($est.Estado) faltan $($est.Faltan)"
    Assert (-not (Test-Path -LiteralPath (P @($d, '_traspaso', 'EN_CURSO.lock')))) 'candado liberado'
    $true
}

Test-Caso 'T32 Mayúsculas: A.jpg y a.jpg (mismo tamaño) al Mover -> nunca se borra uno sin su propia copia verificada' {
    foreach ($tipo in @('adb', 'local')) {
        $raiz = P @($base, "may-$tipo")
        $carpeta = P @($raiz, 'sdcard', 'Pictures', 'Screenshots')
        New-Archivo (P @($carpeta, 'A.jpg')) 3333 ([datetime]'2024-05-05') 71
        New-Archivo (P @($carpeta, 'a.jpg')) 3333 ([datetime]'2024-05-05') 72
        if (-not (Test-Path -LiteralPath (P @($carpeta, 'A.jpg'))) -or @(Get-ChildItem -LiteralPath $carpeta).Count -ne 2) { return 'OMITIDO' }   # sistema que no distingue mayúsculas
        $hA = (Get-FileHash -LiteralPath (P @($carpeta, 'A.jpg'))).Hash
        $d = P @($base, "destino-may-$tipo")
        $previo = P @($d, '2024', '2024-05', 'a.jpg')
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($previo)); [IO.File]::Copy((P @($carpeta, 'a.jpg')), $previo)
        $p = @{ Destino = $d; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR'; FechaPor = 'Modificacion' }
        if ($tipo -eq 'adb') { $env:ADB_FALSO_RAIZ = $raiz; $p.Origen = $ORIGEN_ADB; $p.Adb = $falso } else { $p.Origen = $carpeta }
        $r = Invoke-Motor $p
        Assert ($r.Codigo -eq 0) "$tipo código $($r.Codigo) $($r.Salida)"
        $conA = @(Get-Archivos $d | Where-Object { (Get-FileHash -LiteralPath $_.FullName).Hash -eq $hA })
        $sigueA = Test-Path -LiteralPath (P @($carpeta, 'A.jpg'))
        Assert ($sigueA -or $conA.Count -ge 1) "$tipo : A.jpg se borró sin que exista ninguna copia con su contenido"
        Assert ($conA.Count -ge 1) "$tipo : el contenido de A.jpg debe estar en el destino"
    }
    $true
}

Test-Caso 'T33 Menú: traspaso rápido (origen, destino, desde, hasta con fecha mala y DD/MM/AAAA, MB mínimos)' {
    $pw = (Get-Process -Id $PID).Path
    $d = P @($base, 'destino-rapido')
    $rutaCfg = P @($base, 'cfg-menu3.json')
    [IO.File]::WriteAllText($rutaCfg, ([ordered]@{ Ultimo = $null; Destinos = @($d); Origenes = @($local) } | ConvertTo-Json -Depth 4))
    # 9 rápido · 2 carpeta local · 1 reciente · 1 destino reciente · s subcarpetas · desde/hasta al revés (se repiten) ·
    # desde · hasta mala · hasta buena · MB · 1 Copiar · 2 ejecutar · 10 salir
    # Fechas 2022-01..2023-12 dejan 'raíz [1].png' (3200 bytes) e IMG_20230101 (3000); 0,003 MB (3146 bytes) deja solo el primero
    $entrada = @('9', '2', '1', '1', 's', '2024-01', '2023-01', '2022-01', '2023-13', '31/12/2023', '1.000', '0,003', '1', '2', '10')
    $salida = $entrada | & $pw -NoProfile -File $menu -RutaConfig $rutaCfg 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $salida -match 'Fecha no válida' -and $salida -match 'DESDE es posterior a HASTA' -and $salida -match 'Separador de miles' -and $salida -match 'Terminado sin fallos') $salida
    Assert ($salida -match "-Desde '2022-01' -Hasta '2023-12-31' -MinMB '0\.003'") "comando: $salida"
    $copias = @(Get-Archivos $d)
    Assert ($copias.Count -eq 1 -and $copias[0].Name -eq 'raíz [1].png') "copias: $(@($copias | ForEach-Object { $_.Name }) -join ', ')"
    $true
}

Test-Caso 'T34 Listado del móvil con "Argument list too long" (find -exec +) -> se repite archivo a archivo y sale completo' {
    $m = New-Movil 'movil-argmax'
    $env:ADB_FALSO_RAIZ = $m
    $env:ADB_FALSO_ARGMAX = '1'
    $env:ADB_FALSO_LOG = P @($base, 'adb-log-argmax.txt')
    $ri = Invoke-Motor @{ Origen = $ORIGEN_ADB; SoloInventario = $true; Adb = $falso }
    $d = P @($base, 'destino-argmax')
    $r = Invoke-Motor @{ Origen = $ORIGEN_ADB; Destino = $d; Adb = $falso; SinPausa = $true; Modo = 'Mover'; ConfirmarBorrado = 'BORRAR' }
    $env:ADB_FALSO_ARGMAX = $null
    $env:ADB_FALSO_LOG = $null
    Assert ($ri.Codigo -eq 0 -and $ri.Salida -match "(^|\D)$ARCHIVOS_VISIBLES tras los filtros" -and $ri.Salida -match 'archivo a archivo') "inventario: $($ri.Codigo) $($ri.Salida)"
    Assert ($ri.Salida -notmatch 'Aviso: el listado') 'sin aviso de lectura parcial'
    Assert ($r.Codigo -eq 0 -and @(Get-Registro $d | Where-Object { $_.EstadoOrigen -eq 'BORRADO_ORIGEN' }).Count -eq $ARCHIVOS_VISIBLES) "mover: $($r.Codigo)"
    Assert (@(Get-Content -LiteralPath (P @($base, 'adb-log-argmax.txt')) -Encoding UTF8 | Where-Object { $_ -match '\{\} \\;' }).Count -ge 1) 'usó el modo archivo a archivo'
    $true
}

# ---------------------------------------------------------------- resumen
$ok = @($resultados | Where-Object { $_.OK }).Count
$omitidos = @($resultados | Where-Object { $_.Omitido }).Count
$fallidos = $resultados.Count - $ok - $omitidos
$color = 'Green'
if ($fallidos -gt 0) { $color = 'Red' } elseif ($omitidos -gt 0) { $color = 'Yellow' }
Write-Host ("`nRESULTADO: {0}/{1} casos en verde · {2} fallidos · {3} omitidos (no probados en este equipo)" -f $ok, $resultados.Count, $fallidos, $omitidos) -ForegroundColor $color
$env:ADB_FALSO_RAIZ = $null
if ($Conservar) { Write-Host "Carpeta de pruebas conservada: $base" }
else { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
if ($fallidos -gt 0) { exit 1 }
if ($omitidos -gt 0) { exit 3 }   # sin fallos, pero con casos sin probar
exit 0
