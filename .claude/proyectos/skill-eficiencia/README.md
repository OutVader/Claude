# Proyecto: skill-eficiencia
Skill personal «eficiencia» para Claude Code: menos tokens y menos abandonos a mitad de tarea, en Windows y Linux.

- **Usuario:** Iñaki (sistemas: Windows, PowerShell, AD/Exchange; también Linux)
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)
- **Skill:** [`../../skills/eficiencia/`](../../skills/eficiencia/SKILL.md) (fuente versionada) · versión anterior en [`version-anterior/`](./version-anterior/SKILL.md)

## Estado
| Hito | Contenido | Estado |
|---|---|---|
| 1 | Script `eficiencia.py` (preflight, auditar, done, verificar, confiar, presupuesto, envolver, hooks, reglas, autotest) | ✅ autotest 67/67 en Python 3.8, 3.10, 3.11, 3.12 y 3.13 (Linux) |
| 2 | `SKILL.md` (76 líneas, frontmatter `name`/`description`/`allowed-tools`) + `principios.md` + `frontend.md` | ✅ `claude plugin validate --strict` sin avisos |
| 3 | Instalación en el contenedor de la sesión en la nube (`~/.claude`) | ✅ efímera: se pierde al reciclar el contenedor |
| 4 | Instalación en el PC Windows y en el equipo Linux | ⏳ la ejecuta Iñaki (pasos abajo) |
| 5 | Subir la versión nueva a claude.ai (sustituye a la sincronizada, que está incompleta) | ⏳ Iñaki |

## Instalar en tu máquina
Desde la raíz de este repo, ya actualizado con `git pull`.

**Windows (PowerShell):**
```powershell
$dst = "$HOME\.claude\skills\eficiencia"
Copy-Item -Recurse .\.claude\skills\eficiencia $dst
$ef = "$dst\scripts\eficiencia.py"
py -3 $ef autotest                      # debe terminar en "autotest: N/N OK"
py -3 $ef reglas --instalar --simular   # revisa el diff de ~/.claude/CLAUDE.md
py -3 $ef reglas --instalar
py -3 $ef hooks --instalar --simular    # revisa el diff de ~/.claude/settings.json
py -3 $ef hooks --instalar
```

**Linux:**
```bash
cp -r .claude/skills/eficiencia ~/.claude/skills/
ef=~/.claude/skills/eficiencia/scripts/eficiencia.py
python3 "$ef" autotest
python3 "$ef" reglas --instalar --simular && python3 "$ef" reglas --instalar
python3 "$ef" hooks --instalar --simular  && python3 "$ef" hooks --instalar
```

Los hooks quedan en forma exec con la ruta absoluta del intérprete que ejecutó el comando
(en Windows, el `python.exe` real al que apunta `py -3`).

## Desinstalar
```text
<python> eficiencia.py reglas --quitar     # retira el bloque de ~/.claude/CLAUDE.md
<python> eficiencia.py hooks --quitar      # retira los 3 hooks de ~/.claude/settings.json
```
Después, borra `~/.claude/skills/eficiencia/` y, si quieres, el estado en `~/.claude/eficiencia-estado/`
(confianza de comandos, sesiones y presupuestos). `hooks --quitar` solo toca los hooks propios.

## Decisiones pendientes
- [ ] Subir la carpeta `eficiencia` a claude.ai (Customize → Skills) para reemplazar la versión sincronizada.
- [ ] Ejecutar `autotest` en Windows y anotar el resultado en la bitácora.
