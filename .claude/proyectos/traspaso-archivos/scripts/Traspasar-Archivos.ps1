<#
.SYNOPSIS
  Copia o mueve archivos de cualquier origen (carpeta local, USB, UNC o móvil por ADB) a cualquier
  destino, con verificación, sin sobrescribir nunca y de forma reanudable.

.DESCRIPTION
  Traspasar-Archivos v3 (proyecto Traspaso-Archivos). Sustituye a 01-Vaciar-Screenshots (v1) y a
  BackupMovil-v2 (v2) y es compatible con lo que ya hay en D:\GN\BK2.

  Flujo:
   1. Inventario del origen. En local se recorre con una pila, sin seguir junctions ni enlaces.
      En ADB se hace con una sola llamada (find + stat).
   2. Fecha de cada archivo. Se toma del nombre (Screenshot_AAAA-MM-DD..., IMG_AAAAMMDD_hhmmss,
      AAAAMMDD_hhmmss, PXL_, VID_, IMG-AAAAMMDD-WA...). Si el nombre no la lleva, se usa la de
      modificación. Con -UsarExif (solo origen local) la fecha EXIF de los JPG va antes que la de
      modificación. Con -FechaPor Modificacion se ignora el nombre (como hacía BackupMovil-v2).
   3. Filtros: -Extensiones, -Patron, -Excluir, -Desde/-Hasta, -Anio y -Recursivo. Los ocultos
      (.trashed-*, .thumbnails, Thumbs.db...) se excluyen salvo con -IncluirOcultos.
   4. Plan, sin sobrescribir NUNCA. Lo que ya está en el destino se salta: mismo nombre y mismo
      tamaño (también en otra subcarpeta, salvo con -Organizar Original); con -Hash o al Mover,
      además mismo SHA256. Si hay mismo nombre con distinto contenido, se copia como "nombre (2).ext".
   5. Resumen previo (archivos, MB, destino y espacio libre). -WhatIf termina aquí sin escribir nada.
   6. Copia por bloques (-Bloque), con pausa entre bloques salvo -SinPausa. Cada archivo se copia
      primero a <carpeta>\.traspaso_parcial\, se verifica allí y solo entonces se mueve a su nombre
      final sin sobrescribir: un corte nunca deja un archivo a medias con el nombre bueno.
      - ADB: adb pull por lotes, varios archivos por llamada.
      - Local: copia interna sin sobrescritura, o robocopy con -Organizar Original en Windows.
   7. Verificación: el tamaño siempre; con -Hash, SHA256 (Get-FileHash en el PC, sha256sum en el móvil).
   8. -Modo Mover borra en el origen SOLO lo verificado por SHA256 (siempre, aunque no se use -Hash)
      y solo después de escribir BORRAR. Si un archivo ya estaba en el destino de antes, además se
      comprueba que no sea físicamente el mismo archivo (unidad mapeada, subst, junction, enlace duro).
      Un candado (_traspaso\EN_CURSO.lock) impide dos traspasos a la vez sobre el mismo destino.
      Si se desconecta el móvil o el disco, espera (-EsperaMin) y reintenta; antes de borrar del
      móvil se fuerza la escritura en el disco y, si el disco se desconectó, se vuelve a verificar.
   9. Registro CSV por ejecución (separador ;) en <Destino>\_traspaso\. ESTADO.json y ESTADO.txt
      se actualizan en vivo. Al final se muestra el resumen por estado.

  Estados del registro:
    Resultado    = COPIADO | YA_EXISTIA | CONFLICTO_RENOMBRADO | FALLO
    EstadoOrigen = CONSERVADO | BORRADO_ORIGEN | ERROR_BORRADO

  Códigos de salida:
    0 = todo bien
    1 = hubo algún FALLO o ERROR_BORRADO, o no se pudo leer parte del origen o del destino
    2 = error de parámetros o de entorno; el traspaso no empezó o se detuvo (lo hecho está en el registro)
    3 = cancelado por el usuario entre bloques (lo hecho está verificado y en el registro)

.PARAMETER Origen
  Carpeta local, USB o UNC (\\servidor\recurso\carpeta), o carpeta del móvil con el prefijo "adb:"
  (ej. adb:/sdcard/Pictures/Screenshots).

.PARAMETER Destino
  Carpeta destino (local, USB o UNC). Se crea si no existe. Es obligatoria salvo con -SoloInventario.

.PARAMETER Dispositivo
  Serial del móvil (adb devices). Solo hace falta si hay más de uno conectado.

.PARAMETER Modo
  Copiar (por defecto) o Mover. Mover borra en el origen solo lo verificado, tras escribir BORRAR.

.PARAMETER Organizar
  AnioMes (por defecto: <Destino>\AAAA\AAAA-MM\), Anio (<Destino>\AAAA\), Ninguna (todo junto en
  <Destino>) u Original (conserva las subcarpetas del origen).

.PARAMETER FechaPor
  Nombre (por defecto; si el nombre no lleva fecha, se usa la de modificación) o Modificacion.

.PARAMETER UsarExif
  Solo con origen local: la fecha EXIF de los JPG/TIFF va antes que la de modificación.

.PARAMETER Extensiones
  Extensiones que se incluyen, sin punto: -Extensiones jpg,png,mp4 (o 'jpg,png').

.PARAMETER Patron
  Filtro por nombre. Comodín (Screenshot_2024*) o expresión regular con el prefijo re:
  (re:^IMG_\d{8}).

.PARAMETER Excluir
  Comodines que se excluyen. Se aplican al nombre y a la ruta relativa con '/' (ej. '*.tmp','sub/*').

.PARAMETER Desde
  Fecha mínima, incluida: AAAA-MM o AAAA-MM-DD.

.PARAMETER Hasta
  Fecha máxima, incluida: AAAA-MM o AAAA-MM-DD (AAAA-MM llega hasta el último día de ese mes).

.PARAMETER Anio
  Uno o varios años: -Anio 2023 o -Anio 2023,2024.

.PARAMETER Recursivo
  Incluye las subcarpetas del origen.

.PARAMETER IncluirOcultos
  Incluye los archivos y carpetas ocultos (los que empiezan por '.', y los de atributo Oculto o Sistema).

.PARAMETER Hash
  Verifica también con SHA256 en modo Copiar (más lento). En modo Mover se usa siempre.

.PARAMETER Bloque
  Archivos por bloque (por defecto 200). Entre bloques pregunta si continuar, salvo con -SinPausa.

.PARAMETER SinPausa
  No pregunta entre bloques.

.PARAMETER MaxArchivos
  Tope de archivos que se procesan en esta ejecución (0 = sin tope).

.PARAMETER MaxGB
  Tope de GB que se copian en esta ejecución (0 = sin tope).

.PARAMETER MinMB
  Solo archivos de este tamaño o más, en MB (ej. 1.5). 0 = sin mínimo.

.PARAMETER MaxMB
  Solo archivos de este tamaño o menos, en MB. 0 = sin máximo.

.PARAMETER OrdenPor
  En qué orden se traspasa: Fecha (por defecto, de más antiguo a más nuevo) o Tamano (de mayor a
  menor; con -MaxGB sirve para mover primero los archivos más pesados).

.PARAMETER EsperaMin
  Si se desconecta el móvil (o el origen) o el disco de destino, minutos que espera a que vuelva
  antes de parar (por defecto 30; 0 = parar en el acto). Al volver, reintenta lo que falló por el corte.

.PARAMETER SoloInventario
  Cuenta archivos y MB por año y por mes en el origen, con los filtros aplicados, y termina.
  No necesita -Destino ni escribe nada. La columna Discrepan dice cuántos caerían en otro mes
  según el criterio de fecha (nombre o modificación).

.PARAMETER SoloComparar
  Compara el origen con el destino (por nombre y tamaño) y dice cuántos faltan y qué % está hecho.
  No copia nada. Si el destino existe, guarda la lista en <Destino>\_traspaso\faltantes_*.csv.

.PARAMETER Informe
  Informes adicionales al CSV: Html, Json o ambos (-Informe Html,Json).

.PARAMETER Motor
  Auto (por defecto), Interno o Robocopy. Solo afecta a orígenes locales. Auto usa robocopy en
  Windows con -Organizar Original. Robocopy nunca sobrescribe (/XC /XN /XO).

.PARAMETER Adb
  Ruta de adb.exe. Si se omite, se busca en el PATH y en BK2\_tools\platform-tools.

.PARAMETER ConfirmarBorrado
  Para uso desatendido: el texto exacto BORRAR (en mayúsculas) evita la pregunta del modo Mover.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -SoloInventario
  Inventario por año y mes del móvil. No copia nada.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Anio 2024 -WhatIf
  Simulación: dice qué copiaría (y cuánto ocupa) sin escribir nada.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Anio 2024 -Modo Mover -Bloque 500
  Móvil -> PC por año: copia, verifica y borra del móvil lo verificado (pide escribir BORRAR).

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen 'C:\Users\D746288\Pictures' -Destino 'E:\Fotos' -Recursivo -Organizar Original -Hash
  Carpeta -> USB conservando las subcarpetas, con verificación SHA256.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen 'D:\GN\BK2\ScreenShots' -Destino '\\NAS\Fotos\ScreenShots' -Recursivo -Excluir '_index/*' -Informe Html
  PC -> NAS (UNC): copia todo menos los registros de BK2 y genera además un informe HTML.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/DCIM/Camera -Destino 'D:\GN\BK2\Camera' -SoloComparar
  Qué falta por pasar de la cámara y qué % está hecho.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -FechaPor Modificacion -Desde 2024-07 -Hasta 2024-12 -Modo Mover
  Continúa BK2 con su mismo criterio de fecha (modificación), de julio a diciembre de 2024.

.EXAMPLE
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/DCIM/Camera -Destino 'D:\GN\BK2\Bideoak' -Desde 2024-01-01 -Hasta 2024-06-30 -MinMB 50
  Solo los archivos de 50 MB o más (vídeos grandes) del primer semestre de 2024.

.NOTES
  Versión 3.2.2 (2026-10-22). Compatible con Windows PowerShell 5.1 y PowerShell 7. Sin dependencias
  salvo adb (Android platform-tools) para el origen adb:.
  Guardar en UTF-8 con BOM y CRLF: PS 5.1 lee como ANSI los archivos sin BOM.
  Tras borrar en el móvil, la galería puede tardar en reflejarlo (MediaStore).
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Origen,
    [Parameter(Position = 1)][string]$Destino,
    [string]$Dispositivo,
    [ValidateSet('Copiar', 'Mover')][string]$Modo = 'Copiar',
    [ValidateSet('Ninguna', 'Anio', 'AnioMes', 'Original')][string]$Organizar = 'AnioMes',
    [ValidateSet('Nombre', 'Modificacion')][string]$FechaPor = 'Nombre',
    [switch]$UsarExif,
    [string[]]$Extensiones,
    [string]$Patron,
    [string[]]$Excluir,
    [string]$Desde,
    [string]$Hasta,
    [int[]]$Anio,
    [switch]$Recursivo,
    [switch]$IncluirOcultos,
    [switch]$Hash,
    [ValidateRange(1, 100000)][int]$Bloque = 200,
    [switch]$SinPausa,
    [ValidateRange(0, 2147483647)][int]$MaxArchivos = 0,
    [ValidateRange(0, 1000000)][double]$MaxGB = 0,
    [double]$MinMB = 0,
    [double]$MaxMB = 0,
    [ValidateRange(0, 1440)][int]$EsperaMin = 30,
    [ValidateSet('Fecha', 'Tamano')][string]$OrdenPor = 'Fecha',
    [switch]$SoloInventario,
    [switch]$SoloComparar,
    [ValidateSet('Html', 'Json')][string[]]$Informe,
    [ValidateSet('Auto', 'Interno', 'Robocopy')][string]$Motor = 'Auto',
    [string]$Adb,
    [string]$ConfirmarBorrado
)

# 'Continue' a propósito: en PS 5.1, con 'Stop', el stderr de adb se convierte en error terminante.
# La seguridad no depende de esto: solo se borra lo verificado y se comprueba $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
# En PowerShell ISE (F5) el script corre en la sesión global: el modo estricto se quedaría puesto al terminar
if ($Host.Name -notmatch 'ISE') { Set-StrictMode -Version 2.0 }

