# CLAUDE.md · Homelab mini PC Firebat (CachyOS / Omarchy / LLM) · v2.0 20-oct-2026
Español de España. Leer primero `Contexto_maestro_Linux_Firebat_CachyOS_Omarchy_LLM.md` (v2.0; `CONTEXTO.md` v1.1 es histórico). Originales: `original-2026-10-20.md` (copia truncada del chat) y el adjunto de Iñaki (base de la v2.0).
Meta: sistema base del homelab mantenible, seguro, recuperable y bajo control de Iñaki, con IA/LLM locales realistas.

## Normas (bloqueantes)
- NO ejecutar ni dar como definitivo ningún instalador (Omarchy, adaptadores, `curl|bash`) sin hardware confirmado, script auditado, backup Clone verificado y OK explícito de Iñaki.
- Nada de `pacman -Rdd` ni cambios de bootloader, mkinitcpio o pacman.conf sin explicar el riesgo y la reversión.
- No dar por seguro un `--dry-run` sin leer su implementación. Una VM no prueba el hardware real.
- Estados: CONFIRMADO / COMPATIBLE CON RESERVAS / INDICIO / NO VERIFICADO / INCOMPATIBLE, con fuente y fecha. Fuentes oficiales separadas de las comunitarias.
- No inventar; no confundir una integración de IA con suscripción incluida o aprendizaje real.
- No borrar ni mover: `.bak` y CHANGELOG. No pedir números de serie, UUID ni credenciales.
- QA: `RUBRICA.md` y revisión independiente; ahorro de tokens.
