#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Banco de pruebas (Paso 6) para los dos runtimes: python y powershell.

Usa un HOME temporal (JEV_HOME) y el simulador mock_jev.py; nunca toca el ~/.claude real.
Uso: python3 ejecutar_pruebas.py [--solo python|powershell] [--real]
  --real  añade una llamada al endpoint real de OpenRouter con una key FALSA (debe fallar cerrado).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(AQUI, "..", "src", "jev")
PUERTO = 18779


def runtimes():
    rt = {"python": [sys.executable]}
    for ps in ("pwsh", "powershell"):
        if shutil.which(ps):
            rt["powershell"] = [ps, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
            break
    return rt


def preparar(dir_base, sistema, extra=None):
    jev = os.path.join(dir_base, ".claude", "jev")
    os.makedirs(jev, exist_ok=True)
    os.makedirs(os.path.join(dir_base, "proyecto"), exist_ok=True)
    for f in os.listdir(SRC):
        shutil.copy(os.path.join(SRC, f), jev)
    cfg = {"endpoint": "http://127.0.0.1:%d/api/alpha/decisions" % PUERTO, "sistema": sistema,
           "dominios_internos": ["empresa.es"]}
    cfg.update(extra or {})
    with open(os.path.join(dir_base, ".claude", "jev_config.json"), "w") as f:
        json.dump(cfg, f)
    return jev


def script(rt, jev, nombre):
    ext = ".py" if rt == "python" else ".ps1"
    return os.path.join(jev, nombre + ext)


def ejecutar(rt, base_cmd, jev, nombre, args, stdin=None, env=None):
    cmd = base_cmd + [script(rt, jev, nombre)] + args
    t0 = time.monotonic()
    p = subprocess.run(cmd, input=(stdin or "").encode(), capture_output=True, env=env, timeout=60)
    return p.returncode, p.stdout.decode("utf-8", "replace").strip(), p.stderr.decode("utf-8", "replace").strip(), \
        int((time.monotonic() - t0) * 1000)


def n_peticiones(reg):
    try:
        with open(reg) as f:
            return sum(1 for _ in f)
    except FileNotFoundError:
        return 0


def evento(herr, cmd, cwd, desc="revisar el proyecto"):
    return json.dumps({"session_id": "t", "hook_event_name": "PermissionRequest", "tool_name": herr,
                       "tool_input": {"command": cmd, "description": desc}, "cwd": cwd})


def main():
    solo = sys.argv[sys.argv.index("--solo") + 1] if "--solo" in sys.argv else None
    tmp = tempfile.mkdtemp(prefix="jev-pruebas-")
    reg = os.path.join(tmp, "peticiones.jsonl")
    mock = subprocess.Popen([sys.executable, os.path.join(AQUI, "mock_jev.py"), str(PUERTO), reg])
    time.sleep(0.8)
    filas = {}
    try:
        for rt, base_cmd in runtimes().items():
            if solo and rt != solo:
                continue
            res = filas.setdefault(rt, [])
            home = os.path.join(tmp, rt)
            jev = preparar(home, {"os": "windows", "distro": "Windows 11", "init": "windows-scm", "shell": "powershell"})
            env = dict(os.environ, JEV_HOME=home, OPENROUTER_API_KEY="clave-de-prueba-no-real")
            for v in ("USERDNSDOMAIN", "USERDOMAIN"):
                env.pop(v, None)
            proy = os.path.join(home, "proyecto")

            def hook(nombre, herr, cmd, espera, extra_args=None, e=env, jd=jev, cwd=proy):
                antes = n_peticiones(reg)
                rc, out, err, ms = ejecutar(rt, base_cmd, jd, "jev_permission_hook", extra_args or [],
                                            evento(herr, cmd, cwd), e)
                llamadas = n_peticiones(reg) - antes
                try:
                    d = json.loads(out) if out else {}
                except ValueError:
                    d = {"_crudo": out}
                allow = d.get("hookSpecificOutput", {}).get("decision", {}).get("behavior") == "allow"
                if espera == "allow":
                    ok = allow and rc == 0
                elif espera == "estatico":
                    ok = (not allow) and llamadas == 0 and rc == 0 and "estático" in d.get("systemMessage", "")
                elif espera == "cache":
                    ok = allow and llamadas == 0 and "caché" in d.get("systemMessage", "")
                elif espera == "silencio":
                    ok = out == "" and rc == 0
                else:  # ask
                    ok = (not allow) and rc == 0
                res.append((nombre, espera, ok, "%s | llamadas=%d | %d ms | %s" % (
                    "allow" if allow else "aviso", llamadas, ms, (d.get("systemMessage") or out or err)[:90])))
                return d

            # --- Paso 6.1 ping (simulador)
            rc, out, err, ms = ejecutar(rt, base_cmd, jev, "jev", ["ping"], env=env)
            try:
                d = json.loads(out)
            except ValueError:
                d = {}
            res.append(("ping (simulador)", "ok", bool(d.get("ok")),
                        "modelo %s | %s ms | coste %s" % (d.get("model"), d.get("latency_ms"), d.get("cost"))))
            # --- Paso 6.2 router en seco
            rc, out, err, ms = ejecutar(rt, base_cmd, jev, "jev", ["route", "reinicia el servicio de red local"], env=env)
            res.append(("/elige-skill 'reinicia el servicio de red local'", "ninguna", "Skill: ninguna" in out, out[:90] or err[:90]))
            # --- Paso 6.3 hook
            hook("ls -la /var/log", "Bash", "ls -la /var/log", "allow")
            hook("git status", "Bash", "git status", "allow")
            hook("sudo sv restart networking", "Bash", "sudo sv restart networking", "estatico")
            hook("cat ~/.ssh/id_ed25519", "Bash", "cat ~/.ssh/id_ed25519", "estatico")
            hook("timeout forzado 0,001 s", "Bash", "git log --oneline -5", "silencio", ["--timeout", "0.001"])
            hook("ls -la /var/log (2ª vez)", "Bash", "ls -la /var/log", "cache")
            hook("PS Get-ChildItem -Recurse src", "PowerShell", "Get-ChildItem -Recurse src", "allow")
            hook("PS Get-ADUser -Filter *", "PowerShell", "Get-ADUser -Filter * -Server dc01.empresa.corp", "estatico")
            hook("PS Remove-Item -Recurse -Force C:\\temp", "PowerShell", "Remove-Item -Recurse -Force C:\\temp", "estatico")
            hook("PS Set-MpPreference -ExclusionPath C:\\", "PowerShell", "Set-MpPreference -ExclusionPath C:\\", "estatico")
            hook("PS Invoke-WebRequest (red)", "PowerShell", "Invoke-WebRequest https://ejemplo.com -OutFile x.zip", "estatico")
            hook("echo hola > /etc/x (fuera de cwd)", "Bash", "echo hola > /etc/x", "estatico")
            hook("ruta excluida UNC", "PowerShell", "Get-ChildItem \\\\srvfich01\\compartido", "estatico")
            hook("npm test (JEV duda)", "Bash", "npm test", "ask")
            antes = n_peticiones(reg)
            hook("redacción: git log autor/IP", "Bash", "git log --author=juan.perez@empresa.es -- srv01.empresa.es 10.20.30.40.txt", "allow")
            enviado = ""
            with open(reg) as f:
                lineas = f.readlines()
            if len(lineas) > antes:
                enviado = json.dumps(json.loads(lineas[-1])["state"], ensure_ascii=False)
            fuga = any(x in enviado for x in ("juan.perez", "empresa.es", "srv01", "10.20.30.40"))
            res.append(("  └ nada sensible sale a JEV", "sin fuga", bool(enviado) and not fuga, enviado[:90]))
            # coherencia de init: sistema runit
            home2 = os.path.join(tmp, rt + "-runit")
            jev2 = preparar(home2, {"os": "linux", "distro": "antiX", "init": "runit", "shell": "bash"})
            env2 = dict(env, JEV_HOME=home2)
            hook("systemctl restart NetworkManager (runit)", "Bash", "systemctl restart NetworkManager", "estatico",
                 e=env2, jd=jev2, cwd=os.path.join(home2, "proyecto"))
            # sin key -> silencio
            env3 = dict(env)
            env3.pop("OPENROUTER_API_KEY")
            hook("sin key", "Bash", "git diff --stat", "silencio", e=env3)
            # cortacircuitos: endpoint caído
            home4 = os.path.join(tmp, rt + "-caido")
            jev4 = preparar(home4, {"os": "windows", "init": "windows-scm"},
                            {"endpoint": "http://127.0.0.1:9/api/alpha/decisions"})
            env4 = dict(env, JEV_HOME=home4)
            c4 = os.path.join(home4, "proyecto")
            hook("endpoint caído (fallo 1)", "Bash", "git diff", "silencio", e=env4, jd=jev4, cwd=c4)
            hook("endpoint caído (fallo 2)", "Bash", "git show", "silencio", e=env4, jd=jev4, cwd=c4)
            with open(os.path.join(home4, ".claude", "jev", "estado.json")) as f:
                susp = json.load(f).get("suspendido_hasta", "")
            res.append(("  └ cortacircuitos abierto tras 2 fallos", "suspendido", bool(susp), "hasta " + susp))
            # entrada ilegible
            rc, out, err, ms = ejecutar(rt, base_cmd, jev, "jev_permission_hook", [], "esto no es json", env)
            res.append(("stdin ilegible", "silencio", out == "" and rc == 0, "rc=%d" % rc))
            # sync por lotes y panel
            rc, out, err, ms = ejecutar(rt, base_cmd, jev, "jev", ["sync", "--todo"], env=env)
            res.append(("sync --todo (1 petición por lote)", "ok", "revalidados" in out, out[:90] or err[:90]))
            rc, out, err, ms = ejecutar(rt, base_cmd, jev, "jev", ["panel"], env=env)
            res.append(("/jev-panel", "ok", rc == 0 and "Peticiones de permiso" in out, out.splitlines()[1][:90] if out else err[:90]))
            if "--real" in sys.argv:
                home5 = os.path.join(tmp, rt + "-real")
                jev5 = preparar(home5, {"os": "windows"}, {"endpoint": "https://openrouter.ai/api/alpha/decisions"})
                env5 = dict(env, JEV_HOME=home5)
                rc, out, err, ms = ejecutar(rt, base_cmd, jev5, "jev", ["ping"], env=env5)
                try:
                    d = json.loads(out)
                except ValueError:
                    d = {}
                res.append(("ping REAL con key falsa", "http_401", d.get("error") == "http_401", "%s | %d ms" % (d.get("error"), ms)))
    finally:
        mock.terminate()
    # tabla
    rts = list(filas)
    nombres = [f[0] for f in filas[rts[0]]]
    print("| Prueba | Esperado | " + " | ".join(rts) + " |")
    print("|---|---|" + "---|" * len(rts))
    total = fallos = 0
    for i, n in enumerate(nombres):
        celdas = []
        for rt in rts:
            f = filas[rt][i]
            total += 1
            fallos += 0 if f[2] else 1
            celdas.append(("✅ " if f[2] else "❌ ") + f[3].replace("|", "/")[:70])
        print("| %s | %s | %s |" % (n, filas[rts[0]][i][1], " | ".join(celdas)))
    print("\n%d/%d correctas" % (total - fallos, total))
    shutil.rmtree(tmp, ignore_errors=True)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
