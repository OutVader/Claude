# 🚀 GUÍA FASE 1 — De Windows 11 a CachyOS (inicio rápido)

> Guía corta para **empezar**. El detalle (links, comandos, opciones) está en
> [`FASE1-preinstalacion-extendida.md`](./FASE1-preinstalacion-extendida.md).
> Instalar Claude Code + cuenta Pro + permisos: [`POST-INSTALL-claude.md`](./POST-INSTALL-claude.md).
> La parte que se ejecuta EN el mini PC tras instalar está en [`fase-1-baseline/`](./fase-1-baseline/).

## Orden seguro (respaldar → verificar → USB → BIOS → instalar → baseline)

- [ ] **1. Licencia Windows.** Extrae la clave OEM y **vincula la licencia a tu cuenta Microsoft**.
      `(Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey`
- [ ] **2. BitLocker.** Guarda la clave de recuperación (account.microsoft.com/devices).
      Si vas a clonar, **desactívalo** antes.
- [ ] **3. Fast Startup OFF** en Windows (Opciones de energía) antes de apagar.
- [ ] **4. Clona el disco** entero a un disco externo (imagen completa). 3 opciones gratis:
      **Clonezilla** · **Rescuezilla** · **Veeam Agent Free**. (Links en la guía extendida.)
- [ ] **5. Copia tus datos** personales aparte + lista de programas.
- [ ] **6. Descarga CachyOS Desktop x86_64** y **verifica el SHA256**.
      Oficial: https://cachyos.org/download/ · Validación: https://wiki.cachyos.org/cachyos_basic/download/
- [ ] **7. Crea el USB** (≥8 GB). Recomendado **Ventoy** (formatea el USB y luego copias la ISO).
      Alternativas: Rufus (modo **DD**, GPT/UEFI), YUMI, balenaEtcher.
- [ ] **8. BIOS del Firebat:** Secure Boot **OFF**, CSM/Legacy **OFF** (UEFI puro),
      Fast Boot **OFF**, **SVM/AMD-V ON**, USB como primer arranque.
- [ ] **9. Instala (Calamares):** español · kernel **cachyos** · escritorio **mínimo/None**
      (el WM se decide en Fase 2) · filesystem **Btrfs** · **borrar disco** · crear usuario.
- [ ] **10. Reinicia, quita el USB.** Abre terminal → red (`nmtui` si Wi-Fi) → `sudo pacman -Syu`.
- [ ] **11. Instala Claude Code** (nativo): `curl -fsSL https://claude.ai/install.sh | bash` → `claude`.
      **Vincula tu cuenta Pro** con `/login` → *Claude account with subscription*.
- [ ] **12. Importa el proyecto:** `git clone …/OutVader/Claude.git ~/Claude` → `cd ~/Claude` → `claude`
      (autocarga `CLAUDE.md` + skills). Permisos: modo equilibrado (lista blanca + acceptEdits) o
      `--dangerously-skip-permissions` para acceso total. Detalle en `POST-INSTALL-claude.md`.
- [ ] **13. Ejecuta el baseline** (`fase-1-baseline/00-diagnostico.sh`) y seguimos desde ahí.

## Decisiones ya tomadas
- **Firewall:** firewalld. · **RAM:** soldada, techo **16 GB**. · **Escritorio:** se decide en Fase 2.

## Siguiente (Fase 2, resumen)
WM (recomendado **Hyprland + Caelestia/Noctalia**) + estética oriental (wallpapers, paleta
dinámica desde el fondo) + iconos/fuentes ya instaladas en el baseline. Detalle al final de la guía extendida.

⚠️ **Antes de formatear**: confirma que el clon del disco y los datos están a salvo. Esto es irreversible.
