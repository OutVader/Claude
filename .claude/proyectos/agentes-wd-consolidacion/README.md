# Proyecto: agentes-wd-consolidacion
Consolidar `~\.claude`, `~\.codex` y `TRACASA\SCRIPTS` en **AGENTES_WD** (indexado, ordenado,
enlaces rehechos) y dejarlo como raíz por defecto de Claude Code.

- **Usuario:** Iñaki — PC de trabajo Windows (`C:\Users\D746288`)
- **Prompt optimizado:** [`PROMPT-MEJORADO.md`](./PROMPT-MEJORADO.md) · **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)
- **Dónde se ejecuta:** en tu PC (esta sesión en la nube **no ve `C:\`**; aquí se redacta y se valida la sintaxis).

## Cómo ejecutarlo (PowerShell, en `scripts\`)
Todos los scripts **simulan por defecto**; solo escriben con `-Aplicar`.

| Fase | Comando | Qué hace | Estado |
|---|---|---|---|
| 0 | `.\02-Permisos.ps1` → `-Aplicar` | Te da control total `(OI)(CI)F` sobre AGENTES_WD | ⏳ pendiente |
| 1 | `.\01-Indexar.ps1` | Índices CSV+MD de las 3 fuentes en `AGENTES_WD\.claude\_indices` (solo lectura) | ⏳ pendiente |
| 2 | `.\03-Migrar.ps1` → `-Aplicar` | **Copia** (no mueve) con robocopy; excluye credenciales y junctions | ⏳ pendiente |
| 3 | `.\04-Enlaces.ps1` → `-Aplicar` | Informe de enlaces rotos y reescritura de rutas antiguas (con copia previa) | ⏳ pendiente |
| 4 | `.\05-RaizPorDefecto.ps1` → `-Aplicar -Acceso` | Migra la memoria, la regla de raíz por defecto, la función `cc` y el acceso directo | ⏳ pendiente |
| 5 | manual | Retirar los originales, **solo con tu OK** tras unos días usando la copia | ⏳ |

Si `ExecutionPolicy` lo bloquea: `Set-ExecutionPolicy -Scope Process Bypass` (solo para esa consola).

## Estructura destino
```
AGENTES_WD\
├── INDICE.md, CONTEXTO.md, DECISIONES.md, ENTORNO.md   (marco compartido, ya existe)
├── skills\                                             (canónica; junctions desde .claude/.codex)
├── .claude\
│   ├── _indices\        INDICE-GENERAL.md, INDICE-<fuente>.md/.csv, ENLACES-*.md/.csv, logs robocopy
│   ├── _home\           copia ordenada de C:\Users\D746288\.claude (sin credenciales)
│   └── Proyectos\
│       ├── Web_Checklist\        (ya existe)
│       └── TRACASA-SCRIPTS\      copia de TRABAJO\TRACASA\SCRIPTS (vault + scripts + .git)
└── .codex\
    └── _home\           copia de C:\Users\D746288\.codex (sin auth.json)
```

## Subtarea — proyecto "Screenshots del móvil" ✅ localizado
Está en tu memoria de Claude Code del PC, no en este repo:
- **Entrada en `MEMORY.md`:** *"Screenshots drain project — mover capturas OPPO→PC por bloques (ADB); vaciando 2023, otros años pendientes"*.
- **Archivo:** `C:\Users\D746288\.claude\projects\C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md`
- **Qué era (según esa entrada):** mover las capturas de la carpeta *Screenshots* del móvil **OPPO** al PC **por bloques**, usando **ADB**. Estado: **2023 en curso (vaciando); el resto de años, pendientes.**
- Se hizo en una sesión **local** (no aparece entre las sesiones en la nube ni de Remote Control que veo); el detalle completo y los scripts estarán en ese `.md` y, seguramente, en la carpeta SCRIPTS. Lo verás en `INDICE-SCRIPTS.md` tras la fase 1 (busca `adb`, `screenshot`, `oppo`).
- Para retomarlo: `Get-Content "$env:USERPROFILE\.claude\projects\C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md"`

## Decisiones pendientes
- [ ] ¿Copiar el **historial de sesiones** (`*.jsonl`, puede pesar GB) o usar `-SinHistorial`?
- [ ] Fase 5: ¿retirar los originales de `~\.claude` y `~\.codex`? (no recomendado: son la configuración viva)
- [ ] ¿Retomar el proyecto Screenshots como proyecto propio en AGENTES_WD?
