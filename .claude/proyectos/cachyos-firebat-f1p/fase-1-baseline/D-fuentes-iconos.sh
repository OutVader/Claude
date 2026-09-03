#!/usr/bin/env bash
# BLOQUE D — Fuentes e iconos (base para la estética de Fase 2)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib/common.sh"
require_cachyos

section "BLOQUE D — Fuentes / iconos"
cat <<'TXT'
Paquetes:
  ttf-jetbrains-mono-nerd  Fuente monoespaciada con glifos Nerd Fonts (terminal, barras, prompts).
  noto-fonts               Cobertura Unicode amplia.
  noto-fonts-emoji         Emojis a color.
  noto-fonts-cjk           Chino/Japonés/Coreano (útil para la estética oriental de Fase 2).
  papirus-icon-theme       Set de iconos.

Riesgo: nulo. Solo añade recursos; no cambia el tema activo (eso es Fase 2).
TXT

PKGS=(ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk papirus-icon-theme)
if confirm "¿Instalar fuentes e iconos?"; then
  pac_install "${PKGS[@]}"
  have fc-cache && fc-cache -f >/dev/null 2>&1 || true
  ok "Fuentes e iconos instalados."
fi
