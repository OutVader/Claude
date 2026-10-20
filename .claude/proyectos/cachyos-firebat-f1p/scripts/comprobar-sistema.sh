#!/usr/bin/env bash
# comprobar-sistema.sh — Fase 1 · comprobaciones tras instalar/actualizar. SOLO LECTURA.
# No instala ni modifica nada y no necesita sudo (Snapper puede pedirlo para listar).
# Uso: bash comprobar-sistema.sh [--ruta A|B|C|D] [--pacman-conf FICHERO]
#   --ruta A  = Omarchy ISO oficial (no lleva repos de CachyOS); B/C/D = base CachyOS (por defecto).
# Salida: 0 = sin fallos · 1 = hay FALLOS · 2 = entorno no válido o uso incorrecto.
set -uo pipefail

RUTA=D
PACMAN_CONF=/etc/pacman.conf
MKINIT_DIR=/etc/mkinitcpio.conf.d

uso() { echo "Uso: $0 [--ruta A|B|C|D] [--pacman-conf FICHERO]" >&2; exit 2; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ruta)        [[ $# -ge 2 ]] || uso; RUTA="${2^^}"; shift 2 ;;
    --pacman-conf) [[ $# -ge 2 ]] || uso; PACMAN_CONF="$2"; shift 2 ;;
    -h|--help)     sed -n '2,7p' "$0"; exit 0 ;;
    *)             echo "Opción desconocida: $1" >&2; uso ;;
  esac
done
[[ "$RUTA" =~ ^[ABCD]$ ]] || { echo "Ruta no válida: $RUTA" >&2; uso; }

fallos=0; avisos=0
bien()  { printf '[BIEN]  %s\n' "$*"; }
aviso() { printf '[AVISO] %s\n' "$*"; avisos=$((avisos + 1)); }
fallo() { printf '[FALLO] %s\n' "$*"; fallos=$((fallos + 1)); }
info()  { printf '[INFO]  %s\n' "$*"; }
invalido() { echo "[FALLO] $*" >&2; echo "RESULTADO: FALLO (entorno no válido)" >&2; exit 2; }

command -v pacman >/dev/null 2>&1 || invalido "No hay 'pacman': esto no es Arch/CachyOS. Ejecútalo en el Firebat ya instalado."
[[ -r "$PACMAN_CONF" ]] || invalido "No se puede leer $PACMAN_CONF"
echo "== Comprobaciones Fase 1 · ruta $RUTA · $(date '+%F %H:%M') =="

# 1. Arranque UEFI
if [[ -d /sys/firmware/efi ]]; then bien "Arranque en modo UEFI"; else aviso "No arranca en UEFI (se esperaba UEFI puro)"; fi

# 2. Repositorios (Omarchy sobrescribe pacman.conf y el mirrorlist)
activos=$(grep -E '^[[:space:]]*\[[^]]+\]' "$PACMAN_CONF" | tr -d ' \t' | grep -v '^\[options\]' | tr '\n' ' ')
info "Repos activos en $PACMAN_CONF: ${activos:-ninguno}"
tiene_cachyos=0; tiene_omarchy=0
grep -qE '^[[:space:]]*\[cachyos[^]]*\]' "$PACMAN_CONF" && tiene_cachyos=1
grep -qE '^[[:space:]]*\[omarchy\]' "$PACMAN_CONF" && tiene_omarchy=1
if [[ "$RUTA" == A ]]; then
  if [[ $tiene_omarchy -eq 1 ]]; then bien "Repo [omarchy] presente (ruta A)"; else fallo "Ruta A sin repo [omarchy] en $PACMAN_CONF"; fi
else
  if [[ $tiene_cachyos -eq 1 ]]; then bien "Repos de CachyOS presentes"
  else fallo "Faltan los repos de CachyOS (¿los ha sobrescrito Omarchy?). NO actualices: restaura pacman.conf o el snapshot."; fi
  [[ $tiene_omarchy -eq 1 ]] && info "Repo [omarchy] presente: propio de la ruta C (solo SSD de prueba)"
fi

# 3. Kernel en uso
k=$(uname -r)
case "$k" in
  *cachyos*) if [[ "$RUTA" == A ]]; then aviso "Kernel CachyOS ($k) en la ruta A: inesperado"; else bien "Kernel CachyOS: $k"; fi ;;
  *omarchy*) if [[ "$RUTA" == A ]]; then bien "Kernel Omarchy: $k"; else aviso "Kernel de Omarchy ($k) sobre base CachyOS: se pierden optimizaciones"; fi ;;
  *)         aviso "Kernel no identificado como CachyOS ni Omarchy: $k" ;;
esac

# 4. Btrfs + Snapper (reversibilidad)
fs=$(findmnt -no FSTYPE / 2>/dev/null || true)
if [[ "$fs" == btrfs ]]; then bien "Raíz en Btrfs"; else aviso "Raíz en '${fs:-desconocido}', no Btrfs: sin snapshots de Snapper"; fi
if ! command -v snapper >/dev/null 2>&1; then
  fallo "Snapper no está instalado: sin snapshots no hay vuelta atrás (FASE1.md, paso 1.4)"
elif cfg=$(snapper list-configs 2>/dev/null); then
  if grep -qE '^[[:space:]]*root[[:space:]]' <<<"$cfg"; then bien "Configuración 'root' de Snapper presente"
  else fallo "Snapper sin configuración 'root' (FASE1.md, paso 1.4)"; fi
else
  aviso "Snapper no responde sin privilegios: comprueba con 'sudo snapper list-configs'"
fi
if pacman -Q snap-pac >/dev/null 2>&1; then bien "snap-pac instalado (snapshot automático en cada pacman)"; else aviso "snap-pac no instalado"; fi

# 5. Bootloader e initramfs
if [[ -f /boot/limine.conf || -f /boot/limine/limine.conf || -d /boot/EFI/limine ]]; then info "Bootloader: Limine"
elif [[ -f /boot/grub/grub.cfg ]]; then info "Bootloader: GRUB"
elif [[ -d /boot/loader/entries ]]; then info "Bootloader: systemd-boot"
else info "Bootloader: no identificado (sin permiso para leer /boot o ubicación distinta)"; fi
if compgen -G "$MKINIT_DIR/*.conf" >/dev/null; then
  for f in "$MKINIT_DIR"/*.conf; do info "mkinitcpio: $(basename "$f") → $(grep -E '^[[:space:]]*HOOKS' "$f" | head -1)"; done
else
  info "Sin ficheros en $MKINIT_DIR"
fi

# 6. Paquetes foráneos (AUR o externos): revisar; ver [H1] en VERSIONES.md (incidente del AUR de jun-2026)
mapfile -t foraneos < <(pacman -Qmq 2>/dev/null)
info "Paquetes foráneos (pacman -Qm): ${#foraneos[@]}${foraneos[*]:+ → ${foraneos[*]:0:15}}"

# 7. Cortafuegos: Omarchy activa ufw; no debe convivir con firewalld
fw=()
for s in firewalld ufw; do systemctl is-active --quiet "$s" 2>/dev/null && fw+=("$s"); done
case ${#fw[@]} in
  0) aviso "Ningún cortafuegos activo" ;;
  1) bien "Cortafuegos activo: ${fw[0]}" ;;
  *) fallo "Dos cortafuegos activos a la vez (${fw[*]}): deja solo uno" ;;
esac

echo "== Resumen: $fallos fallo(s), $avisos aviso(s) =="
if [[ $fallos -gt 0 ]]; then echo "RESULTADO: FALLO"; exit 1; fi
echo "RESULTADO: OK"
exit 0
