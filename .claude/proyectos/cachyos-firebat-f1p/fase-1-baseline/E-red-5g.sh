#!/usr/bin/env bash
# BLOQUE E — Validar el adaptador 5G (WAVLINK / RTL8157) y, SOLO si hace falta, arreglarlo.
# DIAGNÓSTICO PRIMERO. No toca nada del sistema salvo que tú confirmes cada paso.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos
start_log

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
have ethtool || warn "   ethtool no está (lo instala el bloque C): la velocidad se lee de sysfs y puede salir '?'."
found=0
for p in /sys/class/net/*; do
  # Solo interfaces cuyo dispositivo cuelga de un bus USB (sea cual sea su nombre: enx…, enp…u…, eth…).
  [[ "$(readlink -f "$p/device" 2>/dev/null)" == */usb* ]] || continue
  i="${p##*/}"; found=1
  if have ethtool; then
    drv=$(ethtool -i "$i" 2>/dev/null | awk -F': ' '/^driver/{print $2}')
    spd=$(ethtool  "$i" 2>/dev/null | awk -F': ' '/Speed/{print $2}')
  else
    drv=$(basename "$(readlink -e "$p/device/driver" 2>/dev/null)" 2>/dev/null)
    spd=$(cat "$p/speed" 2>/dev/null)
  fi
  printf '   %-16s driver=%-12s speed=%s\n' "$i" "${drv:-?}" "${spd:-?}"
done
(( found )) || warn "   No hay ninguna NIC USB en /sys/class/net. ¿Está enchufado el adaptador?"
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
  5) Regenerar initramfs para que el blacklist también aplique en el arranque.
Reversión COMPLETA (en este orden; el módulo DKMS de updates/dkms tiene prioridad
sobre el del kernel, así que borrar solo el .conf NO basta):
  sudo rm /etc/modprobe.d/r8152-realtek.conf
  paru -Rns r8152-dkms
  sudo mkinitcpio -P            (o: sudo dracut --regenerate-all --force)
  reiniciar   (dkms y los headers pueden quitarse con 'sudo pacman -Rns' si no se usan)
TXT

if confirm "¿El 5G aparece con cdc_ncm/cdc_ether y quieres aplicar el arreglo?"; then
  # 1) headers acordes al kernel en uso
  krel="$(uname -r)"
  hdr=""
  # Preferente: el paquete dueño del kernel en uso + "-headers" (cubre cachyos-lts, -bore, etc.).
  kpkg="$(pacman -Qoq "/usr/lib/modules/$krel/vmlinuz" 2>/dev/null)"
  [[ -n "$kpkg" ]] && hdr="${kpkg}-headers"
  [[ -n "$hdr" ]] || case "$krel" in
    *cachyos*) hdr="linux-cachyos-headers" ;;
    *lts*)     hdr="linux-lts-headers" ;;
    *zen*)     hdr="linux-zen-headers" ;;
    *)         hdr="linux-headers" ;;
  esac
  info "Kernel: $krel → headers: $hdr"
  if confirm "¿Instalar $hdr y dkms?"; then
    pac_install "$hdr" dkms
  else
    err "Sin headers no se puede compilar el módulo DKMS. Arreglo cancelado (no se tocó nada más)."
    exit 1
  fi

  # 2) r8152-dkms desde AUR
  if ! have paru; then
    err "paru no está; instálalo en el bloque C antes de continuar."
    exit 1
  fi
  if confirm "¿Instalar r8152-dkms desde AUR (paru)? Revisa el PKGBUILD cuando paru lo muestre."; then
    run paru -S --needed r8152-dkms
  else
    warn "Sin r8152-dkms no se aplica el blacklist (dejaría el adaptador sin driver). Fin del arreglo."
    exit 0
  fi
  # Un fallo del hook DKMS no cambia el código de salida de paru → se verifica el módulo instalado.
  kmod="$(modinfo -k "$krel" -n r8152 2>/dev/null)"
  if [[ "$kmod" != */updates/* ]]; then
    err "El módulo r8152 de DKMS no está instalado para $krel (modinfo: ${kmod:-no encontrado})."
    err "Revisa 'dkms status' y la salida de paru. NO se aplica el blacklist."
    exit 1
  fi
  ok "Módulo DKMS instalado: $kmod"

  # 3) blacklist de los módulos genéricos que capturan el chip
  if confirm "¿Crear blacklist de cdc_ncm/cdc_mbim en /etc/modprobe.d/r8152-realtek.conf?"; then
    printf 'blacklist cdc_ncm\nblacklist cdc_mbim\n' | sudo tee /etc/modprobe.d/r8152-realtek.conf >/dev/null \
      || { err "No se pudo escribir /etc/modprobe.d/r8152-realtek.conf."; exit 1; }
    ok "Blacklist creada. (Reversión completa: ver el texto del principio de este bloque.)"
    warn "cdc_ncm/cdc_mbim también los usan algunos módems USB; si usas tethering por USB, revisa antes."
    # 5) initramfs, para que el blacklist también aplique en el arranque
    if confirm "¿Regenerar initramfs ahora?"; then
      if have mkinitcpio; then run sudo mkinitcpio -P
      elif have dracut; then run sudo dracut --regenerate-all --force
      else warn "No encuentro mkinitcpio ni dracut: regenera el initramfs a mano."
      fi
    fi
  fi

  # 4) recargar
  if confirm "¿Recargar módulos ahora (si no, reinicia)?"; then
    # cdc_mbim depende de cdc_ncm → se descarga primero.
    sudo modprobe -r cdc_mbim cdc_ncm 2>/dev/null || true
    lsmod | grep -q '^cdc_ncm' && warn "cdc_ncm sigue cargado (algún dispositivo lo usa): reinicia para aplicar el cambio."
    # r8152 ya suele estar cargado (lo usan los RTL8156 2.5G): hay que recargarlo para que entre el de DKMS.
    if lsmod | grep -q '^r8152'; then
      warn "r8152 ya está cargado (lo usan también las NIC USB 2.5G): recargarlo CORTA su red unos segundos."
      if confirm "¿Recargar r8152 para cargar el módulo de DKMS?"; then
        run sudo modprobe -r r8152
      fi
    fi
    run sudo modprobe r8152
    # Comprobación: la versión cargada debe ser la del .ko de DKMS (updates/).
    if [[ "$(cat /sys/module/r8152/srcversion 2>/dev/null)" == "$(modinfo -k "$krel" -F srcversion r8152 2>/dev/null)" ]]; then
      ok "Cargado el r8152 de DKMS ($(modinfo -k "$krel" -n r8152 2>/dev/null))."
    else
      warn "El r8152 cargado NO es el de DKMS: reinicia para aplicarlo."
    fi
    warn "Desconecta y reconecta el adaptador 5G y repite el diagnóstico (parte 3)."
  fi
  info "Si tras reiniciar sigue en cdc_ncm, avísame y probamos un override por udev específico del ID."
fi
