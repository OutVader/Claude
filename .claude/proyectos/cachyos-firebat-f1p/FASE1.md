# FASE 1 · Instalación, actualización y Omarchy (guía paso a paso, con puertas)

> v2.0 · 20-oct-2026 · Se ejecuta **en el Firebat**. Requisito: **PUERTA 0 cerrada** ([`FASE0.md`](./FASE0.md)).
> Versiones y enlaces: [`VERSIONES.md`](./VERSIONES.md) · Normas: [`CLAUDE.md`](./CLAUDE.md) · Registro: [`bitacora.md`](./bitacora.md).
> Ningún instalador de Omarchy ni de adaptadores es un paso definitivo hasta la **PUERTA 2** (hardware confirmado, auditoría, backup verificado y tu OK por escrito).

## Paso 1.0 · BIOS
Aplica los valores objetivo del paso 0.9 de la Fase 0 (Secure Boot Off, CSM Off, Fast Boot Off, SVM On).
- ↳ **Si algo no arranca:** vuelve a los valores de la foto, o *Load Optimized Defaults*.

## Paso 1.1 · Identificar el hardware desde el USB live, SIN instalar
Arranca el USB → Ventoy → CachyOS → entorno live (no abras el instalador todavía). Abre una terminal:
```bash
lscpu | grep -E 'Model name|Socket|Core|Thread'
grep -o 'avx512[a-z]*' /proc/cpuinfo | sort -u | head -3      # con salida: Zen 4/5 → repos v4/znver4
free -h
cat /sys/class/dmi/id/{sys_vendor,product_name,board_name}
sudo dmidecode -t memory | grep -E 'Maximum Capacity|Number Of Devices|Form Factor|Locator:|^\s+Size:|Speed:'
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL
lspci -nnk | grep -A3 -Ei 'VGA|3D|Display|Network|Ethernet|Audio'
lsusb                                # adaptadores de red USB (RTL8156/RTL8157)
ls /sys/firmware/efi >/dev/null && echo UEFI || echo "NO UEFI"
```
- Copia la salida en `bitacora.md` (estos comandos no muestran números de serie ni UUID). Con ella, resuelve los cuatro conflictos de hardware de la Fase 0.
- RAM: `Form Factor: SODIMM` con un `Locator` sin módulo ⇒ ampliable. `Row Of Chips`, o todo ocupado ⇒ soldada o sin hueco.
- ↳ **Si el live no arranca (pantalla negra):** en el menú de arranque del live elige la entrada *fallback* o *nomodeset*. Si no la hay, prueba el USB de Rufus del paso 0.7.
- ↳ **Si no hay red en el live:** cable, o Wi-Fi desde el icono de red (NetworkManager). Para este paso no hace falta red.

**PUERTA 1 · hardware confirmado → elegir ruta → OK para borrar.** Rehaz la comparativa A-D (contexto maestro §7) con los datos reales y escribe en la bitácora, **antes de abrir ningún instalador**:
1. la ruta elegida;
2. una línea de autorización con el disco concreto, por ejemplo: `OK Iñaki AAAA-MM-DD: borrar el disco <modelo> de <tamaño> para la ruta <X>` (copia el modelo y el tamaño de la salida de `lsblk`).
Sin esa línea no se pulsa ningún "Borrar disco".
| Ruta | Qué es | Dónde | Estado hoy |
|---|---|---|---|
| **D** | CachyOS + Hyprland + estilo Omarchy **recreado a mano** | Disco principal | Recomendación provisional (control máximo) |
| **B** | CachyOS + Hyprland, sin Omarchy | Disco principal | Igual de seguro que D |
| **A** | ISO oficial de Omarchy 4.0.6 (Arch + kernel `linux-omarchy` [H2], **sustituye** a CachyOS) | Disco principal | Si prima Omarchy íntegro |
| **C** | CachyOS + omacachy | **Solo SSD de prueba** | COMPATIBLE CON RESERVAS (baseline 4.0.2) |
Ruta A → salta al paso 1.5-A, que tiene su propia puerta (**PUERTA 2-A**). Rutas B, C y D → paso 1.2.
[Hn] = hecho citado con fuente y fecha en `VERSIONES.md` → "Hechos citados".

