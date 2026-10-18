# Contexto: Traspaso-Archivos

## Origen
- Proyecto anterior: [`..\Screenshots-OPPO`](../Screenshots-OPPO/). Puede que aún no exista en este repo.
- Memoria original, que **no se modifica**:
  `C:\Users\D746288\.claude\projects\C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md`
- Herramienta en uso: `C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\`. Es la copia maestra; se sincroniza
  con `D:\GN\BK2\_tools\`.
  - `BackupMovil-v2.ps1`: versión interna 3.0, última modificación 2026-08-20.
  - `1_LANZAR-Backup.bat` v2.8, `2_VER-Progreso.bat`, `3_PARAR.bat` y `LEEME.txt`.
  - Más antiguos: `Drain-Screenshots.ps1` y `Move-Screenshots.ps1` (2026-08-05), y `_historico\` (v2.6 a v2.9).
- La carpeta `TRACASA\SCRIPTS` no contiene scripts ADB: todo es Exchange y AD.

## Estado del vaciado (según la memoria, a 2026-08-20)
- Móvil: **OPPO Find X5** (ColorOS) por ADB. adb se ejecuta desde la copia de C:, porque D: da "Acceso denegado".
- Capturas: `/sdcard/Pictures/Screenshots` → `D:\GN\BK2\ScreenShots\<Año>\<Año-Mes>\`.
- Hecho: **2023 completo y 2024 hasta 2024-06** (23.669 de 98.326, 0 errores).
  El 2024-07 → 2024-12 estaba en curso; su resultado no se conoce.
- Otras carpetas pendientes: DCIM/Camera (2874), Pictures/Twitter (1664), Telegram (1085),
  DCIM/Collage (587), Snapseed (385), Instagram (268) y Polish (167). Destino: `D:\GN\BK2\<Carpeta>`.
- Velocidad medida: unos 116–166 archivos/min y 1,5–2,2 MB/s hacia D:.

## Cómo funciona BackupMovil-v2 (y qué hay que respetar)
- El mes se calcula con la **fecha de modificación** en el móvil (`find -printf '%T@'`), no con el nombre.
- Lo ya movido se apunta en un registro que solo guarda nombres:
  `<destino>\_index\<clave>.moved_ok.log`, con una copia en el móvil en
  `/sdcard/MobileBackup/<clave>.moved_ok.log`.
- El índice (`<clave>.index.csv`) se genera **una sola vez** y queda en caché: las capturas
  nuevas no entran salvo que se borre.

## Fallos detectados en BackupMovil-v2 (sin tocar; solo documentados)
1. `-FreeCopied` usa `$remote` (línea 256) antes de asignarlo (línea 290). El `rm` acaba apuntando
   a `/<nombre>`: **no libera nada, pero lo cuenta como liberado**. No se pierden datos.
2. En el modo Mover no se comprueba si el `rm` funcionó: el archivo se apunta como hecho aunque
   siga en el móvil.
3. Al generar el índice no se fuerza UTF-8 en la salida de adb. En PS 5.1 los nombres con tildes
   pueden llegar mal escritos.

## Decisiones de diseño (fase 1)
- **MTP fuera de la v3.** No hay API nativa en PowerShell; con Shell.Application no hay verificación
  fiable ni código de salida. Se diseña de forma que pueda añadirse más adelante, solo en modo Copiar.
- **Compatibilidad con `D:\GN\BK2`:** `-Organizar AnioMes` genera `<Año>\<Año-Mes>`, y se tienen
  en cuenta `_index\*.moved_ok.log` y lo que ya hay en el destino para no repetir trabajo.
- **Nombre:** `Traspasar-Archivos.ps1` = **v3**. La v1 es `01-Vaciar-Screenshots` y la v2 es `BackupMovil-v2`.
- **Versiones antiguas** en `referencia\historico\` con el sufijo `_AAAA-MM-DD` (fecha de última modificación).

## Decisiones de diseño (fase 2, 2026-10-12)
- **Estructura de carpetas:** `-Organizar AnioMes` por defecto, con el formato de BK2:
  `<Destino>\<AAAA>\<AAAA-MM>\archivo`. También `Ninguna`, `Anio` y `Original`.
- **Fecha que decide la carpeta:** se toma del nombre (`Screenshot_AAAA-MM-DD…`, `IMG_AAAAMMDD`,
  `AAAAMMDD_hhmmss`, `PXL_`, `VID_`); si no la lleva, la de modificación. Así lo hacía la v1.
  - BK2 usaba **siempre** la de modificación, por eso existe `-FechaPor Modificacion`.
  - La diferencia solo afecta a qué mes va un archivo, nunca a duplicarlo ni a perderlo: lo ya
    copiado se reconoce por nombre y tamaño **en cualquier subcarpeta del destino**.
  - `-SoloInventario` muestra una columna `Discrepan` con cuántos archivos caerían en otro mes
    según el criterio. Así se decide con datos antes de mover.
- **Seguridad al Mover:** si un archivo ya estaba en el destino de antes, solo se borra del
  origen tras comparar SHA256, aunque no se haya pedido `-Hash`.

## Decisiones de implementación (fase 3, 2026-10-18)
- **Mover = SHA256 siempre:** `sha256sum` en el móvil y `Get-FileHash` en el PC. Es más lento, pero es lo que se exige para borrar.
- **Copia en dos pasos:** primero a `<carpeta>\.traspaso_parcial\`, se verifica y se pasa con `File.Move`, que falla si el destino
  ya existe (nunca sobrescribe). Los restos de un corte no cuentan como copiados y se limpian en la siguiente ejecución.
- **Identidad física antes de borrar algo que ya existía:** volumen + id de archivo y ruta final (Add-Type con
  GetFileInformationByHandle / GetFinalPathNameByHandleW; en Linux, `stat`/`realpath`). Si no se puede confirmar, no se borra.
- **Candado** `_traspaso\EN_CURSO.lock`, que se toma antes de leer el destino.
- **Códigos de salida:**
  - 0 = todo bien;
  - 1 = fallos o lecturas incompletas;
  - 2 = parámetros o entorno;
  - 3 = cancelado entre bloques.
- **CSV con separador `;`** (para Excel en español) y UTF-8 con BOM.
- **Las tablas de hashes distinguen mayúsculas** (StringComparer.Ordinal).
- **Índice del destino:**
  - nombres en minúsculas (los destinos de Windows no distinguen mayúsculas);
  - lo ya copiado se reconoce aunque esté en otra subcarpeta, salvo con `-Organizar Original`.
