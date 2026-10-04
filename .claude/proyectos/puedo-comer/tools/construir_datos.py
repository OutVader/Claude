"""Une las altas de datos/nuevos_*.py a los datos 2.1.0 y los incrusta en public/index.html.
Comprueba ids únicos, sinónimos únicos entre fichas (normalizados como la app), campos y fuentes."""
import json, re, sys, unicodedata, importlib.util, pathlib
R = pathlib.Path(__file__).resolve().parent.parent
def norm(s):
    s = unicodedata.normalize("NFD", str(s).lower()); s = "".join(c for c in s if unicodedata.category(c) != "Mn" or c == "̃")
    s = unicodedata.normalize("NFC", s); s = re.sub(r"[^a-z0-9ñ ]+", " ", s); return re.sub(r"\s+", " ", s).strip()
base = json.load(open(R / "datos/alimentos-2.1.0.json", encoding="utf-8"))
spec = importlib.util.spec_from_file_location("n", R / "datos/nuevos_2_2_0.py"); n = importlib.util.module_from_spec(spec); spec.loader.exec_module(n)
alimentos = base["alimentos"] + n.NUEVOS
ids, vistos, err = set(), {}, []
for a in alimentos:
    if a["id"] in ids: err.append(f"id repetido {a['id']}")
    ids.add(a["id"])
    if a["estado"] not in ("verde", "amarillo", "rojo"): err.append(f"estado {a['id']}")
    if not a["fuente"] or not all(": http" in f for f in a["fuente"]): err.append(f"fuente {a['id']}")
    for t in [a["nombre"], *a["sinonimos"]]:
        k = norm(t)
        if k in vistos and vistos[k] != a["id"]: err.append(f"sinónimo «{t}» en {a['id']} y {vistos[k]}")
        vistos.setdefault(k, a["id"])
if err: print("\n".join(err)); sys.exit(1)
datos = {**base, "version": "2.2.0", "actualizado": "2026-10-04", "alimentos": alimentos}
json.dump(datos, open(R / "datos/alimentos-2.2.0.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
html = (R / "public/index.html").read_text(encoding="utf-8")
nuevo = "/*__DATOS_INICIO__*/" + json.dumps(datos, ensure_ascii=False, separators=(",", ":")) + "/*__DATOS_FIN__*/"
html, k = re.subn(r'(<script type="application/json" id="datos-embebidos">\s*)/\*__DATOS_INICIO__\*/.*?/\*__DATOS_FIN__\*/', lambda m: m.group(1) + nuevo, html, flags=re.S)
assert k == 1
(R / "public/index.html").write_text(html, encoding="utf-8")
from collections import Counter
print(len(alimentos), "alimentos:", dict(Counter(a["estado"] for a in alimentos)))
print(dict(Counter(a["categoria"] for a in alimentos)))
