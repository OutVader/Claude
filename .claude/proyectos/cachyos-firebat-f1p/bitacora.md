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

## 2026-10-20 — v2.0: Fase 0 y Fase 1 rediseñadas (sesión Claude en la nube; nada ejecutado en el equipo)
- Importado el traspaso `homelab-minipc-claude-v2-2026-10-20.zip` (sin colisiones; `original-2026-10-20.md` con el mismo SHA256).
- Plan de septiembre movido a `v1-2026-09/` (histórico, a petición de Iñaki). Vigente en la raíz: `FASE0.md`, `FASE1.md`, `VERSIONES.md` y `scripts/`.
- Decisiones de Iñaki: Omarchy en 3 rutas con puerta; backup con Rescuezilla (alternativa Clonezilla); fusionar en este proyecto.
- Revalidado el 20-oct-2026: ISO CachyOS 260809 · Omarchy 4.0.6 (RC 4.5.0-rc1) · omacachy `b46236a` (baseline 4.0.2) · AstroByte01 `d8d16f0` · versiones de herramientas en `VERSIONES.md`.
- Hallazgo: la config de Hyprland de Omarchy 4.0.6 depende de `/usr/share/omarchy` (paquete `omarchy`) → ruta D = recrear, no copiar.
- Pendiente (Iñaki, en el equipo): Fase 0 completa → PUERTA 0; paso 1.1 → resolver los conflictos de hardware y elegir la ruta.
