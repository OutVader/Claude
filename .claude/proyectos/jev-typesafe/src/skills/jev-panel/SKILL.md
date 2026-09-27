---
name: jev-panel
description: Panel de JEV (TypeSafe) en Claude Code. Muestra coste, % auto-aprobado, % bloqueado por la lista estática, latencia, llamadas evitadas por la caché local, el criterio de las últimas decisiones y las reglas aprendidas pendientes de confirmar. Úsalo cuando el usuario pida /jev-panel, el coste de JEV, por qué JEV aprobó o no un comando, o revisar/confirmar reglas locales.
argument-hint: "[sync | diag | reglas listar]"
allowed-tools:
  - 'Bash({{JEV}} panel*)'
  - 'Bash({{JEV}} reglas listar*)'
  - 'Bash({{JEV}} diag*)'
  - 'PowerShell({{JEV}} panel*)'
  - 'PowerShell({{JEV}} reglas listar*)'
  - 'PowerShell({{JEV}} diag*)'
---

# /jev-panel — criterio, coste y reglas de JEV

Argumento opcional: `$ARGUMENTS`

1. Según el argumento, ejecuta **uno** de estos comandos y muestra su salida tal cual en un bloque de código:
   - (vacío) → `{{JEV}} panel`
   - `diag`  → `{{JEV}} diag`   (red, proxy, inspección SSL, key presente, cortacircuitos)
   - `reglas listar` → `{{JEV}} reglas listar`
   - `sync`  → `{{JEV}} sync`   (revalida la caché en lotes; usa red: pedirá permiso)
2. Lectura rápida de la columna de criterio del panel:
   `estatico` = la lista estática lo bloqueó (nunca sale a la red) · `cache`/`regla` = decidido en
   local sin red · `jev` = consulta nueva a JEV · `error` = fallo o cortacircuitos (fail-closed:
   aviso normal).
3. Si el panel lista **Propuestas**, pregunta al usuario (AskUserQuestion, multiselección) cuáles
   convertir en regla local permanente. Por cada una elegida ejecuta
   `{{JEV}} reglas aprobar <id>`; ese comando **pedirá permiso** a propósito
   (toca la configuración de JEV). Nunca apruebes propuestas sin confirmación explícita.
4. Para retirar una regla: `{{JEV}} reglas revocar <id>` (también con confirmación).
5. No añadas resúmenes largos: como mucho una línea de lectura del panel.
