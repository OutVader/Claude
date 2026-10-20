# RÚBRICA · traspaso homelab-minipc a Claude Code (20-oct-2026)
Aprobado si se cumplen TODOS:
1. Original intacto en `original-2026-10-20.md` (sin editar tras crearse).
2. Cada dato de versión/estado lleva fuente URL y fecha de consulta; lo no comprobado va marcado **NO VERIFICADO**.
3. Hardware: no se asume modelo ni CPU; se señalan nombres dudosos.
4. Adaptadores: último commit, issues/PR abiertos relevantes y compatibilidad con Omarchy 4.x.
5. Seguridad: ningún instalador se ejecuta ni se da como paso definitivo; backup con Clone previo; Btrfs/Snapper; SSD de prueba; revisión de scripts antes de ejecutar.
6. Aporte Geordi (homelab/seguridad/backups) y MacGyver (Linux) presente; preferencia de control del ecosistema y LLM locales con 16 GB.
7. Normas: no borrar, `.bak`, CHANGELOG; mismo formato que handoff empleo (CONTEXTO, PROMPT-CLAUDE-CODE, CLAUDE, RUBRICA, CHANGELOG).
8. Magro: CONTEXTO ≤ 150 líneas; PROMPT ≤ 40; CLAUDE ≤ 30.

## Añadido v2.0 (antes: solo criterios 1-8)
9. El contexto maestro separa hechos, hipótesis y NO VERIFICADO, y las fuentes oficiales de las comunitarias.
10. Incluye auditoría de seguridad, comparativa A-D, IA y agentes (costes, límites, memoria, skills, portabilidad, aprendizaje real), pruebas reproducibles (reinicio, migración) y el formato de salida.
11. El .md y el .txt dicen lo mismo; el zip de entrega no lleva .bak.
