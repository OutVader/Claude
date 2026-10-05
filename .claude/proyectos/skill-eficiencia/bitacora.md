# Bitácora: skill-eficiencia

## 2026-10-05: versión 2.0.0 (reescritura completa)
- **Qué se hizo:**
  - Versión previa encontrada solo en `~/.claude/skills/synced/…/eficiencia/`: únicamente `SKILL.md`, que enlazaba
    `referencia-effort-cache.md`, `referencia-frontend.md` y `scripts/eficiencia.py`, inexistentes; además usaba
    `argument-hint` (claude.ai lo rechaza) y ofrecía un hook de leer antes de editar. Copia en `version-anterior/`.
  - Nueva skill en `~/.claude/skills/eficiencia/` (contenedor) y en `.claude/skills/eficiencia/` (repo).
  - Instalados en el contenedor: bloque de reglas en `~/.claude/CLAUDE.md` (8 líneas con marcadores) y 3 hooks
    en `~/.claude/settings.json`. Ninguno de los dos archivos existía antes.
- **Resultado:**
  - `autotest` 67/67 en Python 3.8.20, 3.10, 3.11, 3.12 y 3.13 (Linux). 11 mutaciones deliberadas del script:
    todas las detecta el autotest.
  - Prueba real de extremo a extremo con `claude -p --model haiku` en un repo temporal: Claude escribió `hola`,
    el hook Stop bloqueó con la cola del fallo y Claude lo corrigió a `adios` antes de parar (4 turnos).
    El hook PostToolUse también se disparó en la propia sesión de trabajo.
  - `claude plugin validate ~/.claude/skills --strict` (v2.1.289): sin errores ni avisos. Ojo: el validador no
    detectó un YAML roto en una skill de prueba, así que no sustituye al autotest.
- **Correcciones tras contrastar con la documentación:**
  - Effort: el predeterminado es `medium` en Opus 5.5 y Sonnet 5.5, `xhigh` en Opus 4.7 y `high` en el resto;
    Opus/Sonnet 4.6 no tienen `xhigh`. Un `effort` en frontmatter **sustituye** al de la sesión (sube o baja).
    `ultrathink` no cambia el effort enviado a la API: añade una instrucción en contexto.
  - Caché: 1 h solo en la conversación principal con suscripción dentro del plan; 5 min con API key, proveedor
    cloud, créditos de uso y en subagentes. Configurable con `promptCacheTtl`. Cambiar effort no invalida la caché
    en Opus 5.5, Sonnet 5.5 y Fable 5.1 (API key o suscripción); en el resto sí.
  - `/compact`: barato con la caché caliente, caro tras una pausa mayor que el TTL. Para descartar un camino,
    `/rewind` (reutiliza un prefijo ya en caché).
  - Editar CLAUDE.md a mitad de sesión no invalida la caché, pero tampoco aplica hasta `/clear`, `/compact` o reinicio.
  - Edit/Write ya no exigen siempre leer antes (modelos nuevos): editan sin leer solo si `old_string` coincide
    exactamente y leer no pediría permiso. Seguro por diseño → no se añade hook.
  - Claude Code ya corta a las 8 continuaciones seguidas por hooks Stop; nuestro límite es 2.
- **Pendiente / decisiones:**
  - Instalar en Windows y Linux (README), ejecutar allí `autotest` y anotar el resultado.
  - Subir la carpeta a claude.ai para reemplazar la versión sincronizada incompleta.
  - No comprobado aquí: cmd.exe, `py -3`, alias de Microsoft Store, consola cp1252 real, `.cmd`/`.bat` de npm,
    `pwsh` con Pester y PSScriptAnalyzer (no instalados en el contenedor).
