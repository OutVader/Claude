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
