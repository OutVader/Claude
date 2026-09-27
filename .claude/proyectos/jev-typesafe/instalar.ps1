<#
.SYNOPSIS
  Instalador de JEV (TypeSafe) para Claude Code — perfil corporativo, Windows primero.

.DESCRIPTION
  1. Detecta SO, PowerShell (5.1 / 7), modo de lenguaje (CLM/AppLocker), ExecutionPolicy y Python.
     Comprueba si hay versiones más recientes (solo informa: no instala nada).
  2. Elige runtime: PowerShell primero; Python si PowerShell está bloqueado o es claramente más lento.
  3. Copia jev.ps1 / jev.py / reglas.json a ~/.claude/jev y los skills /elige-skill y /jev-panel.
  4. Crea o fusiona ~/.claude/jev_config.json (copia .bak si existía).
  5. Fusiona los hooks en ~/.claude/settings.json (copia .bak antes; nunca sobrescribe lo tuyo).
  No toca la API key: al final te muestra cómo guardarla tú (DPAPI, sin que pase por el historial).

.PARAMETER Runtime        auto (defecto) | powershell | python
.PARAMETER Destino        Carpeta base (defecto: tu perfil). Útil para probar en una carpeta temporal.
.PARAMETER DominiosInternos  Dominios corporativos a redactar antes de enviar nada (p. ej. empresa.local).
.PARAMETER RutasExcluidas    Regex extra que nunca se envían ni se auto-aprueban (se suman a las genéricas).
.PARAMETER SinRed         No consulta las últimas versiones de PowerShell/Python en Internet.
.PARAMETER Simular        Muestra lo que haría sin escribir nada.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\instalar.ps1 -DominiosInternos empresa.local -Simular
#>
param(
    [ValidateSet('auto', 'powershell', 'python')][string]$Runtime = 'auto',
    [string]$Destino = '',
    [string[]]$DominiosInternos = @(),
    [string[]]$RutasExcluidas = @(),
    [switch]$SinRed,
    [switch]$Simular
)

$ErrorActionPreference = 'Stop'
$INV = [Globalization.CultureInfo]::InvariantCulture
$AQUI = Split-Path -Parent $MyInvocation.MyCommand.Path
$SRC = Join-Path $AQUI 'src'
$ESWIN = ($env:OS -eq 'Windows_NT')
if (-not $Destino) { if ($env:USERPROFILE) { $Destino = $env:USERPROFILE } else { $Destino = $HOME } }
$CLAUDE = Join-Path $Destino '.claude'
$JEVDIR = Join-Path $CLAUDE 'jev'
$UTF8 = New-Object Text.UTF8Encoding($false)

