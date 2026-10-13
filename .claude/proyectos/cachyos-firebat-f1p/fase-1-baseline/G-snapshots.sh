#!/usr/bin/env bash
# BLOQUE G — Snapshots + crear snapshot "baseline"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos
start_log

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
    # ¿Saldrán los snapshots en el menú de arranque? Solo con estas integraciones.
    if pacman -Q limine-snapper-sync >/dev/null 2>&1 || pacman -Q grub-btrfs >/dev/null 2>&1; then
      ok "Integración de snapshots en el menú de arranque presente (limine-snapper-sync / grub-btrfs)."
    else
      warn "Sin limine-snapper-sync ni grub-btrfs: los snapshots NO saldrán en el menú de arranque."
      warn "La restauración se haría desde un USB live (README › «Reversión · restaurar / con snapper»)."
    fi
    if ! sudo snapper -c root list >/dev/null 2>&1; then
      warn "No hay config 'root' de snapper."
      if [[ -e /.snapshots ]]; then
        # Instalaciones con subvolumen @snapshots: create-config falla si /.snapshots ya existe.
        warn "/.snapshots ya existe (subvolumen @snapshots): 'create-config /' fallaría."
        warn "Configúralo a mano siguiendo la Arch Wiki (Snapper › Configuración de subvolumen @snapshots) y repite este bloque."
        exit 1
      fi
      if confirm "¿Crear config snapper para / (create-config /)?"; then
        run sudo snapper -c root create-config /
      else
        warn "Sin config 'root' no se puede crear el snapshot. Fin del bloque."
        exit 0
      fi
    else
      ok "Config 'root' de snapper ya existe."
    fi
    snaps="$(sudo snapper -c root list 2>/dev/null)"
    [[ "$snaps" == *"baseline Fase 1"* ]] && warn "Ya existe un snapshot 'baseline Fase 1'; crear otro es opcional."
    if confirm "¿Crear snapshot 'baseline Fase 1' ahora?"; then
      run sudo snapper -c root create -d "baseline Fase 1 - $(date +%F)"
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
    info "Si falla por el dispositivo de destino: 'sudo timeshift --list-devices' y añade --snapshot-device /dev/XXX."
    if confirm "¿Crear snapshot 'baseline' con timeshift (modo rsync)?"; then
      run sudo timeshift --create --comments "baseline Fase 1 - $(date +%F)" --tags D
      ok "Snapshot creado. Lista:"; sudo timeshift --list | tail -n 10
    fi
  fi
fi
