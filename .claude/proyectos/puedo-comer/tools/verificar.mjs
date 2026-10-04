// Comprueba las 5 condiciones de publicación sobre una URL (http(s):// o file://).
// Uso: node tools/verificar.mjs <url>   (contexto de navegador limpio, sin sesión)
import { chromium } from "/opt/node-tools/node_modules/playwright/index.mjs";

const url = process.argv[2];
if (!url) { console.error("Falta la URL"); process.exit(2); }
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium" });
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: "es-ES" });
const page = await ctx.newPage();
const errores = [];
page.on("pageerror", (e) => errores.push(e.message));
let fallos = 0;
const ok = (n, cond, txt) => { console.log(`${cond ? "OK " : "FALLO"} ${n}. ${txt}`); if (!cond) fallos++; };

const resp = await page.goto(url, { waitUntil: "load" });
console.log(`URL: ${page.url()}  HTTP ${resp ? resp.status() : "(file)"}  content-type: ${resp ? resp.headers()["content-type"] : "-"}`);
console.log(`Título: ${await page.title()}`);
await page.waitForTimeout(800);

async function buscar(q) {
  await page.click("#tab-buscar");
  await page.fill("#q", q);
  await page.press("#q", "Enter");
  await page.waitForTimeout(500);
  return page.$$eval("#resultados article.tarjeta", (as) => as.map((a) => ({ clase: a.className, titulo: (a.querySelector("h2,h3")?.textContent || "").trim() })));
}

const jamon = await buscar("jamón");
ok(1, jamon.length > 0 && /Jamón curado/.test(jamon[0].titulo) && jamon[0].clase.includes("rojo"), `«jamón» → ${JSON.stringify(jamon.slice(0, 2))}`);
const miel = await buscar("miel");
const todoMiel = await page.textContent("#resultados");
ok(2, miel.length > 0 && miel[0].titulo === "Miel" && miel[0].clase.includes("verde") && !/Tiburón/.test(todoMiel), `«miel» → ${JSON.stringify(miel)}; ¿Tiburón?: ${/Tiburón/.test(todoMiel)}`);

await page.click("#tab-listado");
await page.waitForTimeout(300);
const c1 = (await page.textContent("#contador")).trim();
await page.click('.filtro[data-color="verde"]');
await page.click('.filtro[data-color="amarillo"]');
await page.waitForTimeout(300);
const c2 = (await page.textContent("#contador")).trim();
ok(3, c1 === "78 de 78 alimentos" && c2 === "25 de 78 alimentos", `Listado: «${c1}»; solo Evitar: «${c2}»`);

const cuerpo = await page.textContent("body");
const aviso = await page.isVisible("text=/no sustituye el consejo de tu matrona, ginecóloga\\/o/");
ok(4, aviso && /no sustituye/.test(cuerpo), `Aviso médico visible: ${aviso}`);

await page.click("#tab-ajustes");
await page.waitForTimeout(300);
const ajustes = await page.textContent("#panel-ajustes");
const m = ajustes.match(/Ajustes en el navegador\s*:?\s*([^\n]*?)(Caché|$)/);
ok(5, /Ajustes en el navegador\s*:?\s*disponible/.test(ajustes), `Ajustes en el navegador: «${m ? m[1].trim() : "?"}»`);

if (errores.length) console.log("Errores JS:", errores);
await page.screenshot({ path: process.env.CAPTURA || "/dev/null", fullPage: false }).catch(() => {});
await browser.close();
console.log(fallos ? `${fallos} comprobación(es) fallida(s)` : "Las 5 comprobaciones pasan");
process.exit(fallos ? 1 : 0);
