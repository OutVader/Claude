#!/usr/bin/env bash
# BLOQUE A — Mirrors óptimos + actualización completa del sistema
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos
start_log

section "BLOQUE A — Mirrors + pacman -Syu"
cat <<'TXT'
Qué hace y por qué:
  1) cachyos-rate-mirrors → mide y reordena los mirrors de CachyOS y de Arch por
     velocidad/latencia. Mejora la velocidad de descarga de todo lo que sigue.
  2) pacman -Syu → ACTUALIZACIÓN COMPLETA. En Arch/CachyOS es obligatoria y de una
     sola pieza: los "upgrades parciales" (-Sy paquete suelto) no están soportados
     y pueden romper el sistema. Por eso se sincroniza y actualiza TODO junto.

Riesgo: bajo (operación estándar). Requiere red estable. Si actualiza el kernel,
conviene REINICIAR antes de seguir con los demás bloques.

Reversión:
  - Mirrors: antes de tocarlos se guarda copia en /etc/pacman.d/<lista>.bak-<fecha_hora>;
    para volver: sudo cp -a <copia> /etc/pacman.d/<lista>
  - -Syu: arrancar el snapshot "baseline Fase 1" desde el menú de Limine/GRUB y
    restaurar (comandos exactos en el README, sección «Reversión»), o con timeshift
    'sudo timeshift --restore --snapshot <nombre>'. Un paquete suelto:
    'sudo pacman -U /var/cache/pacman/pkg/<paquete-versión>.pkg.tar.zst'.
TXT

if have cachyos-rate-mirrors; then
  if confirm "¿Optimizar mirrors con cachyos-rate-mirrors?"; then
    ts="$(date +%F_%H%M%S)"
    for ml in /etc/pacman.d/mirrorlist /etc/pacman.d/cachyos-mirrorlist; do
      [[ -f "$ml" ]] && run sudo cp -a "$ml" "$ml.bak-$ts" && info "Copia: $ml.bak-$ts"
    done
    run sudo cachyos-rate-mirrors
  fi
else
  warn "cachyos-rate-mirrors no encontrado; se omite el reordenado (no es bloqueante)."
fi

# Punto de retorno antes del -Syu (la acción más arriesgada de la fase).
if [[ "$(findmnt -no FSTYPE / 2>/dev/null)" == "btrfs" ]] && have snapper; then
  if ! sudo snapper -c root list 2>/dev/null | grep -q 'baseline Fase 1'; then
    warn "No hay snapshot 'baseline Fase 1': no habría punto de retorno antes del -Syu."
    warn "Recomendado: ejecuta antes 'bash G-snapshots.sh'."
    confirm "¿Seguir de todos modos sin snapshot baseline?" || { warn "Cancelado. Ejecuta el bloque G y vuelve."; exit 0; }
  fi
elif have timeshift; then
  if ! sudo timeshift --list 2>/dev/null | grep -q 'baseline Fase 1'; then
    warn "No hay snapshot timeshift 'baseline Fase 1': no habría punto de retorno antes del -Syu."
    warn "Recomendado: ejecuta antes 'bash G-snapshots.sh'."
    confirm "¿Seguir de todos modos sin snapshot baseline?" || { warn "Cancelado. Ejecuta el bloque G y vuelve."; exit 0; }
  fi
else
  warn "No hay snapper ni timeshift: no habría punto de retorno antes del -Syu (solo 'pacman -U' desde la caché)."
  warn "Recomendado: ejecuta antes 'bash G-snapshots.sh'."
  confirm "¿Seguir de todos modos sin snapshot?" || { warn "Cancelado. Ejecuta el bloque G y vuelve."; exit 0; }
fi

if confirm "¿Ejecutar 'sudo pacman -Syu' (actualización completa)?"; then
  run sudo pacman -Syu
  ok "Sistema actualizado."
  # Si el kernel en uso se actualizó, sus módulos ya no están instalados → hay que reiniciar.
  if [[ -d "/usr/lib/modules/$(uname -r)" ]]; then
    ok "El kernel en uso ($(uname -r)) sigue instalado: no hace falta reiniciar."
  else
    warn "El kernel en uso ($(uname -r)) se ha actualizado: REINICIA antes de seguir con otros bloques."
  fi
fi
