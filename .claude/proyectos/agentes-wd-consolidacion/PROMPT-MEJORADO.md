# Prompt mejorado — Consolidación en AGENTES_WD

> Versión optimizada del pedido original (2026-10-12). Pensada para pegarla en una sesión
> de **Claude Code local en el PC de trabajo** (Windows), que es la única que ve `C:\`.

---

**Rol:** sysadmin Windows senior, cauto con los datos. Idioma: español. Effort `medium`
(indexar/copiar es mecánico; sube a `high` solo si falla la verificación de enlaces).

**Raíz de trabajo:** `C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD`
(en adelante `AGENTES_WD`).

**Fuentes:**
| Alias | Ruta | Destino |
|---|---|---|
| `CLAUDE_HOME` | `C:\Users\D746288\.claude` | `AGENTES_WD\.claude\_home\` |
| `CODEX_HOME`  | `C:\Users\D746288\.codex`  | `AGENTES_WD\.codex\_home\` |
| `SCRIPTS`     | `C:\Users\D746288\Desktop\0.Escritorio\TRABAJO\TRACASA\SCRIPTS` | `AGENTES_WD\.claude\Proyectos\TRACASA-SCRIPTS\` |

**Reglas duras**
1. **Copiar, no mover.** `~\.claude` y `~\.codex` son las carpetas de configuración vivas de
   Claude Code y Codex; si se mueven, ambos dejan de funcionar. El original se borra solo
   después de verificar, y solo con mi OK explícito.
2. **No tocar credenciales:** se excluyen `.credentials.json`, `auth.json`, `*.key`, `*.pem`,
   `.env*`, `*token*`. Se indexan por nombre (marcadas `SENSIBLE`), pero no se leen ni se copian.
3. **No seguir junctions** (`AGENTES_WD\.claude\skills`, `.codex\skills` ya son junctions);
   se listan, pero no se recorren, para evitar bucles y duplicados.
4. Copia de seguridad antes de reescribir cualquier archivo (`AGENTES_WD\.backups\<fecha>\`).
5. Trabajo **por fases**: al terminar cada una, enseño el resultado y espero tu OK.

**Fases**
| # | Fase | Script | Salida / criterio de *done* |
|---|---|---|---|
| 0 | Permisos sobre AGENTES_WD | `02-Permisos.ps1` | `icacls` muestra tu usuario con `(OI)(CI)(F)` |
| 1 | **Indexar** las 3 fuentes (solo lectura) | `01-Indexar.ps1` | `AGENTES_WD\.claude\_indices\INDICE-*.md` + `.csv`, guardados **antes** de copiar nada |
| 2 | Copia ordenada (simulación primero, después real) | `03-Migrar.ps1` | `robocopy` termina con código < 8 y el número de archivos copiados cuadra con el índice |
| 3 | Rehacer enlaces y vínculos rotos | `04-Enlaces.ps1` | El informe de enlaces queda con 0 `ROTO` (o una lista justificada) |
| 4 | Raíz por defecto + memoria | `05-RaizPorDefecto.ps1` | `claude` abre en AGENTES_WD y la memoria antigua aparece en el proyecto nuevo |
| 5 | Retirar originales | (manual) | Solo con OK, tras usar unos días la copia |

**Subtarea:** localizar en los hilos de la cuenta el proyecto para mover las capturas de la
carpeta *Screenshots* del móvil a otro destino. → **Resuelto en la nube**, ver `README.md`.

**Si hay dudas, pregúntame antes de empezar la fase en la que surjan.**