$VERSION_SCRIPT = '3.2.2'
$CI = [Globalization.CultureInfo]::InvariantCulture
$script:EsWindows = ($env:OS -eq 'Windows_NT')
$script:VerOcultos = [bool]$IncluirOcultos
$script:HashCopias = [bool]$Hash     # Mover lo activa siempre (ver más abajo)
$script:IdDestino = $null
$script:Candado = $null
$script:RutaCandado = ''
$script:Parciales = New-Object System.Collections.Generic.List[string]
$script:NativoListo = $false
$script:AvisoCodificacion = $false
$script:OpcionesPull = @('-a')       # + '-Z' (sin compresión) si el adb lo admite
$script:DestinoSePerdio = $false
$script:Cortado = $false
$script:EsperaMinutos = $EsperaMin
$PARCIAL = '.traspaso_parcial'
$script:AdbExe = $null
$script:Serial = $null
$script:Ocultos = 0
$script:Enlaces = 0
$script:AvisosLectura = 0
$script:IdxRuta = @{}       # ruta en minúsculas -> bytes (lo que hay en el destino)
$script:IdxNombre = @{}     # nombre en minúsculas -> lista de {Ruta, Bytes}
$script:Reservadas = @{}    # rutas de destino ya asignadas en esta ejecución
$script:IdxReal = @{}       # ruta en minúsculas -> ruta real en el destino
# Distingue mayúsculas: en carpetas que las distinguen, A.jpg y a.jpg son archivos distintos
$script:CacheHash = New-Object System.Collections.Hashtable -ArgumentList ([StringComparer]::Ordinal)   # ruta -> sha256

trap {
    Write-Host "ERROR inesperado: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Lo verificado ya está registrado; relanza para continuar. No se ha borrado nada sin verificar.' -ForegroundColor Red
    Close-Candado
    exit 1
}

# ============================== utilidades ==============================
function Write-Linea {
    param([string]$Texto, [string]$Color = 'Gray')
    Write-Host $Texto -ForegroundColor $Color
}

function Close-Candado {
    if ($script:Candado) {
        try { $script:Candado.Dispose() } catch { Write-Verbose 'El candado ya no estaba accesible (¿disco desconectado?).' }
        $script:Candado = $null
        try { [IO.File]::Delete($script:RutaCandado) } catch { Write-Verbose 'No se pudo borrar el candado.' }
    }
}

function Stop-Traspaso {
    param([string]$Mensaje)
    Write-Host "ERROR: $Mensaje" -ForegroundColor Red
    Close-Candado
    exit 2
}

function ConvertTo-ShComillas {
    # Entrecomilla para sh: 'texto' (la comilla simple se escribe como '\'')
    param([string]$Texto)
    return "'" + $Texto.Replace("'", "'\''") + "'"
}

function Resolve-RutaPs {
    param([string]$Ruta)
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Ruta)
}

function Test-Contenida {
    # $true si $Hija es $Padre o está dentro de $Padre
    param([string]$Padre, [string]$Hija)
    $p = $Padre.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $h = $Hija.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return $h.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)
}

function Write-Tabla {
    # Tabla por Write-Host (así también la recoge quien capture la salida)
    param([object[]]$Filas, [switch]$Ajustar)
    if (-not $Filas -or $Filas.Count -eq 0) { return }
    if ($Ajustar) { $t = $Filas | Format-Table -AutoSize -Wrap | Out-String -Width 220 }
    else { $t = $Filas | Format-Table -AutoSize | Out-String -Width 220 }
    Write-Host $t.TrimEnd()
}

