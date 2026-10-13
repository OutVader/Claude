# export-skills — copias locales de tus skills

| Skill | Origen en el repo | Destino en Windows |
|---|---|---|
| `gauntlet-loop` v2 | `.claude/skills/gauntlet-loop/SKILL.md` (fuente única, no se duplica) | `C:\Users\<tu usuario>\.claude\skills\gauntlet-loop\SKILL.md` |
| `eficiencia` | `export-skills/eficiencia/SKILL.md` (copia de tu skill de cuenta) | `C:\Users\<tu usuario>\.claude\skills\eficiencia\SKILL.md` |

## Instalar (PowerShell, desde el clon del repo)
```powershell
cd <ruta-del-clon>\.claude\proyectos\gauntlet-portable\export-skills
.\instalar-skills.ps1 -WhatIf   # ensayo: muestra lo que haría
.\instalar-skills.ps1           # instala (hace .bak si ya existían)
```
Si la política de ejecución lo bloquea: `powershell -ExecutionPolicy Bypass -File .\instalar-skills.ps1`.

## ⚠ Aviso sobre `eficiencia`
- El `SKILL.md` llama a `scripts/eficiencia.py` y enlaza `referencia-effort-cache.md` y
  `referencia-frontend.md`. **Esos archivos no estaban en la copia sincronizada**: solo
  llegó el `SKILL.md`. Si la instalas en local sin ellos, fallará en el primer paso
  (`EF preflight`). Si tienes el paquete completo (.zip o .skill original), cópialo
  entero a la misma carpeta.
- Ya la tienes en tu cuenta como `anthropic-skills:eficiencia`. La copia local se llama
  `eficiencia` y no choca con ella, pero tendrías dos con la misma función.
