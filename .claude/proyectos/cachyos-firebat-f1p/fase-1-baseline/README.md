# Fase 1F — Baseline + validación (CachyOS / Firebat F1 P)

> Playbook **WM-agnóstico**: solo baseline y validación. **No** instala escritorio/WM ni
> modelos de IA (eso es Fase 2 y Fase 3). Cada bloque que modifica el sistema **pide
> confirmación** y es **idempotente** (`--needed` no reinstala lo ya presente).

## Requisitos
- CachyOS instalado, usuario con `sudo` y red estable.
- Ejecutar con `bash` **desde esta carpeta** del repo clonado (usa `lib/common.sh`).
- El 00 corre **antes** que el bloque C: si faltan `inxi`, `ethtool` o `dmidecode`, el
  diagnóstico saldrá incompleto. Repítelo tras el C.
- Antes de pegar salidas en un chat, ten en cuenta que incluyen **MACs** (`ip -br link`)
  y datos de hardware. Recórtalos si no quieres compartirlos.

## Cómo se usa (en el Firebat, no en la nube)

Esta carpeta es un **cuaderno de ejecución**. Los scripts corren **en tu CachyOS**,
no en la sesión de Claude en la nube (que no toca tu hardware). Orden recomendado:

```bash
cd fase-1-baseline

# 0) DIAGNÓSTICO (solo lectura). Pega la salida en el chat antes de seguir.
bash 00-diagnostico.sh

# Luego, bloque a bloque, revisando cada uno.
# G va PRIMERO: crea el punto de retorno "baseline" antes de tocar nada.
bash G-snapshots.sh
bash A-mirrors-update.sh
bash B-graficos-amd.sh
bash C-base.sh
bash D-fuentes-iconos.sh
bash E-red-5g.sh        # diagnóstico primero; arreglo solo si hace falta
bash F-firewall.sh
```

Al terminar, rellena `H-resumen.md` (o pégame las salidas y lo cierro yo).

**Registro y errores:**
- Cada script guarda su salida en `salidas/<bloque>-<fecha_hora>.log`. La carpeta
  `salidas/` está en `.gitignore` porque puede contener números de serie y MACs. Para
  desactivar el log: `NO_LOG=1 bash <script>.sh`. Con log, pacman no muestra las barras
  de progreso.
- Si una acción falla (pacman, systemctl, firewall-cmd…), el bloque **se detiene** con el
  error, en lugar de seguir y dar un "ok" falso.

> **G antes que A**: así hay punto de retorno antes del `-Syu`. El bloque A busca el
> snapshot "baseline Fase 1" (snapper o timeshift) y, si no lo encuentra, pide
> confirmación para seguir sin él.

## Qué hace cada bloque (y por qué)

| # | Bloque | Acción | Riesgo | Reversible |
|---|--------|--------|--------|------------|
| 00 | Diagnóstico | `inxi`, RAM (`dmidecode`), discos, UEFI/bootloader, SVM/KVM, NICs (chip/driver/velocidad) | **Ninguno** (solo lectura) | — |
| A | Mirrors + update | `cachyos-rate-mirrors` (con copia `.bak` previa) + `pacman -Syu` (update completo, nunca parcial) | Bajo | Ver «Reversión» |
| B | Gráficos AMD | `amd-ucode mesa vulkan-radeon libva-mesa-driver libva-utils vulkan-tools radeontop` | Bajo | Ver «Reversión» |
| C | Base | `git base-devel inxi btop fastfetch wget curl unzip openssh ethtool dmidecode` (+ `paru` si falta). SSH **no** se activa | Bajo | Ver «Reversión» |
| D | Fuentes/iconos | `ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk papirus-icon-theme` | Nulo | Ver «Reversión» |
| E | Red 5G (RTL8157) | Diagnóstico; **solo si** cae en `cdc_ncm`: `r8152-dkms` (AUR) + blacklist `cdc_ncm` | Medio | Ver «Reversión» |
| F | Firewall | `firewalld` (recomendado) o `ufw`: deny in / allow out, sin puertos abiertos (en firewalld se quita `ssh` de la zona public). Un solo firewall: el otro se desactiva con OK o se cancela | Bajo | Ver «Reversión» |
| G | Snapshots | `snapper` (Btrfs) o `timeshift` (rsync) + snapshot **"baseline"** | Bajo | Ver «Reversión» |
| H | Resumen | Plantilla de cierre (NICs, Vulkan, virtualización, RAM, próximos pasos) | — | — |

