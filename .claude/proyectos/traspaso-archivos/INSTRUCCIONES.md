# Instrucciones: Traspasar-Archivos v3

Copia o mueve archivos de **cualquier origen** a **cualquier destino**, con verificación:
- **Orígenes:** carpeta del PC, disco externo, USB, red `\\servidor\recurso`, o el móvil por ADB.
- **Destino:** se crea si no existe.
- **Nunca sobrescribe.** Si un nombre ya existe con otro contenido, guarda la copia como `nombre (2).ext`.
- **Se puede parar y relanzar:** lo ya hecho no se repite.

| Archivo | Para qué |
|---|---|
| `scripts\1_LANZAR-Traspaso.bat` | **Doble clic**: abre el menú |
| `scripts\Menu-Traspaso.ps1` | Menú maestro interactivo (pregunta todo por pantalla) |
| `scripts\Traspasar-Archivos.ps1` | Motor (se puede usar directamente con parámetros) |
| `tests\Probar-Traspaso.ps1` | Pruebas automáticas con un móvil simulado |

---

## 1. Requisitos
- Windows 10/11 con **Windows PowerShell 5.1** (viene de serie) o **PowerShell 7**.
- Para el móvil: **Android platform-tools** (adb).
  - Ya lo tienes en `C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\platform-tools\adb.exe`.
  - El script lo encuentra solo: primero busca `adb` en el PATH y luego en esa ruta.
- Si PowerShell bloquea los scripts descargados, ejecuta esto una vez y solo para estos archivos (no cambia la política del equipo):
  ```powershell
  Get-ChildItem -LiteralPath '<carpeta del proyecto>' -Recurse -Include *.ps1,*.bat | Unblock-File
  ```

## 2. Preparar el móvil (solo la primera vez)
1. **Activa las opciones de desarrollador.** En el OPPO (ColorOS) ve a *Ajustes → Acerca del dispositivo → Versión* y pulsa **7 veces** sobre el *Número de compilación*.
2. **Activa la depuración USB.** En *Ajustes → Ajustes adicionales → Opciones de desarrollador*, activa **Depuración USB**.
3. **Conecta el cable y desbloquea el móvil.** En el aviso de USB elige **Transferir archivos**.
4. **Autoriza el PC.** Cuando salga *¿Permitir depuración USB?*, marca *Permitir siempre desde este equipo* y pulsa **Permitir**.
5. **Comprueba la conexión.** Usa la opción **7** del menú o escribe `adb devices`: el móvil debe aparecer como `device`. Si aparece `unauthorized`, repite el paso 4.

## 3. Uso con el menú (recomendado)
Doble clic en `scripts\1_LANZAR-Traspaso.bat`. Opciones del menú principal:

| Opción | Qué hace |
|---|---|
| 1 Nuevo traspaso | Asistente paso a paso: origen → destino → modo → organización → fecha → qué archivos → fechas o nombres → subcarpetas → verificación → ritmo → tope → informe |
| 2 Repetir el último | Vuelve a lanzar el último traspaso; lo ya hecho no se repite |
| 3 Inventario | Archivos y MB por año y mes en un origen; no copia nada |
| 4 Comparar | Cuántos faltan por pasar y qué % está hecho, y guarda la lista de faltantes |
| 5 Ver estado | Barra de %, hechos, faltan, MB y tiempo restante, **en vivo** (cada 5 s). También sirve para un traspaso que corre en otra ventana |
| 6 Último registro | Resumen por estado, fallos, y abre el informe HTML o la carpeta |
| 7 Comprobar el móvil | `adb devices` explicado |
| 8 Ayuda | La ayuda completa del motor |

- **Al responder:** Enter acepta la opción marcada con `*` y `0` vuelve atrás.
- **Antes de ejecutar:** el menú muestra el **comando equivalente** (para repetirlo sin menú) y propone **Simular primero**.
- **Configuración guardada:** guarda la última configuración y los destinos recientes en `%LOCALAPPDATA%\Traspaso-Archivos\menu.json`.

## 4. Uso directo (6+ ejemplos)
Abre PowerShell en la carpeta `scripts` y ejecuta el ejemplo que necesites.

```powershell
# 1) Inventario del móvil por año y mes (no copia nada)
.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -SoloInventario

# 2) Simular (-WhatIf): qué haría, cuánto ocupa y si cabe; no escribe nada
.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Anio 2024 -WhatIf

# 3) Móvil → PC por año, MOVIENDO (pide escribir BORRAR), bloques de 500 con pausa
.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Anio 2024 -Modo Mover -Bloque 500

# 4) Carpeta → USB conservando las subcarpetas, con SHA256
.\Traspasar-Archivos.ps1 -Origen 'C:\Users\D746288\Pictures' -Destino 'E:\Fotos' -Recursivo -Organizar Original -Hash

# 5) PC → NAS (UNC), sin los registros de BK2, con informe HTML
.\Traspasar-Archivos.ps1 -Origen 'D:\GN\BK2\ScreenShots' -Destino '\\NAS\Fotos\ScreenShots' -Recursivo -Excluir '_index/*' -Informe Html

# 6) ¿Qué falta por pasar de la cámara?
.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/DCIM/Camera -Destino 'D:\GN\BK2\Camera' -SoloComparar

# 7) Seguir BK2 con su mismo criterio de fecha (modificación), de julio a diciembre de 2024
.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -FechaPor Modificacion -Desde 2024-07 -Hasta 2024-12 -Modo Mover

# 8) Solo vídeos, máximo 10 GB esta vez y sin pausas
.\Traspasar-Archivos.ps1 -Origen adb:/sdcard/DCIM/Camera -Destino 'D:\GN\BK2\Bideoak' -Extensiones mp4,mov -MaxGB 10 -SinPausa
```

