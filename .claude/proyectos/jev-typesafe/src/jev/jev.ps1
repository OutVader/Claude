# JEV (TypeSafe) - cliente nucleo en PowerShell (compatible 5.1 y 7+). Sin modulos externos.
# Mismo comportamiento y ficheros que jev.py (jev_config.json, reglas.json, cache.json,
# estado.json, decisions.jsonl). Uso: jev.ps1 <subcomando> [opciones]
#   ping | noul | choice | score | route | hook | sesion | sync | panel |
#   reglas (listar|aprobar|revocar) <id> | diag | toggle <modulo> | on | off

$ErrorActionPreference = 'Stop'
$script:VERSION = '1.0.0'
$script:INV = [Globalization.CultureInfo]::InvariantCulture
$script:IC = [Text.RegularExpressions.RegexOptions]::IgnoreCase
$script:FMT = "yyyy-MM-dd HH:mm:ss'Z'"
$script:MAXLOG = 5MB
$script:LOTE = 20

# ------------------------------------------------------------------ utilidades

function Get-JevBase {
    if ($env:JEV_HOME) { return $env:JEV_HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return $HOME
}

function Get-JevRutas {
    $b = Get-JevBase
    $claude = Join-Path $b '.claude'
    $jev = Join-Path $claude 'jev'
    return @{
        base = $b; claude = $claude; jev = $jev
        config = (Join-Path $claude 'jev_config.json')
        reglas = (Join-Path $PSScriptRoot 'reglas.json')
        cache = (Join-Path $jev 'cache.json')
        estado = (Join-Path $jev 'estado.json')
        log = (Join-Path $jev 'decisions.jsonl')
        skills = (Join-Path $claude 'skills')
        plugins = (Join-Path $claude 'plugins')
        settings = (Join-Path $claude 'settings.json')
        keydir = (Join-Path (Join-Path $b '.config') 'jev')
    }
}

function Get-Ahora { return [DateTime]::UtcNow }
function Format-Iso([DateTime]$d) { return $d.ToString($script:FMT, $script:INV) }
function Read-Iso([string]$s) {
    if (-not $s) { return $null }
    try {
        return [DateTime]::ParseExact($s, $script:FMT, $script:INV,
            ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal))
    } catch { return $null }
}
function F2($v) { return ([double]$v).ToString('0.00', $script:INV) }

function ConvertTo-HT($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [DateTime]) { return (Format-Iso $o.ToUniversalTime()) }
    if ($o -is [System.Collections.IDictionary]) {
        $h = @{}; foreach ($k in $o.Keys) { $h[[string]$k] = ConvertTo-HT $o[$k] }; return $h
    }
    if ($o -is [PSCustomObject]) {
        $h = @{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-HT $p.Value }; return $h
    }
    if (($o -is [System.Collections.IEnumerable]) -and -not ($o -is [string])) {
        $l = New-Object System.Collections.ArrayList
        foreach ($x in $o) { [void]$l.Add((ConvertTo-HT $x)) }
        return , $l.ToArray()
    }
    return $o
}

function Read-JsonFile([string]$ruta, $defecto) {
    try {
        if (-not (Test-Path -LiteralPath $ruta)) { return $defecto }
        $txt = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
        if (-not $txt.Trim()) { return $defecto }
        return ConvertTo-HT ($txt | ConvertFrom-Json)
    } catch { return $defecto }
}

function ConvertTo-JsonC($o) { return (ConvertTo-Json -InputObject $o -Depth 20 -Compress) }

function Write-JsonFile([string]$ruta, $datos) {
    $dir = Split-Path -Parent $ruta
    if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Force -Path $dir) }
    $tmp = "$ruta.$PID.tmp"
    $txt = ConvertTo-Json -InputObject $datos -Depth 20
    [IO.File]::WriteAllText($tmp, $txt, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $ruta -Force
}

function Get-Val($h, [string]$k, $defecto) {
    if ($h -is [System.Collections.IDictionary] -and $h.Contains($k) -and $null -ne $h[$k]) { return $h[$k] }
    return $defecto
}

# ------------------------------------------------------------------ config

function Get-ConfigDef {
    return @{
        activo = $true; perfil = 'corporativo'; runtime = 'powershell'
        modelo = 'typesafe/jev-1.13'; endpoint = 'https://openrouter.ai/api/alpha/decisions'
        approve_threshold = 0.90; router_min_confidence = 0.75; timeout_s = 8
        proxy = ''; ca_bundle = ''
        sistema = @{ os = ''; distro = ''; init = ''; shell = '' }
        red = @{ modo = 'nuevo_y_sync'; sync_dias = 7; cortacircuitos_fallos = 2; cortacircuitos_min = 15 }
        cache = @{ ttl_dias = 30; promover_tras = 5; promover_min = 0.95 }
        mostrar_criterio = $true; redaccion = $true; dominios_internos = @()
        modulos = @{ router_manual = $true; permisos_shell = $true; panel = $true; permisos_read = $false
            sugeridor_auto = $false; triaje_logs = $false; check_commit = $false }
        rutas_excluidas = $null; instalado = ''   # null -> reglas.json:exclusiones_por_defecto
    }
}

function Merge-HT($def, $real) {
    if (-not ($def -is [System.Collections.IDictionary]) -or -not ($real -is [System.Collections.IDictionary])) {
        if ($null -ne $real) { return $real } else { return $def }
    }
    $out = @{}
    foreach ($k in $def.Keys) { $out[$k] = $def[$k] }
    foreach ($k in $real.Keys) {
        if ($def.Contains($k)) { $out[$k] = Merge-HT $def[$k] $real[$k] } else { $out[$k] = $real[$k] }
    }
    return $out
}

function Get-JevConfig {
    $r = Get-JevRutas
    $cfg = Merge-HT (Get-ConfigDef) (Read-JsonFile $r.config @{})
    $th = 0.90
    try { $th = [double]$cfg.approve_threshold } catch { }
    $cfg.approve_threshold = [Math]::Min([Math]::Max($th, 0.80), 1.0)   # nunca por debajo de 0.80
    return $cfg
}

function Get-JevReglas { return Read-JsonFile (Get-JevRutas).reglas $null }

# ------------------------------------------------------------------ key

function Get-JevKey {
    if ($env:OPENROUTER_API_KEY) { return $env:OPENROUTER_API_KEY.Trim() }
    $kd = (Get-JevRutas).keydir
    $dp = Join-Path $kd 'key.dpapi'
    try {
        if (Test-Path -LiteralPath $dp) {
            $ss = (Get-Content -LiteralPath $dp -Raw).Trim() | ConvertTo-SecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
            try { return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)).Trim() }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        }
    } catch { }
    $ef = Join-Path $kd 'env'
    try {
        if (Test-Path -LiteralPath $ef) {
            foreach ($l in [IO.File]::ReadAllLines($ef)) {
                if ($l.StartsWith('OPENROUTER_API_KEY=')) { return $l.Substring(19).Trim().Trim('"').Trim("'") }
            }
        }
    } catch { }
    return ''
}

# ------------------------------------------------------------------ log

function Write-JevLog($entrada) {
    try {
        $r = Get-JevRutas
        if (-not (Test-Path -LiteralPath $r.jev)) { [void](New-Item -ItemType Directory -Force -Path $r.jev) }
        if ((Test-Path -LiteralPath $r.log) -and ((Get-Item -LiteralPath $r.log).Length -gt $script:MAXLOG)) {
            Move-Item -LiteralPath $r.log -Destination ($r.log + '.1') -Force
        }
        $e = [ordered]@{ fecha = (Format-Iso (Get-Ahora)) }
        foreach ($k in $entrada.Keys) { if ($null -ne $entrada[$k]) { $e[$k] = $entrada[$k] } }
        [IO.File]::AppendAllText($r.log, (ConvertTo-JsonC $e) + "`n", (New-Object Text.UTF8Encoding($false)))
    } catch { }
}

# ------------------------------------------------------------------ red

