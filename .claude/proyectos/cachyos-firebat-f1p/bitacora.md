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
