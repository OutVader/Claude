<#
.SYNOPSIS  Fase 3 — Detecta y rehace enlaces rotos y rutas antiguas dentro de AGENTES_WD.
.DESCRIPTION
  Revisa:
    - Enlaces Markdown  [texto](ruta)     -> existe el destino (relativo al archivo)?
    - Wikilinks Obsidian [[nota]] / [[nota|alias]] -> existe nota.md en la raíz?
    - Rutas absolutas antiguas (tabla $Mapa) dentro de archivos de texto.
    - Accesos directos .lnk -> existe el destino? apunta a una ruta antigua?
  Sin -Aplicar: solo genera el informe _indices\ENLACES-<fecha>.csv/.md.
  Con -Aplicar: reescribe las rutas antiguas según $Mapa (con copia previa en .backups).
  Por defecto solo reescribe .md/.txt/.json/.lnk; los scripts (.ps1/.bat/.cmd) solo con
  -IncluirScripts. No toca el código de apps (.html/.js) ni el historial (.jsonl).
.EXAMPLE   .\04-Enlaces.ps1
.EXAMPLE   .\04-Enlaces.ps1 -Aplicar -IncluirScripts
#>
[CmdletBinding()]
param([switch]$Aplicar, [switch]$IncluirScripts)
. "$PSScriptRoot\_comun.ps1"

