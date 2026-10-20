# Proyecto: Mini PC Firebat F1 P → CachyOS
## Escritorio bonito (Wayland tiling) + IA local + Laboratorios de Ciberseguridad

> Documento maestro de contexto y plan por fases (v3).
> En CachyOS déjalo como `~/CONTEXT.md` y pásaselo a Claude Code como referencia.

---

## 0. Contexto

- **Usuario:** Inaki. Admin de sistemas (AD/Exchange), scripting (PowerShell),
  especialidad infra MS + ciberseguridad + cloud. **Idioma: español** en todo.
- **Objetivo:** migrar el mini PC (hoy Windows 11 Pro) a **CachyOS** con un
  escritorio **bonito y funcional** (estética oriental/japonesa tipo los vídeos
  de referencia), **optimizado para IA local** y para montar **laboratorios de
  ciberseguridad** (virtualización, redes segmentadas).
- **Método:** por fases, confirmando cada una. Nada destructivo sin
  confirmación explícita.
- **Estrategia:** backup Win11 + licencia → formatear → instalación limpia.
- **Marco de evaluación HW:** chip real, térmica 24/7, cuellos físicos
  (cables/puertos), soporte en kernel, utilidad real vs. marketing.

---

## 1. Hardware — Firebat F1 P

- **APU:** AMD "Ryzen 7 H 255" = **Ryzen 7 8745H renombrado**. 8C/16T, Zen4,
  boost ~4.9 GHz. Soporta virtualización **AMD-V (SVM)** — activar en BIOS.
- **iGPU:** **Radeon 780M** (RDNA3, 12 CU). Acelera LLMs vía **Vulkan**.
- **RAM:** 16 GB DDR5-5600. ⚠️ **CONFIRMAR si es soldada o SO-DIMM**: las
  reviews del F1 P dicen SO-DIMM ampliable a **64 GB**; el usuario cree que su
  unidad es **soldada a 16 GB**. Si se puede ampliar → **subir a 32 GB** cambia
  radicalmente el techo de IA + VMs. Plan actual: **techo 16 GB**.
- **Disco:** 512 GB NVMe PCIe 4.0 + **2º slot M.2 libre** (hasta 4 TB).
- **Red:** 2.5 GbE integrada + **Wi-Fi 6**. Puertos: **USB4 (40 Gbps)**,
  USB 3.2 Gen 2, HDMI, DP 1.4.

### Tarjetas de red USB añadidas
| Tarjeta | Chip | Vel. | Linux |
|---|---|---|---|
| UGREEN CM648 | RTL8156BG | 2.5G | Nativo `r8152`, plug&play |
| WAVLINK WL-NWU340G | RTL8157 | 5G | Mainline `r8152` ~mar-2026; si negocia mal → `r8152-dkms` (AUR) + blacklist `cdc_ncm`. Enchufar a **USB4/Gen2** |
| Genérico 2.5G | RTL8156B | 2.5G | Nativo |

Uso previsto: 2.5G integrada + UGREEN 2.5G = **doble 2.5G para segmentar redes
de laboratorio**; el 5G para futuro switch. Enchufar el 5G al **USB4**.

---

## 2. Estética objetivo (de los vídeos de referencia)

- Vídeos YouTube (canal Ezku): **KDE Plasma 6** tematizado para **imitar el
  tiling/ricing de Hyprland**, usando la estética **Caelestia** (port a KDE:
  `ladybug-me/caelestia-dots-kde`). Ruta "estabilidad".
- Reel Instagram ("CachyOS oriental girl"): **Hyprland/KDE muy tematizado**,
  temática oriental (arte asiático / lo-fi para la paleta).
- Shells "espectaculares" (Quickshell): **Caelestia** (`caelestia-dots/shell`)
  y **Noctalia** (packs oficiales CachyOS). Generan **paleta dinámica desde el
  wallpaper**.
