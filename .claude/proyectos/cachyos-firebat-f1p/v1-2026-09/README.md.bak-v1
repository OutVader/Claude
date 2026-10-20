# Proyecto: Mini PC Firebat F1 P → CachyOS

Migración de Windows 11 a **CachyOS** (Arch-based, Wayland) con tres objetivos:
escritorio bonito (tiling estética oriental), **IA local** y **laboratorios de
ciberseguridad**. Trabajo **por fases**, en **español**, sin acciones destructivas
sin confirmación.

- **Usuario:** Iñaki — admin de sistemas (AD/Exchange, PowerShell), infra MS + ciber + cloud.
- **Documento maestro:** [`CONTEXT.md`](./CONTEXT.md) (contexto y plan completo v3).
- **Bitácora:** [`bitacora.md`](./bitacora.md).

## Guías de Fase 1
- 🚀 [`GUIA-FASE1.md`](./GUIA-FASE1.md) — inicio rápido (checklist para empezar).
- 📘 [`FASE1-preinstalacion-extendida.md`](./FASE1-preinstalacion-extendida.md) — detalle:
  licencia Windows, clonado de disco, ISO CachyOS + SHA256, USB de arranque, BIOS.
- 🤖 [`POST-INSTALL-claude.md`](./POST-INSTALL-claude.md) — instalar Claude Code, vincular
  cuenta Pro, importar skills y permisos.
- ⚙️ [`fase-1-baseline/`](./fase-1-baseline/) — playbook que se ejecuta EN el mini PC (bloques A–H).

## Hardware (resumen)
- APU **AMD Ryzen 7 8745H** ("Ryzen 7 H 255"), 8C/16T Zen4 · iGPU **Radeon 780M** (RDNA3).
- **16 GB DDR5** (⚠️ confirmar soldada vs SO-DIMM ampliable) · NVMe 512 GB + 2º slot M.2 libre.
- Red: **2.5GbE** integrada + Wi-Fi 6 + **USB4**. NICs USB: UGREEN 2.5G (RTL8156BG),
  WAVLINK 5G (RTL8157, va en USB4/Gen2), genérico 2.5G (RTL8156B).

## Estado por fases
| Fase | Contenido | Estado |
|------|-----------|--------|
| **1** | Baseline + validación (HW/red/virtualización) | ▶ **en curso** — ver [`fase-1-baseline/`](./fase-1-baseline/) |
| 2 | Escritorio/WM (recomendado Hyprland + Caelestia/Noctalia) + estética | pendiente |
| 3 | IA local (Ollama/llama.cpp por Vulkan sobre 780M) + Claude Code | pendiente |
| 4 | Laboratorio ciber: virt-manager/KVM, contenedores, redes segmentadas | pendiente |
| 5 | Dotfiles, seguridad, backups automáticos, (Windows en VM opcional) | pendiente |

## Reglas permanentes
- Español en todo. Confirmar antes de acciones irreversibles. Enfoque por fases.
- Marco de evaluación HW: chip real, térmica 24/7, cuellos físicos (cables/puertos),
  soporte en kernel, utilidad real vs. marketing.

## Decisiones
- [x] **Firewall: firewalld** (por integración con libvirt/labs).
- [x] **RAM: soldada, no ampliable → techo 16 GB** (verificar con `dmidecode` en el equipo).
- [ ] **WM de Fase 2** (recomendado Hyprland + Caelestia/Noctalia; alternativa Qtile). ⏳
