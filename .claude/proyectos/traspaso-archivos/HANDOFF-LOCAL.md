# HANDOFF: continuar Traspaso-Archivos en una sesión LOCAL de Claude Code

> Para la nueva sesión: lee este archivo primero. Es el contexto completo y comprimido. No releas la
> historia: todo lo necesario está aquí y en `README.md`, `CONTEXT.md`, `bitacora.md` e `INSTRUCCIONES.md`.

## Cómo arrancar la sesión local
1. Trae la última versión (no toca la rama `Development` ni otros archivos):
   ```powershell
   $wd='C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD'
   git -C $wd fetch origin traspaso-archivos
   git -C $wd restore --source=origin/traspaso-archivos -- .claude/Proyectos/Traspaso-Archivos .claude/Proyectos/INDICE-MAESTRO.html
   ```
2. Abre Claude Code en local: `cd $wd` y `claude`.
3. Primer mensaje: *"Lee `.claude/Proyectos/Traspaso-Archivos/HANDOFF-LOCAL.md` y sigue con los pendientes."*

## Modos del motor
- `-Modo Copiar` (**por defecto**): copia y verifica (tamaño; con `-Hash` también SHA256). No toca el origen.
- `-Modo Mover`: copia, verifica SIEMPRE por SHA256 y borra del origen solo lo verificado, tras escribir `BORRAR` (o `-ConfirmarBorrado BORRAR`).
- Copiar primero y Mover después es seguro: lo ya copiado sale `YA_EXISTIA` (por SHA256) y solo se borra del origen.
- En el menú: opción 1 (asistente) o 9 (traspaso rápido) → "Copiar (no toca el origen)".

## Quién y cómo
- **Usuario:** Iñaki, sysadmin MS (AD/Exchange, PowerShell).
- **Idioma:** español.
- **Respuestas:** concisas.
- **Forma de trabajar:** por fases, sin nada destructivo sin explicarlo y confirmarlo, y sin tocar credenciales.
- **El primer Mover real de cada carpeta lo lanza él.**

## Dónde está todo
- **Proyecto:** `C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD\.claude\Proyectos\Traspaso-Archivos`
- **Índice maestro:** `...\AGENTES_WD\.claude\Proyectos\INDICE-MAESTRO.html`. Hay que actualizarlo en cada cambio: bloque `INDICE`, fecha y una línea en el historial.
- **Repos:**
  - `OutVader/Obsidian`: `AGENTES_WD` es su clon local, en la rama local `Development`. El proyecto vive en la rama remota `traspaso-archivos`.
  - `OutVader/Claude`: tiene una copia del proyecto en la rama `ccr-14aef5b1-yuju7s`, en `.claude/proyectos/traspaso-archivos/`.
