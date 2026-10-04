# ¿Puedo comer…? · Alimentación segura en el embarazo

PWA de un solo archivo (`public/index.html`, v2.1.0, datos 2026-10-04). 78 alimentos (25 «evitar»).
Fuentes AESAN, EFSA y OMS; NHS como apoyo. Orientativa: no sustituye a tu matrona ni a tu ginecóloga/o.

- `public/index.html` — la app (parte del index.html de 214505 bytes con reintento de Gemini).
- `tools/verificar.mjs` — prueba con Playwright de las 5 comprobaciones de publicación: `node tools/verificar.mjs <url>`.
- `CONTEXT.md` — contexto del proyecto (redactado para v2.1.0; las cifras actuales están en la bitácora).
- `datos/` — datos 2.1.0 extraídos, altas de la 2.2.0 y datos 2.2.0 generados. `tools/construir_datos.py` los une al index.html.
- `tools/simular-gemini.mjs` — simulación de la cadena de servicios de IA para las fotos.
- `docs/revision-fichas-2.2.0.pdf` — PDF para que la matrona revise las 34 fichas nuevas (`tools/pdf_revision.py` lo regenera).
- `bitacora.md` — registro.

**Estado:** v2.2.0 (112 alimentos) publicada en https://outvader.github.io/Claude/ (rama `gh-pages`), verificada.
