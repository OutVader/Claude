#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
crear_sandbox.py — Crea un Escritorio de PRUEBA para ensayar ordenar_archivos.py y
Ordenar-Archivos.ps1 sin tocar nunca el Escritorio real.

Uso:  py crear_sandbox.py [ruta]      (por defecto, una carpeta nueva en %TEMP%)

Crea:
  <ruta>\\origen\\   archivos de ejemplo (accesos directos, PDF, duplicados, sensibles,
                     Unicode, corchetes, sin extensión, ~$, desktop.ini oculto, carpeta
                     "Proyecto X" con 2 archivos)
  <ruta>\\destino\\  con zOrdenado\\PDF\\informe.pdf ya existente (para probar "(1)")
Imprime la ruta creada en la última línea.
"""
import os
import sys
import tempfile

ARCHIVOS = {
    "Warp.lnk": b"LNK-FALSO-WARP",
    "Zoom.lnk": b"LNK-FALSO-ZOOM",
    "Acceso directo a Internet.url": b"[InternetShortcut]\r\nURL=https://example.org/\r\n",
    "WhatsApp Image 2026-09-30 at 10.12.33.jpeg": b"\xff\xd8\xff\xe0JPEG-FALSO",
    "informe.pdf": b"%PDF-1.7 informe",
    "informe (1).pdf": b"%PDF-1.7 informe",          # mismo contenido → duplicado por hash
    "acta_v2.docx": b"DOCX v2",
    "acta_v3.docx": b"DOCX v3 distinto",
    "notas.md": "# Notas\nñ áéíóú\n".encode("utf-8"),
    "log.txt": b"linea de log\n",
    "correo.msg": b"MSG-FALSO",
    "cert.p12": b"P12-FALSO-NO-ES-UN-CERTIFICADO",
    "cert.key": b"KEY-FALSA-NO-ES-UNA-CLAVE",
    "script.ps1": b"Write-Output 'hola'\r\n",
    "pack.rar": b"Rar!FALSO",
    "año ñ 😀.txt": "Unicode ñ 😀\n".encode("utf-8"),
    "a[1].txt": b"corchetes\n",
    "sinextension": b"sin extension\n",
    "~$acta.docx": b"temporal de Word",
    "desktop.ini": b"[.ShellClassInfo]\r\n",
}


def ocultar(ruta: str) -> None:
    """Marca como oculto+sistema en Windows (desktop.ini). Fuera de Windows no hace nada:
    el script lo excluye igualmente por nombre."""
    if os.name == "nt":
        import ctypes
        ctypes.windll.kernel32.SetFileAttributesW(ruta, 0x2 | 0x4)


def crear(base: str) -> str:
    origen = os.path.join(base, "origen")
    destino = os.path.join(base, "destino")
    os.makedirs(origen)
    for nombre, datos in ARCHIVOS.items():
        with open(os.path.join(origen, nombre), "wb") as f:
            f.write(datos)
    ocultar(os.path.join(origen, "desktop.ini"))
    proyecto = os.path.join(origen, "Proyecto X")
    os.makedirs(proyecto)
    for nombre in ("plan.docx", "datos.xlsx"):
        with open(os.path.join(proyecto, nombre), "wb") as f:
            f.write(f"contenido de {nombre}".encode())
    pdf = os.path.join(destino, "zOrdenado", "PDF")
    os.makedirs(pdf)
    with open(os.path.join(pdf, "informe.pdf"), "wb") as f:
        f.write(b"%PDF ya existente en destino")
    return base


if __name__ == "__main__":
    if len(sys.argv) > 1:
        base = os.path.abspath(sys.argv[1])
        if os.path.exists(base) and os.listdir(base):
            sys.exit(f"La carpeta {base} ya existe y no está vacía: elige otra (no se sobrescribe nada).")
        os.makedirs(base, exist_ok=True)
    else:
        base = tempfile.mkdtemp(prefix="sandbox_ordenar_")
    print(crear(base))
