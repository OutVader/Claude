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

## 2026-10-18: Fase 3 (IMPLEMENTACIÓN) y 4 (VERIFICACIÓN en la nube), con gauntlet loop
- Qué se hizo:
  - `scripts\Traspasar-Archivos.ps1` (motor v3), `scripts\Menu-Traspaso.ps1` (menú maestro) y `scripts\1_LANZAR-Traspaso.bat`.
  - `tests\adb-falso.ps1` (móvil simulado), `tests\Probar-Traspaso.ps1` (33 casos) y `tests\PSScriptAnalyzerSettings.psd1`.
  - `INSTRUCCIONES.md`.
- Revisión (gauntlet, Crítico ciego en un subagente nuevo por ronda; el hash del código se comprobó igual tras cada revisión):
  - Ronda 1 RECHAZADO:
    - B1: al Mover, las copias nuevas solo se verificaban por tamaño.
    - B2: un alias físico (unidad mapeada, subst, junction) podía tomar el original como "copia" y borrar la única que había.
    - B3: una unidad inexistente acababa con exit 0.
    - Corrección: SHA256 siempre al Mover, rutas reales e identidad física (Add-Type en Windows), try/catch → código 2.
  - Ronda 2 RECHAZADO:
    - B4: el candado se tomaba después del plan.
    - B5: las lecturas incompletas acababan con exit 0.
    - B6: un corte dejaba un archivo truncado con el nombre final.
    - B7: el test del menú podía tocar la configuración real.
    - Corrección: candado antes de leer el destino, avisos de lectura → exit 1, copia a `.traspaso_parcial` y paso al nombre final sin sobrescribir, `-RutaConfig`.
  - Cierre RECHAZADO:
    - B8: las tablas de hashes no distinguían mayúsculas (A.jpg/a.jpg).
    - Corrección: StringComparer.Ordinal y el test T32 (reproducía el fallo antes de corregirlo). **B8 corregido sin una nueva revisión del Crítico** (tras el cierre no hay más rondas).
  - Mejoras opcionales aplicadas:
    - cancelar entre bloques → código 3;
    - los tests sin poder crear enlaces cuentan como OMITIDO (exit 3), no como verdes;
    - destino con la raíz ilegible → código 2;
    - un adb `.ps1` solo se acepta si se pasa con `-Adb`;
    - aviso de los archivos de OneDrive "solo en la nube".
- Resultado (pwsh 7.4.6, Linux):
  - 33/33 tests en verde, 0 omitidos.
  - ScriptAnalyzer 0 avisos con la configuración del proyecto.
  - 0 variables o parámetros sin usar y 0 errores de sintaxis.
  - Mutaciones: cada protección quitada hace fallar su test (T19 tamaño, T24 guarda física, T26 SHA256 al Mover, T29 restos parciales, T30 lecturas, T31 cancelar).
- No verificable aquí (verificar en destino): Windows PowerShell 5.1, Add-Type (GetFinalPathNameByHandleW / GetFileInformationByHandle), robocopy, adb real y el OPPO.
- Opcionales no aplicados:
  - candado para destinos anidados (D:\BK2 y D:\BK2\ScreenShots a la vez): está documentado "no lanzar dos a la vez";
  - aviso si el origen contiene una carpeta `_traspaso`;
  - adb antiguo sin shell_v2: no devuelve el código de salida del shell.
- Pendiente (Iñaki, en Windows):
  ```powershell
  cd '<AGENTES_WD>\.claude\Proyectos\Traspaso-Archivos\tests'
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Probar-Traspaso.ps1   # PS 5.1
  pwsh -NoProfile -File .\Probar-Traspaso.ps1                                 # PS 7 (si lo tienes)
  cd ..\scripts
  .\Traspasar-Archivos.ps1 -Origen "$env:USERPROFILE\Pictures" -Destino "$env:TEMP\prueba-traspaso" -Recursivo -WhatIf
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -SoloInventario
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -SoloComparar
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Desde 2024-07 -Hasta 2024-12 -WhatIf
  ```

## 2026-10-20: v3.1. Fallos de los tests en Windows 5.1, traspaso rápido, filtro de tamaño e ISE
- Entrada: primera ejecución de Iñaki en Windows PowerShell 5.1, con otro móvil (A5CS024624001326) y otro disco.
  - Tests: 17/33 en verde, 15 fallidos y 1 omitido.
  - Prueba real: `-SoloComparar` funcionó (419 capturas, 470,6 MB, 0 % en ese disco).
