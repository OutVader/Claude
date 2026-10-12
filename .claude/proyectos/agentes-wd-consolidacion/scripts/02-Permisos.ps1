<#
.SYNOPSIS  Fase 0 — Control total para el usuario actual sobre AGENTES_WD.
.DESCRIPTION
  Sin -Aplicar: solo muestra la ACL actual y lo que se haría.
  Con -Aplicar: concede (OI)(CI)F al usuario actual de forma recursiva y quita el atributo
  "solo lectura" a los archivos. No elimina permisos de nadie ni cambia el propietario
  (para eso, -TomarPropiedad, que exige consola como administrador).
.EXAMPLE   .\02-Permisos.ps1            # ver
.EXAMPLE   .\02-Permisos.ps1 -Aplicar   # aplicar
#>
[CmdletBinding()]
param([switch]$Aplicar, [switch]$TomarPropiedad)
. "$PSScriptRoot\_comun.ps1"

$usuario = "$env:USERDOMAIN\$env:USERNAME"
Write-Fase "ACL actual de $Raiz"
icacls "$Raiz"

if (-not $Aplicar) {
    Write-Host "`n[SIMULACIÓN] Se ejecutaría:" -ForegroundColor Yellow
    if ($TomarPropiedad) { Write-Host "  takeown /F `"$Raiz`" /R /D S" }
    Write-Host "  icacls `"$Raiz`" /grant `"${usuario}:(OI)(CI)F`" /T /C"
    Write-Host "  attrib -R `"$Raiz\*`" /S /D"
    Write-Host "Repite con -Aplicar para ejecutarlo."
    return
}

if ($TomarPropiedad) { takeown /F "$Raiz" /R /D S | Out-Null }
icacls "$Raiz" /grant "${usuario}:(OI)(CI)F" /T /C | Select-Object -Last 2
attrib -R "$Raiz\*" /S /D
Write-Fase 'ACL resultante'
icacls "$Raiz" | Select-String ([regex]::Escape($env:USERNAME))
