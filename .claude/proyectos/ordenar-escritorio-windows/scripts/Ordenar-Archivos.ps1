<#
.SYNOPSIS
    Clasifica los archivos de una carpeta (por defecto, el Escritorio real) en subcarpetas
    por tipo dentro de una carpeta CONTENEDORA. SIEMPRE simula primero.

.DESCRIPTION
    MODO DE PRUEBA PRIMERO (regla del proyecto):
      * Sin -Aplicar el script SOLO SIMULA: muestra que haria y escribe los logs.
        No crea, copia, mueve ni borra nada en el origen ni en el destino.
      * Con -Aplicar ejecuta igualmente la simulacion completa, la ensena, pide
        confirmacion (S/N; "SI" si hay que Mover) y solo entonces ejecuta ESE MISMO plan.
      * -WhatIf gana a -Aplicar.

    Archivo en ASCII puro (sin tildes) a proposito: asi no depende de la codificacion con la que
    se descargue o se abra (ISE, consola 5.1, pwsh 7).

    Compatible con Windows PowerShell 5.1 y PowerShell 7.x (7.6 LTS). Sin modulos
    externos, sin admin y sin escribir en el registro. Mismo mapeo que
    ordenar_archivos.py (mapeo-extensiones.json, junto al script).

    Codigos de salida: 0 OK - 1 con errores no criticos - 2 parametros no validos o
    cancelado - 3 abortado por error critico.

.PARAMETER Origen
    Carpeta a ordenar. Por defecto, el Escritorio real ([Environment]::GetFolderPath('Desktop')),
    aunque este redirigido a OneDrive. El Escritorio publico no se procesa salvo que se indique aqui.
.PARAMETER Excluir
    Nombres o patrones separados por comas ("Warp.lnk, *.p12, Proyecto*"). Sin distinguir
    mayusculas; se comparan con el nombre y con la ruta relativa. EXCLUIR gana a INCLUIR SOLO.
.PARAMETER IncluirSolo
    Extensiones o patrones separados por comas (".pdf,.docx" o "WhatsApp*").
.PARAMETER Destino
    Ruta local, USB o UNC. Por defecto, el propio origen.
.PARAMETER Contenedora
    Carpeta contenedora dentro del destino. Por defecto "zOrdenado".
.PARAMETER Otros
    Carpeta para tipos desconocidos y archivos sin extension. Por defecto, la del JSON ("zOtros").
.PARAMETER Modo
    Copiar (por defecto) o Mover.
.PARAMETER Recursivo
    Clasifica tambien los archivos de las subcarpetas. No combinable con -Carpetas Copiar/Mover.
.PARAMETER Carpetas
    Que hacer con las subcarpetas del origen: Dejar (defecto), Copiar o Mover enteras a <contenedora>\Carpetas.
.PARAMETER Aplicar
    Ejecuta de verdad (tras simular, ensenar el plan y confirmar).
.PARAMETER Si
    No pide confirmacion (queda anotado en el log).
.PARAMETER Mapeo
    Ruta a mapeo-extensiones.json. Por defecto, el que esta junto al script; si no existe, el interno.
.PARAMETER ExcluirSensibles
    Deja fuera certificados y claves.
.PARAMETER IncluirNube
    Procesa archivos "solo en la nube" (OneDrive los descargara).
.PARAMETER IncluirOcultos
    Procesa archivos ocultos y de sistema.

.EXAMPLE
    .\Ordenar-Archivos.ps1
    Modo interactivo. Termina en simulacion y pregunta si ejecutar ese mismo plan.
.EXAMPLE
    .\Ordenar-Archivos.ps1 -Destino D:\
    Simula ordenar el Escritorio en D:\zOrdenado. No toca nada.
.EXAMPLE
    .\Ordenar-Archivos.ps1 -Destino E:\ -Aplicar
    Simula, ensena el plan, pide confirmacion y copia al USB E:\zOrdenado.
.EXAMPLE
    .\Ordenar-Archivos.ps1 -Destino \\NAS\share -Contenedora zOrdenado-Red -Aplicar
.LINK
    README.md (junto al script)
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Origen,
    [string]$Excluir,
    [string]$IncluirSolo,
    [string]$Destino,
    [string]$Contenedora = 'zOrdenado',
    [string]$Otros,
    [string]$Modo = 'Copiar',
    [switch]$Recursivo,
    [string]$Carpetas = 'Dejar',
    [switch]$Aplicar,
    [switch]$Si,
    [string]$Mapeo,
    [switch]$ExcluirSensibles,
    [switch]$IncluirNube,
    [switch]$IncluirOcultos
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:Version = '1.0.3'
$script:EsWindows = [Environment]::OSVersion.Platform -eq 'Win32NT'

# ------------------------------------------------------------------------------------
# Constantes
# ------------------------------------------------------------------------------------
$script:SALIDA_OK = 0; $script:SALIDA_NO_CRITICOS = 1; $script:SALIDA_PARAMETROS = 2; $script:SALIDA_CRITICO = 3

# Mapeo interno (identico a mapeo-extensiones.json). El orden importa: gana la primera.
$script:MapeoInternoJson = @'
{"carpetaOtros":"zOtros","sensibles":["Certificados y claves"],"categorias":{
"Certificados y claves":["p12","pfx","cer","crt","pem","key"],
"Documentos":["doc","docx","odt","rtf"],"PDF":["pdf"],
"Hojas de calculo":["xls","xlsx","xlsm","csv","ods"],"Presentaciones":["ppt","pptx","odp"],
"Textos":["txt","log"],"Markdown":["md"],
"Imagenes":["jpg","jpeg","png","gif","bmp","webp","heic","svg"],
"Accesos directos":["lnk"],"Enlaces web":["url","webloc"],"Correos":["msg","eml","oft"],
"Scripts":["ps1","psm1","bat","cmd","py","sh","vbs","reg"],
"Comprimidos":["zip","rar","7z","tar","gz"],
"Instaladores y Aplicaciones":["exe","msi","msix","appx"],
"Audio":["mp3","wav","flac","m4a","ogg"],"Video":["mp4","mkv","avi","mov","webm"],
"Codigo":["js","json","xml","yaml","yml","html","css","c","cpp","cs","java","go","rs","sql"]}}
'@

$script:CarpetaCarpetas = 'Carpetas'
$script:CarpetaLogs = '_logs'
$script:ExclusionesDefecto = @('desktop.ini', 'thumbs.db', '~$*', '*.tmp')
$script:AtributosNube = 0x1000 -bor 0x40000 -bor 0x400000   # OFFLINE | RECALL_ON_OPEN | RECALL_ON_DATA_ACCESS

$script:CausasNoCriticas = @{
    2   = 'El archivo ha desaparecido durante el proceso (se movio o borro por otro lado).'
    32  = 'El archivo esta en uso por otro proceso: cierralo en Outlook/Word/... y repite.'
    33  = 'Parte del archivo esta bloqueada por otro proceso: cierralo y repite.'
    5   = 'Acceso denegado: revisa permisos, atributo de solo lectura o el antivirus.'
    206 = 'Ruta o nombre demasiado largo: activa LongPathsEnabled o acorta la ruta.'
    123 = 'Nombre de archivo, carpeta o volumen no valido.'
}
$script:CodigosNube = @(358) + (362..366) + @(374, 375) + (377..383) + (386..398) + @(404, 426, 434, 475)
$script:CodigosDestinoCritico = @(3, 21, 53, 59, 64, 67, 121, 1167)
$script:CodigosSinEspacio = @(39, 112)
# Fuera de Windows .NET devuelve errno en HResult: equivalencias a Win32
$script:ErrnoAWin32 = @{ 13 = 5; 1 = 5; 16 = 32; 26 = 32; 36 = 206; 28 = 112; 122 = 112; 18 = 17; 107 = 64; 112 = 64; 113 = 53; 116 = 64; 19 = 21 }

# ------------------------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------------------------
function Write-Linea {
    # Escribe en consola (y en el transcript) con color opcional.
    param([string]$Texto = '', [string]$Color)
    if ($Color) { Write-Host $Texto -ForegroundColor $Color } else { Write-Host $Texto }
}

