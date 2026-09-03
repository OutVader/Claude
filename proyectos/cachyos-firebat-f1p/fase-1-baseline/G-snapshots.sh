#!/usr/bin/env bash
# BLOQUE G — Snapshots + crear snapshot "baseline"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

section "BLOQUE G — Snapshots"
fs="$(findmnt -no FSTYPE / 2>/dev/null)"
info "Sistema de archivos de / : ${fs:-desconocido}"
cat <<'TXT'
Criterio:
  - Btrfs  → snapper (nativo, instantáneo, integrado con el bootloader). CachyOS suele
             configurarlo en la instalación (snapper + snap-pac + grub-btrfs/limine).
  - ext4/otros → timeshift en modo RSYNC.
Objetivo: dejar un snapshot llamado "baseline Fase 1" como punto de retorno seguro.
Riesgo: bajo (crear un snapshot no altera el sistema en uso).
TXT

if [[ "$fs" == "btrfs" ]]; then
  # ¿snapper ya instalado/configurado?
  if ! have snapper; then
    confirm "¿Instalar snapper + snap-pac (autosnapshots al usar pacman)?" && pac_install snapper snap-pac
  fi
  if have snapper; then
    if ! sudo snapper -c root list >/dev/null 2>&1; then
      warn "No hay config 'root' de snapper."
      confirm "¿Crear config snapper para / (create-config /)?" && sudo snapper -c root create-config /
    else
      ok "Config 'root' de snapper ya existe."
    fi
    if confirm "¿Crear snapshot 'baseline Fase 1' ahora?"; then
      sudo snapper -c root create -d "baseline Fase 1 - $(date +%F)"
      ok "Snapshot creado. Lista:"
      sudo snapper -c root list | tail -n 5
    fi
  fi
else
  info "Filesystem no-btrfs → usaremos timeshift (modo rsync)."
  if ! have timeshift; then
    confirm "¿Instalar timeshift?" && pac_install timeshift
  fi
  if have timeshift; then
    warn "timeshift en rsync guarda una copia; la primera es más lenta y ocupa espacio."
    if confirm "¿Crear snapshot 'baseline' con timeshift (modo rsync)?"; then
      sudo timeshift --create --comments "baseline Fase 1 - $(date +%F)" --tags D
      ok "Snapshot creado. Lista:"; sudo timeshift --list | tail -n 10
    fi
  fi
fi
