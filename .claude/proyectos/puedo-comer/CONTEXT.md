# ¿Puedo comer…? — Contexto del proyecto y prompt para publicar con Grok

> Versión de la app: **2.1.0** (datos v2.1.0, 4-oct-2026) · Archivo para publicar: `embarazo-alimentos-standalone.html` (en esta misma carpeta `entrega/`). El `.txt` tiene el mismo contenido, para copiarlo y pegarlo.

## 1. Objetivo
App web móvil (PWA), en español de España, para consultar **con calma** si un alimento es seguro durante el embarazo. Está pensada también para embarazos por reproducción asistida (incluida la reproducción asistida con donante). Da una respuesta clara con color, icono y texto, explica las condiciones («cuándo sí»), da consejos y alternativas y **cita la fuente oficial de cada ficha**. Es orientativa y no sustituye a la matrona ni a la ginecóloga o el ginecólogo.

## 2. Funciones
- **Buscar:** autocompletado accesible. Normaliza tildes, tolera erratas y busca por palabra completa en los sinónimos («miel» no devuelve «mielga»). Incluye una búsqueda semántica ligera por conceptos («mercurio», «listeria», «cafeína»…). Si el alimento no está en la base, muestra una tarjeta neutra que invita a consultarlo.
- **Listado:** los 78 alimentos agrupados en 9 categorías y en orden alfabético, con filtros por color (Apto / Precaución / Evitar) y por categoría y un contador. Al tocar un alimento se abre su ficha.
- **Foto (opcional):** analiza un plato o una etiqueta con Gemini (modelo por defecto `gemini-3.8-flash`, alternativa `gemini-flash-latest`) usando **la clave de la propia usuaria**, que se guarda solo en su navegador. Cada alimento detectado se cruza con la base local.
- **Ajustes:** clave de Gemini, modelo, URL de sincronización (JSON o CSV de Google Sheets), «Sincronizar ahora», «Borrar clave», «Restablecer datos» y estado técnico.
- **Funciona sin conexión** (salvo la foto) y en modo privado. Los errores se avisan de forma discreta sin bloquear la interfaz: fallos de red, JSON inválido, timeouts, cuota o clave de Gemini, imágenes no válidas…
- **Enlaces directos:** `?q=jamón` · `?vista=listado&color=rojo,amarillo&cat=Pescados`.
- **Accesibilidad:** el color siempre va acompañado de texto e icono, contraste AA, navegación por teclado y `aria-live`.

## 3. Datos: esquema de `alimentos.json`
```json
{ "version": "2.1.0", "actualizado": "2026-10-04", "nota": "…", "alimentos": [ /* fichas */ ] }
```
Campos de cada ficha: `id` (único), `nombre`, `sinonimos[]` (no se pueden repetir entre fichas), `categoria`, `estado` (`verde` | `amarillo` | `rojo`), `resumen`, `riesgos[]`, `condiciones[]`, `consejos[]`, `alternativas[]` y `fuente[]` («Organismo — Título: URL»).

Ejemplo real de ficha:
```json
{
  "id": "atun-lata",
  "nombre": "Atún y bonito en lata",
  "sinonimos": [
    "atún en lata",
    "atun",
    "bonito en conserva",
    "bonito del norte en lata",
    "atún claro",
    "lata de atún",
    "ventresca en lata",
    "atún en aceite"
  ],
  "categoria": "Pescados",
  "estado": "amarillo",
  "resumen": "Puedes tomarlo, pero con medida: el atún no está entre las especies de bajo mercurio de AESAN y el NHS fija un máximo semanal.",
  "riesgos": [
    "mercurio"
  ],
  "condiciones": [
    "NHS: no más de 4 latas de atún por semana.",
    "AESAN lo considera de contenido medio en mercurio: entra en tus 3-4 raciones semanales de pescado, variando especies."
  ],
  "consejos": [
    "Alterna con sardinas o caballa en lata (bajo mercurio).",
    "Lata abierta: a la nevera y consúmela pronto."
  ],
  "alternativas": [
    "Sardinas en lata",
    "Caballa en lata"
  ],
  "fuente": [
    "AESAN — Recomendaciones de consumo de pescado por presencia de mercurio: https://www.aesan.gob.es/dam/jcr:37655af5-1ba6-4a9e-a756-79a51810aac7/RECOMENDACIONES_consumo_pescado_MERCURIO_AESAN_WEB.pdf",
    "NHS (Reino Unido, apoyo) — Foods to avoid in pregnancy: https://www.nhs.uk/pregnancy/keeping-well/foods-to-avoid/"
  ]
}
```
Recuento: 78 alimentos (verde 23 · amarillo 30 · rojo 25). Categorías: Pescados 16, Carnes y embutidos 15, Lácteos y quesos 11, Bebidas 9, Frutas, verduras y vegetales 8, Huevos y postres 6, Cereales, legumbres y otros 6, Mariscos 4, Dulces y endulzantes 3.

