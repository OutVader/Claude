# Prompt para la conversación nueva (Claude Code **local**, abierto en AGENTES_WD)

Copia todo lo que hay debajo de la línea y pégalo como primer mensaje.

---

**Rol:** ingeniero senior de PowerShell y sysadmin Windows, muy cauto con los datos. Español. Effort `high`
(script con borrado de datos; la verificación tiene que ser sólida).

**Contexto:** lee primero, enteros:
1. `C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD\.claude\Proyectos\Screenshots-OPPO\HANDOFF-CONTEXTO.md`
2. En esa misma carpeta: `README.md`, `CONTEXT.md`, `bitacora.md`, `scripts\01-Vaciar-Screenshots.ps1`, y
   `docs\memoria-original.md` y `docs\referencias.md` si existen.
3. Si `Screenshots-OPPO` no existe, búscala: `Get-ChildItem 'C:\Users\D746288' -Recurse -Filter '*Vaciar-Screenshots*.ps1' -ErrorAction SilentlyContinue`.
   Lee también la memoria original:
   `C:\Users\D746288\.claude\projects\C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md`.

**Objetivo:** convertir `01-Vaciar-Screenshots.ps1` en una herramienta **genérica** `Traspasar-Archivos.ps1` que
copie o mueva archivos de **cualquier carpeta origen** a **cualquier carpeta destino**, con verificación, y entregar
el script final optimizado y sus instrucciones de uso.

**Requisitos del script**
- **Orígenes:** carpeta local, USB o UNC (`\\servidor\recurso`) **y** móvil por ADB (`adb:/sdcard/DCIM/Screenshots`,
  con `-Dispositivo <serial>` si hay varios). MTP solo como fase opcional, si lo apruebo.
- **Destino:** cualquier carpeta (local, USB o UNC); la crea si no existe.
- **Filtros:** `-Extensiones`, `-Patron` (comodín o regex), `-Desde`/`-Hasta` (fechas), `-Anio`, `-Recursivo`,
  `-Excluir`.
- **Fecha de cada archivo:** del nombre (`Screenshot_AAAA…`, `IMG_AAAAMMDD`, `AAAAMMDD_hhmmss`, `PXL_AAAAMMDD`…) y,
  si no la lleva, de la fecha de modificación (EXIF opcional).
- **Organización:** `-Organizar Ninguna|Anio|AnioMes|Original` (`Original` = conserva las subcarpetas).
- **Modo:** `Copiar` por defecto; `Mover` = borrar en el origen solo lo verificado, tras escribir `BORRAR`.
- **Verificación:** tamaño siempre; `-Hash` añade SHA256 (local con `Get-FileHash`; en el móvil con
  `sha256sum` por ADB).
- **Conflictos:** mismo nombre y mismo contenido → saltar; distinto contenido → renombrar `nombre (2).ext`.
  Nunca sobrescribir.
- **Seguridad:** simulación (`-WhatIf`/`SupportsShouldProcess`) con resumen previo; reanudable; registro CSV por
  ejecución, más resumen final por estado (copiados, saltados, conflictos, fallos, borrados) y código de salida ≠ 0
  si hay fallos.
- **Rendimiento:** con ADB, `adb pull` por **lotes** (varios orígenes por llamada) y no archivo a archivo; en
  local, `Copy-Item`, o `robocopy` si no se filtra por fecha del nombre; barra de progreso (`Write-Progress`).
- **Compatibilidad:** Windows PowerShell 5.1 y pwsh 7; UTF-8 **con BOM**; `-LiteralPath` siempre; ayuda
  comentada (`Get-Help .\Traspasar-Archivos.ps1 -Full`) con ejemplos; sin dependencias externas salvo `adb`.
- Aplica las lecciones de la §5 del HANDOFF.

**Entregables:** crea la carpeta
`C:\Users\D746288\Desktop\0.Escritorio\0.CONASAyPRS\00.Cursos\AGENTES_WD\.claude\Proyectos\Traspaso-Archivos\` con:
```
Traspaso-Archivos\
├── README.md              índice, estado y uso rápido
├── INSTRUCCIONES.md       guía paso a paso (requisitos, ADB, 6+ ejemplos, recuperación ante fallos, FAQ)
├── CONTEXT.md             de dónde viene (enlace a ..\Screenshots-OPPO) y decisiones de diseño
├── bitacora.md            registro fechado
├── scripts\
│   └── Traspasar-Archivos.ps1
└── tests\
    ├── adb-falso.ps1      simula un móvil sirviendo una carpeta local
    └── Probar-Traspaso.ps1  casos: inventario, filtros, organización, reanudación, conflicto, Mover, -WhatIf, -Hash
```

**Método (por fases; para y enséñame el resultado al acabar cada una):**
1. **Explorar:** lee el contexto y resúmeme en 10 líneas como máximo qué hizo la v1, qué dice la memoria original
   (carpeta destino y en qué punto quedó 2023) y las dudas que tengas. **Pregúntame antes de seguir.**
2. **Diseño:** parámetros, flujo y tabla de estados del CSV. Espera mi OK.
3. **Implementación** del script y de los tests.
4. **Verificación:** pasa `tests\Probar-Traspaso.ps1` (todo en verde) y `Invoke-ScriptAnalyzer` si está instalado;
   después, prueba real **solo en simulación** contra una carpeta de prueba y contra el móvil (`-WhatIf`).
5. **Documentación** y actualización de `..\Screenshots-OPPO\bitacora.md` para indicar que la v2 vive en
   `Traspaso-Archivos`.

**Prohibido:** borrar o mover archivos reales del móvil o del PC durante el desarrollo; solo en la carpeta de
pruebas. El primer `Mover` real lo lanzo yo.
