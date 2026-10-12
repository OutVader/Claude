# _comun.ps1 — rutas y utilidades compartidas. Se carga con: . "$PSScriptRoot\_comun.ps1"
# Compatible con Windows PowerShell 5.1 y PowerShell 7.

$ErrorActionPreference = 'Stop'

$Script:Raiz    = 'C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD'
$Script:Indices = Join-Path $Raiz '.claude\_indices'
$Script:Backups = Join-Path $Raiz ('.backups\consolidacion-' + (Get-Date -Format 'yyyyMMdd'))

# Alias -> origen / destino
$Script:Fuentes = [ordered]@{
    'CLAUDE_HOME' = @{ Origen = "$env:USERPROFILE\.claude"; Destino = Join-Path $Raiz '.claude\_home' }
    'CODEX_HOME'  = @{ Origen = "$env:USERPROFILE\.codex";  Destino = Join-Path $Raiz '.codex\_home' }
    'SCRIPTS'     = @{ Origen = 'C:\Users\D746288\Desktop\0.Escritorio\TRABAJO\TRACASA\SCRIPTS'
                       Destino = Join-Path $Raiz '.claude\Proyectos\TRACASA-SCRIPTS' }
}

# Nunca se leen ni se copian (solo se listan como SENSIBLE)
$Script:PatronesSensibles = @('.credentials.json','auth.json','*.key','*.pem','*.pfx','.env','.env.*','*token*','*secret*')

function Test-Sensible([string]$Nombre) {
    foreach ($p in $PatronesSensibles) { if ($Nombre -like $p) { return $true } }
    return $false
}

function Test-Junction([System.IO.FileSystemInfo]$Item) {
    return [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Write-Fase([string]$Texto) { Write-Host "`n=== $Texto ===" -ForegroundColor Cyan }

function New-Carpeta([string]$Ruta) {
    if (-not (Test-Path -LiteralPath $Ruta)) { New-Item -ItemType Directory -Path $Ruta -Force | Out-Null }
}

# Codificación de ruta que usa Claude Code para ~\.claude\projects\<carpeta>
function ConvertTo-ClaveProyecto([string]$Ruta) { return ($Ruta -replace '[^A-Za-z0-9]', '-') }

# Lista archivos recursivamente SIN entrar en junctions/symlinks (PS 5.1 sí las sigue con -Recurse)
function Get-ArchivosSinJunctions([string]$Ruta, [string]$ExcluirRegex = '^$') {
    $pila = New-Object System.Collections.Generic.Stack[string]; $pila.Push($Ruta)
    while ($pila.Count -gt 0) {
        $d = $pila.Pop()
        foreach ($h in (Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue)) {
            if ($h.FullName -match $ExcluirRegex -or (Test-Junction $h)) { continue }
            if ($h.PSIsContainer) { $pila.Push($h.FullName) } else { $h }
        }
    }
}

# Reemplazo literal sin distinguir mayúsculas
function Edit-Literal([string]$Texto, [string]$Viejo, [string]$Nuevo) {
    return [regex]::Replace($Texto, [regex]::Escape($Viejo), $Nuevo.Replace('$', '$$'), 'IgnoreCase')
}