function Invoke-Jev($cfg, $state, $preguntas, $timeoutS) {
    $key = Get-JevKey
    if (-not $key) { throw 'JEV:sin_key' }
    $body = ConvertTo-JsonC @{ model = $cfg.modelo; state = $state; questions = $preguntas }
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }
    if ($null -eq $timeoutS) { $timeoutS = [double]$cfg.timeout_s }
    $ms = [int][Math]::Max(1, [Math]::Round([double]$timeoutS * 1000))
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $req = [Net.HttpWebRequest][Net.WebRequest]::Create([string]$cfg.endpoint)
        $req.Method = 'POST'; $req.ContentType = 'application/json'
        $req.UserAgent = "jev-claude-code/$($script:VERSION)"
        $req.Headers.Add('Authorization', "Bearer $key")
        $req.Timeout = $ms; $req.ReadWriteTimeout = $ms
        if ($cfg.proxy) {
            $px = New-Object Net.WebProxy([string]$cfg.proxy)
            $px.UseDefaultCredentials = $true
            $req.Proxy = $px
        } elseif ($req.Proxy) {
            try { $req.Proxy.Credentials = [Net.CredentialCache]::DefaultCredentials } catch { }   # proxy corporativo NTLM/Kerberos
        }
        $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
        $resp = $req.GetResponse()
        try {
            if ([int]$resp.StatusCode -ne 200) { throw ('JEV:http_' + [int]$resp.StatusCode) }
            $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd()
        } finally { $resp.Close() }
    } catch {
        $m = $_.Exception.Message
        if ($m -like 'JEV:*') { throw }
        $ex = $_.Exception
        while ($ex -and -not ($ex -is [Net.WebException]) -and $ex.InnerException) { $ex = $ex.InnerException }
        if ($ex -is [Net.WebException]) {
            if ($ex.Response) { throw ('JEV:http_' + [int]$ex.Response.StatusCode) }
            if ($ex.Status -eq [Net.WebExceptionStatus]::Timeout) { throw 'JEV:timeout' }
            throw ('JEV:red: ' + $ex.Status)
        }
        if ($sw.ElapsedMilliseconds -ge $ms) { throw 'JEV:timeout' }
        throw ('JEV:error: ' + $_.Exception.GetType().Name)
    }
    $lat = [int]$sw.ElapsedMilliseconds
    try { $d = ConvertTo-HT ($txt | ConvertFrom-Json) } catch { throw 'JEV:json_ilegible' }
    if (-not ($d -is [System.Collections.IDictionary]) -or -not ($d['answers'] -is [System.Collections.IDictionary])) {
        throw 'JEV:respuesta_sin_answers'
    }
    return @{ r = $d; lat = $lat }
}

function Get-Prob($resp, [string]$qid) {
    try { $v = $resp.answers[$qid]['noul'] } catch { throw "JEV:noul_ausente:$qid" }
    if ($null -eq $v -or -not (($v -is [double]) -or ($v -is [int]) -or ($v -is [long]) -or ($v -is [decimal]))) {
        throw "JEV:noul_ausente:$qid"
    }
    $v = [double]$v
    if ([double]::IsNaN($v) -or $v -lt 0 -or $v -gt 1) { throw "JEV:noul_fuera_de_rango:$qid" }
    return $v
}

function Get-Coste($resp) {
    try { return [double](Get-Val (Get-Val $resp 'usage' @{}) 'cost' 0) } catch { return 0.0 }
}

function Get-ErrMsg($err) {
    $m = $err.Exception.Message
    if ($m -like 'JEV:*') { return $m.Substring(4) }
    return 'error: ' + $err.Exception.GetType().Name
}

# ------------------------------------------------------------------ estado / cortacircuitos

function Get-Estado {
    return Merge-HT @{ fallos = 0; suspendido_hasta = ''; ultimo_sync = ''; pendientes = @{} } (Read-JsonFile (Get-JevRutas).estado @{})
}
function Save-Estado($e) { try { Write-JsonFile (Get-JevRutas).estado $e } catch { } }
function Test-Suspendido($est) {
    $t = Read-Iso ([string]$est.suspendido_hasta)
    return ($null -ne $t -and $t -gt (Get-Ahora))
}
function Add-Fallo($cfg, $est) {
    $est.fallos = [int]$est.fallos + 1
    if ($est.fallos -ge [int]$cfg.red.cortacircuitos_fallos) {
        $est.suspendido_hasta = Format-Iso ((Get-Ahora).AddMinutes([int]$cfg.red.cortacircuitos_min))
        $est.fallos = 0
    }
    Save-Estado $est
}
function Add-Exito($est) {
    if ([int]$est.fallos -or $est.suspendido_hasta) { $est.fallos = 0; $est.suspendido_hasta = ''; Save-Estado $est }
}

# ------------------------------------------------------------------ analisis de comandos

function Split-Comando([string]$cmd) {
    $segs = New-Object System.Collections.ArrayList
    $cur = New-Object Text.StringBuilder
    $q = [char]0; $i = 0
    while ($i -lt $cmd.Length) {
        $c = $cmd[$i]
        if ($q -ne [char]0) {
            [void]$cur.Append($c); if ($c -eq $q) { $q = [char]0 }; $i++; continue
        }
        if ($c -eq '"' -or $c -eq "'") { $q = $c; [void]$cur.Append($c); $i++; continue }
        if ($c -eq '\' -and ($i + 1) -lt $cmd.Length -and ';&|(){}'.Contains([string]$cmd[$i + 1])) {
            [void]$cur.Append($cmd[$i + 1]); $i += 2; continue
        }
        if (($i + 1) -lt $cmd.Length) {
            $dos = $cmd.Substring($i, 2)
            if ($dos -eq '&&' -or $dos -eq '||') { [void]$segs.Add($cur.ToString()); [void]$cur.Clear(); $i += 2; continue }
        }
        if (";|&(){}`n".Contains([string]$c)) { [void]$segs.Add($cur.ToString()); [void]$cur.Clear(); $i++; continue }
        [void]$cur.Append($c); $i++
    }
    [void]$segs.Add($cur.ToString())
    $out = @(); foreach ($s in $segs) { $t = $s.Trim(); if ($t) { $out += $t } }
    return , $out
}

$script:RE_TOKEN = '"(?:[^"\\]|\\.)*"|''[^'']*''|\S+'
$script:RE_ASIG = '^[A-Za-z_][A-Za-z0-9_]*='
$script:RE_BIN = '^(/usr/local/s?bin/|/usr/s?bin/|/s?bin/|[a-z]:[\\/]windows[\\/]system32[\\/](windowspowershell[\\/]v1\.0[\\/])?)'
$script:ENVOLT = @('env', 'nohup', 'command', 'builtin', 'time', 'nice', 'stdbuf', 'ionice', 'timeout')

function Get-Tokens([string]$s) {
    $l = @(); foreach ($m in [regex]::Matches($s, $script:RE_TOKEN)) { $l += $m.Value }; return , $l
}

