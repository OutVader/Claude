#!/usr/bin/env bash
# BLOQUE F — Firewall con reglas sensatas para una estación de trabajo
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

section "BLOQUE F — Firewall"
cat <<'TXT'
Elige motor:
  1) firewalld  → RECOMENDADO aquí. Se integra bien con libvirt/NetworkManager (Fase 4,
                  laboratorios y redes segmentadas). Manejo por "zonas".
  2) ufw        → Más simple. Bien para un equipo que solo consume red.

Política base en ambos: DENEGAR entrante, PERMITIR saliente. No abrimos ningún puerto
(SSH incluido) hasta que lo decidas. Riesgo: bajo; no dejamos servicios expuestos.
TXT

printf '%sElige [1=firewalld / 2=ufw / q=cancelar]:%s ' "${C_YELLOW}${C_BOLD}" "$C_RESET"
read -r choice || exit 1

case "$choice" in
  1)
    if confirm "¿Instalar y activar firewalld con política por defecto (deny in / allow out)?"; then
      pac_install firewalld
      # Evita conflicto: si ufw estuviera activo, avisar.
      systemctl is-enabled ufw >/dev/null 2>&1 && warn "ufw está habilitado; deshabilítalo para no chocar con firewalld."
      sudo systemctl enable --now firewalld
      # Zona por defecto 'public' bloquea entrante salvo lo permitido explícitamente.
      sudo firewall-cmd --set-default-zone=public
      ok "firewalld activo. Zona por defecto: public (entrante bloqueado)."
      info "Estado:"; sudo firewall-cmd --list-all
      info "Para permitir SSH en el futuro: sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload"
    fi
    ;;
  2)
    if confirm "¿Instalar y activar ufw (deny in / allow out)?"; then
      pac_install ufw
      systemctl is-enabled firewalld >/dev/null 2>&1 && warn "firewalld está habilitado; deshabilítalo para no chocar con ufw."
      sudo systemctl enable --now ufw
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw --force enable
      ok "ufw activo (deny incoming / allow outgoing)."
      info "Estado:"; sudo ufw status verbose
      info "Para permitir SSH en el futuro: sudo ufw limit ssh"
    fi
    ;;
  *) warn "Cancelado. No se tocó el firewall." ;;
esac