## Paso 1.2 · Instalar CachyOS (rutas B, C y D)
Abre **CachyOS Hello → Launch Installer** (Calamares) y elige:
1. Idioma **Español (España)**, zona horaria **Europe/Madrid**, teclado **es**.
2. Bootloader: el que proponga el instalador. Anota cuál es (por defecto en 2026: NO VERIFICADO).
3. Particionado: **Borrar disco**. ⚠️ **Comprueba el disco por modelo y tamaño** (salida de `lsblk` del paso 1.1).
   - Ruta C: elige el **SSD de prueba**. El NVMe principal debe estar **desconectado físicamente**, o al menos no seleccionado.
4. Sistema de archivos: **Btrfs**. Cifrado (LUKS): opcional. Si piensas probar la ruta C, ojo: Omarchy reescribe los HOOKS de mkinitcpio y puede dejar sin arranque un sistema con LUKS [H3]. omacachy dice mitigarlo, pero solo lo ha validado con la 4.0.2 [H4].
5. Escritorio: **Hyprland** (rutas B y D). Ruta C: lo que exija el README auditado de omacachy (NO VERIFICADO).
6. Usuario, contraseña y **Instalar**. Al terminar: reinicia y retira el USB.
- ↳ **Si la instalación falla al descargar paquetes:** en el live ejecuta `sudo cachyos-rate-mirrors` y relanza el instalador. Guarda el log que ofrece Calamares para revisarlo.
- ↳ **Si tras reiniciar no arranca:** en la BIOS, pon como primera opción la entrada del bootloader instalado (no "Windows Boot Manager"). Si sigue sin arrancar, arranca el live y pásame la salida de `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS` (sin UUID ni etiquetas).

## Paso 1.3 · Primer arranque y actualización completa
```bash
sudo cachyos-rate-mirrors        # reordena los mirrors por velocidad
sudo pacman -Syu                 # actualización COMPLETA (nunca parcial: nada de -Sy paquete)
uname -r                         # si pacman actualizó el kernel, reinicia ahora
```
- ↳ **Si sale "invalid or corrupted package (PGP signature)":** `sudo pacman -Sy archlinux-keyring cachyos-keyring && sudo pacman -Su`. Es la única excepción a la regla de "nada de -Sy paquete": se actualizan solo los llaveros y, **justo después**, el sistema completo con `-Su`.
- ↳ **Si sale "unable to lock database":** comprueba con `pgrep -a pacman` que no hay otro pacman en marcha. Solo si no hay ninguno: `sudo rm /var/lib/pacman/db.lck` (borra un fichero de bloqueo huérfano).
- ↳ **Si sale "conflicting files":** **no** uses `--overwrite` a ciegas. Copia el mensaje en la bitácora y revísalo antes de seguir.
- ↳ **Si fallan los mirrors:** repite `sudo cachyos-rate-mirrors` y vuelve a intentar.

## Paso 1.4 · Snapper, snapshot base y prueba real de reversión
```bash
sudo pacman -S --needed snapper snap-pac
sudo snapper list-configs                       # debe aparecer "root"
sudo snapper -c root create-config /            # SOLO si "root" no aparece
sudo snapper -c root create -d "base-fase1"
# Prueba de reversión con un paquete inofensivo:
sudo pacman -S --needed sl                      # snap-pac crea snapshots pre y post
sudo snapper -c root list | tail -3             # anota los números pre (N) y post (M) de "pacman -S sl"
sudo snapper -c root undochange N..M            # sustituye N y M por los números anotados
pacman -Q sl                                    # esperado: "error: package 'sl' was not found"
```
- ↳ **Si `create-config` dice que `/.snapshots` ya existe:** CachyOS ya trae una configuración. Usa la existente (`sudo snapper list-configs`) y no la vuelvas a crear.
- ↳ **Si `pacman -Q sl` sigue mostrando el paquete:** la reversión no cubre la base de datos de pacman (depende de los subvolúmenes: NO VERIFICADO). Quita el paquete con `sudo pacman -Rns sl` y anótalo: tendrás que revertir desde el menú de arranque o desde el live.
- ↳ **Si `/` no es Btrfs:** Snapper no sirve. Lo correcto es reinstalar con Btrfs (paso 1.2); como apaño, **Timeshift** en modo RSYNC.