- Diagnóstico:
  - Los 15 fallos tenían una sola causa: el móvil simulado crea `raro:nombre…png` y `:` no vale en NTFS. Era un fallo del test, no del motor.
  - T27 buscaba `SYNOPSIS`, pero Windows en español muestra `SINOPSIS`.
  - T32 OMITIDO es lo esperado (NTFS no distingue mayúsculas).
  - `→` salía como `␦` en la consola 5.1.
- Qué se hizo (tocando lo mínimo; la copia, la verificación y el borrado no cambian):
  - Tests: el archivo con `:` solo se crea fuera de Windows, los recuentos son dinámicos y T27 acepta `SINOPSIS`.
  - Motor: `-MinMB` y `-MaxMB`, con límites incluidos y redondeo hacia el lado del filtro. Valores negativos, NaN, mayores de 10.000.000 o MinMB > MaxMB dan código 2.
  - Fechas: años 1990-2100.
  - Aviso si ISE no deja leer adb en UTF-8.
  - En ISE no se activa el modo estricto.
  - `→` cambiado por `->`.
  - Menú: opción **9 Traspaso rápido** (origen, destino, desde, hasta y MB mínimos). Las fechas se validan (AAAA-MM-DD, AAAA-MM o DD/MM/AAAA; DESDE > HASTA → se vuelven a pedir) y `1.000` se rechaza.
  - Menú: estado "en vivo" en ISE con Enter para actualizar; MB mínimos también en las opciones avanzadas del asistente.
  - Los números 1-8 del menú no cambian; Salir pasa al 10.
- Revisión (gauntlet: Crítico ciego nuevo en cada ronda, hash comprobado):
  - Ronda 1 RECHAZADO:
    - B1: el rápido en la posición 1 renumeraba el menú y rompía la "opción 6".
    - B2: el modo estricto podía quedarse activado en ISE.
  - Ronda 2 RECHAZADO:
    - B3: un MaxMB menor de 1 byte se trataba como "sin máximo".
  - Cierre: ver la entrada de abajo.
- Resultado:
  - 34/34 tests en Linux y 34/34 con los recuentos de Windows simulados.
  - ScriptAnalyzer 0 avisos; 0 variables o parámetros sin usar; 0 errores de sintaxis.
  - Mutaciones: quitar el filtro MinMB hace fallar T10; quitar la corrección de B3 también.
- No verificable aquí: Windows PowerShell 5.1 real, PowerShell ISE y adb real.
- **Cierre APROBADO** (sin bloqueantes, confianza media: Windows 5.1 e ISE no se pudieron ejecutar aquí).
- Después del cierre, **sin revisar**:
  - `0.003` se aceptaba mal como "separador de miles": ahora solo se rechaza si la parte entera no es 0 (`1.000`, `1.250`).
  - El resumen dice "sin límite" en vez de "hoy".
  - Versión 3.1.0.
- Pendiente (Iñaki, en Windows): `tests\Probar-Traspaso.ps1` en PS 5.1. Se espera 33 verdes y T32 OMITIDO (NTFS no distingue mayúsculas), con exit 3. Después, probar el menú en ISE (F5 → opción 9) con `-WhatIf` ("Simular primero").

## 2026-10-20: verificación en Windows 5.1 y arreglo para pestañas de ISE sin guardar
- Resultado en el Windows de Iñaki (PS 5.1): **33/34 en verde, 0 fallidos y T32 OMITIDO** (lo esperado: NTFS no distingue mayúsculas). La fase 4 de tests queda cerrada en Windows.
- Arreglo (sin revisión del Crítico): en una pestaña de ISE sin guardar, `$PSScriptRoot` está vacío.
  - El motor: `Join-Path` con una ruta vacía fallaba al buscar adb. Ahora se salta ese candidato.
  - El menú: ahora busca el motor en la carpeta actual y, si no lo encuentra, avisa con código 2.
  - Comprobado ejecutando el motor como bloque de texto, sin ruta (inventario ADB correcto). Tests: 34/34 en Linux; analizador: 0 avisos.
- Pendiente: probar el menú real en ISE (F5, opción 9, "Simular primero") con el móvil.

## 2026-10-20: primer MOVER real (fase 4 cerrada)
- Lo lanzó Iñaki desde PowerShell ISE: menú → 1 asistente → móvil (A5CS024624001326) `/sdcard/Pictures/Screenshots` → `D:\GN\BK2\ScreenShots`.
  - Opciones: Mover, AnioMes, fecha del nombre, recursivo, bloques de 200 con pausa e informe HTML.
