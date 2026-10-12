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
| 2 | DISEÑO: parámetros, flujo y tabla de estados del CSV | ▶ pendiente del OK |
| 3 | IMPLEMENTACIÓN del script y los tests | ⏳ |
| 4 | VERIFICACIÓN: tests en verde, ScriptAnalyzer y -WhatIf real | ⏳ |
| 5 | DOCUMENTACIÓN: README, INSTRUCCIONES y bitácora | ⏳ |

## Contenido
```
Traspaso-Archivos\
  README.md · CONTEXT.md · bitacora.md
  referencia\historico\     versiones anteriores, con sufijo _AAAA-MM-DD (fecha de última modificación)
  scripts\                  Traspasar-Archivos.ps1 (fase 3)
  tests\                    adb-falso.ps1 + Probar-Traspaso.ps1 (fase 3)
```

## Sincronización
- Repo **OutVader/Obsidian**, rama `traspaso-archivos` → `AGENTES_WD\.claude\Proyectos\Traspaso-Archivos`
- Repo **OutVader/Claude** (copia) → `.claude/proyectos/traspaso-archivos/`

## Decisiones pendientes
- [ ] OK al diseño (fase 2).
- [ ] Subir el resto de `BK2\_tools` (Drain/Move-Screenshots, LEEME, 2_VER, 3_PARAR y `_historico`) para archivarlo en `referencia\historico\`.
