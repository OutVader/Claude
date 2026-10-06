# Prompt mejorado — ordenar el Escritorio u otras carpetas (v2, octubre 2026)

El prompt original de Iñaki ya era muy completo (seguridad, errores Win32, logs, pruebas).
La v2 lo mantiene y añade lo que faltaba para el entorno actual. Es el que se ha ejecutado
para generar [`scripts/`](./scripts/).

## Cambios frente al original
| # | Cambio | Por qué |
|---|---|---|
| 1 | **Modo de prueba primero obligatorio**: planificar → mostrar plan completo → confirmar → ejecutar el mismo plan | Regla del proyecto; evita que lo ejecutado difiera de lo revisado. |
| 2 | Pregunta final en modo interactivo "¿Ejecutar este mismo plan?" (N por defecto) | Un solo flujo: simulas, revisas y decides. |
| 3 | Detección de Constrained Language Mode (AppLocker/WDAC) | Habitual en sector público; `Add-Type`/`StreamWriter` fallarían a mitad. |
| 4 | Unblock-File explicado por Mark of the Web / Smart App Control | Windows 11 24H2/25H2 bloquea scripts descargados. |
| 5 | PSScriptAnalyzer `PSUseCompatibleSyntax` (5.1 + 7.x) | Verificación objetiva de la compatibilidad con 5.1. |
| 6 | Python 3.12–3.14 | 3.14 es la versión estable actual; `is_junction()` desde 3.12. |
| 7 | `NO_COLOR` | Convención actual para consolas/logs sin color. |
| 8 | `ejecutar_pruebas.py` automatiza los casos a–h | Repetible en Windows sin copiar comandos a mano. |
| 9 | Logs a `_logs` solo si se ejecutó algo | No crear nada en el destino tras cancelar. |
| 11 | `.ps1` en ASCII puro en vez de UTF-8 con BOM | En ISE el BOM llegó como texto `ï»¿` y rompió el bloque de ayuda; ASCII no depende de la codificación. |
| 10 | Sección H de entorno corporativo (firma Authenticode opcional, sin red) | Políticas AllSigned y auditoría. |

## Prompt v2 (listo para pegar)

