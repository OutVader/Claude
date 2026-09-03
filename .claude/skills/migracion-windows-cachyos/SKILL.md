---
name: migracion-windows-cachyos
description: >-
  Fase 1 pre-instalación: migrar un equipo de Windows 11 a CachyOS. Úsala cuando el
  usuario pregunte por respaldar/extraer la licencia de Windows, clonar el disco antes
  de formatear, descargar y verificar la ISO de CachyOS, crear el USB de arranque
  (Ventoy/Rufus/YUMI/Etcher), o ajustar la BIOS del mini PC (Secure Boot, CSM/UEFI, SVM,
  Fast Boot) antes de instalar. Enfoque cauto: nada irreversible sin confirmación.
---

# Migración Windows 11 → CachyOS (Fase 1, pre-instalación)

Rol: técnico de migración. Orden seguro: **respaldar → verificar → crear USB → BIOS →
instalar**. Nada irreversible (formatear, clonar sobre destino) sin confirmar.

## 1. Respaldo y licencia (en Windows, antes de nada)
- **Clave OEM** (PowerShell admin): `(Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey`.
- **Vincular la licencia digital a la cuenta Microsoft** (Configuración → Sistema →
  Activación → Añadir cuenta): en Win11 la activación suele ser digital ligada a HW/cuenta.
- **BitLocker**: guardar clave de recuperación (account.microsoft.com/devices). Si se va a
  CLONAR, desactivar BitLocker antes (o el clon queda cifrado).
- **Desactivar Inicio rápido / Fast Startup** (Opciones de energía) antes de apagar.
- Copiar datos personales aparte + lista de programas instalados.

## 2. Clonar el disco (imagen completa, gratis)
- Clonezilla — https://clonezilla.org/  (FOSS, imagen/clonado, arranca desde USB propio).
- Rescuezilla — https://rescuezilla.com/  (GUI sobre Clonezilla, más fácil).
- Veeam Agent for Microsoft Windows (FREE) — https://www.veeam.com/ (sección Free) — imagen a nivel de disco.
- Nota: **Macrium Reflect Free** fue descontinuado; no enviar ahí esperando gratis.

## 3. Descargar y verificar CachyOS
- Página oficial: https://cachyos.org/download/ · Wiki de validación:
  https://wiki.cachyos.org/cachyos_basic/download/ · Mirror: https://mirror.cachyos.org/ISO/
- Edición: **Desktop x86_64** (build con fecha YYMMDD; coger la más reciente). Hay Handheld/Server.
- Verificar SHA256 antes de escribir:
  - Windows (PowerShell): `certUtil -hashfile <iso> SHA256` y comparar con el `.sha256`.
  - Linux/Mac: `sha256sum -c cachyos-desktop-linux-*.iso.sha256`.

## 4. Crear el USB (≥ 8 GB)
- **Ventoy (recomendado)** — https://www.ventoy.net/ : Ventoy2Disk → Option → Partition
  Style **GPT** → Install (⚠️ formatea el USB). Luego COPIAR la ISO al USB (multi-ISO).
- **Rufus** — https://rufus.ie/ : ISO + esquema **GPT** + destino **UEFI (non-CSM)**; al
  START elegir **DD Image mode** para ISOs Arch (isohybrid).
- **YUMI** — https://www.yumiusb.com/ (multiboot; con Arch a veces da fricción UEFI → preferir Ventoy).
- **balenaEtcher** — https://etcher.balena.io/ (flasheo simple DD, una ISO).
- Aviso: confirmar que se descarga del dominio oficial (evitar typosquatting).

## 5. BIOS del mini PC (Firebat) antes de instalar
- **Secure Boot: Disabled** (reactivable luego con sbctl).
- **CSM/Legacy: Disabled** → **UEFI puro**. **Fast Boot (BIOS): Disabled**.
- **SVM Mode (AMD-V): Enabled** (Advanced → CPU) para KVM/QEMU (Fase 4).
- Orden de arranque: USB primero (o menú de arranque F7/F11/F12 según placa; entrar con Supr/F2).
- (DDR5) EXPO opcional; dejar Auto por estabilidad si hay dudas.

## 6. Instalar (Calamares) y enlazar con el baseline
- Idioma español; kernel **cachyos**; escritorio **mínimo/None** si se ofrece (el WM se
  decide en Fase 2); filesystem **Btrfs** (encaja con snapper del baseline); **borrar disco**;
  bootloader por defecto; crear usuario; instalar; reiniciar y quitar USB.
- Tras arrancar → **Fase 1F baseline** (skill `cachyos-baseline`, playbook `fase-1-baseline/`).
