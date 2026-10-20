# Fase 1F — Baseline + validación (CachyOS / Firebat F1 P)

> Playbook **WM-agnóstico**: solo baseline y validación. **No** instala escritorio/WM ni
> modelos de IA (eso es Fase 2 y Fase 3). Cada bloque que modifica el sistema **pide
> confirmación** y es **idempotente** (`--needed` no reinstala lo ya presente).

## Cómo se usa (en el Firebat, no en la nube)

Esta carpeta es un **cuaderno de ejecución**. Los scripts corren **en tu CachyOS**,
no en la sesión de Claude en la nube (que no toca tu hardware). Orden recomendado:

```bash
cd fase-1-baseline
mkdir -p salidas

# 0) DIAGNÓSTICO (solo lectura). Pega la salida en el chat antes de seguir.
bash 00-diagnostico.sh 2>&1 | tee salidas/diagnostico-$(date +%F).txt

# Luego, bloque a bloque, revisando cada uno:
bash A-mirrors-update.sh
bash B-graficos-amd.sh
bash C-base.sh
bash D-fuentes-iconos.sh
bash E-red-5g.sh        # diagnóstico primero; arreglo solo si hace falta
bash F-firewall.sh
bash G-snapshots.sh
```

Al terminar, rellena `H-resumen.md` (o pégame las salidas y lo cierro yo).

> Consejo: crea el snapshot **baseline** (bloque G) **al principio** si ya tienes
> Btrfs+snapper configurado, para tener punto de retorno antes de instalar nada.

## Qué hace cada bloque (y por qué)

| # | Bloque | Acción | Riesgo | Reversible |
|---|--------|--------|--------|------------|
| 00 | Diagnóstico | `inxi`, RAM (`dmidecode`), discos, UEFI/bootloader, SVM/KVM, NICs (chip/driver/velocidad) | **Ninguno** (solo lectura) | — |
| A | Mirrors + update | `cachyos-rate-mirrors` + `pacman -Syu` (update completo, nunca parcial) | Bajo | — |
| B | Gráficos AMD | `amd-ucode mesa vulkan-radeon libva-mesa-driver libva-utils vulkan-tools radeontop` | Bajo | Desinstalar |
| C | Base | `git base-devel inxi btop fastfetch wget curl unzip openssh ethtool dmidecode` (+ `paru` si falta). SSH **no** se activa | Bajo | Desinstalar |
| D | Fuentes/iconos | `ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk papirus-icon-theme` | Nulo | Desinstalar |
| E | Red 5G (RTL8157) | Diagnóstico; **solo si** cae en `cdc_ncm`: `r8152-dkms` (AUR) + blacklist `cdc_ncm` | Medio | Borrar `.conf` + initramfs |
| F | Firewall | `firewalld` (recomendado) o `ufw`: deny in / allow out, sin puertos abiertos | Bajo | Deshabilitar servicio |
| G | Snapshots | `snapper` (Btrfs) o `timeshift` (rsync) + snapshot **"baseline"** | Bajo | Borrar snapshot |
| H | Resumen | Plantilla de cierre (NICs, Vulkan, virtualización, RAM, próximos pasos) | — | — |

## Notas de hardware específicas

- **RAM soldada vs ampliable:** el bloque 00 usa `dmidecode -t memory`. Si el *Form
  Factor* es `SODIMM` → ampliable (subir a 32 GB cambia el techo de IA+VMs). Si es
  `Row Of Chips`/`Unknown` sin slots libres → soldada (plan actual: 16 GB).
- **5GbE real:** el RTL8157 necesita **10000M** (USB 3.2 Gen2 / USB4) para negociar
  5000Mb/s. En un puerto de 5000M/480M el límite es **físico**: se cambia de puerto,
  no de driver.
- **SVM/AMD-V:** si el bloque 00 no ve `svm`, actívalo en BIOS (**SVM Mode**) antes de Fase 4.
- **Escritorio:** deliberadamente **no** se instala. La decisión de WM (recomendado
  Hyprland + Caelestia/Noctalia) es de Fase 2 y no afecta a esta fase.