function Paso([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Info([string]$t) { Write-Host "   $t" }
function Aviso([string]$t) { Write-Host "   ! $t" -ForegroundColor Yellow }
function Bien([string]$t) { Write-Host "   OK $t" -ForegroundColor Green }

function ConvertTo-HT($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Collections.IDictionary]) { $h = [ordered]@{}; foreach ($k in $o.Keys) { $h[[string]$k] = ConvertTo-HT $o[$k] }; return $h }
    if ($o -is [PSCustomObject]) { $h = [ordered]@{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-HT $p.Value }; return $h }
    if (($o -is [System.Collections.IEnumerable]) -and -not ($o -is [string])) {
        $l = New-Object System.Collections.ArrayList; foreach ($x in $o) { [void]$l.Add((ConvertTo-HT $x)) }; return , $l.ToArray()
    }
    return $o
}
function Read-Json([string]$ruta) {
    $txt = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
    if (-not $txt.Trim()) { return [ordered]@{} }
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { return ConvertTo-HT ($txt | ConvertFrom-Json -DateKind String) }
    return ConvertTo-HT ($txt | ConvertFrom-Json)
}
function Write-Json([string]$ruta, $datos) {
    $txt = ConvertTo-Json -InputObject $datos -Depth 50
    if ($Simular) { Info "[simulación] escribiría $ruta"; return }
    [IO.File]::WriteAllText($ruta, $txt, $UTF8)
}
function Backup([string]$ruta) {
    if (-not (Test-Path -LiteralPath $ruta)) { return $null }
    $bak = "$ruta.bak"
    if (Test-Path -LiteralPath $bak) { $bak = "$ruta.bak-" + (Get-Date).ToString('yyyyMMdd-HHmmss', $INV) }
    if ($Simular) { Info "[simulación] copia de seguridad -> $bak"; return $bak }
    Copy-Item -LiteralPath $ruta -Destination $bak -Force
    return $bak
}
function Get-Web([string]$url) {
    $req = [Net.HttpWebRequest][Net.WebRequest]::Create($url)
    $req.Timeout = 5000; $req.UserAgent = 'jev-instalador'
    if ($req.Proxy) { try { $req.Proxy.Credentials = [Net.CredentialCache]::DefaultCredentials } catch { } }
    $r = $req.GetResponse()
    try { return (New-Object IO.StreamReader($r.GetResponseStream())).ReadToEnd() } finally { $r.Close() }
}
function Measure-Ms([scriptblock]$sb) {
    $t = @(); for ($i = 0; $i -lt 3; $i++) { $sw = [Diagnostics.Stopwatch]::StartNew(); & $sb | Out-Null; $t += $sw.ElapsedMilliseconds }
    return [int](($t | Sort-Object)[1])
}
function Compare-Ver([string]$a, [string]$b) { try { return ([version]$a).CompareTo([version]$b) } catch { return 0 } }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# ------------------------------------------------------------------ 1. entorno
Paso '1/6 Sistema'
$so = 'linux'; $distro = ''; $init = ''
if ($ESWIN) {
    $so = 'windows'; $init = 'windows-scm'
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; $distro = "$($os.Caption) $($os.Version)" }
    catch { $distro = "Windows $([Environment]::OSVersion.Version)" }
} else {
    if (Test-Path /etc/os-release) { $m = Select-String -Path /etc/os-release -Pattern '^PRETTY_NAME="?([^"]*)' ; if ($m) { $distro = $m.Matches[0].Groups[1].Value } }
    $p1 = ''; try { $p1 = (Get-Content /proc/1/comm -ErrorAction Stop).Trim() } catch { }
    if ($p1 -eq 'systemd') { $init = 'systemd' } elseif ($p1 -match 'runit' -or (Test-Path /etc/runit)) { $init = 'runit' } else { $init = $p1 }
}
Info "SO: $so · $distro · init: $init"
Info "Destino: $CLAUDE"

Paso '2/6 Runtimes (PowerShell primero, Python como alternativa)'
$candPS = @()
if ($ESWIN) {
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $ps51) { $candPS += [pscustomobject]@{ nombre = 'powershell.exe'; exe = $ps51 } }
}
$pw = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pw) { $candPS += [pscustomobject]@{ nombre = 'pwsh'; exe = $pw.Source } }