function Get-Normalizado([string]$seg) {
    $t = New-Object System.Collections.ArrayList
    $t.AddRange([object[]](Get-Tokens $seg))
    while ($t.Count -gt 0) {
        $t0 = [string]$t[0]
        if ($t0 -match $script:RE_ASIG) { $t.RemoveAt(0); continue }
        $m = [regex]::Match($t0, $script:RE_BIN, $script:IC)
        if ($m.Success -and $t0.Length -gt $m.Length) { $t[0] = $t0.Substring($m.Length); continue }
        $b = $t0.ToLowerInvariant()
        if ($b.EndsWith('.exe') -and -not $b.Contains('/') -and -not $b.Contains('\')) { $t[0] = $t0.Substring(0, $t0.Length - 4); continue }
        if ($script:ENVOLT -contains $b) {
            $t.RemoveAt(0)
            while ($t.Count -gt 0 -and (([string]$t[0]).StartsWith('-') -or ([string]$t[0] -match $script:RE_ASIG))) {
                $opt = [string]$t[0]; $t.RemoveAt(0)
                if (@('nice', 'ionice', 'timeout', 'stdbuf') -contains $b -and @('-n', '-c', '-s', '-k', '--signal', '--kill-after') -contains $opt) {
                    if ($t.Count -gt 0) { $t.RemoveAt(0) }
                }
            }
            if ($b -eq 'timeout' -and $t.Count -gt 0 -and ([string]$t[0] -match '^\d+(\.\d+)?[smhd]?$')) { $t.RemoveAt(0) }
            continue
        }
        break
    }
    return ($t -join ' ')
}

function Get-Limpia([string]$p) { return $p.Trim('"').Trim("'") }

function Get-RutaNorm([string]$p, [string]$cwd, [string]$hdir) {
    $p = (Get-Limpia $p).Replace('\', '/')
    $pl = $p.ToLowerInvariant()
    if ($pl.StartsWith('~')) { $p = $hdir.Replace('\', '/') + $p.Substring(1) }
    elseif ($pl.StartsWith('$env:userprofile') -or $pl.StartsWith('$home')) {
        $i = $p.IndexOf('/'); if ($i -ge 0) { $p = $hdir.Replace('\', '/') + $p.Substring($i) } else { $p = $hdir }
    }
    elseif ($pl.StartsWith('$') -or $pl.StartsWith('%')) { return $null }
    elseif (-not (($pl -match '^[a-z]:/') -or $pl.StartsWith('/'))) { $p = $cwd.Replace('\', '/').TrimEnd('/') + '/' + $p }
    $partes = New-Object System.Collections.ArrayList
    foreach ($x in $p.Split('/')) {
        if ($x -eq '' -or $x -eq '.') { continue }
        if ($x -eq '..') { if ($partes.Count -gt 0) { $partes.RemoveAt($partes.Count - 1) }; continue }
        [void]$partes.Add($x)
    }
    $pref = '/'
    if ($partes.Count -gt 0 -and ([string]$partes[0] -match '^[a-z]:$')) { $pref = '' }
    return ($pref + ($partes -join '/')).ToLowerInvariant()
}

function Test-Rutaish([string]$t) {
    $t = Get-Limpia $t
    return (($t -match '^([a-z]:[\\/]|\\\\|/|~|\.{1,2}[\\/]|\.\.$|\$env:|\$home|%)') -or $t.Contains('/') -or $t.Contains('\'))
}

function Test-Dentro([string]$p, [string]$cwd, [string]$hdir) {
    $n = Get-RutaNorm $p $cwd $hdir
    if ($null -eq $n) { return $false }
    $c = Get-RutaNorm $cwd $cwd $hdir
    return ($n -eq $c -or $n.StartsWith($c.TrimEnd('/') + '/'))
}

$script:RE_REDIR = '(?:\d|&|\*)?>>?\s*("[^"]*"|''[^'']*''|[^\s;|&]+)'

function Get-RedirFuera([string]$seg, [string]$cwd, [string]$hdir) {
    foreach ($m in [regex]::Matches($seg, $script:RE_REDIR)) {
        $d = Get-Limpia $m.Groups[1].Value
        if ($d.StartsWith('&') -or @('/dev/null', '$null', 'nul', 'null', '/dev/stderr', '/dev/stdout') -contains $d.ToLowerInvariant()) { continue }
        if (-not (Test-Dentro $d $cwd $hdir)) { return $d }
    }
    return $null
}

function Out-Txt([string]$s) { [Console]::Out.WriteLine($s) }

function Test-Re([string]$s, [string]$re) { return [regex]::IsMatch($s, $re, $script:IC) }

function Test-Estatico([string]$cmd, [string]$cwd, $cfg, $reglas) {
    $home_ = Get-JevBase
    foreach ($g in @('global', 'secretos', 'rutas_sensibles')) {
        foreach ($r in @($reglas[$g])) { if ($r -and (Test-Re $cmd $r.re)) { return @($r.id, $r.motivo) } }
    }
    $excl = $cfg.rutas_excluidas
    if ($null -eq $excl) { $excl = $reglas.exclusiones_por_defecto }
    foreach ($rx in @($excl)) {
        if (-not $rx) { continue }
        try { if ((Test-Re $cmd $rx) -or (Test-Re $cwd $rx)) { return @('excluida', 'ruta/patrón excluido por configuración') } }
        catch { return @('excluida', 'regla de exclusión inválida (fail-closed)') }
    }
    $segs = Split-Comando $cmd
    if ($segs.Count -eq 0) { return @('vacio', 'comando vacío') }
    $so = [string](Get-Val $cfg.sistema 'os' ''); $init = [string](Get-Val $cfg.sistema 'init' '')
    $clave = $init; if ($so -eq 'windows') { $clave = 'windows' }
    $coh = Get-Val $reglas 'coherencia' @{}
    $grupos = @($reglas.segmento)
    if ($cfg.perfil -eq 'corporativo') { $grupos += @($reglas.corporativo) }
    foreach ($crudo in $segs) {
        $seg = Get-Normalizado $crudo
        if (-not $seg) { continue }
        if ($clave -and $coh.Contains($clave) -and (Test-Re $seg $coh[$clave].re)) { return @("coherencia_$clave", $coh[$clave].motivo) }
        foreach ($r in $grupos) { if (Test-Re $seg $r.re) { return @($r.id, $r.motivo) } }
        $f = Get-RedirFuera $crudo $cwd $home_
        if ($f) { return @('redireccion_fuera', 'redirección fuera del proyecto: ' + (Get-Redactado $f $cfg $reglas)) }
        if (Test-Re $seg $reglas.escritura) {
            $tk = Get-Tokens $seg
            for ($i = 1; $i -lt $tk.Count; $i++) {
                $t = [string]$tk[$i]
                if ($t.StartsWith('-') -or (-not (Test-Rutaish $t) -and -not $t.Contains('..'))) { continue }
                if (-not (Test-Dentro $t $cwd $home_)) { return @('escritura_fuera', 'escribe fuera del proyecto') }
            }
        }
    }
    return $null
}

# ------------------------------------------------------------------ redaccion / patron

function Get-Redactado([string]$texto, $cfg, $reglas) {
    if (-not $cfg.redaccion -or -not $texto) { return $texto }
    $s = $texto
    $doms = @($cfg.dominios_internos | Where-Object { $_ })
    foreach ($v in @($env:USERDNSDOMAIN, $env:USERDOMAIN)) { if ($v -and $v.Length -gt 2) { $doms += $v } }
    foreach ($r in @($reglas.redaccion)) {
        $s = [regex]::Replace($s, $r.re, ([string]$r.rep).Replace('{1}', '$1'), $script:IC)
    }
    foreach ($d in ($doms | Sort-Object -Property Length -Descending -Unique)) {
        $s = [regex]::Replace($s, '[a-z0-9.-]*' + [regex]::Escape($d), '<DOM>', $script:IC)
    }
    foreach ($par in @(@($env:USERNAME, '<USR>'), @($env:USER, '<USR>'), @($env:COMPUTERNAME, '<PC>'))) {
        if ($par[0] -and $par[0].Length -gt 2) { $s = [regex]::Replace($s, '\b' + [regex]::Escape($par[0]) + '\b', $par[1], $script:IC) }
    }
    return $s
}

function Get-Patron([string]$cmd, [string]$cwd) {
    $home_ = Get-JevBase
    $partes = @()
    foreach ($crudo in (Split-Comando $cmd)) {
        $tk = Get-Tokens (Get-Normalizado $crudo)
        if ($tk.Count -eq 0) { continue }
        $sal = @(([string]$tk[0]).ToLowerInvariant())
        for ($i = 1; $i -lt $tk.Count; $i++) {
            $t = [string]$tk[$i]; $tl = $t.ToLowerInvariant()
            if ($t -match '^\d?>>?$') { $sal += $t }
            elseif ($tl.StartsWith('-')) {
                $k = $tl.Split('=')[0]; if ($tl.Contains('=')) { $k += '=<V>' }; $sal += $k
            }
            elseif ($tl -match '^/[a-z?]{1,2}$') { $sal += $tl }
            elseif ($t.StartsWith('"') -or $t.StartsWith("'")) { $sal += '<TXT>' }
            elseif ($t -match '^\d+(\.\d+)?$') { $sal += '<N>' }
            elseif ((Test-Rutaish $t) -or $t.Contains('..')) {
                if (Test-Dentro $t $cwd $home_) { $sal += '<RUTA_INT>' } else { $sal += '<RUTA_EXT>' }
            }
            elseif ($i -eq 1 -and ($tl -cmatch '^[a-z][a-z0-9-]*$')) { $sal += $tl }
            else { $sal += '<ARG>' }
        }
        $partes += ($sal -join ' ')
    }
    return ($partes -join ' ; ')
}

function Get-Fnv([string]$s) {
    [uint64]$h = 2166136261
    $mask = [uint64]4294967295
    foreach ($b in [Text.Encoding]::UTF8.GetBytes($s)) {
        $h = $h -bxor [uint64]$b
        $h = ($h * [uint64]16777619) -band $mask
    }
    return $h.ToString('x8')
}

# ------------------------------------------------------------------ cache

function Get-Cache { return Read-JsonFile (Get-JevRutas).cache @{} }
function Save-Cache($c) { try { Write-JsonFile (Get-JevRutas).cache $c } catch { } }

function Find-Cache($cfg, $cache, [string]$pat) {
    if (-not $cache.Contains($pat)) { return $null }
    $e = $cache[$pat]
    if ($e.estado -eq 'revocada') { return $null }
    if ($e.estado -eq 'regla') { return $e }
    $f = Read-Iso ([string]$e.fecha)
    if ($null -eq $f -or ((Get-Ahora) - $f).TotalDays -gt [int]$cfg.cache.ttl_dias) { return $null }
    return $e
}

function Update-Cache($cfg, $cache, [string]$pat, [double]$p, [string]$ejemplo, [bool]$aprobado, [string]$modelo) {
    if ($cache.Contains($pat)) { $e = $cache[$pat] } else { $e = @{ id = (Get-Fnv $pat); n_visto = 0; n_aprobado = 0; estado = 'cache' } }
    $e.reversible = [Math]::Round($p, 4); $e.fecha = Format-Iso (Get-Ahora); $e.modelo = $modelo
    if ($ejemplo.Length -gt 300) { $ejemplo = $ejemplo.Substring(0, 300) }
    $e.ejemplo = $ejemplo
    $e.n_visto = [int]$e.n_visto + 1
    if ($aprobado) { $e.n_aprobado = [int]$e.n_aprobado + 1 }
    $pm = [double]$cfg.cache.promover_min
    if ($e.estado -eq 'cache' -and [int]$e.n_aprobado -ge [int]$cfg.cache.promover_tras -and $p -ge $pm) { $e.estado = 'propuesta' }
    if ($e.estado -eq 'propuesta' -and $p -lt $pm) { $e.estado = 'cache' }
    $cache[$pat] = $e
}

# ------------------------------------------------------------------ preguntas

function New-QReversible {
    return @{ type = 'noul'
        instructions = 'Cada comando de `commands` solo lee o cambia ficheros dentro de `project` y puede deshacerse con git o repitiéndolo. No publica, no despliega, no borra fuera del proyecto, no cambia la configuración del sistema ni envía datos a un servicio de red. Los marcadores entre <> son datos redactados por privacidad.'
        criteria = @{ 'true' = 'Todos los comandos son locales al proyecto, reversibles e inocuos.'
            'false' = 'Algún comando actúa fuera del proyecto, es irreversible, cambia el sistema o usa la red.' } }
}
function New-QTarea {
    return @{ type = 'noul'; instructions = 'Ejecutar `commands` es un siguiente paso razonable hacia `task`.'
        criteria = @{ 'true' = 'Los comandos encajan con la tarea descrita.'; 'false' = 'Los comandos no tienen relación clara con la tarea o la exceden.' } }
}
function Get-SistemaState($cfg) {
    $s = $cfg.sistema
    return @{ os = (Get-Val $s 'os' ''); distro = (Get-Val $s 'distro' ''); init = (Get-Val $s 'init' ''); shell = (Get-Val $s 'shell' '') }
}
function Get-Corto([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

# ------------------------------------------------------------------ hook PermissionRequest

function Set-Utf8Consola {
    try { [Console]::InputEncoding = New-Object Text.UTF8Encoding($false) } catch { }
    try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false) } catch { }
}

function Write-Salida($cfg, [bool]$permitir, [string]$mensaje) {
    $out = @{}
    if ($cfg.mostrar_criterio -and $mensaje) { $out.systemMessage = $mensaje }
    if ($permitir) { $out.hookSpecificOutput = @{ hookEventName = 'PermissionRequest'; decision = @{ behavior = 'allow' } } }
    if ($out.Count -gt 0) { [Console]::Out.Write((ConvertTo-JsonC $out)); [Console]::Out.Flush() }
}

function Invoke-Hook([string[]]$opts) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $ev = ConvertTo-HT ([Console]::In.ReadToEnd() | ConvertFrom-Json) } catch { return }
    if (-not ($ev -is [System.Collections.IDictionary])) { return }
    $cfg = Get-JevConfig
    if (-not $cfg.activo -or -not $cfg.modulos.permisos_shell) { return }
    $to = Get-Opt $opts '--timeout' $null
    if ($to) { $cfg.timeout_s = [double]::Parse($to, $script:INV) }
    $reglas = Get-JevReglas
    if (-not $reglas) { Write-JevLog @{ modulo = 'permisos'; origen = 'error'; error = 'reglas.json ilegible' }; return }
    $herr = [string](Get-Val $ev 'tool_name' '')
    if (@('Bash', 'PowerShell') -notcontains $herr) { return }
    $ti = Get-Val $ev 'tool_input' @{}
    $cmd = [string](Get-Val $ti 'command' ''); $desc = [string](Get-Val $ti 'description' '')
    $cwd = [string](Get-Val $ev 'cwd' (Get-Location).Path)
    if (-not $cmd.Trim()) { return }
    $base = @{ modulo = 'permisos'; herramienta = $herr }
    function L($extra) { $h = @{}; foreach ($k in $base.Keys) { $h[$k] = $base[$k] }; foreach ($k in $extra.Keys) { $h[$k] = $extra[$k] }; Write-JevLog $h }

    # 1) Lista estatica: frontera de seguridad
    $est = Test-Estatico $cmd $cwd $cfg $reglas
    if ($est) {
        L @{ origen = 'estatico'; regla = $est[0]; motivo = $est[1]; decision = 'ask'; comando = (Get-Corto (Get-Redactado $cmd $cfg $reglas) 300) }
        Write-Salida $cfg $false ('[JEV] aviso normal · estático: ' + $est[1]); return
    }
    $red = Get-Corto (Get-Redactado $cmd $cfg $reglas) 300
    $pat = Get-Patron $cmd $cwd
    $th = [double]$cfg.approve_threshold
    $modo = [string]$cfg.red.modo
    # 2) Cache de criterio (local-first)
    $cache = Get-Cache
    if ($modo -ne 'online') {
        $e = Find-Cache $cfg $cache $pat
        if ($e) {
            if ($e.estado -eq 'regla') {
                L @{ origen = 'regla'; patron = $pat; pid = $e.id; decision = 'allow'; comando = $red }
                Write-Salida $cfg $true ("[JEV] permitido · regla local $($e.id) · " + (Get-Corto $pat 80)); return
            }
            $p = [double]$e.reversible; $ok = $p -ge $th
            $dec = 'ask'; if ($ok) { $dec = 'allow' }
            L @{ origen = 'cache'; patron = $pat; pid = $e.id; respuestas = @{ reversible = $p }; decision = $dec; comando = $red }
            $txt = 'aviso normal'; $cola = ' (< ' + (F2 $th) + ')'; if ($ok) { $txt = 'permitido'; $cola = '' }
            Write-Salida $cfg $ok ("[JEV] $txt · caché $($e.id) · reversible " + (F2 $p) + $cola + ' · ' + (Get-Corto ([string]$e.fecha) 10)); return
        }
    }
    if ($modo -eq 'solo_sync') {
        $estado = Get-Estado; $estado.pendientes[$pat] = $red; Save-Estado $estado
        L @{ origen = 'cola'; patron = $pat; decision = 'ask'; comando = $red }
        Write-Salida $cfg $false '[JEV] aviso normal · patrón nuevo en cola para el próximo sync'; return
    }
    # 3) Consulta a JEV (fail-closed)
    $estado = Get-Estado
    if (Test-Suspendido $estado) { L @{ origen = 'error'; error = 'cortacircuitos'; patron = $pat; decision = 'ask' }; return }
    $cmds = @(); foreach ($s in (Split-Comando $cmd)) { $cmds += (Get-Redactado $s $cfg $reglas) }
    $state = @{ commands = $cmds; project = (Get-Redactado $cwd $cfg $reglas); system = (Get-SistemaState $cfg) }
    $preg = @{ reversible = (New-QReversible) }
    if ($desc.Trim()) { $state.task = Get-Corto (Get-Redactado $desc $cfg $reglas) 500; $preg.serves_task = New-QTarea }
    try {
        $res = Invoke-Jev $cfg $state $preg $null
        $ps = @{}; foreach ($q in $preg.Keys) { $ps[$q] = Get-Prob $res.r $q }
    } catch {
        $m = Get-ErrMsg $_
        if ($m -ne 'sin_key') { Add-Fallo $cfg $estado }
        L @{ origen = 'error'; error = $m; patron = $pat; decision = 'ask'; latencia_ms = [int]$sw.ElapsedMilliseconds }
        return
    }
    Add-Exito $estado
    $ok = $true; foreach ($v in $ps.Values) { if ($v -lt $th) { $ok = $false } }
    $modelo = [string](Get-Val $res.r 'model' '')
    Update-Cache $cfg $cache $pat $ps.reversible $red $ok $modelo
    Save-Cache $cache
    $dec = 'ask'; if ($ok) { $dec = 'allow' }
    L @{ origen = 'jev'; patron = $pat; pid = (Get-Fnv $pat); respuestas = $ps; decision = $dec; id = (Get-Val $res.r 'id' ''); modelo = $modelo
        latencia_ms = $res.lat; coste = (Get-Coste $res.r); comando = $red }
    $det = 'reversible ' + (F2 $ps.reversible)
    if ($ps.Contains('serves_task')) { $det += ' · tarea ' + (F2 $ps.serves_task) }
    $txt = 'aviso normal'; $cola = ' (umbral ' + (F2 $th) + ')'; if ($ok) { $txt = 'permitido'; $cola = '' }
    Write-Salida $cfg $ok ("[JEV] $txt · jev · $det$cola · $($res.lat) ms")
}

# ------------------------------------------------------------------ sync por lotes

function Invoke-Sync([bool]$todo, [bool]$silencioso) {
    $cfg = Get-JevConfig; $reglas = Get-JevReglas; if (-not $reglas) { $reglas = @{} }
    $estado = Get-Estado
    if (Test-Suspendido $estado) { if (-not $silencioso) { Out-Txt "JEV suspendido por cortacircuitos hasta $($estado.suspendido_hasta)" }; return $null }
    $cache = Get-Cache
    $limite = (Get-Ahora).AddDays(-[int]$cfg.red.sync_dias)
    $trabajo = [ordered]@{}
    foreach ($k in @($estado.pendientes.Keys)) { $trabajo[$k] = $estado.pendientes[$k] }
    foreach ($k in @($cache.Keys)) {
        $e = $cache[$k]
        if (@('regla', 'revocada') -contains $e.estado) { continue }
        $f = Read-Iso ([string]$e.fecha)
        if ($todo -or $null -eq $f -or $f -lt $limite) { $trabajo[$k] = [string](Get-Val $e 'ejemplo' $k) }
    }
    if ($trabajo.Count -eq 0) {
        $estado.ultimo_sync = Format-Iso (Get-Ahora); Save-Estado $estado
        if (-not $silencioso) { Out-Txt 'Sync: nada que revalidar.' }; return $null
    }
    $items = @($trabajo.Keys)
    $hechos = 0; $coste = 0.0; $npet = 0
    for ($i = 0; $i -lt $items.Count; $i += $script:LOTE) {
        $lote = @($items[$i..([Math]::Min($i + $script:LOTE, $items.Count) - 1)])
        $cmds = @{}; $preg = @{}
        for ($j = 0; $j -lt $lote.Count; $j++) {
            $cid = "c$j"
            $cmds[$cid] = Get-Redactado ([string]$trabajo[$lote[$j]]) $cfg $reglas
            $q = New-QReversible
            $q.instructions = $q.instructions.Replace('Cada comando de `commands`', "El comando ``commands.$cid``")
            $preg[$cid] = $q
        }
        $state = @{ commands = $cmds; project = 'directorio de trabajo del usuario'; system = (Get-SistemaState $cfg) }
        try { $res = Invoke-Jev $cfg $state $preg ([Math]::Max([double]$cfg.timeout_s, 15)) }
        catch {
            $m = Get-ErrMsg $_; Add-Fallo $cfg $estado
            Write-JevLog @{ modulo = 'sync'; origen = 'error'; error = $m }
            if (-not $silencioso) { Out-Txt "Sync interrumpido: $m" }; break
        }
        $npet++; $coste += Get-Coste $res.r
        for ($j = 0; $j -lt $lote.Count; $j++) {
            $pat = $lote[$j]
            try { $p = Get-Prob $res.r "c$j" } catch { continue }
            $ap = $p -ge [double]$cfg.approve_threshold
            Update-Cache $cfg $cache $pat $p ([string]$trabajo[$pat]) $ap ([string](Get-Val $res.r 'model' ''))
            $cache[$pat].n_visto = [int]$cache[$pat].n_visto - 1
            if ($ap) { $cache[$pat].n_aprobado = [int]$cache[$pat].n_aprobado - 1 }
            if ($estado.pendientes.Contains($pat)) { $estado.pendientes.Remove($pat) }
            $hechos++
        }
        Write-JevLog @{ modulo = 'sync'; origen = 'jev'; id = (Get-Val $res.r 'id' ''); modelo = (Get-Val $res.r 'model' ''); latencia_ms = $res.lat; coste = (Get-Coste $res.r); patrones = $lote.Count }
    }
    Save-Cache $cache
    $nuevo = Get-Estado
    $nuevo.pendientes = $estado.pendientes; $nuevo.ultimo_sync = Format-Iso (Get-Ahora)
    if ($npet -gt 0) { $nuevo.fallos = 0; $nuevo.suspendido_hasta = '' }
    Save-Estado $nuevo
    $msg = "Sync JEV: $hechos patrones revalidados en $npet petición(es), coste " + ([double]$coste).ToString('0.000000', $script:INV) + ' $'
    if (-not $silencioso) { Out-Txt $msg }
    return $msg
}

function Invoke-Sesion {
    try { [void][Console]::In.ReadToEnd() } catch { }
    try {
        $cfg = Get-JevConfig
        if (-not $cfg.activo -or $cfg.red.modo -eq 'online' -or -not (Get-JevKey)) { return }
        $est = Get-Estado
        $u = Read-Iso ([string]$est.ultimo_sync)
        if ($u -and ((Get-Ahora) - $u).TotalDays -lt [int]$cfg.red.sync_dias) { return }
        $msg = Invoke-Sync $false $true
        if ($msg -and $cfg.mostrar_criterio) { [Console]::Out.Write((ConvertTo-JsonC @{ systemMessage = "[JEV] $msg" })) }
    } catch { }
}

# ------------------------------------------------------------------ primitivas CLI

function Get-Opt([string[]]$opts, [string]$nombre, $defecto) {
    for ($i = 0; $i -lt $opts.Count; $i++) {
        if ($opts[$i] -eq $nombre -and ($i + 1) -lt $opts.Count) { return $opts[$i + 1] }
        if ($opts[$i].StartsWith("$nombre=")) { return $opts[$i].Substring($nombre.Length + 1) }
    }
    return $defecto
}
function Test-Flag([string[]]$opts, [string]$nombre) { return ($opts -contains $nombre) }

function Read-State([string]$v) {
    if ($v.StartsWith('@')) { $v = [IO.File]::ReadAllText($v.Substring(1), [Text.Encoding]::UTF8) }
    try { $o = ConvertTo-HT ($v | ConvertFrom-Json); if ($o -is [System.Collections.IDictionary]) { return $o } } catch { }
    return @{ texto = $v }
}

function Invoke-Primitiva([string]$tipo, $state, $pregunta, [string]$modulo, $timeout) {
    $cfg = Get-JevConfig
    try {
        $res = Invoke-Jev $cfg $state @{ q = $pregunta } $timeout
        $a = $res.r.answers['q']
        if ($tipo -eq 'noul') { $ans = Get-Prob $res.r 'q'; $conf = $null }
        elseif ($tipo -eq 'choice') { $ans = [string]$a.choice; $conf = [double]$a.confidence }
        else { $ans = [double]$a.score; $conf = [double]$a.confidence }
        $out = [ordered]@{ ok = $true; answer = $ans; confidence = $conf; latency_ms = $res.lat; cost = (Get-Coste $res.r)
            id = (Get-Val $res.r 'id' ''); model = (Get-Val $res.r 'model' '') }
        if ($tipo -ne 'noul') { $out.probabilities = $a.probabilities }
    } catch {
        $out = [ordered]@{ ok = $false; error = (Get-ErrMsg $_); answer = $null; confidence = $null; latency_ms = $null; cost = 0; id = $null; model = $null }
    }
    $o = 'error'; if ($out.ok) { $o = 'jev' }
    Write-JevLog @{ modulo = $modulo; origen = $o; tipo = $tipo; respuesta = $out.answer; confianza = $out.confidence; id = $out.id
        modelo = $out.model; latencia_ms = $out.latency_ms; coste = $out.cost; error = $out['error'] }
    return $out
}

function Invoke-CmdPrimitiva([string]$tipo, [string[]]$opts) {
    $state = Read-State (Get-Opt $opts '--state' '')
    $ins = Get-Opt $opts '--instructions' ''
    if ($tipo -eq 'noul') {
        $q = @{ type = 'noul'; instructions = $ins; criteria = @{ 'true' = (Get-Opt $opts '--true' 'Sí.'); 'false' = (Get-Opt $opts '--false' 'No.') } }
    } else {
        $q = @{ type = $tipo; instructions = $ins; criteria = (ConvertTo-HT ((Get-Opt $opts '--criteria' '{}') | ConvertFrom-Json)) }
    }
    $to = Get-Opt $opts '--timeout' $null; if ($to) { $to = [double]::Parse($to, $script:INV) }
    $out = Invoke-Primitiva $tipo $state $q 'cli' $to
    Out-Txt (ConvertTo-JsonC $out)
    if ($out.ok) { return 0 } else { return 1 }
}

function Invoke-Ping([string[]]$opts) {
    $to = Get-Opt $opts '--timeout' $null; if ($to) { $to = [double]::Parse($to, $script:INV) }
    $q = @{ type = 'noul'; instructions = 'El texto de `texto` es la palabra ping.'; criteria = @{ 'true' = 'Es la palabra ping.'; 'false' = 'No lo es.' } }
    $out = Invoke-Primitiva 'noul' @{ texto = 'ping' } $q 'ping' $to
    Out-Txt (ConvertTo-JsonC $out)
    if ($out.ok) { return 0 } else { return 1 }
}

# ------------------------------------------------------------------ router de skills

function Get-Frontmatter([string]$ruta) {
    try { $txt = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8) } catch { return $null }
    $m = [regex]::Match($txt, '^﻿?---\s*\r?\n([\s\S]*?)\r?\n---')
    if (-not $m.Success) { return $null }
    $d = @{}; $clave = $null
    foreach ($l in ($m.Groups[1].Value -split "\r?\n")) {
        $mm = [regex]::Match($l, '^([A-Za-z_-]+):\s*(.*)$')
        if ($mm.Success) {
            $clave = $mm.Groups[1].Value; $v = $mm.Groups[2].Value.Trim()
            if (@('>-', '>', '|', '|-') -contains $v) { $v = '' }
            $d[$clave] = $v.Trim('"').Trim("'")
        } elseif ($clave -and ($l.StartsWith(' ') -or $l.StartsWith("`t"))) { $d[$clave] = ($d[$clave] + ' ' + $l.Trim()).Trim() }
    }
    return $d
}

function Get-Skills([string]$cwd) {
    $r = Get-JevRutas
    $enc = [ordered]@{}
    $bases = @($r.skills); if ($cwd) { $bases += (Join-Path (Join-Path $cwd '.claude') 'skills') }
    foreach ($b in $bases) {
        if (-not (Test-Path -LiteralPath $b)) { continue }
        foreach ($d in (Get-ChildItem -LiteralPath $b -Directory | Sort-Object Name)) {
            $fm = Get-Frontmatter (Join-Path $d.FullName 'SKILL.md')
            if ($fm -and $fm.name -and -not $enc.Contains($fm.name)) { $enc[$fm.name] = [string](Get-Val $fm 'description' '') }
        }
    }
    $set = Read-JsonFile $r.settings @{}
    $act = @(); $ep = Get-Val $set 'enabledPlugins' @{}
    foreach ($k in $ep.Keys) { if ($ep[$k]) { $act += $k.Split('@')[0].ToLowerInvariant() } }
    if ($act.Count -gt 0 -and (Test-Path -LiteralPath $r.plugins)) {
        foreach ($f in (Get-ChildItem -LiteralPath $r.plugins -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue)) {
            $segs = $f.DirectoryName.ToLowerInvariant() -split '[\\/]'
            if (-not ($segs -contains 'skills')) { continue }
            $hit = $false; foreach ($a in $act) { if ($segs -contains $a) { $hit = $true } }
            if (-not $hit) { continue }
            $fm = Get-Frontmatter $f.FullName
            if ($fm -and $fm.name -and -not $enc.Contains($fm.name)) { $enc[$fm.name] = [string](Get-Val $fm 'description' '') }
        }
    }
    if ($enc.Contains('elige-skill')) { $enc.Remove('elige-skill') }
    return $enc
}

function Invoke-Route([string[]]$opts) {
    $cfg = Get-JevConfig; $reglas = Get-JevReglas; if (-not $reglas) { $reglas = @{} }
    $json = Test-Flag $opts '--json'
    $pet = (@($opts | Where-Object { $_ -ne '--json' }) -join ' ')
    $skills = Get-Skills (Get-Location).Path
    $crit = @{}; $mapa = @{}
    foreach ($n in $skills.Keys) {
        $k = [regex]::Replace($n.ToLowerInvariant(), '[^a-z0-9_-]', '_'); $k = Get-Corto $k 60
        $mapa[$k] = $n; $d = [string]$skills[$n]; if (-not $d) { $d = $n }
        $crit[$k] = Get-Corto $d 600
    }
    $crit['ninguna'] = 'Ningún skill encaja; lo resuelve el Sistema 2'
    $state = @{ peticion = (Get-Redactado $pet $cfg $reglas); sistema = (Get-SistemaState $cfg) }
    $q = @{ type = 'choice'; instructions = 'Elige el skill cuyo propósito mejor encaja con `peticion`.'; criteria = $crit }
    $out = Invoke-Primitiva 'choice' $state $q 'router' $null
    $el = 'ninguna'
    if ($out.ok -and $mapa.Contains([string]$out.answer) -and [double]$out.confidence -ge [double]$cfg.router_min_confidence) { $el = $mapa[[string]$out.answer] }
    $out.skill = $el
    $c = '-'; if ($null -ne $out.confidence) { $c = F2 $out.confidence }
    $l = '-'; if ($null -ne $out.latency_ms) { $l = $out.latency_ms }
    Out-Txt "[JEV Router] -> Skill: $el | Confianza: $c | Tiempo: ${l}ms"
    if ($json) { Out-Txt (ConvertTo-JsonC $out) }
    return 0
}

# ------------------------------------------------------------------ panel

function Read-Log {
    $r = Get-JevRutas; $out = New-Object System.Collections.ArrayList
    foreach ($p in @(($r.log + '.1'), $r.log)) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        foreach ($l in [IO.File]::ReadAllLines($p, [Text.Encoding]::UTF8)) {
            if (-not $l.Trim()) { continue }
            try { [void]$out.Add((ConvertTo-HT ($l | ConvertFrom-Json))) } catch { }
        }
    }
    return , $out.ToArray()
}

function Invoke-Panel([string[]]$opts) {
    $n = [int](Get-Opt $opts '--n' (Get-Opt $opts '-n' 15))
    $cfg = Get-JevConfig; $ents = Read-Log
    $perm = @($ents | Where-Object { $_.modulo -eq 'permisos' })
    $tot = [Math]::Max(1, $perm.Count)
    $por = @{}; foreach ($e in $perm) { $o = [string]$e.origen; $por[$o] = [int](Get-Val $por $o 0) + 1 }
    $aprob = @($perm | Where-Object { $_.decision -eq 'allow' }).Count
    $coste = 0.0; foreach ($e in $ents) { $coste += [double](Get-Val $e 'coste' 0) }
    $lats = @($ents | Where-Object { $_.origen -eq 'jev' -and $null -ne $_['latencia_ms'] } | ForEach-Object { [int]$_.latencia_ms } | Sort-Object)
    $local = [int](Get-Val $por 'cache' 0) + [int](Get-Val $por 'regla' 0)
    $est = Get-Estado; $cache = Get-Cache
    function Pc($x) { return ([double](100.0 * $x / $tot)).ToString('0', $script:INV) + '%' }
    $act = 'APAGADO'; if ($cfg.activo) { $act = 'ACTIVO' }
    Out-Txt "== JEV · panel ($act, perfil $($cfg.perfil), runtime $($cfg.runtime)) =="
    Out-Txt ("Peticiones de permiso: $($perm.Count) | auto-aprobadas $(Pc $aprob) | estático $(Pc ([int](Get-Val $por 'estatico' 0))) | caché/regla $(Pc $local) | jev $(Pc ([int](Get-Val $por 'jev' 0))) | error $(Pc ([int](Get-Val $por 'error' 0)))")
    $cs = $coste.ToString('0.000000', $script:INV)
    if ($lats.Count -gt 0) {
        $media = [int](($lats | Measure-Object -Sum).Sum / $lats.Count)
        $p95 = $lats[[Math]::Min($lats.Count - 1, [int][Math]::Floor($lats.Count * 0.95))]
        Out-Txt "Llamadas a JEV: $($lats.Count) | latencia media $media ms | p95 $p95 ms | coste total $cs `$"
    } else { Out-Txt "Llamadas a JEV: 0 | coste total $cs `$" }
    $cc = 'ok'; if (Test-Suspendido $est) { $cc = "suspendido hasta $($est.suspendido_hasta)" }
    $us = [string]$est.ultimo_sync; if (-not $us) { $us = 'nunca' }
    Out-Txt "Resueltas en local sin red: $local | Último sync: $us | Cortacircuitos: $cc"
    $props = @($cache.Keys | Where-Object { $cache[$_].estado -eq 'propuesta' })
    $regs = @($cache.Keys | Where-Object { $cache[$_].estado -eq 'regla' })
    Out-Txt "Caché: $($cache.Count) patrones | reglas locales $($regs.Count) | propuestas pendientes $($props.Count) | en cola $($est.pendientes.Count)"
    if ($props.Count -gt 0) {
        Out-Txt ''; Out-Txt '-- Propuestas (confirmar con: reglas aprobar <id>) --'
        foreach ($p in $props) { $e = $cache[$p]; Out-Txt ("  $($e.id)  rev $(F2 $e.reversible)  x$($e.n_aprobado)  " + (Get-Corto $p 90)) }
    }
    $ult = @($ents | Where-Object { @('permisos', 'router', 'sync') -contains $_.modulo })
    if ($ult.Count -gt $n) { $ult = $ult[($ult.Count - $n)..($ult.Count - 1)] }
    if ($ult.Count -gt 0) {
        Out-Txt ''; Out-Txt "-- Últimas $($ult.Count) decisiones (criterio) --"
        foreach ($e in $ult) {
            $crit = [string](Get-Val $e 'regla' (Get-Val $e 'error' (Get-Val $e 'pid' '')))
            $rs = Get-Val $e 'respuestas' @{}
            $probs = (@($rs.Keys | Sort-Object -Descending | ForEach-Object { (Get-Corto $_ 3) + '=' + (F2 $rs[$_]) }) -join ' ')
            $f = [string](Get-Val $e 'fecha' ''); if ($f.Length -ge 16) { $f = $f.Substring(5, 11) }
            $h = [string](Get-Val $e 'herramienta' (Get-Val $e 'modulo' ''))
            Out-Txt ('  {0} {1,-8} {2,-6} {3,-5} {4,-22} {5} {6}' -f $f, $e.origen, (Get-Val $e 'decision' ''), (Get-Corto $h 5), (Get-Corto $crit 22), $probs, (Get-Corto ([string](Get-Val $e 'comando' '')) 60))
        }
    }
    return 0
}

function Invoke-Reglas([string[]]$opts) {
    $acc = if ($opts.Count -gt 0) { $opts[0] } else { 'listar' }
    $cache = Get-Cache
    if ($acc -eq 'listar') {
        foreach ($p in ($cache.Keys | Sort-Object { $cache[$_].estado })) {
            $e = $cache[$p]
            Out-Txt ((("$($e.id)  {0,-9} rev $(F2 $e.reversible)  visto $($e.n_visto)  aprob $($e.n_aprobado)  " -f $e.estado)) + (Get-Corto $p 90))
        }
        return 0
    }
    if (@('aprobar', 'revocar') -notcontains $acc -or $opts.Count -lt 2) { Out-Txt 'Uso: reglas listar | reglas aprobar <id> | reglas revocar <id>'; return 1 }
    $id = $opts[1]
    foreach ($p in @($cache.Keys)) {
        if ($cache[$p].id -eq $id) {
            if ($acc -eq 'aprobar') { $cache[$p].estado = 'regla' } else { $cache[$p].estado = 'revocada' }
            $cache[$p].confirmado = Format-Iso (Get-Ahora)
            Save-Cache $cache
            Write-JevLog @{ modulo = 'reglas'; origen = 'usuario'; accion = $acc; pid = $id; patron = $p }
            Out-Txt "Patrón $id -> $($cache[$p].estado): $p"; return 0
        }
    }
    Out-Txt "No existe el patrón $id"; return 1
}

# ------------------------------------------------------------------ config CLI

function Invoke-Toggle([string[]]$opts) {
    $r = Get-JevRutas; $cfg = Read-JsonFile $r.config @{}
    if (-not $cfg.Contains('modulos')) { $cfg.modulos = @{} }
    $def = (Get-ConfigDef).modulos
    $m = if ($opts.Count -gt 0) { $opts[0] } else { '' }
    if (-not $def.Contains($m)) { Out-Txt ('Módulo desconocido. Válidos: ' + (($def.Keys | Sort-Object) -join ', ')); return 1 }
    $actual = [bool](Get-Val $cfg.modulos $m $def[$m])
    $cfg.modulos[$m] = -not $actual
    Write-JsonFile $r.config $cfg
    Out-Txt "$m = $($cfg.modulos[$m])"; return 0
}

function Set-Activo([bool]$v) {
    $r = Get-JevRutas; $cfg = Read-JsonFile $r.config @{}
    $cfg.activo = $v; Write-JsonFile $r.config $cfg
    $t = 'DESACTIVADO'; if ($v) { $t = 'ACTIVADO' }
    Out-Txt "JEV $t (los hooks siguen registrados; salen sin hacer nada si activo=false)"; return 0
}

# ------------------------------------------------------------------ diagnostico

function Invoke-Diag {
    $cfg = Get-JevConfig; $r = Get-JevRutas
    Out-Txt "JEV diag (PowerShell $($PSVersionTable.PSVersion) $($PSVersionTable.PSEdition), modo de lenguaje $($ExecutionContext.SessionState.LanguageMode))"
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        try { Out-Txt ('  ExecutionPolicy: ' + ((Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join ', ')) } catch { }
    }
    $ok = 'NO EXISTE'; if (Test-Path -LiteralPath $r.config) { $ok = 'ok' }
    Out-Txt "  config: $($r.config) ($ok)"
    $rg = 'ILEGIBLE'; if (Get-JevReglas) { $rg = 'ok' }; Out-Txt "  reglas: $rg"
    $k = 'AUSENTE'; if (Get-JevKey) { $k = 'presente' }; Out-Txt "  key: $k"
    $uri = [Uri][string]$cfg.endpoint
    $px = ''
    if ($cfg.proxy) { $px = [string]$cfg.proxy }
    else { try { $dp = [Net.WebRequest]::DefaultWebProxy; if ($dp) { $pu = $dp.GetProxy($uri); if ($pu -and $pu.AbsoluteUri -ne $uri.AbsoluteUri) { $px = $pu.AbsoluteUri } } } catch { } }
    if ($px) { Out-Txt "  proxy: $px" } else { Out-Txt '  proxy: ninguno (conexión directa)' }
    try { $ips = [Net.Dns]::GetHostAddresses($uri.Host); Out-Txt "  DNS $($uri.Host) -> $($ips[0])" }
    catch { Out-Txt "  DNS $($uri.Host): FALLO" }
    if ($uri.Scheme -eq 'https' -and -not $px) {
        try {
            $tcp = New-Object Net.Sockets.TcpClient
            $ar = $tcp.BeginConnect($uri.Host, $uri.Port, $null, $null)
            if (-not $ar.AsyncWaitHandle.WaitOne(5000)) { throw 'timeout' }
            $tcp.EndConnect($ar)
            $script:diagErr = 'None'; $script:diagCert = $null
            $cb = [Net.Security.RemoteCertificateValidationCallback] { param($s, $c, $ch, $e) $script:diagErr = [string]$e; $script:diagCert = $c; return $true }
            $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, $cb)
            $ssl.AuthenticateAsClient($uri.Host)
            $emisor = ''; if ($script:diagCert) { $emisor = $script:diagCert.Issuer }
            $pub = $false
            foreach ($ca in @('google trust', "let's encrypt", 'digicert', 'sectigo', 'globalsign', 'amazon', 'cloudflare', 'isrg', 'usertrust', 'entrust', 'godaddy', 'microsoft', 'baltimore', 'comodo', 'ssl.com')) {
                if ($emisor.ToLowerInvariant().Contains($ca)) { $pub = $true }
            }
            $nota = ''
            if (-not $pub) { $nota = '  <- POSIBLE INSPECCIÓN SSL corporativa' }
            if ($script:diagErr -ne 'None') { $nota += "  (validación: $($script:diagErr))" }
            Out-Txt "  TLS ok · emisor: $emisor$nota"
            $ssl.Dispose(); $tcp.Close()
        } catch { Out-Txt ('  TLS: FALLO (' + $_.Exception.Message + ')') }
    }
    try {
        $req = [Net.HttpWebRequest][Net.WebRequest]::Create($uri); $req.Method = 'POST'; $req.ContentType = 'application/json'; $req.Timeout = 8000
        if ($req.Proxy) { $req.Proxy.Credentials = [Net.CredentialCache]::DefaultCredentials }
        $b = [Text.Encoding]::UTF8.GetBytes('{}'); $s = $req.GetRequestStream(); $s.Write($b, 0, $b.Length); $s.Close()
        $resp = $req.GetResponse(); Out-Txt "  HTTP sin auth: $([int]$resp.StatusCode) (inesperado)"; $resp.Close()
    } catch {
        $ex = $_.Exception; while ($ex -and -not ($ex -is [Net.WebException]) -and $ex.InnerException) { $ex = $ex.InnerException }
        if ($ex -is [Net.WebException] -and $ex.Response) {
            $code = [int]$ex.Response.StatusCode
            $cuerpo = ''; try { $cuerpo = (New-Object IO.StreamReader($ex.Response.GetResponseStream())).ReadToEnd().ToLowerInvariant() } catch { }
            $bloq = $false; foreach ($x in @('palo alto', 'check point', 'checkpoint', 'blocked', 'bloquead', 'url filtering')) { if ($cuerpo.Contains($x)) { $bloq = $true } }
            if ($bloq) { Out-Txt "  HTTP sin auth: $code  <- POSIBLE BLOQUEO del cortafuegos (página de bloqueo)" }
            elseif ($code -eq 400 -or $code -eq 401) { Out-Txt "  HTTP sin auth: $code -> endpoint alcanzable" }
            else { Out-Txt "  HTTP sin auth: $code" }
        } else { Out-Txt ('  HTTP: FALLO (' + $_.Exception.Message + ')') }
    }
    $est = Get-Estado; $cc = 'ok'; if (Test-Suspendido $est) { $cc = "suspendido hasta $($est.suspendido_hasta)" }
    Out-Txt "  cortacircuitos: $cc"
    return 0
}

# ------------------------------------------------------------------ main

$sub = ''; $resto = @()
if ($args.Count -gt 0) { $sub = [string]$args[0]; if ($args.Count -gt 1) { $resto = @($args[1..($args.Count - 1)] | ForEach-Object { [string]$_ }) } }

if ($sub -eq 'hook') {
    Set-Utf8Consola
    try { Invoke-Hook $resto } catch { }
    exit 0      # fail-closed: nunca romper la sesion
}
if ($sub -eq 'sesion') { Set-Utf8Consola; Invoke-Sesion; exit 0 }
Set-Utf8Consola
$rc = 0
switch ($sub) {
    'noul' { $rc = Invoke-CmdPrimitiva 'noul' $resto }
    'choice' { $rc = Invoke-CmdPrimitiva 'choice' $resto }
    'score' { $rc = Invoke-CmdPrimitiva 'score' $resto }
    'ping' { $rc = Invoke-Ping $resto }
    'route' { $rc = Invoke-Route $resto }
    'sync' { [void](Invoke-Sync (Test-Flag $resto '--todo') $false); $rc = 0 }
    'panel' { $rc = Invoke-Panel $resto }
    'reglas' { $rc = Invoke-Reglas $resto }
    'diag' { $rc = Invoke-Diag }
    'toggle' { $rc = Invoke-Toggle $resto }
    'on' { $rc = Set-Activo $true }
    'off' { $rc = Set-Activo $false }
    default {
        Out-Txt 'Uso: jev.ps1 ping|noul|choice|score|route|sync|panel|reglas|diag|toggle <modulo>|on|off'
        Out-Txt '  noul   --state <txt|json|@f> --instructions <txt> [--true <txt>] [--false <txt>] [--timeout s]'
        Out-Txt '  choice --state ... --instructions ... --criteria ''{"a":"desc",...}'''
        Out-Txt '  score  --state ... --instructions ... --criteria ''["nivel0","nivel1",...]'''
        $rc = 1
    }
}
exit ([int]($rc | Select-Object -Last 1))