Para tener aquí los scripts, déjalos **siempre** en `~/firebat/scripts/`: copia la carpeta `scripts/` por USB a `~/firebat/`, o clona el repo y copia desde él (`git clone` te pedirá un token de GitHub si el repo es privado). Todos los comandos de esta guía usan esa ruta absoluta:
```bash
mkdir -p ~/firebat && ls ~/firebat/scripts/comprobar-sistema.sh   # debe existir
bash ~/firebat/scripts/comprobar-sistema.sh --ruta D      # o B / C; debe terminar en "RESULTADO: OK"
```
- ↳ **Si da FALLO:** corrige lo que marque `[FALLO]` antes de pasar a la PUERTA 2. Si es "Faltan los repos de CachyOS", **no actualices**: revierte al snapshot `base-fase1` como indica el paso 1.6.

## PUERTA 2 · Omarchy en rutas B, C y D (requisitos, todos)
PUERTA 0 cerrada · PUERTA 1 (con la línea de OK) · snapshot `base-fase1` · `comprobar-sistema.sh` en OK · auditoría hecha (ruta C) · **tu OK escrito en la bitácora para esta ruta**. Nunca `v4.5.0-rc1` en el disco principal.
**PUERTA 2-A (solo ruta A, que no pasa por los pasos 1.2-1.4):** PUERTA 0 cerrada (imagen **verificada**) · PUERTA 1 (con la línea de OK para borrar el disco) · ISO de Omarchy con SHA256 OK (paso 0.5) · tu OK escrito para la ruta A.
Aviso: Omarchy activa **ufw** con `deny incoming`, abre 53317/tcp+udp (LocalSend) y no tiene regla para SSH [H5]. Si usas firewalld (decisión de sept-2026), deja solo uno: el script marca FALLO si hay dos activos.

### 1.5-D · Estilo Omarchy recreado a mano (recomendación provisional)
CONFIRMADO en el código de v4.0.6 [H6]: `config/hypr/hyprland.lua` carga `/usr/share/omarchy/default/hypr/bootstrap.lua`, que pertenece al paquete `omarchy`. **Copiar su configuración sin el paquete no funciona.** La ruta D consiste en recrear, no en copiar:
```bash
sudo snapper -c root create -d "antes-estilo-omarchy"
cp -a ~/.config ~/.config.bak-$(date +%F)                      # vuelta atrás de tu configuración
git clone --depth 1 --branch v4.0.6 https://github.com/omacom/omarchy ~/src/omarchy   # SOLO lectura: no ejecutes nada de bin/ ni de install/
ls ~/src/omarchy/themes ~/src/omarchy/config/hypr              # temas y atajos de referencia
```
Copia colores y atajos a **tu propia** configuración de Hyprland (`~/.config/hypr/`), versionada en un repo de dotfiles.
- ↳ **Si Hyprland no arranca tras un cambio:** en una TTY (Ctrl+Alt+F3), `rm -rf ~/.config/hypr && cp -a ~/.config.bak-AAAA-MM-DD/hypr ~/.config/` (pon la fecha de tu copia). Borra **solo** tu configuración rota y repone la copia.

### 1.5-B · Sin Omarchy
No hay nada más que hacer: Hyprland de CachyOS tal cual. Pasa al paso 1.6.

### 1.5-A · ISO oficial de Omarchy 4.0.6 (sustituye a CachyOS)
USB grabado con balenaEtcher (paso 0.7) → **Secure Boot y TPM en Off** → arranca → instalación de **disco completo**, que **borra la unidad** y **cifra por defecto** [H7]. Usa un **teclado con cable** para la contraseña de cifrado.
- ↳ **Si quieres volver atrás:** reinstala CachyOS (paso 1.2) o restaura la imagen de la Fase 0.

### 1.5-C · omacachy, SOLO en el SSD de prueba
1. NVMe principal **desconectado**. Clona y comprueba el commit:
   ```bash
   git clone https://github.com/t1nk333r/omacachy ~/src/omacachy && cd ~/src/omacachy
   git log -1 --format='%h %ci %s'      # esperado: b46236a 2026-09-15 … o uno posterior que hayas revisado
   ```
