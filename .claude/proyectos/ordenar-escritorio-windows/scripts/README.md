# Ordenar archivos por tipo (PowerShell y Python)

Dos scripts equivalentes que clasifican los archivos del Escritorio (o de la carpeta que
indiques) en subcarpetas por tipo dentro de una **contenedora** (`zOrdenado` por defecto).
Comparten el mismo [`mapeo-extensiones.json`](./mapeo-extensiones.json).

| Archivo | Para qué |
|---|---|
| `Ordenar-Archivos.ps1` | Windows PowerShell 5.1 y PowerShell 7.x (7.6 LTS). **ASCII puro** (sin tildes a propósito): funciona igual en ISE, consola 5.1 y pwsh 7 se descargue como se descargue. |
| `ordenar_archivos.py` | Python 3.12+, solo biblioteca estándar. |
| `mapeo-extensiones.json` | Categorías → extensiones. El orden importa: gana la primera. |
| `crear_sandbox.py` / `crear_sandbox.ps1` | Crean un Escritorio de prueba con todos los casos raros. |
| `ejecutar_pruebas.py` | Ejecuta los casos a–h contra los dos scripts, siempre en sandboxes temporales. |

## Regla de oro: siempre en modo de prueba primero

1. **Sin `-Aplicar` / `--aplicar` el script solo simula.** Enseña la lista completa de lo que
   haría (`COPIAR origen → destino`), el resumen y escribe los logs. No crea, copia, mueve
   ni borra nada.
2. **Con `-Aplicar`** el script vuelve a simular, enseña el plan y pide confirmación
   (S/N; si hay que **Mover** hay que escribir `SI`). Solo entonces ejecuta **ese mismo plan**.
3. `-WhatIf` / `--dry-run` gana siempre a `-Aplicar`.
4. En modo interactivo (sin parámetros), al terminar la simulación pregunta si ejecutar ese
   plan. La respuesta por defecto es **N**.
5. **El modo interactivo solo trabaja con los archivos sueltos de la raíz** del origen: no entra
   en subcarpetas ni las mueve (para eso, `-Recursivo` / `-Carpetas` por parámetro).
6. Si el destino está **dentro** del origen (p. ej. `Escritorio\0.Escritorio_ORDENAR`), esa
   carpeta se omite. Una ruta demasiado larga o no válida se registra como omitida y el proceso sigue.

## Ejecución en Windows 11

```powershell
# 1) Desbloquear los archivos descargados (Mark of the Web / Smart App Control)
Get-ChildItem -LiteralPath . | Unblock-File

# 2a) PowerShell, solo esta vez
powershell -ExecutionPolicy Bypass -File .\Ordenar-Archivos.ps1
# 2b) o de forma permanente para tu usuario
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 3) Python
py ordenar_archivos.py
```

**Rutas largas (> 260 caracteres):** activa `LongPathsEnabled` (necesita admin, lo haces tú):
`New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -PropertyType DWord -Force`.
Los scripts no escriben en el registro.

**Política `AllSigned`:** firma el script con tu certificado de firma de código:
`Set-AuthenticodeSignature .\Ordenar-Archivos.ps1 (Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert)[0]`.

**AppLocker/WDAC (Constrained Language Mode):** si PowerShell no está en *FullLanguage*,
el `.ps1` se para con código 2 y te sugiere la versión Python.

## Ejemplos

| Caso | PowerShell | Python |
|---|---|---|
| Escritorio → D:\ (simulación) | `.\Ordenar-Archivos.ps1 -Destino D:\` | `py ordenar_archivos.py --destino D:\` |
| USB E:\ de verdad | `.\Ordenar-Archivos.ps1 -Destino E:\ -Aplicar` | `py ordenar_archivos.py --destino E:\ --aplicar` |
| NAS con otra contenedora | `.\Ordenar-Archivos.ps1 -Destino \\NAS\share -Contenedora zOrdenado-Red -Aplicar` | `py ordenar_archivos.py --destino \\NAS\share --contenedora zOrdenado-Red --aplicar` |
| Excluir e incluir | `-Excluir "Warp.lnk, *.p12" -IncluirSolo ".pdf,.docx"` | `--excluir "Warp.lnk, *.p12" --incluir-solo ".pdf,.docx"` |
| Carpetas enteras | `-Carpetas Copiar` | `--carpetas copiar` |
| Mover dentro del Escritorio | `-Modo Mover -Aplicar` (pide escribir `SI`) | `--modo mover --aplicar` |
| Otra carpeta | `-Origen "C:\Users\inaki\Downloads"` | `--origen "C:\Users\inaki\Downloads"` |

Ayuda completa: `Get-Help .\Ordenar-Archivos.ps1 -Full` · `py ordenar_archivos.py --help`.

## Parámetros (PS ↔ Py)

| PowerShell | Python | Defecto | Nota |
|---|---|---|---|
| `-Origen` | `--origen` | Escritorio real (aunque esté en OneDrive) | El Escritorio público solo si lo indicas. |
| `-Excluir` | `--excluir` | — | Patrones por comas, contra nombre y ruta relativa. Gana a IncluirSolo. |
| `-IncluirSolo` | `--incluir-solo` | — | `.pdf` equivale a `*.pdf`. |
| `-Destino` | `--destino` | el origen | Local, USB o UNC. Si no existe → código 3. |
| `-Contenedora` | `--contenedora` | `zOrdenado` | Nombre validado (sin `<>:"/\|?*`, sin CON/PRN/AUX/NUL/COM1-9/LPT1-9). |
| `-Otros` | `--otros` | `zOtros` | Desconocidos y sin extensión. |
| `-Modo` | `--modo` | Copiar | Copiar o Mover. |
| `-Recursivo` | `--recursivo` | no | No combinable con Carpetas Copiar/Mover. |
| `-Carpetas` | `--carpetas` | Dejar | Dejar, Copiar o Mover a `<contenedora>\Carpetas`. |
| `-Aplicar` | `--aplicar` | no | Ejecuta tras simular y confirmar. |
| `-WhatIf` | `--dry-run` | — | Fuerza simulación. |
| `-Si` | `--si` | no | Sin confirmaciones (queda en el log). |
| `-Mapeo` | `--mapeo` | JSON junto al script | Si no hay JSON, mapeo interno idéntico. |
| `-ExcluirSensibles` | `--excluir-sensibles` | no | Deja fuera certificados y claves. |
| `-IncluirNube` | `--incluir-nube` | no | Descarga los "solo en la nube" de OneDrive. |
| `-IncluirOcultos` | `--incluir-ocultos` | no | Procesa ocultos y de sistema. |