# Ruta antigua -> ruta nueva (orden: de la más específica a la más general)
$Mapa = [ordered]@{
    'C:\Users\D746288\Desktop\0.Escritorio\TRABAJO\TRACASA\SCRIPTS' = $Fuentes['SCRIPTS'].Destino
    "$Raiz\Proyectos\Web_Checklist"                                  = "$Raiz\.claude\Proyectos\Web_Checklist"
}
# Variantes escapadas para JSON (C:\\Users\\...)
foreach ($k in @($Mapa.Keys)) { $Mapa[$k.Replace('\', '\\')] = $Mapa[$k].Replace('\', '\\') }
# Rutas que solo se informan (siguen siendo válidas mientras existan los originales)
$SoloInformar = @("$env:USERPROFILE\.claude", "$env:USERPROFILE\.codex")

$extTexto    = @('.md', '.txt', '.json', '.yml', '.yaml', '.csv')
$extScripts  = @('.ps1', '.psm1', '.bat', '.cmd')
$excluirDirs = '\\(\.git|node_modules|\.backups|\.obsidian|_indices)(\\|$)|\\_home\\projects(\\|$)'

$todos = @(Get-ArchivosSinJunctions $Raiz $excluirDirs)
$notas = @{}; foreach ($n in ($todos | Where-Object Extension -eq '.md')) { $notas[$n.BaseName.ToLower()] = $true }

$hallazgos = New-Object System.Collections.Generic.List[object]
function Add-H($a, $l, $t, $d, $e, $p) { $hallazgos.Add([pscustomobject]@{ Archivo = $a.Substring($Raiz.Length); Linea = $l; Tipo = $t; Destino = $d; Estado = $e; Propuesta = $p }) }
function Get-Propuesta([string]$Texto) {
    foreach ($k in $Mapa.Keys) { if ($Texto -and $Texto.IndexOf($k, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return (Edit-Literal $Texto $k $Mapa[$k]) } }
    return ''
}

Write-Fase "Analizando $($todos.Count) archivos"
foreach ($a in $todos) {
    $ext = $a.Extension.ToLower()
    if ($ext -eq '.lnk') {
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($a.FullName)
        $t = $sc.TargetPath
        $p = Get-Propuesta $t
        $estado = if ($p) { 'RUTA_ANTIGUA' } elseif ($t -and -not (Test-Path -LiteralPath $t)) { 'ROTO' } else { 'OK' }
        if ($estado -ne 'OK') { Add-H $a.FullName 0 'LNK' $t $estado $p }
        continue
    }
    if ($ext -notin ($extTexto + $extScripts)) { continue }
    $lineas = Get-Content -LiteralPath $a.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $lineas.Count; $i++) {
        $ln = [string]$lineas[$i]
        foreach ($k in $Mapa.Keys) { if ($ln.IndexOf($k, [StringComparison]::OrdinalIgnoreCase) -ge 0) { Add-H $a.FullName ($i + 1) 'RUTA' $k 'RUTA_ANTIGUA' $Mapa[$k] } }
        foreach ($k in $SoloInformar) { if ($ln.IndexOf($k, [StringComparison]::OrdinalIgnoreCase) -ge 0) { Add-H $a.FullName ($i + 1) 'RUTA' $k 'INFO_HOME_ORIGINAL' '' } }
        if ($ext -ne '.md') { continue }
        foreach ($m in [regex]::Matches($ln, '\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)')) {
            $dest = $m.Groups[1].Value
            if ($dest -match '^(https?|mailto|file|obsidian):' -or $dest.StartsWith('#')) { continue }
            $limpio = [uri]::UnescapeDataString(($dest -split '#')[0]).Replace('/', '\')
            if (-not $limpio) { continue }
            $abs = if ([IO.Path]::IsPathRooted($limpio)) { $limpio } else { Join-Path $a.DirectoryName $limpio }
            if (-not (Test-Path -LiteralPath $abs)) { Add-H $a.FullName ($i + 1) 'MD' $dest 'ROTO' (Get-Propuesta $abs) }
        }
        foreach ($m in [regex]::Matches($ln, '\[\[([^\]\|#]+)')) {
            $nota = [IO.Path]::GetFileNameWithoutExtension($m.Groups[1].Value.Trim()).ToLower()
            if (-not $notas.ContainsKey($nota)) { Add-H $a.FullName ($i + 1) 'WIKI' $m.Groups[1].Value 'ROTO' '' }
        }
    }
}

$sello = Get-Date -Format 'yyyyMMdd-HHmm'
New-Carpeta $Indices
$csv = Join-Path $Indices "ENLACES-$sello.csv"
$hallazgos | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
$hallazgos | Group-Object Tipo, Estado | Sort-Object Name | Format-Table Count, Name -AutoSize
$md = @("# Informe de enlaces — $sello", "", "| Tipo · Estado | Nº |", "|---|---:|")
$md += $hallazgos | Group-Object Tipo, Estado | Sort-Object Name | ForEach-Object { "| $($_.Name) | $($_.Count) |" }
$md += "", "Detalle: [ENLACES-$sello.csv](./ENLACES-$sello.csv)"
Set-Content -LiteralPath (Join-Path $Indices "ENLACES-$sello.md") -Value $md -Encoding UTF8
Write-Host "Informe: $csv" -ForegroundColor Green

if (-not $Aplicar) { Write-Host "[SIMULACIÓN] No se ha modificado nada. Repite con -Aplicar para reescribir las RUTA_ANTIGUA." -ForegroundColor Yellow; return }

# --- Reescritura (solo RUTA_ANTIGUA) ---
$permitidas = $extTexto + $(if ($IncluirScripts) { $extScripts } else { @() })
$archivos = $hallazgos | Where-Object Estado -eq 'RUTA_ANTIGUA' | Select-Object -ExpandProperty Archivo -Unique
$cambiados = 0
foreach ($rel in $archivos) {
    $ruta = Join-Path $Raiz $rel.TrimStart('\')
    $ext = [IO.Path]::GetExtension($ruta).ToLower()
    $bk = Join-Path $Backups ('enlaces\' + $rel.TrimStart('\'))
    New-Carpeta (Split-Path $bk -Parent)
    if ($ext -eq '.lnk') {
        Copy-Item -LiteralPath $ruta -Destination $bk -Force
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($ruta)
        $p = Get-Propuesta $sc.TargetPath; if ($p) { $sc.TargetPath = $p }
        if ($sc.WorkingDirectory) { $p = Get-Propuesta $sc.WorkingDirectory; if ($p) { $sc.WorkingDirectory = $p } }
        $sc.Save(); $cambiados++; continue
    }
    if ($ext -notin $permitidas) { Write-Host "  (omitido, extensión $ext) $rel" -ForegroundColor DarkYellow; continue }
    Copy-Item -LiteralPath $ruta -Destination $bk -Force
    $bytes = [IO.File]::ReadAllBytes($ruta)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $txt = [IO.File]::ReadAllText($ruta)
    foreach ($k in $Mapa.Keys) { $txt = Edit-Literal $txt $k $Mapa[$k] }
    [IO.File]::WriteAllText($ruta, $txt, (New-Object Text.UTF8Encoding($bom)))
    $cambiados++
}
Write-Host "Reescritos $cambiados archivos. Copia previa en $Backups\enlaces. Vuelve a ejecutar sin -Aplicar para comprobar que quedan 0 RUTA_ANTIGUA." -ForegroundColor Green
