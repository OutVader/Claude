// Simula respuestas de Gemini (sin clave real) y comprueba la cadena de reintentos y reservas.
// Uso: node tools/simular-gemini.mjs <url> <imagen>   (SPKI_EXTRA opcional, como en verificar.mjs)
import { chromium } from "/opt/node-tools/node_modules/playwright/index.mjs";
const [url, img] = process.argv.slice(2);
const b = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium",
  ...(process.env.HTTPS_PROXY && url.startsWith("http") ? { proxy: { server: process.env.HTTPS_PROXY } } : {}),
  args: process.env.SPKI_EXTRA ? [`--ignore-certificate-errors-spki-list=${process.env.SPKI_EXTRA}`] : [] });
const OK = (desc) => ({ status: 200, contentType: "application/json", body: JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ descripcion: desc, alimentos: [{ nombre: "jamón serrano", preparacion: "curado" }] }) }] } }] }) });
const E = (status, msg = "overloaded") => ({ status, contentType: "application/json", body: JSON.stringify({ error: { code: status, message: msg } }) });
const escenarios = {
  reserva: (m) => (m === "gemini-3.8-flash" ? E(503) : OK("plato")),
  todo503: (m) => E(503),
  cuota429: (m) => (["gemini-3.8-flash", "gemini-3.7-flash"].includes(m) ? E(429, "quota") : OK("plato")),
  sinNivel: (m, body) => (body.generationConfig.thinkingConfig ? E(400, "thinking_level is not supported for this model") : OK("plato")),
  clave: () => E(400, "API key not valid. Please pass a valid API key. API_KEY_INVALID"),
};
let fallos = 0;
for (const [nombre, fn] of Object.entries(escenarios)) {
  const ctx = await b.newContext(); const p = await ctx.newPage();
  const llamadas = []; let segundaVuelta = false;
  await p.route("https://generativelanguage.googleapis.com/**", (r) => {
    const m = r.request().url().match(/models\/([^:]+)/)[1]; const body = JSON.parse(r.request().postData());
    llamadas.push(`${m}${body.generationConfig.thinkingConfig ? "[" + body.generationConfig.thinkingConfig.thinkingLevel + "]" : ""}`);
    r.fulfill(segundaVuelta ? OK("reintento") : fn(m, body));
  });
  await p.goto(url); await p.evaluate(() => localStorage.setItem("pc_gemini_key", "FALSA-de-prueba"));
  await p.reload(); await p.click("#tab-foto");
  const t0 = Date.now();
  await p.setInputFiles("#inputFoto", img);
  await p.waitForFunction(() => !document.querySelector("#resultadosFoto .cargando"), null, { timeout: 170000 });
  const txt = (await p.textContent("#resultadosFoto")).replace(/\s+/g, " ");
  console.log(`[${nombre}] ${((Date.now() - t0) / 1000).toFixed(1)} s · ${llamadas.length} llamadas: ${llamadas.join(", ")}\n  → ${txt.slice(0, 230)}`);
  if (llamadas.some((l) => /lite/.test(l))) { console.log("  FALLO: ha usado un modelo lite"); fallos++; }
  if (llamadas.some((l) => /^gemini-2/.test(l) && l.includes("["))) { console.log("  FALLO: thinkingLevel enviado a 2.x"); fallos++; }
  if (await p.isVisible("#btnReintentarFoto")) {
    segundaVuelta = true; await p.click("#btnReintentarFoto");
    await p.waitForFunction(() => !document.querySelector("#resultadosFoto .cargando"), null, { timeout: 60000 });
    console.log(`  Reintentar con la misma foto → ${(await p.textContent("#resultadosFoto")).replace(/\s+/g, " ").slice(0, 110)}`);
  }
  await ctx.close();
}
await b.close(); process.exit(fallos ? 1 : 0);