## Reversión (comandos exactos)

| Bloque | Cómo deshacer |
|---|---|
| A · mirrors | `sudo cp -a /etc/pacman.d/<lista>.bak-<fecha_hora> /etc/pacman.d/<lista>` (copia creada por el bloque) |
| A · `-Syu` | **snapper:** ver abajo «Reversión · restaurar / con snapper». **timeshift:** `sudo timeshift --list` y después `sudo timeshift --restore --snapshot '<nombre>'`. **Un paquete suelto:** `sudo pacman -U /var/cache/pacman/pkg/<paquete-versión>.pkg.tar.zst` |
| B · C · D | Quita **solo lo que instaló el bloque**, nunca `mesa`/`amd-ucode` si ya estaban: `grep "\[ALPM\] installed" /var/log/pacman.log \| tail -n 30` para ver qué entró hoy y después `sudo pacman -Rns <solo esos paquetes>` |
| E | `sudo rm /etc/modprobe.d/r8152-realtek.conf && paru -Rns r8152-dkms && sudo mkinitcpio -P` (o `sudo dracut --regenerate-all --force`) y reiniciar. `dkms` y los headers, con `sudo pacman -Rns` si no se usan |
| F · firewalld | `sudo systemctl disable --now firewalld`. Solo si de verdad quieres volver a permitir SSH: `sudo firewall-cmd --permanent --zone=public --add-service=ssh && sudo firewall-cmd --reload` |
| F · ufw | `sudo ufw disable && sudo systemctl disable --now ufw` |
| F · el otro firewall | Si `ensure_off` desactivó el que había: `sudo systemctl enable --now <ufw\|firewalld>` (y `sudo ufw enable` en el caso de ufw) |
| G | snapper: `sudo snapper -c root list` y después `sudo snapper -c root delete <N>`. timeshift: `sudo timeshift --delete --snapshot '<nombre>'` |

### Reversión · restaurar `/` con snapper (desde un USB live de CachyOS)
`snapper rollback` a secas **no** basta con la disposición `subvol=` de CachyOS. Si tienes
`limine-snapper-sync` o `grub-btrfs` (el bloque G lo comprueba), puedes arrancar antes el
snapshot desde el menú para comprobar que es el bueno. La restauración:
```bash
lsblk -f                                         # identifica la partición Btrfs raíz y la ESP
sudo mount -o subvolid=5 /dev/<raíz> /mnt        # nivel superior del Btrfs
sudo btrfs subvolume list /mnt | grep -i snapshot  # localiza la ruta del snapshot N "baseline Fase 1"
#   (p. ej. @/.snapshots/N/snapshot  o  @snapshots/N/snapshot)
sudo mv /mnt/@ /mnt/@.roto                      # aparta la raíz actual (no se borra)
#   si el snapshot estaba DENTRO de @, su ruta pasa a ser @.roto/.snapshots/N/snapshot
sudo btrfs subvolume snapshot /mnt/<ruta-del-snapshot-N> /mnt/@
sudo umount /mnt
# El kernel de la ESP NO va en el snapshot: hay que reinstalar el de la versión restaurada.
sudo mount -o subvol=@ /dev/<raíz> /mnt && sudo mount /dev/<esp> /mnt/boot   # (o /mnt/efi, según tu fstab)
sudo arch-chroot /mnt pacman -S <paquete-kernel>   # p. ej. linux-cachyos; también regenera el initramfs
sudo umount -R /mnt && reboot
# Cuando arranque bien: monta subvolid=5 y borra @.roto con 'btrfs subvolume delete'
#   (antes mueve fuera los snapshots anidados que quieras conservar).
```

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