## 4. Reglas clave y fuentes
Prioridad: **AESAN** (España) > **EFSA** / **OMS** > **NHS** (Reino Unido), que se usa como apoyo explícito. Todas las URL respondían HTTP 200 el 04-10-2026.
- **Cocinado:** carne y pescado a más de 70 ºC durante 2 minutos en el centro. Para el anisakis basta con pescado a 60 ºC durante 1 minuto en toda la pieza (AESAN, embarazo 2024 y tríptico de anisakis).
- **Listeria (AESAN, folleto 2026):**
  - Evitar: quesos de leche cruda salvo cocinados, patés refrigerados, ahumados refrigerados, ensaladas envasadas y sándwiches listos para comer, brotes crudos y zumos sin pasteurizar.
  - Fruta cortada: solo recién cortada o refrigerada entre 1 y 3 días.
  - Alternativas aceptadas: mayonesa con huevo pasteurizado, conservas y fiambre en lata.
- **Toxoplasma:** evitar embutidos curados crudos y carne poco hecha si no hay inmunidad. Cuenta la serología de la persona gestante, también en reproducción asistida con donante.
- **Mercurio (AESAN):** evitar pez espada, atún rojo, tiburón y lucio. El atún en lata está en **ámbar**: AESAN no lo incluye entre las especies de bajo mercurio y el NHS pone un máximo de 4 latas a la semana.
- **Cafeína (EFSA):** hasta 200 mg al día sumando todas las fuentes. Las cantidades por bebida son estimaciones del NHS. AESAN pide evitar las bebidas energéticas.
- **Alcohol:** nada, en ningún trimestre (AESAN, OMS).
- **Otros:** algas, por el yodo (AESAN); vitamina A e hígado (AESAN/EFSA, nivel máximo 3000 µg al día); raíz de regaliz (NHS, AEMPS); poleo (EMA, aceite de poleo); kombucha (AESAN, por el alcohol; OCU como apoyo).
- **Fuentes principales:**
  - AESAN — Alimentación segura durante el embarazo (2024): https://www.aesan.gob.es/dam/jcr:6f57a77f-541c-4c54-a124-543d65b1aaf1/alimentacion_segura_embarazo.pdf
  - AESAN — Folleto Listeriosis (2026): https://www.aesan.gob.es/dam/jcr:b8fc1e69-c7a5-4d6c-98c0-e3b9fec5c4d6/Folleto_LISTERIOSIS.pdf
  - AESAN — Mercurio: https://www.aesan.gob.es/dam/jcr:37655af5-1ba6-4a9e-a756-79a51810aac7/RECOMENDACIONES_consumo_pescado_MERCURIO_AESAN_WEB.pdf
  - AESAN — Anisakis: https://www.aesan.gob.es/dam/jcr:d3142291-9e1e-463c-8402-1a5b8e604adf/Triptico_anisakis.pdf
  - EFSA — Cafeína: https://www.efsa.europa.eu/es/topics/topic/caffeine
  - OMS — Alcohol: https://www.who.int/es/news-room/fact-sheets/detail/alcohol
  - NHS — Foods to avoid in pregnancy: https://www.nhs.uk/pregnancy/keeping-well/foods-to-avoid/
  - Y 10 más (sushi, algas, arsénico, vitamina A, aspartamo, isoflavonas, poleo, regaliz, miel, kombucha), citadas en cada ficha.

