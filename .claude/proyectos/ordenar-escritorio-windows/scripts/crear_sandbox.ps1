<#
.SYNOPSIS
    Crea un Escritorio de PRUEBA para ensayar Ordenar-Archivos.ps1 y ordenar_archivos.py
    sin tocar nunca el Escritorio real.
.DESCRIPTION
    Crea <Ruta>\origen (accesos directos, PDF, duplicados, sensibles FALSOS, Unicode,
    corchetes, sin extensión, ~$, desktop.ini oculto y la carpeta "Proyecto X") y
    <Ruta>\destino con zOrdenado\PDF\informe.pdf ya existente. Devuelve la ruta creada.
.PARAMETER Ruta
    Carpeta del sandbox. Por defecto, una nueva en %TEMP%. Si existe y no está vacía, se para.
.EXAMPLE
    $s = .\crear_sandbox.ps1; .\Ordenar-Archivos.ps1 -Origen "$s\origen" -Destino "$s\destino"
#>
[CmdletBinding()]
param([string]$Ruta)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if (-not $Ruta) { $Ruta = Join-Path ([IO.Path]::GetTempPath()) ('sandbox_ordenar_' + [guid]::NewGuid().ToString('N').Substring(0, 8)) }
$Ruta = [IO.Path]::GetFullPath($Ruta)
if ([IO.Directory]::Exists($Ruta) -and @([IO.Directory]::GetFileSystemEntries($Ruta)).Count -gt 0) {
    throw "La carpeta $Ruta ya existe y no está vacía: elige otra (no se sobrescribe nada)."
}
$origen = Join-Path $Ruta 'origen'
[void][IO.Directory]::CreateDirectory($origen)
$utf8 = New-Object Text.UTF8Encoding($false)
$archivos = [ordered]@{
    'Warp.lnk' = 'LNK-FALSO-WARP'; 'Zoom.lnk' = 'LNK-FALSO-ZOOM'
    'Acceso directo a Internet.url' = "[InternetShortcut]`r`nURL=https://example.org/`r`n"
    'WhatsApp Image 2026-09-30 at 10.12.33.jpeg' = 'JPEG-FALSO'
    'informe.pdf' = '%PDF-1.7 informe'; 'informe (1).pdf' = '%PDF-1.7 informe'
    'acta_v2.docx' = 'DOCX v2'; 'acta_v3.docx' = 'DOCX v3 distinto'
    'notas.md' = "# Notas`nñ áéíóú`n"; 'log.txt' = "linea de log`n"; 'correo.msg' = 'MSG-FALSO'
    'cert.p12' = 'P12-FALSO-NO-ES-UN-CERTIFICADO'; 'cert.key' = 'KEY-FALSA-NO-ES-UNA-CLAVE'
    'script.ps1' = "Write-Output 'hola'`r`n"; 'pack.rar' = 'Rar!FALSO'
    ('año ñ ' + [char]::ConvertFromUtf32(0x1F600) + '.txt') = "Unicode ñ`n"
    'a[1].txt' = "corchetes`n"; 'sinextension' = "sin extension`n"; '~$acta.docx' = 'temporal de Word'
    'desktop.ini' = "[.ShellClassInfo]`r`n"
}
foreach ($n in $archivos.Keys) { [IO.File]::WriteAllText((Join-Path $origen $n), $archivos[$n], $utf8) }
$ini = New-Object IO.FileInfo((Join-Path $origen 'desktop.ini'))
if ([Environment]::OSVersion.Platform -eq 'Win32NT') { $ini.Attributes = $ini.Attributes -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System }
$proyecto = Join-Path $origen 'Proyecto X'
[void][IO.Directory]::CreateDirectory($proyecto)
foreach ($n in @('plan.docx', 'datos.xlsx')) { [IO.File]::WriteAllText((Join-Path $proyecto $n), "contenido de $n", $utf8) }
$pdf = Join-Path (Join-Path (Join-Path $Ruta 'destino') 'zOrdenado') 'PDF'
[void][IO.Directory]::CreateDirectory($pdf)
[IO.File]::WriteAllText((Join-Path $pdf 'informe.pdf'), '%PDF ya existente en destino', $utf8)
Write-Output $Ruta