```text
### CONTEXTO
- Soy Iñaki, técnico de ciberseguridad y sistemas en el sector público, con Windows 11. Todo en español de España.
- Quiero ordenar mi Escritorio (puede estar redirigido a OneDrive) o la carpeta que indique. Hay de todo: subcarpetas, .lnk de apps (Warp, Zoom…), .url de Brave, ofimática, capturas, MSG, comprimidos, scripts, P12/PFX (SENSIBLES) y duplicados "(1)"/"_v2". Los iconos del sistema (Este equipo, Papelera) no son archivos.
- Política: nunca borrar, mover ni sobrescribir nada sin mi OK. Por defecto, SIMULAR y COPIAR.
- MODO DE PRUEBA PRIMERO (obligatorio): toda ejecución empieza simulando y enseña la lista completa "ACCIÓN origen → destino"; con -Aplicar se confirma y se ejecuta ESE MISMO plan, sin volver a decidir nada.
- Entorno corporativo: puede haber AppLocker/WDAC (Constrained Language Mode), Smart App Control, Defender ASR y ExecutionPolicy AllSigned. El destino (local, USB o red) puede caerse a mitad del proceso.

### PROMPT
ROL: ingeniero senior de automatización en Windows. Haz un PLAN BREVE (máximo 15 líneas) y después IMPLEMENTA, PRUEBA y DOCUMENTA sin preguntarme, salvo que haya una ambigüedad real que bloquee.

OBJETIVO: dos scripts equivalentes que clasifiquen archivos por tipo en subcarpetas de una CONTENEDORA, con el mismo mapeo-extensiones.json.
1) Ordenar-Archivos.ps1, compatible con PS 5.1 y 7.6 LTS (comprueba la sintaxis con PSScriptAnalyzer PSUseCompatibleSyntax para 5.1 y 7.x). Guárdalo en ASCII puro (sin tildes ni BOM) para que no dependa de la codificación; los caracteres no ASCII de las pruebas, generados con [char].
   - Prohibido: ??, ?:, ?., -Parallel, $IsWindows (usa [Environment]::OSVersion.Platform -eq 'Win32NT'), Join-Path con más de 2 rutas, ConvertFrom-Json -AsHashtable, y Out-File/Set-Content para los logs.
   - Siempre -LiteralPath (nombres con [ ]) y -ErrorAction Stop. El prefijo \\?\ (o \\?\UNC\), solo en rutas absolutas normalizadas para APIs .NET.
2) ordenar_archivos.py: Python 3.12–3.14, solo biblioteca estándar (hashlib incluido; ctypes/winreg solo para LEER).
   - Prohibido shutil.move: renombrar, o copiar+verificar+borrar, de forma explícita.

A. ENTRADA. Interactiva: valor por defecto entre [ ], validación y repetir si no vale. Con parámetros solo pide la confirmación final (-Si la quita).
 1. ORIGEN: por defecto, el Escritorio real (PS: [Environment]::GetFolderPath('Desktop'); Py: SHGetKnownFolderPath(FOLDERID_Desktop) con ctypes → winreg "User Shell Folders\Desktop" + expandvars → ~/Desktop). El Escritorio público (CommonDesktopDirectory) no se procesa salvo que se indique.
 2. EXCLUIR (opcional): nombres o patrones separados por comas ("Warp.lnk, *.p12, Proyecto*"), sin distinguir mayúsculas, contra el nombre y la ruta relativa (PS: -like; Py: fnmatch sobre casefold()).
 3. INCLUIR SOLO (opcional): extensiones o patrones (".pdf,.docx" o "WhatsApp*"). Si hay conflicto, EXCLUIR gana.
 4. DESTINO: ruta local, USB o UNC (por defecto, el origen) y CONTENEDORA (por defecto "zOrdenado"; la de desconocidos, dentro, es "zOtros").
    Valida el nombre (sin <>:"/\|?*, sin punto o espacio al final, sin CON/PRN/AUX/NUL/COM1-9/LPT1-9). Si coincide con la de desconocidos, avisa del anidamiento (zOtros\zOtros).
 5. MODO: Copiar (por defecto) o Mover.
 6. RECURSIVO: sí/no (por defecto, no).
 7. CARPETAS DEL ORIGEN: Dejar (por defecto), Copiar enteras o Mover enteras a <contenedora>\Carpetas. No se puede combinar con RECURSIVO=sí: explica el conflicto y vuelve a preguntar.
 8. PLAN DE PRUEBA: lista de cada elemento con su acción y su destino final (ya con los "(n)" resueltos), aunque luego se aplique.
 9. RESUMEN PREVIO y confirmación (S/N; Mover exige escribir "SI"): origen/destino/modo, archivos y tamaño por categoría, carpetas, sensibles, omitidos (ocultos/nube/excluidos), espacio libre frente al necesario y posibles duplicados.
 Parámetros (PS -Nombre / Py --nombre): Origen, Excluir, IncluirSolo, Destino, Contenedora, Otros, Modo, Recursivo, Carpetas (Dejar|Copiar|Mover), Aplicar, Si, Mapeo, ExcluirSensibles, IncluirNube, IncluirOcultos.

B. CLASIFICACIÓN. Subcarpetas creadas solo cuando hacen falta (nunca vacías; ninguna en simulación). "Carpetas" es solo para A.7. Para los archivos, gana la primera categoría que encaje, en el orden del JSON:
 Certificados y claves (p12, pfx, cer, crt, pem, key) → Documentos (doc, docx, odt, rtf) → PDF → Hojas de calculo (xls, xlsx, xlsm, csv, ods) → Presentaciones (ppt, pptx, odp) → Textos (txt, log) → Markdown (md) → Imagenes (jpg, jpeg, png, gif, bmp, webp, heic, svg) → Accesos directos (lnk) → Enlaces web (url, webloc) → Correos (msg, eml, oft) → Scripts (ps1, psm1, bat, cmd, py, sh, vbs, reg) → Comprimidos (zip, rar, 7z, tar, gz) → Instaladores y Aplicaciones (exe, msi, msix, appx) → Audio (mp3, wav, flac, m4a, ogg) → Video (mp4, mkv, avi, mov, webm) → Codigo (js, json, xml, yaml, yml, html, css, c, cpp, cs, java, go, rs, sql) → zOtros (desconocidos y archivos sin extensión; configurable con Otros).
 - JSON: {"carpetaOtros":"zOtros","sensibles":["Certificados y claves"],"categorias":{...}}. Sin distinguir mayúsculas; si falta, mapeo interno igual.
 - SENSIBLES:
   · aviso en color: no dejarlos en el Escritorio ni en una red sin protección (mejor un almacén cifrado o el de certificados);
   · destino UNC o extraíble → confirmación aparte (-Si la salta y lo anota en el log); -ExcluirSensibles los deja fuera;
   · su contenido nunca se interpreta ni se muestra (leer bytes para copiar o verificar sí).
 - .lnk y .url se tratan como archivos: no se resuelven ni se ejecutan.
 - Exclusiones por defecto: Hidden/System, desktop.ini, Thumbs.db, ~$*, *.tmp; la contenedora, los logs y el script; los archivos solo en la nube (0x1000 | 0x40000 | 0x400000) salvo con -IncluirNube; symlinks y junctions sin seguirlos (PS: LinkType; Py: is_symlink()/is_junction()). Los placeholders de OneDrive son reparse points y NO se excluyen por eso.
 - Conflictos: nunca se sobrescribe. Sufijo "nombre (1).ext", "(2)"…, también con las carpetas y con los nombres reservados en la misma ejecución.
 - Duplicados ("(1)", "_v2", "_v3", y mismo tamaño + SHA-256): solo un INFORME, sin borrar ni fusionar. El hash, solo si dos archivos tienen el mismo tamaño, y nunca de archivos solo en la nube.

C. OPERACIÓN SEGURA
 - Arquitectura planificar → mostrar → confirmar → ejecutar: la fase de planificación es pura (no escribe nada salvo logs) y la ejecución recorre el mismo plan. En modo interactivo, tras la simulación, pregunta "¿Ejecutar ahora este mismo plan?" con N por defecto.
 - Simulación salvo -Aplicar/--aplicar; -WhatIf/--dry-run gana a -Aplicar. En simulación solo se escriben los logs (PS: Start-Transcript y New-Item de logs con -WhatIf:$false).
 - Mover = intentar renombrar sin sobrescribir (Py: comprueba antes que el destino no existe, porque os.rename sobrescribe en POSIX). Si da 17 (ERROR_NOT_SAME_DEVICE) o EXDEV, se copia, se verifica el tamaño (y el SHA-256 en los sensibles) y se borra el origen, que NO se borra si la verificación falla.
 - Carpetas enteras a otro volumen: copiar el árbol (Py: copytree, con cada shutil.Error en su fila del log), verificar número de archivos y bytes, y solo entonces borrar el origen; si falla a mitad, queda intacto.
 - Unicode: prueba con ñ, tildes y emojis. En el CSV, rutas sin prefijo \\?\.

D. ERRORES: try/catch por archivo.
 Código Win32: PS = $_.Exception.GetBaseException().HResult -band 0xFFFF (deshace MethodInvocationException); Py = OSError.winerror (errno fuera de Windows).
 - NO CRÍTICOS (en amarillo, con la causa en español; se registran y se sigue): 32/33 en uso ("ciérralo en Outlook/Word y repite"), 5 acceso denegado, 206/PathTooLong, 123 nombre no válido, archivo desaparecido, nube (ERROR_CLOUD_FILE_* de winerror.h: 358, 362-366, 374, 375, 377-383, 386-398, 404, 426, 434, 475).
 - CRÍTICOS (en rojo; se para y se sale con 3): origen inexistente; destino no accesible (3, 21, 53, 59, 64, 67, 121, 1167); sin espacio (39, 112); falla la PRUEBA DE ESCRITURA en la raíz del destino.
 - Prueba de escritura (crear y borrar un temporal propio) y espacio libre: al inicio con -Aplicar y otra vez tras cualquier error en el destino; si pasa, ese error es NO CRÍTICO. Espacio libre: Py shutil.disk_usage; PS GetDiskFreeSpaceEx vía Add-Type (vale para UNC), si no [IO.DriveInfo], y si tampoco, solo aviso.
 - Códigos de salida: 0 OK · 1 con errores no críticos · 2 parámetros no válidos o cancelado · 3 abortado por crítico.

E. LOGS
 - CSV en caliente: flush por fila y fsync cada 50 filas y al cerrar (PS: StreamWriter AutoFlush + UTF8Encoding($true), fsync = BaseStream.Flush($true); Py: open(newline='', encoding='utf-8-sig')). Separador ";": Fecha;Accion;Categoria;Origen;Destino;Bytes;Resultado;Severidad;Detalle.
 - Texto: PS Start-Transcript; Py logging. Los dos en disco local, %LOCALAPPDATA%\OrdenarArchivos\logs\ (fuera de Windows, ~/.local/state/ordenar-archivos/). Con -Aplicar, al final: Stop-Transcript, cerrar el CSV y copiarlos a <contenedora>\_logs\.
 - Respeta NO_COLOR para desactivar colores.
 - Los logs solo se copian a <contenedora>\_logs si realmente se ejecutó algo (no tras cancelar).
 - Resumen final: los mismos campos que A.8, más los errores por tipo (los 10 primeros con su causa), las rutas de los logs y la duración.

F. VERIFICACIÓN (tuya, antes de entregar), solo en un sandbox temporal, NUNCA contra mi Escritorio ni rutas reales.
 1. Sintaxis: py -m py_compile; Parser::ParseFile de PowerShell con 0 errores; PSScriptAnalyzer si está.
 2. crear_sandbox (.ps1 y .py): Warp.lnk, Zoom.lnk, "Acceso directo a Internet.url", "WhatsApp Image 2026-09-30 at 10.12.33.jpeg", informe.pdf, "informe (1).pdf", acta_v2.docx, acta_v3.docx, notas.md, log.txt, correo.msg, cert.p12, cert.key, script.ps1, pack.rar, "año ñ 😀.txt", "a[1].txt", sinextension, ~$acta.docx, desktop.ini (oculto), la carpeta "Proyecto X" con 2 archivos, y un destino que ya contenga PDF\informe.pdf.
 3. Casos que deben pasar:
    a) La simulación (también con -Aplicar -WhatIf) no crea nada en el destino.
    b) La copia: deja el origen intacto, crea "informe (n)", aparta los ocultos y ~$, manda sinextension a zOtros, manda cert.p12 y cert.key a Certificados y claves con aviso, y copia "a[1].txt".
    c) EXCLUIR "*.p12, Warp.lnk" e INCLUIR SOLO ".pdf,.md" se aplican.
    d) Carpetas=Copiar → Carpetas\Proyecto X; Carpetas junto con Recursivo da conflicto.
    e) Mover con la contenedora dentro del origen: una segunda pasada procesa 0.
    f) Un archivo bloqueado (FileShare.None en Windows; en Linux, chmod 000 con un usuario que no sea root) se registra como NO CRÍTICO y el proceso sigue.
    g) Un destino inexistente sale con 3; un nombre de contenedora no válido, con 2.
    h) El CSV tiene una fila por archivo y no hay subcarpetas vacías.
 4. Automatiza los casos en ejecutar_pruebas.py (sandbox nuevo por caso, sale 1 si alguno falla) para que yo pueda repetirlos en Windows.
 5. Muestra la salida real; si no puedes ejecutar comandos, dilo y dame los comandos exactos.

G. ENTREGABLES: Ordenar-Archivos.ps1, ordenar_archivos.py, mapeo-extensiones.json, crear_sandbox.ps1/.py, ejecutar_pruebas.py y README.md en español con:
 - tabla PS↔Py;
 - ejemplos: Escritorio→D:\ (simulación), USB E:\ con -Aplicar, \\NAS\share con la contenedora "zOrdenado-Red", excluir/incluir, carpetas, mover;
 - ejecución: Unblock-File (Mark of the Web / Smart App Control); powershell -ExecutionPolicy Bypass -File … o Set-ExecutionPolicy -Scope CurrentUser RemoteSigned; py ordenar_archivos.py; LongPathsEnabled;
 - errores frecuentes y riesgos (sensibles, OneDrive, .lnk que se rompen al cambiar de PC, mover entre volúmenes);
 - DESHACER con el CSV (filas con Resultado=ok, de Destino a Origen).
 Código comentado en español, Get-Help/--help, sin dependencias externas, sin admin y sin escribir en el registro. En un chat sin archivos: cada archivo una vez, en su bloque y con su nombre. Al final: archivos y resultado de las pruebas en 10 líneas como máximo, sin repetir código.

H. ENTORNO CORPORATIVO (2026)
 - Si $ExecutionContext.SessionState.LanguageMode no es FullLanguage (AppLocker/WDAC), el .ps1 se para con código 2 y recomienda la versión Python.
 - Documenta la firma opcional con Set-AuthenticodeSignature si la política es AllSigned.
 - Nada de descargas, módulos de la Galería, telemetría ni conexiones de red propias.
```
