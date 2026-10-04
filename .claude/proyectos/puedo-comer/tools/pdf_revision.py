"""Genera el PDF de revisión profesional de las fichas nuevas de la v2.2.0.
Uso: python3 tools/pdf_revision.py  →  docs/revision-fichas-2.2.0.pdf
"""
import json, pathlib, importlib.util, re
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle,
                                PageBreak, KeepTogether, CondPageBreak)

R = pathlib.Path(__file__).resolve().parent.parent
F = "/usr/share/fonts/truetype/dejavu/"
pdfmetrics.registerFont(TTFont("DV", F + "DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("DVB", F + "DejaVuSans-Bold.ttf"))
pdfmetrics.registerFontFamily("DV", normal="DV", bold="DVB", italic="DV", boldItalic="DVB")

MARCA = colors.HexColor("#2f6f62")
SUAVE = colors.HexColor("#4f5f5b")
BORDE = colors.HexColor("#c9d6d2")
ESTADO = {
    "verde": ("✔ APTO", colors.HexColor("#1f6b3a"), colors.HexColor("#e3f3e8")),
    "amarillo": ("⚠ PRECAUCIÓN · CON CONDICIONES", colors.HexColor("#7a4d00"), colors.HexColor("#fff1d6")),
    "rojo": ("✖ EVITAR", colors.HexColor("#9b1c1c"), colors.HexColor("#fde3e3")),
}

st = lambda name, **kw: ParagraphStyle(name, **{"fontName": "DV", "fontSize": 9.5, "leading": 13, "alignment": TA_LEFT, **kw})
S = {
    "t": st("t", fontName="DVB", fontSize=20, leading=25, textColor=MARCA, spaceAfter=4),
    "st": st("st", fontSize=12, leading=16, textColor=SUAVE, spaceAfter=10),
    "h1": st("h1", fontName="DVB", fontSize=13.5, leading=18, textColor=MARCA, spaceBefore=6, spaceAfter=6),
    "h2": st("h2", fontName="DVB", fontSize=11.5, leading=15, spaceAfter=3),
    "p": st("p", spaceAfter=5),
    "pq": st("pq", fontSize=8.5, leading=11.5, textColor=SUAVE),
    "lab": st("lab", fontName="DVB", fontSize=8.5, leading=11.5, textColor=SUAVE, spaceBefore=4),
    "li": st("li", leftIndent=10, bulletIndent=0, spaceAfter=1),
    "duda": st("duda", fontSize=9, leading=12.5, textColor=colors.HexColor("#5a3d00")),
    "cel": st("cel", fontSize=8.5, leading=11),
}

datos = json.load(open(R / "datos/alimentos-2.2.0.json", encoding="utf-8"))
spec = importlib.util.spec_from_file_location("n", R / "datos/nuevos_2_2_0.py"); n = importlib.util.module_from_spec(spec); spec.loader.exec_module(n)
ids_nuevos = [a["id"] for a in n.NUEVOS]
nuevos = [a for a in datos["alimentos"] if a["id"] in ids_nuevos]
assert len(nuevos) == len(ids_nuevos)

# Dudas concretas del autor para cada ficha (lo que más conviene que mire la profesional).
DUDAS = {
    "agua": "¿Añadirías algo sobre aguas con mucho sodio o sobre el agua de pozo o de fuentes no controladas?",
    "isotonicas-aguas-sabor": "AESAN dice «evita bebidas azucaradas». La app ya tenía los refrescos de cola en Precaución y he seguido ese criterio. ¿Debería ser Evitar?",
    "batidos-lacteos": "Los he puesto en Apto (leche pasteurizada o UHT). ¿El azúcar y la cafeína del cacao justifican Precaución?",
    "zumos-pasteurizados": "Apto por seguridad (pasteurizados), aunque AESAN aconseja reducir las bebidas azucaradas. ¿Apto o Precaución?",
    "zumo-maquina-super": "Clasificado como Evitar por el texto literal de AESAN 2026 («zumos envasados sin pasteurizar, incluidos los que preparas y envasas tú mismo en comercio al por menor»). ¿De acuerdo?",
    "complementos": "Solo remite a «los que te indique tu médica o médico» (AESAN). ¿Conviene citar el ácido fólico o el yodo como ejemplos habituales prescritos?",
    "pollo-asado-super": "Precaución por la conservación tras comprarlo. ¿Debería ser Apto con la condición de comerlo caliente?",
    "croquetas": "Apto. AESAN cita las croquetas como cocinado válido del embutido curado. ¿Alguna salvedad con las caseras (bechamel guardada en la nevera)?",
    "morcilla": "Apto bien cocinada (base: NHS). ¿Hay algún matiz español (morcilla curada o de cebolla cruda)?",
    "salchichas-frescas": "Apto bien cocinadas. Incluye «chorizo fresco o criollo»: ¿confunde con el chorizo curado (Evitar)?",
    "conejo-codorniz": "Apto bien cocinados. ¿El magret poco hecho merece una advertencia más fuerte?",
    "guisos-con-embutido": "Apto en caliente (AESAN: curados cocinados a más de 70 ºC). ¿De acuerdo?",
    "platos-preparados-calentar": "Precaución: aptos si se calientan según la etiqueta. ¿Bien así?",
    "tortilla-envasada": "AESAN pide evitar los envasados listos para consumir que llevan huevo. La ficha la permite solo bien calentada. ¿Precaución o Evitar?",
    "ensaladilla-rusa": "Precaución: casera con mayonesa comercial, sí; envasada o de bar, no. ¿Evitar sería más prudente?",
    "hummus-untables": "AESAN no menciona el hummus. Lo he tratado como alimento refrigerado listo para consumir (riesgo de listeria). ¿Precaución es adecuado?",
    "gazpacho-envasado": "Extrapolado de la regla de AESAN sobre zumos (envasados: pasteurizados). ¿Es razonable?",
    "ahumado-conserva": "Apto: AESAN lo propone como alternativa explícita. ¿De acuerdo?",
    "huevas-caviar": "Mezcla cocidas (sí) con crudas o curadas (no) en una sola ficha de Precaución. ¿Sería mejor separarlas?",
    "pescado-empanado": "Apto si se cocina según la etiqueta. ¿De acuerdo?",
    "marisco-crudo": "Evitar (AESAN y NHS: marisco crudo). ¿De acuerdo?",
    "fruta-pelada": "Apto: AESAN propone «frutas frescas peladas». ¿De acuerdo?",
    "compotas-conservas-fruta": "Apto: alternativa explícita de AESAN. ¿De acuerdo?",
    "verduras-cocinadas": "Apto. ¿Alguna verdura cocinada que deba tener matiz (por ejemplo, setas silvestres)?",
    "verduras-conserva": "Apto: alternativa explícita de AESAN. Aviso sobre la sal. ¿De acuerdo?",
    "snacks-salados": "Precaución por sal y grasa (motivos nutricionales, no infecciosos). ¿Tiene sentido este color o confunde?",
    "pan-cereales": "Apto. ¿Algún matiz (cereales con mucho azúcar)?",
    "pasta": "Apto. ¿De acuerdo?",
    "quinoa-cuscus": "Apto. ¿De acuerdo?",
    "proteina-vegetal": "Apto si se cocina según la etiqueta. ¿Hace falta algo más (soja, sal)?",
    "sal-salsas": "Precaución por la sal (AESAN: menos de 5 g al día). ¿Falta algo sobre la sal yodada, que suele recomendarse?",
    "huevos-otras-aves": "Precaución: solo bien cocinados (NHS). ¿De acuerdo?",
    "pasteleria": "Precaución: industrial o con huevo pasteurizado, sí; merengue o crema caseros con huevo crudo, no. ¿De acuerdo?",
    "dulces-navidad": "Apto con moderación (industriales). Aviso de que los dulces con licor cuentan como alcohol. ¿Precaución sería más coherente con «Pastelería»?",
}
assert set(DUDAS) == set(ids_nuevos), set(ids_nuevos) ^ set(DUDAS)

NO_INCLUIDOS = [
    ("Horchata fresca (granel)", "Ninguna fuente oficial revisada la menciona. Duda: horchata natural sin pasteurizar."),
    ("Mojama y salazones de atún", "Pescado curado (NHS: cocinar) y además atún (mercurio). No he encontrado un criterio de AESAN específico."),
    ("Semillas (chía, lino, sésamo)", "Sin indicación específica en las fuentes revisadas."),
    ("Smoothies refrigerados de marca", "Depende de si están pasteurizados. Ya están cubiertos por la ficha «Zumos» (sin pasteurizar)."),
    ("Kéfir y cuajada", "Ya incluidos en la ficha existente «Leche pasteurizada/UHT, yogur…»."),
    ("Cerveza 0,0", "Ya incluida en «Bebidas alcohólicas» (Evitar), con la nota de elegir 0,0 y revisar la etiqueta."),
]

def fuente_corta(f):
    org, _, url = f.partition(": http")
    return f"{org} — <font color='#2f6f62'>http{url}</font>" if url else f

def lista(items, html=False):
    return [Paragraph(x if html else x.replace("&", "&amp;").replace("<", "&lt;"), S["li"], bulletText="•") for x in items]

def esc(x):
    return str(x).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def caja_revision():
    t = Table([
        [Paragraph("<b>Revisión</b>", S["cel"]),
         Paragraph("☐ De acuerdo &nbsp;&nbsp; ☐ Corregir texto &nbsp;&nbsp; ☐ Quitar la ficha", S["cel"])],
        ["", Paragraph("Cambiar estado a: &nbsp; ☐ Apto &nbsp;&nbsp; ☐ Precaución &nbsp;&nbsp; ☐ Evitar", S["cel"])],
        [Paragraph("Comentarios", S["cel"]), ""], ["", ""], ["", ""],
    ], colWidths=[26 * mm, None], rowHeights=[None, None, 8 * mm, 8 * mm, 8 * mm])
    t.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.8, BORDE), ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#f2f6f5")),
        ("LINEBELOW", (1, 2), (1, 4), 0.4, BORDE), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return t

def ficha(i, a):
    txt, fg, bg = ESTADO[a["estado"]]
    cab = Table([[Paragraph(f"<b>{i}. {esc(a['nombre'])}</b>", S["h2"]),
                  Paragraph(f"<font color='{fg.hexval().replace('0x', '#')}'><b>{txt}</b></font>", S["cel"])]],
                colWidths=[None, 52 * mm])
    cab.setStyle(TableStyle([("BACKGROUND", (1, 0), (1, 0), bg), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                             ("LEFTPADDING", (0, 0), (0, 0), 0), ("LINEBELOW", (0, 0), (-1, 0), 1.2, fg)]))
    out = [cab, Spacer(1, 4),
           Paragraph(f"<font color='#4f5f5b'>Categoría:</font> {esc(a['categoria'])} &nbsp;·&nbsp; <font color='#4f5f5b'>id:</font> {a['id']}", S["pq"]),
           Spacer(1, 3), Paragraph(f"<b>Resumen que ve la usuaria:</b> {esc(a['resumen'])}", S["p"])]
    if a["riesgos"]: out.append(Paragraph(f"<b>Riesgos:</b> {esc(', '.join(a['riesgos']))}", S["p"]))
    for clave, titulo in (("condiciones", "Cuándo sí / condiciones"), ("consejos", "Preparación segura y consejos"), ("alternativas", "Alternativas")):
        if a[clave]: out += [Paragraph(titulo, S["lab"])] + lista(a[clave])
    out += [Paragraph("Fuentes citadas", S["lab"])] + [Paragraph(fuente_corta(esc(f)), S["pq"], bulletText="•") for f in a["fuente"]]
    out += [Paragraph("Términos de búsqueda (incluye marcas solo como ejemplo)", S["lab"]),
            Paragraph(esc(", ".join(a["sinonimos"])), S["pq"]), Spacer(1, 5)]
    duda = Table([[Paragraph(f"<b>Pregunta para la revisión:</b> {esc(DUDAS[a['id']])}", S["duda"])]])
    duda.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#fff6dd")), ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#e2c27a"))]))
    out += [duda, Spacer(1, 5), caja_revision(), Spacer(1, 12)]
    return out

def pie(c, doc):
    c.saveState(); c.setFont("DV", 7.5); c.setFillColor(SUAVE)
    c.drawString(18 * mm, 10 * mm, "¿Puedo comer…? · Revisión de fichas nuevas v2.2.0 · Borrador para revisión profesional, no es consejo médico")
    c.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Página {doc.page}")
    c.setStrokeColor(MARCA); c.setLineWidth(2); c.line(18 * mm, A4[1] - 12 * mm, A4[0] - 18 * mm, A4[1] - 12 * mm)
    c.restoreState()

def main():
    salida = R / "docs/revision-fichas-2.2.0.pdf"; salida.parent.mkdir(exist_ok=True)
    doc = BaseDocTemplate(str(salida), pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=18 * mm, bottomMargin=18 * mm,
                          title="Revisión de fichas nuevas · ¿Puedo comer…? v2.2.0", author="Proyecto ¿Puedo comer…?",
                          subject="Fichas nuevas para revisión por matrona o ginecóloga/o")
    doc.addPageTemplates([PageTemplate(id="p", frames=[Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="f")], onPage=pie)])
    from collections import Counter
    c = Counter(a["estado"] for a in nuevos)
    E = []
    E += [Spacer(1, 10), Paragraph("¿Puedo comer…?", S["t"]),
          Paragraph("Revisión profesional de las 34 fichas nuevas (versión 2.2.0 · 4 de octubre de 2026)", S["st"]),
          Paragraph("Para la matrona, la ginecóloga o el ginecólogo", S["h1"]),
          Paragraph("«¿Puedo comer…?» es una web gratuita, en español de España, para consultar de forma orientativa si un alimento es seguro "
                    "durante el embarazo. Cada ficha da un color (Apto, Precaución o Evitar), explica las condiciones y cita su fuente oficial. "
                    "En toda la app se ve el aviso de que <b>no sustituye el consejo de la matrona ni del ginecólogo o la ginecóloga</b>.", S["p"]),
          Paragraph(f"La base pasa de 78 a 112 alimentos. Este documento recoge solo las <b>34 fichas nuevas</b> "
                    f"(Apto {c['verde']} · Precaución {c['amarillo']} · Evitar {c['rojo']}), redactadas a partir de estas fuentes:", S["p"])]
    E += lista(["AESAN — Alimentación segura durante el embarazo (2.ª ed., 2024).",
                "AESAN — Evita la listeriosis: consejos prácticos para grupos de riesgo (2026).",
                "NHS (Reino Unido) — Foods to avoid in pregnancy, solo como apoyo; prevalece AESAN.",
                "EFSA — Cafeína (hasta 200 mg al día de todas las fuentes)."])
    E += [Paragraph("Cómo revisar", S["h1"])]
    E += lista(["Cada ficha muestra el texto tal como lo ve la usuaria, sus fuentes y una <b>pregunta concreta</b> sobre el punto más discutible.",
                "Marca «De acuerdo», «Cambiar estado», «Corregir texto» o «Quitar la ficha», y escribe lo que haga falta en «Comentarios».",
                "Las marcas comerciales (Mercadona/Hacendado, Lidl, Carrefour, Don Simón…) solo sirven para que la búsqueda encuentre el producto. "
                "La recomendación depende siempre de la etiqueta del envase concreto.",
                "Estas fichas ya están publicadas en la app; tus correcciones se aplicarán en cuanto las recibamos. Las 78 fichas anteriores no han cambiado."], html=True)
    E += [Paragraph("Índice de fichas nuevas", S["h1"])]
    filas = [[Paragraph("<b>#</b>", S["cel"]), Paragraph("<b>Ficha</b>", S["cel"]), Paragraph("<b>Categoría</b>", S["cel"]), Paragraph("<b>Estado</b>", S["cel"]), Paragraph("<b>OK</b>", S["cel"])]]
    estilo = [("GRID", (0, 0), (-1, -1), 0.4, BORDE), ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e6efec")), ("VALIGN", (0, 0), (-1, -1), "MIDDLE")]
    for i, a in enumerate(nuevos, 1):
        txt, fg, bg = ESTADO[a["estado"]]
        filas.append([Paragraph(str(i), S["cel"]), Paragraph(esc(a["nombre"]), S["cel"]), Paragraph(esc(a["categoria"]), S["cel"]),
                      Paragraph(f"<font color='{fg.hexval().replace('0x', '#')}'>{txt.split(' ·')[0]}</font>", S["cel"]), Paragraph("☐", S["cel"])])
        estilo.append(("BACKGROUND", (3, i), (3, i), bg))
    t = Table(filas, colWidths=[10 * mm, None, 46 * mm, 30 * mm, 10 * mm], repeatRows=1); t.setStyle(TableStyle(estilo))
    E += [t, PageBreak(), Paragraph("Fichas nuevas", S["h1"])]
    for i, a in enumerate(nuevos, 1):
        E.append(KeepTogether(ficha(i, a)))
    E += [PageBreak(), Paragraph("Lo que no se ha añadido, y por qué", S["h1"]),
          Paragraph("Para no inventar recomendaciones, solo se han creado fichas con respaldo en las fuentes citadas. Si crees que alguna de estas debería estar, indícalo con su criterio:", S["p"])]
    tn = Table([[Paragraph("<b>Alimento</b>", S["cel"]), Paragraph("<b>Motivo</b>", S["cel"]), Paragraph("<b>¿Añadir? Estado y criterio</b>", S["cel"])]] +
               [[Paragraph(esc(x), S["cel"]), Paragraph(esc(y), S["cel"]), ""] for x, y in NO_INCLUIDOS],
               colWidths=[40 * mm, None, 50 * mm])
    tn.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.4, BORDE), ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e6efec")), ("VALIGN", (0, 0), (-1, -1), "TOP"),
                            ("BOTTOMPADDING", (0, 1), (-1, -1), 10)]))
    E += [tn, Spacer(1, 14), Paragraph("Comentarios generales", S["h1"])]
    lineas = Table([[""]] * 8, colWidths=[doc.width], rowHeights=[9 * mm] * 8)
    lineas.setStyle(TableStyle([("LINEBELOW", (0, 0), (-1, -1), 0.4, BORDE)]))
    E += [lineas, Spacer(1, 14),
          Paragraph("Nombre y firma de quien revisa: ______________________________________ &nbsp;&nbsp; Fecha: ____ / ____ / ________", S["p"]),
          Spacer(1, 8), Paragraph("Gracias por tu tiempo. Tus correcciones se aplicarán a la app y quedarán anotadas en su registro de cambios.", S["pq"])]
    doc.build(E)
    print(salida, "·", len(nuevos), "fichas")

if __name__ == "__main__":
    main()
