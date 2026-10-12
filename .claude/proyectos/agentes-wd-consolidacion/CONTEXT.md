# Contexto — agentes-wd-consolidacion

## Pedido original (2026-10-12, resumido)
Revisar e indexar `C:\Users\D746288\.claude`, `C:\Users\D746288\.codex` y
`C:\Users\D746288\Desktop\0.Escritorio\TRABAJO\TRACASA\SCRIPTS`; pasarlo todo, ordenado e
indexado, a `AGENTES_WD\.claude` y `AGENTES_WD\.codex`; rehacer los enlaces de los proyectos y
los vínculos rotos; dar permisos totales sobre AGENTES_WD y guardar allí los índices **antes**
de mover; dejar AGENTES_WD como raíz por defecto (en memoria). Subtarea: localizar el proyecto
de mover las capturas de *Screenshots* del móvil.

## Antecedentes (sesión del 2026-09-02, "Proyectos AGENTES_WD: indexación y migración")
- Se creó el **marco compartido** en la raíz de AGENTES_WD: `INDICE.md`, `CONTEXTO.md`,
  `DECISIONES.md`, `ENTORNO.md`, `IDEAS-PROXIMO-DIA.md`, `remote-control-CHECKLIST.md`,
  `telegram-bridge-PLAN-B.md`, `.gitignore`.
- **Skills fusionadas** en `AGENTES_WD\skills\` (de `~\.claude\skills`, `~\.agents\skills`,
  `.codex\skills`); `AGENTES_WD\.claude\skills` y `.codex\skills` son **junctions**.
  Copia de seguridad en `AGENTES_WD\.backups\reorg-2026-09-02`.
- Ruta corregida: Web_Checklist está en `AGENTES_WD\.claude\Proyectos\Web_Checklist`
  (no en `AGENTES_WD\Proyectos\...`).
- **Decisión de entonces:** TRACASA\SCRIPTS se **mantenía** en su ruta antigua.
  → **El pedido actual la revoca:** ahora se consolida en AGENTES_WD.
- `AGENTES_WD\.claude\settings.local.json`: Remote Control al arrancar, avisos push y el
  hook `UserPromptSubmit` (contexto-maestro). **No se sobrescribe.**
- La memoria del usuario vive en la clave de proyecto de SCRIPTS (ver más abajo).

## Hechos técnicos que condicionan el plan
- **`~\.claude` y `~\.codex` son las carpetas de configuración vivas.** Si se mueven, Claude
  Code y Codex arrancan "de cero" (sin login, ajustes ni memoria). Por eso se **copian** y el
  original se queda.
- **La memoria de Claude Code es por carpeta de trabajo:**
  `~\.claude\projects\<ruta con los caracteres no alfanuméricos cambiados por '-'>\memory`.
  - Actual: `C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS`
  - Nueva: `C--Users-D746288-Desktop-0-Escritorio-0-CONASAyPRS-00-Cursos-AGENTES-WD`
  - Sin migrarla, al abrir Claude en AGENTES_WD "se pierde" la memoria → `05-RaizPorDefecto.ps1`.
- Claude Code no tiene un ajuste de "carpeta por defecto": se arranca en la carpeta actual.
  De ahí la función `cc`, el acceso directo y la regla en `~\.claude\CLAUDE.md`.
- Windows PowerShell 5.1 **sigue las junctions** con `-Recurse` → los scripts recorren el
  árbol a mano para no duplicar `skills\` ni entrar en bucles.
- Credenciales (`.credentials.json`, `auth.json`, `*.key`, `*.pem`, `.env*`, `*token*`, `*secret*`):
  se listan como SENSIBLE y **no se leen ni se copian** (regla del workspace).

## Entradas de memoria relevantes (MEMORY.md del PC, vistas en el historial)
Autonomía/confirmaciones · Límite de credenciales · Reorganización del vault Obsidian (SCRIPTS) ·
Ahorro de tokens · Web_Checklist · Seguridad de datos · Metacognición · Preguntar antes de empezar ·
**Screenshots drain** · Master Zero Day · Mejorar prompts siempre · Handoff Web_Checklist ·
Workspace AGENTES_WD · Contexto maestro · Cierre de jornada.