- Fondos: Wallhaven (tags `oriental landscape`, `anime scenery`),
  `catppuccin/wallpapers`. Paletas base: Catppuccin / Nord / Gruvbox.
- Caveat: Caelestia en CachyOS puede chocar por versión de **Quickshell**
  (AUR vs repo). Noctalia suele dar menos fricción.

---

## 3. DECISIÓN DE ESCRITORIO (pendiente de confirmar antes de Fase 2)

Objetivo declarado por el usuario: **Qtile**. Recomendación honesta tras
analizar objetivo (bonito como los vídeos + IA + labs, con 16 GB):

| Ruta | Aspecto vídeos | RAM libre p/ IA+VMs | Estabilidad | Nota |
|---|---|---|---|---|
| **Hyprland + Caelestia/Noctalia** | ✅ es esto | Ligero | Buena | ⭐ **Recomendada** |
| KDE + caelestia-dots-kde | ✅ (ruta Ezku) | Pesado | Máxima | Si prima estabilidad |
| Qtile | ❌ ricing manual | Muy ligero | Buena (DIY) | Solo si quieres config Python |

Razonamiento: con 16 GB compartidos entre escritorio + LLM + VMs, conviene un
escritorio **ligero**; **Hyprland + Caelestia** da el look de los vídeos y se
mantiene ligero → mejor que Qtile para este objetivo. **Qtile** queda como
alternativa si se prioriza control por Python sobre estética de fábrica.
> ACCIÓN: confirmar WM antes de Fase 2. Fase 1 es idéntica en cualquier caso.

---

## 4. IA local (techo 16 GB)
- Modelos **7-8B Q4** con soltura; 13B ajustado; contexto moderado.
- Backend: **Ollama/llama.cpp con Vulkan** (Mesa moderno de CachyOS) sobre 780M.
- Con 16 GB: **no** correr LLM grande y varias VMs a la vez. Si se amplía a
  32 GB, todo mejora mucho.

## 5. Laboratorios de ciberseguridad
- **Virtualización:** KVM/QEMU + `virt-manager` (requiere SVM activo en BIOS).
- **Contenedores:** Docker o Podman.
- **Redes segmentadas:** aprovechar doble 2.5G para redes de laboratorio
  aisladas; opción de VM router/firewall (pfSense/OPNsense) como gateway del lab.
- **Análisis:** Wireshark, nmap y utilidades estándar de red.
- **Contención RAM (16 GB):** VMs ligeras, uso de snapshots, no solapar LLM
  pesado con varias VMs. Considerar swap/zram generoso.

---

## PLAN POR FASES
- **Fase 1** ← *ahora*: backup Win11 + clave → USB → formatear → instalar
  CachyOS → baseline + updates + validación de hardware/red/virtualización.
- **Fase 2**: WM decidido (Hyprland+Caelestia/Noctalia recomendado) + estética
  oriental + fondos + paleta dinámica.
- **Fase 3**: IA local (Ollama + modelo, Vulkan) + Claude Code + integración
  con el shell (p. ej. companion de Noctalia).
- **Fase 4**: laboratorio de ciberseguridad (virt-manager, contenedores, redes
  segmentadas con las NICs).
- **Fase 5**: dotfiles propios, seguridad, backups automáticos, (Windows en VM
  opcional en el 2º M.2).

---

> El detalle operativo de la Fase 1F (diagnóstico + bloques A–H) vive en
> [`fase-1-baseline/`](./fase-1-baseline/). Este documento es el contexto maestro;
> la ejecución paso a paso está en esos scripts y su `README.md`.

## Preferencias permanentes
- Español en todo. Avisar/confirmar antes de acciones irreversibles.
- Enfoque por fases. Análisis HW con el marco indicado.

## Pendiente del usuario
- Confirmar RAM (soldada 16 GB vs SO-DIMM ampliable a 32/64).
- **Confirmar WM antes de Fase 2** (recomendado: Hyprland + Caelestia/Noctalia).