- **En local, edita directamente en `AGENTES_WD`;** ya no hace falta `git restore`. Los archivos del proyecto aún **no están confirmados en `Development`**: pregunta antes de hacer commit o push.
- **adb:** `C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\platform-tools\adb.exe` (en D: no se puede ejecutar).
- **Herramienta anterior (BK2):** `C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\` (BackupMovil-v2). El histórico está en `referencia\historico\`.

## Estado (2026-10-22): v3.2.2 (pendiente de probar en Windows)
- **Archivos:**
  - `scripts\Traspasar-Archivos.ps1`: el motor.
  - `scripts\Menu-Traspaso.ps1`: el menú; la opción 9 es el traspaso rápido.
  - `scripts\1_LANZAR-Traspaso.bat`
  - `tests\Probar-Traspaso.ps1` (43 casos), `tests\adb-falso.ps1` (móvil simulado) y `tests\PSScriptAnalyzerSettings.psd1`.
- **Verificado:**
  - Tests en Windows PS 5.1: 33/34 con T32 OMITIDO, que es lo esperado porque NTFS no distingue mayúsculas. T34 se añadió después.
  - ScriptAnalyzer: 0 avisos.
  - Primer Mover real desde ISE: 419 capturas, 0 fallos.
- **Garantías:**
  - Mover verifica siempre por SHA256 y pide escribir `BORRAR`.
  - La copia pasa por `.traspaso_parcial` y nunca sobrescribe; con mismo nombre y distinto contenido guarda `nombre (2)`.
  - Un candado (`_traspaso\EN_CURSO.lock`) impide dos traspasos a la vez.
  - Antes de borrar se comprueba que copia y original son físicamente archivos distintos.
  - Hay un CSV por ejecución (separador `;`) y `ESTADO.json` en vivo.
  - Códigos de salida: 0 = bien · 1 = fallos o lectura incompleta · 2 = parámetros o entorno · 3 = cancelado.
- **v3.2.2:** listado por `find -printf` / `xargs stat` / `stat` uno a uno, validado con `wc -l`; `pull -Z`; `-OrdenPor Tamano`; `-EsperaMin` (espera ante desconexión); Flush físico; re-comprobación antes de borrar; solo lectura OK. Las correcciones B4/B5 de la v3.2.2 no pasaron otra ronda del Crítico.
- **`Prueba-y-Tanda.ps1`:** tests → móvil/disco → velocidad con y sin `-Z` → simulación → Mover de los 10 GB más pesados a `D:\BK\Honor\Bideoak`.
- **v3.1.1:** si `find -exec stat {} +` falla en el móvil (*Argument list too long*), se repite con `{} \;`.

## En curso (móvil A5CS024624001326, disco D: "Elements" con unos 12,5 GB libres)
- **Inventario de vídeos de `adb:/sdcard/DCIM/Camera`:** 50.670 archivos en la carpeta, de ellos **1.150 vídeos (194,6 GB)**, de 2024-12 a 2026-10. Julio de 2025: 181 vídeos, 40,1 GB.
- **Simulación de julio de 2025 hecha (OK):**
  - 181 vídeos tras los filtros; con `-MaxGB 10` se seleccionan 52 (10,1 GB), todos COPIAR.
  - Destino `D:\GN\BK2\Camera\2025\2025-07\`, con 22,4 GB libres.
  - Comando (sin `-WhatIf` para mover de verdad; repetirlo 4 veces para julio):
    `.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/DCIM/Camera -Destino 'D:\GN\BK2\Camera' -Recursivo -Modo Mover -Extensiones mp4,mov,3gp,mkv,avi,m4v,webm -Desde 2025-07 -Hasta 2025-07 -MaxGB 10 -Informe Html`
- **Problema de espacio:** 194 GB no caben en 12,5 GB. Hace falta un destino con más de 200 GB.
  - No usar R: ni Y:: son unidades corporativas.
  - En BK2 los vídeos iban a `D:\GN\BK2\Bideoak`.
- **Posible mejora:** el listado archivo a archivo de 50.670 archivos es lento. Medir cuánto tarda; si son minutos, ir directo a `{} \;` en carpetas grandes o listar por subcarpetas.

## Pendientes
0. Lanzar `Prueba-y-Tanda.ps1` y revisar su salida (tests en Windows 5.1, MB/s, simulación, primera tanda). Nuevo destino de vídeos: `D:\BK\Honor\Bideoak` (Toshiba 500 GB, caja USB 3.0).
1. Terminar los vídeos de la cámara por tandas (`-MaxGB`), con un destino que tenga espacio.
2. OPPO Find X5 contra el disco BK2 real (`D:\GN\BK2\ScreenShots`, desde 2024-07): primero `-SoloComparar`. Valorar `-FechaPor Modificacion` para seguir el criterio de BK2.
3. Resto de carpetas del móvil: Twitter, Telegram, Instagram, Collage, Snapseed, WhatsApp...
4. Fase 5: anotar la v3 en `..\Screenshots-OPPO\bitacora.md` cuando exista.

## Reglas técnicas (obligatorias)
- **Codificación de los .ps1:** UTF-8 con BOM y CRLF.
- **Compatibilidad:** PS 5.1 + pwsh 7 + ISE. Nada de sintaxis de PS 6+, nada de `Join-Path` con 3 o más argumentos, y `-LiteralPath` siempre.
- **Errores:** `$ErrorActionPreference = 'Continue'` y comprobar `$LASTEXITCODE`. En ISE no se activa el modo estricto.
- **Ojo con los nombres:** en PowerShell las variables no distinguen mayúsculas (`$R` es `$r`).
- **Antes de entregar:** `tests\Probar-Traspaso.ps1` sin fallos y ScriptAnalyzer a 0 con `tests\PSScriptAnalyzerSettings.psd1`.
- **Al terminar cada cosa:** actualizar `bitacora.md` y `INDICE-MAESTRO.html`.
