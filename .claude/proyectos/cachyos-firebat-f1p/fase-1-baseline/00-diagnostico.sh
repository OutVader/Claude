#!/usr/bin/env bash
# 00-diagnostico.sh — SOLO LECTURA. No instala ni modifica nada.
# Recoge hardware, virtualización y estado de red para revisarlos ANTES de tocar el sistema.
# Ejecuta:  bash 00-diagnostico.sh 2>&1 | tee ../salidas/diagnostico-$(date +%F).txt
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

# ============================================================================
section "1) HARDWARE"
# ============================================================================
if have inxi; then
  inxi -Fzx
else
  warn "inxi no instalado todavía (se instala en el bloque C). Muestro alternativas nativas:"
fi
echo
info "CPU (lscpu):"
lscpu | grep -E 'Model name|Socket|Core|Thread|^CPU\(s\)|Virtualization|Flags' || true

section "RAM — ¿soldada o ampliable? (dmidecode, requiere sudo)"
if have dmidecode; then
  sudo dmidecode -t memory | grep -E 'Maximum Capacity|Number Of Devices|Form Factor|Locator:|^\s+Size:|^\s+Type:|Speed:' || true
  echo
  info "Lectura: Form Factor 'SODIMM' ⇒ ampliable. 'Row Of Chips'/'Other'/'Unknown' con"
  info "'Number Of Devices' bajo y sin locators vacíos ⇒ probablemente soldada."
else
  warn "dmidecode no disponible. Instálalo con: sudo pacman -S --needed dmidecode  (o corre el bloque C)"
fi

section "Discos / NVMe / slots"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL || true
echo
info "Slots físicos M.2 (para confirmar el 2º libre):"
if have dmidecode; then sudo dmidecode -t slot 2>/dev/null | grep -E 'Designation|Type|Current Usage' || true; fi

section "Kernel / modo de arranque / bootloader"
info "Kernel: $(uname -r)"
if [[ -d /sys/firmware/efi ]]; then ok "Arranque en modo UEFI"; else warn "Arranque en modo BIOS/Legacy"; fi
if have bootctl && bootctl status >/dev/null 2>&1; then
  ok "Bootloader: systemd-boot"
elif [[ -f /boot/grub/grub.cfg ]]; then ok "Bootloader: GRUB"
elif [[ -f /boot/limine.conf || -f /boot/limine/limine.conf || -d /boot/EFI/limine ]]; then ok "Bootloader: Limine"
else warn "Bootloader no identificado automáticamente; revisar /boot"; fi

# ============================================================================
section "2) VIRTUALIZACIÓN (AMD-V / SVM)"
# ============================================================================
if grep -qw svm /proc/cpuinfo; then
  ok "SVM (AMD-V) ACTIVO en la CPU → virtualización por hardware disponible"
else
  err "SVM NO detectado → activa 'SVM Mode' en la BIOS (Advanced/CPU) para KVM/QEMU"
fi
info "Módulos KVM cargados:"
lsmod | grep -E '^kvm' || warn "kvm no cargado (normal si SVM está off o el módulo aún no se cargó)"
if [[ -e /dev/kvm ]]; then ok "/dev/kvm presente"; ls -l /dev/kvm; else warn "/dev/kvm ausente"; fi
info "Grupos del usuario (kvm/libvirt se configuran en Fase 4):"
id -nG | tr ' ' '\n' | grep -E 'kvm|libvirt' || warn "Usuario aún no está en kvm/libvirt (OK por ahora)"

# ============================================================================
section "3) RED — interfaces y adaptadores USB"
# ============================================================================
info "Interfaces (estado breve):"
ip -br link
echo
info "Chips RealTek USB esperados: UGREEN=0bda:8156 (RTL8156BG), genérico=0bda:8156 (RTL8156B), WAVLINK=0bda:8157 (RTL8157):"
lsusb | grep -iE '0bda:81(56|57)|realtek' || warn "No se detectan RTL815x por lsusb (¿están enchufados?)"
echo
info "Árbol USB — la velocidad del puerto donde va cada adaptador (clave para el 5G):"
lsusb -t 2>/dev/null || warn "lsusb -t no disponible"
info "  El RTL8157 (5G) necesita un puerto de 10000M (USB 3.2 Gen2 / USB4) para negociar 5000Mb/s."
echo
info "Driver + velocidad negociada por interfaz ethernet:"
for i in $(ls /sys/class/net 2>/dev/null | grep -vE '^(lo|wl|virbr|docker|veth|tun|tap)'); do
  drv="?"; spd="?"
  if have ethtool; then
    drv=$(ethtool -i "$i" 2>/dev/null | awk -F': ' '/^driver/{print $2}')
    spd=$(ethtool  "$i" 2>/dev/null | awk -F': ' '/Speed/{print $2}')
  else
    drv=$(basename "$(readlink -f "/sys/class/net/$i/device/driver" 2>/dev/null)" 2>/dev/null)
  fi
  printf '  %-12s driver=%-12s speed=%s\n' "$i" "${drv:-?}" "${spd:-?}"
done
info "Objetivo: los RTL815x deben usar driver 'r8152' (NO 'cdc_ncm'/'cdc_ether')."
echo
ok "Diagnóstico terminado. Pega esta salida en el chat para revisarla antes de los bloques A–H."
