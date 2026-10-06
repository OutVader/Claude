#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ordenar_archivos.py — Clasifica los archivos de una carpeta (por defecto, el Escritorio
real del usuario, aunque esté redirigido a OneDrive) en subcarpetas por tipo dentro de
una carpeta CONTENEDORA (por defecto "zOrdenado").

MODO DE PRUEBA PRIMERO (regla del proyecto):
  * Sin --aplicar el script SOLO SIMULA: muestra qué haría y escribe los logs. No crea,
    copia, mueve ni borra nada en el origen ni en el destino.
  * Con --aplicar, el script ejecuta igualmente la simulación completa, la enseña,
    pide confirmación (S/N; "SI" si es Mover) y solo entonces ejecuta ESE MISMO plan.
  * --dry-run gana a --aplicar.

Requisitos: Python 3.12+, solo biblioteca estándar. Sin admin. No escribe en el registro
(ctypes/winreg se usan solo para LEER la ruta del Escritorio y el tipo de unidad).

Códigos de salida: 0 OK · 1 con errores no críticos · 2 parámetros no válidos o
cancelado · 3 abortado por error crítico.
"""

from __future__ import annotations

import argparse
import csv
import errno
import fnmatch
import hashlib
import json
import logging
import os
import re
import shutil
import stat
import sys
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime

VERSION = "1.0.4"
ES_WINDOWS = os.name == "nt"

# --------------------------------------------------------------------------------------
# Constantes
# --------------------------------------------------------------------------------------
SALIDA_OK, SALIDA_NO_CRITICOS, SALIDA_PARAMETROS, SALIDA_CRITICO = 0, 1, 2, 3

# Mapeo interno (idéntico a mapeo-extensiones.json). El orden importa: gana la primera.
MAPEO_INTERNO = {
    "carpetaOtros": "zOtros",
    "sensibles": ["Certificados y claves"],
    "categorias": {
        "Certificados y claves": ["p12", "pfx", "cer", "crt", "pem", "key"],
        "Documentos": ["doc", "docx", "odt", "rtf"],
        "PDF": ["pdf"],
        "Hojas de calculo": ["xls", "xlsx", "xlsm", "csv", "ods"],
        "Presentaciones": ["ppt", "pptx", "odp"],
        "Textos": ["txt", "log"],
        "Markdown": ["md"],
        "Imagenes": ["jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "svg"],
        "Accesos directos": ["lnk"],
        "Enlaces web": ["url", "webloc"],
        "Correos": ["msg", "eml", "oft"],
        "Scripts": ["ps1", "psm1", "bat", "cmd", "py", "sh", "vbs", "reg"],
        "Comprimidos": ["zip", "rar", "7z", "tar", "gz"],
        "Instaladores y Aplicaciones": ["exe", "msi", "msix", "appx"],
        "Audio": ["mp3", "wav", "flac", "m4a", "ogg"],
        "Video": ["mp4", "mkv", "avi", "mov", "webm"],
        "Codigo": ["js", "json", "xml", "yaml", "yml", "html", "css", "c", "cpp", "cs",
                   "java", "go", "rs", "sql"],
    },
}

CARPETA_CARPETAS = "Carpetas"          # destino de A.7 (carpetas enteras)
CARPETA_LOGS = "_logs"                 # copia final de los logs dentro de la contenedora
EXCLUSIONES_DEFECTO = ["desktop.ini", "thumbs.db", "~$*", "*.tmp"]
NOMBRES_RESERVADOS = {"CON", "PRN", "AUX", "NUL",
                      *(f"COM{i}" for i in range(1, 10)), *(f"LPT{i}" for i in range(1, 10))}

# Atributos de archivo de Windows
FILE_ATTRIBUTE_HIDDEN = 0x2
FILE_ATTRIBUTE_SYSTEM = 0x4
ATRIBUTOS_NUBE = 0x1000 | 0x40000 | 0x400000   # OFFLINE | RECALL_ON_OPEN | RECALL_ON_DATA_ACCESS

# Códigos Win32 (D. ERRORES)
CAUSAS_NO_CRITICAS = {
    2: "El archivo ha desaparecido durante el proceso (se movió o borró por otro lado).",
    32: "El archivo está en uso por otro proceso: ciérralo en Outlook/Word/… y repite.",
    33: "Parte del archivo está bloqueada por otro proceso: ciérralo y repite.",
    5: "Acceso denegado: revisa permisos, atributo de solo lectura o el antivirus.",
    206: "Ruta o nombre demasiado largo: activa LongPathsEnabled o acorta la ruta.",
    123: "Nombre de archivo, carpeta o volumen no válido.",
}
CODIGOS_NUBE = {358, *range(362, 367), 374, 375, *range(377, 384), *range(386, 399),
                404, 426, 434, 475}
CODIGOS_DESTINO_CRITICO = {3, 21, 53, 59, 64, 67, 121, 1167}
CODIGOS_SIN_ESPACIO = {39, 112}

# Equivalencias errno → código Win32 (fuera de Windows, para usar una sola tabla)
ERRNO_A_WIN32 = {
    errno.ENOENT: 2, errno.EACCES: 5, errno.EPERM: 5, errno.EBUSY: 32,
    errno.ETXTBSY: 32, errno.ENAMETOOLONG: 206, errno.EINVAL: 123,
    errno.ENOSPC: 112, errno.EDQUOT: 112, errno.EXDEV: 17,
    errno.ENOTCONN: 64, errno.EHOSTDOWN: 64, errno.EHOSTUNREACH: 53,
    errno.ESTALE: 64, errno.ENODEV: 21, errno.EIO: 1167,
}

# --------------------------------------------------------------------------------------
# Consola con colores (respeta NO_COLOR)
# --------------------------------------------------------------------------------------
_COLORES = {"rojo": "\033[91m", "amarillo": "\033[93m", "verde": "\033[92m",
            "cian": "\033[96m", "magenta": "\033[95m", "gris": "\033[90m", "fin": "\033[0m"}
_USAR_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
LOG = logging.getLogger("ordenar")


def preparar_consola() -> None:
    """UTF-8 en consola y secuencias ANSI en Windows 10/11 (no toca el registro)."""
    for flujo in (sys.stdout, sys.stderr):
        try:
            flujo.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    if ES_WINDOWS and _USAR_COLOR:
        try:
            import ctypes
            k32 = ctypes.windll.kernel32
            h = k32.GetStdHandle(-11)
            modo = ctypes.c_uint32()
            if k32.GetConsoleMode(h, ctypes.byref(modo)):
                k32.SetConsoleMode(h, modo.value | 0x0004)  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
        except Exception:
            pass


def decir(texto: str = "", color: str | None = None, nivel: int = logging.INFO) -> None:
    """Escribe en consola (con color) y en el log de texto."""
    if color and _USAR_COLOR:
        print(f"{_COLORES[color]}{texto}{_COLORES['fin']}")
    else:
        print(texto)
    LOG.log(nivel, texto)


def tam_legible(n: int) -> str:
    for unidad in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unidad == "TB":
            return f"{n:.0f} {unidad}" if unidad == "B" else f"{n:.1f} {unidad}"
        n /= 1024
    return f"{n} B"


# --------------------------------------------------------------------------------------
# Rutas
# --------------------------------------------------------------------------------------
def lp(ruta: str) -> str:
    """Prefijo \\\\?\\ (o \\\\?\\UNC\\) para rutas largas en Windows. Solo en APIs de disco;
    en el CSV y en pantalla se usan siempre las rutas sin prefijo."""
    if not ES_WINDOWS or ruta.startswith("\\\\?\\"):
        return ruta
    ruta = os.path.abspath(ruta)
    if ruta.startswith("\\\\"):
        return "\\\\?\\UNC\\" + ruta[2:]
    return "\\\\?\\" + ruta


def sin_prefijo(ruta: str) -> str:
    if ruta.startswith("\\\\?\\UNC\\"):
        return "\\\\" + ruta[8:]
    if ruta.startswith("\\\\?\\"):
        return ruta[4:]
    return ruta


def clave_ruta(ruta: str) -> str:
    """Clave para comparar rutas sin distinguir mayúsculas (Windows) ni separadores."""
    return os.path.normcase(os.path.abspath(sin_prefijo(ruta))).rstrip("\\/").casefold()


def dentro_de(ruta: str, carpeta: str) -> bool:
    r, c = clave_ruta(ruta), clave_ruta(carpeta)
    return r == c or r.startswith(c + os.sep.casefold()) or r.startswith(c + "/")


def escritorio_real() -> str:
    """Escritorio del usuario: SHGetKnownFolderPath → winreg "User Shell Folders" → ~/Desktop."""
    if ES_WINDOWS:
        try:
            import ctypes
            from ctypes import wintypes

            class GUID(ctypes.Structure):
                _fields_ = [("Data1", wintypes.DWORD), ("Data2", wintypes.WORD),
                            ("Data3", wintypes.WORD), ("Data4", ctypes.c_ubyte * 8)]

            # FOLDERID_Desktop {B4BFCC3A-DB2C-424C-B029-7FE99A87C641}
            fid = GUID(0xB4BFCC3A, 0xDB2C, 0x424C,
                       (ctypes.c_ubyte * 8)(0xB0, 0x29, 0x7F, 0xE9, 0x9A, 0x87, 0xC6, 0x41))
            ptr = ctypes.c_wchar_p()
            if ctypes.windll.shell32.SHGetKnownFolderPath(ctypes.byref(fid), 0, None,
                                                          ctypes.byref(ptr)) == 0:
                ruta = ptr.value
                ctypes.windll.ole32.CoTaskMemFree(ptr)
                if ruta and os.path.isdir(ruta):
                    return ruta
        except Exception:
            pass
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                                r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders") as k:
                valor, _ = winreg.QueryValueEx(k, "Desktop")
                ruta = os.path.expandvars(valor)
                if os.path.isdir(ruta):
                    return ruta
        except OSError:
            pass
    return os.path.join(os.path.expanduser("~"), "Desktop")


def carpeta_logs() -> str:
    if ES_WINDOWS:
        base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), "AppData", "Local")
        return os.path.join(base, "OrdenarArchivos", "logs")
    return os.path.join(os.path.expanduser("~"), ".local", "state", "ordenar-archivos")


def es_unc(ruta: str) -> bool:
    return sin_prefijo(os.path.abspath(ruta)).startswith("\\\\")


def es_extraible(ruta: str) -> bool:
    """True si la unidad es extraíble (USB). Solo lectura vía GetDriveTypeW."""
    if not ES_WINDOWS:
        return False
    try:
        import ctypes
        raiz = os.path.splitdrive(os.path.abspath(ruta))[0] + "\\"
        return ctypes.windll.kernel32.GetDriveTypeW(raiz) == 2   # DRIVE_REMOVABLE
    except Exception:
        return False


def validar_nombre_carpeta(nombre: str) -> str | None:
    """Devuelve None si es válido o el motivo en español si no lo es."""
    if not nombre or not nombre.strip():
        return "el nombre está vacío"
    if re.search(r'[<>:"/\\|?*\x00-\x1f]', nombre):
        return 'contiene caracteres no permitidos (<>:"/\\|?*)'
    if nombre[-1] in ". ":
        return "no puede terminar en punto ni en espacio"
    if nombre.split(".")[0].upper().strip() in NOMBRES_RESERVADOS:
        return "es un nombre reservado de Windows (CON, PRN, AUX, NUL, COM1-9, LPT1-9)"
    return None


# --------------------------------------------------------------------------------------
# Mapeo
# --------------------------------------------------------------------------------------
@dataclass
class Mapeo:
    otros: str
    sensibles: set[str]
    categorias: list[tuple[str, set[str]]]

    def categoria(self, nombre: str) -> str:
        ext = os.path.splitext(nombre)[1].lstrip(".").casefold()
        if ext:
            for cat, exts in self.categorias:
                if ext in exts:
                    return cat
        return self.otros


def cargar_mapeo(ruta: str | None, otros: str | None) -> Mapeo:
    datos = MAPEO_INTERNO
    origen = "interno"
    if ruta is None:
        junto = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mapeo-extensiones.json")
        if os.path.isfile(junto):
            ruta = junto
    if ruta:
        with open(ruta, encoding="utf-8-sig") as f:
            datos = json.load(f)
        origen = ruta
        if not isinstance(datos.get("categorias"), dict):
            raise ValueError("el JSON no tiene un objeto 'categorias'")
    cats = [(str(c), {str(e).lstrip(".").casefold() for e in exts})
            for c, exts in datos["categorias"].items()]
    m = Mapeo(otros=otros or datos.get("carpetaOtros") or "zOtros",
              sensibles={s.casefold() for s in datos.get("sensibles", [])}, categorias=cats)
    LOG.info("Mapeo cargado: %s (%d categorías)", origen, len(cats))
    return m


# --------------------------------------------------------------------------------------
# Plan
# --------------------------------------------------------------------------------------
@dataclass
class Elemento:
    tipo: str                 # "archivo" | "carpeta"
    origen: str
    rel: str
    categoria: str = ""
    destino: str = ""
    bytes: int = 0
    archivos: int = 0         # solo carpetas
    sensible: bool = False
    nube: bool = False
    omitido: str = ""         # motivo si se omite


@dataclass
class Config:
    origen: str
    destino: str
    contenedora: str
    excluir: list[str]
    incluir_solo: list[str]
    modo: str
    recursivo: bool
    carpetas: str
    aplicar: bool
    si: bool
    excluir_sensibles: bool
    incluir_nube: bool
    incluir_ocultos: bool
    mapeo: Mapeo = None

    @property
    def ruta_contenedora(self) -> str:
        return os.path.join(self.destino, self.contenedora)


def partir_lista(texto: str | None) -> list[str]:
    return [p.strip() for p in (texto or "").split(",") if p.strip()]


def coincide(patrones: list[str], nombre: str, rel: str) -> bool:
    """fnmatch sin distinguir mayúsculas, contra el nombre y contra la ruta relativa."""
    n, r = nombre.casefold(), rel.replace("\\", "/").casefold()
    for p in patrones:
        p = p.replace("\\", "/").casefold()
        if fnmatch.fnmatchcase(n, p) or fnmatch.fnmatchcase(r, p):
            return True
    return False


def patron_incluir(p: str) -> str:
    """".pdf" o "pdf" (sin comodines ni punto interior) → "*.pdf"; lo demás, tal cual."""
    if p.startswith(".") and not any(c in p for c in "*?["):
        return "*" + p
    return p


def atributos(st: os.stat_result) -> int:
    return getattr(st, "st_file_attributes", 0)


def es_oculto(nombre: str, st: os.stat_result) -> bool:
    if ES_WINDOWS:
        return bool(atributos(st) & (FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM))
    return nombre.startswith(".")


def es_enlace(entrada: os.DirEntry) -> bool:
    try:
        return entrada.is_symlink() or entrada.is_junction()
    except AttributeError:     # Python < 3.12 sin is_junction
        return entrada.is_symlink()


def medir_carpeta(ruta: str) -> tuple[int, int]:
    """(nº de archivos, bytes) sin seguir enlaces."""
    n = b = 0
    for raiz, dirs, archivos in os.walk(lp(ruta), followlinks=False):
        for a in archivos:
            try:
                st = os.lstat(os.path.join(raiz, a))
                if not stat.S_ISLNK(st.st_mode):
                    n += 1
                    b += st.st_size
            except OSError:
                pass
    return n, b


class Planificador:
    """Recorre el origen SIN escribir nada y decide qué pasaría con cada elemento."""

    def __init__(self, cfg: Config, rutas_excluidas: list[str]):
        self.cfg = cfg
        self.excluidas = [clave_ruta(r) for r in rutas_excluidas]
        self.elementos: list[Elemento] = []
        self.reservados: set[str] = set()
        self.excluir = cfg.excluir
        self.incluir = [patron_incluir(p) for p in cfg.incluir_solo]

    def _excluida(self, ruta: str) -> bool:
        k = clave_ruta(ruta)
        return any(k == e or k.startswith(e + os.sep.casefold()) for e in self.excluidas)

    def recorrer(self) -> None:
        self._carpeta(self.cfg.origen, "")
        self.elementos.sort(key=lambda e: (e.tipo != "carpeta", e.rel.casefold()))
        for e in self.elementos:
            if not e.omitido:
                try:
                    self._asignar_destino(e)
                except (OSError, ValueError) as ex:
                    e.omitido = f"ruta de destino demasiado larga o no válida (se omite): {ex}"

    def _carpeta(self, ruta: str, rel_base: str) -> None:
        try:
            entradas = sorted(os.scandir(lp(ruta)), key=lambda x: x.name.casefold())
        except OSError as ex:
            self.elementos.append(Elemento("carpeta", ruta, rel_base or ".",
                                           omitido=f"no se puede leer: {ex.strerror}"))
            return
        for ent in entradas:
            try:
                self._entrada(ruta, rel_base, ent)
            except (OSError, ValueError) as ex:     # ruta larga o rara: se registra y se sigue
                self.elementos.append(Elemento("archivo", os.path.join(ruta, ent.name), ent.name,
                                               omitido=f"ruta demasiado larga o no válida (se omite): {ex}"))

    def _entrada(self, ruta: str, rel_base: str, ent: os.DirEntry) -> None:
        plano = os.path.join(ruta, ent.name)
        rel = os.path.join(rel_base, ent.name) if rel_base else ent.name
        if self._excluida(plano):
            return                                     # contenedora, logs, script…
        try:
            st = ent.stat(follow_symlinks=False)
        except OSError as ex:
            self.elementos.append(Elemento("archivo", plano, rel,
                                           omitido=f"no se puede leer: {ex.strerror}"))
            return
        if es_enlace(ent):
            self.elementos.append(Elemento("carpeta" if ent.is_dir() else "archivo", plano, rel,
                                           omitido="enlace simbólico/junction (no se sigue)"))
            return
        oculto = es_oculto(ent.name, st)
        if ent.is_dir(follow_symlinks=False):
            if oculto and not self.cfg.incluir_ocultos:
                return                                # carpeta oculta: ni se entra ni se lista
            if self.cfg.recursivo:
                if not coincide(self.excluir, ent.name, rel):
                    self._carpeta(plano, rel)
            elif self.cfg.carpetas != "dejar":
                e = Elemento("carpeta", plano, rel)
                if coincide(self.excluir, ent.name, rel):
                    e.omitido = "excluido por patrón"
                else:
                    e.archivos, e.bytes = medir_carpeta(plano)
                    e.categoria = CARPETA_CARPETAS
                self.elementos.append(e)
            return
        # --- archivos ---
        e = Elemento("archivo", plano, rel, bytes=st.st_size)
        e.categoria = self.cfg.mapeo.categoria(ent.name)
        e.sensible = e.categoria.casefold() in self.cfg.mapeo.sensibles
        e.nube = bool(atributos(st) & ATRIBUTOS_NUBE)
        if oculto and not self.cfg.incluir_ocultos:
            e.omitido = "oculto o de sistema"
        elif coincide(EXCLUSIONES_DEFECTO, ent.name, ent.name):
            e.omitido = "exclusión por defecto (desktop.ini, Thumbs.db, ~$*, *.tmp)"
        elif e.nube and not self.cfg.incluir_nube:
            e.omitido = "solo en la nube (usa --incluir-nube para descargarlo)"
        elif coincide(self.excluir, ent.name, rel):
            e.omitido = "excluido por patrón"
        elif self.incluir and not coincide(self.incluir, ent.name, rel):
            e.omitido = "no está en INCLUIR SOLO"
        elif e.sensible and self.cfg.excluir_sensibles:
            e.omitido = "sensible excluido (--excluir-sensibles)"
        self.elementos.append(e)

    def _asignar_destino(self, e: Elemento) -> None:
        carpeta = os.path.join(self.cfg.ruta_contenedora, e.categoria)
        e.destino = self.nombre_libre(carpeta, os.path.basename(e.origen), e.tipo == "carpeta")

    def nombre_libre(self, carpeta: str, nombre: str, es_carpeta: bool) -> str:
        """Nunca sobrescribe: "nombre (1).ext", "(2)"… comprobando disco y reservas de esta ejecución."""
        base, ext = (nombre, "") if es_carpeta else os.path.splitext(nombre)
        candidato, n = nombre, 1
        while True:
            ruta = os.path.join(carpeta, candidato)
            k = clave_ruta(ruta)
            if k not in self.reservados and not os.path.lexists(lp(ruta)):
                self.reservados.add(k)
                return ruta
            candidato = f"{base} ({n}){ext}"
            n += 1


# --------------------------------------------------------------------------------------
# Duplicados (solo informe)
# --------------------------------------------------------------------------------------
_RE_VERSION = re.compile(r"^(?P<base>.*?)(?:\s\(\d+\)|_v\d+)$", re.IGNORECASE)


def sha256(ruta: str) -> str:
    h = hashlib.sha256()
    with open(lp(ruta), "rb") as f:
        while bloque := f.read(1024 * 1024):
            h.update(bloque)
    return h.hexdigest()


def informe_duplicados(elementos: list[Elemento]) -> list[tuple[str, list[str]]]:
    """Grupos de posibles duplicados por nombre ("(1)", "_v2"…) y por tamaño + SHA-256."""
    grupos: list[tuple[str, list[str]]] = []
    archivos = [e for e in elementos if e.tipo == "archivo" and not e.omitido]
    por_nombre: dict[str, list[Elemento]] = {}
    for e in archivos:
        base, ext = os.path.splitext(os.path.basename(e.origen))
        m = _RE_VERSION.match(base)
        clave = ((m.group("base") if m else base) + ext).casefold()
        por_nombre.setdefault(clave, []).append(e)
    for clave, lista in por_nombre.items():
        if len(lista) > 1:
            grupos.append(("mismo nombre base", [x.rel for x in lista]))
    por_tam: dict[int, list[Elemento]] = {}
    for e in archivos:
        if not e.nube:                                     # nunca hash de archivos solo en la nube
            por_tam.setdefault(e.bytes, []).append(e)
    for tam, lista in por_tam.items():
        if len(lista) < 2:
            continue                                       # hash solo si hay coincidencia de tamaño
        por_hash: dict[str, list[str]] = {}
        for e in lista:
            try:
                por_hash.setdefault(sha256(e.origen), []).append(e.rel)
            except OSError:
                pass
        for h, rels in por_hash.items():
            if len(rels) > 1:
                grupos.append((f"mismo contenido ({tam_legible(tam)}, SHA-256 {h[:12]}…)", rels))
    return grupos


# --------------------------------------------------------------------------------------
# CSV en caliente
# --------------------------------------------------------------------------------------
class RegistroCSV:
    CAMPOS = ["Fecha", "Accion", "Categoria", "Origen", "Destino", "Bytes", "Resultado",
              "Severidad", "Detalle"]

    def __init__(self, ruta: str):
        self.ruta = ruta
        self.f = open(ruta, "w", newline="", encoding="utf-8-sig")
        self.w = csv.writer(self.f, delimiter=";")
        self.w.writerow(self.CAMPOS)
        self.filas = 0

    def fila(self, accion, categoria, origen, destino, nbytes, resultado, severidad, detalle=""):
        self.w.writerow([datetime.now().isoformat(timespec="seconds"), accion, categoria,
                         sin_prefijo(origen or ""), sin_prefijo(destino or ""), nbytes,
                         resultado, severidad, detalle])
        self.f.flush()
        self.filas += 1
        if self.filas % 50 == 0:
            os.fsync(self.f.fileno())

    def cerrar(self):
        if not self.f.closed:
            self.f.flush()
            os.fsync(self.f.fileno())
            self.f.close()


# --------------------------------------------------------------------------------------
# Errores
# --------------------------------------------------------------------------------------
class Critico(Exception):
    """Error que obliga a parar (código de salida 3)."""


def codigo_error(ex: OSError) -> int:
    w = getattr(ex, "winerror", None)
    if w:
        return int(w)
    return ERRNO_A_WIN32.get(ex.errno, ex.errno or 0)


def causa(codigo: int, ex: BaseException) -> str:
    if codigo in CAUSAS_NO_CRITICAS:
        return CAUSAS_NO_CRITICAS[codigo]
    if codigo in CODIGOS_NUBE:
        return "Error del proveedor de nube (OneDrive): comprueba que está sincronizado y con sesión iniciada."
    if codigo in CODIGOS_DESTINO_CRITICO:
        return "El destino no está accesible (red/USB desconectado o ruta inexistente)."
    if codigo in CODIGOS_SIN_ESPACIO:
        return "No queda espacio en el destino."
    return f"{type(ex).__name__}: {getattr(ex, 'strerror', None) or ex}"


def espacio_libre(ruta: str) -> int | None:
    try:
        return shutil.disk_usage(lp(ruta)).free
    except OSError:
        return None


def prueba_escritura(ruta: str) -> str | None:
    """Crea y borra un temporal PROPIO en la raíz del destino. None = OK; texto = motivo."""
    tmp = os.path.join(ruta, f".ordenar_prueba_{os.getpid()}_{uuid.uuid4().hex[:8]}.tmp")
    try:
        with open(lp(tmp), "xb") as f:
            f.write(b"ok")
            f.flush()
            os.fsync(f.fileno())
        os.remove(lp(tmp))
        return None
    except OSError as ex:
        return f"{causa(codigo_error(ex), ex)} [código {codigo_error(ex)}]"


# --------------------------------------------------------------------------------------
# Operaciones de disco (solo con --aplicar)
# --------------------------------------------------------------------------------------
def copiar_exclusivo(src: str, dst: str, con_hash: bool) -> tuple[int, str | None]:
    """Copia sin sobrescribir nunca (open 'xb'). Si falla, borra SOLO la copia parcial propia."""
    h = hashlib.sha256() if con_hash else None
    n = 0
    with open(lp(src), "rb") as fi:
        fo = open(lp(dst), "xb")                     # FileExistsError si ya existe
        try:
            with fo:
                while bloque := fi.read(1024 * 1024):
                    fo.write(bloque)
                    n += len(bloque)
                    if h:
                        h.update(bloque)
                fo.flush()
                os.fsync(fo.fileno())
        except BaseException:
            try:
                os.remove(lp(dst))
            except OSError:
                pass
            raise
    try:
        shutil.copystat(lp(src), lp(dst))
    except OSError:
        pass                                          # fechas/atributos: no es motivo de fallo
    return n, (h.hexdigest() if h else None)


def verificar_copia(src_bytes: int, dst: str, hash_src: str | None) -> str | None:
    """None si la copia es correcta; texto con el motivo si no."""
    real = os.stat(lp(dst)).st_size
    if real != src_bytes:
        return f"tamaño distinto (origen {src_bytes} B, copia {real} B)"
    if hash_src and sha256(dst) != hash_src:
        return "SHA-256 distinto entre origen y copia"
    return None


def copiar_arbol(src: str, dst: str, csvlog: RegistroCSV) -> tuple[int, int, int]:
    """copytree sin sobrescribir (dst no debe existir). Devuelve (archivos, bytes, errores)."""
    errores = 0
    try:
        shutil.copytree(lp(src), lp(dst), symlinks=True)
    except shutil.Error as ex:
        for s, d, por_que in ex.args[0]:
            errores += 1
            csvlog.fila("copiar-carpeta", CARPETA_CARPETAS, s, d, "", "error", "no-critico", str(por_que))
    n, b = medir_carpeta(dst)
    return n, b, errores


# --------------------------------------------------------------------------------------
# Entrada interactiva
# --------------------------------------------------------------------------------------
def preguntar(texto: str, defecto: str, validar=None) -> str:
    while True:
        r = input(f"{texto} [{defecto}]: ").strip() or defecto
        motivo = validar(r) if validar else None
        if not motivo:
            return r
        decir(f"  Valor no válido: {motivo}. Vuelve a intentarlo.", "amarillo")


def preguntar_si_no(texto: str, defecto: bool) -> bool:
    d = "S" if defecto else "N"
    while True:
        r = (input(f"{texto} (S/N) [{d}]: ").strip() or d).upper()
        if r in ("S", "SI", "SÍ"):
            return True
        if r == "N" or r == "NO":
            return False
        decir("  Responde S o N.", "amarillo")


def entrada_interactiva(a: argparse.Namespace) -> None:
    decir("=== Ordenar archivos — modo interactivo (Enter = valor por defecto) ===", "cian")
    a.origen = preguntar("ORIGEN", a.origen or escritorio_real(),
                         lambda v: None if os.path.isdir(v) else "la carpeta no existe")
    a.excluir = preguntar("EXCLUIR (patrones separados por comas, vacío = nada)", a.excluir or "-")
    a.excluir = "" if a.excluir == "-" else a.excluir
    a.incluir_solo = preguntar("INCLUIR SOLO (p. ej. .pdf,.docx o WhatsApp*; vacío = todo)", a.incluir_solo or "-")
    a.incluir_solo = "" if a.incluir_solo == "-" else a.incluir_solo
    a.destino = preguntar("DESTINO (local, USB o \\\\servidor\\recurso)", a.destino or a.origen,
                          lambda v: None if os.path.isdir(v) else "el destino no existe o no está accesible")
    a.logs = preguntar("CARPETA DE LOGS", a.logs or os.path.join(a.destino, "00.logs"),
                       lambda v: "contiene caracteres no permitidos" if any(c in v for c in '<>"|?*') else None)
    a.contenedora = preguntar("CONTENEDORA", a.contenedora, validar_nombre_carpeta)
    a.modo = preguntar("MODO (Copiar/Mover)", a.modo.capitalize(),
                       lambda v: None if v.casefold() in ("copiar", "mover") else "escribe Copiar o Mover").casefold()
    # Por ahora el modo interactivo trabaja SOLO con los archivos sueltos de la raíz del origen:
    # no entra en subcarpetas ni las mueve. Para eso están --recursivo y --carpetas por parámetro.
    a.recursivo, a.carpetas = False, "dejar"
    decir("  Subcarpetas: se omiten (solo archivos sueltos de la raíz).", "gris")


# --------------------------------------------------------------------------------------
# Programa principal
# --------------------------------------------------------------------------------------
def crear_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="ordenar_archivos.py",
        description="Clasifica archivos por tipo en subcarpetas de una CONTENEDORA. "
                    "SIEMPRE simula primero: sin --aplicar no se toca nada.",
        epilog="Ejemplos:\n"
               "  py ordenar_archivos.py                         (interactivo, simulación)\n"
               "  py ordenar_archivos.py --destino D:\\           (simulación)\n"
               "  py ordenar_archivos.py --destino E:\\ --aplicar (simula, enseña y pide OK)\n"
               "Salida: 0 OK · 1 errores no críticos · 2 parámetros/cancelado · 3 crítico",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--origen", help="carpeta a ordenar (por defecto, el Escritorio real)")
    p.add_argument("--excluir", help='patrones separados por comas: "Warp.lnk, *.p12, Proyecto*"')
    p.add_argument("--incluir-solo", dest="incluir_solo", help='extensiones o patrones: ".pdf,.docx" o "WhatsApp*"')
    p.add_argument("--destino", help="ruta local, USB o UNC (por defecto, el origen)")
    p.add_argument("--contenedora", default="zOrdenado", help="carpeta contenedora (defecto: zOrdenado)")
    p.add_argument("--otros", help="carpeta para desconocidos (defecto: la del JSON, zOtros)")
    p.add_argument("--modo", default="copiar", type=str.casefold, choices=["copiar", "mover"])
    p.add_argument("--recursivo", action="store_true", help="clasificar también los archivos de las subcarpetas")
    p.add_argument("--carpetas", default="dejar", type=str.casefold, choices=["dejar", "copiar", "mover"],
                   help="qué hacer con las subcarpetas del origen (no combinable con --recursivo)")
    p.add_argument("--aplicar", action="store_true", help="ejecutar de verdad (tras simular y confirmar)")
    p.add_argument("--dry-run", dest="dry_run", action="store_true", help="forzar simulación (gana a --aplicar)")
    p.add_argument("--si", action="store_true", help="no pedir confirmación (queda anotado en el log)")
    p.add_argument("--mapeo", help="ruta a mapeo-extensiones.json (por defecto, el que está junto al script)")
    p.add_argument("--excluir-sensibles", dest="excluir_sensibles", action="store_true",
                   help="dejar fuera certificados y claves")
    p.add_argument("--incluir-nube", dest="incluir_nube", action="store_true",
                   help="procesar archivos solo-en-la-nube (OneDrive los descargará)")
    p.add_argument("--logs", help="carpeta de logs (interactivo: <destino>\\00.logs; si no, %%LOCALAPPDATA%%)")
    p.add_argument("--incluir-ocultos", dest="incluir_ocultos", action="store_true",
                   help="procesar archivos ocultos y de sistema")
    p.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    return p


def iniciar_logs(d: str) -> tuple[str, str, RegistroCSV]:
    os.makedirs(d, exist_ok=True)
    sello = datetime.now().strftime("%Y%m%d_%H%M%S")
    # Nombre neutro: la misma ejecución puede empezar simulando y terminar aplicando (lo dice el CSV)
    base = os.path.join(d, f"ordenar_{sello}")
    ruta_txt, ruta_csv = base + ".log", base + ".csv"
    h = logging.FileHandler(ruta_txt, encoding="utf-8")
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    LOG.addHandler(h)
    LOG.setLevel(logging.INFO)
    return ruta_txt, ruta_csv, RegistroCSV(ruta_csv)


def resumen(cfg: Config, elems: list[Elemento], duplicados, libre: int | None, necesario: int,
            titulo: str) -> None:
    activos = [e for e in elems if not e.omitido]
    decir("")
    decir(f"===== {titulo} =====", "cian")
    decir(f"Origen     : {cfg.origen}")
    decir(f"Destino    : {cfg.ruta_contenedora}")
    decir(f"Modo       : {cfg.modo.upper()}   Recursivo: {'sí' if cfg.recursivo else 'no'}   "
          f"Carpetas: {cfg.carpetas}")
    por_cat: dict[str, list[int]] = {}
    for e in activos:
        if e.tipo == "archivo":
            v = por_cat.setdefault(e.categoria, [0, 0])
            v[0] += 1
            v[1] += e.bytes
    orden = [c for c, _ in cfg.mapeo.categorias] + [cfg.mapeo.otros]
    decir("Archivos por categoría:")
    for c in sorted(por_cat, key=lambda x: orden.index(x) if x in orden else 999):
        decir(f"  {c:<30} {por_cat[c][0]:>6}  {tam_legible(por_cat[c][1]):>10}")
    if not por_cat:
        decir("  (ninguno)")
    carps = [e for e in activos if e.tipo == "carpeta"]
    if carps:
        decir(f"Carpetas enteras ({cfg.carpetas}): {len(carps)} "
              f"({sum(e.archivos for e in carps)} archivos, {tam_legible(sum(e.bytes for e in carps))})")
    sens = [e for e in activos if e.sensible]
    if sens:
        decir(f"SENSIBLES: {len(sens)} → no los dejes en el Escritorio ni en una red sin protección; "
              f"mejor un almacén cifrado o el almacén de certificados.", "magenta")
    omit: dict[str, int] = {}
    for e in elems:
        if e.omitido:
            omit[e.omitido] = omit.get(e.omitido, 0) + 1
    if omit:
        decir("Omitidos:")
        for k, v in omit.items():
            decir(f"  {v:>4}  {k}", "gris")
    if libre is None:
        decir(f"Espacio necesario: {tam_legible(necesario)} · espacio libre: desconocido", "amarillo")
    else:
        color = "rojo" if libre < necesario else None
        decir(f"Espacio necesario: {tam_legible(necesario)} · libre en destino: {tam_legible(libre)}", color)
    if duplicados:
        decir(f"Posibles duplicados (solo informe, no se borra ni fusiona nada): {len(duplicados)} grupo(s)", "amarillo")
        for motivo, rels in duplicados:
            decir(f"  · {motivo}: " + " | ".join(rels))


def main(argv: list[str] | None = None) -> int:
    preparar_consola()
    inicio = time.monotonic()
    argv = sys.argv[1:] if argv is None else argv
    a = crear_parser().parse_args(argv)          # argparse sale con 2 si algo no vale
    interactivo = not argv and sys.stdin.isatty()
    if interactivo:
        entrada_interactiva(a)

    # ---------- validación de parámetros ----------
    origen = os.path.abspath(os.path.expandvars(a.origen or escritorio_real()))
    destino = os.path.abspath(os.path.expandvars(a.destino or origen))
    motivo = validar_nombre_carpeta(a.contenedora)
    if motivo:
        decir(f"ERROR: nombre de contenedora no válido ({motivo}).", "rojo")
        return SALIDA_PARAMETROS
    if a.recursivo and a.carpetas != "dejar":
        decir("ERROR: --carpetas copiar/mover no se puede combinar con --recursivo: los archivos de las "
              "subcarpetas ya se clasifican uno a uno y se duplicarían.", "rojo")
        return SALIDA_PARAMETROS
    aplicar = a.aplicar and not a.dry_run
    ejecutado = False                            # solo se copian logs a la contenedora si se ejecutó algo

    dir_logs = os.path.abspath(os.path.expandvars(a.logs)) if a.logs else carpeta_logs()
    try:
        ruta_txt, ruta_csv, csvlog = iniciar_logs(dir_logs)
    except OSError as ex:
        decir(f"ERROR: no se puede crear la carpeta de logs {dir_logs}: {ex}", "rojo")
        return SALIDA_PARAMETROS
    LOG.info("ordenar_archivos.py %s · argumentos: %s", VERSION, argv)
    try:
        if not os.path.isdir(lp(origen)):
            decir(f"CRÍTICO: el origen no existe: {origen}", "rojo")
            return SALIDA_CRITICO
        if not os.path.isdir(lp(destino)):
            decir(f"CRÍTICO: el destino no existe o no está accesible: {destino}", "rojo")
            return SALIDA_CRITICO
        try:
            mapeo = cargar_mapeo(a.mapeo, a.otros)
        except (OSError, ValueError) as ex:
            decir(f"ERROR: no se puede leer el mapeo ({ex}).", "rojo")
            return SALIDA_PARAMETROS
        if validar_nombre_carpeta(mapeo.otros):
            decir(f"ERROR: nombre de carpeta de desconocidos no válido: {mapeo.otros}", "rojo")
            return SALIDA_PARAMETROS
        if a.contenedora.casefold() == mapeo.otros.casefold():
            decir(f"AVISO: la contenedora y la carpeta de desconocidos se llaman igual: quedará "
                  f"{a.contenedora}\\{mapeo.otros}.", "amarillo")

        cfg = Config(origen=origen, destino=destino, contenedora=a.contenedora,
                     excluir=partir_lista(a.excluir), incluir_solo=partir_lista(a.incluir_solo),
                     modo=a.modo, recursivo=a.recursivo, carpetas=a.carpetas, aplicar=aplicar, si=a.si,
                     excluir_sensibles=a.excluir_sensibles, incluir_nube=a.incluir_nube,
                     incluir_ocultos=a.incluir_ocultos, mapeo=mapeo)

        # ---------- 1) MODO DE PRUEBA: planificar sin escribir nada ----------
        excluidas = [cfg.ruta_contenedora, dir_logs, os.path.abspath(__file__)]
        if clave_ruta(destino) != clave_ruta(origen) and dentro_de(destino, origen):
            excluidas.append(destino)            # el destino dentro del origen no se ordena a sí mismo
            decir(f"AVISO: el destino está dentro del origen; la carpeta {os.path.relpath(destino, origen)} "
                  "no se procesa.", "amarillo")
        if a.mapeo:
            excluidas.append(os.path.abspath(a.mapeo))
        plan = Planificador(cfg, excluidas)
        plan.recorrer()
        elems = plan.elementos
        activos = [e for e in elems if not e.omitido]
        duplicados = informe_duplicados(elems)

        try:
            otro_volumen = os.stat(lp(origen)).st_dev != os.stat(lp(destino)).st_dev
        except OSError:
            otro_volumen = True
        necesario = sum(e.bytes for e in activos if
                        otro_volumen or (cfg.modo if e.tipo == "archivo" else cfg.carpetas) == "copiar")
        libre = espacio_libre(destino)

        decir("")
        decir(">>> MODO DE PRUEBA: esto es lo que se haría (no se ha tocado nada) <<<", "cian")
        verbo = {"copiar": "COPIAR", "mover": "MOVER"}
        for e in activos:
            v = verbo[cfg.modo] if e.tipo == "archivo" else verbo[cfg.carpetas] + " CARPETA"
            marca = "  [SENSIBLE]" if e.sensible else ""
            decir(f"  {v:<15} {e.rel}  →  {os.path.relpath(e.destino, destino)}{marca}",
                  "magenta" if e.sensible else None)
        if not activos:
            decir("  (nada que procesar)")
        resumen(cfg, elems, duplicados, libre, necesario,
                "RESUMEN PREVIO" if aplicar else "RESUMEN DE LA SIMULACIÓN")

        for e in elems:
            if e.omitido:
                csvlog.fila("omitir", e.categoria, e.origen, "", e.bytes, "omitido", "info", e.omitido)

        ya_confirmado = False
        if not aplicar:
            for e in activos:
                acc = cfg.modo if e.tipo == "archivo" else f"{cfg.carpetas}-carpeta"
                csvlog.fila(acc, e.categoria, e.origen, e.destino, e.bytes, "simulado",
                            "aviso" if e.sensible else "info", "SENSIBLE" if e.sensible else "")
            decir("")
            decir("SIMULACIÓN terminada: no se ha creado, copiado, movido ni borrado nada.", "verde")
            decir(f"Logs: {ruta_txt}\n      {ruta_csv}")
            if not (interactivo and activos and not a.dry_run and
                    preguntar_si_no("\n¿Ejecutar ahora DE VERDAD este mismo plan?", False)):
                decir("Para ejecutarlo más tarde:  " + comando_equivalente(cfg))
                decir(f"Duración: {time.monotonic() - inicio:.1f} s")
                return SALIDA_OK
            aplicar = cfg.aplicar = True
            ya_confirmado = True
            LOG.info("El usuario ha pedido ejecutar el plan simulado (modo interactivo)")
            csvlog.fila("aviso", "", "", "", "", "confirmado", "info",
                        "simulación revisada; se ejecuta el mismo plan")

        mueve = cfg.modo == "mover" or cfg.carpetas == "mover"
        # ---------- 2) Comprobaciones previas a la ejecución ----------
        fallo = prueba_escritura(destino)
        if fallo:
            decir(f"CRÍTICO: falla la prueba de escritura en {destino}: {fallo}", "rojo")
            return SALIDA_CRITICO
        if libre is not None and libre < necesario:
            decir("CRÍTICO: no hay espacio suficiente en el destino.", "rojo")
            return SALIDA_CRITICO
        if not activos:
            decir("Nada que procesar.", "verde")
            return SALIDA_OK

        sens = [e for e in activos if e.sensible]
        if sens and (es_unc(destino) or es_extraible(destino)):
            decir(f"ATENCIÓN: vas a llevar {len(sens)} archivo(s) SENSIBLE(S) a una unidad de red o extraíble.",
                  "magenta")
            if a.si:
                LOG.warning("Confirmación de sensibles en destino UNC/extraíble saltada con --si")
                csvlog.fila("aviso", "", "", destino, "", "confirmado", "aviso",
                            "sensibles a UNC/extraíble confirmados con --si")
            elif not sys.stdin.isatty() or not preguntar_si_no("¿Incluir los sensibles?", False):
                for e in sens:
                    e.omitido = "sensible no confirmado para destino UNC/extraíble"
                    csvlog.fila("omitir", e.categoria, e.origen, "", e.bytes, "omitido", "aviso", e.omitido)
                activos = [e for e in activos if not e.omitido]

        if not a.si and not (ya_confirmado and not mueve):
            if not sys.stdin.isatty():
                decir("Cancelado: no hay consola para confirmar (usa --si).", "amarillo")
                return SALIDA_PARAMETROS
            if mueve:
                ok = input('\nVas a MOVER archivos. Escribe "SI" para continuar: ').strip().upper() in ("SI", "SÍ")
            else:
                ok = preguntar_si_no("\n¿Ejecutar este plan?", False)
            if not ok:
                decir("Cancelado por el usuario. No se ha tocado nada.", "amarillo")
                return SALIDA_PARAMETROS
        else:
            LOG.warning("Confirmación final saltada con --si")

        # ---------- 3) Ejecución del MISMO plan ----------
        ejecutado = True
        ejec = Ejecutor(cfg, plan, csvlog, otro_volumen)
        ejec.ejecutar(activos)
        codigo = SALIDA_NO_CRITICOS if ejec.errores else SALIDA_OK
        resumen_final(cfg, elems, duplicados, ejec, inicio, ruta_txt, ruta_csv)
        return codigo
    except Critico as ex:
        decir(f"CRÍTICO: {ex}. Proceso abortado.", "rojo")
        return SALIDA_CRITICO
    except KeyboardInterrupt:
        decir("Interrumpido por el usuario (Ctrl+C).", "amarillo")
        return SALIDA_PARAMETROS
    finally:
        csvlog.cerrar()
        if ejecutado and not a.logs:
            copiar_logs(destino, a.contenedora, ruta_txt, ruta_csv)
        for h in list(LOG.handlers):
            h.close()
            LOG.removeHandler(h)


def comando_equivalente(cfg: Config) -> str:
    partes = ["py ordenar_archivos.py", f'--origen "{cfg.origen}"', f'--destino "{cfg.destino}"',
              f'--contenedora "{cfg.contenedora}"', f"--modo {cfg.modo}", f"--carpetas {cfg.carpetas}"]
    if cfg.recursivo:
        partes.append("--recursivo")
    if cfg.excluir:
        partes.append(f'--excluir "{", ".join(cfg.excluir)}"')
    if cfg.incluir_solo:
        partes.append(f'--incluir-solo "{",".join(cfg.incluir_solo)}"')
    return " ".join(partes + ["--aplicar"])


def copiar_logs(destino: str, contenedora: str, ruta_txt: str, ruta_csv: str) -> None:
    """Con --aplicar: copia los logs a <contenedora>\\_logs (si el destino sigue accesible)."""
    d = os.path.join(destino, contenedora, CARPETA_LOGS)
    try:
        if not os.path.isdir(os.path.join(destino, contenedora)):
            return                                   # no se creó nada: no crear la contenedora solo por los logs
        os.makedirs(lp(d), exist_ok=True)
        for r in (ruta_txt, ruta_csv):
            if os.path.isfile(r):
                shutil.copy2(r, lp(os.path.join(d, os.path.basename(r))))
        print(f"Logs copiados a {d}")
    except OSError as ex:
        print(f"AVISO: no se pudieron copiar los logs a {d}: {ex}")


class Ejecutor:
    def __init__(self, cfg: Config, plan: Planificador, csvlog: RegistroCSV, otro_volumen: bool):
        self.cfg, self.plan, self.csv, self.otro_volumen = cfg, plan, csvlog, otro_volumen
        self.ok = 0
        self.bytes = 0
        self.errores: list[tuple[str, str]] = []      # (ruta, causa)
        self.creadas: set[str] = set()

    def _carpeta_destino(self, ruta: str) -> None:
        """Crea la subcarpeta solo cuando hace falta (nunca vacías)."""
        d = os.path.dirname(ruta)
        if d not in self.creadas:
            os.makedirs(lp(d), exist_ok=True)
            self.creadas.add(d)

    def _no_critico(self, e: Elemento, accion: str, ex: OSError) -> None:
        cod = codigo_error(ex)
        en_destino = any(f and dentro_de(sin_prefijo(str(f)), self.cfg.destino)
                         and not dentro_de(sin_prefijo(str(f)), self.cfg.origen)
                         for f in (ex.filename, ex.filename2))
        if cod in CODIGOS_SIN_ESPACIO or cod in CODIGOS_DESTINO_CRITICO or en_destino:
            # Error en el destino: repetir prueba de escritura y espacio antes de seguir
            fallo = prueba_escritura(self.cfg.destino)
            libre = espacio_libre(self.cfg.destino)
            if fallo or (libre is not None and libre < e.bytes):
                self.csv.fila(accion, e.categoria, e.origen, e.destino, e.bytes, "error", "critico",
                              f"{causa(cod, ex)} [código {cod}]")
                raise Critico(fallo or "sin espacio en el destino")
        texto = f"{causa(cod, ex)} [código {cod}]"
        decir(f"  AVISO ({e.rel}): {texto}", "amarillo", logging.WARNING)
        self.csv.fila(accion, e.categoria, e.origen, e.destino, e.bytes, "error", "no-critico", texto)
        self.errores.append((e.rel, causa(cod, ex)))

    def ejecutar(self, activos: list[Elemento]) -> None:
        decir("")
        decir(">>> EJECUTANDO <<<", "cian")
        for e in activos:
            accion = self.cfg.modo if e.tipo == "archivo" else f"{self.cfg.carpetas}-carpeta"
            try:
                if e.tipo == "archivo":
                    self._archivo(e, accion)
                else:
                    self._carpeta(e, accion)
            except Critico:
                raise
            except OSError as ex:
                self._no_critico(e, accion, ex)

    def _reintentar_nombre(self, e: Elemento) -> None:
        e.destino = self.plan.nombre_libre(os.path.dirname(e.destino), os.path.basename(e.origen),
                                           e.tipo == "carpeta")

    def _archivo(self, e: Elemento, accion: str) -> None:
        self._carpeta_destino(e.destino)
        if e.sensible:
            decir(f"  SENSIBLE: {e.rel} (no lo dejes en una ubicación sin protección)", "magenta")
        if accion == "mover" and not self.otro_volumen:
            if os.path.lexists(lp(e.destino)):         # os.rename sobrescribe en POSIX: comprobar antes
                self._reintentar_nombre(e)
            try:
                os.rename(lp(e.origen), lp(e.destino))
                self._ok(e, accion, "renombrado")
                return
            except OSError as ex:
                if codigo_error(ex) != 17:             # 17 = ERROR_NOT_SAME_DEVICE / EXDEV
                    raise
        # Copia (o mover entre volúmenes = copiar + verificar + borrar origen)
        try:
            n, h = copiar_exclusivo(e.origen, e.destino, e.sensible)
        except FileExistsError:
            self._reintentar_nombre(e)
            n, h = copiar_exclusivo(e.origen, e.destino, e.sensible)
        motivo = verificar_copia(e.bytes, e.destino, h)
        if motivo:
            self.csv.fila(accion, e.categoria, e.origen, e.destino, n, "verificacion-fallida", "no-critico",
                          motivo + ("; el origen NO se ha borrado" if accion == "mover" else ""))
            self.errores.append((e.rel, "verificación fallida: " + motivo))
            decir(f"  AVISO ({e.rel}): verificación fallida: {motivo}", "amarillo", logging.WARNING)
            return
        if accion == "mover":
            os.remove(lp(e.origen))
            self._ok(e, accion, "copiado+verificado+borrado origen")
        else:
            self._ok(e, accion, "copiado+verificado" + (" (SHA-256)" if h else ""))

    def _carpeta(self, e: Elemento, accion: str) -> None:
        self._carpeta_destino(e.destino)
        if os.path.lexists(lp(e.destino)):
            self._reintentar_nombre(e)
        if accion == "mover-carpeta" and not self.otro_volumen:
            try:
                os.rename(lp(e.origen), lp(e.destino))
                self._ok(e, accion, "renombrada")
                return
            except OSError as ex:
                if codigo_error(ex) != 17:
                    raise
        n, b, errs = copiar_arbol(e.origen, e.destino, self.csv)
        if errs or n != e.archivos or b != e.bytes:
            motivo = f"verificación: {n}/{e.archivos} archivos, {b}/{e.bytes} bytes, {errs} errores"
            self.csv.fila(accion, e.categoria, e.origen, e.destino, b, "verificacion-fallida", "no-critico",
                          motivo + ("; el origen queda intacto" if accion == "mover-carpeta" else ""))
            self.errores.append((e.rel, motivo))
            decir(f"  AVISO ({e.rel}): {motivo}", "amarillo", logging.WARNING)
            return
        if accion == "mover-carpeta":
            shutil.rmtree(lp(e.origen))
            self._ok(e, accion, f"copiada+verificada ({n} archivos)+borrado origen")
        else:
            self._ok(e, accion, f"copiada+verificada ({n} archivos)")

    def _ok(self, e: Elemento, accion: str, detalle: str) -> None:
        self.ok += 1
        self.bytes += e.bytes
        self.csv.fila(accion, e.categoria, e.origen, e.destino, e.bytes, "ok",
                      "aviso" if e.sensible else "info", detalle)
        decir(f"  OK  {e.rel}  →  {os.path.relpath(e.destino, self.cfg.destino)}", "verde")


def resumen_final(cfg, elems, duplicados, ejec: Ejecutor, inicio, ruta_txt, ruta_csv) -> None:
    resumen(cfg, elems, duplicados, espacio_libre(cfg.destino), 0, "RESUMEN FINAL")
    decir(f"Procesados correctamente: {ejec.ok} ({tam_legible(ejec.bytes)})", "verde")
    if ejec.errores:
        por_tipo: dict[str, int] = {}
        for _, c in ejec.errores:
            por_tipo[c] = por_tipo.get(c, 0) + 1
        decir(f"Errores no críticos: {len(ejec.errores)}", "amarillo")
        for c, n in por_tipo.items():
            decir(f"  {n:>4} × {c}", "amarillo")
        decir("Primeros 10:", "amarillo")
        for rel, c in ejec.errores[:10]:
            decir(f"  · {rel}: {c}", "amarillo")
    decir(f"Logs: {ruta_txt}\n      {ruta_csv}")
    decir(f"Duración: {time.monotonic() - inicio:.1f} s")


if __name__ == "__main__":
    sys.exit(main())
