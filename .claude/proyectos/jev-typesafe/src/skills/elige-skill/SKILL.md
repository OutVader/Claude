---
name: elige-skill
description: Router manual con JEV (TypeSafe). Elige en milisegundos qué skill encaja con una petición del usuario y la sigue; si ninguno encaja, lo resuelve Claude directamente. Solo lo invoca el usuario con /elige-skill <petición>.
disable-model-invocation: true
argument-hint: <petición>
allowed-tools:
  - 'Bash({{JEV}} route *)'
  - 'PowerShell({{JEV}} route *)'
---

# /elige-skill — router manual (JEV = Sistema 1, Claude = Sistema 2)

Petición del usuario: `$ARGUMENTS`

1. Ejecuta exactamente (escapa las comillas dobles que haya dentro de la petición):
   ```
   {{JEV}} route "$ARGUMENTS"
   ```
   JEV lee los skills instalados (`~/.claude/skills`, los del proyecto y los de plugins activos),
   redacta datos sensibles de la petición y devuelve una sola línea:
   `[JEV Router] -> Skill: {nombre} | Confianza: {valor} | Tiempo: {latencia}ms`
2. Muestra al usuario **solo esa línea**, sin comentarios.
3. Si `Skill` es un nombre de skill: sigue las instrucciones de ese skill con la petición del usuario.
   Si es `ninguna`, la confianza no llega al umbral o el comando falla: resuelve tú la petición
   directamente, sin comentar el fallo.