# Prueba real: ejecutar un .ps1 DESDE la carpeta de destino (AppLocker/WDAC filtran por ruta)
$mejorPS = $null
$probeDir = $JEVDIR
if ($Simular) { $probeDir = Join-Path ([IO.Path]::GetTempPath()) ('jev-probe-' + $PID) }
[void](New-Item -ItemType Directory -Force -Path $probeDir)
$probe = Join-Path $probeDir 'jev_probe.ps1'
[IO.File]::WriteAllText($probe, '$ExecutionContext.SessionState.LanguageMode.ToString() + "|" + $PSVersionTable.PSVersion.ToString()', $UTF8)
foreach ($c in $candPS) {
    try {
        $out = (& $c.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $probe 2>&1 | Out-String).Trim()
        $partes = $out.Split('|')
        $modo = $partes[0]; $ver = ''; if ($partes.Count -gt 1) { $ver = $partes[1] }
        if ($modo -ne 'FullLanguage') { Aviso "$($c.nombre): no utilizable ($out)"; continue }
        $ms = Measure-Ms { & $c.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $probe }
        Bien "$($c.nombre) $ver · FullLanguage · arranque ~$ms ms"
        $c | Add-Member -NotePropertyName ver -NotePropertyValue $ver
        $c | Add-Member -NotePropertyName ms -NotePropertyValue $ms
        if (-not $mejorPS -or $ms -lt $mejorPS.ms) { $mejorPS = $c }
    } catch { Aviso "$($c.nombre): bloqueado ($($_.Exception.Message))" }
}
Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
if ($Simular) { Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue }
if ($ESWIN) {
    try {
        $pol = Get-ExecutionPolicy -List | Where-Object { $_.ExecutionPolicy -ne 'Undefined' } | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }
        Info ('ExecutionPolicy: ' + ($pol -join ', '))
        $gpo = Get-ExecutionPolicy -List | Where-Object { $_.Scope -in 'MachinePolicy', 'UserPolicy' -and $_.ExecutionPolicy -in 'AllSigned', 'Restricted' }
        if ($gpo) { Aviso 'Una GPO fija AllSigned/Restricted: -ExecutionPolicy Bypass no la anula; si falla, usa -Runtime python.' }
    } catch { }
}

$py = $null
$candPy = @()
foreach ($n in @('py', 'python', 'python3')) {
    $g = Get-Command $n -ErrorAction SilentlyContinue
    if ($g) { $candPy += [pscustomobject]@{ nombre = $n; exe = $g.Source } }
}
foreach ($c in $candPy) {
    try {
        $pre = @(); if ($c.nombre -eq 'py') { $pre = @('-3') }
        $v = (& $c.exe @pre --version 2>&1 | Out-String).Trim()
        if ($v -notmatch 'Python (\d+\.\d+\.\d+)') {
            if ($c.exe -match 'WindowsApps') { Aviso "$($c.nombre): alias de Microsoft Store, no es un Python instalado" }
            continue
        }
        $ver = $Matches[1]
        if ((Compare-Ver $ver '3.8.0') -lt 0) { Aviso "$($c.nombre) $ver es demasiado antiguo (mínimo 3.8)"; continue }
        $ms = Measure-Ms { & $c.exe @pre -c 'import json,re,ssl,urllib.request' }
        $c | Add-Member -NotePropertyName ver -NotePropertyValue $ver
        $c | Add-Member -NotePropertyName ms -NotePropertyValue $ms
        $c | Add-Member -NotePropertyName pre -NotePropertyValue $pre
        Bien "Python $ver ($($c.nombre)) · arranque ~$ms ms"
        $py = $c; break
    } catch { }
}
if (-not $py) { Info 'Python: no disponible (no es necesario si PowerShell es utilizable)' }