$CODIGO_NATIVO = @'
namespace TraspasoNativo {
    using System;
    using System.Text;
    using System.Runtime.InteropServices;
    using Microsoft.Win32.SafeHandles;
    public static class Fs {
        [StructLayout(LayoutKind.Sequential)]
        private struct BHFI {
            public uint Attr;
            public System.Runtime.InteropServices.ComTypes.FILETIME Creado, Accedido, Escrito;
            public uint Serie, TamAlto, TamBajo, Enlaces, IdAlto, IdBajo;
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string nombre, uint acceso, uint compartir, IntPtr seg, uint disp, uint flags, IntPtr plantilla);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle h, out BHFI info);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle h, StringBuilder buf, uint largo, uint flags);
        private static SafeFileHandle Abrir(string ruta) {
            // acceso 0 = solo atributos; 0x02000000 = FILE_FLAG_BACKUP_SEMANTICS (también carpetas)
            return CreateFileW(ruta, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero);
        }
        public static string Id(string ruta) {
            using (SafeFileHandle h = Abrir(ruta)) {
                if (h.IsInvalid) { return null; }
                BHFI i;
                if (!GetFileInformationByHandle(h, out i)) { return null; }
                if (i.IdAlto == 0 && i.IdBajo == 0) { return null; }   // algunos NAS no dan id: "desconocido"
                return i.Serie.ToString("X8") + ":" + i.IdAlto.ToString("X8") + i.IdBajo.ToString("X8");
            }
        }
        public static string Real(string ruta) {
            using (SafeFileHandle h = Abrir(ruta)) {
                if (h.IsInvalid) { return null; }
                StringBuilder sb = new StringBuilder(2048);
                uint n = GetFinalPathNameByHandleW(h, sb, 2048, 0);
                if (n == 0 || n >= 2048) { return null; }
                string s = sb.ToString();
                if (s.StartsWith(@"\\?\UNC\")) { return @"\\" + s.Substring(8); }
                if (s.StartsWith(@"\\?\")) { return s.Substring(4); }
                return s;
            }
        }
    }
}
'@

function Initialize-Nativo {
    if ($script:NativoListo -or -not $script:EsWindows) { return }
    $script:NativoListo = $true
    if ('TraspasoNativo.Fs' -as [type]) { return }
    try { Add-Type -TypeDefinition $CODIGO_NATIVO -ErrorAction Stop }
    catch { Write-Linea "  Aviso: no se pudo cargar la comprobación de identidad física: $($_.Exception.Message)" 'Yellow' }
}

function Get-RutaReal {
    # Ruta física real (resuelve unidades mapeadas, subst, junctions y enlaces). $null si no se puede.
    param([string]$Ruta)
    try {
        if ($script:EsWindows) {
            Initialize-Nativo
            if ('TraspasoNativo.Fs' -as [type]) { return [TraspasoNativo.Fs]::Real($Ruta) }
            return $null
        }
        $global:LASTEXITCODE = 0
        $o = & realpath -e -- $Ruta 2>$null
        if ($global:LASTEXITCODE -eq 0 -and $o) { return ([string]$o).Trim() }
    }
    catch { Write-Verbose "Sin ruta real para '$Ruta'." }
    return $null
}

function Get-IdFisico {
    # Identidad física (volumen + id de archivo). Dos rutas con el mismo id son el MISMO archivo.
    param([string]$Ruta)
    try {
        if ($script:EsWindows) {
            Initialize-Nativo
            if ('TraspasoNativo.Fs' -as [type]) { return [TraspasoNativo.Fs]::Id($Ruta) }
            return $null
        }
        $global:LASTEXITCODE = 0
        $o = & stat -L -c '%d:%i' -- $Ruta 2>$null
        if ($global:LASTEXITCODE -eq 0 -and $o) { return ([string]$o).Trim() }
    }
    catch { Write-Verbose "Sin id físico para '$Ruta'." }
    return $null
}

function Get-RutaRealDestino {
    # Como Get-RutaReal, pero el destino puede no existir todavía: se resuelve el antecesor que exista
    param([string]$Ruta)
    $resto = New-Object System.Collections.Generic.List[string]
    $act = $Ruta
    while ($act -and -not (Test-Path -LiteralPath $act)) {
        $resto.Insert(0, [IO.Path]::GetFileName($act))
        $act = [IO.Path]::GetDirectoryName($act)
    }
    if (-not $act) { return $null }
    $r = Get-RutaReal $act
    if (-not $r) { return $null }
    foreach ($x in $resto) { $r = [IO.Path]::Combine($r, $x) }
    return $r
}

function Format-MB {
    param([double]$Bytes)
    return ('{0:N1}' -f ($Bytes / 1MB))
}

function Get-Lotes {
    # Parte una lista en lotes cuyo texto total (según $Texto) no pase de $Max caracteres
    param([object[]]$Elementos, [scriptblock]$Texto, [int]$Max)
    $lotes = New-Object System.Collections.Generic.List[object]
    $actual = New-Object System.Collections.Generic.List[object]
    $largo = 0
    foreach ($e in $Elementos) {
        $t = ([string](& $Texto $e)).Length + 3
        if ($actual.Count -gt 0 -and ($largo + $t) -gt $Max) {
            $lotes.Add($actual.ToArray())
            $actual = New-Object System.Collections.Generic.List[object]
            $largo = 0
        }
        $actual.Add($e)
        $largo += $t
    }
    if ($actual.Count -gt 0) { $lotes.Add($actual.ToArray()) }
    return , $lotes
}

function Add-FilasCsv {
    # CSV en UTF-8 con BOM (Excel lo abre bien) y separador ';'
    param([string]$Ruta, [object[]]$Filas)
    if (-not $Filas -or $Filas.Count -eq 0) { return }
    $lineas = @($Filas | ConvertTo-Csv -NoTypeInformation -Delimiter ';')
    $codif = New-Object System.Text.UTF8Encoding($true)
    if ([IO.File]::Exists($Ruta)) { $lineas = @($lineas | Select-Object -Skip 1) }
    [IO.File]::AppendAllText($Ruta, (($lineas -join "`r`n") + "`r`n"), $codif)
}

# ============================== ADB ==============================
function Invoke-Adb {
    param([string[]]$Argumentos)
    $previos = @()
    if ($script:Serial) { $previos = @('-s', $script:Serial) }
    $codifPrevia = $null
    try { $codifPrevia = [Console]::OutputEncoding; [Console]::OutputEncoding = [Text.Encoding]::UTF8 }
    catch {
        $codifPrevia = $null
        if (-not $script:AvisoCodificacion) {
            $script:AvisoCodificacion = $true
            Write-Linea '  Aviso: este programa (¿PowerShell ISE?) no deja leer adb en UTF-8. Los nombres del móvil con tildes o ñ podrían no copiarse (se registran como FALLO; solo se borra lo verificado). Para esos, usa la consola o 1_LANZAR-Traspaso.bat.' 'Yellow'
        }
    }
    $global:LASTEXITCODE = 0
    try {
        $salida = @(& $script:AdbExe @previos @Argumentos 2>&1)
        $codigo = $global:LASTEXITCODE
    }
    finally {
        if ($null -ne $codifPrevia) { try { [Console]::OutputEncoding = $codifPrevia } catch { Write-Verbose 'No se pudo restaurar la codificación de la consola.' } }
    }
    $lineas = New-Object System.Collections.Generic.List[string]
    $errores = New-Object System.Collections.Generic.List[string]
    foreach ($l in $salida) {
        if ($l -is [System.Management.Automation.ErrorRecord]) { $errores.Add($l.ToString()) }
        else { $lineas.Add(([string]$l).TrimEnd("`r")) }
    }
    return [pscustomobject]@{ Salida = $lineas.ToArray(); Errores = $errores.ToArray(); Codigo = $codigo }
}

function Resolve-Adb {
    param([string]$Preferido)
    $candidatos = New-Object System.Collections.Generic.List[string]
    if ($Preferido) { $candidatos.Add((Resolve-RutaPs $Preferido)) }
    else {
        $enPath = Get-Command adb -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($enPath) { $candidatos.Add($enPath.Path) }
        if ($env:USERPROFILE) { $candidatos.Add((Join-Path $env:USERPROFILE 'Desktop\0.Escritorio\BK2\_tools\platform-tools\adb.exe')) }
        if ($PSScriptRoot) { $candidatos.Add((Join-Path $PSScriptRoot 'platform-tools\adb.exe')) }   # vacío en una pestaña de ISE sin guardar
        if ($env:LOCALAPPDATA) { $candidatos.Add((Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')) }
    }
    foreach ($c in $candidatos) {
        if (-not (Test-Path -LiteralPath $c -PathType Leaf)) { continue }
        if ($Preferido -and $c -like '*.ps1') { return $c }   # adb simulado de los tests (solo si se indica con -Adb)
        $global:LASTEXITCODE = 0
        try { & $c version *> $null } catch { continue }
        if ($global:LASTEXITCODE -eq 0) { return $c }
    }
    if ($Preferido) { Stop-Traspaso "No puedo ejecutar adb en '$Preferido'." }
    Stop-Traspaso "No encuentro adb. Instala Android platform-tools o indica -Adb 'C:\ruta\adb.exe'."
}

function Select-Dispositivo {
    param([string]$Pedido)
    $r = Invoke-Adb -Argumentos @('devices')
    $lista = New-Object System.Collections.Generic.List[object]
    foreach ($l in $r.Salida) {
        if ($l -match '^(\S+)\s+(device|unauthorized|offline|recovery|sideload|bootloader|no permissions.*)$') {
            $lista.Add([pscustomobject]@{ Serial = $Matches[1]; Estado = $Matches[2] })
        }
    }
    $listos = @($lista | Where-Object { $_.Estado -eq 'device' })
    if ($Pedido) {
        $d = @($lista | Where-Object { $_.Serial -eq $Pedido })
        if ($d.Count -eq 0) { Stop-Traspaso "El móvil '$Pedido' no aparece en 'adb devices'." }
        if ($d[0].Estado -ne 'device') { Stop-Traspaso "El móvil '$Pedido' está '$($d[0].Estado)'. Desbloquéalo y acepta la depuración USB." }
        return $Pedido
    }
    if ($listos.Count -eq 1) { return $listos[0].Serial }
    if ($listos.Count -gt 1) { Stop-Traspaso ("Hay varios móviles: " + (($listos | ForEach-Object { $_.Serial }) -join ', ') + '. Indica cuál con -Dispositivo.') }
    if (@($lista | Where-Object { $_.Estado -eq 'unauthorized' }).Count -gt 0) {
        Stop-Traspaso 'El móvil no ha autorizado este PC: desbloquéalo y pulsa "Permitir" en el aviso de depuración USB.'
    }
    Stop-Traspaso 'No hay ningún móvil conectado con la depuración USB activa (adb devices).'
}

# ============================== fechas ==============================
$script:ReFechaHora = New-Object System.Text.RegularExpressions.Regex '(?<!\d)((?:19|20)\d{2})[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12]\d|3[01])[-_. T]?([01]\d|2[0-3])[-_.]?([0-5]\d)[-_.]?([0-5]\d)'
$script:ReFecha = New-Object System.Text.RegularExpressions.Regex '(?<!\d)((?:19|20)\d{2})[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12]\d|3[01])(?!\d)'
$script:AnioMaximo = (Get-Date).Year + 1

function Get-FechaNombre {
    param([string]$Nombre)
    $m = $script:ReFechaHora.Match($Nombre)
    if ($m.Success) {
        $g = $m.Groups
        try {
            $f = New-Object DateTime ([int]$g[1].Value), ([int]$g[2].Value), ([int]$g[3].Value), ([int]$g[4].Value), ([int]$g[5].Value), ([int]$g[6].Value)
            if ($f.Year -le $script:AnioMaximo) { return $f }
        }
        catch { Write-Verbose "Fecha con hora no válida en '$Nombre'." }
    }
    $m = $script:ReFecha.Match($Nombre)
    if ($m.Success) {
        $g = $m.Groups
        try {
            $f = New-Object DateTime ([int]$g[1].Value), ([int]$g[2].Value), ([int]$g[3].Value)
            if ($f.Year -le $script:AnioMaximo) { return $f }
        }
        catch { Write-Verbose "Fecha no válida en '$Nombre'." }
    }
    return $null
}

function Get-FechaExif {
    # Busca la fecha EXIF (AAAA:MM:DD hh:mm:ss) en la cabecera de un JPEG y devuelve la más antigua
    param([string]$Ruta)
    $buf = New-Object byte[] 131072
    $n = 0
    try {
        $fs = [IO.File]::OpenRead($Ruta)
        try { $n = $fs.Read($buf, 0, $buf.Length) } finally { $fs.Dispose() }
    }
    catch { return $null }
    if ($n -lt 4 -or $buf[0] -ne 0xFF -or $buf[1] -ne 0xD8) { return $null }
    $texto = [Text.Encoding]::GetEncoding(28591).GetString($buf, 0, $n)
    $minima = $null
    foreach ($m in [regex]::Matches($texto, '((?:19|20)\d{2}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})')) {
        try {
            $g = $m.Groups
            $f = New-Object DateTime ([int]$g[1].Value), ([int]$g[2].Value), ([int]$g[3].Value), ([int]$g[4].Value), ([int]$g[5].Value), ([int]$g[6].Value)
            if ($null -eq $minima -or $f -lt $minima) { $minima = $f }
        }
        catch { Write-Verbose 'Fecha EXIF no válida.' }
    }
    return $minima
}

function New-Elemento {
    param([string]$Ruta, [string[]]$Segmentos, [long]$Bytes, [datetime]$FechaMod)
    $nombre = $Segmentos[$Segmentos.Count - 1]
    [string[]]$dirSeg = @()
    if ($Segmentos.Count -gt 1) { $dirSeg = [string[]]$Segmentos[0..($Segmentos.Count - 2)] }
    $ext = [IO.Path]::GetExtension($nombre).TrimStart('.').ToLowerInvariant()
    $fNombre = Get-FechaNombre $nombre
    $fecha = $FechaMod
    $fuente = 'Modificacion'
    if ($FechaPor -eq 'Nombre' -and $null -ne $fNombre) { $fecha = $fNombre; $fuente = 'Nombre' }
    elseif ($UsarExif -and -not $script:EsAdb -and $ext -in @('jpg', 'jpeg', 'tif', 'tiff')) {
        $fe = Get-FechaExif $Ruta
        if ($null -ne $fe) { $fecha = $fe; $fuente = 'Exif' }
    }
    return [pscustomobject]@{
        Ruta = $Ruta; Relativa = ($Segmentos -join '/'); DirSeg = $dirSeg; Nombre = $nombre; Extension = $ext
        Bytes = $Bytes; FechaMod = $FechaMod; FechaNombre = $fNombre; Fecha = $fecha; Fuente = $fuente
    }
}

# ============================== inventario ==============================
function Test-Oculto {
    param([IO.FileSystemInfo]$Info)
    if ($script:VerOcultos) { return $false }
    if ($Info.Name.StartsWith('.')) { return $true }
    $a = $Info.Attributes
    return ((($a -band [IO.FileAttributes]::Hidden) -ne 0) -or (($a -band [IO.FileAttributes]::System) -ne 0))
}

function Get-InventarioLocal {
    param([string]$Raiz)
    $res = New-Object System.Collections.Generic.List[object]
    $pila = New-Object System.Collections.Generic.Stack[object]
    $pila.Push(@{ Dir = (New-Object IO.DirectoryInfo $Raiz); Seg = [string[]]@() })
    while ($pila.Count -gt 0) {
        $act = $pila.Pop()
        try { $hijos = $act.Dir.GetFileSystemInfos() }
        catch {
            if ($act.Seg.Count -eq 0) { Stop-Traspaso "No se puede leer el origen '$($act.Dir.FullName)': $($_.Exception.Message)" }
            $script:AvisosLectura++; Write-Linea "  Aviso: no se puede leer '$($act.Dir.FullName)': $($_.Exception.Message)" 'Yellow'; continue
        }
        foreach ($h in $hijos) {
            if (($h.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { $script:Enlaces++; continue }
            if (Test-Oculto $h) { $script:Ocultos++; continue }
            [string[]]$seg = @($act.Seg) + @($h.Name)
            if ($h -is [IO.DirectoryInfo]) {
                if (-not $Recursivo -or $h.Name -eq $PARCIAL -or ($act.Seg.Count -eq 0 -and $h.Name -eq '_traspaso')) { continue }
                if ($script:IdDestino -and (Get-IdFisico $h.FullName) -eq $script:IdDestino) {
                    Write-Linea "  Aviso: se salta '$($h.FullName)': es la carpeta de destino." 'Yellow'
                    continue
                }
                $pila.Push(@{ Dir = $h; Seg = $seg })
            }
            else {
                $res.Add((New-Elemento -Ruta $h.FullName -Segmentos $seg -Bytes $h.Length -FechaMod $h.LastWriteTime))
            }
        }
    }
    return , $res
}

function ConvertFrom-ListadoAdb {
    # Líneas "segundos|bytes|ruta" -> elementos. Cuenta también las líneas que no se entienden.
    param([string[]]$Lineas, [string]$Prefijo)
    $o = [pscustomobject]@{ Elementos = (New-Object System.Collections.Generic.List[object]); Total = 0; Ocultos = 0; Malas = 0; Metodo = ''; Motivo = '' }
    foreach ($l in $Lineas) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $p = $l.Split([char[]]'|', 3)
        $segundos = [double]0
        $bytes = 0L
        if ($p.Count -ne 3 -or -not [double]::TryParse($p[0], [Globalization.NumberStyles]::Float, $CI, [ref]$segundos) -or -not [long]::TryParse($p[1], [ref]$bytes)) { $o.Malas++; continue }
        $ruta = $p[2]
        if ($ruta.StartsWith($Prefijo + '/')) { $ruta = $Prefijo + $ruta.Substring($Prefijo.Length + 1) }
        if (-not $ruta.StartsWith($Prefijo)) { $o.Malas++; continue }
        $o.Total++
        [string[]]$seg = $ruta.Substring($Prefijo.Length).Split('/')
        if (-not $script:VerOcultos -and @($seg | Where-Object { $_.StartsWith('.') }).Count -gt 0) { $o.Ocultos++; continue }
        $fm = [DateTimeOffset]::FromUnixTimeSeconds([long][math]::Floor($segundos)).LocalDateTime
        $o.Elementos.Add((New-Elemento -Ruta $ruta -Segmentos $seg -Bytes $bytes -FechaMod $fm))
    }
    return $o
}

function Get-InventarioAdb {
    param([string]$Raiz)
    $q = ConvertTo-ShComillas $Raiz
    $r = Invoke-Adb -Argumentos @('shell', "if [ -d $q ]; then echo CARPETA_OK; else echo CARPETA_NO; fi")
    if (@($r.Salida | Where-Object { $_ -eq 'CARPETA_OK' }).Count -eq 0) {
        Stop-Traspaso "La carpeta '$Raiz' no existe en el móvil (o no se puede leer). $($r.Errores -join ' ')"
    }
    $profundidad = ''
    if (-not $Recursivo) { $profundidad = '-maxdepth 1 ' }
    $prefijo = $Raiz + '/'
    if ($Raiz -eq '/') { $prefijo = '/' }
    # Con '/' al final, find entra aunque la raíz sea un enlace (p. ej. /sdcard -> /storage/emulated/0)
    $baseFind = "find $(ConvertTo-ShComillas $prefijo) $($profundidad)-type f"
    # Cuántos archivos hay: sirve para comprobar que el listado salió completo
    $esperados = -1
    $rc = Invoke-Adb -Argumentos @('shell', "$baseFind 2>/dev/null | wc -l")
    $txtN = @($rc.Salida | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1)
    if ($rc.Codigo -eq 0 -and $txtN.Count -eq 1) { $esperados = [int]$txtN[0].Trim() }
    # Del más rápido al más lento. Algunos Android no tienen -printf, o cortan "-exec {} +" (Argument list too long)
    $metodos = @(
        @{ Nombre = 'find -printf'; Cmd = "$baseFind -printf '%T@|%s|%p\n'" }
        @{ Nombre = 'find | xargs'; Cmd = "$baseFind -print0 | xargs -0 -n 400 stat -c '%Y|%s|%n'" }
        @{ Nombre = 'archivo a archivo'; Cmd = "$baseFind -exec stat -c '%Y|%s|%n' {} \;" }
    )
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    $mejor = $null
    foreach ($m in $metodos) {
        $r = Invoke-Adb -Argumentos @('shell', $m.Cmd)
        $lect = ConvertFrom-ListadoAdb -Lineas $r.Salida -Prefijo $prefijo
        $errMovil = @($r.Errores | Where-Object { $_ -match '(^|\s)(find|xargs|stat|sh|toybox)\b.*:' })
        $motivos = New-Object System.Collections.Generic.List[string]
        if ($r.Codigo -ne 0) { $motivos.Add("código $($r.Codigo)") }
        if ($errMovil.Count -gt 0) { $motivos.Add(($errMovil | Select-Object -First 2) -join ' ') }
        if ($lect.Malas -gt 0) { $motivos.Add("$($lect.Malas) líneas no válidas") }
        if ($esperados -lt 0) { $motivos.Add('no se pudo contar los archivos para comprobar el listado') }
        elseif ($lect.Total -ne $esperados) { $motivos.Add("$($lect.Total) de $esperados archivos") }
        $lect.Metodo = $m.Nombre
        if ($motivos.Count -eq 0) { $mejor = $lect; break }
        $lect.Motivo = $motivos -join '; '
        if ($null -eq $mejor -or $lect.Total -gt $mejor.Total) { $mejor = $lect }
        Write-Linea "  Listado del móvil con '$($m.Nombre)' incompleto ($($lect.Motivo)); se prueba otro método..." 'DarkGray'
    }
    $script:Ocultos += $mejor.Ocultos
    $res = $mejor.Elementos
    Write-Linea ("  Listado del móvil: {0} archivos en {1:N0} s (método: {2})" -f $mejor.Total, $reloj.Elapsed.TotalSeconds, $mejor.Metodo) 'DarkGray'
    if ($mejor.Motivo) {
        if ($res.Count -eq 0) { Stop-Traspaso "No se pudo listar '$Raiz' en el móvil: $($mejor.Motivo)" }
        $script:AvisosLectura++
        Write-Linea "  Aviso: el listado del móvil está incompleto (se sigue con lo leído): $($mejor.Motivo)" 'Yellow'
    }
    return , $res
}

function Add-Indice {
    param([string]$Ruta, [long]$Bytes)
    $script:IdxRuta[$Ruta.ToLowerInvariant()] = $Bytes
    $script:IdxReal[$Ruta.ToLowerInvariant()] = $Ruta   # la ruta tal cual está en el disco (mayúsculas incluidas)
    $n = [IO.Path]::GetFileName($Ruta).ToLowerInvariant()
    if (-not $script:IdxNombre.ContainsKey($n)) { $script:IdxNombre[$n] = New-Object System.Collections.Generic.List[object] }
    $script:IdxNombre[$n].Add([pscustomobject]@{ Ruta = $Ruta; Bytes = $Bytes })
}

function Read-IndiceDestino {
    param([string]$Raiz)
    if (-not (Test-Path -LiteralPath $Raiz -PathType Container)) { return }
    $pila = New-Object System.Collections.Generic.Stack[object]
    $pila.Push(@{ Dir = (New-Object IO.DirectoryInfo $Raiz); Raiz = $true })
    while ($pila.Count -gt 0) {
        $act = $pila.Pop()
        try { $hijos = $act.Dir.GetFileSystemInfos() }
        catch {
            if ($act.Raiz) { Stop-Traspaso "No se puede leer el destino '$($act.Dir.FullName)': $($_.Exception.Message)" }
            $script:AvisosLectura++; Write-Linea "  Aviso: no se puede leer '$($act.Dir.FullName)' en el destino." 'Yellow'; continue
        }
        foreach ($h in $hijos) {
            if (($h.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            if ($h -is [IO.DirectoryInfo]) {
                if ($h.Name -eq $PARCIAL) { $script:Parciales.Add($h.FullName); continue }   # restos de un corte: no cuentan
                if (-not ($act.Raiz -and $h.Name -eq '_traspaso')) { $pila.Push(@{ Dir = $h; Raiz = $false }) }
            }
            else { Add-Indice -Ruta $h.FullName -Bytes $h.Length }
        }
    }
}

# ============================== plan ==============================
$script:NombresReservados = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')

function ConvertTo-NombreSeguro {
    # Nombre válido en Windows: cambia <>:"/\|?* y los caracteres de control por '_'
    param([string]$Nombre)
    $s = [regex]::Replace($Nombre, '[<>:"/\\|?*\x00-\x1F]', '_')
    if ($s -match '[. ]$') { $s = $s.TrimEnd('.', ' ') + '_' }
    if ($s -eq '') { $s = '_' }
    $base = [IO.Path]::GetFileNameWithoutExtension($s).ToUpperInvariant()
    if ($script:NombresReservados -contains $base) { $s = '_' + $s }
    return $s
}

function Get-DirDestino {
    param($E)
    switch ($Organizar) {
        'Ninguna' { return $script:DestinoFull }
        'Anio' { return [IO.Path]::Combine($script:DestinoFull, $E.Fecha.ToString('yyyy', $CI)) }
        'AnioMes' { return [IO.Path]::Combine($script:DestinoFull, $E.Fecha.ToString('yyyy', $CI), $E.Fecha.ToString('yyyy-MM', $CI)) }
        default {
            $d = $script:DestinoFull
            foreach ($s in $E.DirSeg) { $d = [IO.Path]::Combine($d, (ConvertTo-NombreSeguro $s)) }
            return $d
        }
    }
}

function Get-Variante {
    param([string]$Dir, [string]$Nombre, [int]$K)
    $base = [IO.Path]::GetFileNameWithoutExtension($Nombre)
    $ext = [IO.Path]::GetExtension($Nombre)
    return [IO.Path]::Combine($Dir, "$base ($K)$ext")
}

function Test-Ocupada {
    param([string]$Ruta)
    $k = $Ruta.ToLowerInvariant()
    return ($script:IdxRuta.ContainsKey($k) -or $script:Reservadas.ContainsKey($k))
}

function Get-RutaLibre {
    param([string]$Dir, [string]$Nombre)
    for ($k = 2; $k -lt 100000; $k++) {
        $c = Get-Variante -Dir $Dir -Nombre $Nombre -K $k
        if (-not (Test-Ocupada $c) -and -not (Test-Path -LiteralPath $c)) { return $c }
    }
    Stop-Traspaso "No hay nombre libre para '$Nombre' en '$Dir'."
}

function Set-Reserva {
    param([string]$Ruta)
    $script:Reservadas[$Ruta.ToLowerInvariant()] = $true
}

function New-Plan {
    param($E)
    $dir = Get-DirDestino $E
    $nombre = ConvertTo-NombreSeguro $E.Nombre
    $objetivo = [IO.Path]::Combine($dir, $nombre)
    $p = [pscustomobject]@{
        E = $E; Dir = $dir; NombreSeguro = $nombre; Accion = ''; RutaDestino = ''
        Candidatos = (New-Object System.Collections.Generic.List[string]); Detalle = ''
        HashOrigen = ''; HashFinal = ''; RutaTemporal = ''; AccionCopia = ''; MovidoAqui = $false; Verificado = $false; Preexistente = $false; Resultado = ''; EstadoOrigen = 'CONSERVADO'
    }
    if ($script:EsAdb -and $E.Ruta.Contains('"')) {
        $p.Accion = 'FALLO'; $p.Detalle = 'NOMBRE_NO_SOPORTADO (comillas dobles)'; return $p
    }
    $rutaOrigenMin = ''
    if (-not $script:EsAdb) { $rutaOrigenMin = $E.Ruta.ToLowerInvariant() }
    $k = $objetivo.ToLowerInvariant()
    if ($script:IdxRuta.ContainsKey($k)) {
        if ($script:IdxRuta[$k] -eq $E.Bytes) { $p.Candidatos.Add($script:IdxReal[$k]) }
        for ($i = 2; $i -lt 100000; $i++) {
            $v = Get-Variante -Dir $dir -Nombre $nombre -K $i
            $kv = $v.ToLowerInvariant()
            if (-not $script:IdxRuta.ContainsKey($kv)) { break }
            if ($script:IdxRuta[$kv] -eq $E.Bytes) { $p.Candidatos.Add($script:IdxReal[$kv]) }
        }
    }
    elseif (-not $script:Reservadas.ContainsKey($k) -and $Organizar -ne 'Original') {
        $n = $nombre.ToLowerInvariant()
        if ($script:IdxNombre.ContainsKey($n)) {
            foreach ($x in $script:IdxNombre[$n]) { if ($x.Bytes -eq $E.Bytes) { $p.Candidatos.Add($x.Ruta) } }
        }
    }
    # Nunca se compara un archivo consigo mismo (evita borrar la única copia)
    if ($rutaOrigenMin) {
        foreach ($c in @($p.Candidatos)) { if ($c.ToLowerInvariant() -eq $rutaOrigenMin) { [void]$p.Candidatos.Remove($c) } }
    }
    if ($p.Candidatos.Count -gt 0) {
        if ($script:NecesitaHash) { $p.Accion = 'VERIFICAR' }
        else { $p.Accion = 'YA_EXISTIA'; $p.RutaDestino = $p.Candidatos[0]; $p.Detalle = 'mismo nombre y tamaño' }
    }
    elseif (Test-Ocupada $objetivo) {
        $p.Accion = 'CONFLICTO'; $p.RutaDestino = Get-RutaLibre -Dir $dir -Nombre $nombre; Set-Reserva $p.RutaDestino
    }
    else {
        $p.Accion = 'COPIAR'; $p.RutaDestino = $objetivo; Set-Reserva $objetivo
    }
    return $p
}

# ============================== hashes ==============================
function Get-HashLocal {
    param([string]$Ruta, [switch]$SinCache)
    $k = $Ruta   # sin pasar a minúsculas: en sistemas que distinguen mayúsculas son archivos distintos
    if (-not $SinCache -and $script:CacheHash.ContainsKey($k)) { return $script:CacheHash[$k] }
    $h = ''
    try { $h = (Get-FileHash -LiteralPath $Ruta -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() }
    catch { $h = '' }
    if ($h) { $script:CacheHash[$k] = $h }   # un fallo de lectura no se recuerda: se reintentará
    return $h
}

function Set-HashesOrigen {
    param([object[]]$Planes)
    if (-not $Planes -or $Planes.Count -eq 0) { return }
    if (-not $script:EsAdb) {
        foreach ($p in $Planes) { $p.HashOrigen = Get-HashLocal $p.E.Ruta }
        return
    }
    $lotes = Get-Lotes -Elementos $Planes -Texto { param($x) ConvertTo-ShComillas $x.E.Ruta } -Max 3000
    foreach ($lote in $lotes) {
        $cmd = 'sha256sum ' + (($lote | ForEach-Object { ConvertTo-ShComillas $_.E.Ruta }) -join ' ')
        $r = Invoke-Adb -Argumentos @('shell', $cmd)
        $mapa = New-Object System.Collections.Hashtable -ArgumentList ([StringComparer]::Ordinal)   # distingue mayúsculas
        foreach ($l in $r.Salida) {
            if ($l -match '^([0-9a-fA-F]{64})\s+\*?(.+)$') { $mapa[$Matches[2]] = $Matches[1].ToLowerInvariant() }
        }
        foreach ($p in $lote) { if ($mapa.ContainsKey($p.E.Ruta)) { $p.HashOrigen = $mapa[$p.E.Ruta] } }
    }
}

# ============================== copia y borrado ==============================
function Copy-Interno {
    param($P)
    try {
        [IO.File]::Copy($P.E.Ruta, $P.RutaTemporal, $false)   # $false = nunca sobrescribir
        $fi = New-Object IO.FileInfo $P.E.Ruta
        [IO.File]::SetLastWriteTimeUtc($P.RutaTemporal, $fi.LastWriteTimeUtc)
        if ($script:EsWindows) { [IO.File]::SetCreationTimeUtc($P.RutaTemporal, $fi.CreationTimeUtc) }
    }
    catch { $P.Detalle = 'COPIA: ' + $_.Exception.Message }
}

function Sync-Disco {
    # Fuerza la escritura física (FlushFileBuffers). Un archivo de solo lectura se abre quitando el
    # atributo un momento y se le devuelve al terminar.
    param([string]$Ruta)
    $atributos = [IO.File]::GetAttributes($Ruta)
    $soloLectura = ($atributos -band [IO.FileAttributes]::ReadOnly) -ne 0
    if ($soloLectura) { [IO.File]::SetAttributes($Ruta, ($atributos -band (-bnot [IO.FileAttributes]::ReadOnly))) }
    try {
        $fs = New-Object IO.FileStream($Ruta, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
        try { $fs.Flush($true) } finally { $fs.Dispose() }
    }
    finally { if ($soloLectura) { [IO.File]::SetAttributes($Ruta, $atributos) } }
}

function Remove-Propio {
    # Borra una copia hecha por esta ejecución (aunque sea de solo lectura). $true = borrada o no estaba.
    param([string]$Ruta)
    try {
        if ([IO.File]::Exists($Ruta)) {
            [IO.File]::SetAttributes($Ruta, [IO.FileAttributes]::Normal)
            [IO.File]::Delete($Ruta)
        }
        return $true
    }
    catch { return $false }
}

function Copy-Bloque {
    param([object[]]$Planes)
    if (-not $Planes -or $Planes.Count -eq 0) { return }
    $porDir = @{}
    $sueltos = New-Object System.Collections.Generic.List[object]
    foreach ($p in $Planes) {
        $d = [IO.Path]::GetDirectoryName($p.RutaDestino)
        try { [void][IO.Directory]::CreateDirectory($d) }
        catch { $p.Detalle = 'CARPETA: ' + $_.Exception.Message; continue }
        if ($p.MovidoAqui) {
            # Reintento: el archivo final lo dejó esta ejecución sin asegurar en el disco; se rehace
            if (Remove-Propio $p.RutaDestino) { $p.MovidoAqui = $false }
        }
        if (Test-Path -LiteralPath $p.RutaDestino) {
            # Apareció entre el plan y la copia: no se sobrescribe, se renombra
            $p.RutaDestino = Get-RutaLibre -Dir $d -Nombre $p.NombreSeguro
            Set-Reserva $p.RutaDestino
            $p.Accion = 'CONFLICTO'
        }
        # Se copia a <carpeta>\.traspaso_parcial\<nombre final>; tras verificar se mueve a su sitio
        $tmpDir = [IO.Path]::Combine($d, $PARCIAL)
        try { [void][IO.Directory]::CreateDirectory($tmpDir) }
        catch { $p.Detalle = 'CARPETA: ' + $_.Exception.Message; continue }
        $p.RutaTemporal = [IO.Path]::Combine($tmpDir, [IO.Path]::GetFileName($p.RutaDestino))
        if (-not (Remove-Propio $p.RutaTemporal)) { $p.Detalle = 'CARPETA: no se pudo quitar un resto de copia anterior en ' + $PARCIAL; continue }   # resto propio de un corte
        $mismoNombre = ([IO.Path]::GetFileName($p.RutaDestino) -ceq $p.E.Nombre)
        if ($mismoNombre -and ($script:EsAdb -or $script:UsarRobocopy)) {
            $clave = $tmpDir
            if (-not $script:EsAdb) { $clave = [IO.Path]::GetDirectoryName($p.E.Ruta) + '|' + $tmpDir }
            if (-not $porDir.ContainsKey($clave)) { $porDir[$clave] = New-Object System.Collections.Generic.List[object] }
            $porDir[$clave].Add($p)
        }
        else { $sueltos.Add($p) }
    }
    foreach ($clave in $porDir.Keys) {
        $grupo = $porDir[$clave].ToArray()
        if ($script:EsAdb) {
            $lotes = Get-Lotes -Elementos $grupo -Texto { param($x) $x.E.Ruta } -Max 6000
            foreach ($lote in $lotes) {
                $argumentos = @('pull') + $script:OpcionesPull + @($lote | ForEach-Object { $_.E.Ruta }) + @($clave)
                $r = Invoke-Adb -Argumentos $argumentos
                if ($r.Codigo -ne 0) { foreach ($p in $lote) { $p.Detalle = 'adb pull: ' + (($r.Errores + $r.Salida) -join ' ') } }
            }
        }
        else {
            $partes = $clave.Split('|')
            $lotes = Get-Lotes -Elementos $grupo -Texto { param($x) $x.E.Nombre } -Max 6000
            foreach ($lote in $lotes) {
                $argumentos = @($partes[0], $partes[1]) + @($lote | ForEach-Object { $_.E.Nombre }) + @('/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/XC', '/XN', '/XO', '/NP', '/NJH', '/NJS', '/NFL', '/NDL')
                $global:LASTEXITCODE = 0
                & robocopy.exe @argumentos | Out-Null
                if ($global:LASTEXITCODE -ge 8) { foreach ($p in $lote) { $p.Detalle = "robocopy código $global:LASTEXITCODE" } }
            }
        }
    }
    foreach ($p in $sueltos) {
        if ($p.Detalle -like 'CARPETA:*') { continue }
        if ($script:EsAdb) {
            $r = Invoke-Adb -Argumentos (@('pull') + $script:OpcionesPull + @($p.E.Ruta, $p.RutaTemporal))
            if ($r.Codigo -ne 0) { $p.Detalle = 'adb pull: ' + (($r.Errores + $r.Salida) -join ' ') }
        }
        else { Copy-Interno $p }
    }
}

function Confirm-Copias {
    # Verifica las copias en .traspaso_parcial y las pasa a su nombre final sin sobrescribir
    param([object[]]$Planes)
    if (-not $Planes -or $Planes.Count -eq 0) { return }
    $dirsTemporales = @{}
    foreach ($p in $Planes) {
        if (-not $p.RutaTemporal) { $p.Accion = 'FALLO'; if (-not $p.Detalle) { $p.Detalle = 'COPIA: no se pudo preparar la copia' }; continue }
        $dirsTemporales[[IO.Path]::GetDirectoryName($p.RutaTemporal)] = $true
        $fi = $null
        if ([IO.File]::Exists($p.RutaTemporal)) { $fi = New-Object IO.FileInfo $p.RutaTemporal }
        if ($null -eq $fi) {
            $p.Accion = 'FALLO'; if (-not $p.Detalle) { $p.Detalle = 'COPIA: el archivo no llegó al destino' }; continue
        }
        # Forzar la escritura física en el disco antes de verificar (y de borrar luego en el origen)
        try { Sync-Disco $p.RutaTemporal }
        catch {
            $p.Accion = 'FALLO'; $p.Detalle = 'DISCO: no se pudo asegurar la escritura en el destino (' + $_.Exception.Message + ')'
            if (-not (Remove-Propio $p.RutaTemporal)) { $p.Detalle += ' (no se pudo borrar la copia temporal)' }
            continue
        }
        # Solo se borra el temporal: es de esta ejecución (nunca un archivo con su nombre final)
        if ($fi.Length -ne $p.E.Bytes) {
            $p.Detalle = "TAMANO: $($fi.Length) de $($p.E.Bytes) bytes $($p.Detalle)".Trim()
            $p.Accion = 'FALLO'
            if (-not (Remove-Propio $p.RutaTemporal)) { $p.Detalle += ' (no se pudo borrar la copia temporal)' }
            continue
        }
        if ($script:HashCopias) {
            $hd = Get-HashLocal -Ruta $p.RutaTemporal -SinCache
            if ($hd -ne $p.HashOrigen) {
                $p.Detalle = 'HASH: el SHA256 de la copia no coincide'
                $p.Accion = 'FALLO'
                if (-not (Remove-Propio $p.RutaTemporal)) { $p.Detalle += ' (no se pudo borrar la copia temporal)' }
                continue
            }
            $p.HashFinal = $hd
        }
        # Nombre final sin sobrescribir: File.Move falla si ya existe
        $movido = $false
        try { [IO.File]::Move($p.RutaTemporal, $p.RutaDestino); $movido = $true }
        catch {
            try {
                $nueva = Get-RutaLibre -Dir ([IO.Path]::GetDirectoryName($p.RutaDestino)) -Nombre $p.NombreSeguro
                [IO.File]::Move($p.RutaTemporal, $nueva)
                Set-Reserva $nueva
                $p.RutaDestino = $nueva; $p.Accion = 'CONFLICTO'; $movido = $true
            }
            catch { $p.Detalle = 'MOVER: ' + $_.Exception.Message }
        }
        if (-not $movido) {
            $p.Accion = 'FALLO'
            if (-not (Remove-Propio $p.RutaTemporal)) { $p.Detalle += ' (no se pudo borrar la copia temporal)' }
            continue
        }
        # Asegurar en el disco también el archivo ya con su nombre final
        try { Sync-Disco $p.RutaDestino }
        catch {
            # Es de esta ejecución y el original sigue intacto: se quita; si no se puede (disco
            # desconectado), el reintento lo quita antes de volver a copiar, sin crear un "(2)"
            $p.Accion = 'FALLO'; $p.Detalle = 'DISCO: no se pudo asegurar la escritura del archivo final (' + $_.Exception.Message + ')'
            if (-not (Remove-Propio $p.RutaDestino)) { $p.MovidoAqui = $true }
            continue
        }
        $p.Verificado = $true
        $p.Detalle = ''
        Add-Indice -Ruta $p.RutaDestino -Bytes $p.E.Bytes
    }
    foreach ($t in $dirsTemporales.Keys) {
        try { if (@([IO.Directory]::GetFileSystemEntries($t)).Count -eq 0) { [IO.Directory]::Delete($t) } } catch { Write-Verbose "No se pudo quitar '$t'." }
    }
}

function Get-Desconectados {
    # Qué falta ahora mismo: el móvil (o la carpeta de origen) y/o el disco de destino
    $faltan = New-Object System.Collections.Generic.List[string]
    if ($script:EsAdb) {
        $r = Invoke-Adb -Argumentos @('get-state')
        if ($r.Codigo -ne 0 -or @($r.Salida | Where-Object { $_ -eq 'device' }).Count -eq 0) { $faltan.Add('el móvil') }
    }
    elseif (-not (Test-Path -LiteralPath $origenLocal -PathType Container)) { $faltan.Add('el origen') }
    if (-not (Test-Path -LiteralPath $script:DestinoFull -PathType Container)) { $faltan.Add('el disco de destino'); $script:DestinoSePerdio = $true }
    return , $faltan
}

function Wait-Conexion {
    # Si falta el móvil o el disco, espera hasta -EsperaMin minutos. $true = se puede seguir.
    param([string]$Momento)
    $faltan = Get-Desconectados
    if ($faltan.Count -eq 0) { return $true }
    Write-Linea "`n  Se ha perdido la conexión con $($faltan -join ' y ') ($Momento)." 'Red'
    if ($script:EsperaMinutos -le 0) { return $false }
    Write-Linea "  Reconecta (cable, móvil desbloqueado y en 'Transferir archivos'; disco enchufado). Espero hasta $script:EsperaMinutos min. Ctrl+C para parar: lo hecho está a salvo." 'Yellow'
    Write-Estado 'ESPERANDO_CONEXION'
    $limite = (Get-Date).AddMinutes($script:EsperaMinutos)
    while ((Get-Date) -lt $limite) {
        Start-Sleep -Seconds 10
        if ((Get-Desconectados).Count -eq 0) { Write-Linea '  Conexión recuperada: se sigue.' 'Green'; Start-Sleep -Seconds 2; return $true }
    }
    Write-Linea "  Sigue sin conexión tras $script:EsperaMinutos min: se para. Relanza cuando esté conectado; lo hecho no se repite." 'Red'
    return $false
}

function Test-CopiasIntactas {
    # Justo antes de borrar en el origen: cada copia sigue en el disco con su tamaño. Si el disco se
    # desconectó en este bloque (-ConHash), además se vuelve a comprobar el SHA256.
    param([object[]]$Planes, [switch]$ConHash)
    foreach ($p in $Planes) {
        $ok = [IO.File]::Exists($p.RutaDestino) -and ((New-Object IO.FileInfo $p.RutaDestino).Length -eq $p.E.Bytes)
        if ($ok -and $ConHash -and $script:HashCopias) {
            $esperado = $p.HashFinal
            if (-not $esperado) { $esperado = $p.HashOrigen }
            $ok = ($esperado -and (Get-HashLocal -Ruta $p.RutaDestino -SinCache) -eq $esperado)
        }
        if (-not $ok) { $p.Verificado = $false; $p.Accion = 'FALLO'; $p.Detalle = 'DESTINO: la copia ya no está bien en el disco (¿desconexión?); no se borra el original' }
    }
}

function Remove-Origenes {
    param([object[]]$Planes)
    if (-not $Planes -or $Planes.Count -eq 0) { return }
    if (-not $script:EsAdb) {
        foreach ($p in $Planes) {
            if ($p.Preexistente) {
                # La "copia" ya estaba: confirmar que no es físicamente el mismo archivo que el original
                $idO = Get-IdFisico $p.E.Ruta
                $idD = Get-IdFisico $p.RutaDestino
                $realO = Get-RutaReal $p.E.Ruta
                $realD = Get-RutaReal $p.RutaDestino
                if (-not $idO -or -not $idD -or $idO -eq $idD -or ($realO -and $realD -and $realO -eq $realD)) {
                    $p.EstadoOrigen = 'ERROR_BORRADO'
                    $p.Detalle = 'NO_BORRADO: no se pudo confirmar que la copia y el original son archivos distintos'
                    continue
                }
            }
            try { [IO.File]::Delete($p.E.Ruta) } catch { $p.Detalle = ($p.Detalle + ' BORRADO: ' + $_.Exception.Message).Trim() }
            if ([IO.File]::Exists($p.E.Ruta)) { $p.EstadoOrigen = 'ERROR_BORRADO' } else { $p.EstadoOrigen = 'BORRADO_ORIGEN' }
        }
        return
    }
    # Un solo viaje por lote: rm y, después, comprobación explícita archivo a archivo (B = borrado, S = sigue)
    $lotes = Get-Lotes -Elementos $Planes -Texto { param($x) (ConvertTo-ShComillas $x.E.Ruta) * 2 + 'if [ -e ]; then echo S; else echo B; fi; ' } -Max 3000
    foreach ($lote in $lotes) {
        $qs = @($lote | ForEach-Object { ConvertTo-ShComillas $_.E.Ruta })
        $cmd = 'rm -f ' + ($qs -join ' ') + '; ' + (($qs | ForEach-Object { "if [ -e $_ ]; then echo S; else echo B; fi;" }) -join ' ')
        $r = Invoke-Adb -Argumentos @('shell', $cmd)
        $marcas = @($r.Salida | Where-Object { $_ -eq 'S' -or $_ -eq 'B' })
        for ($i = 0; $i -lt $lote.Count; $i++) {
            if ($marcas.Count -eq $lote.Count -and $marcas[$i] -eq 'B') { $lote[$i].EstadoOrigen = 'BORRADO_ORIGEN' }
            else {
                $lote[$i].EstadoOrigen = 'ERROR_BORRADO'
                if ($marcas.Count -ne $lote.Count) { $lote[$i].Detalle = ($lote[$i].Detalle + ' BORRADO: estado desconocido').Trim() }
            }
        }
    }
}

# ============================== estado e informes ==============================
function Write-Estado {
    param([string]$Estado)
    if (-not $script:DirTraspaso) { return }
    $c = $script:Cuenta
    $hechos = $script:Procesados
    $pct = 100
    if ($script:TotalSel -gt 0) { $pct = [math]::Round(100 * $hechos / $script:TotalSel, 1) }
    $eta = $null
    $seg = $script:Reloj.Elapsed.TotalSeconds
    if ($script:BytesHechos -gt 0 -and $script:BytesTotal -gt $script:BytesHechos) {
        $eta = [math]::Round((($script:BytesTotal - $script:BytesHechos) * $seg / $script:BytesHechos) / 60, 1)
    }
    $o = [ordered]@{
        Version = $VERSION_SCRIPT; IdEjecucion = $script:IdEjecucion; Estado = $Estado
        Inicio = $script:Inicio.ToString('s'); Actualizado = (Get-Date).ToString('s')
        Origen = $Origen; Destino = $script:DestinoFull; Modo = $Modo; Organizar = $Organizar
        Total = $script:TotalSel; Procesados = $hechos; Faltan = ($script:TotalSel - $hechos); Porcentaje = $pct
        MBTotal = [math]::Round($script:BytesTotal / 1MB, 1); MBHechos = [math]::Round($script:BytesHechos / 1MB, 1); EtaMin = $eta
        Copiados = $c['COPIADO']; YaExistian = $c['YA_EXISTIA']; Conflictos = $c['CONFLICTO_RENOMBRADO']; Fallos = $c['FALLO']
        BorradosOrigen = $c['BORRADO_ORIGEN']; ErroresBorrado = $c['ERROR_BORRADO']; Registro = $script:RutaCsv
    }
    $codif = New-Object System.Text.UTF8Encoding($false)
    try {
        [IO.File]::WriteAllText([IO.Path]::Combine($script:DirTraspaso, 'ESTADO.json'), ($o | ConvertTo-Json), $codif)
        $txt = @(
            "Traspaso $($o.IdEjecucion) - $Estado - actualizado $($o.Actualizado)"
            "Origen : $Origen"
            "Destino: $($o.Destino)   (modo $Modo)"
            ("Progreso: {0}% · {1} de {2} · faltan {3} · {4} de {5} MB · ETA {6} min" -f $pct, $hechos, $o.Total, $o.Faltan, $o.MBHechos, $o.MBTotal, $(if ($null -eq $eta) { '-' } else { $eta }))
            ("Copiados {0} · Ya existían {1} · Renombrados {2} · Fallos {3} · Borrados en origen {4} · Errores de borrado {5}" -f $o.Copiados, $o.YaExistian, $o.Conflictos, $o.Fallos, $o.BorradosOrigen, $o.ErroresBorrado)
            "Registro: $($o.Registro)"
        )
        [IO.File]::WriteAllText([IO.Path]::Combine($script:DirTraspaso, 'ESTADO.txt'), ($txt -join "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    }
    catch { Write-Linea "  Aviso: no se pudo escribir ESTADO: $($_.Exception.Message)" 'Yellow' }
}

function Write-InformeHtml {
    param([string]$Ruta, [object[]]$Filas)
    $enc = { param($t) [System.Net.WebUtility]::HtmlEncode([string]$t) }
    $c = $script:Cuenta
    $filasMal = @($Filas | Where-Object { $_.Resultado -eq 'FALLO' -or $_.EstadoOrigen -eq 'ERROR_BORRADO' -or $_.Resultado -eq 'CONFLICTO_RENOMBRADO' })
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Informe de traspaso</title>')
    [void]$sb.Append('<style>body{font:14px Segoe UI,system-ui,sans-serif;margin:20px;color:#1c2330}table{border-collapse:collapse;margin:10px 0}td,th{border:1px solid #ccd;padding:4px 8px;text-align:left}th{background:#eef}.mal{color:#b3261e}</style></head><body>')
    [void]$sb.Append("<h1>Informe de traspaso $(& $enc $script:IdEjecucion)</h1>")
    [void]$sb.Append("<p>Origen: <b>$(& $enc $Origen)</b><br>Destino: <b>$(& $enc $script:DestinoFull)</b><br>Modo: $(& $enc $Modo) · Organizar: $(& $enc $Organizar) · Verificación: $(& $enc $script:TextoVerif)</p>")
    [void]$sb.Append('<table><tr><th>Estado</th><th>Archivos</th></tr>')
    foreach ($k in @('COPIADO', 'YA_EXISTIA', 'CONFLICTO_RENOMBRADO', 'FALLO', 'BORRADO_ORIGEN', 'ERROR_BORRADO')) { [void]$sb.Append("<tr><td>$k</td><td>$($c[$k])</td></tr>") }
    [void]$sb.Append('</table>')
    [void]$sb.Append("<h2>Para revisar ($($filasMal.Count))</h2><table><tr><th>Resultado</th><th>Origen</th><th>Ruta origen</th><th>Ruta destino</th><th>Detalle</th></tr>")
    foreach ($f in $filasMal) { [void]$sb.Append("<tr class=""mal""><td>$(& $enc $f.Resultado)</td><td>$(& $enc $f.EstadoOrigen)</td><td>$(& $enc $f.RutaOrigen)</td><td>$(& $enc $f.RutaDestino)</td><td>$(& $enc $f.Detalle)</td></tr>") }
    [void]$sb.Append('</table><p>Registro completo: ' + (& $enc $script:RutaCsv) + '</p></body></html>')
    [IO.File]::WriteAllText($Ruta, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
}

# ============================== validación ==============================
$script:EsAdb = $Origen -match '^adb:'
$script:DestinoFull = ''
$script:DirTraspaso = ''
$script:RutaCsv = ''
$raizAdb = ''
$origenLocal = ''
if ($script:EsAdb) {
    $raizAdb = $Origen.Substring(4).Trim()
    if (-not $raizAdb.StartsWith('/')) { Stop-Traspaso "La ruta del móvil debe ser absoluta: adb:/sdcard/... (has puesto '$Origen')." }
    if ($raizAdb.Contains('"')) { Stop-Traspaso 'La ruta del móvil no puede contener comillas dobles.' }
    $raizAdb = $raizAdb.TrimEnd('/')
    if ($raizAdb -eq '') { $raizAdb = '/' }
    if ($UsarExif) { Write-Linea '  Aviso: -UsarExif solo se aplica a orígenes locales; se ignora con adb:.' 'Yellow' }
}
else {
    try { $origenLocal = (Resolve-RutaPs $Origen).TrimEnd('\', '/') }
    catch { Stop-Traspaso "El origen '$Origen' no está disponible (¿unidad o USB desconectado?): $($_.Exception.Message)" }
    if ($origenLocal -match '^[A-Za-z]:$') { $origenLocal += '\' }
    if (-not $origenLocal -or -not (Test-Path -LiteralPath $origenLocal -PathType Container)) { Stop-Traspaso "El origen '$Origen' no existe o no es una carpeta." }
}
if (-not $SoloInventario) {
    if (-not $Destino) { Stop-Traspaso 'Indica -Destino (o usa -SoloInventario).' }
    try { $script:DestinoFull = (Resolve-RutaPs $Destino).TrimEnd('\', '/') }
    catch { Stop-Traspaso "El destino '$Destino' no está disponible (¿unidad o recurso desconectado?): $($_.Exception.Message)" }
    if (-not $script:DestinoFull) { Stop-Traspaso "El destino '$Destino' no es una ruta válida." }
    if ($script:DestinoFull -match '^[A-Za-z]:$') { $script:DestinoFull += '\' }
    if (Test-Path -LiteralPath $script:DestinoFull -PathType Leaf) { Stop-Traspaso "El destino '$Destino' es un archivo, no una carpeta." }
    $raizDestino = $null
    try { $raizDestino = [IO.Path]::GetPathRoot($script:DestinoFull) } catch { $raizDestino = $null }
    if (-not $raizDestino -or -not (Test-Path -LiteralPath $raizDestino)) { Stop-Traspaso "La unidad o el recurso del destino ('$Destino') no está disponible." }
    if (Test-Path -LiteralPath $script:DestinoFull -PathType Container) { $script:IdDestino = Get-IdFisico $script:DestinoFull }
    if (-not $script:EsAdb) {
        # 1) Por el texto de las rutas
        if (Test-Contenida -Padre $script:DestinoFull -Hija $origenLocal) { Stop-Traspaso 'El origen no puede ser el destino ni estar dentro de él.' }
        if ($Recursivo -and (Test-Contenida -Padre $origenLocal -Hija $script:DestinoFull)) { Stop-Traspaso 'Con -Recursivo, el destino no puede estar dentro del origen.' }
        # 2) Por la ruta física real (unidades mapeadas, subst, junctions, enlaces, nombres cortos)
        $realOrigen = Get-RutaReal $origenLocal
        $realDestino = Get-RutaRealDestino $script:DestinoFull
        if ($realOrigen -and $realDestino) {
            if (Test-Contenida -Padre $realDestino -Hija $realOrigen) { Stop-Traspaso "El origen es (físicamente) el destino o está dentro de él: $realOrigen" }
            if ($Recursivo -and (Test-Contenida -Padre $realOrigen -Hija $realDestino)) { Stop-Traspaso "Con -Recursivo, el destino está (físicamente) dentro del origen: $realDestino" }
        }
        else { Write-Linea '  Aviso: no se pudo resolver la ruta física de origen o destino; se comparan las rutas tal cual.' 'Yellow' }
        # 3) Por identidad física: el destino no puede ser el origen ni uno de sus antecesores
        if ($script:IdDestino) {
            $act = $origenLocal
            if ($realOrigen) { $act = $realOrigen }
            while ($act) {
                if ((Get-IdFisico $act) -eq $script:IdDestino) { Stop-Traspaso "El origen está (físicamente) dentro del destino: $act" }
                $act = [IO.Path]::GetDirectoryName($act)
            }
        }
    }
}
if ($SoloInventario -and $SoloComparar) { Stop-Traspaso 'Usa -SoloInventario o -SoloComparar, no los dos.' }
foreach ($v in @($MinMB, $MaxMB)) {
    if ([double]::IsNaN($v) -or $v -lt 0 -or $v -gt 10000000) { Stop-Traspaso '-MinMB y -MaxMB deben estar entre 0 y 10.000.000 MB.' }
}
if ($MaxMB -gt 0 -and $MinMB -gt $MaxMB) { Stop-Traspaso "-MinMB ($MinMB) es mayor que -MaxMB ($MaxMB)." }
# Redondeo hacia el lado del filtro: el mínimo hacia arriba y el máximo hacia abajo (límites incluidos)
$bytesMin = [long][math]::Ceiling($MinMB * 1MB)
$bytesMax = [long][math]::Floor($MaxMB * 1MB)
if ($SoloInventario -and $Modo -eq 'Mover') { Stop-Traspaso '-SoloInventario no admite -Modo Mover.' }
if ($ConfirmarBorrado -and $Modo -ne 'Mover') { Stop-Traspaso '-ConfirmarBorrado solo tiene sentido con -Modo Mover.' }

# Filtros
$extSet = @{}
foreach ($x in @($Extensiones)) { foreach ($y in ("$x" -split '[,; ]+')) { $y = $y.Trim().TrimStart('.').ToLowerInvariant(); if ($y) { $extSet[$y] = $true } } }
$likePatron = $null
$rePatron = $null
if ($Patron) {
    if ($Patron.StartsWith('re:')) {
        try { $rePatron = New-Object System.Text.RegularExpressions.Regex ($Patron.Substring(3)), ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase) }
        catch { Stop-Traspaso "Expresión regular no válida en -Patron: $($_.Exception.Message)" }
    }
    else { $likePatron = $Patron }
}
$excluirLista = @(@($Excluir) | Where-Object { $_ } | ForEach-Object { $_.Replace('\', '/') })

function ConvertTo-FechaLimite {
    param([string]$Texto, [bool]$Fin)
    $f = [datetime]::MinValue
    $estilo = [Globalization.DateTimeStyles]::None
    if ([datetime]::TryParseExact($Texto, [string[]]@('yyyy-MM-dd', 'yyyy-M-d'), $CI, $estilo, [ref]$f) -and $f.Year -ge 1990 -and $f.Year -le 2100) {
        if ($Fin) { return $f.AddDays(1).AddTicks(-1) }
        return $f
    }
    if ([datetime]::TryParseExact($Texto, [string[]]@('yyyy-MM', 'yyyy-M'), $CI, $estilo, [ref]$f) -and $f.Year -ge 1990 -and $f.Year -le 2100) {
        if ($Fin) { return $f.AddMonths(1).AddTicks(-1) }
        return $f
    }
    Stop-Traspaso "Fecha no válida '$Texto': usa AAAA-MM o AAAA-MM-DD (años 1990-2100)."
}
$fDesde = $null
$fHasta = $null
if ($Desde) { $fDesde = ConvertTo-FechaLimite -Texto $Desde -Fin $false }
if ($Hasta) { $fHasta = ConvertTo-FechaLimite -Texto $Hasta -Fin $true }
if ($null -ne $fDesde -and $null -ne $fHasta -and $fDesde -gt $fHasta) { Stop-Traspaso '-Desde es posterior a -Hasta.' }
$anioSet = @{}
foreach ($a in @($Anio)) { if ($a) { $anioSet[[int]$a] = $true } }

function Test-Filtro {
    param($E)
    if ($extSet.Count -gt 0 -and -not $extSet.ContainsKey($E.Extension)) { return $false }
    if ($likePatron -and -not ($E.Nombre -like $likePatron)) { return $false }
    if ($rePatron -and -not $rePatron.IsMatch($E.Nombre)) { return $false }
    foreach ($x in $excluirLista) { if ($E.Nombre -like $x -or $E.Relativa -like $x) { return $false } }
    if ($null -ne $fDesde -and $E.Fecha -lt $fDesde) { return $false }
    if ($null -ne $fHasta -and $E.Fecha -gt $fHasta) { return $false }
    if ($anioSet.Count -gt 0 -and -not $anioSet.ContainsKey($E.Fecha.Year)) { return $false }
    if ($bytesMin -gt 0 -and $E.Bytes -lt $bytesMin) { return $false }
    if ($MaxMB -gt 0 -and $E.Bytes -gt $bytesMax) { return $false }   # por MaxMB: un máximo de menos de 1 byte no es "sin máximo"
    return $true
}

# ============================== inventario ==============================
Write-Linea "=== Traspasar-Archivos v$VERSION_SCRIPT ===" 'Cyan'
if ($script:EsAdb) {
    $script:AdbExe = Resolve-Adb $Adb
    $script:Serial = Select-Dispositivo $Dispositivo
    # Fotos y vídeos ya van comprimidos: sin la compresión de adb el traspaso pesa menos en el móvil
    $ayuda = Invoke-Adb -Argumentos @('help')
    if ((@($ayuda.Salida) + @($ayuda.Errores)) -join "`n" -match 'pull[^\n]*\[-Z\]') { $script:OpcionesPull = @('-a', '-Z') }
    $txtZ = ''
    if ($script:OpcionesPull -contains '-Z') { $txtZ = '   ·   pull sin compresión (-Z)' }
    Write-Linea "Móvil: $script:Serial   ·   adb: $script:AdbExe$txtZ" 'DarkGray'
    $todos = Get-InventarioAdb $raizAdb
}
else {
    $todos = Get-InventarioLocal $origenLocal
}
if ($OrdenPor -eq 'Tamano') { $sel = @($todos | Where-Object { Test-Filtro $_ } | Sort-Object -Property @{ Expression = 'Bytes'; Descending = $true }, Relativa) }
else { $sel = @($todos | Where-Object { Test-Filtro $_ } | Sort-Object -Property Fecha, Relativa) }
$textoExtra = "ocultos excluidos: $script:Ocultos"
if ($script:Enlaces) { $textoExtra += " · enlaces/junctions saltados: $script:Enlaces (también archivos de OneDrive solo en la nube)" }
Write-Linea ("Origen: {0}  ·  {1} archivos leídos, {2} tras los filtros ({3})" -f $Origen, $todos.Count, $sel.Count, $textoExtra) 'White'

if ($SoloInventario) {
    if ($sel.Count -eq 0) { Write-Linea 'No hay archivos que cumplan los filtros.' 'Yellow'; exit 0 }
    $resumen = foreach ($g in ($sel | Group-Object -Property { $_.Fecha.Year } | Sort-Object -Property Name)) {
        [pscustomobject]@{
            Anio = $g.Name; Archivos = $g.Count; MB = [math]::Round((($g.Group | Measure-Object -Property Bytes -Sum).Sum) / 1MB, 1)
            FechaDelNombre = @($g.Group | Where-Object { $_.Fuente -eq 'Nombre' }).Count
            Discrepan = @($g.Group | Where-Object { $null -ne $_.FechaNombre -and $_.FechaNombre.ToString('yyyy-MM', $CI) -ne $_.FechaMod.ToString('yyyy-MM', $CI) }).Count
        }
    }
    Write-Linea "`nPor año (Discrepan = archivos cuyo mes según el nombre no coincide con el de modificación):" 'Cyan'
    Write-Tabla @($resumen)
    Write-Linea "`nPor mes:" 'Cyan'
    Write-Tabla @($sel | Group-Object -Property { $_.Fecha.ToString('yyyy-MM', $CI) } | Sort-Object -Property Name | ForEach-Object {
            [pscustomobject]@{ Mes = $_.Name; Archivos = $_.Count; MB = [math]::Round((($_.Group | Measure-Object -Property Bytes -Sum).Sum) / 1MB, 1) }
        })
    $total = ($sel | Measure-Object -Property Bytes -Sum).Sum
    Write-Linea ("Total: {0} archivos · {1} MB · criterio de fecha: {2}" -f $sel.Count, (Format-MB $total), $FechaPor) 'Green'
    if ($script:AvisosLectura -gt 0) { Write-Linea "  Ojo: no se pudo leer todo el origen ($script:AvisosLectura avisos): el inventario puede estar incompleto." 'Red'; exit 1 }
    exit 0
}

# ============================== plan ==============================
$script:NecesitaHash = ($Hash -or $Modo -eq 'Mover') -and -not $SoloComparar
$script:TextoVerif = 'tamaño'
if ($Hash -or $Modo -eq 'Mover') { $script:TextoVerif = 'tamaño + SHA256' }
# Candado ANTES de leer el destino: el plan no puede quedarse viejo por otra ejecución
if (-not $WhatIfPreference -and -not $SoloComparar) {
    $script:DirTraspaso = [IO.Path]::Combine($script:DestinoFull, '_traspaso')
    try { [void][IO.Directory]::CreateDirectory($script:DirTraspaso) } catch { Stop-Traspaso "No se puede crear '$script:DirTraspaso': $($_.Exception.Message)" }
    $script:RutaCandado = [IO.Path]::Combine($script:DirTraspaso, 'EN_CURSO.lock')
    try { $script:Candado = [IO.File]::Open($script:RutaCandado, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { $script:RutaCandado = ''; Stop-Traspaso "Ya hay otro traspaso en curso sobre '$script:DestinoFull'. Espera a que termine (si no hay ninguno, borra _traspaso\EN_CURSO.lock)." }
}
Read-IndiceDestino $script:DestinoFull
if ($script:Candado -and $script:Parciales.Count -gt 0) {
    foreach ($t in $script:Parciales) {
        try { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop } catch { Write-Linea "  Aviso: no se pudo limpiar '$t'." 'Yellow' }
    }
    Write-Linea "  Limpiadas $($script:Parciales.Count) carpetas $PARCIAL de una ejecución cortada." 'DarkGray'
}
$planes = New-Object System.Collections.Generic.List[object]
foreach ($e in $sel) { $planes.Add((New-Plan $e)) }

# Topes (-MaxArchivos / -MaxGB): se cuentan los archivos que hay que copiar o comprobar
$planesSel = New-Object System.Collections.Generic.List[object]
$nAccion = 0
$bytesAccion = 0.0
foreach ($p in $planes) {
    $esAccion = $p.Accion -in @('COPIAR', 'CONFLICTO', 'VERIFICAR')
    if ($esAccion) {
        if ($MaxArchivos -gt 0 -and $nAccion -ge $MaxArchivos) { break }
        if ($MaxGB -gt 0 -and ($bytesAccion + $p.E.Bytes) -gt ($MaxGB * 1GB) -and $nAccion -gt 0) { break }
        $nAccion++
        $bytesAccion += $p.E.Bytes
    }
    $planesSel.Add($p)
}
$planes = $planesSel

$cuentaPlan = @{ COPIAR = 0; CONFLICTO = 0; VERIFICAR = 0; YA_EXISTIA = 0; FALLO = 0 }
foreach ($p in $planes) { $cuentaPlan[$p.Accion]++ }
$bytesCopiar = 0.0
foreach ($p in $planes) { if ($p.Accion -in @('COPIAR', 'CONFLICTO', 'VERIFICAR')) { $bytesCopiar += $p.E.Bytes } }
$bytesSel = 0.0
foreach ($p in $planes) { $bytesSel += $p.E.Bytes }

$libreGB = $null
try { $di = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($script:DestinoFull)); if ($di.IsReady) { $libreGB = [math]::Round($di.AvailableFreeSpace / 1GB, 1) } } catch { $libreGB = $null }

Write-Linea ''
Write-Linea "Destino : $script:DestinoFull" 'White'
Write-Linea "Modo    : $Modo · Organizar: $Organizar · Fecha: $FechaPor · Verificación: $script:TextoVerif" 'White'
Write-Linea ("Selección: {0} archivos ({1} MB)" -f $planes.Count, (Format-MB $bytesSel)) 'White'
Write-Linea ("  A copiar: {0} · Ya en destino: {1} · A comprobar por SHA256: {2} · Conflictos (se renombran): {3} · No soportados: {4}" -f $cuentaPlan['COPIAR'], $cuentaPlan['YA_EXISTIA'], $cuentaPlan['VERIFICAR'], $cuentaPlan['CONFLICTO'], $cuentaPlan['FALLO']) 'White'
Write-Linea ("  Datos a copiar (máximo): {0} MB · Espacio libre en destino: {1}" -f (Format-MB $bytesCopiar), $(if ($null -eq $libreGB) { 'no disponible' } else { "$libreGB GB" })) 'White'
if ($MaxArchivos -gt 0 -or $MaxGB -gt 0) { Write-Linea "  Topes activos: MaxArchivos=$MaxArchivos · MaxGB=$MaxGB (lo demás queda para la siguiente ejecución)." 'DarkGray' }

if ($SoloComparar) {
    $ya = $cuentaPlan['YA_EXISTIA']
    $faltan = @($planes | Where-Object { $_.Accion -in @('COPIAR', 'CONFLICTO') })
    $pct = 100
    if ($planes.Count -gt 0) { $pct = [math]::Round(100 * $ya / $planes.Count, 1) }
    Write-Linea ''
    Write-Linea ("COMPARACIÓN: {0}% hecho · ya en destino {1} de {2} · faltan {3} ({4} MB) · no soportados {5}" -f $pct, $ya, $planes.Count, $faltan.Count, (Format-MB (($faltan | ForEach-Object { $_.E.Bytes } | Measure-Object -Sum).Sum)), $cuentaPlan['FALLO']) 'Green'
    if ($faltan.Count -gt 0) {
        Write-Linea 'Primeros que faltan:' 'Cyan'
        Write-Tabla @($faltan | Select-Object -First 20 | ForEach-Object { [pscustomobject]@{ Fecha = $_.E.Fecha.ToString('yyyy-MM-dd', $CI); MB = [math]::Round($_.E.Bytes / 1MB, 2); Archivo = $_.E.Relativa; Nota = $(if ($_.Accion -eq 'CONFLICTO') { 'existe otro con ese nombre' } else { '' }) } })
        if ((Test-Path -LiteralPath $script:DestinoFull -PathType Container) -and -not $WhatIfPreference) {
            $dirT = [IO.Path]::Combine($script:DestinoFull, '_traspaso')
            [void][IO.Directory]::CreateDirectory($dirT)
            $rutaF = [IO.Path]::Combine($dirT, ('faltantes_{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
            $filasF = @($faltan | ForEach-Object { [pscustomobject]@{ RutaOrigen = $_.E.Ruta; Bytes = $_.E.Bytes; FechaArchivo = $_.E.Fecha.ToString('s'); RutaDestinoPrevista = $_.RutaDestino; Nota = $_.Accion } })
            Add-FilasCsv -Ruta $rutaF -Filas $filasF
            Write-Linea "Lista completa de faltantes: $rutaF" 'Green'
        }
    }
    if ($script:AvisosLectura -gt 0) { Write-Linea "  Ojo: no se pudo leer todo ($script:AvisosLectura avisos): la comparación puede estar incompleta." 'Red'; exit 1 }
    exit 0
}

if ($planes.Count -eq 0) {
    Close-Candado
    if ($script:AvisosLectura -gt 0) { Write-Linea "No hay nada que traspasar, pero no se pudo leer todo ($script:AvisosLectura avisos)." 'Red'; exit 1 }
    Write-Linea 'No hay nada que traspasar con esos filtros.' 'Yellow'
    exit 0
}
if ($null -ne $libreGB -and ($bytesCopiar / 1GB) -gt $libreGB) {
    Stop-Traspaso ("No cabe: hacen falta hasta {0} GB y en el destino hay {1} GB libres. Usa -MaxGB o libera espacio." -f [math]::Round($bytesCopiar / 1GB, 1), $libreGB)
}

if (-not $PSCmdlet.ShouldProcess($script:DestinoFull, ("Traspasar {0} archivos ({1} MB) en modo {2}" -f $planes.Count, (Format-MB $bytesSel), $Modo))) {
    if ($WhatIfPreference) {
        Write-Linea "`nSIMULACIÓN (-WhatIf): no se ha copiado, borrado ni escrito nada. Primeros 15 del plan:" 'Yellow'
        Write-Tabla -Ajustar @($planes | Select-Object -First 15 | ForEach-Object {
                $accion = $_.Accion
                if ($accion -eq 'VERIFICAR') { $accion = 'COMPROBAR_SHA256' }
                [pscustomobject]@{ Accion = $accion; Archivo = $_.E.Relativa; Destino = $(if ($_.RutaDestino) { $_.RutaDestino } else { '(se decide al comprobar)' }) }
            })
    }
    Close-Candado
    exit 0
}

if ($Modo -eq 'Mover') {
    Write-Linea "`nSe BORRARÁN del origen los archivos cuya copia quede verificada ($($planes.Count) seleccionados)." 'Red'
    $respuesta = $ConfirmarBorrado
    if (-not $respuesta) { $respuesta = Read-Host 'Escribe BORRAR (en mayúsculas) para confirmar; otra cosa = solo copiar' }
    if ($respuesta -cne 'BORRAR') { Write-Linea 'Sin confirmación: se COPIA sin borrar nada del origen.' 'Yellow'; $Modo = 'Copiar' }
}
# Al Mover, todo lo que se borra en el origen se verifica antes por SHA256 (copias nuevas incluidas)
$script:HashCopias = $Hash -or ($Modo -eq 'Mover')

# ============================== ejecución ==============================
$script:UsarRobocopy = (-not $script:EsAdb) -and (($Motor -eq 'Robocopy') -or ($Motor -eq 'Auto' -and $script:EsWindows -and $Organizar -eq 'Original'))
if ($script:UsarRobocopy -and -not (Get-Command robocopy.exe -ErrorAction SilentlyContinue)) {
    if ($Motor -eq 'Robocopy') { Stop-Traspaso 'No encuentro robocopy.exe.' }
    $script:UsarRobocopy = $false
}
$script:IdEjecucion = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$script:Inicio = Get-Date
$script:Reloj = [System.Diagnostics.Stopwatch]::StartNew()
$script:RutaCsv = [IO.Path]::Combine($script:DirTraspaso, "registro_$($script:IdEjecucion).csv")
$script:Cuenta = @{ COPIADO = 0; YA_EXISTIA = 0; CONFLICTO_RENOMBRADO = 0; FALLO = 0; BORRADO_ORIGEN = 0; ERROR_BORRADO = 0 }
$script:TotalSel = $planes.Count
$script:Procesados = 0
$script:BytesTotal = $bytesSel
$script:BytesHechos = 0.0
$todasFilas = New-Object System.Collections.Generic.List[object]
$estadoFinal = 'INTERRUMPIDO'
$nBloques = [math]::Ceiling($planes.Count / $Bloque)
Write-Estado 'EN_CURSO'

try {
    for ($i = 0; $i -lt $planes.Count; $i += $Bloque) {
        $nb = [math]::Floor($i / $Bloque) + 1
        $fin = [math]::Min($i + $Bloque, $planes.Count) - 1
        $bloquePlanes = @($planes[$i..$fin])
        Write-Linea "`n--- Bloque $nb de $nBloques ($($i + 1)-$($fin + 1) de $($planes.Count)) ---" 'Cyan'
        if (-not (Wait-Conexion 'antes del bloque')) { $script:Cortado = $true; break }
        $script:DestinoSePerdio = $false
        Write-Progress -Activity 'Traspasar-Archivos' -Status "Bloque $nb de $nBloques" -PercentComplete ([math]::Min(100, [int](100 * $i / $planes.Count)))

        # 1) Hashes del origen que hacen falta
        $necesitanHash = @($bloquePlanes | Where-Object { $_.Accion -eq 'VERIFICAR' -or ($script:HashCopias -and $_.Accion -in @('COPIAR', 'CONFLICTO')) })
        Set-HashesOrigen $necesitanHash

        # 2) Lo que podía existir ya: se decide por SHA256
        foreach ($p in @($bloquePlanes | Where-Object { $_.Accion -eq 'VERIFICAR' })) {
            if (-not $p.HashOrigen) { $p.Accion = 'FALLO'; $p.Detalle = 'HASH_ORIGEN: no se pudo calcular el SHA256 en el origen'; continue }
            $igual = $null
            $ilegible = $false
            foreach ($c in $p.Candidatos) {
                $hc = Get-HashLocal $c
                if (-not $hc) { $ilegible = $true; continue }
                if ($hc -eq $p.HashOrigen) { $igual = $c; break }
            }
            # Si algún archivo existente no se pudo leer (¿disco desconectado?), no se decide nada: ni copia "(2)" ni borrado
            if (-not $igual -and $ilegible) { $p.Accion = 'FALLO'; $p.Detalle = 'HASH_DESTINO: no se pudo leer un archivo que ya estaba en el destino'; continue }
            if ($igual) { $p.Accion = 'YA_EXISTIA'; $p.RutaDestino = $igual; $p.HashFinal = $p.HashOrigen; $p.Verificado = $true; $p.Preexistente = $true; $p.Detalle = 'mismo SHA256' }
            else {
                $objetivo = [IO.Path]::Combine($p.Dir, $p.NombreSeguro)
                if (Test-Ocupada $objetivo) { $p.Accion = 'CONFLICTO'; $p.RutaDestino = Get-RutaLibre -Dir $p.Dir -Nombre $p.NombreSeguro }
                else { $p.Accion = 'COPIAR'; $p.RutaDestino = $objetivo }
                Set-Reserva $p.RutaDestino
            }
        }
        foreach ($p in @($bloquePlanes | Where-Object { $script:HashCopias -and $_.Accion -in @('COPIAR', 'CONFLICTO') -and -not $_.HashOrigen })) {
            $p.Accion = 'FALLO'; $p.Detalle = 'HASH_ORIGEN: no se pudo calcular el SHA256 en el origen'
        }

        # 3) Copia
        $aCopiar = @($bloquePlanes | Where-Object { $_.Accion -in @('COPIAR', 'CONFLICTO') })
        foreach ($p in $aCopiar) { $p.AccionCopia = $p.Accion }
        Copy-Bloque $aCopiar

        # 4) Verificación (y, si falló algo por una desconexión, esperar y reintentarlo una vez)
        Confirm-Copias $aCopiar
        $fallidas = @($aCopiar | Where-Object { $_.Accion -eq 'FALLO' -and $_.AccionCopia })
        if ($fallidas.Count -gt 0 -and (Get-Desconectados).Count -gt 0) {
            if (Wait-Conexion 'durante la copia') {
                foreach ($p in $fallidas) { $p.Accion = $p.AccionCopia; $p.Detalle = ''; $p.RutaTemporal = '' }
                if ($script:HashCopias) {
                    Set-HashesOrigen @($fallidas | Where-Object { -not $_.HashOrigen })
                    foreach ($p in @($fallidas | Where-Object { -not $_.HashOrigen })) { $p.Accion = 'FALLO'; $p.Detalle = 'HASH_ORIGEN: no se pudo calcular el SHA256 en el origen' }
                }
                $re = @($fallidas | Where-Object { $_.Accion -in @('COPIAR', 'CONFLICTO') })
                Write-Linea "  Reintentando $($re.Count) archivos que fallaron por la desconexión..." 'DarkGray'
                Copy-Bloque $re
                Confirm-Copias $re
            }
            else { $script:Cortado = $true }
        }

        # 5) Mover: borrar en el origen solo lo verificado
        if ($Modo -eq 'Mover' -and -not $script:Cortado) {
            if (-not (Wait-Conexion 'antes de borrar en el origen')) { $script:Cortado = $true }
            else {
                Test-CopiasIntactas -Planes @($bloquePlanes | Where-Object { $_.Verificado }) -ConHash:$script:DestinoSePerdio
                Remove-Origenes @($bloquePlanes | Where-Object { $_.Verificado })
            }
        }

        # 6) Registro
        $filas = New-Object System.Collections.Generic.List[object]
        foreach ($p in $bloquePlanes) {
            switch ($p.Accion) {
                'COPIAR' { $p.Resultado = 'COPIADO' }
                'CONFLICTO' { $p.Resultado = 'CONFLICTO_RENOMBRADO' }
                'YA_EXISTIA' { $p.Resultado = 'YA_EXISTIA' }
                default { $p.Resultado = 'FALLO' }
            }
            if (-not $p.Verificado -and $p.Resultado -ne 'YA_EXISTIA') { $p.Resultado = 'FALLO' }
            $script:Cuenta[$p.Resultado]++
            if ($p.EstadoOrigen -ne 'CONSERVADO') { $script:Cuenta[$p.EstadoOrigen]++ }
            $script:Procesados++
            $script:BytesHechos += $p.E.Bytes
            $filas.Add([pscustomobject]@{
                    FechaHora = (Get-Date).ToString('s'); Resultado = $p.Resultado; EstadoOrigen = $p.EstadoOrigen
                    RutaOrigen = $p.E.Ruta; RutaDestino = $p.RutaDestino; Bytes = $p.E.Bytes
                    FechaArchivo = $p.E.Fecha.ToString('s'); FuenteFecha = $p.E.Fuente; SHA256 = $p.HashFinal; Detalle = $p.Detalle
                })
        }
        try { Add-FilasCsv -Ruta $script:RutaCsv -Filas $filas.ToArray() }
        catch {
            $escrito = $false
            if (Wait-Conexion 'al escribir el registro') {
                try { Add-FilasCsv -Ruta $script:RutaCsv -Filas $filas.ToArray(); $escrito = $true } catch { Write-Verbose $_.Exception.Message }
            }
            if (-not $escrito) { Write-Linea "  No se pudo escribir el registro de este bloque: $($_.Exception.Message)" 'Red'; $script:Cortado = $true }
        }
        foreach ($f in $filas) { $todasFilas.Add($f) }
        $c = $script:Cuenta
        Write-Linea ("  Copiados {0} · Ya existían {1} · Renombrados {2} · Fallos {3} · Borrados en origen {4} · Errores de borrado {5}" -f $c['COPIADO'], $c['YA_EXISTIA'], $c['CONFLICTO_RENOMBRADO'], $c['FALLO'], $c['BORRADO_ORIGEN'], $c['ERROR_BORRADO'])
        Write-Estado 'EN_CURSO'

        if ($script:Cortado) { break }
        if (-not $SinPausa -and $fin -lt $planes.Count - 1) {
            if ((Read-Host '¿Siguiente bloque? (S/n)') -match '^[nN]') { $estadoFinal = 'CANCELADO'; break }
        }
    }
    if ($script:Cortado) { $estadoFinal = 'INTERRUMPIDO' }
    elseif ($estadoFinal -ne 'CANCELADO') {
        $estadoFinal = 'TERMINADO'
        if ($script:Cuenta['FALLO'] -gt 0 -or $script:Cuenta['ERROR_BORRADO'] -gt 0 -or $script:AvisosLectura -gt 0) { $estadoFinal = 'TERMINADO_CON_FALLOS' }
    }
}
finally {
    Write-Progress -Activity 'Traspasar-Archivos' -Completed
    Write-Estado $estadoFinal
    Close-Candado
}

# ============================== resumen final ==============================
$c = $script:Cuenta
Write-Linea "`n===== RESUMEN ($estadoFinal) =====" 'Green'
foreach ($k in @('COPIADO', 'YA_EXISTIA', 'CONFLICTO_RENOMBRADO', 'FALLO', 'BORRADO_ORIGEN', 'ERROR_BORRADO')) {
    $color = 'Gray'
    if ($k -in @('FALLO', 'ERROR_BORRADO') -and $c[$k] -gt 0) { $color = 'Red' }
    Write-Linea ("  {0,-22} {1,8}" -f $k, $c[$k]) $color
}
Write-Linea "  Procesados: $script:Procesados de $script:TotalSel · Duración: $($script:Reloj.Elapsed.ToString('hh\:mm\:ss'))"
Write-Linea "  Registro : $script:RutaCsv"
Write-Linea "  Estado   : $([IO.Path]::Combine($script:DirTraspaso, 'ESTADO.txt'))"
foreach ($formato in @($Informe)) {
    if (-not $formato) { continue }
    try {
        if ($formato -eq 'Html') {
            $rutaH = [IO.Path]::Combine($script:DirTraspaso, "informe_$($script:IdEjecucion).html")
            Write-InformeHtml -Ruta $rutaH -Filas $todasFilas.ToArray()
            Write-Linea "  Informe  : $rutaH"
        }
        else {
            $rutaJ = [IO.Path]::Combine($script:DirTraspaso, "informe_$($script:IdEjecucion).json")
            $json = [ordered]@{ IdEjecucion = $script:IdEjecucion; Estado = $estadoFinal; Origen = $Origen; Destino = $script:DestinoFull; Modo = $Modo; Cuentas = $c; Filas = $todasFilas.ToArray() }
            [IO.File]::WriteAllText($rutaJ, ($json | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
            Write-Linea "  Informe  : $rutaJ"
        }
    }
    catch { Write-Linea "  Aviso: no se pudo generar el informe $formato`: $($_.Exception.Message)" 'Yellow' }
}
if ($c['BORRADO_ORIGEN'] -gt 0 -and $script:EsAdb) { Write-Linea '  La galería del móvil puede tardar en reflejar el borrado (o hasta reiniciarlo).' 'DarkGray' }
if ($estadoFinal -eq 'INTERRUMPIDO') { Write-Linea '  Interrumpido por una desconexión: lo verificado está a salvo; relanza y seguirá donde lo dejó.' 'Red'; exit 1 }
if ($script:AvisosLectura -gt 0) {
    Write-Linea "  No se pudo leer parte del origen o del destino ($script:AvisosLectura avisos, arriba): puede que falten archivos por traspasar." 'Red'
}
if ($c['FALLO'] -gt 0 -or $c['ERROR_BORRADO'] -gt 0 -or $script:AvisosLectura -gt 0) {
    Write-Linea '  Hay fallos: revisa el registro (Resultado=FALLO o EstadoOrigen=ERROR_BORRADO) y relanza; lo ya hecho no se repite.' 'Red'
    exit 1
}
if ($estadoFinal -eq 'CANCELADO') { Write-Linea '  Cancelado por ti entre bloques: lo hecho está verificado; relanza para seguir.' 'Yellow'; exit 3 }
exit 0
