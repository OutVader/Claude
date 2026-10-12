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
