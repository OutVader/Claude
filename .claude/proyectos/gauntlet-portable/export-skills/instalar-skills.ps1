#Requires -Version 5.1
<#
.SYNOPSIS
  Instala las skills personales "gauntlet-loop" (v2) y "eficiencia" en Claude Code (Windows).
.DESCRIPTION
  Copia cada SKILL.md a %USERPROFILE%\.claude\skills\<nombre>\SKILL.md
  (p. ej. C:\Users\<tu usuario>\.claude\skills\gauntlet-loop\SKILL.md).
  Si ya existe un SKILL.md, antes guarda una copia de seguridad .bak-<fecha>.
  Ensayo sin cambios:  .\instalar-skills.ps1 -WhatIf
.NOTES
  Ejecutar desde el clon del repo:  .claude\proyectos\gauntlet-portable\export-skills\
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  # Raíz del repo (4 niveles por encima de esta carpeta).
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,
  # Carpeta de skills personales de Claude Code.
  [string]$Destino  = (Join-Path $env:USERPROFILE '.claude\skills')
)
$ErrorActionPreference = 'Stop'

$skills = [ordered]@{
  'gauntlet-loop' = Join-Path $RepoRoot '.claude\skills\gauntlet-loop\SKILL.md'
  'eficiencia'    = Join-Path $PSScriptRoot 'eficiencia\SKILL.md'
}

foreach ($nombre in $skills.Keys) {
  $origen = $skills[$nombre]
  if (-not (Test-Path -LiteralPath $origen)) { throw "No encuentro el origen: $origen" }

  # OJO: PowerShell no distingue mayúsculas; no reutilizar el nombre $Destino aquí.
  $dirSkill    = Join-Path $Destino $nombre
  $archivoSkill = Join-Path $dirSkill 'SKILL.md'

  if (Test-Path -LiteralPath $archivoSkill) {
    $bak = "$archivoSkill.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($PSCmdlet.ShouldProcess($archivoSkill, "Copia de seguridad en $bak")) {
      Copy-Item -LiteralPath $archivoSkill -Destination $bak
      Write-Host "Copia de seguridad: $bak"
    }
  }
  if ($PSCmdlet.ShouldProcess($archivoSkill, "Instalar desde $origen")) {
    New-Item -ItemType Directory -Force -Path $dirSkill | Out-Null
    Copy-Item -LiteralPath $origen -Destination $archivoSkill -Force
    Write-Host "OK  $archivoSkill"
  }

  # 'eficiencia' depende de archivos que no vienen en la copia sincronizada.
  if ($nombre -eq 'eficiencia') {
    $faltan = @('scripts\eficiencia.py', 'referencia-effort-cache.md', 'referencia-frontend.md') |
      Where-Object { -not (Test-Path -LiteralPath (Join-Path $dirSkill $_)) }
    if ($faltan) {
      Write-Warning ("A 'eficiencia' le faltan: " + ($faltan -join ', ') +
        ". Fallará en 'EF preflight' hasta que copies el paquete completo en $dirSkill")
    }
  }
}
Write-Host "`nReinicia Claude Code para que cargue las skills. Comprueba con /skills."
