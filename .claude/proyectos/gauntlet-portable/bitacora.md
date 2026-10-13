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