2. **Auditoría** (lee el script completo antes de ejecutar nada), dentro de `~/src/omacachy`: `grep -rnE 'curl|wget|sed -i|pacman -R|pacman.conf|mkinitcpio|limine|grub|systemctl enable|rm -rf' .` (se busca en todo el repo porque la estructura de carpetas de omacachy está NO VERIFICADO). Comprueba en el código que su modo de prueba de verdad no escribe, y anota la versión baseline (`OMARCHY_RECONCILED_VERSION` = 4.0.2) frente a la 4.0.6.
3. Antes de ejecutar: `sudo snapper -c root create -d "antes-omacachy"` y `cp -a ~/.config ~/.config.bak-$(date +%F)` (Snapper `root` **no** incluye `/home`). Después, ejecución **solo con tu OK escrito**, según el README auditado (aquí no se da como comando definitivo).
4. `bash ~/firebat/scripts/comprobar-sistema.sh --ruta C`: los repos de CachyOS deben seguir presentes.
- ↳ **Si falla:** busca el número N de `antes-omacachy` (`sudo snapper -c root list`) y revierte con `sudo snapper -c root undochange N..0` (0 = estado actual) y repón tu configuración con `rm -rf ~/.config && cp -a ~/.config.bak-AAAA-MM-DD ~/.config` (pon la fecha de tu copia), porque `undochange` sobre `root` no toca `/home`. Ojo: esto tampoco revierte la partición EFI (`/boot`, `/efi`): si el bootloader o el initramfs quedaron mal, reinstala el SSD de prueba. **AstroByte01: no usar** (modelo 3.x, INCOMPATIBLE).

## Paso 1.6 · Comprobaciones finales y cierre
```bash
bash ~/firebat/scripts/comprobar-sistema.sh --ruta D   # la ruta elegida (A, B, C o D)
pacman -Qm ; grep '^\[' /etc/pacman.conf ; uname -r
sudo snapper -c root create -d "fin-fase1"
```
Reinicia **dos veces** y comprueba: inicio de sesión, red por cable y Wi-Fi, audio y suspensión/reanudación. Anota todo en la bitácora.
- ↳ **Si algo se rompió (rutas B, C y D):** vuelve al snapshot `base-fase1`:
  1. Desde la entrada de snapshots del menú de arranque, si tu bootloader la tiene (NO VERIFICADO).
  2. O busca su número N con `sudo snapper -c root list | grep base-fase1` y ejecuta `sudo snapper -c root undochange N..0` (0 = estado actual). Ojo: esto **no** revierte la partición EFI (`/boot`, `/efi`). Si desde `base-fase1` se actualizó el kernel, tras revertir ejecuta `sudo pacman -Syu` (vuelve a instalar el kernel en `/boot` y regenera el initramfs) antes de reiniciar.
  3. En el peor caso, reinstala desde el paso 1.2: tus datos siguen en el disco externo.
- ↳ **Ruta A:** `base-fase1` no existe. Usa los snapshots que trae Omarchy (*System snapshots* en su manual: NO VERIFICADO), reinstala con la ISO, o vuelve a Windows restaurando la imagen de la Fase 0 con Rescuezilla.

## Paso 1.7 (opcional) · Claude Code para seguir en local
```bash
curl -fsSL https://claude.ai/install.sh -o /tmp/instalar-claude.sh
less /tmp/instalar-claude.sh        # léelo antes (norma: nada de curl|bash a ciegas)
bash /tmp/instalar-claude.sh        # SIN sudo; versión vigente en VERSIONES.md
claude                              # /login → "Claude account with subscription" (tu plan Pro)
```
- ↳ **Si el instalador falla:** `sudo pacman -S --needed nodejs npm`, luego `npm config set prefix ~/.local` y `npm install -g @anthropic-ai/claude-code` (sin sudo; añade `~/.local/bin` al PATH).
- Permisos: usa el modo normal con lista blanca (`/permissions`). `--dangerously-skip-permissions` solo para tareas acotadas, porque se salta tu regla de confirmar lo destructivo.

**Criterio de salida de la Fase 1:** `RESULTADO: OK`, snapshot `fin-fase1`, dos reinicios limpios y la ruta elegida anotada. Siguiente fase: escritorio fino, IA y laboratorio (fuera de esta guía).
