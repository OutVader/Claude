// Prueba favoritos, historial y el escáner de códigos (cámara y BarcodeDetector simulados; Open Food Facts simulado o real).
// Uso: node tools/probar-fav-codigo.mjs <url> [real]
import { chromium } from "/opt/node-tools/node_modules/playwright/index.mjs";
const [url, modo] = process.argv.slice(2);
const b = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium",
  ...(process.env.HTTPS_PROXY && url.startsWith("http") ? { proxy: { server: process.env.HTTPS_PROXY } } : {}),
  args: ["--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream", ...(process.env.SPKI_EXTRA ? [`--ignore-certificate-errors-spki-list=${process.env.SPKI_EXTRA}`] : [])] });
const ctx = await b.newContext({ viewport: { width: 390, height: 900 }, permissions: ["camera"] });
const p = await ctx.newPage(); const errores = []; p.on("pageerror", (e) => errores.push(e.message));
let fallos = 0; const ok = (c, t) => { console.log(`${c ? "OK   " : "FALLO"} ${t}`); if (!c) fallos++; };
const PRODUCTOS = {
  "8480000160072": { product_name: "Tortilla de patatas con cebolla", brands: "Hacendado", ingredients_text_es: "Patata, huevo pasteurizado, aceite de girasol, cebolla, sal.", categories_tags: ["en:meals"] },
  "1111111111116": { product_name: "Bombones surtidos", brands: "Prueba", ingredients_text_es: "Azúcar, cacao, licor de cereza 5%, vinagre de vino.", categories_tags: ["en:chocolates"] },
};
if (modo !== "real") await p.route(/world\.openfoodfacts\.org\/api\/v2\/product\/(\d+)/, (r) => {
  const c = r.request().url().match(/product\/(\d+)/)[1], pr = PRODUCTOS[c];
  r.fulfill({ status: pr ? 200 : 404, contentType: "application/json", body: JSON.stringify(pr ? { status: 1, code: c, product: pr } : { status: 0, code: c }) });
});
// Lector de códigos simulado: «ve» el código tras 1 s (Chromium de escritorio Linux no trae BarcodeDetector).
await p.addInitScript(() => {
  if (!("BarcodeDetector" in window)) window.BarcodeDetector = class { static async getSupportedFormats() { return ["ean_13", "ean_8"]; }
    constructor() { this.t = Date.now(); } async detect() { return Date.now() - this.t > 1000 ? [{ rawValue: "8480000160072", format: "ean_13" }] : []; } };
});
await p.goto(url); await p.waitForTimeout(500);
// --- Favoritos e historial ---
await p.fill("#q", "miel"); await p.press("#q", "Enter"); await p.waitForTimeout(300);
await p.click('#resultados button[data-fav="miel"]'); await p.waitForTimeout(200);
ok(await p.getAttribute('#resultados button[data-fav="miel"]', "aria-pressed") === "true", "estrella de «Miel» marcada");
await p.fill("#q", "jamón"); await p.press("#q", "Enter"); await p.waitForTimeout(300);
const mis = (await p.textContent("#misAlimentos")).replace(/\s+/g, " ");
ok(/Tus favoritos.*Miel/.test(mis) && /Vistos recientemente.*Jamón curado.*Miel/.test(mis), `Buscar muestra favoritos e historial: «${mis.slice(0, 160)}»`);
await p.reload(); await p.waitForTimeout(500);
ok(/Miel/.test(await p.textContent("#misAlimentos")), "favoritos persisten tras recargar (localStorage)");
await p.click("#tab-listado"); await p.click("#btnSoloFav"); await p.waitForTimeout(200);
ok((await p.textContent("#contador")).trim() === "1 de 112 alimentos", `Listado «Solo favoritos»: ${(await p.textContent("#contador")).trim()}`);
await p.click("#btnSoloFav");
await p.click("#tab-buscar"); await p.click("#btnBorrarHist"); await p.waitForTimeout(200);
ok(!/Vistos recientemente/.test(await p.textContent("#misAlimentos")), "Borrar historial");
// --- Escáner con cámara simulada ---
await p.click("#tab-foto"); await p.click("#btnCodigo");
await p.waitForSelector("#resultadosFoto .producto", { timeout: 20000 }).catch(() => {});
const r1 = (await p.textContent("#resultadosFoto")).replace(/\s+/g, " ");
ok(/Tortilla de patatas envasada/.test(r1) || modo === "real", `Cámara → código 8480000160072 → «${r1.slice(0, 200)}»`);
ok(await p.isHidden("#videoCodigo"), "la cámara se apaga tras leer el código");
// --- Código escrito a mano ---
await p.fill("#inputCodigo", modo === "real" ? "8480000160072" : "1111111111116"); await p.press("#inputCodigo", "Enter");
await p.waitForSelector("#resultadosFoto .producto", { timeout: 20000 }); await p.waitForTimeout(300);
const r2 = (await p.textContent("#resultadosFoto")).replace(/\s+/g, " ");
console.log("      →", r2.slice(0, 320));
if (modo !== "real") ok(/Bebidas alcohólicas/.test(r2) && /Chocolate/.test(r2) && !/vinagre.*alcohol/i.test(r2.split("Ingredientes")[0]), "manual: bombones con licor → pista de alcohol + ficha Chocolate");
await p.fill("#inputCodigo", "9999999999999"); await p.press("#inputCodigo", "Enter"); await p.waitForTimeout(modo === "real" ? 4000 : 800);
ok(/no está en Open Food Facts/.test(await p.textContent("#resultadosFoto")), "código inexistente → mensaje claro");
if (process.env.CAPTURA) await p.screenshot({ path: process.env.CAPTURA });
if (errores.length) { console.log("Errores JS:", errores); fallos++; }
await b.close(); console.log(fallos ? `${fallos} fallo(s)` : "Todo OK"); process.exit(fallos ? 1 : 0);
