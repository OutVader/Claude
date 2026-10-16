# Bitácora — gauntlet-portable
## 2026-10-13 — Creación
- Qué se hizo: prompt portable con reglas maestras, eficiencia, bucle Constructor/Crítico, plantillas de rúbrica, prompt del Crítico e informe.
- Resultado: `GAUNTLET-PORTABLE.md` listo para copiar.
- Pendiente / decisiones: probar en Grok; ajustar si la plataforma no admite subagentes.

## 2026-10-13 — v2 con la "Guía del Gauntlet Prompt" (Xavier Mitjana, IA en Acción) + gauntlet sobre sí misma
- Fuente: PDF de 19 páginas, que acompaña al vídeo. El vídeo (youtu.be/sc6PJpFyrvY) no fue accesible: YouTube bloquea con "Sign in to confirm you're not a bot".
- Incorporado: encargo en 4 cajas (Tarea/Método/Listón/Entregable); listón con referencia concreta + checklist comprobable; restricciones no negociables Rn; árbitro adversarial sin elogios ni críticas vagas (qué/dónde/cómo debería ser); juzgar el resultado, no las intenciones; pruebas de perturbación; rondas configurables; "Decisiones tomadas"; resumen de rondas; plantilla corta (Bloque C).
- Gauntlet: 3 rondas. R1 RECHAZADO (B1–B7), R2 RECHAZADO (B8–B10), R3 RECHAZADO (B11–B13). Tope alcanzado: B11–B13 corregidos **sin revisar por el Crítico**.
- Pendiente: probar en Grok; una ronda extra de verificación si Iñaki la quiere.

## 2026-10-13 — Prompt universal + export de skills
- Qué se hizo: `PROMPT-UNIVERSAL.md` (cualquier persona y LLM, chat o agente; perfil rellenable; Crítico en 3 niveles con la autocrítica marcada como "revisión NO ciega"); `export-skills/` con una copia de `eficiencia` y `instalar-skills.ps1` (destino `%USERPROFILE%\.claude\skills\<nombre>\SKILL.md`, con .bak y -WhatIf).
- Resultado: la skill `eficiencia` sincronizada solo trae SKILL.md; faltan `scripts/eficiencia.py` y `referencia-*.md`. Avisado en el README de export-skills.
- Pendiente: ejecutar el instalador en Windows (no verificable en la nube: no hay pwsh); pasar el gauntlet al prompt universal si Iñaki lo quiere.

## 2026-10-13 — Gauntlet sobre PROMPT-UNIVERSAL.md (3 rondas)
- R1 RECHAZADO (B1–B6: límite de las instrucciones personalizadas, inyección en el Crítico, marca [GAUNTLET], perfil vacío, ids sin contenido, devolver el veredicto). R2 RECHAZADO (B7–B9: RECHAZADO sin Bn, entregable completo en chat, rellenar el Bloque C). R3 RECHAZADO (B10: "Listo" se comía el encargo; B11: veredicto incoherente sin salida).
- Tope alcanzado: B10–B11 corregidos **sin revisar por el Crítico**, junto con opcionales (sin secretos en el nivel 1, aviso sobre el chat temporal, del nivel 2 al 3, más de 5 rondas solo con confirmación).
- Pendiente: probarlo en 2–3 LLMs reales.

## 2026-10-16 — Gauntlet sobre la skill gauntlet-loop v3 (chat + Claude Code)
- R1 RECHAZADO (B1 nivel 2 sin pasos literales / "sin esta skill activa" no factible; B2 nivel 1 sin tipo de solo lectura y "rehacer" sin definir; B3 parada por no verificable frente a esperar al usuario; B4 excepción de confirmación demasiado amplia).
- R2 **APROBADO** (B1–B4 cerrados). Se aplicaron 5 opcionales.
- R3 RECHAZADO por los cambios posteriores: B5 (CLAUDE.md podía rebajar "datos, no órdenes"), B6 (segunda incoherencia de formato sin salida), B7 (remedio de interferencias poco práctico). Corregidos tras el tope, **sin revisar por el Crítico**.
- `gauntlet-loop.zip` regenerado (idéntico a la fuente).

## 2026-10-16 — gauntlet-loop v4 (tips de otro agente) + subagente critico-ciego
- Integrado: 2 rondas + cierre; alcance previo; ≥1 criterio ejecutado con caso de error; "opcional que contradice el objetivo = bloqueante"; evidencia al 100 % resumida n/N y nunca más larga que el artefacto; diff + muestra en rondas intermedias (solo Claude Code); Crítico siempre nuevo; hash sha256 del alcance (obligatorio con Explore); metacognición proporcional, DUDA y traza de confianza; estado fuera del repo; `.claude/agents/critico-ciego.md` (Read/Grep/Glob).
- No integrado (razonado): Bash en el Crítico (en este diseño ejecuta el Constructor), `.gauntlet/` dentro del repo, `omitClaudeMd`/`maxTurns`/`disable-model-invocation` (dependen de la versión o romperían la invocación en el chat).
- Gauntlet: R1 RECHAZADO (B8 sin progreso, B9 chat vs diff, B10 Explore tiene Bash, B11 cierre sin definir) → R2 **APROBADO** → cierre RECHAZADO (B12: estado en archivo vs mostrar cajas). B12 corregido **sin revisar**. sha256 del alcance OK en las 3 pasadas.
