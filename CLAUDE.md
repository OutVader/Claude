# CLAUDE.md — Workspace de Iñaki

Reglas permanentes de este repositorio. Este archivo se **autocarga** en cada sesión
de Claude Code abierta en la raíz del repo, así que lo que ponga aquí aplica SIEMPRE.

## Idioma y trato
- **Español** en todo (respuestas, docs, commits).
- Iñaki = admin de sistemas (AD/Exchange, PowerShell), infra MS + ciber + cloud.
- **Nada destructivo ni con efectos** (push, borrados, mover archivos, formatear) sin
  explicarlo y pedir confirmación. **No tocar credenciales.**
- Trabajo **por fases**, confirmando cada paso.

## Convención de organización (OBLIGATORIA, siempre)
- **Cada proyecto o trabajo nuevo → su propia carpeta bajo `.claude/proyectos/<nombre>/`.**
  Nunca dejar archivos sueltos de un proyecto en la raíz ni mezclados con otro.
- Cada carpeta de proyecto lleva como mínimo: `README.md` (índice + estado),
  contexto (`CONTEXT.md` o `docs/`) y `bitacora.md` (registro cronológico).
- Las carpetas reservadas de Claude Code (`.claude/skills/`, `.claude/commands/`,
  `.claude/settings*.json`) **no** se usan para proyectos: por eso los proyectos van
  bajo `.claude/proyectos/`, separados de ellas.
- Al empezar un proyecto nuevo, seguir la skill **`nuevo-proyecto`**.

## Skills del repo
- `nuevo-proyecto` — andamiaje estándar de un proyecto/trabajo nuevo en `.claude/proyectos/`.
- `cachyos-baseline` — rol asistente de sistemas para el baseline/uso de CachyOS.
- `migracion-windows-cachyos` — Fase 1 pre-instalación (backup, licencia, USB, BIOS).
- `ahorro-tokens` — guardián del gasto: cuándo usar `/compact`, `/clear`, cambiar de modelo
  (Opus↔Haiku), moderar MCP/navegador y cambiar de conversación si la sesión es muy larga.

## Entorno
- Las sesiones de Claude Code **en la nube** corren en un contenedor Linux remoto: **no**
  tocan el mini PC Firebat ni el equipo Windows del usuario. Ahí se **redacta** el material
  y el usuario lo ejecuta en su máquina.
