# Bitácora — screenshots-oppo

## 2026-10-12 — Retomado como proyecto propio
- **Qué se hizo:** proyecto creado; script `00` para instalarlo en AGENTES_WD y recuperar la memoria,
  los scripts y las sesiones anteriores; script `01` de vaciado por año y bloques, con verificación.
- **Verificación hecha aquí** (con PowerShell 7 y un `adb` simulado que sirve una carpeta local):
  inventario por año (año sacado del nombre o, si no lo lleva, de la fecha), copia en bloques de 2,
  reanudación (`YA_EXISTIA`), borrado solo de lo verificado y el año pedido (otros años intactos), registro CSV.
- **Sin verificar:** con el OPPO real y Windows PowerShell 5.1; tampoco `00` (necesita las rutas del PC).
- **Pendiente:** ejecutar `00 -Aplicar`, leer `docs\memoria-original.md` para saber la carpeta
  destino y en qué punto quedó 2023, y seguir con `01`.

## 2026-10-12 — Handoff y prompt para la v2 genérica
- **Qué se hizo:** `HANDOFF-CONTEXTO.md` (contexto completo e independiente) y `PROMPT-NUEVA-CONVERSACION.md` (prompt para
  generalizar a cualquier origen y destino → `Traspasar-Archivos.ps1` en el proyecto nuevo `Traspaso-Archivos`).
- **Pendiente:** ejecutar `00-Instalar-en-AGENTES_WD.ps1 -Aplicar` (lleva también estos dos archivos a AGENTES_WD) y abrir
  una conversación nueva con Claude Code local en AGENTES_WD con el prompt.