## 5. Decisiones AESAN vs NHS (prevalece AESAN)
| Tema | AESAN | NHS | En la app |
|---|---|---|---|
| Quesos duros de leche cruda | Evitar salvo cocinados (2026) | Seguros | Queso curado en ámbar: mejor pasteurizado y sin corteza |
| Pescado | 3-4 raciones a la semana, sobre todo azul | Máximo 2 raciones a la semana de pescado azul | Se sigue AESAN |
| Paté | Evitar los refrigerados | Paté de carne refrigerado: «con cuidado»; hígado: evitar | Rojo (listeria + vitamina A en el de hígado) |
| Sushi | No aconsejable en embarazadas | Seguro si está cocinado | Pescado crudo en rojo; sushi vegetal o cocinado en ámbar |
| Atún | Contenido medio de mercurio, sin límite específico para el embarazo | Máximo 4 latas o 2 filetes a la semana | Ámbar, con la cifra del NHS |

## 6. Privacidad
- Sin cuentas, sin analítica, sin cookies y sin servidores propios.
- Las búsquedas se hacen solo en el dispositivo.
- La clave de Gemini se guarda únicamente en el `localStorage` del navegador y no va en el código.
- Las fotos salen del dispositivo **solo** cuando la usuaria pulsa «Foto», y van directas a la API de Google (Gemini) con su clave. La app no las guarda.
- La caché de datos está en IndexedDB y se borra con «Restablecer datos».

## 7. Limitaciones
- Es orientativa: no contempla alergias, diabetes gestacional, tratamientos ni casos particulares.
- La identificación por foto puede equivocarse.
- La versión de archivo único no lleva service worker. Una vez abierta funciona sin red, pero para recargarla sin conexión hace falta la PWA completa (carpeta con `sw.js`). Para instalarla como app hace falta HTTPS.
- Las recomendaciones cambian: hay que revisar las fuentes periódicamente (`node tools/prueba.mjs` comprueba que las URL respondan 200).

## 8. Aviso médico (debe verse siempre en la app)
«Esta herramienta es orientativa y no sustituye el consejo de tu matrona, ginecóloga/o o equipo de reproducción asistida. Ante cualquier duda, síntoma o situación particular, consulta con tu profesional sanitario.»

---

## 9. Qué puede hacer Grok hoy para publicar un HTML (verificado el 04-10-2026)
- **Grok Build sí publica apps en un enlace público.** xAI anuncia que cada app publicada recibe una dirección `*.grok.me` y que el acceso se puede limitar a «solo tú», «cualquiera con el enlace» o «todo internet». También admite dominio propio, exportar a GitHub, remix y secretos.
  - Fuente: xAI, «Grok Build on web and mobile», https://x.ai/news/grok-build-for-everyone. La página no muestra la fecha; guías de terceros la fechan el 19-08-2026.
  - Según ese anuncio está disponible en todos los planes, en la web, iOS y Android. Al lanzarse en julio era una beta solo para SuperGrok Heavy: https://x.ai/news/grok-build-mode.
- **Grok Studio** (abril de 2025) previsualiza HTML dentro del chat. Esa fuente no menciona ninguna opción para publicarlo. Fuente: Engadget, 16-04-2025, https://www.engadget.com/ai/xais-grok-launches-studio-interface-for-documents-and-code-123016714.html.
- Los **enlaces para compartir conversaciones** comparten el chat, no alojan una web. Fuente: xAI, preguntas frecuentes, https://x.ai/legal/faq.
- **Lo que NO está confirmado por xAI:**
  - Si Grok Build puede **importar un HTML ya hecho y publicarlo sin modificarlo**. Los anuncios oficiales hablan de apps que Grok crea a partir de una descripción.
  - El tamaño máximo de archivo o de texto pegado (este HTML ocupa unos 208 KB).
  - Si el alojamiento en grok.me aplica restricciones (CSP, iframe con sandbox) que afecten a la cámara, al `localStorage` o a las llamadas a Gemini.

  Por eso el prompt pide a Grok que lo confirme y, si no puede, que pase al plan B (Netlify Drop o GitHub Pages).

