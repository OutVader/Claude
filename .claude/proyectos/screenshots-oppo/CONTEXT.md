# Contexto — screenshots-oppo

## Origen
Un proyecto anterior, hecho en una sesión **local** de Claude Code en el PC de trabajo. Ha quedado
registrado en la memoria de Claude:

- `MEMORY.md` → *"Screenshots drain project — mover capturas OPPO→PC por bloques (ADB); vaciando 2023, otros años pendientes"*
- Detalle: `C:\Users\D746288\.claude\projects\C--Users-D746288-Desktop-0-Escritorio-TRABAJO-TRACASA-SCRIPTS\memory\project_screenshots_drain.md`

Se localizó el 2026-10-12 revisando el historial de sesiones de la cuenta (la entrada aparece en
la sesión "Proyectos AGENTES_WD: indexación y migración", del 2026-09-02). Desde la nube no se ve el
contenido del `.md`; `00-Instalar-en-AGENTES_WD.ps1` lo copia a `docs\memoria-original.md`, lo muestra
y busca los scripts y sesiones previos (`docs\referencias.md`).

## Datos técnicos
- Carpeta de capturas en ColorOS (OPPO): normalmente `/sdcard/DCIM/Screenshots`; a veces
  `/sdcard/Pictures/Screenshots`. El script prueba ambas (o `-Origen`).
- Nombres típicos: `Screenshot_AAAA-MM-DD-hh-mm-ss-…_<app>.jpg` → el año se toma del nombre y,
  si no lo lleva, de la fecha de modificación.
- El borrado con `adb shell rm` no siempre actualiza la galería al momento (MediaStore): puede
  mostrar miniaturas fantasma hasta que se reindexe o se reinicie el móvil.

## Relación con otros proyectos
- Forma parte de la consolidación en AGENTES_WD → [`../agentes-wd-consolidacion/`](../agentes-wd-consolidacion/).
