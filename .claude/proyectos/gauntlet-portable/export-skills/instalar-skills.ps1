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

  $dir     = Join-Path $Destino $nombre
  $destino = Join-Path $dir 'SKILL.md'

  if (Test-Path -LiteralPath $destino) {
    $bak = "$destino.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($PSCmdlet.ShouldProcess($destino, "Copia de seguridad en $bak")) {
      Copy-Item -LiteralPath $destino -Destination $bak
      Write-Host "Copia de seguridad: $bak"
    }
  }
  if ($PSCmdlet.ShouldProcess($destino, "Instalar desde $origen")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item -LiteralPath $origen -Destination $destino -Force
    Write-Host "OK  $destino"
  }
}
Write-Host "`nReinicia Claude Code para que cargue las skills. Comprueba con /skills."
