# Proyecto: Firebat F1 P → CachyOS + Omarchy (homelab mini PC) · v2.0

Migración del mini PC Firebat de Windows 11 a una base **CachyOS** con escritorio Hyprland y
estilo **Omarchy**, como nodo inicial del homelab (IA local y laboratorios). Trabajo por fases,
en español, sin pasos destructivos sin puerta previa ni tu OK.

## Empieza aquí (vigente, 20-oct-2026)
| Orden | Documento | Para qué |
|---|---|---|
| 1 | [`FASE0.md`](./FASE0.md) | En Windows: inventario, licencia, BitLocker, backup verificado, ISO (SHA256 + firma), USB y BIOS → **PUERTA 0** |
| 2 | [`FASE1.md`](./FASE1.md) | En el Firebat: hardware desde el live → instalación de CachyOS → actualización → Snapper → **PUERTA 2** de Omarchy (rutas A/B/C/D) → comprobaciones |
| — | [`VERSIONES.md`](./VERSIONES.md) | Versiones y enlaces validados el 20-oct-2026, con alternativas |
| — | [`scripts/`](./scripts/) | `Verificar-ISO.ps1` (Windows, SHA256) · `comprobar-sistema.sh` (Linux, solo lectura) |
| — | [`bitacora.md`](./bitacora.md) | Qué se ejecuta en el equipo real y con qué resultado |
| ★ | [`SEGUIR-EN-LOCAL.md`](./SEGUIR-EN-LOCAL.md) | **Contexto + Prompt** para continuar con Claude Code en tu equipo |

## Traspaso v2.0 (handoff del 20-oct-2026, importado del ZIP sin modificar salvo el CHANGELOG)
[`CLAUDE.md`](./CLAUDE.md) (normas bloqueantes) · [`Contexto_maestro_Linux_Firebat_CachyOS_Omarchy_LLM.md`](./Contexto_maestro_Linux_Firebat_CachyOS_Omarchy_LLM.md) (+ `.txt`) ·
[`PROMPT-CLAUDE-CODE.md`](./PROMPT-CLAUDE-CODE.md) · [`RUBRICA.md`](./RUBRICA.md) · [`CHANGELOG.md`](./CHANGELOG.md) ·
[`original-2026-10-20.md`](./original-2026-10-20.md) (no tocar) · [`CONTEXTO.md`](./CONTEXTO.md) (v1.1, histórico del handoff).

## Histórico
[`v1-2026-09/`](./v1-2026-09/): plan de septiembre de 2026 (Hyprland + Caelestia/Noctalia, baseline A–H y guía v1). Se conserva íntegro; solo se añadió un aviso de histórico en `README.md` (original en `README.md.bak-v1`). **No es la guía vigente.**

## Decisiones y pendientes
- [x] Omarchy en la Fase 1: **3 rutas con puerta**; se elige tras identificar el hardware (paso 1.1).
- [x] Herramienta de backup: **Rescuezilla** (alternativa: Clonezilla).
- [x] Cortafuegos: firewalld (sept-2026), a revisar si la ruta es A o C (Omarchy activa ufw).
- [ ] Hardware real: CPU, disco (512 GB o 1 TB), RAM (soldada o SO-DIMM), 2.º M.2 → paso 0.1 y paso 1.1.
- [ ] Ruta definitiva (A/B/C/D) → PUERTA 1.
