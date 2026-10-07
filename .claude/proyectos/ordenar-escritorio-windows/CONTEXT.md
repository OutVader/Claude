# Contexto — ordenar-escritorio-windows

## Origen
Iñaki pidió (sesión del 2026-10-06, skill `/eficiencia`) revisar su prompt para ordenar el
Escritorio u otras carpetas, mejorarlo con las tendencias de octubre de 2026 y ejecutarlo
para obtener dos scripts reutilizables en Windows 11. Esa sesión se interrumpió antes de
crear archivos; el trabajo se completó en el hilo del proyecto "Scripts ordenar Escritorio
Windows". El prompt original completo está en [`PROMPT-mejorado.md`](./PROMPT-mejorado.md)
(sección "Cambios frente al original").

## Entorno del usuario
- Windows 11, Escritorio posiblemente redirigido a OneDrive.
- Contenido típico: subcarpetas, `.lnk` (Warp, Zoom…), `.url` de Brave, ofimática, capturas,
  `.msg`, comprimidos, scripts, **P12/PFX sensibles** y duplicados `(1)` / `_v2`.
- Destinos posibles: local, USB o red (UNC), que pueden caerse a mitad del proceso.

## Política
- Nunca borrar, mover ni sobrescribir nada sin OK. Por defecto, SIMULAR y COPIAR.
- Regla añadida por Iñaki en el proyecto: los scripts incluyen **siempre** un modo de prueba
  que muestra qué se movería sin mover nada, y se ejecutan **primero** en ese modo.

## Cómo se verificó
Las sesiones en la nube corren en Linux: se probó con Python 3.13 y PowerShell 7.4.6 (Linux),
`Parser::ParseFile` con 0 errores y PSScriptAnalyzer `PSUseCompatibleSyntax` para 5.1 y 7.4
sin avisos. Lo específico de Windows (atributos Oculto/Sistema reales, OneDrive, FileShare.None,
UNC, USB, `GetDiskFreeSpaceEx`, PS 5.1) queda por probar en el equipo de Iñaki con
`ejecutar_pruebas.py`.
