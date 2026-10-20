# FASE 1 — Migración Windows 11 → CachyOS (guía extendida)

> Documento detallado de la **pre-instalación** (respaldo, licencia, clonado, ISO, USB, BIOS)
> más el enlace con el **baseline** (`fase-1-baseline/`) y un adelanto de la **Fase 2**.
> Regla de oro: **nada irreversible (formatear, clonar sobre destino) sin tener antes el
> respaldo verificado.** Trabajo por fases, en español.

Índice:
1. Respaldo y licencia de Windows
2. Clonar el disco (3+ programas gratuitos)
3. Descargar y verificar CachyOS
4. Crear el USB de arranque (Ventoy / Rufus / YUMI / Etcher)
5. Configurar la BIOS del Firebat
6. Instalación (Calamares)
7. Tras instalar: baseline (Fase 1F)
8. Adelanto Fase 2 (escritorio + estética)

---

## 1. Respaldo y licencia de Windows (desde Windows, antes de nada)

**a) Extraer la clave de producto (OEM/firmware).** PowerShell **como administrador**:
```powershell
(Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey
# equivalente antiguo:
# wmic path SoftwareLicensingService get OA3xOriginalProductKey
```
Devuelve la clave OEM incrustada en el firmware (UEFI), si existe. Guárdala **dentro y fuera**
del equipo (gestor de contraseñas + papel/otra ubicación).

> ⚠️ En Windows 11 la activación suele ser **licencia digital** ligada al hardware y/o a tu
> cuenta Microsoft, **no** una clave tecleable. Por eso lo más importante es:
> **Configuración → Sistema → Activación → Añadir una cuenta Microsoft** para *vincular* la
> licencia digital. Así, si algún día reinstalas Windows (p. ej. en una VM en el 2º M.2),
> se reactiva sola.

**b) BitLocker.** Comprueba si el disco está cifrado (Panel de control → Cifrado de unidad
BitLocker). Si lo está:
- Guarda la **clave de recuperación**: https://account.microsoft.com/devices (o exporta el `.txt`).
- Si vas a **clonar**, **desactiva BitLocker** antes (descifra la unidad); si no, el clon
  quedará cifrado y necesitarás la clave para restaurarlo.

**c) Fast Startup (Inicio rápido) OFF.** Panel de control → Opciones de energía → *Elegir el
comportamiento de los botones de inicio/apagado* → *Cambiar la configuración actualmente no
disponible* → **desmarca "Activar inicio rápido"**. Evita que el disco quede en estado
hibernado/bloqueado (importante para clonar y para no corromper el sistema de archivos).

**d) Datos y programas.** Copia tus datos personales a un disco externo y anota la **lista de
programas** instalados (para reinstalar equivalentes en Linux o en una VM).

---

## 2. Clonar el disco tal cual está (imagen completa, gratis)

Objetivo: una **imagen completa del disco** (todas las particiones, arranque incluido) en un
disco externo, para poder volver a Windows si hiciera falta. Al menos 3 opciones gratuitas:

| Programa | Tipo | Enlace oficial |
|---|---|---|
| **Clonezilla** | FOSS, imagen/clonado sector-a-sector; arranca desde su propio USB | https://clonezilla.org/ |
| **Rescuezilla** | GUI amigable **sobre** Clonezilla (más fácil de usar) | https://rescuezilla.com/ |
| **Veeam Agent for Microsoft Windows (FREE)** | Imagen a nivel de disco desde Windows | https://www.veeam.com/ → sección *Free* |

Alternativas: **AOMEI Backupper Standard** (https://www.aomeitech.com/, freemium: algunas
funciones de clonado son de pago) y **Hasleo Backup Suite Free** (https://www.easyuefi.com/).
> Nota: **Macrium Reflect Free** fue **descontinuado**; su edición gratuita ya no está
> disponible para nuevas descargas, no cuentes con ella como opción gratis.

Recomendación práctica: **Clonezilla/Rescuezilla** (arrancas desde un USB aparte y clonas el
NVMe entero al disco externo) es lo más fiable para una imagen "tal cual". Verifica que el
disco externo tiene espacio suficiente (≥ tamaño usado del NVMe). Confirma siempre el dominio
oficial de descarga (cuidado con webs que suplantan).

---

## 3. Descargar y verificar CachyOS

- **Página oficial de descarga:** https://cachyos.org/download/
- **Guía oficial de validación (SHA256/firma):** https://wiki.cachyos.org/cachyos_basic/download/
- **Mirror de ISOs:** https://mirror.cachyos.org/ISO/ (estructura `ISO/desktop/<fecha>/` con
  `.iso`, `.sha256` y `.sig`). También en SourceForge: https://sourceforge.net/projects/cachyos-arch/

**Edición:** **Desktop x86_64**. La ISO es *rolling* y va fechada `YYMMDD`
(p. ej. `cachyos-desktop-linux-2609xx.iso`): coge la **más reciente**. Existen también
ediciones *Handheld* y *Server* (no las necesitas). Pendrive **≥ 8 GB**.

**Verificar el SHA256 (hazlo siempre antes de escribir el USB):**
```powershell
# Windows (PowerShell), en la carpeta de la ISO:
certUtil -hashfile cachyos-desktop-linux-2609xx.iso SHA256
# Compara el hash con el contenido del archivo .sha256 descargado al lado de la ISO.
```
```bash
# Linux/Mac (con el .iso y el .sha256 juntos):
sha256sum -c cachyos-desktop-linux-*.iso.sha256   # debe decir: OK
```
Si no coincide → descarga corrupta o manipulada: **vuelve a descargar**.

---

## 4. Crear el USB de arranque