---

## 10. PROMPT listo para pegar en Grok

> Adjunta `embarazo-alimentos-standalone.html` o, si no se admite adjuntar .html, `embarazo-alimentos-standalone.txt`. Si tampoco se puede adjuntar, pega su contenido después del prompt.

```text
Hola, Grok. Quiero publicar una app web que ya está terminada y probada. No quiero que la rediseñes ni que la reescribas.

QUÉ ES
- «¿Puedo comer…?»: una PWA en español de España para consultar si un alimento es seguro durante el embarazo (78 alimentos con fuentes AESAN/EFSA/OMS y NHS como apoyo).
- Es UN ÚNICO archivo HTML autocontenido (te lo adjunto): HTML, CSS, JS, datos, iconos y manifest en data URI. No usa CDN, ni backend, ni base de datos, ni claves en el código.
- La función de foto llama desde el navegador a https://generativelanguage.googleapis.com con la clave de Gemini que cada usuaria introduce en Ajustes (se guarda en su localStorage). NO actives las APIs de xAI ni añadas secretos.

LO QUE TE PIDO, EN ESTE ORDEN
1. Dime con sinceridad si en este chat puedes usar Grok Build para publicar ESTE archivo tal cual en un enlace grok.me. Si no lo tienes disponible o no puedes publicarlo sin modificarlo, dímelo y salta al paso 5.
2. Si puedes: crea el proyecto con el archivo adjunto como index.html SIN CAMBIAR ni una línea (ni estilos, ni textos, ni datos, ni el aviso médico). Si tu entorno te obliga a tocar algo (por ejemplo, la Content-Security-Policy de la etiqueta meta), enséñame el diff exacto antes de aplicarlo.
3. Comprueba en la vista previa que:
   a) la búsqueda «jamón» muestra «Jamón curado…» en rojo y «miel» muestra «Miel» en verde, sin «Tiburón»;
   b) la pestaña Listado muestra «78 de 78 alimentos» y, filtrando solo «Evitar», «25 de 78 alimentos»;
   c) se ve el aviso médico del pie;
   d) en Ajustes, el estado técnico indica «Ajustes en el navegador: disponible». Si pone «no disponible», avísame: significa que el alojamiento bloquea localStorage.
4. Publícala con acceso «Cualquiera con el enlace» (no «Todo internet» de momento) y dame la URL grok.me. Recuérdame que la abra en una ventana privada para comprobar que funciona sin mi sesión.
5. PLAN B, si no puedes publicarla tú: guíame paso a paso, con frases cortas y en español, para publicarla gratis con
   - Netlify Drop (https://app.netlify.com/drop): crear una carpeta, guardar el archivo como index.html, arrastrar la carpeta, crear cuenta para que no caduque y cambiar el nombre del sitio; o
   - GitHub Pages: crear un repositorio público, subir index.html, Settings → Pages → Deploy from a branch → main / (root), y la URL https://USUARIO.github.io/REPO/.
   Si te lo pido, genera también el contenido de un repositorio mínimo (index.html = el archivo adjunto sin cambios, README.md breve, .nojekyll vacío).
6. No inventes funciones ni pasos que no puedas comprobar. Si no estás seguro de algo de Grok Build (límites de tamaño, restricciones del alojamiento), dímelo.

DATOS PARA LA FICHA DEL ENLACE (si los pides)
- Nombre: ¿Puedo comer…? · Alimentación segura en el embarazo
- Descripción: Consulta tranquila sobre qué alimentos son seguros en el embarazo, con fuentes oficiales (AESAN, EFSA, OMS). Orientativa: no sustituye a tu matrona ni a tu ginecóloga/o.
- Portada: tonos verde salvia (#2f6f62) y blanco, sin fotos de personas ni de comida cruda.
```

### Después de publicar
- Abre la URL en el móvil → menú del navegador → «Añadir a pantalla de inicio».
- Para actualizar la app: regenera el archivo (`node tools/standalone.mjs`) y vuelve a subirlo por la misma vía. En Netlify: *Deploys* → arrastrar la carpeta de nuevo.