- Antes: "Simular primero" (-WhatIf), con 419 archivos (470,6 MB) a copiar y 12,9 GB libres.
- Resultado: **COPIADO 419 · BORRADO_ORIGEN 419 · FALLO 0 · ERROR_BORRADO 0** · código 0 · 4 min 07 s (unos 100 archivos/min y 1,9 MB/s, con SHA256 de cada archivo).
  - Registro: `D:\GN\BK2\ScreenShots\_traspaso\registro_20261020-124247-592.csv`
  - Informe: `D:\GN\BK2\ScreenShots\_traspaso\informe_20261020-124247-592.html`
- Observación cosmética: en ISE, la tabla del plan de -WhatIf sale con líneas en blanco y muy ancha (por el ancho de ISE).
- Pendiente:
  - Pasar el OPPO Find X5 original contra el disco BK2 real: lo que quedó desde 2024-07 (usar `-SoloComparar` antes).
  - Las otras carpetas del móvil (Camera, Twitter, Telegram...).
  - Anotar la v3 en `..\Screenshots-OPPO\bitacora.md` cuando exista esa carpeta.

## 2026-10-20: v3.1.1. Listado del móvil cortado en carpetas grandes
- Entrada: al simular `adb:/sdcard/DCIM/Camera` (10.591 archivos) con filtro de vídeos y julio de 2025, el móvil devolvió
  `find: exec stat: Argument list too long`.
  - El motor avisó de que el listado estaba incompleto, terminó con código 1 y **no movió nada**: la protección funcionó.
- Causa: el `find` de ese Android no reparte bien la lista de `-exec stat ... {} +` en carpetas grandes.
- Arreglo (tocando lo mínimo):
  - Si el listado rápido falla, se repite con `-exec stat ... {} \;` (un stat por archivo: más lento, pero completo).
  - Solo si este también falla se mantiene el aviso y el código 1.
  - El mensaje del menú para el código 1 ya no manda al registro cuando no se llegó a copiar.
  - Test T34: el adb simulado corta `{} +` tras 2 archivos.
- Resultado:
  - 35/35 tests (también con los recuentos de Windows); ScriptAnalyzer 0 avisos.
  - Mutación: sin el reintento, falla T34.
  - Sin revisión del Crítico (cambio pequeño y solo añade un reintento).
- Nota: `-Hasta 2025-07-30` deja fuera el 31; para el mes entero, `-Hasta 2025-07`.

## 2026-10-20: simulación de vídeos de julio de 2025 (OK)
- 181 vídeos tras los filtros; `-MaxGB 10` selecciona 52 (10,1 GB), todos COPIAR, sin conflictos. 22,4 GB libres en D:.
- Siguiente: Mover real por tandas de 10 GB (unas 4 para julio). Hace falta un disco más grande para los 194,6 GB.

## 2026-10-22: v3.2 → v3.2.2. Velocidad, desconexiones y tandas por tamaño
- Entrada: el listado de Camera (50.670 archivos, un `stat` por archivo) tardaba muchísimo. Nuevo destino `D:\BK\Honor\Bideoak` (Toshiba 2,5" 500 GB en caja USB 3.0), cable Essager USB-C 4.0.
- Cambios (gauntlet loop: rondas + cierre):
  - Listado por métodos en cadena (`find -printf` → `xargs stat` por lotes → `stat` por archivo), aceptado solo si cuadra con `find | wc -l`.
  - `adb pull -Z` si el adb lo admite. `-OrdenPor Tamano`. `-EsperaMin` (espera ante desconexión y un reintento).
  - Flush físico de cada copia; antes de borrar en el origen, re-comprobación de cada copia (SHA256 si el disco desapareció).
  - Estado INTERRUMPIDO (código 1). Hash vacío del destino = FALLO.
- v3.2.2 (lo que rechazó el Crítico en el cierre de la v3.2.1):
  - B4: los archivos de solo lectura fallaban en el Flush y dejaban temporales. Ahora se quita el atributo, se asegura y se devuelve; si falla, se borra el temporal propio. Test T42 (la mutación lo hace fallar al ejecutar sin privilegios).
  - B5: si el disco caía justo después de pasar el archivo a su nombre final, el reintento creaba un "(2)". Ahora ese archivo propio se quita (o se quita en el reintento) antes de volver a copiar. Sin test automático (difícil de simular); revisado por lectura.
  - El segundo intento de escribir el CSV ya no aborta el script; comentario de la línea 249 en su sitio.
  - Estas correcciones **no han pasado por otra ronda del Crítico**.
- Resultado: 43/43 tests en Linux (como root y sin privilegios) y con los recuentos de Windows; ScriptAnalyzer 0 avisos. Falta probar en Windows 5.1 real con adb real.
- Nuevo `Prueba-y-Tanda.ps1`: prueba, simulación y primera tanda de 10 GB de los vídeos más pesados de `adb:/sdcard/DCIM/Camera`.