### Opción recomendada — **Ventoy** (multi-ISO, arrastrar y soltar)
- Descarga: https://www.ventoy.net/ (paquete Windows `ventoy-*-windows.zip`).
- Ejecuta `Ventoy2Disk.exe` → selecciona el USB → **Option → Partition Style → GPT**
  (para UEFI puro) → **Install**. ⚠️ Esto **formatea el USB** (borra su contenido).
- Después, **copia el archivo `.iso`** de CachyOS a la partición grande del USB (arrastrar y
  soltar). Ventoy muestra un menú con las ISOs al arrancar. Puedes tener varias ISOs a la vez.
- Si vas a dejar Secure Boot activado, marca el soporte de Secure Boot de Ventoy (nosotros lo
  desactivamos en BIOS, así que no es imprescindible).

### Alternativa — **Rufus**
- Descarga: https://rufus.ie/
- *Dispositivo* = tu USB · **SELECT** = la ISO · *Partition scheme* = **GPT** · *Target system*
  = **UEFI (non-CSM)**.
- Al pulsar **START**, Rufus pregunta *ISO Image mode* vs *DD Image mode* → para ISOs
  Arch (isohybrid) elige **DD Image mode** (más fiable). ⚠️ Borra el USB.

### Otras
- **YUMI** — https://www.yumiusb.com/ : creador multiboot. Funciona, pero con ISOs Arch a veces
  da fricción en UEFI → **preferir Ventoy**.
- **balenaEtcher** — https://etcher.balena.io/ : flasheo simple estilo DD, una sola ISO.

Formato/tamaño: USB **≥ 8 GB**. Con Ventoy la partición de datos suele ser **exFAT** (admite
ISOs > 4 GB). Con Rufus/Etcher en modo DD el USB queda con el layout de la propia ISO.

---

## 5. Configurar la BIOS del mini PC (Firebat) antes de instalar

Entra en la BIOS (normalmente **Supr/Del** o **F2** al encender; el menú de arranque puntual
suele ser **F7/F11/F12** según la placa):

- **Secure Boot → Disabled** (para instalar Arch/CachyOS; reactivable luego con `sbctl`).
- **CSM / Legacy → Disabled** → arranque **UEFI puro**.
- **Fast Boot (BIOS) → Disabled**.
- **SVM Mode (AMD-V) → Enabled** (suele estar en *Advanced → CPU Configuration*).
  Es lo que habilita **KVM/QEMU** para los laboratorios (Fase 4). El baseline lo verifica.
- **Orden de arranque:** USB primero, o usa el menú de arranque puntual.
- **(DDR5) EXPO / perfil de memoria:** opcional. Puedes dejarlo en **Auto** por estabilidad y
  activar el perfil más adelante si quieres la velocidad nominal.

> Recordatorio RAM: en este equipo la RAM es **soldada** (no ampliable). Techo de trabajo **16 GB**.

---

## 6. Instalación (Calamares)

Arranca desde el USB (entorno *live* de CachyOS) y abre el instalador **Calamares**:
- **Idioma español**, zona horaria y teclado.
- **Kernel:** `cachyos` (por defecto, optimizado).
- **Escritorio:** elige un perfil **mínimo / None** si el instalador lo ofrece (el WM
  definitivo se decide en **Fase 2**). Si obliga a elegir uno, KDE (por defecto) y lo podamos
  en Fase 2.
- **Particionado:** **Borrar disco** (todo el NVMe de 512 GB) → instalación limpia.
  **Sistema de archivos: Btrfs** (recomendado: encaja con los snapshots de **snapper** del
  bloque G del baseline).
- **Bootloader:** el que venga por defecto (systemd-boot o Limine según la ISO).
- **Usuario:** crea tu cuenta (Iñaki).
- Instala, **reinicia y quita el USB**.

---

## 7. Tras instalar: baseline (Fase 1F)

Ya en CachyOS, ejecuta el **playbook de validación y baseline** que tienes en
[`fase-1-baseline/`](./fase-1-baseline/):
1. `bash 00-diagnostico.sh` (solo lectura) → pégame la salida.
2. Bloques A→G con confirmación (mirrors+update, gráficos AMD/Vulkan, base, fuentes,
   red 5G RTL8157, **firewall = firewalld**, snapshot **baseline**).
3. Cierre con `H-resumen.md` (NICs, Vulkan, virtualización, RAM).

Detalle y explicación de cada bloque: [`fase-1-baseline/README.md`](./fase-1-baseline/README.md).

---

## 8. Adelanto Fase 2 (escritorio + estética oriental) — resumen

1. **Decidir WM:** recomendado **Hyprland + Caelestia/Noctalia** (Wayland tiling, ligero, con
   el look de los vídeos). Alternativa **Qtile** (config en Python) — no descartada.
2. **Instalar el stack Wayland:** WM + *greeter* (SDDM o greetd/tuigreet), audio
   (PipeWire + WirePlumber), portal (`xdg-desktop-portal-hyprland`), notificaciones, terminal
   (kitty/foot), NetworkManager, Bluetooth.
3. **Shell estético (Quickshell):** **Noctalia** (packs oficiales CachyOS, menos fricción) o
   **Caelestia** → **paleta dinámica generada desde el wallpaper**.
4. **Estética oriental:** wallpapers (Wallhaven: *oriental landscape*, *anime scenery*;
   `catppuccin/wallpapers`), iconos **Papirus** y fuentes **Nerd/CJK** (ya instaladas en el baseline).
5. **Aviso:** cuidado con la versión de **Quickshell** (AUR vs repo) al montar Caelestia;
   Noctalia suele dar menos problemas.

> Fase 2 se aborda cuando confirmes el WM. Fase 1 es idéntica sea cual sea la elección.
