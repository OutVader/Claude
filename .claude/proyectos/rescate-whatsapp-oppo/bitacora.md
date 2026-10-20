# Bitácora — rescate-whatsapp-oppo

## 2026-10-19 — Diagnóstico inicial (sesión en la nube)
- Qué se hizo: diagnóstico por chat. Móvil OPPO Find X5 con almacenamiento casi lleno; WhatsApp se queda sin historial al reabrir.
  WhatsApp Web (Opera) conserva todos los chats. El usuario ha exportado algunos desde Web, ha reiniciado y ha actualizado WhatsApp.
  Última copia en Drive: de hace meses. Se crea este proyecto para continuar en local.
- Resultado: plan por fases (README/PROCEDIMIENTO). Vía principal = copias locales en `Databases`.
- Pendiente / decisiones: **Fase 1 urgente** (copiar `com.whatsapp\WhatsApp` al PC antes de la copia nocturna de las 02:00);
  inventario de `Databases`; elegir copia; método para esquivar la copia de Drive.

## 2026-10-20 — Ideas de Fredy, Takeout, Xataka y plan forense
- Qué se hizo: evaluadas las propuestas (hilo de Google Drive, ADB, auditoría forense, Google Takeout, artículo de Xataka de jun 2026).
  Creado `FORENSE-ADB.md` con comandos ADB de inventario/adquisición con hashes, matriz de qué es accesible sin root y utilidad real de cada herramienta.
- Resultado: Drive solo guarda 1 copia (vieja); Takeout no sirve; sin root no hay acceso a `/data`; la vía sigue siendo las copias locales.
  WhatsApp Web (Opera, PC trabajo) es la única copia completa: archivarla antes de restaurar. Si la copia es `.crypt15` E2E con clave de 64 dígitos,
  se puede descifrar y verificar en el PC con wa-crypt-tools.
- Pendiente / decisiones: el usuario dice que **tiene ficheros antiguos** → falta inventario (nombre, fecha, tamaño, ruta).
  Pasar al equipo personal con ADB. ¿Ya se copió `Databases` al PC antes de la copia nocturna del 20/10?

## 2026-10-20 — Corrección navegador + root descartado
- Qué se hizo: corregido el navegador de WhatsApp Web: es **Brave** (no Opera) en el PC del trabajo; actualizadas rutas del perfil
  (`%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\IndexedDB\...`). Evaluado rootear el OPPO.
- Resultado: **root descartado**: desbloquear el bootloader borra el teléfono entero (también las copias de `/sdcard`). Opciones de desarrollador → solo Depuración USB.
- Pendiente / decisiones: inventario de los ficheros antiguos; confirmar copia de `Databases` al PC; archivar WhatsApp Web desde Brave.
