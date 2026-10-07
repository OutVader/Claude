# Bitácora — ordenar-escritorio-windows

## 2026-10-06 — Scripts completos y probados en sandbox
- Qué se hizo:
  - Revisada la sesión anterior: se cortó durante la comprobación del entorno, sin archivos.
  - Creada la carpeta del proyecto y el prompt mejorado (`PROMPT-mejorado.md`).
  - `ordenar_archivos.py`, `Ordenar-Archivos.ps1` (UTF-8 con BOM), `mapeo-extensiones.json`,
    `crear_sandbox.py/.ps1`, `ejecutar_pruebas.py` y `scripts/README.md`.
  - Añadido el **modo de prueba previo obligatorio**: toda ejecución simula y enseña el plan;
    `-Aplicar` ejecuta ese mismo plan solo tras confirmar.
- Resultado: casos a–h 16/16 OK (Python 3.13 y pwsh 7.4.6 en Linux, usuario no root);
  ParseFile 0 errores; PSScriptAnalyzer sin incompatibilidades con 5.1; modo interactivo probado.
- Pendiente / decisiones: probar en Windows 11 real (PS 5.1/7.6 y Python) con
  `ejecutar_pruebas.py`; luego primera simulación sobre el Escritorio real.

## 2026-10-06 — Corrección: error de análisis en PowerShell ISE
- Qué pasó: en ISE el `.ps1` daba "Falta el paréntesis de cierre" en las líneas 11, 14, 28… de la ayuda.
- Causa (reproducida): el BOM UTF-8 llegó convertido en texto `ï»¿` delante de `<#`, así que el
  bloque de ayuda dejó de ser un comentario y se analizó como código.
- Arreglo: `Ordenar-Archivos.ps1` y `crear_sandbox.ps1` pasan a ASCII puro (sin BOM ni tildes; los
  nombres Unicode del sandbox se generan con `[char]`). Además, ISE se detecta para poder preguntar.
- Verificación: análisis leyendo como PS 5.1 (cp1252) con 0 errores; PSScriptAnalyzer
  (sintaxis, comandos y tipos de Windows PowerShell 5.1) sin avisos; pruebas a–h 16/16.

## 2026-10-06 — Corrección: "el origen no existe" en Windows PowerShell 5.1 / ISE
- Qué pasó: con `C:\Users\D746288\Desktop` (existente) el script decía "CRITICO: el origen no existe".
- Causa: el script añadía siempre el prefijo `\\?\` a las rutas para las APIs .NET. En Windows
  PowerShell 5.1 (.NET Framework, también ISE) el manejo de rutas suele ser el antiguo y con ese
  prefijo `Directory.Exists()` devuelve `$false`. En pwsh 7 (lo probado en Linux) no pasa.
- Arreglo (v1.0.2): el prefijo solo se usa con rutas de 240 caracteres o más y si este PowerShell
  lo admite (se comprueba una vez con la carpeta de Windows). Si el destino está dentro del origen
  (p. ej. `Escritorio\0.Escritorio ORDENAR`), esa carpeta se excluye para no reordenar sus propios
  resultados (también en Python). Se admite ejecutar sin guardar en ISE ($PSScriptRoot vacío).
- Verificación: nuevo caso i en `ejecutar_pruebas.py`; 18/18 en Linux. Falta confirmarlo en Windows.

## 2026-10-06 — Corrección: "CRITICO inesperado ... ruta demasiado larga (260/248)" (v1.0.3)
- Qué pasó: con destino `Escritorio\0.Escritorio_ORDENAR`, Mover y recursivo, al recorrer subcarpetas
  una ruta de más de 260 caracteres hizo fallar `GetFullPath` en PS 5.1 y abortó todo el proceso.
- Arreglo (petición de Iñaki): el modo interactivo ya no pregunta RECURSIVO ni CARPETAS y trabaja
  solo con los archivos sueltos de la raíz; el destino dentro del origen se sigue omitiendo; cada
  elemento se planifica en su propio try/catch y una ruta larga o no válida queda como "omitido"
  con su motivo (PS y Python). `-Recursivo`/`-Carpetas` siguen disponibles por parámetro.
- Verificación: reproducido con una ruta de 5306 caracteres dentro del origen (límite de Linux):
  antes no había protección; ahora se omite con aviso y la simulación termina (caso j). 20/20.

## 2026-10-06 — Primera ejecución real OK (65 archivos) y ajustes v1.0.4
- Resultado de Iñaki en Windows (ISE, Mover, destino `Escritorio\0.Escritorio_ORDENAR`): 65 archivos
  procesados sin errores.
- Ajustes pedidos:
  - ISE se cerraba al terminar por el `exit` final: en ISE ahora se devuelve el código sin salir.
  - Carpeta de logs: el modo interactivo la pregunta (por defecto `<destino>\00.logs`); `-Logs`/`--logs`.
    Con carpeta elegida no se duplican en `zOrdenado\_logs`.
  - Se movieron los "Sin titulo*.ps1" abiertos en ISE: ahora se excluyen el script y todos los
    archivos abiertos en las pestañas de ISE.
  - Los logs se llamaban `_simulacion` aunque se aplicara: ahora nombre neutro con fecha; el CSV
    indica si cada fila fue simulada u ok.
- Verificación: 20/20 en Linux; prueba interactiva de la carpeta de logs en Python y PS. El cierre
  de ISE y la exclusión de pestañas solo se pueden comprobar en Windows.

## 2026-10-07 — Segunda pasada sobre un zOrdenado existente (v1.0.5)
- Pregunta de Iñaki: ordenar los sueltos de `Escritorio\0.Escritorio_ORDENAR`, que ya tiene `zOrdenado`.
- Comportamiento previo (v1.0.4): nunca sobrescribía; añadía a las categorías existentes y renombraba
  como `nombre (1).ext`; `zOrdenado` y la carpeta de logs ya se excluían; en interactivo no se tocan
  subcarpetas.
- Cambios: sufijo `_1`, `_2`…; aviso `[IDENTICO a …]` si el que ya existe tiene el mismo contenido;
  carpetas `00.*` y la contenedora nunca se recorren ni se mueven (también con `-Recursivo`).
- Verificación: caso k en `ejecutar_pruebas.py` (2.ª pasada con origen = destino); 22/22 en Linux.
