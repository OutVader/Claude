#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""JEV (TypeSafe) — cliente núcleo en Python (solo librería estándar).

Runtime alternativo a jev.ps1: mismo comportamiento, mismos ficheros
(jev_config.json, reglas.json, cache.json, estado.json, decisions.jsonl).

Subcomandos:
  ping | noul | choice | score | route | hook | sesion | sync | panel |
  reglas (aprobar|revocar|listar) | diag | toggle <modulo> | on | off
"""
import argparse
import ctypes
import json
import os
import re
import socket
import ssl
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

VERSION = "1.0.0"
MODELO_DEF = "typesafe/jev-1.13"
ENDPOINT_DEF = "https://openrouter.ai/api/alpha/decisions"
MAX_LOG = 5 * 1024 * 1024
LOTE_SYNC = 20

# --------------------------------------------------------------------------- rutas


def base_dir():
    return os.environ.get("JEV_HOME") or os.path.expanduser("~")


def rutas():
    b = base_dir()
    claude = os.path.join(b, ".claude")
    jev = os.path.join(claude, "jev")
    return {
        "base": b,
        "claude": claude,
        "jev": jev,
        "config": os.path.join(claude, "jev_config.json"),
        "reglas": os.path.join(os.path.dirname(os.path.abspath(__file__)), "reglas.json"),
        "cache": os.path.join(jev, "cache.json"),
        "estado": os.path.join(jev, "estado.json"),
        "log": os.path.join(jev, "decisions.jsonl"),
        "skills": os.path.join(claude, "skills"),
        "plugins": os.path.join(claude, "plugins"),
        "settings": os.path.join(claude, "settings.json"),
        "key_dir": os.path.join(b, ".config", "jev"),
    }


def ahora():
    return datetime.now(timezone.utc)


def iso(dt=None):
    return (dt or ahora()).strftime("%Y-%m-%d %H:%M:%SZ")


def leer_iso(s):
    try:
        return datetime.strptime(s, "%Y-%m-%d %H:%M:%SZ").replace(tzinfo=timezone.utc)
    except Exception:
        return None


def leer_json(ruta, defecto):
    try:
        with open(ruta, "r", encoding="utf-8-sig") as f:
            return json.load(f)
    except Exception:
        return defecto


def escribir_json(ruta, datos):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    tmp = "%s.%d.tmp" % (ruta, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=1)
    os.replace(tmp, ruta)


# --------------------------------------------------------------------------- config

CONFIG_DEF = {
    "activo": True,
    "perfil": "corporativo",
    "runtime": "python",
    "modelo": MODELO_DEF,
    "endpoint": ENDPOINT_DEF,
    "approve_threshold": 0.90,
    "router_min_confidence": 0.75,
    "timeout_s": 8,
    "proxy": "",
    "ca_bundle": "",
    "sistema": {"os": "", "distro": "", "init": "", "shell": ""},
    "red": {"modo": "nuevo_y_sync", "sync_dias": 7, "cortacircuitos_fallos": 2, "cortacircuitos_min": 15},
    "cache": {"ttl_dias": 30, "promover_tras": 5, "promover_min": 0.95},
    "mostrar_criterio": True,
    "redaccion": True,
    "dominios_internos": [],
    "modulos": {"router_manual": True, "permisos_shell": True, "panel": True, "permisos_read": False,
                "sugeridor_auto": False, "triaje_logs": False, "check_commit": False},
    "rutas_excluidas": None,  # None -> reglas.json:exclusiones_por_defecto
    "instalado": "",
}


def fusionar(defecto, real):
    if not isinstance(defecto, dict) or not isinstance(real, dict):
        return real if real is not None else defecto
    out = dict(defecto)
    for k, v in real.items():
        out[k] = fusionar(defecto.get(k), v) if k in defecto else v
    return out


def cargar_config():
    cfg = fusionar(CONFIG_DEF, leer_json(rutas()["config"], {}))
    try:
        th = float(cfg.get("approve_threshold", 0.90))
    except Exception:
        th = 0.90
    cfg["approve_threshold"] = min(max(th, 0.80), 1.0)  # nunca por debajo de 0.80
    return cfg


def cargar_reglas():
    return leer_json(rutas()["reglas"], None)


# --------------------------------------------------------------------------- key


def _dpapi_descifrar(hexblob):
    """Descifra la salida de ConvertFrom-SecureString (DPAPI, usuario actual)."""
    if os.name != "nt":
        return None
    from ctypes import wintypes

    class BLOB(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]

    datos = bytes.fromhex(hexblob.strip())
    buf = ctypes.create_string_buffer(datos, len(datos))
    ent = BLOB(len(datos), ctypes.cast(buf, ctypes.POINTER(ctypes.c_char)))
    sal = BLOB()
    if not ctypes.windll.crypt32.CryptUnprotectData(ctypes.byref(ent), None, None, None, None, 0, ctypes.byref(sal)):
        return None
    try:
        crudo = ctypes.string_at(sal.pbData, sal.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(sal.pbData)
    return crudo.decode("utf-16-le")


def cargar_key():
    k = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if k:
        return k
    kd = rutas()["key_dir"]
    try:
        p = os.path.join(kd, "key.dpapi")
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8-sig") as f:
                k = _dpapi_descifrar(f.read())
            if k:
                return k.strip()
    except Exception:
        pass
    try:
        with open(os.path.join(kd, "env"), "r", encoding="utf-8") as f:
            for linea in f:
                if linea.startswith("OPENROUTER_API_KEY="):
                    return linea.split("=", 1)[1].strip().strip('"').strip("'")
    except Exception:
        pass
    return ""


# --------------------------------------------------------------------------- log


def registrar(entrada):
    try:
        r = rutas()
        os.makedirs(r["jev"], exist_ok=True)
        if os.path.exists(r["log"]) and os.path.getsize(r["log"]) > MAX_LOG:
            os.replace(r["log"], r["log"] + ".1")
        entrada = dict({"fecha": iso()}, **entrada)
        with open(r["log"], "a", encoding="utf-8") as f:
            f.write(json.dumps(entrada, ensure_ascii=False) + "\n")
    except Exception:
        pass


# --------------------------------------------------------------------------- red


class ErrorJEV(Exception):
    pass


def llamar_jev(cfg, state, preguntas, timeout=None):
    """POST a la API de decisiones. Devuelve (respuesta, latencia_ms). Lanza ErrorJEV."""
    key = cargar_key()
    if not key:
        raise ErrorJEV("sin_key")
    cuerpo = json.dumps({"model": cfg["modelo"], "state": state, "questions": preguntas}).encode("utf-8")
    req = urllib.request.Request(cfg["endpoint"], data=cuerpo, method="POST", headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
        "User-Agent": "jev-claude-code/" + VERSION,
    })
    handlers = []
    if cfg.get("proxy"):
        handlers.append(urllib.request.ProxyHandler({"http": cfg["proxy"], "https": cfg["proxy"]}))
    ctx = ssl.create_default_context(cafile=cfg["ca_bundle"] or None) if cfg.get("ca_bundle") else ssl.create_default_context()
    handlers.append(urllib.request.HTTPSHandler(context=ctx))
    opener = urllib.request.build_opener(*handlers)
    t = float(timeout if timeout is not None else cfg.get("timeout_s", 8))
    t0 = time.monotonic()
    try:
        with opener.open(req, timeout=max(t, 0.001)) as resp:
            if resp.status != 200:
                raise ErrorJEV("http_%d" % resp.status)
            datos = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise ErrorJEV("http_%d" % e.code)
    except ErrorJEV:
        raise
    except (socket.timeout, TimeoutError):
        raise ErrorJEV("timeout")
    except urllib.error.URLError as e:
        raise ErrorJEV("red: %s" % (e.reason.__class__.__name__ if not isinstance(e.reason, str) else e.reason))
    except ValueError:
        raise ErrorJEV("json_ilegible")
    except Exception as e:
        raise ErrorJEV("error: %s" % e.__class__.__name__)
    lat = int((time.monotonic() - t0) * 1000)
    if not isinstance(datos, dict) or not isinstance(datos.get("answers"), dict):
        raise ErrorJEV("respuesta_sin_answers")
    return datos, lat


def prob(respuesta, qid):
    """Probabilidad Noul validada en [0,1]; si no, ErrorJEV."""
    try:
        v = float(respuesta["answers"][qid]["noul"])
    except Exception:
        raise ErrorJEV("noul_ausente:%s" % qid)
    if not (0.0 <= v <= 1.0) or v != v:
        raise ErrorJEV("noul_fuera_de_rango:%s" % qid)
    return v


def coste(respuesta):
    try:
        return float(respuesta.get("usage", {}).get("cost") or 0)
    except Exception:
        return 0.0


# --------------------------------------------------------------------------- estado / cortacircuitos


def cargar_estado():
    return leer_json(rutas()["estado"], {"fallos": 0, "suspendido_hasta": "", "ultimo_sync": "", "pendientes": {}})


def guardar_estado(e):
    try:
        escribir_json(rutas()["estado"], e)
    except Exception:
        pass


def suspendido(cfg, est):
    t = leer_iso(est.get("suspendido_hasta") or "")
    return bool(t and t > ahora())


def anotar_fallo(cfg, est):
    est["fallos"] = int(est.get("fallos", 0)) + 1
    if est["fallos"] >= int(cfg["red"].get("cortacircuitos_fallos", 2)):
        est["suspendido_hasta"] = iso(ahora() + timedelta(minutes=int(cfg["red"].get("cortacircuitos_min", 15))))
        est["fallos"] = 0
    guardar_estado(est)


def anotar_exito(est):
    if est.get("fallos") or est.get("suspendido_hasta"):
        est["fallos"] = 0
        est["suspendido_hasta"] = ""
        guardar_estado(est)


# --------------------------------------------------------------------------- análisis de comandos

OPERADORES2 = ("&&", "||")
OPERADORES1 = set(";|&(){}\n")


def trocear(cmd):
    """Divide por && || ; | & ( ) { } y saltos de línea, respetando comillas."""
    segs, cur, i, q = [], [], 0, None
    while i < len(cmd):
        c = cmd[i]
        if q:
            cur.append(c)
            if c == q:
                q = None
            i += 1
            continue
        if c in "\"'":
            q = c
            cur.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < len(cmd) and cmd[i + 1] in ";&|(){}":
            cur.append(cmd[i + 1])
            i += 2
            continue
        if cmd[i:i + 2] in OPERADORES2:
            segs.append("".join(cur))
            cur = []
            i += 2
            continue
        if c in OPERADORES1:
            segs.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    segs.append("".join(cur))
    return [s.strip() for s in segs if s.strip()]


RE_TOKEN = re.compile(r'"(?:[^"\\]|\\.)*"|\'[^\']*\'|\S+')
RE_ASIG = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
RE_BIN = re.compile(r"^(/usr/local/s?bin/|/usr/s?bin/|/s?bin/|[a-z]:[\\/]windows[\\/]system32[\\/](windowspowershell[\\/]v1\.0[\\/])?)", re.I)
ENVOLTORIOS = {"env", "nohup", "command", "builtin", "time", "nice", "stdbuf", "ionice", "timeout"}


def tokens(s):
    return RE_TOKEN.findall(s)


def normalizar(seg):
    """Quita envoltorios (env, nohup, timeout, VAR=x, /usr/bin/, .exe) y devuelve el segmento."""
    toks = tokens(seg)
    while toks:
        t0 = toks[0]
        if RE_ASIG.match(t0):
            toks = toks[1:]
            continue
        m = RE_BIN.match(t0)
        if m and len(t0) > m.end():
            toks = [t0[m.end():]] + toks[1:]
            continue
        base = t0.lower()
        if base.endswith(".exe") and "/" not in base and "\\" not in base:
            toks = [t0[:-4]] + toks[1:]
            continue
        if base in ENVOLTORIOS:
            toks = toks[1:]
            while toks and (toks[0].startswith("-") or RE_ASIG.match(toks[0])):
                opt = toks.pop(0)
                if base in ("nice", "ionice", "timeout", "stdbuf") and opt in ("-n", "-c", "-s", "-k", "--signal", "--kill-after"):
                    if toks:
                        toks.pop(0)
            if base == "timeout" and toks and re.match(r"^\d+(\.\d+)?[smhd]?$", toks[0]):
                toks.pop(0)
            continue
        break
    return " ".join(toks)


def _limpia(p):
    return p.strip("\"'")


def norm_ruta(p, cwd, home):
    """Normaliza una ruta a forma absoluta en minúsculas con '/'. None si no se puede resolver."""
    p = _limpia(p).replace("\\", "/")
    pl = p.lower()
    if pl.startswith("~"):
        p = home.replace("\\", "/") + p[1:]
    elif pl.startswith("$env:userprofile") or pl.startswith("$home"):
        p = home.replace("\\", "/") + p[p.find("/"):] if "/" in p else home
    elif pl.startswith("$") or pl.startswith("%"):
        return None
    elif not (re.match(r"^[a-z]:/", pl) or pl.startswith("/")):
        p = cwd.replace("\\", "/").rstrip("/") + "/" + p
    partes = []
    for x in p.split("/"):
        if x in ("", "."):
            continue
        if x == "..":
            if partes:
                partes.pop()
            continue
        partes.append(x)
    pref = "" if re.match(r"^[a-z]:$", (partes[0] if partes else ""), re.I) else "/"
    return (pref + "/".join(partes)).lower()


def es_rutaish(t):
    t = _limpia(t)
    return bool(re.match(r"^([a-z]:[\\/]|\\\\|/|~|\.{1,2}[\\/]|\.\.$|\$env:|\$home|%)", t, re.I)) or ("/" in t or "\\" in t)


def dentro(p, cwd, home):
    n = norm_ruta(p, cwd, home)
    if n is None:
        return False
    c = norm_ruta(cwd, cwd, home)
    return n == c or n.startswith(c.rstrip("/") + "/")


RE_REDIR = re.compile(r"(?:\d|&|\*)?>>?\s*(\"[^\"]*\"|'[^']*'|[^\s;|&]+)")


def redirecciones_fuera(seg, cwd, home):
    for m in RE_REDIR.finditer(seg):
        dest = _limpia(m.group(1))
        if dest.startswith("&") or dest.lower() in ("/dev/null", "$null", "nul", "null", "/dev/stderr", "/dev/stdout"):
            continue
        if not dentro(dest, cwd, home):
            return dest
    return None


def _cmp(regex):
    return re.compile(regex, re.I)


def chequeo_estatico(cmd, cwd, cfg, reglas):
    """Devuelve (id_regla, motivo) si el comando NO puede auto-aprobarse; None si pasa."""
    home = base_dir()
    for grupo in ("global", "secretos", "rutas_sensibles"):
        for r in reglas.get(grupo, []):
            if _cmp(r["re"]).search(cmd):
                return r["id"], r["motivo"]
    excl = cfg.get("rutas_excluidas")
    if excl is None:
        excl = reglas.get("exclusiones_por_defecto", [])
    for rx in excl or []:
        try:
            if _cmp(rx).search(cmd) or _cmp(rx).search(cwd or ""):
                return "excluida", "ruta/patrón excluido por configuración"
        except re.error:
            return "excluida", "regla de exclusión inválida (fail-closed)"
    segs = trocear(cmd)
    if not segs:
        return "vacio", "comando vacío"
    init = (cfg.get("sistema") or {}).get("init", "")
    so = (cfg.get("sistema") or {}).get("os", "")
    coh = reglas.get("coherencia", {})
    clave_coh = "windows" if so == "windows" else init
    esc = _cmp(reglas.get("escritura", "^$"))
    grupos = list(reglas.get("segmento", []))
    if cfg.get("perfil") == "corporativo":
        grupos += reglas.get("corporativo", [])
    for crudo in segs:
        seg = normalizar(crudo)
        if not seg:
            continue
        if clave_coh in coh and _cmp(coh[clave_coh]["re"]).search(seg):
            return "coherencia_" + clave_coh, coh[clave_coh]["motivo"]
        for r in grupos:
            if _cmp(r["re"]).search(seg):
                return r["id"], r["motivo"]
        fuera = redirecciones_fuera(crudo, cwd, home)
        if fuera:
            return "redireccion_fuera", "redirección fuera del proyecto: " + redactar(fuera, cfg, reglas)
        if esc.search(seg):
            for t in tokens(seg)[1:]:
                if t.startswith("-") or not es_rutaish(t) and ".." not in t:
                    continue
                if not dentro(t, cwd, home):
                    return "escritura_fuera", "escribe fuera del proyecto"
    return None


# --------------------------------------------------------------------------- redacción / patrón


def redactar(texto, cfg, reglas):
    if not cfg.get("redaccion", True) or not texto:
        return texto
    s = texto
    doms = list(cfg.get("dominios_internos") or [])
    for var in ("USERDNSDOMAIN", "USERDOMAIN"):
        v = os.environ.get(var, "")
        if v and len(v) > 2:
            doms.append(v)
    for r in reglas.get("redaccion", []):
        rep = r["rep"].replace("{1}", r"\g<1>")
        s = re.sub(r["re"], rep, s, flags=re.I)
    for d in sorted(set(doms), key=len, reverse=True):
        s = re.sub(r"[a-z0-9.-]*" + re.escape(d), "<DOM>", s, flags=re.I)
    for var, tag in (("USERNAME", "<USR>"), ("USER", "<USR>"), ("COMPUTERNAME", "<PC>")):
        v = os.environ.get(var, "")
        if v and len(v) > 2:
            s = re.sub(r"\b" + re.escape(v) + r"\b", tag, s, flags=re.I)
    return s


def patron(cmd, cwd):
    """Esqueleto del comando para la caché: comando + flags literales, argumentos como marcadores."""
    home = base_dir()
    partes = []
    for crudo in trocear(cmd):
        toks = tokens(normalizar(crudo))
        if not toks:
            continue
        sal = [toks[0].lower()]
        for i, t in enumerate(toks[1:], 1):
            tl = t.lower()
            if re.match(r"^\d?>>?$", t):
                sal.append(t)
            elif tl.startswith("-"):
                sal.append(tl.split("=", 1)[0] + ("=<V>" if "=" in tl else ""))
            elif re.match(r"^/[a-z?]{1,2}$", tl):
                sal.append(tl)
            elif t[:1] in "\"'":
                sal.append("<TXT>")
            elif re.match(r"^\d+(\.\d+)?$", t):
                sal.append("<N>")
            elif es_rutaish(t) or ".." in t:
                sal.append("<RUTA_INT>" if dentro(t, cwd, home) else "<RUTA_EXT>")
            elif i == 1 and re.match(r"^[a-z][a-z0-9-]*$", tl):
                sal.append(tl)
            else:
                sal.append("<ARG>")
        partes.append(" ".join(sal))
    return " ; ".join(partes)


def fnv1a(s):
    h = 0x811C9DC5
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return "%08x" % h


# --------------------------------------------------------------------------- caché


def cargar_cache():
    return leer_json(rutas()["cache"], {})


def guardar_cache(c):
    try:
        escribir_json(rutas()["cache"], c)
    except Exception:
        pass


def consultar_cache(cfg, cache, pat):
    e = cache.get(pat)
    if not e or e.get("estado") == "revocada":
        return None
    if e.get("estado") == "regla":
        return e
    f = leer_iso(e.get("fecha", ""))
    if not f or ahora() - f > timedelta(days=int(cfg["cache"].get("ttl_dias", 30))):
        return None
    return e


def actualizar_cache(cfg, cache, pat, p, ejemplo, aprobado, modelo):
    e = cache.get(pat) or {"id": fnv1a(pat), "n_visto": 0, "n_aprobado": 0, "estado": "cache"}
    e.update({"reversible": round(p, 4), "fecha": iso(), "modelo": modelo, "ejemplo": ejemplo[:300]})
    e["n_visto"] = int(e.get("n_visto", 0)) + 1
    if aprobado:
        e["n_aprobado"] = int(e.get("n_aprobado", 0)) + 1
    if (e.get("estado") == "cache" and e["n_aprobado"] >= int(cfg["cache"].get("promover_tras", 5))
            and p >= float(cfg["cache"].get("promover_min", 0.95))):
        e["estado"] = "propuesta"
    if e.get("estado") == "propuesta" and p < float(cfg["cache"].get("promover_min", 0.95)):
        e["estado"] = "cache"
    cache[pat] = e


# --------------------------------------------------------------------------- preguntas


def q_reversible():
    return {"type": "noul",
            "instructions": ("Cada comando de `commands` solo lee o cambia ficheros dentro de `project` y puede "
                             "deshacerse con git o repitiéndolo. No publica, no despliega, no borra fuera del "
                             "proyecto, no cambia la configuración del sistema ni envía datos a un servicio de red. "
                             "Los marcadores entre <> son datos redactados por privacidad."),
            "criteria": {"true": "Todos los comandos son locales al proyecto, reversibles e inocuos.",
                         "false": "Algún comando actúa fuera del proyecto, es irreversible, cambia el sistema o usa la red."}}


def q_serves_task():
    return {"type": "noul",
            "instructions": "Ejecutar `commands` es un siguiente paso razonable hacia `task`.",
            "criteria": {"true": "Los comandos encajan con la tarea descrita.",
                         "false": "Los comandos no tienen relación clara con la tarea o la exceden."}}


def sistema_state(cfg):
    s = cfg.get("sistema") or {}
    return {"os": s.get("os", ""), "distro": s.get("distro", ""), "init": s.get("init", ""), "shell": s.get("shell", "")}


# --------------------------------------------------------------------------- salida del hook


def emitir(cfg, permitir, mensaje):
    out = {}
    if cfg.get("mostrar_criterio", True) and mensaje:
        out["systemMessage"] = mensaje
    if permitir:
        out["hookSpecificOutput"] = {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}
    if out:
        sys.stdout.write(json.dumps(out, ensure_ascii=False))
        sys.stdout.flush()


def cmd_hook(args):
    """Hook PermissionRequest. Cualquier fallo -> salir 0 sin salida (aviso normal)."""
    t0 = time.monotonic()
    try:
        crudo = sys.stdin.buffer.read().decode("utf-8-sig")
        ev = json.loads(crudo)
    except Exception:
        return 0
    cfg = cargar_config()
    if not cfg.get("activo") or not cfg["modulos"].get("permisos_shell", True):
        return 0
    reglas = cargar_reglas()
    if not reglas:
        registrar({"modulo": "permisos", "origen": "error", "error": "reglas.json ilegible"})
        return 0
    herr = ev.get("tool_name", "")
    if herr not in ("Bash", "PowerShell"):
        return 0
    ti = ev.get("tool_input") or {}
    cmd = str(ti.get("command") or "")
    desc = str(ti.get("description") or "")
    cwd = str(ev.get("cwd") or os.getcwd())
    base = {"modulo": "permisos", "herramienta": herr}
    if not cmd.strip():
        return 0
    if timeout_forzado := args.timeout:
        cfg["timeout_s"] = timeout_forzado
    # 1) Lista estática: frontera de seguridad
    est = chequeo_estatico(cmd, cwd, cfg, reglas)
    if est:
        registrar(dict(base, origen="estatico", regla=est[0], motivo=est[1], decision="ask",
                       comando=redactar(cmd, cfg, reglas)[:300]))
        emitir(cfg, False, "[JEV] aviso normal · estático: %s" % est[1])
        return 0
    red = redactar(cmd, cfg, reglas)
    pat = patron(cmd, cwd)
    th = cfg["approve_threshold"]
    modo = cfg["red"].get("modo", "nuevo_y_sync")
    # 2) Caché de criterio (local-first)
    cache = cargar_cache()
    if modo != "online":
        e = consultar_cache(cfg, cache, pat)
        if e:
            if e.get("estado") == "regla":
                registrar(dict(base, origen="regla", patron=pat, pid=e["id"], decision="allow", comando=red[:300]))
                emitir(cfg, True, "[JEV] permitido · regla local %s · %s" % (e["id"], pat[:80]))
                return 0
            p = float(e.get("reversible", 0))
            ok = p >= th
            registrar(dict(base, origen="cache", patron=pat, pid=e["id"], respuestas={"reversible": p},
                           decision="allow" if ok else "ask", comando=red[:300]))
            emitir(cfg, ok, "[JEV] %s · caché %s · reversible %.2f%s · %s" % (
                "permitido" if ok else "aviso normal", e["id"], p, "" if ok else " (< %.2f)" % th, e.get("fecha", "")[:10]))
            return 0
    if modo == "solo_sync":
        estado = cargar_estado()
        estado.setdefault("pendientes", {})[pat] = red[:300]
        guardar_estado(estado)
        registrar(dict(base, origen="cola", patron=pat, decision="ask", comando=red[:300]))
        emitir(cfg, False, "[JEV] aviso normal · patrón nuevo en cola para el próximo sync")
        return 0
    # 3) Consulta a JEV (fail-closed)
    estado = cargar_estado()
    if suspendido(cfg, estado):
        registrar(dict(base, origen="error", error="cortacircuitos", patron=pat, decision="ask"))
        return 0
    state = {"commands": [redactar(s, cfg, reglas) for s in trocear(cmd)],
             "project": redactar(cwd, cfg, reglas), "system": sistema_state(cfg)}
    preguntas = {"reversible": q_reversible()}
    if desc.strip():
        state["task"] = redactar(desc, cfg, reglas)[:500]
        preguntas["serves_task"] = q_serves_task()
    try:
        resp, lat = llamar_jev(cfg, state, preguntas)
        ps = {q: prob(resp, q) for q in preguntas}
    except ErrorJEV as e:
        if str(e) != "sin_key":
            anotar_fallo(cfg, estado)
        registrar(dict(base, origen="error", error=str(e), patron=pat, decision="ask",
                       latencia_ms=int((time.monotonic() - t0) * 1000)))
        return 0
    anotar_exito(estado)
    ok = all(v >= th for v in ps.values())
    actualizar_cache(cfg, cache, pat, ps["reversible"], red, ok, resp.get("model", ""))
    guardar_cache(cache)
    registrar(dict(base, origen="jev", patron=pat, pid=fnv1a(pat), respuestas=ps, decision="allow" if ok else "ask",
                   id=resp.get("id"), modelo=resp.get("model"), latencia_ms=lat, coste=coste(resp), comando=red[:300]))
    det = " · ".join("%s %.2f" % ("reversible" if k == "reversible" else "tarea", v) for k, v in ps.items())
    emitir(cfg, ok, "[JEV] %s · jev · %s%s · %d ms" % ("permitido" if ok else "aviso normal", det,
                                                      "" if ok else " (umbral %.2f)" % th, lat))
    return 0


# --------------------------------------------------------------------------- sync por lotes


def cmd_sync(args):
    sincronizar(bool(getattr(args, "todo", False)), silencioso=False)
    return 0


def sincronizar(todo, silencioso=False):
    cfg = cargar_config()
    reglas = cargar_reglas() or {}
    estado = cargar_estado()
    if suspendido(cfg, estado):
        if not silencioso:
            print("JEV suspendido por cortacircuitos hasta %s" % estado.get("suspendido_hasta"))
        return None
    cache = cargar_cache()
    limite = ahora() - timedelta(days=int(cfg["red"].get("sync_dias", 7)))
    trabajo = {}
    for pat, ej in (estado.get("pendientes") or {}).items():
        trabajo[pat] = ej
    for pat, e in cache.items():
        if e.get("estado") in ("regla", "revocada"):
            continue
        f = leer_iso(e.get("fecha", ""))
        if todo or not f or f < limite:
            trabajo[pat] = e.get("ejemplo", pat)
    if not trabajo:
        estado["ultimo_sync"] = iso()
        guardar_estado(estado)
        if not silencioso:
            print("Sync: nada que revalidar.")
        return None
    items = list(trabajo.items())
    hechos = coste_total = 0
    for i in range(0, len(items), LOTE_SYNC):
        lote = items[i:i + LOTE_SYNC]
        state = {"commands": {}, "project": "directorio de trabajo del usuario", "system": sistema_state(cfg)}
        preguntas = {}
        for j, (pat, ej) in enumerate(lote):
            cid = "c%d" % j
            state["commands"][cid] = redactar(ej, cfg, reglas)
            q = q_reversible()
            q["instructions"] = q["instructions"].replace("Cada comando de `commands`", "El comando `commands.%s`" % cid)
            preguntas[cid] = q
        try:
            resp, lat = llamar_jev(cfg, state, preguntas, timeout=max(float(cfg.get("timeout_s", 8)), 15))
        except ErrorJEV as e:
            anotar_fallo(cfg, estado)
            registrar({"modulo": "sync", "origen": "error", "error": str(e)})
            if not silencioso:
                print("Sync interrumpido: %s" % e)
            break
        coste_total += coste(resp)
        for j, (pat, ej) in enumerate(lote):
            try:
                p = prob(resp, "c%d" % j)
            except ErrorJEV:
                continue
            actualizar_cache(cfg, cache, pat, p, ej, p >= cfg["approve_threshold"], resp.get("model", ""))
            cache[pat]["n_visto"] -= 1  # el sync no cuenta como uso
            if p >= cfg["approve_threshold"]:
                cache[pat]["n_aprobado"] -= 1
            (estado.get("pendientes") or {}).pop(pat, None)
            hechos += 1
        registrar({"modulo": "sync", "origen": "jev", "id": resp.get("id"), "modelo": resp.get("model"),
                   "latencia_ms": lat, "coste": coste(resp), "patrones": len(lote)})
    guardar_cache(cache)
    estado = dict(cargar_estado(), pendientes=estado.get("pendientes", {}), ultimo_sync=iso())
    anotar_exito(estado)
    guardar_estado(estado)
    msg = "Sync JEV: %d patrones revalidados en %d petición(es), coste %.6f $" % (
        hechos, (len(items) + LOTE_SYNC - 1) // LOTE_SYNC, coste_total)
    if not silencioso:
        print(msg)
    return msg


def cmd_sesion(args):
    """Hook SessionStart: sync semanal si toca. Silencio ante cualquier fallo."""
    try:
        sys.stdin.read()
    except Exception:
        pass
    try:
        cfg = cargar_config()
        if not cfg.get("activo") or cfg["red"].get("modo") == "online" or not cargar_key():
            return 0
        est = cargar_estado()
        u = leer_iso(est.get("ultimo_sync") or "")
        if u and ahora() - u < timedelta(days=int(cfg["red"].get("sync_dias", 7))):
            return 0
        msg = sincronizar(False, silencioso=True)
        if msg and cfg.get("mostrar_criterio", True):
            sys.stdout.write(json.dumps({"systemMessage": "[JEV] " + msg}, ensure_ascii=False))
    except Exception:
        pass
    return 0


# --------------------------------------------------------------------------- primitivas CLI


def leer_state(valor):
    if valor.startswith("@"):
        with open(valor[1:], "r", encoding="utf-8-sig") as f:
            txt = f.read()
    else:
        txt = valor
    try:
        return json.loads(txt)
    except ValueError:
        return {"texto": txt}


def imprimir(d):
    print(json.dumps(d, ensure_ascii=False))


def ejecutar_primitiva(tipo, state, pregunta, modulo, timeout=None):
    cfg = cargar_config()
    try:
        resp, lat = llamar_jev(cfg, state, {"q": pregunta}, timeout=timeout)
        a = resp["answers"]["q"]
        if tipo == "noul":
            ans, conf = prob(resp, "q"), None
        elif tipo == "choice":
            ans, conf = a.get("choice"), float(a.get("confidence", 0))
        else:
            ans, conf = float(a.get("score")), float(a.get("confidence", 0))
        out = {"ok": True, "answer": ans, "confidence": conf, "latency_ms": lat, "cost": coste(resp),
               "id": resp.get("id"), "model": resp.get("model")}
        if tipo != "noul":
            out["probabilities"] = a.get("probabilities")
    except (ErrorJEV, KeyError, TypeError, ValueError) as e:
        out = {"ok": False, "error": str(e), "answer": None, "confidence": None, "latency_ms": None,
               "cost": 0, "id": None, "model": None}
    registrar({"modulo": modulo, "origen": "jev" if out["ok"] else "error", "tipo": tipo, "respuesta": out.get("answer"),
               "confianza": out.get("confidence"), "id": out.get("id"), "modelo": out.get("model"),
               "latencia_ms": out.get("latency_ms"), "coste": out.get("cost"), "error": out.get("error")})
    return out


def cmd_primitiva(args):
    state = leer_state(args.state)
    if args.tipo == "noul":
        q = {"type": "noul", "instructions": args.instructions,
             "criteria": {"true": args.true or "Sí.", "false": args.false or "No."}}
    elif args.tipo == "choice":
        q = {"type": "choice", "instructions": args.instructions, "criteria": json.loads(args.criteria)}
    else:
        q = {"type": "score", "instructions": args.instructions, "criteria": json.loads(args.criteria)}
    out = ejecutar_primitiva(args.tipo, state, q, "cli", timeout=args.timeout)
    imprimir(out)
    return 0 if out["ok"] else 1


def cmd_ping(args):
    out = ejecutar_primitiva("noul", {"texto": "ping"}, {
        "type": "noul", "instructions": "El texto de `texto` es la palabra ping.",
        "criteria": {"true": "Es la palabra ping.", "false": "No lo es."}}, "ping", timeout=args.timeout)
    imprimir(out)
    return 0 if out["ok"] else 1


# --------------------------------------------------------------------------- router de skills


def frontmatter(ruta):
    try:
        with open(ruta, "r", encoding="utf-8-sig") as f:
            txt = f.read(8000)
    except Exception:
        return None
    m = re.match(r"^---\s*\n(.*?)\n---", txt, re.S)
    if not m:
        return None
    fm, datos, clave = m.group(1), {}, None
    for linea in fm.splitlines():
        mm = re.match(r"^([A-Za-z_-]+):\s*(.*)$", linea)
        if mm:
            clave = mm.group(1)
            v = mm.group(2).strip()
            datos[clave] = "" if v in (">-", ">", "|", "|-") else v.strip("\"'")
        elif clave and linea.startswith((" ", "\t")):
            datos[clave] = (datos[clave] + " " + linea.strip()).strip()
    return datos


def plugins_activos():
    s = leer_json(rutas()["settings"], {})
    ep = s.get("enabledPlugins") or {}
    return {k.split("@")[0].lower() for k, v in ep.items() if v}


def descubrir_skills(cwd=None):
    r = rutas()
    encontrados = {}
    bases = [r["skills"]]
    if cwd:
        bases.append(os.path.join(cwd, ".claude", "skills"))
    for b in bases:
        if os.path.isdir(b):
            for d in sorted(os.listdir(b)):
                fm = frontmatter(os.path.join(b, d, "SKILL.md"))
                if fm and fm.get("name"):
                    encontrados.setdefault(fm["name"], fm.get("description", ""))
    activos = plugins_activos()
    if activos and os.path.isdir(r["plugins"]):
        for raiz, dirs, files in os.walk(r["plugins"]):
            if "SKILL.md" in files and os.sep + "skills" + os.sep in raiz + os.sep:
                segs = [x.lower() for x in raiz.split(os.sep)]
                if activos & set(segs):
                    fm = frontmatter(os.path.join(raiz, "SKILL.md"))
                    if fm and fm.get("name"):
                        encontrados.setdefault(fm["name"], fm.get("description", ""))
    encontrados.pop("elige-skill", None)
    return encontrados


def sanear(n):
    return re.sub(r"[^a-z0-9_-]", "_", n.lower())[:60]


def cmd_route(args):
    cfg = cargar_config()
    reglas = cargar_reglas() or {}
    peticion = " ".join(args.peticion)
    skills = descubrir_skills(os.getcwd())
    criterios, mapa = {}, {}
    for n, d in skills.items():
        k = sanear(n)
        mapa[k] = n
        criterios[k] = (d or n)[:600]
    criterios["ninguna"] = "Ningún skill encaja; lo resuelve el Sistema 2"
    state = {"peticion": redactar(peticion, cfg, reglas), "sistema": sistema_state(cfg)}
    q = {"type": "choice", "instructions": "Elige el skill cuyo propósito mejor encaja con `peticion`.",
         "criteria": criterios}
    out = ejecutar_primitiva("choice", state, q, "router")
    th = float(cfg.get("router_min_confidence", 0.75))
    elegido = "ninguna"
    if out["ok"] and out["answer"] in mapa and (out["confidence"] or 0) >= th:
        elegido = mapa[out["answer"]]
    out["skill"] = elegido
    conf = "%.2f" % out["confidence"] if out.get("confidence") is not None else "-"
    lat = out.get("latency_ms") if out.get("latency_ms") is not None else "-"
    print("[JEV Router] -> Skill: %s | Confianza: %s | Tiempo: %sms" % (elegido, conf, lat))
    if args.json:
        imprimir(out)
    return 0


# --------------------------------------------------------------------------- panel


def leer_log(max_lineas=20000):
    r = rutas()
    lineas = []
    for p in (r["log"] + ".1", r["log"]):
        try:
            with open(p, "r", encoding="utf-8") as f:
                lineas.extend(f.readlines())
        except Exception:
            pass
    out = []
    for l in lineas[-max_lineas:]:
        try:
            out.append(json.loads(l))
        except Exception:
            pass
    return out


def cmd_panel(args):
    cfg = cargar_config()
    ents = leer_log()
    perm = [e for e in ents if e.get("modulo") == "permisos"]
    n = len(perm) or 1
    por = {}
    for e in perm:
        por[e.get("origen")] = por.get(e.get("origen"), 0) + 1
    aprob = sum(1 for e in perm if e.get("decision") == "allow")
    coste_total = sum(float(e.get("coste") or 0) for e in ents)
    lats = sorted(int(e["latencia_ms"]) for e in ents if e.get("origen") == "jev" and e.get("latencia_ms") is not None)
    red = sum(1 for e in ents if e.get("origen") == "jev")
    local = por.get("cache", 0) + por.get("regla", 0)
    est = cargar_estado()
    cache = cargar_cache()
    print("== JEV · panel (%s, perfil %s, runtime %s) ==" % ("ACTIVO" if cfg.get("activo") else "APAGADO",
                                                           cfg.get("perfil"), cfg.get("runtime")))
    print("Peticiones de permiso: %d | auto-aprobadas %.0f%% | estático %.0f%% | caché/regla %.0f%% | jev %.0f%% | error %.0f%%" % (
        len(perm), 100.0 * aprob / n, 100.0 * por.get("estatico", 0) / n, 100.0 * local / n,
        100.0 * por.get("jev", 0) / n, 100.0 * por.get("error", 0) / n))
    if lats:
        print("Llamadas a JEV: %d | latencia media %d ms | p95 %d ms | coste total %.6f $" % (
            red, sum(lats) // len(lats), lats[min(len(lats) - 1, int(len(lats) * 0.95))], coste_total))
    else:
        print("Llamadas a JEV: 0 | coste total %.6f $" % coste_total)
    print("Resueltas en local sin red: %d | Último sync: %s | Cortacircuitos: %s" % (
        local, est.get("ultimo_sync") or "nunca",
        ("suspendido hasta " + est["suspendido_hasta"]) if suspendido(cfg, est) else "ok"))
    props = [(p, e) for p, e in cache.items() if e.get("estado") == "propuesta"]
    reg = [(p, e) for p, e in cache.items() if e.get("estado") == "regla"]
    print("Caché: %d patrones | reglas locales %d | propuestas pendientes %d | en cola %d" % (
        len(cache), len(reg), len(props), len(est.get("pendientes") or {})))
    if props:
        print("\n-- Propuestas (confirmar con: reglas aprobar <id>) --")
        for p, e in props:
            print("  %s  rev %.2f  x%d  %s" % (e["id"], e.get("reversible", 0), e.get("n_aprobado", 0), p[:90]))
    ult = [e for e in ents if e.get("modulo") in ("permisos", "router", "sync")][-args.n:]
    if ult:
        print("\n-- Últimas %d decisiones (criterio) --" % len(ult))
        for e in ult:
            crit = e.get("regla") or e.get("error") or e.get("pid") or ""
            rs = e.get("respuestas") or {}
            probs = " ".join("%s=%.2f" % (k[:3], v) for k, v in rs.items())
            print("  %s %-8s %-6s %-5s %-22s %s %s" % (
                e.get("fecha", "")[5:16], e.get("origen", ""), e.get("decision", ""),
                e.get("herramienta", e.get("modulo", ""))[:5], str(crit)[:22], probs, (e.get("comando") or "")[:60]))
    return 0


def cmd_reglas(args):
    cache = cargar_cache()
    if args.accion == "listar":
        for p, e in sorted(cache.items(), key=lambda x: x[1].get("estado", "")):
            print("%s  %-9s rev %.2f  visto %d  aprob %d  %s" % (e.get("id"), e.get("estado"), e.get("reversible", 0),
                                                              e.get("n_visto", 0), e.get("n_aprobado", 0), p[:90]))
        return 0
    for p, e in cache.items():
        if e.get("id") == args.id:
            e["estado"] = "regla" if args.accion == "aprobar" else "revocada"
            e["confirmado"] = iso()
            guardar_cache(cache)
            registrar({"modulo": "reglas", "origen": "usuario", "accion": args.accion, "pid": args.id, "patron": p})
            print("Patrón %s -> %s: %s" % (args.id, e["estado"], p))
            return 0
    print("No existe el patrón %s" % args.id)
    return 1


# --------------------------------------------------------------------------- config CLI


def cmd_toggle(args):
    r = rutas()
    cfg = leer_json(r["config"], {})
    cfg.setdefault("modulos", {})
    if args.modulo not in CONFIG_DEF["modulos"]:
        print("Módulo desconocido. Válidos: %s" % ", ".join(CONFIG_DEF["modulos"]))
        return 1
    cfg["modulos"][args.modulo] = not cfg["modulos"].get(args.modulo, CONFIG_DEF["modulos"][args.modulo])
    escribir_json(r["config"], cfg)
    print("%s = %s" % (args.modulo, cfg["modulos"][args.modulo]))
    return 0


def cmd_activo(valor):
    r = rutas()
    cfg = leer_json(r["config"], {})
    cfg["activo"] = valor
    escribir_json(r["config"], cfg)
    print("JEV %s (los hooks siguen registrados; salen sin hacer nada si activo=false)" % ("ACTIVADO" if valor else "DESACTIVADO"))
    return 0


# --------------------------------------------------------------------------- diagnóstico


CA_PUBLICAS = ("google trust", "let's encrypt", "digicert", "sectigo", "globalsign", "amazon", "cloudflare",
               "isrg", "usertrust", "entrust", "godaddy", "microsoft", "baltimore", "comodo", "ssl.com")


def cmd_diag(args):
    cfg = cargar_config()
    r = rutas()
    print("JEV diag (python %s, %s)" % (sys.version.split()[0], sys.platform))
    print("  config: %s (%s)" % (r["config"], "ok" if os.path.exists(r["config"]) else "NO EXISTE"))
    print("  reglas: %s" % ("ok" if cargar_reglas() else "ILEGIBLE"))
    print("  key: %s" % ("presente" if cargar_key() else "AUSENTE"))
    from urllib.parse import urlparse
    u = urlparse(cfg["endpoint"])
    host, puerto = u.hostname, u.port or (443 if u.scheme == "https" else 80)
    px = cfg.get("proxy") or urllib.request.getproxies().get("https") or ""
    print("  proxy: %s" % (px or "ninguno (conexión directa)"))
    try:
        ip = socket.gethostbyname(host)
        print("  DNS %s -> %s" % (host, ip))
    except Exception as e:
        print("  DNS %s: FALLO (%s)" % (host, e.__class__.__name__))
    if u.scheme == "https" and not px:
        try:
            ctx = ssl.create_default_context(cafile=cfg["ca_bundle"] or None) if cfg.get("ca_bundle") else ssl.create_default_context()
            with socket.create_connection((host, puerto), timeout=5) as s:
                with ctx.wrap_socket(s, server_hostname=host) as ss:
                    cert = ss.getpeercert()
            emisor = dict(x[0] for x in cert.get("issuer", ()))
            nombre = "%s / %s" % (emisor.get("organizationName", "?"), emisor.get("commonName", "?"))
            insp = not any(c in nombre.lower() for c in CA_PUBLICAS)
            print("  TLS ok · emisor: %s%s" % (nombre, "  <- POSIBLE INSPECCIÓN SSL corporativa" if insp else ""))
        except ssl.SSLCertVerificationError:
            print("  TLS: certificado NO verificado -> inspección SSL; configura ca_bundle con la CA corporativa")
        except Exception as e:
            print("  TLS: FALLO (%s)" % e.__class__.__name__)
    try:
        req = urllib.request.Request(cfg["endpoint"], data=b"{}", method="POST", headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            print("  HTTP sin auth: %d (inesperado)" % resp.status)
    except urllib.error.HTTPError as e:
        cuerpo = e.read(400).decode("utf-8", "replace").lower()
        bloq = any(x in cuerpo for x in ("palo alto", "check point", "checkpoint", "blocked", "bloquead", "url filtering"))
        print("  HTTP sin auth: %d%s" % (e.code, " -> endpoint alcanzable" if e.code in (400, 401) and not bloq else
                                      "  <- POSIBLE BLOQUEO del cortafuegos (página de bloqueo)" if bloq else ""))
    except Exception as e:
        print("  HTTP: FALLO (%s)" % e.__class__.__name__)
    est = cargar_estado()
    print("  cortacircuitos: %s" % (("suspendido hasta " + est["suspendido_hasta"]) if suspendido(cfg, est) else "ok"))
    return 0


# --------------------------------------------------------------------------- main


def main(argv=None):
    ap = argparse.ArgumentParser(prog="jev.py", description="Cliente JEV (TypeSafe) para Claude Code")
    sp = ap.add_subparsers(dest="cmd")
    for t in ("noul", "choice", "score"):
        p = sp.add_parser(t)
        p.set_defaults(tipo=t)
        p.add_argument("--state", required=True, help="texto, JSON o @fichero.json")
        p.add_argument("--instructions", required=True)
        if t == "noul":
            p.add_argument("--true", default="")
            p.add_argument("--false", default="")
        else:
            p.add_argument("--criteria", required=True, help="JSON: objeto (choice) o lista (score)")
        p.add_argument("--timeout", type=float)
    p = sp.add_parser("ping")
    p.add_argument("--timeout", type=float)
    p = sp.add_parser("route")
    p.add_argument("peticion", nargs="+")
    p.add_argument("--json", action="store_true")
    p = sp.add_parser("hook")
    p.add_argument("--timeout", type=float)
    sp.add_parser("sesion")
    p = sp.add_parser("sync")
    p.add_argument("--todo", action="store_true")
    p = sp.add_parser("panel")
    p.add_argument("-n", "--n", dest="n", type=int, default=15)
    p = sp.add_parser("reglas")
    p.add_argument("accion", choices=["listar", "aprobar", "revocar"])
    p.add_argument("id", nargs="?")
    sp.add_parser("diag")
    p = sp.add_parser("toggle")
    p.add_argument("modulo")
    sp.add_parser("on")
    sp.add_parser("off")
    args = ap.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass
    if args.cmd == "hook":
        try:
            return cmd_hook(args)
        except BaseException:
            return 0  # fail-closed: nunca romper la sesión
    if args.cmd == "sesion":
        return cmd_sesion(args)
    tabla = {"noul": cmd_primitiva, "choice": cmd_primitiva, "score": cmd_primitiva, "ping": cmd_ping,
             "route": cmd_route, "sync": cmd_sync, "panel": cmd_panel, "reglas": cmd_reglas, "diag": cmd_diag,
             "toggle": cmd_toggle}
    if args.cmd == "on":
        return cmd_activo(True)
    if args.cmd == "off":
        return cmd_activo(False)
    if args.cmd in tabla:
        if args.cmd == "reglas" and args.accion != "listar" and not args.id:
            print("Falta el id del patrón")
            return 1
        return tabla[args.cmd](args) or 0
    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
