# Bitácora: Traspaso-Archivos

## 2026-10-12: Fase 1 (EXPLORAR)
- Qué se hizo:
  - Se leyó la memoria `project_screenshots_drain.md`, que pegó Iñaki.
  - Se listó `TRACASA\SCRIPTS`: no hay scripts ADB.
  - Se revisaron `BackupMovil-v2.ps1` (versión interna 3.0) y `1_LANZAR-Backup.bat` v2.8.
  - Se creó el andamiaje del proyecto y se archivaron las referencias en `referencia\historico\`:
    - `01-Vaciar-Screenshots-v1_2026-10-12.ps1`
    - `BackupMovil-v2_2026-08-20.ps1`
    - `1_LANZAR-Backup_v2.8_2026-08-20.bat`
  - Se instaló pwsh 7.4.6 en el contenedor de la nube para los tests.
- Resultado:
  - Destino real: `D:\GN\BK2\ScreenShots\<Año>\<Año-Mes>`.
  - Estado: 2023 y 2024 hasta 2024-06 terminados; 2024-07 → 2024-12 en curso al 20-08.
  - Se detectaron 3 fallos en BackupMovil-v2 (ver CONTEXT.md).
- Decisiones:
  - MTP fuera.
  - Nombre v3.
  - Compatibilidad con BK2 (`<Año>\<Año-Mes>` y `_index`).
  - Sincronización por Git (OutVader/Obsidian, rama `traspaso-archivos`) más una copia en OutVader/Claude.
- Pendiente: OK al diseño (fase 2) y subir el resto de `BK2\_tools` para archivarlo.

## 2026-10-12: Fase 2 (DISEÑO) y archivo de BK2\_tools
- Qué se hizo:
  - Se revisó el ZIP `bk2-tools.zip` (13 archivos) y se archivó **byte a byte** en `referencia\historico\`
    con la fecha real de cada archivo, más un README con el índice.
  - Se presentó el diseño: parámetros, flujo y estados del CSV.
  - Se creó `INDICE-MAESTRO.html` (índice interactivo de proyectos, rutas, repos y comandos).
- Resultado:
  - Move/Drain-Screenshots (05-08) confirman que BK2 clasificó **siempre por fecha de modificación**,
    con el destino inicial en `C:\...\BK2\ScreenShots`.
  - La v1 coincide con la de la rama `claude/gallant-lamport-xnchum` (proyecto `screenshots-oppo`).
- Decisiones:
  - `AnioMes` por defecto, con formato `AAAA\AAAA-MM`.
  - Fecha tomada del nombre, con la de modificación como respaldo; `-FechaPor Modificacion` disponible.
- Pendiente: OK para la fase 3.
