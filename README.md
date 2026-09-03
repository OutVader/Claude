# Claude — Workspace de Iñaki

Repositorio de trabajo con **Claude Code**. Reglas permanentes en [`CLAUDE.md`](./CLAUDE.md)
(se autocarga en cada sesión).

## Convenciones
- **Español** en toda la documentación.
- **Cada proyecto/trabajo nuevo → carpeta propia en `.claude/proyectos/<nombre>/`** con su
  `README.md`, contexto y `bitacora.md` (skill `nuevo-proyecto`).
- Nada destructivo sin explicación y confirmación. No se tocan credenciales.
- Skills en `.claude/skills/<nombre>/SKILL.md` con el rol que aplique.

## Estructura
```
.
├── CLAUDE.md                 reglas permanentes (autocargado)
├── README.md                 este índice
└── .claude/
    ├── skills/               skills reutilizables
    └── proyectos/            un proyecto por carpeta
        └── cachyos-firebat-f1p/
```

## Proyectos
| Proyecto | Descripción | Estado |
|----------|-------------|--------|
| [`cachyos-firebat-f1p`](./.claude/proyectos/cachyos-firebat-f1p/) | Mini PC Firebat F1 P → CachyOS (escritorio + IA local + labs ciber) | Fase 1 (pre-instalación + baseline) |

## Skills
| Skill | Rol / uso |
|-------|-----------|
| [`nuevo-proyecto`](./.claude/skills/nuevo-proyecto/SKILL.md) | Andamiaje estándar de cada proyecto nuevo en `.claude/proyectos/` |
| [`cachyos-baseline`](./.claude/skills/cachyos-baseline/SKILL.md) | Asistente de sistemas para CachyOS/Firebat (fases 1–5) |
| [`migracion-windows-cachyos`](./.claude/skills/migracion-windows-cachyos/SKILL.md) | Fase 1 pre-instalación (backup, licencia, USB, BIOS) |
