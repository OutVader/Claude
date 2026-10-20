#!/usr/bin/env bash
# BLOQUE C — Herramientas base del sistema
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

section "BLOQUE C — Base"
cat <<'TXT'
Paquetes:
  git base-devel     Compilación y control de versiones (base-devel es necesario para AUR).
  inxi               Informe de hardware (usado en el diagnóstico).
  btop               Monitor de recursos (CPU/RAM/GPU/red).
  fastfetch          Resumen del sistema.
  wget curl          Descargas.
  unzip              Descompresión.
  openssh            Cliente + servidor SSH. OJO: instala el servicio pero NO lo activa.
  ethtool            Diagnóstico de NICs (velocidad/driver) — clave para el bloque E.
  dmidecode          Lectura de RAM/slots (soldada vs ampliable).

paru: CachyOS ya suele traer 'paru' (ayudante de AUR). Si falta, se instala aparte.
Riesgo: bajo. SSH server queda INACTIVO por seguridad (se decide más adelante).
TXT

PKGS=(git base-devel inxi btop fastfetch wget curl unzip openssh ethtool dmidecode)
if confirm "¿Instalar herramientas base?"; then
  pac_install "${PKGS[@]}"
  if have paru; then
    ok "paru ya presente ($(paru --version 2>/dev/null | head -1))."
  else
    warn "paru no está. En CachyOS suele venir de fábrica."
    confirm "¿Instalar 'paru' (ayudante de AUR) desde repos de CachyOS?" && pac_install paru
  fi
  warn "openssh instalado pero NO activado. Para exponer SSH habría que: claves + firewall + 'systemctl enable --now sshd' (decisión consciente, no ahora)."
  ok "Base instalada."
fi