Toda la ayuda: `Get-Help .\Traspasar-Archivos.ps1 -Full`.

### Carpetas en el destino (`-Organizar`)
| Valor | Resultado |
|---|---|
| `AnioMes` (por defecto) | `<Destino>\2024\2024-07\archivo`, como BK2 |
| `Anio` | `<Destino>\2024\archivo` |
| `Ninguna` | todo en `<Destino>` |
| `Original` | conserva las subcarpetas del origen |

**De dónde sale la fecha:**
- Por defecto, del **nombre**: `Screenshot_2024-07-05…`, `IMG_20240705_…`, `PXL_`, `VID_`, `IMG-20240705-WA…`. Si el nombre no la lleva, se usa la de **modificación**.
- `-FechaPor Modificacion` usa siempre la de modificación, como BK2.
- `-UsarExif` (solo en origen local) usa la fecha EXIF de los JPG cuando el nombre no la trae.
- El inventario tiene una columna **Discrepan**: cuántos archivos caerían en otro mes según el criterio.

### Qué se queda fuera por defecto
- Los archivos ocultos: `.trashed-*` (la papelera de Android), `.thumbnails`, `Thumbs.db`… Para incluirlos, `-IncluirOcultos`.
- Los enlaces simbólicos y junctions: no se siguen, nunca.

## 5. Seguridad: qué garantiza
- **Nunca sobrescribe.**
  - Mismo nombre y mismo contenido → `YA_EXISTIA` (no copia).
  - Mismo nombre y otro contenido → copia como `nombre (2).ext`.
  - Lo ya copiado se reconoce aunque esté en **otra subcarpeta** (p. ej. en el mes que le dio BK2).
- **Mover** solo borra en el origen lo que ha quedado **verificado por SHA256**, y solo después de escribir `BORRAR` en mayúsculas.
  - El SHA256 se usa **siempre** al Mover, con o sin `-Hash`: se calcula en el móvil (`sha256sum`) y en el PC, y tienen que coincidir.
  - Si la "copia" ya estaba en el destino de antes, además se comprueba que **no sea físicamente el mismo archivo**. Esto cubre unidades mapeadas, `subst`, junctions, enlaces duros y la misma carpeta por IP o por nombre. Si no se puede confirmar, **no se borra** y queda como `ERROR_BORRADO`.
  - En el móvil, después de cada `rm` se comprueba archivo a archivo que ya no está. Si no se puede comprobar, queda como `ERROR_BORRADO`.
- **Ningún corte deja un archivo a medias con el nombre bueno.**
  - Cada archivo se copia primero a `<carpeta>\.traspaso_parcial\`, se verifica ahí y solo entonces pasa a su nombre final. Ese paso nunca sobrescribe: si ya existe, se renombra.
  - Si una descarga falla o llega incompleta, se borra solo esa copia temporal y el original no se toca.
  - Si un apagón deja restos en `.traspaso_parcial`, no cuentan como copiados y se limpian en la siguiente ejecución.
- **Lecturas incompletas:** si no se puede leer parte del origen o del destino (permisos, error del móvil al listar), la ejecución termina con código 1 y no "en verde".
- **Rutas peligrosas:** se niega con código 2 si el origen es el destino o está dentro de él, o si el destino está dentro del origen con `-Recursivo`. Se comprueba por el texto de la ruta, por la ruta física real y por la identidad física de las carpetas.
- **Un traspaso a la vez:** `_traspaso\EN_CURSO.lock` impide lanzar dos traspasos sobre el mismo destino. Si un corte deja el archivo, no pasa nada: el candado se libera al cerrarse el proceso.
- **Unidad desconectada** (USB o red) en el origen o el destino: error con código 2, sin copiar nada.
- **Espacio:** antes de empezar comprueba que cabe (`-MaxGB` para ir por tandas).
- **Nombres:** los que no valen en Windows (`: * ? " < > |`) se copian cambiando ese carácter por `_`.

