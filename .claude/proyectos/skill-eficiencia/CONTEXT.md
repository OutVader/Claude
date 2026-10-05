# Contexto: skill-eficiencia

## Objetivo
Una skill que reduzca tokens y abandonos en cualquier repositorio: valida el entorno antes de trabajar,
define y comprueba criterios de Done ejecutables, recomienda effort, protege la caché de prompt y recorta
los datos externos antes de que entren en contexto. La lógica vive en `scripts/eficiencia.py`.

## Diseño
- **Estructura plana**: `SKILL.md` (orquesta, < 100 líneas), `principios.md`, `frontend.md`, `scripts/eficiencia.py`.
- **Frontmatter**: solo `name`, `description` y `allowed-tools`, para poder subirla a claude.ai.
  Sin `effort` (sustituiría al de la sesión que la invoque) ni `model` (enfriaría la caché).
- **`allowed-tools`** preaprueba solo subcomandos de lectura o inocuos (preflight, auditar, verificar,
  presupuesto, envolver). `done`, `confiar`, `hooks` y `reglas` escriben y pasan por el permiso normal.
- **Confianza de comandos Done**: salen de un archivo del repo, así que `verificar` no los ejecuta hasta
  que el usuario los aprueba (`confiar`, o `si` en una terminal interactiva). Se guarda un hash por repo;
  si los comandos cambian, se vuelve a pedir.
- **Ejecución de comandos Done**: sin shell (se dividen como en POSIX, con la barra invertida literal para
  rutas de Windows). Solo si llevan `|`, `&&`, `;`, `$`, `%` o comodines fuera de comillas se usa shell:
  /bin/sh en Linux y cmd.exe en Windows. Variables `CI=true` y `NO_COLOR=1` para evitar modos watch y colores.
- **Hooks** (forma exec, `command` = intérprete absoluto, `args` = script + evento):
  - `SessionStart` → guarda la huella git del árbol de trabajo (línea base de la sesión). No imprime nada.
  - `PostToolUse` (`Edit|Write|NotebookEdit`) → marca la sesión como «ha editado».
  - `Stop` → si el repo tiene Done confiado y la sesión cambió archivos (marca o huella git distinta, así
    que también detecta cambios hechos con Bash), ejecuta `verificar`. Si falla, `decision: block` con la
    cola de la salida en una etiqueta con ID aleatorio. Respeta `stop_hook_active`, como mucho 2 bloqueos
    seguidos, no actúa con tareas en segundo plano ni en modo plan y deja pasar ante cualquier error propio
    (registrado en `~/.claude/eficiencia-estado/hook-errores.log`). Tope de 780 s dentro de un timeout de 900 s.
- **Sin hook de leer antes de editar**: Edit y Write solo aceptan editar un archivo no leído si `old_string`
  coincide exactamente con el contenido actual y leerlo no pediría permiso (doc. tools-reference). Ya es
  seguro, y forzar la lectura gastaría tokens.
- **Estado**: `~/.claude/eficiencia-estado/` (o `$CLAUDE_CONFIG_DIR/eficiencia-estado`).

## Entorno
Las sesiones de Claude Code en la nube no leen `~/.claude` del PC: la copia en `.claude/skills/eficiencia/`
de este repo es la que carga en ellas y la fuente para instalar en Windows y Linux.

## Documentación contrastada (code.claude.com/docs, 2026-10-05)
skills, hooks, hooks-guide, costs, prompt-caching, model-config, memory, settings, permissions, tools-reference,
plugins/cli-reference. Correcciones al enunciado original: ver bitácora.