if (-not $SinRed) {
    try {
        $ult = ((Get-Web 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest') | ConvertFrom-Json).tag_name.TrimStart('v')
        $local = ''; if ($pw) { $local = ($candPS | Where-Object { $_.nombre -eq 'pwsh' } | Select-Object -First 1).ver }
        if (-not $local) { Info "PowerShell 7 no instalado (última: $ult). Opcional: winget install --id Microsoft.PowerShell --scope user" }
        elseif ((Compare-Ver $local $ult) -lt 0) { Aviso "pwsh $local -> hay $ult (winget upgrade --id Microsoft.PowerShell)" }
        else { Bien "pwsh $local es la última ($ult)" }
    } catch { Info 'No se pudo consultar la última versión de PowerShell (red/proxy); se continúa.' }
    if ($py) {
        try {
            $ciclos = (Get-Web 'https://endoflife.date/api/python.json') | ConvertFrom-Json
            $mismo = $ciclos | Where-Object { $py.ver.StartsWith($_.cycle + '.') } | Select-Object -First 1
            $top = ($ciclos | Select-Object -First 1).latest
            if ($mismo -and (Compare-Ver $py.ver $mismo.latest) -lt 0) { Aviso "Python $($py.ver) -> parche disponible $($mismo.latest) (última rama: $top)" }
            else { Bien "Python $($py.ver) al día en su rama (última rama: $top)" }
        } catch { Info 'No se pudo consultar la última versión de Python; se continúa.' }
    }
}

$elegido = $Runtime
if ($Runtime -eq 'auto') {
    if ($mejorPS -and (-not $py -or $mejorPS.ms -lt 1200 -or $mejorPS.ms -lt (2 * $py.ms))) { $elegido = 'powershell' }
    elseif ($py) { $elegido = 'python' }
    else { $elegido = '' }
}
if ($elegido -eq 'powershell' -and -not $mejorPS) { throw 'Se pidió PowerShell pero no hay ninguno utilizable (CLM/AppLocker/GPO). Prueba -Runtime python.' }
if ($elegido -eq 'python' -and -not $py) { throw 'Se pidió Python pero no hay un Python >= 3.8 instalado.' }
if (-not $elegido) { throw 'No hay runtime utilizable: PowerShell bloqueado y sin Python. Nada instalado.' }
$motivo = 'PowerShell utilizable (primera opción)'
if ($elegido -eq 'python') { if ($mejorPS) { $motivo = "PowerShell arranca en ~$($mejorPS.ms) ms frente a ~$($py.ms) ms de Python" } else { $motivo = 'PowerShell no utilizable' } }
if ($Runtime -ne 'auto') { $motivo = 'forzado con -Runtime' }
Bien "Runtime elegido: $elegido ($motivo)"

# comando de hook (forma exec: sin shell intermedio) y prefijo para los skills
$jevFwd = ($JEVDIR -replace '\\', '/')
if ($elegido -eq 'powershell') {
    $hookExe = $mejorPS.exe
    $hookPre = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File')
    $hookScript = Join-Path $JEVDIR 'jev_permission_hook.ps1'
    $cliScript = Join-Path $JEVDIR 'jev.ps1'
    $cmdSkill = "$($mejorPS.nombre) -NoProfile -ExecutionPolicy Bypass -File `"$jevFwd/jev.ps1`""
    $shellTxt = "powershell $($mejorPS.ver)"
} else {
    $hookExe = $py.exe
    $hookPre = @($py.pre)
    $hookScript = Join-Path $JEVDIR 'jev_permission_hook.py'
    $cliScript = Join-Path $JEVDIR 'jev.py'
    $n = $py.nombre; if ($n -eq 'py') { $n = 'py -3' }
    $cmdSkill = "$n `"$jevFwd/jev.py`""
    $shellTxt = "python $($py.ver)"
}

# ------------------------------------------------------------------ 3. ficheros
Paso '3/6 Ficheros'
foreach ($d in @($CLAUDE, $JEVDIR)) { if (-not (Test-Path $d)) { if ($Simular) { Info "[simulación] crearía $d" } else { [void](New-Item -ItemType Directory -Force -Path $d) } } }
foreach ($f in @('jev.ps1', 'jev_permission_hook.ps1', 'jev.py', 'jev_permission_hook.py', 'reglas.json')) {
    $o = Join-Path (Join-Path $SRC 'jev') $f
    if ($Simular) { Info "[simulación] copiaría $f -> $JEVDIR" } else { Copy-Item -LiteralPath $o -Destination (Join-Path $JEVDIR $f) -Force }
}
Bien "Núcleo copiado en $JEVDIR (ambos runtimes, para poder cambiar sin reinstalar)"
foreach ($sk in @('elige-skill', 'jev-panel')) {
    $dst = Join-Path (Join-Path $CLAUDE 'skills') $sk
    $txt = [IO.File]::ReadAllText((Join-Path (Join-Path (Join-Path $SRC 'skills') $sk) 'SKILL.md'), [Text.Encoding]::UTF8).Replace('{{JEV}}', $cmdSkill)
    if ($Simular) { Info "[simulación] escribiría skill $sk"; continue }
    [void](New-Item -ItemType Directory -Force -Path $dst)
    $f = Join-Path $dst 'SKILL.md'
    if (Test-Path $f) { [void](Backup $f) }
    [IO.File]::WriteAllText($f, $txt, $UTF8)
}
Bien "Skills /elige-skill y /jev-panel -> $(Join-Path $CLAUDE 'skills')"

# ------------------------------------------------------------------ 4. config
Paso '4/6 Configuración (jev_config.json)'
$reglas = Read-Json (Join-Path (Join-Path $SRC 'jev') 'reglas.json')
$cfgRuta = Join-Path $CLAUDE 'jev_config.json'
$doms = @($DominiosInternos | Where-Object { $_ })
if ($env:USERDNSDOMAIN) { $doms += $env:USERDNSDOMAIN.ToLowerInvariant() }
$nuevo = [ordered]@{
    activo = $true; perfil = 'corporativo'; runtime = $elegido
    modelo = 'typesafe/jev-1.13'; endpoint = 'https://openrouter.ai/api/alpha/decisions'
    approve_threshold = 0.90; router_min_confidence = 0.75; timeout_s = 8; proxy = ''; ca_bundle = ''
    sistema = [ordered]@{ os = $so; distro = $distro; init = $init; shell = $shellTxt }
    red = [ordered]@{ modo = 'nuevo_y_sync'; sync_dias = 7; cortacircuitos_fallos = 2; cortacircuitos_min = 15 }
    cache = [ordered]@{ ttl_dias = 30; promover_tras = 5; promover_min = 0.95 }
    mostrar_criterio = $true; redaccion = $true
    dominios_internos = @($doms | Sort-Object -Unique)
    modulos = [ordered]@{ router_manual = $true; permisos_shell = $true; panel = $true; permisos_read = $false; sugeridor_auto = $false; triaje_logs = $false; check_commit = $false }
    rutas_excluidas = @(@($reglas.exclusiones_por_defecto) + @($RutasExcluidas | Where-Object { $_ }))
    instalado = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK', $INV)
}
foreach ($rx in $nuevo.rutas_excluidas) { try { [void][regex]::new($rx) } catch { throw "Regex de exclusión inválida: $rx" } }
if (Test-Path -LiteralPath $cfgRuta) {
    $bak = Backup $cfgRuta
    $viejo = Read-Json $cfgRuta
    foreach ($k in @('approve_threshold', 'router_min_confidence', 'timeout_s', 'proxy', 'ca_bundle', 'red', 'cache', 'mostrar_criterio', 'modulos', 'modelo', 'endpoint')) {
        if ($viejo.Contains($k)) { $nuevo[$k] = $viejo[$k] }
    }
    if ($viejo.Contains('dominios_internos')) { $nuevo.dominios_internos = @(@($viejo.dominios_internos) + @($nuevo.dominios_internos) | Where-Object { $_ } | Sort-Object -Unique) }
    if ($viejo.Contains('rutas_excluidas')) { $nuevo.rutas_excluidas = @(@($viejo.rutas_excluidas) + @($nuevo.rutas_excluidas) | Where-Object { $_ } | Select-Object -Unique) }
    Info "Config existente fusionada (copia: $bak)"
}
if ([double]$nuevo.approve_threshold -lt 0.80) { $nuevo.approve_threshold = 0.80 }
Write-Json $cfgRuta $nuevo
Bien "Umbral $($nuevo.approve_threshold) · red: $($nuevo.red.modo) (sync cada $($nuevo.red.sync_dias) días) · dominios a redactar: $(@($nuevo.dominios_internos).Count)"

# ------------------------------------------------------------------ 5. settings.json
Paso '5/6 Hooks en settings.json (fusión con copia .bak)'
$setRuta = Join-Path $CLAUDE 'settings.json'
$set = [ordered]@{}
$bak = $null
if (Test-Path -LiteralPath $setRuta) {
    try { $set = Read-Json $setRuta } catch { throw "settings.json no es JSON válido; no lo toco. Corrígelo y repite. ($($_.Exception.Message))" }
    $bak = Backup $setRuta
}
if (-not $set.Contains('hooks')) { $set['hooks'] = [ordered]@{} }
function Set-HookJev($set, [string]$evento, [string]$matcher, [string[]]$argsHook, [int]$timeout) {
    $lista = @()
    if ($set.hooks.Contains($evento)) {
        foreach ($g in @($set.hooks[$evento])) {
            $hs = @(@($g.hooks) | Where-Object { -not ((([string]$_.command) + ' ' + (@($_.args) -join ' ')) -match 'jev_permission_hook|[\\/]jev\.(ps1|py)') })
            if ($hs.Count -gt 0) { $g.hooks = $hs; $lista += $g }
        }
    }
    $lista += [ordered]@{ matcher = $matcher; hooks = @([ordered]@{ type = 'command'; command = $hookExe; args = $argsHook; timeout = $timeout }) }
    $set.hooks[$evento] = $lista
}
Set-HookJev $set 'PermissionRequest' 'Bash|PowerShell' (@($hookPre) + @($hookScript)) 15
Set-HookJev $set 'SessionStart' 'startup' (@($hookPre) + @($cliScript, 'sesion')) 30
Write-Json $setRuta $set
if (-not $Simular) {
    try { [void](Read-Json $setRuta); Bien "settings.json válido · copia: $(if ($bak) { $bak } else { '(no existía)' })" }
    catch {
        if ($bak) { Copy-Item -LiteralPath $bak -Destination $setRuta -Force }
        throw 'settings.json resultante inválido: restaurada la copia. Nada cambiado.'
    }
}
Info "PermissionRequest (Bash|PowerShell) -> $hookExe $(@($hookPre) -join ' ') $hookScript"
Info "SessionStart (startup) -> sync semanal por lotes si toca"

# ------------------------------------------------------------------ 6. siguiente paso
Paso '6/6 Siguiente paso (tú)'
$kd = Join-Path (Join-Path $Destino '.config') 'jev'
$hayKey = [bool]$env:OPENROUTER_API_KEY -or (Test-Path (Join-Path $kd 'key.dpapi')) -or (Test-Path (Join-Path $kd 'env'))
if ($hayKey) { Bien 'API key encontrada (no se muestra).' }
else {
    Aviso 'Falta la API key de OpenRouter. Pasos (los haces tú; yo no puedo crear la cuenta):'
    Info '  1) Cuenta en https://openrouter.ai y crédito (5 $ sobran para meses).'
    Info '  2) Key en https://openrouter.ai/settings/keys con límite de gasto bajo (p. ej. 2 $).'
    Info '  3) Guárdala cifrada con DPAPI (solo tu usuario puede leerla) pegando en PowerShell:'
    Write-Host '     $d="$env:USERPROFILE\.config\jev"; New-Item -ItemType Directory -Force $d | Out-Null; Read-Host "Key OpenRouter" -AsSecureString | ConvertFrom-SecureString | Set-Content -NoNewline -Encoding ASCII "$d\key.dpapi"; icacls $d /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null' -ForegroundColor White
}
$cli = "& `"$hookExe`" $(@($hookPre) -join ' ') `"$cliScript`""
Info "Comprobar red/proxy/inspección SSL:  $cli diag"
Info "Llamada mínima de prueba:            $cli ping"
Info "Desactivar todo (sin tocar settings): $cli off"
Aviso 'Reinicia Claude Code para que cargue los hooks.'
