<#
.SYNOPSIS
  Fase 0 · Verifica el SHA256 de una ISO contra su fichero .sha256 oficial. SOLO LECTURA.
.DESCRIPTION
  Calcula el hash con Get-FileHash y lo compara con el publicado junto a la ISO.
  Compatible con Windows PowerShell 5.1 y PowerShell 7.
  Códigos de salida: 0 = coincide · 1 = NO coincide · 2 = falta un fichero · 3 = el .sha256 no sirve.
  El SHA256 detecta descargas corruptas; la autenticidad la da la firma .sig (FASE0.md, paso 0.6).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Verificar-ISO.ps1 -Iso .\cachyos-desktop-linux-260809.iso
.EXAMPLE
  .\Verificar-ISO.ps1 -Iso .\omarchy-4.0.6.iso -Sha256 .\omarchy-4.0.6.iso.sha256
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Iso,
  [string]$Sha256
)
$ErrorActionPreference = 'Stop'
if (-not $Sha256) { $Sha256 = "$Iso.sha256" }

foreach ($f in @($Iso, $Sha256)) {
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
    Write-Host "FALLO: no existe el fichero '$f'." -ForegroundColor Red
    exit 2
  }
}

$isoNombre = Split-Path -Leaf $Iso
# Formato oficial (CachyOS y Omarchy): "<64 hex>  <nombre>" o "<64 hex> *<nombre>".
$lineas = @(Get-Content -LiteralPath $Sha256 | Where-Object { $_ -match '^\s*[0-9a-fA-F]{64}(\s|$)' })
if ($lineas.Count -eq 0) {
  Write-Host "FALLO: '$Sha256' no contiene ningún SHA256 válido (64 caracteres hexadecimales)." -ForegroundColor Red
  exit 3
}
$patronNombre = '\s\*?' + [regex]::Escape($isoNombre) + '\s*$'
$linea = $lineas | Where-Object { $_ -match $patronNombre } | Select-Object -First 1
if (-not $linea) {
  if ($lineas.Count -eq 1) {
    $linea = $lineas[0]
    Write-Host "AVISO: el .sha256 no nombra '$isoNombre'; se usa su único hash. Comprueba que es el fichero correcto." -ForegroundColor Yellow
  } else {
    Write-Host "FALLO: '$Sha256' tiene varios hashes y ninguno corresponde a '$isoNombre'." -ForegroundColor Red
    exit 3
  }
}

$esperado = ([regex]::Match($linea, '[0-9a-fA-F]{64}')).Value.ToLowerInvariant()
Write-Host "Calculando SHA256 de '$isoNombre' (puede tardar un minuto)..."
$real = (Get-FileHash -LiteralPath $Iso -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Esperado: $esperado"
Write-Host "Real:     $real"

if ($real -eq $esperado) {
  Write-Host 'RESULTADO: OK - el SHA256 coincide. Siguiente: verificar la firma .sig con gpg.' -ForegroundColor Green
  exit 0
}
Write-Host 'RESULTADO: FALLO - el SHA256 NO coincide. No grabes esta ISO: bórrala y vuelve a descargarla.' -ForegroundColor Red
exit 1
