# Proyecto: gauntlet-portable
Versión portable (copiar y pegar) de la skill `gauntlet-loop` + reglas de eficiencia, para
usarla en otros modelos/sistemas agénticos (Grok, ChatGPT, Gemini, agentes propios).

- **Usuario:** Iñaki — admin de sistemas (AD/Exchange, PowerShell), infra MS + ciber + cloud
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)
- **Entregables:**
  - [`PROMPT-UNIVERSAL.md`](./PROMPT-UNIVERSAL.md) — para cualquier persona y LLM (chat o agente). Perfil rellenable.
  - [`GAUNTLET-PORTABLE.md`](./GAUNTLET-PORTABLE.md) — versión personalizada para Iñaki (Bloques A+B, C).
  - [`export-skills/`](./export-skills/) — skills `gauntlet-loop` v2 + `eficiencia` e instalador `instalar-skills.ps1` para Windows.

## Estado
| Hito | Contenido | Estado |
|---|---|---|
| 1 | Prompt portable gauntlet + eficiencia | ✅ redactado |
| 2 | Probarlo en Grok y ajustar | ⏳ pendiente (lo ejecuta Iñaki) |
| 3 | v2 (Guía del Gauntlet) + prompt universal + export de skills | ✅ redactado |

## Decisiones pendientes
- [ ] Si la plataforma destino no tiene subagentes, ¿Crítico en chat aparte (recomendado) o en el mismo hilo?
