# Proyecto: jev-typesafe
Integrar **JEV** (TypeSafe, "Sistema 1": decisiones tipadas rápidas) en **Claude Code** ("Sistema 2")
en el equipo Windows del trabajo, con perfil corporativo y criterio **local-first**.

- **Usuario:** Iñaki — admin de sistemas (AD/Exchange, PowerShell), equipo corporativo Windows
  con Check Point + Palo Alto GlobalProtect, operaciones restringidas y antivirus/EDR.
- **Contexto y decisiones:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)

## Qué se instala (en `%USERPROFILE%\.claude\`)
| Pieza | Ruta | Función |
|---|---|---|
| Cliente núcleo | `jev\jev.ps1` (y `jev\jev.py`) | `ping`, `noul`, `choice`, `score`, `route`, `sync`, `panel`, `reglas`, `diag`, `toggle`, `on`, `off` |
| Reglas estáticas | `jev\reglas.json` | **Frontera de seguridad** + redacción + exclusiones (compartidas por ambos runtimes) |
| Hook permisos | `jev\jev_permission_hook.ps1` (`.py`) | `PermissionRequest`, matcher `Bash\|PowerShell` |
| Hook sesión | `jev.ps1 sesion` | `SessionStart`: sync semanal por lotes si toca |
| Skill | `skills\elige-skill\SKILL.md` | `/elige-skill <petición>` router manual |
| Skill | `skills\jev-panel\SKILL.md` | `/jev-panel` coste + criterio + reglas aprendidas |
| Config | `jev_config.json` | umbrales, módulos, red, caché, exclusiones |
| Datos | `jev\cache.json`, `jev\estado.json`, `jev\decisions.jsonl` | caché de criterio, cortacircuitos, log (rota a 5 MB) |
| Key (la pones tú) | `%USERPROFILE%\.config\jev\key.dpapi` | cifrada con DPAPI; nunca en settings/logs/chat |

## Guía paso a paso (para no técnicos)
[`docs/Guia-JEV-instalacion-y-pruebas.docx`](./docs/Guia-JEV-instalacion-y-pruebas.docx) (editable) · [`.pdf`](./docs/Guia-JEV-instalacion-y-pruebas.pdf): instalar, simular, probar, capturar resultados, hoja de resultados, deshacer y pendientes.

## Instalación (en el equipo Windows)
```powershell
cd <repo>\.claude\proyectos\jev-typesafe
powershell -NoProfile -ExecutionPolicy Bypass -File .\instalar.ps1 -DominiosInternos dominio1.local,dominio2.corp -Simular   # ver qué haría
powershell -NoProfile -ExecutionPolicy Bypass -File .\instalar.ps1 -DominiosInternos tu-dominio.local
```
Después: guardar la key (el instalador imprime el comando DPAPI), `jev.ps1 diag`, `jev.ps1 ping`, **reiniciar Claude Code**.
Desactivar sin tocar settings: `jev.ps1 off` (o `jev.py off`).

## Estado
| Fase / hito | Contenido | Estado |
|---|---|---|
| 0 | Diagnóstico + decisiones (perfil corporativo, Windows, PS→Python, local-first, /jev-panel) | ✅ |
| 1 | Cliente núcleo PS + Python, reglas estáticas, redacción, cortacircuitos, caché, sync por lotes | ✅ probado en contenedor (simulador) |
| 2 | `/elige-skill` | ✅ |
| 3 | Hook `PermissionRequest` (Bash\|PowerShell) + `SessionStart` | ✅ probado e2e con settings real fusionado |
| 4 | `jev_config.json` + `toggle/on/off` | ✅ |
| 5 | Módulo `/jev-panel` (coste + criterio + reglas) | ✅ |
| 6 | Pruebas: `pruebas/ejecutar_pruebas.py` → 52/52 (python y pwsh 7.6) | ✅ |
| 7 | Instalar en el Windows del trabajo + key + `diag` + `ping` real | ⏳ pendiente (tú) |

## Decisiones pendientes
- [ ] Confirmar con Seguridad/IT que se permite enviar texto **redactado** de comandos a OpenRouter/TypeSafe (política de IA/DLP) y pedir excepción de URL para `openrouter.ai` (POST `/api/alpha/decisions`) si el cortafuegos lo bloquea.
- [ ] Tras `diag`: si hay inspección SSL y Python da error de certificado → `ca_bundle` con la CA corporativa (PowerShell usa el almacén de Windows y no lo necesita).
- [ ] Añadir tus dominios/rutas a `dominios_internos` y `rutas_excluidas` si hace falta.
- [ ] Revisar en `/jev-panel` las primeras propuestas de reglas locales antes de aprobarlas.
