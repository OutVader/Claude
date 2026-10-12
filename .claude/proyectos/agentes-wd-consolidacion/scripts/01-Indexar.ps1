<#
.SYNOPSIS  Fase 1 — Indexa (SOLO LECTURA) ~\.claude, ~\.codex y TRACASA\SCRIPTS.
.DESCRIPTION
  Recorre cada fuente sin entrar en junctions/symlinks y genera, en AGENTES_WD\.claude\_indices:
    INDICE-<alias>.csv   un registro por elemento (ruta, tipo, tamaño, fecha, SENSIBLE, destino)
    INDICE-<alias>.md    resumen legible: árbol de 1er nivel, tamaños, .md, sensibles, junctions
    INDICE-GENERAL.md    tabla resumen de las tres fuentes
  No lee el contenido de los archivos sensibles: solo los marca.
.PARAMETER Hash  Calcula SHA256 de cada archivo (más lento; útil para verificar la copia).
.EXAMPLE   .\01-Indexar.ps1
#>
[CmdletBinding()]
param([switch]$Hash)
. "$PSScriptRoot\_comun.ps1"

New-Carpeta $Indices
$resumen = @()

foreach ($alias in $Fuentes.Keys) {
    $f = $Fuentes[$alias]
    Write-Fase "Indexando $alias  ($($f.Origen))"
    if (-not (Test-Path -LiteralPath $f.Origen)) { Write-Warning "No existe: $($f.Origen)"; continue }

    $filas = New-Object System.Collections.Generic.List[object]
    $pila  = New-Object System.Collections.Generic.Stack[string]
    $pila.Push($f.Origen)
    while ($pila.Count -gt 0) {
        $dir = $pila.Pop()
        try { $hijos = Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop }
        catch { $filas.Add([pscustomobject]@{ Ruta = $dir.Substring($f.Origen.Length).TrimStart('\'); Tipo = 'SIN_ACCESO'; Bytes = 0; Modificado = ''; Ext = ''; Sensible = ''; Destino = ''; SHA256 = '' }); continue }
        foreach ($h in $hijos) {
            $rel  = $h.FullName.Substring($f.Origen.Length).TrimStart('\')
            $junc = Test-Junction $h
            $tipo = if ($junc) { 'JUNCTION' } elseif ($h.PSIsContainer) { 'DIR' } else { 'FILE' }
            $sens = (-not $h.PSIsContainer) -and (Test-Sensible $h.Name)
            $sha  = ''
            if ($Hash -and $tipo -eq 'FILE' -and -not $sens) { try { $sha = (Get-FileHash -LiteralPath $h.FullName -Algorithm SHA256).Hash } catch { $sha = 'ERROR' } }
            $filas.Add([pscustomobject]@{
                Ruta       = $rel
                Tipo       = $tipo
                Bytes      = if ($h.PSIsContainer) { 0 } else { $h.Length }
                Modificado = $h.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
                Ext        = $h.Extension
                Sensible   = if ($sens) { 'SENSIBLE' } else { '' }
                Destino    = if ($sens -or $junc) { '(no se copia)' } else { Join-Path $f.Destino $rel }
                SHA256     = $sha
            })
            if ($h.PSIsContainer -and -not $junc) { $pila.Push($h.FullName) }
        }
    }

    $csv = Join-Path $Indices "INDICE-$alias.csv"
    $filas | Sort-Object Ruta | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8

    $archivos = $filas | Where-Object Tipo -eq 'FILE'
    $totalMB  = [math]::Round((($archivos | Measure-Object Bytes -Sum).Sum) / 1MB, 1)
    $nivel1   = $filas | Where-Object { $_.Ruta -notmatch '\\' } | Sort-Object Tipo, Ruta
    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine("# Índice — $alias")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("- **Origen:** ``$($f.Origen)``")
    [void]$md.AppendLine("- **Destino propuesto:** ``$($f.Destino)``")
    [void]$md.AppendLine("- **Generado:** $(Get-Date -Format 'yyyy-MM-dd HH:mm') · Archivos: $($archivos.Count) · Carpetas: $(($filas | Where-Object Tipo -eq 'DIR').Count) · Total: $totalMB MB")
    [void]$md.AppendLine("- **Detalle completo:** [INDICE-$alias.csv](./INDICE-$alias.csv)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Primer nivel")
    [void]$md.AppendLine("| Elemento | Tipo | Archivos | MB |")
    [void]$md.AppendLine("|---|---|---:|---:|")
    $porRaiz = @{}
    foreach ($a in $archivos) { $k = $a.Ruta.Split('\')[0]; if (-not $porRaiz[$k]) { $porRaiz[$k] = @(0, 0) }; $porRaiz[$k][0]++; $porRaiz[$k][1] += $a.Bytes }
    foreach ($n in $nivel1) {
        $v = if ($porRaiz[$n.Ruta]) { $porRaiz[$n.Ruta] } else { @(0, 0) }
        [void]$md.AppendLine("| ``$($n.Ruta)`` | $($n.Tipo) | $($v[0]) | $([math]::Round($v[1] / 1MB, 2)) |")
    }
    foreach ($bloque in @(
        @{ T = 'Documentos .md'; F = { $_.Ext -eq '.md' } },
        @{ T = 'SENSIBLES (no se copian ni se leen)'; F = { $_.Sensible } },
        @{ T = 'Junctions / enlaces (no se recorren)'; F = { $_.Tipo -eq 'JUNCTION' } },
        @{ T = 'Sin acceso'; F = { $_.Tipo -eq 'SIN_ACCESO' } })) {
        $sel = @($filas | Where-Object $bloque.F | Sort-Object Ruta)
        [void]$md.AppendLine(""); [void]$md.AppendLine("## $($bloque.T) ($($sel.Count))")
        foreach ($s in ($sel | Select-Object -First 300)) { [void]$md.AppendLine("- ``$($s.Ruta)``") }
        if ($sel.Count -gt 300) { [void]$md.AppendLine("- … ($($sel.Count - 300) más en el CSV)") }
    }
    Set-Content -LiteralPath (Join-Path $Indices "INDICE-$alias.md") -Value $md.ToString() -Encoding UTF8

    $resumen += [pscustomobject]@{ Alias = $alias; Origen = $f.Origen; Archivos = $archivos.Count; MB = $totalMB
        Sensibles = @($filas | Where-Object Sensible).Count; Junctions = @($filas | Where-Object Tipo -eq 'JUNCTION').Count }
    Write-Host "  OK -> $csv  ($($archivos.Count) archivos, $totalMB MB)" -ForegroundColor Green
}

$g = @("# Índice general — consolidación AGENTES_WD", "", "Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "",
       "| Fuente | Origen | Archivos | MB | Sensibles | Junctions | Detalle |", "|---|---|---:|---:|---:|---:|---|")
foreach ($r in $resumen) { $g += "| $($r.Alias) | ``$($r.Origen)`` | $($r.Archivos) | $($r.MB) | $($r.Sensibles) | $($r.Junctions) | [md](./INDICE-$($r.Alias).md) · [csv](./INDICE-$($r.Alias).csv) |" }
Set-Content -LiteralPath (Join-Path $Indices 'INDICE-GENERAL.md') -Value $g -Encoding UTF8
$resumen | Format-Table -AutoSize
Write-Host "Índices en: $Indices" -ForegroundColor Green
