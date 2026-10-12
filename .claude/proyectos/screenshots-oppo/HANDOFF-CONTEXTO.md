# HANDOFF — Proyecto Screenshots OPPO → "Traspaso de archivos" genérico

> Para una sesión nueva de Claude (u otro LLM) **sin acceso a la conversación original**.
> Léelo entero antes de tocar nada. Actualizado: 2026-10-12.

## 1. Usuario y normas
- **Iñaki**, sysadmin Microsoft (AD/Exchange, PowerShell), infra + ciberseguridad + cloud. **Español** en todo.
- **Nada destructivo ni con efectos** (borrar, mover, push, formatear) sin explicarlo y pedir confirmación.
  **No tocar credenciales.** Trabajo **por fases**, confirmando cada paso. Si hay dudas, **preguntar antes de empezar**.
- Prefiere **ahorro de tokens**, respuestas concisas, y que se le **mejore el prompt** antes de ejecutarlo.
- **Seguridad de los datos:** no borrar nunca contenido suyo sin una copia verificada; copia de seguridad antes de editar.

## 2. Entorno
| Elemento | Valor |
|---|---|
| PC | Windows, usuario `D746288`, Windows PowerShell 5.1 (y quizá pwsh 7) |
| Raíz de trabajo por defecto | `C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD` (= `AGENTES_WD`) |
| Proyectos de Claude | `AGENTES_WD\.claude\Proyectos\<Proyecto>\` |
| Proyecto actual | `AGENTES_WD\.claude\Proyectos\Screenshots-OPPO\` (scripts en `scripts\`) |
| Móvil | OPPO (ColorOS), por USB con **ADB** (platform-tools); capturas en `/sdcard/DCIM/Screenshots` o `/sdcard/Pictures/Screenshots` |
| Memoria original | `C:\Users\D746288\.claude\projects\C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md` |
| Repo de documentación | GitHub `OutVader/Claude`, carpeta `.claude/proyectos/screenshots-oppo/` (rama `claude/gallant-lamport-xnchum`) |

Ojo: las sesiones de Claude Code **en la nube** no ven `C:\`. Para ejecutar en el PC hace falta **Claude Code local**
abierto en `AGENTES_WD` (o que Iñaki ejecute los scripts y pegue la salida).

## 3. Historia
1. **Proyecto original (sesión local, antes de sept. 2026):** "Screenshots drain": mover las capturas del OPPO al PC
   **por bloques con ADB**. Estado registrado: **2023 a medias (vaciando); los demás años, pendientes.** El detalle
   (carpeta destino, scripts usados) está en la memoria original de la tabla anterior; **todavía no se ha leído desde aquí**.
2. **2026-10-12:** localizado en el historial y retomado como proyecto propio. Se crearon:
   - `00-Instalar-en-AGENTES_WD.ps1`: copia el proyecto a `AGENTES_WD\.claude\Proyectos\Screenshots-OPPO`, copia la
     memoria original a `docs\memoria-original.md` y busca referencias (`screenshot|adb|oppo`) en `TRACASA\SCRIPTS` y
     en el historial de sesiones → `docs\referencias.md`; los scripts heredados van a `docs\heredado\`.
   - `01-Vaciar-Screenshots.ps1`: versión 1, **solo ADB y solo capturas** (ver §4).
3. **Contexto paralelo:** consolidación de `~\.claude`, `~\.codex` y `TRACASA\SCRIPTS` en AGENTES_WD (proyecto
   `agentes-wd-consolidacion`); SCRIPTS acabará en `AGENTES_WD\.claude\Proyectos\TRACASA-SCRIPTS`.

## 4. Estado técnico de `01-Vaciar-Screenshots.ps1` (v1)
Parámetros: `-Anio`, `-Destino`, `-Origen` (ruta del móvil; si se omite, se autodetecta), `-Bloque` (200),
`-SoloInventario`, `-Borrar`, `-SinPausa`, `-Adb`.

Flujo:
1. `adb devices` → exige exactamente 1 dispositivo.
2. Inventario: `adb shell "cd '<origen>' && stat -c '%Y|%s|%n' *"` → nombre, tamaño y fecha. El año sale de
   `^Screenshot_(AAAA)` y, si no, de la fecha de modificación.
3. Copia a `<Destino>\<Año>\` en bloques; `adb pull -a` **archivo a archivo** (conserva la fecha).
4. Verificación **solo por tamaño**; si ya existe con el mismo tamaño → `YA_EXISTIA` (reanudable).
5. `-Borrar` + escribir `BORRAR` → `adb shell rm` de cada archivo verificado. Registro en `<Destino>\_registro-screenshots.csv`.

Probado (PowerShell 7 en Linux con un `adb` simulado): inventario, bloques, reanudación, borrado solo de lo verificado
y del año pedido, CSV. **No probado** con el OPPO real ni en Windows PowerShell 5.1.

Limitaciones conocidas (lo que la v2 debe resolver):
- Solo funciona con **ADB** como origen y con **capturas** (no hay carpetas locales, de red, USB ni MTP).
- **No es recursivo**; no hay filtros por extensión, patrón ni rango de fechas.
- Solo verifica el **tamaño** (no hay hash).
- `adb pull` **archivo a archivo** → lento con miles de archivos (`adb pull` acepta varios orígenes por llamada).
- Si en destino hay un archivo con el mismo nombre y distinto tamaño, se sobrescribe sin aviso.
- Solo organiza por año; no hay simulación global (`-WhatIf`) ni resumen final por estado.
- Archivos con `'` en el nombre: se copian, pero no se borran.

## 5. Lecciones técnicas (no repetir errores)
- **PS 5.1 + `$ErrorActionPreference='Stop'`**: el stderr de ejecutables nativos (adb) se convierte en error
  terminante → usar `'Continue'` y comprobar `$LASTEXITCODE`.
- **Guardar los `.ps1` en UTF-8 con BOM** (y CRLF): PS 5.1 lee como ANSI los archivos sin BOM y rompe tildes y `ñ`.
- `$args` es una variable automática: no usarla como nombre propio.
- PS 5.1 **sigue junctions** con `-Recurse` → recorrer a mano (pila) saltando `ReparsePoint`.
- Rutas con espacios, tildes, `[` `]` → usar siempre `-LiteralPath`.
- En el móvil, `stat` de toybox admite `-c '%Y|%s|%n'`; `sha256sum` existe en Android 8+ (toybox).
- Con `adb shell rm` la galería puede tardar en reflejar el borrado (MediaStore).

## 6. Decisiones pendientes
- [ ] **Carpeta destino** de las capturas (está en la memoria original).
- [ ] Organización por defecto: `Año\` o `Año\Mes\`.
- [ ] ¿Soporte MTP (móvil sin depuración USB) vía `Shell.Application`? Es más lento y frágil; valorarlo como opcional.
- [ ] Nombre y carpeta del proyecto nuevo: propuesto `AGENTES_WD\.claude\Proyectos\Traspaso-Archivos`.
