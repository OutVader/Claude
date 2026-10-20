<#
.SYNOPSIS
  adb simulado para las pruebas: hace de móvil sirviendo una carpeta local.
.DESCRIPTION
  La raíz del "móvil" (/) es la carpeta de la variable ADB_FALSO_RAIZ.
  Admite: version · devices · -s <serial> · pull [-a] <orígenes...> <destino> ·
          shell con: find RAIZ [-maxdepth 1] -type f -exec stat -c '%Y|%s|%n' {} + ·
          sha256sum RUTAS · rm -f RUTAS · if [ -d|-e RUTA ]; then echo X; else echo Y; fi
  Variables de entorno:
    ADB_FALSO_DISPOSITIVOS  lista "serial[:estado]" separada por comas (por defecto FALSO123:device;
                            '-' = ningún móvil)
    ADB_FALSO_FALLAR_PULL   regex: los archivos que casen se descargan a medias (fallo de tamaño)
    ADB_FALSO_FALLAR_RM     regex: los archivos que casen no se borran
    ADB_FALSO_FALLAR_FIND   si vale 1, find lista los archivos pero termina con error (lectura parcial)
    ADB_FALSO_ARGMAX        si vale 1, "find -exec ... {} +" se corta tras 2 archivos con "Argument list too long"
                            (como algunos Android en carpetas grandes); con "{} \;" lista todo
    ADB_FALSO_LOG           si existe, se anota cada llamada (para comprobar los lotes)
  Siempre termina con exit <código>, como un ejecutable.
#>
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version 2.0
$raiz = $env:ADB_FALSO_RAIZ
$a = [System.Collections.Generic.List[string]]@($args | ForEach-Object { [string]$_ })
if ($env:ADB_FALSO_LOG) { Add-Content -LiteralPath $env:ADB_FALSO_LOG -Value ($a -join ' ¦ ') -Encoding UTF8 }

function Get-Dispositivos {
    $txt = $env:ADB_FALSO_DISPOSITIVOS
    if ($null -eq $txt) { $txt = 'FALSO123:device' }
    if ($txt -eq '-') { return @() }
    return @($txt.Split(',') | Where-Object { $_ } | ForEach-Object {
            $p = $_.Split(':'); $estado = 'device'; if ($p.Count -gt 1) { $estado = $p[1] }
            [pscustomobject]@{ Serial = $p[0]; Estado = $estado }
        })
}

function ConvertTo-RutaLocal {
    param([string]$RutaMovil)
    if (-not $RutaMovil.StartsWith('/')) { return $null }
    $rel = $RutaMovil.TrimStart('/')
    if ($rel -eq '') { return $raiz }
    return [IO.Path]::Combine($raiz, $rel.Replace('/', [IO.Path]::DirectorySeparatorChar))
}

