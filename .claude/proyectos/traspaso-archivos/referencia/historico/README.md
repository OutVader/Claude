# Histórico de versiones (referencia, no se ejecuta desde aquí)

El sufijo `_AAAA-MM-DD` es la **fecha de última modificación** del original. Los archivos de
`BK2\_tools` se guardan **byte a byte** como estaban (sacados del ZIP del 2026-10-12). La v1
`01-Vaciar-Screenshots` se guardó en UTF-8 con BOM y CRLF.

| Archivo | Fecha | Qué es |
|---|---|---|
| `Move-Screenshots_2026-08-05.ps1` | 2026-08-05 | Primer motor. Mueve un bloque de capturas (pull → tamaño → rm) a `<Año>\<Año-Mes>`. Usaba `ErrorActionPreference='Stop'`, que provocaba el fallo de PS 5.1 |
| `Drain-Screenshots_2026-08-05.ps1` | 2026-08-05 | Orquestador de Move-Screenshots: reintentos, bloque adaptativo, `-MaxGB`, `-UntilYM` y PROGRESO.txt. Destino en aquel momento: `C:\...\BK2\ScreenShots` |
| `BackupMovil-v2.6_2026-08-20.ps1` | 2026-08-20 | Multicarpeta, interactivo, registro doble (disco + móvil). Añade `-CopyOnly` |
| `BackupMovil-v2.7_2026-08-20.ps1` | 2026-08-20 | Mejoras intermedias |
| `BackupMovil-v2.8_2026-08-20.ps1` | 2026-08-20 | Corte limpio al desconectar, reintento por archivo, `skipped.log`, aviso de disco lleno y parada con STOP.flag |
| `BackupMovil-v2.9_2026-08-20.ps1` | 2026-08-20 | Mejoras intermedias |
| `BackupMovil-v2_2026-08-20.ps1` | 2026-08-20 17:02 | **Versión en uso** (interna 3.0). Añade `-FreeCopied` y `-FromYM` |
| `1_LANZAR-Backup_v2.6/v2.7_2026-08-20.bat` | 2026-08-20 | Lanzadores anteriores (finales de línea LF) |
| `1_LANZAR-Backup_v2.8_2026-08-20.bat` | 2026-08-20 | **Lanzador en uso**: menú origen → destino → nº o mes → Mover, Copiar o Liberar |
| `2_VER-Progreso_2026-08-20.bat` | 2026-08-20 | Muestra `D:\GN\BK2\*\_index\*.PROGRESO.txt` cada minuto |
| `3_PARAR_2026-08-20.bat` | 2026-08-20 | Crea STOP.flag para una parada segura |
| `LEEME_v2.8_2026-08-20.txt` | 2026-08-20 | Manual de uso de BK2 |
| `01-Vaciar-Screenshots-v1_2026-10-12.ps1` | 2026-10-12 | v1 escrita en la nube (también está en la rama `claude/gallant-lamport-xnchum` del repo Claude, idéntica) |
