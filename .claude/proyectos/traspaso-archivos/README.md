# Proyecto: Traspaso-Archivos
Copiar o mover archivos de **cualquier origen** (carpeta local, USB, UNC o móvil por ADB) a
**cualquier destino**, con verificación, de forma reanudable y sin sobrescribir nunca nada.
Evoluciona el proyecto "Screenshots OPPO" (`..\Screenshots-OPPO`) y la herramienta `BackupMovil-v2`.

- **Usuario:** Iñaki (sysadmin MS: AD/Exchange, PowerShell; infra + ciber + cloud)
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)
- **Script:** `scripts\Traspasar-Archivos.ps1` (v3), *pendiente de implementar*

## Estado
| Fase | Contenido | Estado |
|---|---|---|
| 1 | EXPLORAR: memoria original, herramientas BK2\_tools, punto de partida | ✅ hecha (2026-10-12) |
| 2 | DISEÑO: parámetros, flujo y tabla de estados del CSV | ▶ cerrado, pendiente del OK para implementar |
| 3 | IMPLEMENTACIÓN del script y los tests | ⏳ |
| 4 | VERIFICACIÓN: tests en verde, ScriptAnalyzer y -WhatIf real | ⏳ |
| 5 | DOCUMENTACIÓN: README, INSTRUCCIONES y bitácora | ⏳ |

## Contenido
```
Traspaso-Archivos\
  README.md · CONTEXT.md · bitacora.md
  referencia\historico\     14 versiones anteriores (BK2\_tools + v1), con sufijo _AAAA-MM-DD → ver su README.md
  scripts\                  Traspasar-Archivos.ps1 (fase 3)
  tests\                    adb-falso.ps1 + Probar-Traspaso.ps1 (fase 3)
```

## Sincronización
- Repo **OutVader/Obsidian**, rama `traspaso-archivos` → `AGENTES_WD\.claude\Proyectos\Traspaso-Archivos`
- Repo **OutVader/Claude** (copia) → `.claude/proyectos/traspaso-archivos/`

## Índice maestro
`..\INDICE-MAESTRO.html` (en `.claude\Proyectos\`): todos los proyectos, rutas, repos y comandos, con buscador.

## Decisiones tomadas
- Organización por defecto `-Organizar AnioMes` → `<Destino>\2024\2024-07\` (igual que BK2).
- Fecha: del nombre y, si no la lleva, la de modificación. `-FechaPor Modificacion` replica BK2 exactamente.
- MTP queda fuera de la v3.

## Decisiones pendientes
- [ ] OK para la fase 3 (implementación).
