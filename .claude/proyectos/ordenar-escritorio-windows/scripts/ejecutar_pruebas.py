#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ejecutar_pruebas.py — Verifica ordenar_archivos.py y Ordenar-Archivos.ps1 con los casos a–h
del README, SIEMPRE en sandboxes temporales nuevos (nunca contra el Escritorio real).

Uso:
  py ejecutar_pruebas.py                 prueba Python y, si encuentra pwsh/powershell, PowerShell
  py ejecutar_pruebas.py --solo py|ps
  py ejecutar_pruebas.py --ps "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"

El caso f (archivo bloqueado) usa FileShare.None en Windows y chmod 000 fuera de Windows
(en Linux/macOS hay que ejecutarlo con un usuario que NO sea root).
"""
import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import crear_sandbox  # noqa: E402

ES_WINDOWS = os.name == "nt"
RESULTADOS: list[tuple[str, str, bool, str]] = []


def arbol(ruta: str) -> list[str]:
    res = []
    for raiz, dirs, archivos in os.walk(ruta):
        for n in dirs + archivos:
            res.append(os.path.relpath(os.path.join(raiz, n), ruta))
    return sorted(res)


def carpetas_vacias(ruta: str) -> list[str]:
    return [r for r, d, a in os.walk(ruta) if not d and not a]


class Impl:
    def __init__(self, nombre: str, base_cmd: list[str], estilo: str):
        self.nombre, self.base, self.estilo = nombre, base_cmd, estilo

    def args(self, **kw) -> list[str]:
        """Traduce opciones comunes a la sintaxis de cada script."""
        out = []
        for k, v in kw.items():
            if self.estilo == "py":
                flag = "--" + k.replace("_", "-")
                if k == "whatif":
                    flag = "--dry-run"
            else:
                flag = "-" + "".join(p.capitalize() for p in k.split("_"))
                if k == "whatif":
                    flag = "-WhatIf"
            if v is True:
                out.append(flag)
            else:
                out += [flag, str(v)]
        return out

    def run(self, **kw) -> tuple[int, str, str | None]:
        cmd = self.base + self.args(**kw)
        p = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env={**os.environ, "NO_COLOR": "1"})
        salida = p.stdout + p.stderr
        m = re.findall(r"(\S[^\r\n]*?\.csv)\s*$", salida, re.MULTILINE)
        return p.returncode, salida, (m[-1].strip() if m else None)


def filas_csv(ruta: str) -> list[dict]:
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter=";"))


def comprobar(impl: Impl, caso: str, ok: bool, detalle: str = "") -> None:
    RESULTADOS.append((impl.nombre, caso, ok, detalle))
    print(f"  [{'OK ' if ok else 'FALLO'}] {caso}" + (f" — {detalle}" if detalle and not ok else ""))


def nuevo_sandbox() -> tuple[str, str, str]:
    base = tempfile.mkdtemp(prefix="sbx_ordenar_")
    crear_sandbox.crear(base)
    return base, os.path.join(base, "origen"), os.path.join(base, "destino")


def lp_borrar(ruta: str) -> str:
    """Ruta apta para borrar árboles con rutas largas en Windows."""
    return "\\\\?\\" + os.path.abspath(ruta) if ES_WINDOWS else ruta


def bloquear(ruta: str):
    """Deja un archivo ilegible. Devuelve un 'deshacer'."""
    if ES_WINDOWS:
        import ctypes
        GENERIC_READ, OPEN_EXISTING = 0x80000000, 3
        h = ctypes.windll.kernel32.CreateFileW(ruta, GENERIC_READ, 0, None, OPEN_EXISTING, 0, None)
        return lambda: ctypes.windll.kernel32.CloseHandle(h)
    os.chmod(ruta, 0)
    return lambda: os.chmod(ruta, 0o644)


def pruebas(impl: Impl) -> None:
    print(f"\n=== {impl.nombre} ===")
    Z = "zOrdenado"

    # a) Simulación (y aplicar + whatif/dry-run) no crea nada en el destino
    base, o, d = nuevo_sandbox()
    antes = arbol(d)
    rc1, out1, _ = impl.run(origen=o, destino=d)
    rc2, out2, _ = impl.run(origen=o, destino=d, aplicar=True, whatif=True, si=True)
    comprobar(impl, "a) simulación no crea nada", rc1 == 0 and rc2 == 0 and arbol(d) == antes,
              f"rc={rc1},{rc2} cambios={set(arbol(d)) ^ set(antes)}")

    # b) Copia
    origen_antes = arbol(o)
    rc, out, ruta_csv = impl.run(origen=o, destino=d, aplicar=True, si=True)
    dz = os.path.join(d, Z)
    esperados = [os.path.join("PDF", "informe (1).pdf"), os.path.join("PDF", "informe (2).pdf"),
                 os.path.join("zOtros", "sinextension"),
                 os.path.join("Certificados y claves", "cert.p12"),
                 os.path.join("Certificados y claves", "cert.key"),
                 os.path.join("Textos", "a[1].txt"), os.path.join("Textos", "año ñ 😀.txt")]
    faltan = [e for e in esperados if not os.path.isfile(os.path.join(dz, e))]
    contenido = arbol(dz)
    apartados = not any(os.path.basename(x).casefold() in ("desktop.ini", "~$acta.docx") for x in contenido)
    comprobar(impl, "b) copia correcta, origen intacto, (n), ocultos/~$ apartados, sensibles avisados",
              rc == 0 and not faltan and apartados and arbol(o) == origen_antes and "SENSIBLE" in out,
              f"rc={rc} faltan={faltan} apartados={apartados}\n{out[-1500:]}")

    # h) CSV con una fila por archivo y sin subcarpetas vacías
    n_arch = len([n for n in os.listdir(o) if os.path.isfile(os.path.join(o, n))])
    filas = filas_csv(ruta_csv) if ruta_csv and os.path.isfile(ruta_csv) else []
    origenes = [f["Origen"] for f in filas if f["Accion"] in ("copiar", "mover", "omitir")]
    vacias = carpetas_vacias(dz)
    comprobar(impl, "h) CSV una fila por archivo y sin carpetas vacías",
              len(origenes) == n_arch == len(set(origenes)) and not vacias,
              f"filas={len(origenes)} archivos={n_arch} vacías={vacias}")
    shutil.rmtree(base, ignore_errors=True)

    # c) EXCLUIR + INCLUIR SOLO
    base, o, d = nuevo_sandbox()
    rc, out, _ = impl.run(origen=o, destino=d, excluir="*.p12, Warp.lnk", incluir_solo=".pdf,.md",
                          aplicar=True, si=True)
    copiados = {os.path.basename(x) for x in arbol(os.path.join(d, Z))
                if os.path.isfile(os.path.join(d, Z, x)) and not x.startswith("_logs")}
    comprobar(impl, "c) EXCLUIR e INCLUIR SOLO se aplican",
              rc == 0 and copiados == {"informe.pdf", "informe (1).pdf", "informe (2).pdf", "notas.md"},
              f"rc={rc} copiados={copiados}")
    shutil.rmtree(base, ignore_errors=True)

    # d) Carpetas=Copiar y conflicto con Recursivo
    base, o, d = nuevo_sandbox()
    rc, out, _ = impl.run(origen=o, destino=d, carpetas="Copiar", aplicar=True, si=True)
    ok1 = os.path.isfile(os.path.join(d, Z, "Carpetas", "Proyecto X", "plan.docx")) and \
        os.path.isdir(os.path.join(o, "Proyecto X"))
    rc2, out2, _ = impl.run(origen=o, destino=d, carpetas="Copiar", recursivo=True)
    comprobar(impl, "d) Carpetas=Copiar y conflicto con Recursivo (sale 2)", rc == 0 and ok1 and rc2 == 2,
              f"rc={rc} copiada={ok1} rc_conflicto={rc2}")
    shutil.rmtree(base, ignore_errors=True)

    # e) Mover con la contenedora dentro del origen: la segunda pasada procesa 0
    base, o, d = nuevo_sandbox()
    rc1, out1, _ = impl.run(origen=o, modo="Mover", aplicar=True, si=True)
    rc2, out2, _ = impl.run(origen=o, modo="Mover", aplicar=True, si=True)
    quedan = [n for n in os.listdir(o) if os.path.isfile(os.path.join(o, n))]
    comprobar(impl, "e) Mover dentro del origen; 2.ª pasada procesa 0",
              rc1 == 0 and rc2 == 0 and "nada que procesar" in out2.lower()
              and sorted(quedan) == ["desktop.ini", "~$acta.docx"],
              f"rc={rc1},{rc2} quedan={quedan}")
    shutil.rmtree(base, ignore_errors=True)

    # f) Archivo bloqueado → NO CRÍTICO y sigue
    if not ES_WINDOWS and os.geteuid() == 0:
        comprobar(impl, "f) archivo bloqueado (omitido: ejecutar sin root)", True)
    else:
        base, o, d = nuevo_sandbox()
        deshacer = bloquear(os.path.join(o, "log.txt"))
        try:
            rc, out, ruta_csv = impl.run(origen=o, destino=d, aplicar=True, si=True)
        finally:
            deshacer()
        filas = filas_csv(ruta_csv) if ruta_csv and os.path.isfile(ruta_csv) else []
        err = [f for f in filas if f["Origen"].endswith("log.txt") and f["Severidad"] == "no-critico"]
        sigue = os.path.isfile(os.path.join(d, Z, "Markdown", "notas.md"))
        comprobar(impl, "f) archivo bloqueado = NO CRÍTICO y sigue (sale 1)", rc == 1 and len(err) == 1 and sigue,
                  f"rc={rc} filas_error={len(err)} sigue={sigue}")
        shutil.rmtree(base, ignore_errors=True)

    # i) Destino dentro del origen + Mover + Recursivo: no se ordena a sí mismo
    base, o, d = nuevo_sandbox()
    dd = os.path.join(o, "0.Escritorio ORDENAR")
    os.makedirs(os.path.join(dd, "previo"))
    with open(os.path.join(dd, "previo", "ya.pdf"), "wb") as f:
        f.write(b"%PDF previo")
    rc1, out1, _ = impl.run(origen=o, destino=dd, modo="Mover", recursivo=True, aplicar=True, si=True)
    rc2, out2, _ = impl.run(origen=o, destino=dd, modo="Mover", recursivo=True, aplicar=True, si=True)
    intacto = os.path.isfile(os.path.join(dd, "previo", "ya.pdf"))
    movido = os.path.isfile(os.path.join(dd, Z, "Documentos", "plan.docx"))
    comprobar(impl, "i) destino dentro del origen (Mover+Recursivo) no se reordena; 2.ª pasada procesa 0",
              rc1 == 0 and rc2 == 0 and intacto and movido and "nada que procesar" in out2.lower(),
              f"rc={rc1},{rc2} intacto={intacto} movido={movido}")
    shutil.rmtree(base, ignore_errors=True)

    # j) Ruta demasiado larga dentro del origen (recursivo): se registra y se sigue, nunca aborta
    base, o, d = nuevo_sandbox()
    seg = "carpeta_con_nombre_muy_largo_" + "x" * 200
    largo = os.path.join(o, "profunda")
    os.makedirs(largo)
    previo = os.getcwd()
    try:
        if ES_WINDOWS:
            ruta = "\\\\?\\" + largo + ("\\" + seg) * 3        # ~700 caracteres > MAX_PATH
            os.makedirs(ruta)
            open(ruta + "\\profundo.pdf", "wb").close()
        else:
            os.chdir(largo)                                       # relativo para superar PATH_MAX
            for _ in range(22):
                os.mkdir(seg)
                os.chdir(seg)
            open("profundo.pdf", "wb").close()
    finally:
        os.chdir(previo)
    rc, out, _ = impl.run(origen=o, destino=d, recursivo=True)
    comprobar(impl, "j) ruta demasiado larga se omite con aviso y el proceso sigue (sale 0)",
              rc == 0 and "SIMULACI" in out and "inesperado" not in out,
              f"rc={rc}\n{out[-800:]}")
    shutil.rmtree(lp_borrar(base), ignore_errors=True)

    # g) Destino inexistente → 3; contenedora no válida → 2
    base, o, d = nuevo_sandbox()
    rc1, _, _ = impl.run(origen=o, destino=os.path.join(base, "no-existe"))
    rc2, _, _ = impl.run(origen=o, destino=d, contenedora="CON")
    rc3, _, _ = impl.run(origen=o, destino=d, contenedora="mal<nombre")
    comprobar(impl, "g) destino inexistente sale 3; contenedora no válida sale 2",
              rc1 == 3 and rc2 == 2 and rc3 == 2, f"rc={rc1},{rc2},{rc3}")
    shutil.rmtree(base, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--solo", choices=["py", "ps"])
    ap.add_argument("--ps", help="ruta a pwsh o powershell.exe")
    a = ap.parse_args()
    impls = []
    if a.solo in (None, "py"):
        impls.append(Impl("Python", [sys.executable, os.path.join(AQUI, "ordenar_archivos.py")], "py"))
    if a.solo in (None, "ps"):
        ps = a.ps or shutil.which("pwsh") or shutil.which("powershell")
        if ps:
            impls.append(Impl(f"PowerShell ({os.path.basename(ps)})",
                              [ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                               os.path.join(AQUI, "Ordenar-Archivos.ps1")], "ps"))
        else:
            print("AVISO: no se encuentra pwsh/powershell; se prueban solo los casos de Python.")
    for i in impls:
        pruebas(i)
    fallos = [r for r in RESULTADOS if not r[2]]
    print(f"\nTotal: {len(RESULTADOS)} comprobaciones, {len(fallos)} fallos.")
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
