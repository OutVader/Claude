---
name: nuevo-proyecto
description: >-
  Úsala SIEMPRE al empezar un proyecto o trabajo nuevo de Iñaki. Crea una carpeta
  propia para ese proyecto bajo .claude/proyectos/<nombre>/ con su README, contexto y
  bitácora, en vez de dejar archivos sueltos o mezclados con otro proyecto. Dispárala
  cuando el usuario diga "nuevo proyecto", "empezamos con…", "monta la estructura",
  "crea el proyecto X" o presente un trabajo que aún no tiene carpeta.
---

# Nuevo proyecto — andamiaje estándar (destino: `.claude/proyectos/`)

Regla del workspace (ver `CLAUDE.md`): **cada proyecto/trabajo vive en su propia carpeta
bajo `.claude/proyectos/<nombre>/`**. Nunca en la raíz ni dentro de otro proyecto, y nunca
en las carpetas reservadas `.claude/skills/`, `.claude/commands/`.

## Pasos
1. **Elige un nombre** en `kebab-case`, corto y descriptivo (p. ej. `cachyos-firebat-f1p`).
2. **Crea la estructura mínima** en `.claude/proyectos/<nombre>/`:
   ```
   .claude/proyectos/<nombre>/
   ├── README.md      índice: objetivo, estado por fases/hitos, decisiones pendientes
   ├── CONTEXT.md     contexto extendido (o docs/ si son varios)
   └── bitacora.md    registro cronológico (una entrada por sesión/acción)
   ```
   Añade subcarpetas por fase/tarea cuando aporten (p. ej. `fase-1-baseline/`, `docs/`, `scripts/`).
3. **Rellena `README.md`** con: objetivo, hardware/entorno si aplica, tabla de fases o hitos
   con su estado, reglas permanentes y decisiones pendientes.
4. **Registra en `bitacora.md`** qué se hizo y qué queda pendiente.
5. **Actualiza el índice del workspace** (`/README.md`): añade el proyecto a la tabla.
6. Si el proyecto necesita un rol repetible → valora crear/actualizar una **skill** propia.

## Plantillas
`README.md`:
```markdown
# Proyecto: <nombre>
<una línea de objetivo>

- **Usuario:** Iñaki — <rol/contexto>
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)

## Estado
| Fase / hito | Contenido | Estado |
|---|---|---|
| 1 | … | ▶ en curso |

## Decisiones pendientes
- [ ] …
```

`bitacora.md`:
```markdown
# Bitácora — <nombre>
## AAAA-MM-DD — <acción>
- Qué se hizo:
- Resultado:
- Pendiente / decisiones:
```

## Notas
- Una **skill** se activa cuando es relevante; el cumplimiento *siempre* lo garantiza la
  regla en `CLAUDE.md` (autocargado). Mantener ambas alineadas.
- Nada destructivo sin confirmación. Español en toda la documentación.
