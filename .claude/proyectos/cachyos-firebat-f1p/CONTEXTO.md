# CONTEXTO · Homelab mini PC: CachyOS + Omarchy + Firebat
Versión 1.1 · 20-oct-2026 (antes: v1.0) (Europe/Madrid) · fuente del usuario: `original-2026-10-20.md` (copia recibida incompleta, ver aviso allí).

## 1. Objetivo
Instalación limpia en el mini PC Firebat como nodo inicial del homelab. Opciones: A ISO Omarchy · B CachyOS + Hyprland · C CachyOS + Omarchy vía adaptador comunitario · D CachyOS + escritorio «tipo Omarchy» manual. Preferencia inicial de Iñaki: C. Criterio: mejor solución para el hardware, no una distro a cualquier precio.

## 2. Estado verificado en la web (consulta 20-oct-2026)
| Tema | Dato | Fuente |
|---|---|---|
| CachyOS ISO | Última release: **agosto 2026** (Shelly rewrite, cachy-update rework, perfiles Server). No hay release de octubre. Kernel en repos ~7.2.11 (semana 12-oct). | cachyos.org/category/release/ · discuss.cachyos.org/c/announcements/5 · repojournal.com (CachyOS week 2026-10-12) |
| CachyOS aviso | AUR comprometido el 11-jun-2026 (~2000 paquetes). Minimizar AUR y revisar PKGBUILD. | discuss.cachyos.org (anuncio 20260611) |
| Omarchy estable | **v4.0.6** (19-oct-2026), parche de 4.0.5 (fallo migración OpenClaw, bloqueo antes de suspender, Limine). ISO con SHA256 publicado. | github.com/omacom/omarchy/releases · oatlug.org/news/releases/v4.0.6 |
| Omarchy RC | **v4.5.0-rc1** (20-oct-2026) — pre-release, no usar en el equipo principal. | github.com/omacom/omarchy/releases |
| Omarchy 4 arquitectura | Se distribuye como paquetes pacman (`omarchy`, `omarchy-settings`), sin `install.sh` raíz; kernel propio `linux-omarchy-bore`. | issue mroboff #74 · omarchylinux.org/vs/cachyos/ |
| **Adaptador 1 (de Iñaki): AstroByte01/omarchy-on-cachyos** | Continuación de mroboff. Último commit **20-jul-2026 02:38** (Europe/Madrid), anterior a Omarchy 4.0.0. 0 issues abiertos, 0 estrellas. Sigue el modelo 3.x de clonar, parchear y ejecutar `install.sh` → **soporte de Omarchy 4.x: no consta (lo más probable es que no lo tenga)**. Kernel: mantiene el de CachyOS (parchea la detección de kernel de `omarchy-update-restart`). Repos: añade `[omarchy]` con firma obligatoria y para si hay servidores inesperados. Vigila con CI los repos v3, v4 y znver4 de CachyOS. mkinitcpio: mantiene activos los hooks de pacman (issue #6188), repara los `.hook.disabled` y no sobrescribe hooks activos. Desactiva la hibernación de Omarchy. Exige snapshot Snapper de raíz y tiene `--dry-run`/`--prepare-only`. | github.com/AstroByte01/omarchy-on-cachyos (README y API commits/issues, 20-oct) |
| **Adaptador 2 (de Iñaki): t1nk333r/omacachy** | Último commit **15-sep-2026 19:14** (Europe/Madrid), solo cambios de documentación. 0 issues abiertos, 0 estrellas. **Soporta Omarchy 4 «Quattro»** con `bin/install-omarchy-quattro.sh` (recomendado por el propio repo), pero validado sobre **4.0.2**: avisa si la versión instalada se aleja. Con 4.0.6, **NO VERIFICADO**. Repos: añade `[omarchy]` (`Required DatabaseOptional`), hace backup de `pacman.conf` y del mirrorlist y los restaura después de `omarchy-apply-system`, porque este los sobrescribe. mkinitcpio: crea `zz-cachyos-keep-hooks.conf`, que transforma los HOOKS de Omarchy para conservar `sd-encrypt` (mitiga el issue #74). Regenera el initramfs una vez y ejecuta un conjunto de comprobaciones. Bootloader: cualquiera; Limine solo si está en uso. Kernel: **NO VERIFICADO** (no consta que instale `linux-omarchy-bore`). Debloater opcional. | github.com/t1nk333r/omacachy (README y API, 20-oct) |
| Referencia: mroboff/omarchy-on-cachyos | Último commit **1-jun-2026** (antes de Omarchy 4.0.0, 14-ago-2026). ~22 issues y 10 PR abiertos (a 16-sep). **No soporta Omarchy 4.x**: issue #74 abierta (rutas 4/9 en v4; sin `set -e` → falso «éxito»; `omarchy-settings` reasigna HOOKS de mkinitcpio → puede dejar el equipo sin arrancar con LUKS). PR #77 (soporte 4.x) abierta. | github.com/mroboff/omarchy-on-cachyos/commits/main · /issues/74 · omarchylinux.org/vs/cachyos/ |
| Referencia: lentra0/omarchy-cachyos | Fork de estilo 3.x (usa `install.sh`) → incompatible con 4.x. Último commit e issues: **NO VERIFICADO**. | github.com/lentra0/omarchy-cachyos |
| Riesgo estructural | El post-install de Omarchy sobrescribe `pacman.conf`/mirrorlist → elimina repos CachyOS → actualización parcial. | omarchylinux.org/vs/cachyos/ |
| Firebat P1 | **NO VERIFICADO / probablemente no existe con ese nombre.** Existen M1 (Ryzen AI 9 365 / HX 470, 32 GB LPDDR5), F1 y F1 P / AM02 (Ryzen 7 H 255, 16 GB). | shop.hornington.com (firebat-m1, firebat-f1) · notebookcheck (Firebat F1 P) · firebatpc.com (AM02) |
| Ryzen AI 9 HX 255 | **No existe** en el catálogo AMD. Candidatos: **Ryzen 7 H 255** (Zen 4, 8C/16T, Radeon 780M, sin NPU) — encaja con «Firebat + 16 GB DDR5»; o Ryzen AI 9 HX 370/375 (Zen 5, 890M). Confirmar con `lscpu`. | amd.com · liliputing · nanoreview |

Consecuencia (antes: «C no viable»): con Omarchy 4.0.6, **la única vía C plausible es omacachy**: va con 4.x, pero está validada en 4.0.2, tiene 0 estrellas y un solo autor. AstroByte01 solo sirve para 3.x. mroboff y lentra0 no valen. C sigue siendo solo de laboratorio, en SSD de prueba.

## 3. Hardware: qué confirmar (sin números de serie)
`lscpu` · `free -h` · `uname -a` · `cat /sys/class/dmi/id/{sys_vendor,product_name,board_name}` · `lspci -nnk | grep -A3 -Ei 'VGA|3D|Display|Network|Audio'` · `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL` · `sudo dmidecode -t bios` · `ls /sys/firmware/efi` (UEFI) · `grep -o 'avx512[a-z]*' /proc/cpuinfo | sort -u` (decide x86-64-v3 vs v4/znver4 en repos CachyOS).
Si es Ryzen 7 H 255 (Zen 4): repos CachyOS znver4/v4 aplicables; iGPU 780M con Mesa/radv. Wi-Fi/BT: identificar chip (MediaTek/Realtek/Intel) antes de decidir.

## 4. Recomendación provisional (a revalidar con hardware real)
1. **Primera opción: B o D** — CachyOS (Btrfs+Snapper, Limine o el bootloader por defecto) + edición Hyprland de CachyOS, importando a mano temas/atajos de Omarchy (D). Conserva optimizaciones y control del ecosistema.
2. **Alternativa: A** — Omarchy 4.0.6 oficial si prima la experiencia Omarchy íntegra (kernel `linux-omarchy-bore`, sin repos CachyOS).
3. **C solo en laboratorio**: omacachy en un SSD de prueba, tras auditar `install-omarchy-quattro.sh` y comprobar su ajuste con 4.0.6. Nunca en el disco principal.

## 5. Aporte Geordi (homelab, seguridad, backups)
- **Backup previo con Clone** (Clonezilla o equivalente) del SSD actual a disco externo, con verificación (restauración de prueba o checksum) antes de tocar nada. **NO VERIFICADO**: herramienta exacta «Clone» que usa Iñaki → confirmar.
- **Aislamiento**: pruebas C en un **SSD de prueba** (el modelo tiene 2.º M.2 según ficha F1 P/AM02, NO VERIFICADO en su unidad) o USB NVMe externo; disco principal desconectado o sin montar.
- **Btrfs + Snapper** (+ `snap-pac`, limine/grub-btrfs para arrancar snapshots): snapshot antes de cada cambio de paquete; probar un rollback real antes de usarlo en serio.
- Seguridad: LUKS2 opcional (ojo issue #74 con hooks), firewall (ufw/nftables), SSH solo con claves, actualizaciones vía `cachy-update`/pacman, AUR mínimo y auditado (incidente jun-2026), Secure Boot **NO VERIFICADO** en BIOS Firebat.
- Homelab: el mini PC como nodo inicial → servicios en contenedores (Podman/Docker) con datos en subvolumen propio; backup 3-2-1 de `/home` y configs (p. ej. restic/borg) **NO VERIFICADO** qué destino tiene Iñaki.

## 6. Aporte MacGyver (Linux)
- Auditoría de cualquier script: leer completo, buscar `curl|bash`, `sed -i` sobre /etc, `pacman -Rdd`, sobrescrituras de `pacman.conf`, `mkinitcpio`, bootloader, `systemctl enable`; ejecutar primero en VM/SSD de prueba con `set -x` y diff de /etc (`etckeeper` o snapshot comparado).
- Tras cualquier instalación: `pacman -Qm` (foráneos), `grep '^\[' /etc/pacman.conf` (repos CachyOS presentes), `cat /etc/mkinitcpio.conf.d/*`, `uname -r` (kernel cachyos vs omarchy).
- **Preferencia de Iñaki: controlar el ecosistema** → favorece B/D (configs propias en git/dotfiles, sin capas opacas que reescriban el sistema en cada update).
- **LLM locales con 16 GB**: realista modelos 7-8B en Q4 (≈5-6 GB) y como máximo ~14B Q4 justo; iGPU 780M vía Vulkan (llama.cpp/Ollama-Vulkan) o ROCm (soporte gfx1103 **NO VERIFICADO**); NPU XDNA solo si es CPU Ryzen AI (el H 255 no tiene NPU). Reservar memoria de vídeo en BIOS (UMA) y añadir zram. Ampliar a 32 GB+ si se quiere más (F1 P admite hasta 64 GB según notebookcheck, **NO VERIFICADO** en su unidad).

## 7. Criterios de decisión
Adaptador mantenido + soporte Omarchy actual + auditado → probar en SSD de prueba. Sin soporte versión actual (caso hoy) → no ejecutar. Conflictos con repos/hooks CachyOS → descartar. Sin evidencia → no asumir.

## 8. Pendiente / NO VERIFICADO
Modelo y CPU reales · chip Wi-Fi/BT · 2.º slot M.2 · Secure Boot · herramienta «Clone» · omacachy con 4.0.6 y su gestión del kernel · AstroByte01 con 4.x · estado de lentra0 · ROCm en 780M · texto íntegro del original.
