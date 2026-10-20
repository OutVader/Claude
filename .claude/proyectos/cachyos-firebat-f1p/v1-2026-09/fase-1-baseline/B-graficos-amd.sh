#!/usr/bin/env bash
# BLOQUE B — Pila gráfica AMD (Radeon 780M / RDNA3) + Vulkan
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

section "BLOQUE B — Gráficos AMD + Vulkan"
cat <<'TXT'
Paquetes y para qué sirven:
  amd-ucode          Microcódigo de CPU AMD (correcciones/seguridad; lo carga el bootloader).
  mesa               Drivers OpenGL/Vulkan open source (base de la 780M).
  vulkan-radeon      ICD Vulkan RADV para GPUs AMD → necesario para IA por Vulkan (Fase 3).
  libva-mesa-driver  Aceleración de vídeo VAAPI (decodificación por hardware).
  libva-utils        'vainfo' para comprobar VAAPI.
  vulkan-tools       'vulkaninfo' y 'vkcube' para validar Vulkan.
  radeontop          Monitor de uso de la iGPU.

Nota: en CachyOS gran parte ya viene instalada; --needed no reinstala lo que exista.
Riesgo: bajo.
TXT

PKGS=(amd-ucode mesa vulkan-radeon libva-mesa-driver libva-utils vulkan-tools radeontop)
if confirm "¿Instalar la pila gráfica AMD (${#PKGS[@]} paquetes)?"; then
  pac_install "${PKGS[@]}"
  echo
  if have vulkaninfo; then
    section "Comprobación Vulkan (resumen)"
    vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName|apiVersion|GPU id' || \
      vulkaninfo 2>/dev/null | grep -E 'deviceName|driverName|apiVersion' | head
  fi
  if have vainfo; then
    section "Comprobación VAAPI"
    vainfo 2>/dev/null | grep -E 'Driver version|VAProfile' | head
  fi
  ok "Pila gráfica lista. Recuerda: NO instalamos escritorio (eso es Fase 2)."
fi
