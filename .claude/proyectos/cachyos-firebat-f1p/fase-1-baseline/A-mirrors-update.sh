#!/usr/bin/env bash
# BLOQUE A — Mirrors óptimos + actualización completa del sistema
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

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
TXT

if have cachyos-rate-mirrors; then
  confirm "¿Optimizar mirrors con cachyos-rate-mirrors?" && sudo cachyos-rate-mirrors
else
  warn "cachyos-rate-mirrors no encontrado; se omite el reordenado (no es bloqueante)."
fi

if confirm "¿Ejecutar 'sudo pacman -Syu' (actualización completa)?"; then
  sudo pacman -Syu
  ok "Sistema actualizado."
  if pacman -Q linux-cachyos linux linux-lts 2>/dev/null | grep -q .; then
    warn "Si se actualizó el kernel, REINICIA antes de continuar (módulos vs kernel en uso)."
  fi
fi
