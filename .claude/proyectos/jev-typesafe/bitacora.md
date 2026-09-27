# Bitácora — jev-typesafe

## 2026-09-27 — Diseño, implementación y pruebas (sesión cloud)
- **Qué se hizo:**
  - Diagnóstico: la sesión corre en un contenedor Ubuntu (no en la máquina de Iñaki), sin key. Endpoint alcanzable (401 sin auth).
  - Decisiones con Iñaki: perfil **corporativo rediseñado**, equipo de trabajo **Windows nativo**, runtime
    **PowerShell primero / Python si es más óptimo**, red **local-first** (patrón nuevo → JEV, sync semanal por lotes),
    módulo **/jev-panel**, criterio visible en pantalla + log, auto-aprobador solo shell (Bash|PowerShell),
    exclusiones genéricas.
  - Verificado en la doc oficial: formato JEV (`questions` como objeto, respuestas `noul`/`choice`/`score`),
    `PermissionRequest` → `decision.behavior`, `systemMessage`, forma exec (`command` + `args`), matcher `Bash|PowerShell`,
    `allowed-tools` en skills.
  - Código: `src/jev/{jev.ps1,jev.py,jev_permission_hook.*,reglas.json}`, skills, `instalar.ps1`, simulador y banco de pruebas.
- **Resultado:** `pruebas/ejecutar_pruebas.py --real` → **52/52 + ping real con key falsa = http_401** (python 3.11 y pwsh 7.6).
  Instalador probado en carpeta temporal: fusión de settings conservando hooks/permisos previos, `.bak`, idempotente.
- **Pendiente / decisiones:** instalar en el Windows del trabajo, crear key y guardarla con DPAPI, `diag` + `ping` real,
  validar 5.1 y DPAPI-Python en Windows, consulta a Seguridad sobre política de IA/DLP y excepción de URL.
