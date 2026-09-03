# Bloque H — Resumen de baseline (Fase 1F)

> Plantilla del informe de cierre. Rellénala (o pégame las salidas y la relleno yo)
> tras ejecutar los bloques A–G en el Firebat.

**Fecha:** `____-__-__`
**Kernel:** `uname -r → __________`
**Modo arranque:** `UEFI / BIOS` — **Bootloader:** `systemd-boot / GRUB / Limine`

## 1. Qué se instaló
- [ ] A — Mirrors reordenados + `pacman -Syu` (nº paquetes actualizados: ____)
- [ ] B — `amd-ucode mesa vulkan-radeon libva-mesa-driver libva-utils vulkan-tools radeontop`
- [ ] C — `git base-devel inxi btop fastfetch wget curl unzip openssh ethtool dmidecode` (+ paru: sí/no)
- [ ] D — `ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk papirus-icon-theme`
- [ ] F — Firewall: `firewalld / ufw` — activo: sí/no
- [ ] G — Snapshot baseline: `snapper / timeshift` — creado: sí/no

## 2. Estado de las 3 NICs
| NIC | Chip | ID USB | Driver | Velocidad negociada | Puerto | OK |
|---|---|---|---|---|---|---|
| 2.5G integrada | (r8169?) | — | | | PCIe | |
| UGREEN 2.5G | RTL8156BG | 0bda:8156 | | | USB | |
| Genérico 2.5G | RTL8156B | 0bda:8156 | | | USB | |
| WAVLINK 5G | RTL8157 | 0bda:8157 | | | USB4/Gen2 | |

Objetivo: RTL815x con driver `r8152`; el 5G a `5000Mb/s` en puerto de 10000M.

## 3. Vulkan (resumen `vulkaninfo --summary`)
```
deviceName = __________ (Radeon 780M / RADV)
driverName = radv
apiVersion = __________
```
VAAPI (`vainfo`): decodificadores disponibles sí/no.

## 4. Virtualización
- SVM (AMD-V) en CPU: **sí / no**  (grep svm /proc/cpuinfo)
- `/dev/kvm` presente: **sí / no**
- Módulo `kvm_amd` cargado: **sí / no**
- **Listo para KVM/QEMU:** sí / no (grupos kvm/libvirt → se configuran en Fase 4)

## 5. RAM
- Form factor: **SODIMM (ampliable) / soldada** — Máximo: ____ GB — Slots libres: ____
- Decisión: mantener 16 GB / ampliar a 32 GB

## 6. Próximos pasos
- **Fase 2 (escritorio):** confirmar WM (recomendado Hyprland + Caelestia/Noctalia) →
  estética oriental, fondos, paleta dinámica.
- **Fase 4 (laboratorio):** virt-manager + KVM/QEMU, contenedores (Docker/Podman),
  redes segmentadas con la 2.5G integrada + UGREEN 2.5G; 5G para futuro switch.