Códigos de salida: **0** OK · **1** con errores no críticos · **2** parámetros no válidos o
cancelado · **3** abortado por error crítico (origen/destino inaccesible, sin espacio, falla
la prueba de escritura).

## Qué hace y qué no

- **Nunca sobrescribe:** si existe, usa `nombre (1).ext`, `(2)`… (también con carpetas).
- **Duplicados** (`(1)`, `_v2`, mismo tamaño + SHA-256): solo informe, nunca borra ni fusiona.
- **Sensibles** (`p12, pfx, cer, crt, pem, key`): aviso en color; si el destino es UNC o USB,
  confirmación aparte; con copia se verifica también el SHA-256. Su contenido nunca se muestra.
- **Omitidos por defecto:** ocultos/sistema, `desktop.ini`, `Thumbs.db`, `~$*`, `*.tmp`, la
  contenedora, los logs, el propio script, symlinks/junctions y archivos *solo en la nube*.
- `.lnk` y `.url` se mueven como archivos: no se resuelven ni se ejecutan.
- **Mover entre volúmenes** = copiar → verificar → borrar origen. Si la verificación falla,
  el origen **no** se borra.
- **Logs** en `%LOCALAPPDATA%\OrdenarArchivos\logs\` (texto + CSV `;` en UTF-8 con BOM,
  escrito en caliente). Con `-Aplicar` se copian al final a `<contenedora>\_logs\`.

## Errores frecuentes

| Mensaje | Qué hacer |
|---|---|
| En uso (32/33) | Cierra el archivo en Outlook/Word y repite. Se registra y sigue. |
| Acceso denegado (5) | Permisos, solo lectura o antivirus/ASR. Se registra y sigue. |
| Ruta demasiado larga (206) | Activa `LongPathsEnabled` o acorta la ruta. |
| Error de nube (358…475) | OneDrive sin sesión o pausado. Se registra y sigue. |
| Destino no accesible (3, 53, 64, 67…) | Se repite la prueba de escritura: si falla, se para con código 3. |
| Script bloqueado | `Unblock-File` y `-ExecutionPolicy Bypass` (ver arriba). |
| `Falta el paréntesis de cierre` en las líneas de la ayuda | El archivo se guardó con otra codificación (aparece `ï»¿` al principio). Desde la v1.0.1 el `.ps1` es ASCII puro; vuelve a descargarlo con *Download raw file*. |

## Riesgos

- **Certificados y claves:** no los dejes en el Escritorio ni en una carpeta de red sin
  protección. Mejor un almacén cifrado o el almacén de certificados de Windows.
- **OneDrive:** si el Escritorio está redirigido, mover dentro de él sincroniza los cambios a
  la nube. Los *solo en la nube* se omiten salvo `-IncluirNube` (los descargaría).
- **Accesos directos (.lnk):** apuntan a rutas de este equipo; copiados a otro PC pueden no
  funcionar.
- **Mover entre volúmenes** es más lento y depende de la verificación; revisa el CSV.

## Deshacer con el CSV

Cada fila con `Resultado = ok` tiene `Origen` y `Destino`. Para deshacer un **Mover**, se lleva
de `Destino` a `Origen`. Para deshacer una **Copia**, basta con borrar las copias (revísalo tú).
Este fragmento **solo simula** (`-WhatIf`); quítalo cuando la lista sea correcta:

```powershell
$csv = Import-Csv -LiteralPath "$env:LOCALAPPDATA\OrdenarArchivos\logs\ordenar-ps_AAAAMMDD_HHMMSS_aplicar.csv" -Delimiter ';'
foreach ($f in $csv | Where-Object { $_.Resultado -eq 'ok' -and $_.Accion -like 'mover*' }) {
    if (Test-Path -LiteralPath $f.Origen) { Write-Warning "Ya existe, no se toca: $($f.Origen)"; continue }
    Move-Item -LiteralPath $f.Destino -Destination $f.Origen -WhatIf
}
```

## Pruebas

```powershell
py ejecutar_pruebas.py            # Python y, si lo encuentra, PowerShell
py ejecutar_pruebas.py --ps "$PSHOME\powershell.exe"   # forzar Windows PowerShell 5.1
```

Crea sandboxes nuevos en `%TEMP%` y comprueba: (a) la simulación no crea nada, (b) la copia
deja el origen intacto, numera `(n)`, aparta ocultos/`~$` y avisa de sensibles, (c) EXCLUIR e
INCLUIR SOLO, (d) Carpetas=Copiar y el conflicto con Recursivo, (e) Mover dentro del origen y
segunda pasada a 0, (f) archivo bloqueado = no crítico, (g) códigos 3 y 2, (h) CSV con una fila
por archivo y sin carpetas vacías.