function Format-Tam {
    param([double]$N)
    $unidades = @('B', 'KB', 'MB', 'GB', 'TB')
    $i = 0
    while ($N -ge 1024 -and $i -lt 4) { $N = $N / 1024; $i++ }
    if ($i -eq 0) { return ('{0:N0} B' -f $N) }
    return ('{0:N1} {1}' -f $N, $unidades[$i])
}

function Test-PrefijoLargo {
    # Windows PowerShell 5.1 (.NET Framework, incluido ISE) suele ejecutarse con el manejo de
    # rutas "legacy": ahi el prefijo \\?\ hace que Exists() devuelva $false aunque la ruta
    # exista. Se comprueba una vez con una carpeta que existe seguro.
    if ($null -eq $script:PrefijoLargoOk) {
        $script:PrefijoLargoOk = $false
        try {
            $sys = [Environment]::GetFolderPath('Windows')
            if ($sys) { $script:PrefijoLargoOk = [IO.Directory]::Exists('\\?\' + $sys) }
        } catch { $script:PrefijoLargoOk = $false }
    }
    return $script:PrefijoLargoOk
}

function Get-LP {
    # Prefijo \\?\ (o \\?\UNC\) para APIs .NET en Windows, solo en rutas absolutas normalizadas,
    # solo si la ruta es larga y solo si este PowerShell lo admite (ver Test-PrefijoLargo).
    param([string]$Ruta)
    if (-not $script:EsWindows -or $Ruta.StartsWith('\\?\')) { return $Ruta }
    $abs = $Ruta
    try { $abs = [IO.Path]::GetFullPath($Ruta) } catch { }
    if ($abs.Length -lt 240 -or -not (Test-PrefijoLargo)) { return $abs }
    if ($abs.StartsWith('\\')) { return '\\?\UNC\' + $abs.Substring(2) }
    return '\\?\' + $abs
}

function Get-Clave {
    # Clave para comparar rutas sin distinguir mayusculas ni barra final.
    param([string]$Ruta)
    $abs = $Ruta
    try { $abs = [IO.Path]::GetFullPath($Ruta) } catch { }   # ruta larga en PS 5.1: se compara tal cual
    return $abs.TrimEnd('\', '/').ToLowerInvariant()
}

function Test-Dentro {
    param([string]$Ruta, [string]$Carpeta)
    $r = Get-Clave $Ruta; $c = Get-Clave $Carpeta
    return ($r -eq $c -or $r.StartsWith($c + '\') -or $r.StartsWith($c + '/'))
}

function Test-Existe {
    param([string]$Ruta)
    $l = Get-LP $Ruta
    return ([IO.File]::Exists($l) -or [IO.Directory]::Exists($l))
}

function Get-RutaRelativa {
    param([string]$Ruta, [string]$Base)
    $b = $Base.TrimEnd('\', '/')
    if ($Ruta.Length -gt $b.Length -and $Ruta.Substring(0, $b.Length).ToLowerInvariant() -eq $b.ToLowerInvariant()) {
        return $Ruta.Substring($b.Length + 1)
    }
    return $Ruta
}

function Get-EscritorioReal {
    $d = [Environment]::GetFolderPath('Desktop')
    if ($d -and [IO.Directory]::Exists($d)) { return $d }
    return (Join-Path $HOME 'Desktop')
}

function Get-CarpetaLogs {
    if ($script:EsWindows) {
        $base = $env:LOCALAPPDATA
        if (-not $base) { $base = Join-Path $HOME 'AppData\Local' }
        return (Join-Path (Join-Path $base 'OrdenarArchivos') 'logs')
    }
    return (Join-Path (Join-Path $HOME '.local/state') 'ordenar-archivos')
}

function Resolve-RutaCompleta {
    # Expande %VARIABLES% y resuelve rutas relativas contra la ubicacion actual de PowerShell.
    param([string]$Ruta)
    $r = [Environment]::ExpandEnvironmentVariables($Ruta)
    return [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($r))
}

function Test-SinConsola {
    # True si no se puede preguntar al usuario. PowerShell ISE no tiene consola pero si Read-Host.
    if ($Host.Name -like '*ISE*') { return $false }
    try { return [Console]::IsInputRedirected } catch { return $false }
}

function Test-NombreCarpeta {
    # Devuelve $null si es valido o el motivo en espanol.
    param([string]$Nombre)
    if ([string]::IsNullOrWhiteSpace($Nombre)) { return 'el nombre esta vacio' }
    if ($Nombre -match '[<>:"/\\|?*\x00-\x1f]') { return 'contiene caracteres no permitidos (<>:"/\|?*)' }
    if ($Nombre.EndsWith('.') -or $Nombre.EndsWith(' ')) { return 'no puede terminar en punto ni en espacio' }
    $raiz = $Nombre.Split('.')[0].Trim().ToUpperInvariant()
    if ($raiz -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
        return 'es un nombre reservado de Windows (CON, PRN, AUX, NUL, COM1-9, LPT1-9)'
    }
    return $null
}

function Split-Lista {
    param([string]$Texto)
    if (-not $Texto) { return @() }
    return @($Texto.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Test-Patron {
    # -like sin distinguir mayusculas, contra el nombre y la ruta relativa.
    param([string[]]$Patrones, [string]$Nombre, [string]$Rel)
    $r = $Rel.Replace('/', '\')
    foreach ($p in $Patrones) {
        $pp = $p.Replace('/', '\')
        if ($Nombre -like $pp -or $r -like $pp) { return $true }
    }
    return $false
}

function ConvertTo-PatronIncluir {
    param([string]$P)
    if ($P.StartsWith('.') -and $P.IndexOfAny([char[]]'*?[') -lt 0) { return '*' + $P }
    return $P
}

function Get-CodigoWin32 {
    # Codigo Win32 de una excepcion (deshace MethodInvocationException).
    param($Excepcion)
    $base = $Excepcion
    if ($Excepcion -is [System.Management.Automation.ErrorRecord]) { $base = $Excepcion.Exception }
    $c = $base.GetBaseException().HResult -band 0xFFFF
    if (-not $script:EsWindows -and $script:ErrnoAWin32.ContainsKey($c)) { $c = $script:ErrnoAWin32[$c] }
    return $c
}

function Get-Causa {
    param([int]$Codigo, $Excepcion)
    if ($script:CausasNoCriticas.ContainsKey($Codigo)) { return $script:CausasNoCriticas[$Codigo] }
    if ($script:CodigosNube -contains $Codigo) { return 'Error del proveedor de nube (OneDrive): comprueba que esta sincronizado y con sesion iniciada.' }
    if ($script:CodigosDestinoCritico -contains $Codigo) { return 'El destino no esta accesible (red/USB desconectado o ruta inexistente).' }
    if ($script:CodigosSinEspacio -contains $Codigo) { return 'No queda espacio en el destino.' }
    $b = $Excepcion
    if ($b -is [System.Management.Automation.ErrorRecord]) { $b = $b.Exception }
    return ('{0}: {1}' -f $b.GetBaseException().GetType().Name, $b.GetBaseException().Message)
}

function Get-EspacioLibre {
    # GetDiskFreeSpaceEx via Add-Type (vale para UNC); si no, DriveInfo; si tampoco, $null.
    param([string]$Ruta)
    if ($script:EsWindows) {
        try {
            if (-not ('OrdenarArchivos.Disco' -as [type])) {
                Add-Type -Namespace OrdenarArchivos -Name Disco -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern bool GetDiskFreeSpaceEx(string lpDirectoryName, out ulong lpFreeBytesAvailable, out ulong lpTotalNumberOfBytes, out ulong lpTotalNumberOfFreeBytes);
'@
            }
            $libre = [uint64]0; $total = [uint64]0; $totalLibre = [uint64]0
            $r = [IO.Path]::GetFullPath($Ruta)
            if (-not $r.EndsWith('\')) { $r = $r + '\' }
            if ([OrdenarArchivos.Disco]::GetDiskFreeSpaceEx($r, [ref]$libre, [ref]$total, [ref]$totalLibre)) { return [int64]$libre }
        } catch { }
    }
    try {
        $raiz = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Ruta))
        if ($raiz -and -not $raiz.StartsWith('\\')) { return [int64](New-Object IO.DriveInfo($raiz)).AvailableFreeSpace }
    } catch { }
    return $null
}

function Test-Escritura {
    # Crea y borra un temporal PROPIO en la raiz del destino. $null = OK; texto = motivo.
    param([string]$Ruta)
    $tmp = Join-Path $Ruta ('.ordenar_prueba_{0}_{1}.tmp' -f $PID, ([guid]::NewGuid().ToString('N').Substring(0, 8)))
    try {
        $fs = New-Object IO.FileStream((Get-LP $tmp), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $fs.WriteByte(79); $fs.Flush($true) } finally { $fs.Dispose() }
        [IO.File]::Delete((Get-LP $tmp))
        return $null
    } catch {
        $c = Get-CodigoWin32 $_
        return ('{0} [codigo {1}]' -f (Get-Causa $c $_), $c)
    }
}

function Test-Extraible {
    param([string]$Ruta)
    if (-not $script:EsWindows) { return $false }
    try {
        $raiz = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Ruta))
        if ($raiz.StartsWith('\\')) { return $false }
        return ((New-Object IO.DriveInfo($raiz)).DriveType -eq [IO.DriveType]::Removable)
    } catch { return $false }
}

function Get-Sha256 {
    param([string]$Ruta)
    $fs = [IO.File]::OpenRead((Get-LP $Ruta))
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return (-join ($sha.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') })) } finally { $sha.Dispose() }
    } finally { $fs.Dispose() }
}

# ------------------------------------------------------------------------------------
# Mapeo
# ------------------------------------------------------------------------------------
function Read-Mapeo {
    param([string]$Ruta, [string]$OtrosParam)
    $texto = $script:MapeoInternoJson
    $desc = 'interno'
    if (-not $Ruta) {
        if ($PSScriptRoot) {                              # vacio si se ejecuta sin guardar (ISE)
            $junto = Join-Path $PSScriptRoot 'mapeo-extensiones.json'
            if ([IO.File]::Exists($junto)) { $Ruta = $junto }
        }
    }
    if ($Ruta) {
        $texto = [IO.File]::ReadAllText((Get-LP ([IO.Path]::GetFullPath($Ruta))), [Text.Encoding]::UTF8)
        $desc = $Ruta
    }
    $json = $texto | ConvertFrom-Json
    if (-not $json.PSObject.Properties['categorias']) { throw "el JSON no tiene un objeto 'categorias'" }
    $cats = New-Object System.Collections.Generic.List[object]
    foreach ($p in $json.categorias.PSObject.Properties) {
        $exts = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($x in @($p.Value)) { [void]$exts.Add(([string]$x).TrimStart('.')) }
        $cats.Add([pscustomobject]@{ Nombre = $p.Name; Ext = $exts })
    }
    $otros = 'zOtros'
    if ($json.PSObject.Properties['carpetaOtros'] -and $json.carpetaOtros) { $otros = [string]$json.carpetaOtros }
    if ($OtrosParam) { $otros = $OtrosParam }
    $sens = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if ($json.PSObject.Properties['sensibles']) { foreach ($s in @($json.sensibles)) { [void]$sens.Add([string]$s) } }
    Write-Verbose ('Mapeo cargado: {0} ({1} categorias)' -f $desc, $cats.Count)
    return [pscustomobject]@{ Otros = $otros; Sensibles = $sens; Categorias = $cats; Origen = $desc }
}

function Get-Categoria {
    param($MapeoObj, [string]$Nombre)
    $ext = [IO.Path]::GetExtension($Nombre).TrimStart('.')
    if ($ext) {
        foreach ($c in $MapeoObj.Categorias) { if ($c.Ext.Contains($ext)) { return $c.Nombre } }
    }
    return $MapeoObj.Otros
}

# ------------------------------------------------------------------------------------
# Planificacion (no escribe nada)
# ------------------------------------------------------------------------------------
function Test-EsEnlace {
    param($Item)
    $lt = $null
    if ($Item.PSObject.Properties['LinkType']) { $lt = $Item.LinkType }
    return ($lt -eq 'SymbolicLink' -or $lt -eq 'Junction')
}

function Get-ArchivosArbol {
    # Lista recursiva de archivos (sin seguir enlaces). Devuelve objetos FileInfo.
    param([string]$Ruta)
    $res = New-Object System.Collections.Generic.List[object]
    $pend = New-Object System.Collections.Generic.Stack[string]
    $pend.Push($Ruta)
    while ($pend.Count -gt 0) {
        $d = $pend.Pop()
        $hijos = @()
        try { $hijos = @(Get-ChildItem -LiteralPath $d -Force -ErrorAction Stop) } catch { Write-Verbose ('No se puede leer {0}: {1}' -f $d, $_.Exception.Message) }
        foreach ($it in $hijos) {
            if (Test-EsEnlace $it) { continue }
            if ($it.PSIsContainer) { $pend.Push($it.FullName) } else { $res.Add($it) }
        }
    }
    return , $res
}

function Measure-Carpeta {
    param([string]$Ruta)
    $n = 0; [int64]$b = 0
    foreach ($f in (Get-ArchivosArbol $Ruta)) { $n++; $b += $f.Length }
    return [pscustomobject]@{ Archivos = $n; Bytes = $b }
}

function New-Elemento {
    param([string]$Tipo, [string]$Ruta, [string]$Rel)
    return [pscustomobject]@{
        Tipo = $Tipo; Origen = $Ruta; Rel = $Rel; Categoria = ''; Destino = ''; Bytes = [int64]0
        Archivos = 0; Sensible = $false; Nube = $false; Omitido = ''
    }
}

function Get-NombreLibre {
    # Nunca sobrescribe: "nombre (1).ext", "(2)"... comprobando disco y reservas de esta ejecucion.
    param([string]$Carpeta, [string]$Nombre, [bool]$EsCarpeta)
    if ($EsCarpeta) { $base = $Nombre; $ext = '' }
    else { $base = [IO.Path]::GetFileNameWithoutExtension($Nombre); $ext = [IO.Path]::GetExtension($Nombre) }
    $cand = $Nombre; $n = 1
    while ($true) {
        $ruta = Join-Path $Carpeta $cand
        $k = Get-Clave $ruta
        if (-not $script:Reservados.Contains($k) -and -not (Test-Existe $ruta)) {
            [void]$script:Reservados.Add($k)
            return $ruta
        }
        $cand = '{0} ({1}){2}' -f $base, $n, $ext
        $n++
    }
}

function Test-RutaExcluida {
    param([string]$Ruta)
    $k = Get-Clave $Ruta
    foreach ($e in $script:RutasExcluidas) {
        if ($k -eq $e -or $k.StartsWith($e + '\') -or $k.StartsWith($e + '/')) { return $true }
    }
    return $false
}

function Add-Carpeta {
    # Recorre una carpeta del origen y anade elementos al plan.
    param([string]$Ruta, [string]$RelBase)
    try {
        $items = @(Get-ChildItem -LiteralPath $Ruta -Force -ErrorAction Stop | Sort-Object { $_.Name.ToLowerInvariant() })
    } catch {
        $e = New-Elemento 'carpeta' $Ruta $RelBase
        $e.Omitido = 'no se puede leer: ' + $_.Exception.Message
        $script:Elementos.Add($e)
        return
    }
    foreach ($it in $items) {
      try {
        if ($RelBase) { $rel = Join-Path $RelBase $it.Name } else { $rel = $it.Name }
        if (Test-RutaExcluida $it.FullName) { continue }      # contenedora, logs, script...
        $oculto = (([int64]$it.Attributes) -band ([int64][IO.FileAttributes]::Hidden -bor [int64][IO.FileAttributes]::System)) -ne 0
        if (Test-EsEnlace $it) {
            $tipo = 'archivo'; if ($it.PSIsContainer) { $tipo = 'carpeta' }
            $e = New-Elemento $tipo $it.FullName $rel
            $e.Omitido = 'enlace simbolico/junction (no se sigue)'
            $script:Elementos.Add($e)
            continue
        }
        if ($it.PSIsContainer) {
            if ($oculto -and -not $IncluirOcultos) { continue }
            if ($Recursivo) {
                if (-not (Test-Patron $script:PatronesExcluir $it.Name $rel)) { Add-Carpeta $it.FullName $rel }
            } elseif ($Carpetas -ne 'Dejar') {
                $e = New-Elemento 'carpeta' $it.FullName $rel
                if (Test-Patron $script:PatronesExcluir $it.Name $rel) {
                    $e.Omitido = 'excluido por patron'
                } else {
                    $m = Measure-Carpeta $it.FullName
                    $e.Archivos = $m.Archivos; $e.Bytes = $m.Bytes; $e.Categoria = $script:CarpetaCarpetas
                }
                $script:Elementos.Add($e)
            }
            continue
        }
        # --- archivos ---
        $e = New-Elemento 'archivo' $it.FullName $rel
        $e.Bytes = [int64]$it.Length
        $e.Categoria = Get-Categoria $script:MapeoObj $it.Name
        $e.Sensible = $script:MapeoObj.Sensibles.Contains($e.Categoria)
        $e.Nube = (([int64]$it.Attributes) -band $script:AtributosNube) -ne 0
        if ($oculto -and -not $IncluirOcultos) { $e.Omitido = 'oculto o de sistema' }
        elseif (Test-Patron $script:ExclusionesDefecto $it.Name $it.Name) { $e.Omitido = 'exclusion por defecto (desktop.ini, Thumbs.db, ~$*, *.tmp)' }
        elseif ($e.Nube -and -not $IncluirNube) { $e.Omitido = 'solo en la nube (usa -IncluirNube para descargarlo)' }
        elseif (Test-Patron $script:PatronesExcluir $it.Name $rel) { $e.Omitido = 'excluido por patron' }
        elseif ($script:PatronesIncluir.Count -gt 0 -and -not (Test-Patron $script:PatronesIncluir $it.Name $rel)) { $e.Omitido = 'no esta en INCLUIR SOLO' }
        elseif ($e.Sensible -and $ExcluirSensibles) { $e.Omitido = 'sensible excluido (-ExcluirSensibles)' }
        $script:Elementos.Add($e)
      } catch {
        # Ruta demasiado larga o no valida: se registra y se sigue, nunca aborta
        $e = New-Elemento 'archivo' ([string]$it.FullName) ([string]$it.Name)
        $e.Omitido = 'ruta demasiado larga o no valida (se omite): ' + $_.Exception.Message
        $script:Elementos.Add($e)
      }
    }
}

function Get-InformeDuplicados {
    # Grupos de posibles duplicados por nombre ("(1)", "_v2"...) y por tamano + SHA-256. Solo informe.
    $grupos = New-Object System.Collections.Generic.List[object]
    $archivos = @($script:Elementos | Where-Object { $_.Tipo -eq 'archivo' -and -not $_.Omitido })
    $porNombre = [ordered]@{}
    foreach ($e in $archivos) {
        $nombre = [IO.Path]::GetFileName($e.Origen)
        $base = [IO.Path]::GetFileNameWithoutExtension($nombre); $ext = [IO.Path]::GetExtension($nombre)
        if ($base -match '^(?<b>.*?)(?:\s\(\d+\)|_v\d+)$') { $base = $Matches['b'] }
        $k = ($base + $ext).ToLowerInvariant()
        if (-not $porNombre.Contains($k)) { $porNombre[$k] = New-Object System.Collections.Generic.List[string] }
        $porNombre[$k].Add($e.Rel)
    }
    foreach ($k in $porNombre.Keys) {
        if ($porNombre[$k].Count -gt 1) { $grupos.Add([pscustomobject]@{ Motivo = 'mismo nombre base'; Rels = @($porNombre[$k]) }) }
    }
    $porTam = @{}
    foreach ($e in $archivos) {
        if ($e.Nube) { continue }                         # nunca hash de archivos solo en la nube
        if (-not $porTam.ContainsKey($e.Bytes)) { $porTam[$e.Bytes] = New-Object System.Collections.Generic.List[object] }
        $porTam[$e.Bytes].Add($e)
    }
    foreach ($t in $porTam.Keys) {
        if ($porTam[$t].Count -lt 2) { continue }          # hash solo si coincide el tamano
        $porHash = [ordered]@{}
        foreach ($e in $porTam[$t]) {
            try { $h = Get-Sha256 $e.Origen } catch { continue }
            if (-not $porHash.Contains($h)) { $porHash[$h] = New-Object System.Collections.Generic.List[string] }
            $porHash[$h].Add($e.Rel)
        }
        foreach ($h in $porHash.Keys) {
            if ($porHash[$h].Count -gt 1) {
                $grupos.Add([pscustomobject]@{ Motivo = ('mismo contenido ({0}, SHA-256 {1}...)' -f (Format-Tam $t), $h.Substring(0, 12)); Rels = @($porHash[$h]) })
            }
        }
    }
    return , $grupos
}

# ------------------------------------------------------------------------------------
# CSV en caliente
# ------------------------------------------------------------------------------------
function ConvertTo-Campo {
    param($Valor)
    $s = [string]$Valor
    if ($s.StartsWith('\\?\UNC\')) { $s = '\\' + $s.Substring(8) } elseif ($s.StartsWith('\\?\')) { $s = $s.Substring(4) }
    if ($s.IndexOfAny([char[]](';"' + "`r`n")) -ge 0) { $s = '"' + $s.Replace('"', '""') + '"' }
    return $s
}

function Open-Csv {
    param([string]$Ruta)
    $script:Csv = New-Object IO.StreamWriter($Ruta, $false, (New-Object Text.UTF8Encoding($true)))
    $script:Csv.AutoFlush = $true
    $script:CsvFilas = 0
    $script:Csv.WriteLine('Fecha;Accion;Categoria;Origen;Destino;Bytes;Resultado;Severidad;Detalle')
}

function Write-Fila {
    param($Accion, $Categoria, $OrigenF, $DestinoF, $Bytes, $Resultado, $Severidad, $Detalle = '')
    $campos = @((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'), $Accion, $Categoria, $OrigenF, $DestinoF, $Bytes, $Resultado, $Severidad, $Detalle)
    $script:Csv.WriteLine((($campos | ForEach-Object { ConvertTo-Campo $_ }) -join ';'))
    $script:CsvFilas++
    if ($script:CsvFilas % 50 -eq 0) { $script:Csv.BaseStream.Flush($true) }   # fsync
}

function Close-Csv {
    if ($script:Csv) {
        try { $script:Csv.Flush(); $script:Csv.BaseStream.Flush($true) } catch { }
        $script:Csv.Dispose()
        $script:Csv = $null
    }
}

# ------------------------------------------------------------------------------------
# Operaciones de disco (solo con -Aplicar)
# ------------------------------------------------------------------------------------
function Copy-Exclusivo {
    # Copia sin sobrescribir nunca (FileMode.CreateNew). Si falla, borra SOLO la copia parcial propia.
    param([string]$Src, [string]$Dst, [bool]$ConHash)
    $script:EnDestino = $false
    $in = New-Object IO.FileStream((Get-LP $Src), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $creado = $false
    $sha = $null
    try {
        $script:EnDestino = $true
        $out = New-Object IO.FileStream((Get-LP $Dst), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $creado = $true
        try {
            if ($ConHash) { $sha = [Security.Cryptography.SHA256]::Create() }
            $buf = New-Object byte[] 1048576
            [int64]$total = 0
            $script:EnDestino = $false
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $script:EnDestino = $true
                $out.Write($buf, 0, $n)
                $script:EnDestino = $false
                $total += $n
                if ($sha) { [void]$sha.TransformBlock($buf, 0, $n, $null, 0) }
            }
            $script:EnDestino = $true
            $out.Flush($true)
        } finally { $out.Dispose() }
    } catch {
        if ($creado) { try { [IO.File]::Delete((Get-LP $Dst)) } catch { } }
        throw
    } finally { $in.Dispose() }
    try {
        [IO.File]::SetCreationTimeUtc((Get-LP $Dst), [IO.File]::GetCreationTimeUtc((Get-LP $Src)))
        [IO.File]::SetLastWriteTimeUtc((Get-LP $Dst), [IO.File]::GetLastWriteTimeUtc((Get-LP $Src)))
    } catch { }                                          # fechas: no es motivo de fallo
    $hash = $null
    if ($sha) {
        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
        $hash = -join ($sha.Hash | ForEach-Object { $_.ToString('x2') })
        $sha.Dispose()
    }
    return [pscustomobject]@{ Bytes = $total; Hash = $hash }
}

function Test-Copia {
    # $null si la copia es correcta; texto con el motivo si no.
    param([int64]$BytesOrigen, [string]$Dst, [string]$HashOrigen)
    $real = (New-Object IO.FileInfo((Get-LP $Dst))).Length
    if ($real -ne $BytesOrigen) { return ('tamano distinto (origen {0} B, copia {1} B)' -f $BytesOrigen, $real) }
    if ($HashOrigen -and (Get-Sha256 $Dst) -ne $HashOrigen) { return 'SHA-256 distinto entre origen y copia' }
    return $null
}

function Copy-Arbol {
    # Copia un arbol sin sobrescribir (Dst no debe existir). Cada error, en su fila del CSV.
    param([string]$Src, [string]$Dst)
    $errores = 0
    [void][IO.Directory]::CreateDirectory((Get-LP $Dst))
    foreach ($f in (Get-ArchivosArbol $Src)) {
        $rel = Get-RutaRelativa $f.FullName $Src
        $obj = Join-Path $Dst $rel
        try {
            [void][IO.Directory]::CreateDirectory((Get-LP ([IO.Path]::GetDirectoryName($obj))))
            [void](Copy-Exclusivo $f.FullName $obj $false)
        } catch {
            $errores++
            $c = Get-CodigoWin32 $_
            Write-Fila 'copiar-carpeta' $script:CarpetaCarpetas $f.FullName $obj '' 'error' 'no-critico' ('{0} [codigo {1}]' -f (Get-Causa $c $_), $c)
        }
    }
    $m = Measure-Carpeta $Dst
    return [pscustomobject]@{ Archivos = $m.Archivos; Bytes = $m.Bytes; Errores = $errores }
}

function Test-MismoVolumen {
    param([string]$A, [string]$B)
    if (-not $script:EsWindows) { return $true }          # en Linux/macOS .NET ya copia+borra entre dispositivos
    $ra = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($A)).TrimEnd('\').ToLowerInvariant()
    $rb = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($B)).TrimEnd('\').ToLowerInvariant()
    return ($ra -eq $rb)
}

function New-CarpetaDestino {
    # Crea la subcarpeta solo cuando hace falta (nunca vacias).
    param([string]$Ruta)
    $d = [IO.Path]::GetDirectoryName($Ruta)
    if (-not $script:Creadas.Contains($d)) {
        $script:EnDestino = $true
        [void][IO.Directory]::CreateDirectory((Get-LP $d))
        [void]$script:Creadas.Add($d)
    }
}

function Write-Ok {
    param($E, [string]$Accion, [string]$Detalle)
    $script:NumOk++
    $script:BytesOk += $E.Bytes
    $sev = 'info'; if ($E.Sensible) { $sev = 'aviso' }
    Write-Fila $Accion $E.Categoria $E.Origen $E.Destino $E.Bytes 'ok' $sev $Detalle
    Write-Linea ('  OK  {0}  ->  {1}' -f $E.Rel, (Get-RutaRelativa $E.Destino $script:DestinoAbs)) 'Green'
}

function Add-ErrorNoCritico {
    param($E, [string]$Accion, $Err)
    $c = Get-CodigoWin32 $Err
    $causa = Get-Causa $c $Err
    if (($script:CodigosSinEspacio -contains $c) -or ($script:CodigosDestinoCritico -contains $c) -or $script:EnDestino) {
        # Error en el destino: repetir prueba de escritura y espacio antes de seguir
        $fallo = Test-Escritura $script:DestinoAbs
        $libre = Get-EspacioLibre $script:DestinoAbs
        if ($fallo -or ($null -ne $libre -and $libre -lt $E.Bytes)) {
            Write-Fila $Accion $E.Categoria $E.Origen $E.Destino $E.Bytes 'error' 'critico' ('{0} [codigo {1}]' -f $causa, $c)
            if (-not $fallo) { $fallo = 'sin espacio en el destino' }
            throw (New-Object System.ApplicationException($fallo))
        }
    }
    $texto = '{0} [codigo {1}]' -f $causa, $c
    Write-Linea ('  AVISO ({0}): {1}' -f $E.Rel, $texto) 'Yellow'
    Write-Fila $Accion $E.Categoria $E.Origen $E.Destino $E.Bytes 'error' 'no-critico' $texto
    $script:Errores.Add([pscustomobject]@{ Rel = $E.Rel; Causa = $causa })
}

function Invoke-Archivo {
    param($E, [string]$Accion)
    New-CarpetaDestino $E.Destino
    if ($E.Sensible) { Write-Linea ('  SENSIBLE: {0} (no lo dejes en una ubicacion sin proteccion)' -f $E.Rel) 'Magenta' }
    if ($Accion -eq 'mover' -and $script:MismoVolumen) {
        if (Test-Existe $E.Destino) { $E.Destino = Get-NombreLibre ([IO.Path]::GetDirectoryName($E.Destino)) ([IO.Path]::GetFileName($E.Origen)) $false }
        $script:EnDestino = $false
        [IO.File]::Move((Get-LP $E.Origen), (Get-LP $E.Destino))      # Move no sobrescribe nunca
        Write-Ok $E $Accion 'renombrado'
        return
    }
    # Copia (o mover entre volumenes = copiar + verificar + borrar origen)
    if (Test-Existe $E.Destino) { $E.Destino = Get-NombreLibre ([IO.Path]::GetDirectoryName($E.Destino)) ([IO.Path]::GetFileName($E.Origen)) $false }
    $r = Copy-Exclusivo $E.Origen $E.Destino $E.Sensible
    $script:EnDestino = $false
    $motivo = Test-Copia $E.Bytes $E.Destino $r.Hash
    if ($motivo) {
        $extra = ''; if ($Accion -eq 'mover') { $extra = '; el origen NO se ha borrado' }
        Write-Fila $Accion $E.Categoria $E.Origen $E.Destino $r.Bytes 'verificacion-fallida' 'no-critico' ($motivo + $extra)
        $script:Errores.Add([pscustomobject]@{ Rel = $E.Rel; Causa = 'verificacion fallida: ' + $motivo })
        Write-Linea ('  AVISO ({0}): verificacion fallida: {1}' -f $E.Rel, $motivo) 'Yellow'
        return
    }
    if ($Accion -eq 'mover') {
        [IO.File]::Delete((Get-LP $E.Origen))
        Write-Ok $E $Accion 'copiado+verificado+borrado origen'
    } else {
        $d = 'copiado+verificado'; if ($r.Hash) { $d = $d + ' (SHA-256)' }
        Write-Ok $E $Accion $d
    }
}

function Invoke-Carpeta {
    param($E, [string]$Accion)
    New-CarpetaDestino $E.Destino
    if (Test-Existe $E.Destino) { $E.Destino = Get-NombreLibre ([IO.Path]::GetDirectoryName($E.Destino)) ([IO.Path]::GetFileName($E.Origen)) $true }
    if ($Accion -eq 'mover-carpeta' -and $script:MismoVolumen) {
        $script:EnDestino = $false
        [IO.Directory]::Move((Get-LP $E.Origen), (Get-LP $E.Destino))
        Write-Ok $E $Accion 'renombrada'
        return
    }
    $r = Copy-Arbol $E.Origen $E.Destino
    if ($r.Errores -gt 0 -or $r.Archivos -ne $E.Archivos -or $r.Bytes -ne $E.Bytes) {
        $motivo = 'verificacion: {0}/{1} archivos, {2}/{3} bytes, {4} errores' -f $r.Archivos, $E.Archivos, $r.Bytes, $E.Bytes, $r.Errores
        $extra = ''; if ($Accion -eq 'mover-carpeta') { $extra = '; el origen queda intacto' }
        Write-Fila $Accion $E.Categoria $E.Origen $E.Destino $r.Bytes 'verificacion-fallida' 'no-critico' ($motivo + $extra)
        $script:Errores.Add([pscustomobject]@{ Rel = $E.Rel; Causa = $motivo })
        Write-Linea ('  AVISO ({0}): {1}' -f $E.Rel, $motivo) 'Yellow'
        return
    }
    if ($Accion -eq 'mover-carpeta') {
        [IO.Directory]::Delete((Get-LP $E.Origen), $true)
        Write-Ok $E $Accion ('copiada+verificada ({0} archivos)+borrado origen' -f $r.Archivos)
    } else {
        Write-Ok $E $Accion ('copiada+verificada ({0} archivos)' -f $r.Archivos)
    }
}

# ------------------------------------------------------------------------------------
# Entrada interactiva y resumenes
# ------------------------------------------------------------------------------------
function Read-Valor {
    param([string]$Texto, [string]$Defecto, [scriptblock]$Validar)
    while ($true) {
        $r = Read-Host ('{0} [{1}]' -f $Texto, $Defecto)
        if (-not $r) { $r = $Defecto }
        $r = $r.Trim()
        $motivo = $null
        if ($Validar) { $motivo = & $Validar $r }
        if (-not $motivo) { return $r }
        Write-Linea ('  Valor no valido: {0}. Vuelve a intentarlo.' -f $motivo) 'Yellow'
    }
}

function Read-SiNo {
    param([string]$Texto, [bool]$Defecto)
    $d = 'N'; if ($Defecto) { $d = 'S' }
    while ($true) {
        $r = Read-Host ('{0} (S/N) [{1}]' -f $Texto, $d)
        if (-not $r) { $r = $d }
        $r = $r.Trim().ToUpperInvariant()
        if ($r -eq 'S' -or $r -eq 'SI' -or $r -eq 'SI') { return $true }
        if ($r -eq 'N' -or $r -eq 'NO') { return $false }
        Write-Linea '  Responde S o N.' 'Yellow'
    }
}

function Invoke-Interactivo {
    Write-Linea '=== Ordenar archivos - modo interactivo (Enter = valor por defecto) ===' 'Cyan'
    $def = $script:Origen; if (-not $def) { $def = Get-EscritorioReal }
    $script:Origen = Read-Valor 'ORIGEN' $def { param($v) if ([IO.Directory]::Exists($v)) { $null } else { 'la carpeta no existe' } }
    $v = Read-Valor 'EXCLUIR (patrones separados por comas, - = nada)' '-' $null
    if ($v -eq '-') { $v = '' }; $script:Excluir = $v
    $v = Read-Valor 'INCLUIR SOLO (p. ej. .pdf,.docx o WhatsApp*; - = todo)' '-' $null
    if ($v -eq '-') { $v = '' }; $script:IncluirSolo = $v
    $script:Destino = Read-Valor 'DESTINO (local, USB o \\servidor\recurso)' $script:Origen { param($v) if ([IO.Directory]::Exists($v)) { $null } else { 'el destino no existe o no esta accesible' } }
    $script:Contenedora = Read-Valor 'CONTENEDORA' $script:Contenedora { param($v) Test-NombreCarpeta $v }
    $script:Modo = Read-Valor 'MODO (Copiar/Mover)' $script:Modo { param($v) if ($v -eq 'Copiar' -or $v -eq 'Mover') { $null } else { 'escribe Copiar o Mover' } }
    # Por ahora el modo interactivo trabaja SOLO con los archivos sueltos de la raiz del origen:
    # no entra en subcarpetas ni las mueve. Para eso estan -Recursivo y -Carpetas por parametro.
    $script:Recursivo = [switch]$false
    $script:Carpetas = 'Dejar'
    Write-Linea '  Subcarpetas: se omiten (solo archivos sueltos de la raiz).' 'DarkGray'
}

function Show-Resumen {
    param([string]$Titulo, $Libre, [int64]$Necesario)
    $activos = @($script:Elementos | Where-Object { -not $_.Omitido })
    Write-Linea ''
    Write-Linea ('===== {0} =====' -f $Titulo) 'Cyan'
    Write-Linea ('Origen     : {0}' -f $script:OrigenAbs)
    Write-Linea ('Destino    : {0}' -f $script:RutaContenedora)
    $rs = 'no'; if ($Recursivo) { $rs = 'si' }
    Write-Linea ('Modo       : {0}   Recursivo: {1}   Carpetas: {2}' -f $Modo.ToUpperInvariant(), $rs, $Carpetas)
    Write-Linea 'Archivos por categoria:'
    $orden = @($script:MapeoObj.Categorias | ForEach-Object { $_.Nombre }) + @($script:MapeoObj.Otros)
    $hay = $false
    foreach ($c in $orden) {
        $g = @($activos | Where-Object { $_.Tipo -eq 'archivo' -and $_.Categoria -eq $c })
        if ($g.Count -gt 0) {
            $hay = $true
            $b = [int64]0; foreach ($x in $g) { $b += $x.Bytes }
            Write-Linea ('  {0,-30} {1,6}  {2,10}' -f $c, $g.Count, (Format-Tam $b))
        }
    }
    if (-not $hay) { Write-Linea '  (ninguno)' }
    $carps = @($activos | Where-Object { $_.Tipo -eq 'carpeta' })
    if ($carps.Count -gt 0) {
        $na = 0; $nb = [int64]0; foreach ($x in $carps) { $na += $x.Archivos; $nb += $x.Bytes }
        Write-Linea ('Carpetas enteras ({0}): {1} ({2} archivos, {3})' -f $Carpetas, $carps.Count, $na, (Format-Tam $nb))
    }
    $sens = @($activos | Where-Object { $_.Sensible })
    if ($sens.Count -gt 0) {
        Write-Linea ('SENSIBLES: {0} -> no los dejes en el Escritorio ni en una red sin proteccion; mejor un almacen cifrado o el almacen de certificados.' -f $sens.Count) 'Magenta'
    }
    $om = [ordered]@{}
    foreach ($e in $script:Elementos) {
        if ($e.Omitido) { if ($om.Contains($e.Omitido)) { $om[$e.Omitido]++ } else { $om[$e.Omitido] = 1 } }
    }
    if ($om.Count -gt 0) {
        Write-Linea 'Omitidos:'
        foreach ($k in $om.Keys) { Write-Linea ('  {0,4}  {1}' -f $om[$k], $k) 'DarkGray' }
    }
    if ($null -eq $Libre) {
        Write-Linea ('Espacio necesario: {0} - espacio libre: desconocido' -f (Format-Tam $Necesario)) 'Yellow'
    } else {
        $col = $null; if ($Libre -lt $Necesario) { $col = 'Red' }
        Write-Linea ('Espacio necesario: {0} - libre en destino: {1}' -f (Format-Tam $Necesario), (Format-Tam $Libre)) $col
    }
    if ($script:Duplicados.Count -gt 0) {
        Write-Linea ('Posibles duplicados (solo informe, no se borra ni fusiona nada): {0} grupo(s)' -f $script:Duplicados.Count) 'Yellow'
        foreach ($g in $script:Duplicados) { Write-Linea ('  - {0}: {1}' -f $g.Motivo, ($g.Rels -join ' | ')) }
    }
}

function Get-ComandoEquivalente {
    $p = @('.\Ordenar-Archivos.ps1', ('-Origen "{0}"' -f $script:OrigenAbs), ('-Destino "{0}"' -f $script:DestinoAbs),
        ('-Contenedora "{0}"' -f $Contenedora), ('-Modo {0}' -f $Modo), ('-Carpetas {0}' -f $Carpetas))
    if ($Recursivo) { $p += '-Recursivo' }
    if ($Excluir) { $p += ('-Excluir "{0}"' -f $Excluir) }
    if ($IncluirSolo) { $p += ('-IncluirSolo "{0}"' -f $IncluirSolo) }
    return (($p + '-Aplicar') -join ' ')
}

# ------------------------------------------------------------------------------------
# Programa principal
# ------------------------------------------------------------------------------------
function Invoke-Principal {
    $inicio = Get-Date
    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
        Write-Linea ('ERROR: PowerShell esta en modo {0} (AppLocker/WDAC). Este script necesita FullLanguage; usa ordenar_archivos.py.' -f $ExecutionContext.SessionState.LanguageMode) 'Red'
        return $script:SALIDA_PARAMETROS
    }
    $comunes = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable',
        'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'WhatIf', 'Confirm', 'ProgressAction')
    $propios = @($script:ParamsLlamada | Where-Object { $comunes -notcontains $_ })
    $interactivo = ($propios.Count -eq 0) -and [Environment]::UserInteractive -and -not (Test-SinConsola)
    if ($interactivo) { Invoke-Interactivo }

    # ---------- validacion de parametros ----------
    if (@('Copiar', 'Mover') -notcontains $script:Modo) { Write-Linea "ERROR: -Modo debe ser Copiar o Mover." 'Red'; return $script:SALIDA_PARAMETROS }
    if (@('Dejar', 'Copiar', 'Mover') -notcontains $script:Carpetas) { Write-Linea "ERROR: -Carpetas debe ser Dejar, Copiar o Mover." 'Red'; return $script:SALIDA_PARAMETROS }
    $motivo = Test-NombreCarpeta $script:Contenedora
    if ($motivo) { Write-Linea ('ERROR: nombre de contenedora no valido ({0}).' -f $motivo) 'Red'; return $script:SALIDA_PARAMETROS }
    if ($script:Recursivo -and $script:Carpetas -ne 'Dejar') {
        Write-Linea 'ERROR: -Carpetas Copiar/Mover no se puede combinar con -Recursivo: los archivos de las subcarpetas ya se clasifican uno a uno y se duplicarian.' 'Red'
        return $script:SALIDA_PARAMETROS
    }
    $o = $script:Origen; if (-not $o) { $o = Get-EscritorioReal }
    # Rutas relativas respecto a la ubicacion actual de PowerShell (no al directorio del proceso)
    $script:OrigenAbs = Resolve-RutaCompleta $o
    $d = $script:Destino; if (-not $d) { $d = $script:OrigenAbs }
    $script:DestinoAbs = Resolve-RutaCompleta $d
    if ($script:Mapeo) { $script:Mapeo = Resolve-RutaCompleta $script:Mapeo }
    $script:RutaContenedora = Join-Path $script:DestinoAbs $script:Contenedora
    $script:Simulacion = (-not $script:Aplicar) -or $WhatIfPreference

    # ---------- logs (lo unico que se escribe en simulacion) ----------
    $dirLogs = Get-CarpetaLogs
    [void](New-Item -ItemType Directory -Path $dirLogs -Force -WhatIf:$false -Confirm:$false)
    $tipo = 'aplicar'; if ($script:Simulacion) { $tipo = 'simulacion' }
    $base = Join-Path $dirLogs ('ordenar-ps_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $tipo)
    $script:RutaTxt = $base + '.log'; $script:RutaCsv = $base + '.csv'
    try { [void](Start-Transcript -LiteralPath $script:RutaTxt -WhatIf:$false -Confirm:$false); $script:Transcript = $true } catch { Write-Linea "AVISO: no se pudo iniciar el transcript: $($_.Exception.Message)" 'Yellow' }
    Open-Csv $script:RutaCsv
    Write-Verbose ('Ordenar-Archivos.ps1 {0} - PS {1}' -f $script:Version, $PSVersionTable.PSVersion)

    if (-not [IO.Directory]::Exists((Get-LP $script:OrigenAbs))) { Write-Linea ('CRITICO: el origen no existe: {0}' -f $script:OrigenAbs) 'Red'; return $script:SALIDA_CRITICO }
    if (-not [IO.Directory]::Exists((Get-LP $script:DestinoAbs))) { Write-Linea ('CRITICO: el destino no existe o no esta accesible: {0}' -f $script:DestinoAbs) 'Red'; return $script:SALIDA_CRITICO }
    try { $script:MapeoObj = Read-Mapeo $script:Mapeo $script:Otros } catch { Write-Linea ('ERROR: no se puede leer el mapeo ({0}).' -f $_.Exception.Message) 'Red'; return $script:SALIDA_PARAMETROS }
    if (Test-NombreCarpeta $script:MapeoObj.Otros) { Write-Linea ('ERROR: nombre de carpeta de desconocidos no valido: {0}' -f $script:MapeoObj.Otros) 'Red'; return $script:SALIDA_PARAMETROS }
    if ($script:Contenedora -eq $script:MapeoObj.Otros) {
        Write-Linea ('AVISO: la contenedora y la carpeta de desconocidos se llaman igual: quedara {0}\{1}.' -f $script:Contenedora, $script:MapeoObj.Otros) 'Yellow'
    }

    # ---------- 1) MODO DE PRUEBA: planificar sin escribir nada ----------
    $script:PatronesExcluir = @(Split-Lista $script:Excluir)
    $script:PatronesIncluir = @(Split-Lista $script:IncluirSolo | ForEach-Object { ConvertTo-PatronIncluir $_ })
    $script:RutasExcluidas = @((Get-Clave $script:RutaContenedora), (Get-Clave $dirLogs))
    if ($PSCommandPath) { $script:RutasExcluidas += (Get-Clave $PSCommandPath) }
    # Destino dentro del origen (p. ej. Escritorio\0.Escritorio ORDENAR): no se ordena a si mismo
    if ((Get-Clave $script:DestinoAbs) -ne (Get-Clave $script:OrigenAbs) -and (Test-Dentro $script:DestinoAbs $script:OrigenAbs)) {
        $script:RutasExcluidas += (Get-Clave $script:DestinoAbs)
        Write-Linea ('AVISO: el destino esta dentro del origen; la carpeta {0} no se procesa.' -f (Get-RutaRelativa $script:DestinoAbs $script:OrigenAbs)) 'Yellow'
    }
    if ($script:Mapeo) { $script:RutasExcluidas += (Get-Clave $script:Mapeo) }
    $script:Elementos = New-Object System.Collections.Generic.List[object]
    $script:Reservados = New-Object 'System.Collections.Generic.HashSet[string]'
    Add-Carpeta $script:OrigenAbs ''
    $ordenados = @($script:Elementos | Sort-Object @{ Expression = { $_.Tipo -ne 'carpeta' } }, @{ Expression = { $_.Rel.ToLowerInvariant() } })
    $script:Elementos = New-Object System.Collections.Generic.List[object]
    foreach ($e in $ordenados) { $script:Elementos.Add($e) }
    foreach ($e in $script:Elementos) {
        if (-not $e.Omitido) {
            try {
                $e.Destino = Get-NombreLibre (Join-Path $script:RutaContenedora $e.Categoria) ([IO.Path]::GetFileName($e.Origen)) ($e.Tipo -eq 'carpeta')
            } catch {
                $e.Omitido = 'ruta de destino demasiado larga o no valida (se omite): ' + $_.Exception.Message
            }
        }
    }
    $activos = @($script:Elementos | Where-Object { -not $_.Omitido })
    $script:Duplicados = Get-InformeDuplicados
    $script:MismoVolumen = Test-MismoVolumen $script:OrigenAbs $script:DestinoAbs
    [int64]$necesario = 0
    foreach ($e in $activos) {
        $m = $Modo; if ($e.Tipo -eq 'carpeta') { $m = $Carpetas }
        if ($m -eq 'Copiar' -or -not $script:MismoVolumen) { $necesario += $e.Bytes }
    }
    $libre = Get-EspacioLibre $script:DestinoAbs

    Write-Linea ''
    Write-Linea '>>> MODO DE PRUEBA: esto es lo que se haria (no se ha tocado nada) <<<' 'Cyan'
    foreach ($e in $activos) {
        $v = $Modo.ToUpperInvariant(); if ($e.Tipo -eq 'carpeta') { $v = $Carpetas.ToUpperInvariant() + ' CARPETA' }
        $marca = ''; $col = $null
        if ($e.Sensible) { $marca = '  [SENSIBLE]'; $col = 'Magenta' }
        Write-Linea ('  {0,-15} {1}  ->  {2}{3}' -f $v, $e.Rel, (Get-RutaRelativa $e.Destino $script:DestinoAbs), $marca) $col
    }
    if ($activos.Count -eq 0) { Write-Linea '  (nada que procesar)' }
    $tit = 'RESUMEN DE LA SIMULACION'; if (-not $script:Simulacion) { $tit = 'RESUMEN PREVIO' }
    Show-Resumen $tit $libre $necesario
    foreach ($e in $script:Elementos) {
        if ($e.Omitido) { Write-Fila 'omitir' $e.Categoria $e.Origen '' $e.Bytes 'omitido' 'info' $e.Omitido }
    }

    $yaConfirmado = $false
    if ($script:Simulacion) {
        foreach ($e in $activos) {
            $acc = $Modo.ToLowerInvariant(); if ($e.Tipo -eq 'carpeta') { $acc = $Carpetas.ToLowerInvariant() + '-carpeta' }
            $sev = 'info'; $det = ''; if ($e.Sensible) { $sev = 'aviso'; $det = 'SENSIBLE' }
            Write-Fila $acc $e.Categoria $e.Origen $e.Destino $e.Bytes 'simulado' $sev $det
        }
        Write-Linea ''
        Write-Linea 'SIMULACION terminada: no se ha creado, copiado, movido ni borrado nada.' 'Green'
        Write-Linea ('Logs: {0}' -f $script:RutaTxt); Write-Linea ('      {0}' -f $script:RutaCsv)
        $seguir = $false
        if ($interactivo -and $activos.Count -gt 0 -and -not $WhatIfPreference) { $seguir = Read-SiNo "`nEjecutar ahora DE VERDAD este mismo plan?" $false }
        if (-not $seguir) {
            Write-Linea ('Para ejecutarlo mas tarde:  {0}' -f (Get-ComandoEquivalente))
            Write-Linea ('Duracion: {0:N1} s' -f ((Get-Date) - $inicio).TotalSeconds)
            return $script:SALIDA_OK
        }
        $script:Simulacion = $false
        $yaConfirmado = $true
        Write-Fila 'aviso' '' '' '' '' 'confirmado' 'info' 'simulacion revisada; se ejecuta el mismo plan'
    }
    $mueve = ($Modo -eq 'Mover' -or $Carpetas -eq 'Mover')

    # ---------- 2) Comprobaciones previas a la ejecucion ----------
    $fallo = Test-Escritura $script:DestinoAbs
    if ($fallo) { Write-Linea ('CRITICO: falla la prueba de escritura en {0}: {1}' -f $script:DestinoAbs, $fallo) 'Red'; return $script:SALIDA_CRITICO }
    if ($null -ne $libre -and $libre -lt $necesario) { Write-Linea 'CRITICO: no hay espacio suficiente en el destino.' 'Red'; return $script:SALIDA_CRITICO }
    if ($activos.Count -eq 0) { Write-Linea 'Nada que procesar.' 'Green'; return $script:SALIDA_OK }

    $sens = @($activos | Where-Object { $_.Sensible })
    if ($sens.Count -gt 0 -and ($script:DestinoAbs.StartsWith('\\') -or (Test-Extraible $script:DestinoAbs))) {
        Write-Linea ('ATENCION: vas a llevar {0} archivo(s) SENSIBLE(S) a una unidad de red o extraible.' -f $sens.Count) 'Magenta'
        if ($Si) {
            Write-Fila 'aviso' '' '' $script:DestinoAbs '' 'confirmado' 'aviso' 'sensibles a UNC/extraible confirmados con -Si'
        } elseif ((Test-SinConsola) -or -not (Read-SiNo 'Incluir los sensibles?' $false)) {
            foreach ($e in $sens) {
                $e.Omitido = 'sensible no confirmado para destino UNC/extraible'
                Write-Fila 'omitir' $e.Categoria $e.Origen '' $e.Bytes 'omitido' 'aviso' $e.Omitido
            }
            $activos = @($activos | Where-Object { -not $_.Omitido })
        }
    }

    if (-not $Si -and -not ($yaConfirmado -and -not $mueve)) {
        if ((Test-SinConsola)) { Write-Linea 'Cancelado: no hay consola para confirmar (usa -Si).' 'Yellow'; return $script:SALIDA_PARAMETROS }
        if ($mueve) {
            $r = Read-Host "`nVas a MOVER archivos. Escribe ""SI"" para continuar"
            $ok = (@('SI', 'SI') -contains $r.Trim().ToUpperInvariant())
        } else {
            $ok = Read-SiNo "`nEjecutar este plan?" $false
        }
        if (-not $ok) { Write-Linea 'Cancelado por el usuario. No se ha tocado nada.' 'Yellow'; return $script:SALIDA_PARAMETROS }
    } elseif ($Si) {
        Write-Verbose 'Confirmacion final saltada con -Si'
        Write-Fila 'aviso' '' '' '' '' 'confirmado' 'info' 'confirmacion final saltada con -Si'
    }

    # ---------- 3) Ejecucion del MISMO plan ----------
    $script:Creadas = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:Errores = New-Object System.Collections.Generic.List[object]
    $script:NumOk = 0; $script:BytesOk = [int64]0
    $script:Ejecutado = $true
    Write-Linea ''
    Write-Linea '>>> EJECUTANDO <<<' 'Cyan'
    foreach ($e in $activos) {
        $acc = $Modo.ToLowerInvariant(); if ($e.Tipo -eq 'carpeta') { $acc = $Carpetas.ToLowerInvariant() + '-carpeta' }
        $script:EnDestino = $false
        try {
            if ($e.Tipo -eq 'archivo') { Invoke-Archivo $e $acc } else { Invoke-Carpeta $e $acc }
        } catch [System.ApplicationException] {
            throw
        } catch {
            Add-ErrorNoCritico $e $acc $_
        }
    }

    Show-Resumen 'RESUMEN FINAL' (Get-EspacioLibre $script:DestinoAbs) 0
    Write-Linea ('Procesados correctamente: {0} ({1})' -f $script:NumOk, (Format-Tam $script:BytesOk)) 'Green'
    if ($script:Errores.Count -gt 0) {
        Write-Linea ('Errores no criticos: {0}' -f $script:Errores.Count) 'Yellow'
        foreach ($g in ($script:Errores | Group-Object Causa)) { Write-Linea ('  {0,4} x {1}' -f $g.Count, $g.Name) 'Yellow' }
        Write-Linea 'Primeros 10:' 'Yellow'
        foreach ($x in ($script:Errores | Select-Object -First 10)) { Write-Linea ('  - {0}: {1}' -f $x.Rel, $x.Causa) 'Yellow' }
    }
    Write-Linea ('Logs: {0}' -f $script:RutaTxt); Write-Linea ('      {0}' -f $script:RutaCsv)
    Write-Linea ('Duracion: {0:N1} s' -f ((Get-Date) - $inicio).TotalSeconds)
    if ($script:Errores.Count -gt 0) { return $script:SALIDA_NO_CRITICOS }
    return $script:SALIDA_OK
}

function Copy-LogsFinal {
    # Con -Aplicar: Stop-Transcript, cerrar CSV y copiar los logs a <contenedora>\_logs.
    if (-not $script:Ejecutado -or -not $script:RutaContenedora) { return }
    if (-not [IO.Directory]::Exists((Get-LP $script:RutaContenedora))) { return }   # no crear la contenedora solo por los logs
    $d = Join-Path $script:RutaContenedora $script:CarpetaLogs
    try {
        [void][IO.Directory]::CreateDirectory((Get-LP $d))
        foreach ($r in @($script:RutaTxt, $script:RutaCsv)) {
            if ($r -and [IO.File]::Exists($r)) { [IO.File]::Copy($r, (Get-LP (Join-Path $d ([IO.Path]::GetFileName($r)))), $false) }
        }
        Write-Host ('Logs copiados a {0}' -f $d)
    } catch {
        Write-Host ('AVISO: no se pudieron copiar los logs a {0}: {1}' -f $d, $_.Exception.Message)
    }
}

# Variables de script que la funcion principal puede modificar (modo interactivo)
$script:ParamsLlamada = @($PSBoundParameters.Keys)
$script:Origen = $Origen; $script:Excluir = $Excluir; $script:IncluirSolo = $IncluirSolo
$script:Destino = $Destino; $script:Contenedora = $Contenedora; $script:Otros = $Otros
$script:Modo = $Modo; $script:Recursivo = $Recursivo; $script:Carpetas = $Carpetas
$script:Aplicar = $Aplicar; $script:Mapeo = $Mapeo
$script:Simulacion = $true; $script:Transcript = $false; $script:Csv = $null
$script:RutaContenedora = $null; $script:RutaTxt = $null; $script:RutaCsv = $null
$script:EnDestino = $false; $script:Ejecutado = $false; $script:PrefijoLargoOk = $null

$codigo = $script:SALIDA_OK
try {
    $codigo = Invoke-Principal
} catch [System.ApplicationException] {
    Write-Linea ('CRITICO: {0}. Proceso abortado.' -f $_.Exception.Message) 'Red'
    $codigo = $script:SALIDA_CRITICO
} catch {
    Write-Linea ('CRITICO inesperado: {0}' -f $_.Exception.Message) 'Red'
    $codigo = $script:SALIDA_CRITICO
} finally {
    if ($script:Transcript) { try { [void](Stop-Transcript) } catch { } }
    Close-Csv
    Copy-LogsFinal
}
exit $codigo