function Split-Sh {
    # Troceo mínimo de sh: comillas simples, \ fuera de comillas, ';' como palabra propia
    param([string]$Texto)
    $res = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $hay = $false; $enComilla = $false; $i = 0
    while ($i -lt $Texto.Length) {
        $ch = $Texto[$i]
        if ($enComilla) {
            if ($ch -eq "'") { $enComilla = $false } else { [void]$sb.Append($ch) }
        }
        elseif ($ch -eq "'") { $enComilla = $true; $hay = $true }
        elseif ($ch -eq '\' -and $i + 1 -lt $Texto.Length) { $i++; [void]$sb.Append($Texto[$i]); $hay = $true }
        elseif ($ch -eq ';') {
            if ($hay) { $res.Add($sb.ToString()); [void]$sb.Clear(); $hay = $false }
            $res.Add(';')
        }
        elseif ([char]::IsWhiteSpace($ch)) {
            if ($hay) { $res.Add($sb.ToString()); [void]$sb.Clear(); $hay = $false }
        }
        else { [void]$sb.Append($ch); $hay = $true }
        $i++
    }
    if ($hay) { $res.Add($sb.ToString()) }
    return , $res
}

function Invoke-Sh {
    param([string]$Comando)
    $t = Split-Sh $Comando
    $codigo = 0; $i = 0
    while ($i -lt $t.Count) {
        $w = $t[$i]
        if ($w -eq ';') { $i++; continue }
        # Sentencia hasta el siguiente ';' (salvo dentro de if ... fi)
        if ($w -eq 'if') {
            # if [ -X RUTA ] ; then echo A ; else echo B ; fi
            $op = $t[$i + 2]; $ruta = $t[$i + 3]
            $local = ConvertTo-RutaLocal $ruta
            $ok = $false
            if ($local) {
                if ($op -eq '-d') { $ok = [IO.Directory]::Exists($local) } else { $ok = [IO.File]::Exists($local) -or [IO.Directory]::Exists($local) }
            }
            $j = $i; while ($t[$j] -ne 'then') { $j++ }
            $si = $t[$j + 2]
            while ($t[$j] -ne 'else') { $j++ }
            $no = $t[$j + 2]
            while ($t[$j] -ne 'fi') { $j++ }
            if ($ok) { Write-Output $si } else { Write-Output $no }
            $i = $j + 1; continue
        }
        $sent = New-Object System.Collections.Generic.List[string]
        while ($i -lt $t.Count -and $t[$i] -ne ';') { $sent.Add($t[$i]); $i++ }
        switch ($sent[0]) {
            'find' {
                $base = ConvertTo-RutaLocal $sent[1]
                if (-not $base -or -not [IO.Directory]::Exists($base)) { Write-Error "find: $($sent[1]): No such file or directory"; $codigo = 1; break }
                $opcion = [IO.SearchOption]::AllDirectories
                if ($sent.Contains('-maxdepth')) { $opcion = [IO.SearchOption]::TopDirectoryOnly }
                $prefMovil = $sent[1].TrimEnd('/')
                $n = 0
                $conMas = ($sent[$sent.Count - 1] -eq '+')
                foreach ($f in [IO.Directory]::GetFiles($base, '*', $opcion)) {
                    if ($env:ADB_FALSO_ARGMAX -eq '1' -and $conMas -and $n -ge 2) { Write-Error 'find: exec stat: Argument list too long'; $codigo = 1; break }
                    $n++
                    $fi = New-Object IO.FileInfo $f
                    $rel = $f.Substring($base.Length).TrimStart([IO.Path]::DirectorySeparatorChar).Replace([IO.Path]::DirectorySeparatorChar, '/')
                    $seg = [DateTimeOffset]::new($fi.LastWriteTimeUtc).ToUnixTimeSeconds()
                    Write-Output ('{0}|{1}|{2}/{3}' -f $seg, $fi.Length, $prefMovil, $rel)
                }
                if ($env:ADB_FALSO_FALLAR_FIND -eq '1') { Write-Error "find: $($sent[1])/privado: Permission denied"; $codigo = 1 }
            }
            'sha256sum' {
                foreach ($r in ($sent | Select-Object -Skip 1)) {
                    $local = ConvertTo-RutaLocal $r
                    if ($local -and [IO.File]::Exists($local)) { Write-Output ('{0}  {1}' -f (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant(), $r) }
                    else { Write-Error "sha256sum: ${r}: No such file or directory"; $codigo = 1 }
                }
            }
            'rm' {
                foreach ($r in ($sent | Select-Object -Skip 1 | Where-Object { $_ -ne '-f' })) {
                    $local = ConvertTo-RutaLocal $r
                    if ($env:ADB_FALSO_FALLAR_RM -and $r -match $env:ADB_FALSO_FALLAR_RM) { Write-Error "rm: ${r}: Permission denied"; $codigo = 1; continue }
                    if ($local -and [IO.File]::Exists($local)) { [IO.File]::Delete($local) }
                }
            }
            default { Write-Error "sh: $($sent[0]): not found"; $codigo = 127 }
        }
    }
    $script:CodigoSh = $codigo
}

# ---------------- principal ----------------
$serial = $null
if ($a.Count -ge 2 -and $a[0] -eq '-s') { $serial = $a[1]; $a.RemoveRange(0, 2) }
if ($a.Count -eq 0) { Write-Error 'adb: sin orden'; exit 1 }
$orden = $a[0]
if ($orden -eq 'version') { Write-Output 'Android Debug Bridge version 1.0.41 (adb-falso)'; exit 0 }
$devs = @(Get-Dispositivos)
if ($orden -eq 'devices') {
    Write-Output 'List of devices attached'
    foreach ($d in $devs) { Write-Output ("{0}`t{1}" -f $d.Serial, $d.Estado) }
    Write-Output ''
    exit 0
}
$listos = @($devs | Where-Object { $_.Estado -eq 'device' })
if ($serial) {
    if (@($listos | Where-Object { $_.Serial -eq $serial }).Count -eq 0) { Write-Error "adb: device '$serial' not found"; exit 1 }
}
elseif ($listos.Count -eq 0) { Write-Error 'adb: no devices/emulators found'; exit 1 }
elseif ($listos.Count -gt 1) { Write-Error 'adb: more than one device/emulator'; exit 1 }

switch ($orden) {
    'shell' {
        $cmd = ($a | Select-Object -Skip 1) -join ' '
        $script:CodigoSh = 0
        Invoke-Sh $cmd
        exit $script:CodigoSh
    }
    'pull' {
        $resto = @($a | Select-Object -Skip 1)
        $conserva = $false
        if ($resto.Count -gt 0 -and $resto[0] -eq '-a') { $conserva = $true; $resto = @($resto | Select-Object -Skip 1) }
        if ($resto.Count -lt 2) { Write-Error 'adb: pull necesita origen y destino'; exit 1 }
        $dest = $resto[$resto.Count - 1]
        $origenes = @($resto[0..($resto.Count - 2)])
        if ($origenes.Count -gt 1 -and -not [IO.Directory]::Exists($dest)) { Write-Error "adb: error: target '$dest' is not a directory"; exit 1 }
        $rc = 0; $n = 0
        foreach ($o in $origenes) {
            $local = ConvertTo-RutaLocal $o
            if (-not $local -or -not [IO.File]::Exists($local)) { Write-Error "adb: error: remote object '$o' does not exist"; $rc = 1; continue }
            $final = $dest
            if ([IO.Directory]::Exists($dest)) { $final = [IO.Path]::Combine($dest, $o.Substring($o.LastIndexOf('/') + 1)) }
            $bytes = [IO.File]::ReadAllBytes($local)
            if ($env:ADB_FALSO_FALLAR_PULL -and $o -match $env:ADB_FALSO_FALLAR_PULL) {
                [IO.File]::WriteAllBytes($final, $bytes[0..([math]::Max(0, [int]($bytes.Length / 2) - 1))])
                Write-Error "adb: error: failed to copy '$o' to '$final': connection reset"; $rc = 1; continue
            }
            [IO.File]::WriteAllBytes($final, $bytes)
            if ($conserva) { [IO.File]::SetLastWriteTimeUtc($final, [IO.File]::GetLastWriteTimeUtc($local)) }
            $n++
        }
        Write-Output "${n} files pulled. 0 files skipped."
        exit $rc
    }
    default { Write-Error "adb: orden no soportada '$orden'"; exit 1 }
}
