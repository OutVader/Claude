#!/usr/bin/env bash
# BLOQUE E — Validar el adaptador 5G (WAVLINK / RTL8157) y, SOLO si hace falta, arreglarlo.
# DIAGNÓSTICO PRIMERO. No toca nada del sistema salvo que tú confirmes cada paso.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

section "BLOQUE E — Diagnóstico del 5G (RTL8157)"
cat <<'TXT'
Contexto: el RTL8157 (5GbE) es reciente. Puede pasar una de estas:
  (a) El kernel lo asocia a 'r8152' y negocia bien → NO tocar nada.
  (b) Lo captura 'cdc_ncm'/'cdc_ether' (modo genérico) → rinde peor o negocia mal.
  (c) Está en un puerto lento (USB 2.0 / 5000M) → no llega a 5000Mb/s por límite físico.
Solución SOLO para el caso (b): r8152-dkms (AUR) + blacklist de cdc_ncm. Reversible.
El caso (c) se resuelve moviendo el adaptador a un puerto USB4/Gen2 (10000M), no con software.
TXT

info "1) ¿Está el chip presente? (0bda:8157)"
lsusb | grep -iE '0bda:8157|RTL8157' || warn "No veo el RTL8157 por lsusb. Enchúfalo y repite."
echo
info "2) Velocidad del puerto USB donde está (busca la rama del 0bda:8157):"
lsusb -t 2>/dev/null || true
warn "   Si esa rama dice 5000M o 480M, muévelo a un puerto de 10000M (USB4/Gen2) antes de nada."
echo
info "3) Driver y velocidad negociada de cada NIC USB:"
for i in $(ls /sys/class/net 2>/dev/null | grep -vE '^(lo|wl|virbr|docker|veth|tun|tap|enp[0-9])'); do
  drv=$(ethtool -i "$i" 2>/dev/null | awk -F': ' '/^driver/{print $2}')
  spd=$(ethtool  "$i" 2>/dev/null | awk -F': ' '/Speed/{print $2}')
  printf '   %-12s driver=%-12s speed=%s\n' "$i" "${drv:-?}" "${spd:-?}"
done
echo
info "Interpretación:"
info "  driver=r8152 y speed=5000Mb/s → PERFECTO, no hagas nada más en este bloque."
info "  driver=cdc_ncm/cdc_ether     → candidato al arreglo (abajo)."
info "  speed<5000 con r8152         → casi seguro puerto lento: cambia de puerto, no de driver."

# ---------------------------------------------------------------------------
section "Arreglo OPCIONAL (solo caso b): r8152-dkms + blacklist cdc_ncm"
cat <<'TXT'
NO ejecutes esto salvo que el diagnóstico muestre cdc_ncm/cdc_ether en el 5G.
Pasos (cada uno pide confirmación):
  1) Instalar headers del kernel en uso (necesarios para DKMS).
  2) Compilar r8152-dkms desde AUR (con paru).
  3) Blacklist de cdc_ncm/cdc_mbim para que no capturen el adaptador.
  4) Recargar módulos (o reiniciar) y volver a medir.
Reversible: borrar /etc/modprobe.d/r8152-realtek.conf y reconstruir initramfs.
TXT

if confirm "¿El 5G aparece con cdc_ncm/cdc_ether y quieres aplicar el arreglo?"; then
  # 1) headers acordes al kernel en uso
  krel="$(uname -r)"
  hdr=""
  case "$krel" in
    *cachyos*) hdr="linux-cachyos-headers" ;;
    *lts*)     hdr="linux-lts-headers" ;;
    *zen*)     hdr="linux-zen-headers" ;;
    *)         hdr="linux-headers" ;;
  esac
  info "Kernel: $krel → headers: $hdr"
  confirm "¿Instalar $hdr y dkms?" && pac_install "$hdr" dkms

  # 2) r8152-dkms desde AUR
  if have paru; then
    confirm "¿Instalar r8152-dkms desde AUR (paru)?" && paru -S --needed r8152-dkms
  else
    err "paru no está; instálalo en el bloque C antes de continuar."
  fi

  # 3) blacklist de los módulos genéricos que capturan el chip
  if confirm "¿Crear blacklist de cdc_ncm/cdc_mbim en /etc/modprobe.d/r8152-realtek.conf?"; then
    printf 'blacklist cdc_ncm\nblacklist cdc_mbim\n' | sudo tee /etc/modprobe.d/r8152-realtek.conf >/dev/null
    ok "Blacklist creada. (Para revertir: sudo rm /etc/modprobe.d/r8152-realtek.conf)"
    warn "cdc_ncm/cdc_mbim también los usan algunos módems USB; si usas tethering por USB, revisa antes."
  fi

  # 4) recargar
  if confirm "¿Recargar módulos ahora (si no, reinicia)?"; then
    sudo modprobe -r cdc_ncm cdc_mbim 2>/dev/null || true
    sudo modprobe r8152 2>/dev/null || true
    warn "Desconecta y reconecta el adaptador 5G, luego repite el diagnóstico (parte 3)."
  fi
  info "Si tras reiniciar sigue en cdc_ncm, avísame y probamos un override por udev específico del ID."
fi