## 6. Registro, estado e informes
Todo se guarda en `<Destino>\_traspaso\`:

| Archivo | Contenido |
|---|---|
| `EN_CURSO.lock` | Candado mientras hay un traspaso en marcha (se borra al terminar) |
| `registro_AAAAMMDD-HHMMSS-mmm.csv` | Una fila por archivo (separador `;`, se abre con Excel) |
| `ESTADO.json` / `ESTADO.txt` | Progreso en vivo: %, hechos, faltan, MB, ETA y cuentas |
| `faltantes_*.csv` | Lista de lo que falta (lo genera `-SoloComparar`) |
| `informe_*.html` / `.json` | Informes opcionales (`-Informe Html,Json`) |

| `Resultado` | Significado |
|---|---|
| `COPIADO` | Copiado y verificado (tamaño, y SHA256 con `-Hash`) |
| `YA_EXISTIA` | Ya estaba (mismo nombre y tamaño; con SHA256 si se usa `-Hash` o al Mover) |
| `CONFLICTO_RENOMBRADO` | El nombre existía con otro contenido: guardado como `nombre (2).ext` |
| `FALLO` | No se pudo copiar o verificar; la columna `Detalle` dice por qué. El origen no se toca |

| `EstadoOrigen` | Significado |
|---|---|
| `CONSERVADO` | No se borró (modo Copiar, o no verificado) |
| `BORRADO_ORIGEN` | Verificado y borrado del origen |
| `ERROR_BORRADO` | Se intentó borrar y sigue en el origen (o no se pudo comprobar, o no se pudo confirmar que copia y original son archivos distintos) |

**Códigos de salida:**
- `0`: todo bien.
- `1`: hubo `FALLO` o `ERROR_BORRADO`, o no se pudo leer todo el origen o el destino.
- `2`: error de parámetros o de entorno; el traspaso no empezó o se detuvo (lo hecho queda en el registro).
- `3`: lo cancelaste tú entre bloques; lo hecho está verificado y basta con relanzar.

## 7. Recuperación ante fallos
| Situación | Qué hacer |
|---|---|
| Se cortó el cable o se cerró la ventana | Relanza lo mismo (menú → 2). Lo verificado no se repite; lo que quedó a medias se vuelve a copiar |
| "Ya hay otro traspaso en curso" | Hay otra ventana trabajando sobre ese destino: espera a que acabe o ciérrala. Si no hay ninguna, borra `_traspaso\EN_CURSO.lock` |
| `FALLO` en el registro | Mira `Detalle` (`TAMANO`, `HASH`, `COPIA`, `adb pull…`), corrige la causa (cable, espacio, permisos) y relanza |
| `ERROR_BORRADO` | La copia está bien, pero el original sigue en el origen. Relanza en modo Mover: lo detectará como `YA_EXISTIA` (por SHA256) y volverá a intentar borrarlo |
| "No cabe" | Libera espacio o usa `-MaxGB` |
| El móvil sale `unauthorized` | Desbloquéalo y acepta el aviso de depuración USB |
| La galería sigue mostrando fotos borradas | Es la caché de Android (MediaStore). Se actualiza sola o al reiniciar el móvil |

## 8. Preguntas frecuentes
- **¿Puedo usarlo a la vez que BK2 (BackupMovil-v2)?** No los lances a la vez sobre la misma carpeta. Sí puedes seguir con v3 donde lo dejó BK2: reconoce lo que ya está en `D:\GN\BK2\ScreenShots`, aunque esté en otro mes.
- **¿Y el registro `_index` de BK2?** v3 no lo necesita, porque compara directamente con lo que hay en el destino. Tampoco lo modifica.
- **¿Por qué el CSV usa `;`?** Para que Excel en español lo abra en columnas. En PowerShell se lee con `Import-Csv -Delimiter ';'`.
- **¿Hace falta `-Hash`?** Para **copiar**, el tamaño basta casi siempre; úsalo para máxima seguridad (hacia un NAS, o tras fallos del cable). Para **mover** no hace falta: el SHA256 se usa siempre. Eso hace el modo Mover algo más lento, porque el móvil calcula el SHA256 de cada archivo.
- **¿Y MTP (sin depuración USB)?** Fuera de la v3, por decisión de diseño (ver `CONTEXT.md`).
- **¿Cómo pruebo sin riesgo?** Con `-WhatIf`, con la opción "Simular primero" del menú, o ejecutando `tests\Probar-Traspaso.ps1`, que trabaja solo en una carpeta temporal.

## 9. Pruebas
```powershell
cd <carpeta del proyecto>\tests
.\Probar-Traspaso.ps1              # 33 casos con un móvil simulado (también el menú); exit 0 si todo pasa, 1 si falla algo, 3 si algo no se pudo probar
.\Probar-Traspaso.ps1 -Conservar   # deja la carpeta de pruebas para mirarla
# Opcional: Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path ..\scripts -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```
`PSScriptAnalyzerSettings.psd1` excluye cuatro reglas que no aplican aquí:
- `PSAvoidUsingWriteHost`: son herramientas de consola.
- `PSUseSingularNouns`: los nombres de las funciones están en español.
- `PSUseShouldProcessForStateChangingFunctions`: `-WhatIf` y `-Confirm` se controlan una sola vez, a nivel de script.
- `PSUseLiteralInitializerForHashtable`: las tablas de hashes distinguen mayúsculas a propósito (`A.jpg` ≠ `a.jpg`).
