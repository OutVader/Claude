# Bitácora

## 2026-10-04
- Partimos del index.html de 214505 bytes (md5 8c486fe0…), con `pedirGemini` y los modelos de reserva.
- Cambios en el flujo de la foto (sin tocar datos ni avisos):
  - Texto de espera: antes decía «máx. 20 s», pero con los reintentos puede tardar más. Ahora lo avisa.
  - Si el modelo elegido da 503 y uno de reserva da 404, se muestra el 503, que es el error que importa.
  - El aviso del modelo de reserva ya no da por hecho «saturado»: dice «saturado o no disponible».
- Verificación local (file://): 5/5. Simulación de Gemini: reserva tras 503 OK, todo caído → 503, clave inválida → sin reintentos.
- Publicación: no se puede crear el repo nuevo desde la sesión (403, integración limitada a OutVader/Claude).
- Publicada en GitHub Pages: rama `gh-pages` de OutVader/Claude (solo index.html, README.md, .nojekyll). Pages se activó solo al subir la rama.
  URL: https://outvader.github.io/Claude/ — el archivo servido es idéntico a `public/index.html` (mismo md5).
- Verificación de la URL pública con Chromium limpio (`tools/verificar.mjs`): 5/5. Flujo de la foto simulado: OK.
  Nota: en el contenedor cloud, Chromium pasa por el proxy de salida; se confía solo en la clave (SPKI) de su CA vía `SPKI_EXTRA`.
- v2.1.0 + mejora de la foto (petición de Iñaki: reservas inteligentes, nada de «lite"):
  - Cadena: modelo elegido (3 intentos, esperas de 1,5 s y 4 s) → gemini-3.7-flash → 3.6-flash → 3.5-flash → 2.5-flash (2 intentos cada uno). Nunca «lite».
    Modelos comprobados en ai.google.dev/gemini-api/docs/models (todos estables; 2.5-flash obsoleto pero en servicio).
  - Nuevo ajuste «Nivel de razonamiento» (thinkingConfig.thinkingLevel), por defecto ALTO. Solo se envía a Gemini 3+; si un modelo lo rechaza (400), se repite sin él.
  - Tiempo por llamada 45 s (antes 20) y tope total de 150 s. Un timeout salta al siguiente modelo; un 404 no se repite.
  - El progreso (modelo e intento) se ve en pantalla; botón «Reintentar con la misma foto» en errores de saturación/cuota/tiempo.
  - Clave inválida, imagen rechazada o filtro de seguridad cortan la cadena (no son saturación).
  - Prueba: `tools/simular-gemini.mjs` (reserva, todo 503, cuota 429, nivel no admitido, clave inválida, reintentar).
- Otros servicios de visión (petición de Iñaki), opcionales y con la clave de cada persona, como reserva de Gemini o como principal:
  - Groq: `qwen/qwen3.8-27b` (visión; gratis sin tarjeta, 30 rpm / 1000 al día según console.groq.com/docs/rate-limits).
  - OpenRouter: `qwen/qwen3.8-27b:free`, `google/gemma-4-31b-it:free`, `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` (lista de /api/v1/models, filtro «:free» con entrada de imagen).
  - Mistral: `mistral-large-2512` (Large 3, visión). medium-2508 y small-2506 ya están retirados.
  - Descartados: NVIDIA directo (integrate.api.nvidia.com) y GitHub Models no envían cabeceras CORS, así que el navegador no puede llamarlos. DeepSeek: visión solo de pago (deepseek-flash). Qwen DashScope: cuota gratis solo para cuentas nuevas en Alibaba Cloud, con un alta compleja.
  - Cadena: servicio principal (por defecto Gemini con su cadena Flash) → resto con clave, en orden Gemini, Groq, OpenRouter, Mistral. Una clave inválida descarta ese servicio. Si todos fallan, el error se resume por servicio.
  - Prueba: `tools/simular-gemini.mjs` (9 escenarios).
