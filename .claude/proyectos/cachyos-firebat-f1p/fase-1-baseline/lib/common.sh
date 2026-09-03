#!/usr/bin/env bash
# common.sh — helpers compartidos del playbook de baseline (CachyOS / Firebat F1 P)
# Se importa desde cada script:  source "$DIR/lib/common.sh"
#
# Filosofía: nada destructivo se ejecuta sin confirmación explícita del usuario.

set -uo pipefail

# --- Colores (solo si la salida es una terminal) ------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_BLUE=$'\e[34m'
  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'
else
  C_RESET=""; C_BOLD=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

section() { printf '\n%s══ %s ══%s\n' "${C_BOLD}${C_BLUE}" "$*" "$C_RESET"; }
info()    { printf '%s»%s %s\n'  "$C_BLUE"   "$C_RESET" "$*"; }
ok()      { printf '%s✔%s %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
warn()    { printf '%s!%s %s\n'  "$C_YELLOW" "$C_RESET" "$*"; }
err()     { printf '%s✗%s %s\n'  "$C_RED"    "$C_RESET" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Confirmación explícita antes de modificar el sistema. Devuelve 0 solo si s/S/y/Y.
confirm() {
  local prompt="${1:-¿Continuar?}" ans
  printf '%s%s [s/N]:%s ' "${C_YELLOW}${C_BOLD}" "$prompt" "$C_RESET"
  read -r ans || return 1
  [[ "$ans" =~ ^[sSyY]$ ]]
}

# Aborta si no estamos en un sistema Arch/CachyOS.
require_cachyos() {
  if ! have pacman; then
    err "Esto no parece Arch/CachyOS (no hay 'pacman'). Ejecuta el playbook EN el Firebat."
    exit 1
  fi
}

# Instala paquetes de repos oficiales de forma idempotente (--needed no reinstala).
pac_install() {
  info "Paquetes: $*"
  sudo pacman -S --needed "$@"
}
