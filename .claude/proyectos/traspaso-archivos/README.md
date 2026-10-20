# Proyecto: Traspaso-Archivos
Copiar o mover archivos de **cualquier origen** (carpeta local, USB, UNC o móvil por ADB) a
**cualquier destino**, con verificación, de forma reanudable y sin sobrescribir nunca nada.
Evoluciona el proyecto "Screenshots OPPO" (`..\Screenshots-OPPO`) y la herramienta `BackupMovil-v2`.

- **Usuario:** Iñaki (sysadmin MS: AD/Exchange, PowerShell; infra + ciber + cloud)
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Uso:** [`INSTRUCCIONES.md`](./INSTRUCCIONES.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)

## Uso rápido
- **Doble clic** en `scripts\1_LANZAR-Traspaso.bat`: abre el menú (asistente, simulación, estado en vivo, faltantes...).
- **Desde PowerShell ISE:** abre `scripts\Menu-Traspaso.ps1` y pulsa F5. La opción **9 Traspaso rápido** pide solo origen, destino, fecha desde, fecha hasta y MB mínimos.
- **O directamente:**
  ```powershell
  cd scripts
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -SoloInventario
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Anio 2024 -WhatIf
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Anio 2024 -Modo Mover
  ```
- **Ayuda completa:** `Get-Help .\scripts\Traspasar-Archivos.ps1 -Full`.

## Estado
| Fase | Contenido | Estado |
|---|---|---|
| 1 | EXPLORAR: memoria original, BK2\_tools, punto de partida | ✅ 2026-10-12 |
| 2 | DISEÑO: parámetros, flujo y estados del CSV | ✅ 2026-10-12 |
| 3 | IMPLEMENTACIÓN: motor, menú, lanzador y tests (gauntlet: 2 rondas + cierre) | ✅ 2026-10-18 |
| 4 | VERIFICACIÓN: 34/34 tests y ScriptAnalyzer 0 avisos en pwsh 7 (Linux); 1.ª prueba en Windows 5.1: 15 fallos de los tests (archivo con ':') → corregido en v3.1 | ✅ en la nube · ⏳ **en tu Windows**: tests en PS 5.1 + `-WhatIf` real (ver bitácora) |
| 5 | DOCUMENTACIÓN: README, INSTRUCCIONES y bitácora (v3.1: traspaso rápido, -MinMB/-MaxMB, ISE) | ✅ · ⏳ nota en `..\Screenshots-OPPO\bitacora.md` cuando exista |

## Contenido
```
Traspaso-Archivos\
  README.md · INSTRUCCIONES.md · CONTEXT.md · bitacora.md
  scripts\  Traspasar-Archivos.ps1 (motor v3) · Menu-Traspaso.ps1 (menú maestro) · 1_LANZAR-Traspaso.bat
  tests\    Probar-Traspaso.ps1 (34 casos) · adb-falso.ps1 (móvil simulado) · PSScriptAnalyzerSettings.psd1
  referencia\historico\   14 versiones anteriores (BK2\_tools + v1), con sufijo _AAAA-MM-DD → ver su README.md
```

## Sincronización
- Repo **OutVader/Obsidian**, rama `traspaso-archivos` → `AGENTES_WD\.claude\Proyectos\Traspaso-Archivos`
- Repo **OutVader/Claude** (copia) → `.claude/proyectos/traspaso-archivos/`
- Índice maestro: `..\INDICE-MAESTRO.html`

## Decisiones tomadas
- Organización por defecto `-Organizar AnioMes` → `<Destino>\2024\2024-07\` (igual que BK2).
- Fecha: del nombre y, si no la lleva, la de modificación. `-FechaPor Modificacion` replica BK2 exactamente.
- **Mover = SHA256 siempre** (también sin `-Hash`). Copia a `.traspaso_parcial` y paso al nombre final sin sobrescribir.
- Candado por destino, identidad física de los archivos antes de borrar, y los errores de lectura cuentan como fallo.
- MTP queda fuera de la v3.

## Pendiente (tú)
- [ ] En Windows: `tests\Probar-Traspaso.ps1` con **Windows PowerShell 5.1** y con pwsh 7.
- [ ] `-WhatIf` real contra una carpeta de pruebas y contra el móvil (comandos en la bitácora).
- [ ] El primer `-Modo Mover` real lo lanzas tú.
