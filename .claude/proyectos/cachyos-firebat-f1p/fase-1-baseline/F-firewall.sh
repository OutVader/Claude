#!/usr/bin/env bash
# BLOQUE F — Firewall con reglas sensatas para una estación de trabajo
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos
start_log

section "BLOQUE F — Firewall"
cat <<'TXT'
Elige motor:
  1) firewalld  → RECOMENDADO aquí. Se integra bien con libvirt/NetworkManager (Fase 4,
                  laboratorios y redes segmentadas). Manejo por "zonas".
  2) ufw        → Más simple. Bien para un equipo que solo consume red.

Política base en ambos: DENEGAR entrante, PERMITIR saliente. No abrimos ningún puerto
(SSH incluido) hasta que lo decidas. En firewalld se QUITA 'ssh' de la zona public, que
lo trae permitido de serie; solo queda 'dhcpv6-client' (necesario para IPv6 por DHCP).
Solo puede haber UN firewall: si el otro está activo, se pide desactivarlo o se cancela.
Riesgo: bajo; no dejamos servicios expuestos.
TXT

# Garantiza un único firewall: si $1 está habilitado o activo, lo desactiva (con OK) o aborta.
# Se llama DESPUÉS de instalar el nuevo, para no quedarse sin firewall si pacman falla.
PREV_FW=""
ensure_off() {
  local other="$1"
  if systemctl is-enabled "$other" >/dev/null 2>&1 || systemctl is-active "$other" >/dev/null 2>&1; then
    warn "$other está habilitado o activo: dos firewalls a la vez chocan entre sí."
    if confirm "¿Deshabilitar y parar $other antes de seguir?"; then
      [[ "$other" == "ufw" ]] && have ufw && run sudo ufw disable
      run sudo systemctl disable --now "$other"
      PREV_FW="$other"
      ok "$other deshabilitado."
    else
      err "Cancelado: no se activa un segundo firewall con $other activo."
      exit 1
    fi
  fi
}

# Activa el firewall nuevo; si falla, dice cómo reactivar el anterior (no quedarse sin firewall).
enable_fw() {
  local fw="$1"
  if ! sudo systemctl enable --now "$fw"; then
    err "No se pudo activar $fw."
    if [[ -n "$PREV_FW" ]]; then
      err "Reactiva el anterior YA: sudo systemctl enable --now $PREV_FW$([[ $PREV_FW == ufw ]] && echo ' && sudo ufw --force enable')"
    fi
    exit 1
  fi
}

printf '%sElige [1=firewalld / 2=ufw / q=cancelar]:%s ' "${C_YELLOW}${C_BOLD}" "$C_RESET"
read -r choice || exit 1

case "$choice" in
  1)
    if confirm "¿Instalar y activar firewalld con política por defecto (deny in / allow out)?"; then
      pac_install firewalld
      ensure_off ufw
      enable_fw firewalld
      # Zona por defecto 'public': bloquea entrante salvo los servicios listados.
      run sudo firewall-cmd --set-default-zone=public
      # 'public' trae ssh permitido de serie → se quita (idempotente: si no está, solo avisa).
      run sudo firewall-cmd --permanent --zone=public --remove-service=ssh
      run sudo firewall-cmd --reload
      ok "firewalld activo. Zona public sin ssh (entrante bloqueado salvo dhcpv6-client)."
      info "Estado:"; sudo firewall-cmd --list-all
      info "Zonas activas (si alguna interfaz no está en 'public', revisa sus servicios):"
      sudo firewall-cmd --get-active-zones
      info "Para permitir SSH en el futuro: sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload"
    fi
    ;;
  2)
    if confirm "¿Instalar y activar ufw (deny in / allow out)?"; then
      pac_install ufw
      ensure_off firewalld
      enable_fw ufw
      run sudo ufw default deny incoming
      run sudo ufw default allow outgoing
      run sudo ufw --force enable
      ok "ufw activo (deny incoming / allow outgoing)."
      info "Estado:"; sudo ufw status verbose
      info "Para permitir SSH en el futuro: sudo ufw limit ssh"
    fi
    ;;
  *) warn "Cancelado. No se tocó el firewall." ;;
esac
