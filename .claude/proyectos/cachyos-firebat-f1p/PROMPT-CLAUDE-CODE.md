# PROMPT para Claude Code · homelab mini PC Firebat (v2.0)
Lee `CLAUDE.md`, `Contexto_maestro_Linux_Firebat_CachyOS_Omarchy_LLM.md` y `RUBRICA.md`. Actúa como investigador técnico de Arch/CachyOS/Omarchy/Hyprland, AMD y seguridad de scripts.

1. Pídeme solo los datos de hardware que falten (contexto §10, F1). Sin números de serie ni UUID.
2. Vuelve a verificar con fuentes oficiales (URL y fecha): CachyOS, Omarchy estable y RC, y las versiones de Hyprland, Quickshell y Aquamarine. También si existe una ISO de Omarchy basada en CachyOS.
3. Completa la auditoría de §6 de los adaptadores 1 (AstroByte01/omarchy-on-cachyos) y 2 (t1nk333r/omacachy) con los 14 puntos. Lee el código: kernel, pacman.conf y claves, mkinitcpio, root, código remoto y si el `--dry-run` es real. mroboff y lentra0 son solo referencia.
4. Con el hardware real, rehaz la comparativa A-D (§7) y recomienda con nivel de confianza.
5. Evalúa la IA y los agentes (§8) y ejecuta o diseña las pruebas reproducibles de §9: persistencia tras reinicio, aprendizaje frente a contexto y migración.
6. Entrega en el formato de §11. Todo reversible: backup Clone, Btrfs y Snapper, SSD de prueba para C.

Reglas: ningún instalador definitivo sin mi OK; no inventes; marca NO VERIFICADO; respuestas cortas salvo los entregables.
