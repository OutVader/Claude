# Bitácora — CachyOS / Firebat F1 P

Registro cronológico de lo que se ejecuta y sus resultados. Una entrada por sesión/bloque.

Formato:
```
## AAAA-MM-DD — <bloque/acción>
- Comando(s):
- Resultado:
- Decisiones / pendientes:
```

---

## 2026-09-03 — Fase 1F: preparación del playbook (sesión Claude en la nube)
- La sesión de Claude corre en un contenedor remoto (Ubuntu), **no** sobre el Firebat:
  no se ejecutó nada en el hardware real. Entregado el playbook `fase-1-baseline/`.
- Pendiente del usuario (en el Firebat, en este orden):
  1. `bash 00-diagnostico.sh` y pegar la salida.
  2. Confirmar bloque a bloque A→G.
  3. Cerrar con `H-resumen.md`.

## 2026-09-03 — Decisiones confirmadas por el usuario
- **Firewall → firewalld** (recomendado por integración con libvirt/labs).
- **RAM → soldada, NO ampliable. Techo 16 GB** (pendiente verificar con `dmidecode` en el equipo).
- **Escritorio → aplazado a Fase 2.**

## 2026-09-03 — Documentación de pre-instalación + Claude Code + reorganización
- Reorganización: los proyectos pasan a `.claude/proyectos/<nombre>/` (convención del workspace).
  Añadidos `CLAUDE.md` raíz y skill `nuevo-proyecto` que fijan esa regla; skill
  `migracion-windows-cachyos` para la Fase 1 pre-instalación.
- Nuevas guías: `GUIA-FASE1.md` (inicio rápido), `FASE1-preinstalacion-extendida.md`
  (licencia Win, clonado de disco con links, ISO CachyOS + SHA256, USB Ventoy/Rufus/YUMI/Etcher,
  BIOS), `POST-INSTALL-claude.md` (instalar Claude Code, cuenta Pro, importar skills, permisos).
- Repo sincronizado (commit + push) a la rama `claude/cachyos-baseline-firebat-tglfuy`.
- Pendiente del usuario: ejecutar Fase 1 en el equipo real (pre-instalación → instalación →
  baseline) y confirmar WM para Fase 2.

## 2026-10-13 — Gauntlet sobre `fase-1-baseline/` (iteración 1/3, solo diagnóstico)
- Qué se hizo: rúbrica R1–R8 (lint, robustez, idempotencia, seguridad, confirmación, 00 solo lectura, dominio CachyOS, claridad/logs). `bash -n` OK; `shellcheck` 2× SC2010. Crítico Ciego: RECHAZADO.
- Bloqueantes: (1) `common.sh` sin `set -e` → imprime "ok" tras fallos; (2) F: zona `public` deja SSH abierto; (3) F: posible doble firewall (ufw + firewalld); (4) E:25 filtro `enp[0-9]` oculta NICs USB; (5) 00:73 SC2010; (6) A–G sin log, ruta de log de 00 incoherente.
- Pendiente / decisiones: OK de Iñaki para aplicar correcciones (iteraciones 2–3).

## 2026-10-13 — Gauntlet fase-1-baseline, ronda 2 (correcciones B1–B6)
- Qué se hizo: `run()` (aborta si falla, sin "ok" falso) + `start_log()` (salidas/<bloque>-<fecha>.log, NO_LOG=1) en common.sh; A–G con run/start_log; F: se quita ssh de la zona public y un solo firewall (ensure_off: desactivar con OK o abortar); E/00: NIC USB por sysfs, sin ls|grep, `readlink -e`; E: headers por `pacman -Qoq`; A: aviso de reinicio real; G: avisos de /.snapshots y de timeshift; README y `.gitignore` de salidas/.
- Evidencia: bash -n OK; shellcheck -S info 0 avisos; pruebas T1–T5 en el scratchpad (run, start_log, filtros sysfs con perturbación, ensure_off simulado).
- Pendiente: veredicto del Crítico (ronda 2) y verificar en el Firebat.
