# FASE 0 · Windows 11: inventario, backup, clave y preparación de la ISO (guía paso a paso)

> v2.0 · 20-oct-2026 · La ejecuta Iñaki **en el propio Firebat, todavía con Windows**. Nada de esta fase borra el disco interno.
> Versiones y enlaces: [`VERSIONES.md`](./VERSIONES.md) · Normas: [`CLAUDE.md`](./CLAUDE.md) · Registro: [`bitacora.md`](./bitacora.md).
> Sustituye a la guía v1 de septiembre (en [`v1-2026-09/`](./v1-2026-09/), solo histórico).
> **No pegues claves, números de serie ni UUID en el chat ni en el repo.**

Necesitas: disco externo (≥ espacio ocupado en el NVMe + datos), USB ≥ 16 GB y teclado **con cable**.

## Conflictos de hardware que se resuelven en el paso 0.1
- **CPU:** declarada en sept-2026 como Ryzen 7 8745H / "Ryzen 7 H 255"; el original dice "Ryzen AI 9 HX 255", que **no existe** en el catálogo de AMD (contexto maestro §2, fuente amd.com, 20-oct-2026) → INDICIO: H 255.
- **Disco:** 512 GB (sept-2026) frente a 1 TB (oct-2026) → NO VERIFICADO.
- **RAM:** "soldada, 16 GB" (Iñaki) frente a "SO-DIMM hasta 64 GB" (ficha del F1 P) → NO VERIFICADO.
- **2.º M.2 libre** (para el SSD de prueba de la ruta C) → NO VERIFICADO.

## Paso 0.1 · Inventario sin datos sensibles (PowerShell normal)
```powershell
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model
Get-CimInstance Win32_PhysicalMemory | Select-Object DeviceLocator, Capacity, Speed, FormFactor
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, Size
Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate
Get-NetAdapter | Select-Object Name, InterfaceDescription, LinkSpeed
```
- `FormFactor 12` = SO-DIMM (módulo), lo que **indica** que es ampliable. Otro valor, o un solo `DeviceLocator` sin hueco libre, apunta a RAM soldada. Se confirma en el paso 1.1.
- Copia la salida a `bitacora.md`. Estos comandos no muestran números de serie; no añadas `SerialNumber`.
- ↳ **Si falla** (`Get-CimInstance` no reconocido o con error): usa `systeminfo` y *Administrador de tareas → Rendimiento* (CPU, memoria y disco). Si no se ve el 2.º M.2, se confirma desde el USB live en el paso 1.1.

## Paso 0.2 · Licencia de Windows
1. **Configuración → Sistema → Activación** debe decir *"activado con una licencia digital vinculada a tu cuenta Microsoft"*. Si no lo dice: **Añadir una cuenta**.
2. Clave OEM del firmware, en PowerShell **como administrador**:
   ```powershell
   (Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey
   ```
   Guárdala en tu gestor de contraseñas, **fuera del repo y del chat**.
- ↳ **Si sale vacía:** la licencia es solo digital; con el punto 1 basta. Comprueba el canal con `slmgr /dli`.
- ↳ **Si no aparece "Añadir una cuenta":** inicia sesión en Windows con tu cuenta Microsoft y repite el punto 1.

## Paso 0.3 · BitLocker y Fast Startup (PowerShell como administrador)
```powershell
manage-bde -status C:          # mira "Estado de la protección" y "Porcentaje cifrado"
manage-bde -off C:             # SOLO si la protección está activada; descifra (tarda)
manage-bde -status C:          # repite hasta "Totalmente descifrado"
powercfg /h off                # desactiva la hibernación y el Inicio rápido (se revierte con: powercfg /h on)
```
Antes de descifrar, guarda la clave de recuperación desde https://account.microsoft.com/devices/recoverykey.
- ↳ **Si `manage-bde` no existe** (Windows Home): *Configuración → Privacidad y seguridad → Cifrado del dispositivo* → **Desactivado**.
- ↳ **Si el descifrado no avanza:** no apagues el equipo; déjalo enchufado. Si se queda parado, `manage-bde -resume C:`.

## Paso 0.4 · Datos personales y lista de programas
```powershell
winget export -o "$HOME\Desktop\programas-windows.json"
```
Copia `Documentos`, `Escritorio`, `Imágenes`, `Descargas` y `programas-windows.json` al disco externo. Es un respaldo **aparte** de la imagen del paso 0.8.
- ↳ **Si `winget` falla:** `Get-Package | Select-Object Name, Version | Out-File "$HOME\Desktop\programas-windows.txt"`.

## Paso 0.5 · Descargar las ISOs y comprobar su integridad (SHA256)
1. Descarga de [`VERSIONES.md`](./VERSIONES.md) estos tres ficheros de cada ISO (`.iso`, `.sha256`, `.sig`):
   - CachyOS `260809`.
   - Omarchy `4.0.6`, solo si contemplas la ruta A.
   - Además, la ISO de **Rescuezilla 2.6.2**. Si su página de release publica el SHA256 (NO VERIFICADO), compruébala también con el script del punto 2 (usa `-Sha256` si el fichero tiene otro nombre).
2. Copia [`scripts/Verificar-ISO.ps1`](./scripts/Verificar-ISO.ps1) a la carpeta de descargas y ejecuta:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Verificar-ISO.ps1 -Iso .\cachyos-desktop-linux-260809.iso
   powershell -ExecutionPolicy Bypass -File .\Verificar-ISO.ps1 -Iso .\omarchy-4.0.6.iso
   ```
   Solo vale `RESULTADO: OK` (código 0). Códigos: 1 = no coincide · 2 = falta un fichero · 3 = `.sha256` no válido.
- ↳ **Si da 1 (no coincide):** borra la ISO y descárgala de nuevo (si se repite, desde el mirror alternativo de `VERSIONES.md`).
- ↳ **Si el script no se puede ejecutar:** `certutil -hashfile .\cachyos-desktop-linux-260809.iso SHA256` y compara a ojo con el contenido del `.sha256`.

## Paso 0.6 · Autenticidad: firma GPG (Gpg4win 5.1.1)
Instala Gpg4win (https://www.gpg4win.org/download.html). En PowerShell, en la carpeta de descargas:
```powershell
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 882DCFE48E2051D48E2562ABF3B607488DB35A47
gpg --verify .\cachyos-desktop-linux-260809.iso.sig .\cachyos-desktop-linux-260809.iso
```
Válido solo con `Good signature` **y** la huella `882D CFE4 8E20 51D4 8E25 62AB F3B6 0748 8DB3 5A47`. El aviso *"This key is not certified"* es normal. Una firma mala o una huella distinta → **no uses la ISO**.
- ↳ **Si el keyserver no responde:** usa el que indica la wiki de CachyOS: `gpg --keyserver hkps://keys.openpgp.org --recv-key F3B607488DB35A47`. Si importa la clave "sin user ID", vuelve a probar con el primero más tarde.
- ↳ **Si `gpg` no se reconoce:** cierra y abre PowerShell después de instalar Gpg4win, o usa Kleopatra (*Archivo → Descifrar/Verificar*).
- ↳ **Omarchy:** la huella de su clave de firma está NO VERIFICADO. Hasta confirmarla, la ISO de Omarchy solo queda verificada por SHA256 (anótalo en la bitácora). Guarda su `.sig` junto a la ISO para verificarla cuando tengas la huella oficial.

## Paso 0.7 · USB multiarranque (Ventoy 1.1.18)
1. Descomprime Ventoy → `Ventoy2Disk.exe` → elige el **USB** (comprueba la letra y el tamaño) → *Opción → Estilo de partición → **GPT*** y *Opción → **Soporte de Secure Boot*** activado → **Instalar**. ⚠️ Borra **el USB**, no el disco interno.
2. Copia en la partición `Ventoy` del USB las ISOs de **Rescuezilla** y **CachyOS** ya verificadas.
- ↳ **Si al arrancar sale "Verification failed: (0x1A) Security Violation"** (Secure Boot todavía activo): pulsa *OK* → *Enroll key from disk* → USB → `ENROLL_THIS_KEY_IN_MOKMANAGER.cer` → *Continue* → *Yes* → *Reboot* (procedimiento de Ventoy; los textos exactos pueden variar: NO VERIFICADO en tu BIOS). Otra opción: adelanta ahora el *Secure Boot → Off* del paso 0.9. Windows arranca igual sin Secure Boot, y como BitLocker ya está descifrado (paso 0.3) no te pedirá la clave de recuperación.
- ↳ **Si el Firebat no arranca el USB de Ventoy:** graba una ISO por USB con **Rufus 4.15** (GPT, UEFI (no CSM) y, si pregunta, *modo DD*) o con **balenaEtcher 2.1.8**.
- ↳ **ISO de Omarchy (ruta A):** se graba según su manual, con **balenaEtcher**, en un USB **aparte**. Que funcione con Ventoy: NO VERIFICADO.

## Paso 0.8 · Imagen completa del disco y su verificación (Rescuezilla 2.6.2)
1. Reinicia y abre el menú de arranque (tecla NO VERIFICADO en tu unidad: prueba F7, F11 o F12, o Supr/F2 para la BIOS) → USB → Ventoy → **Rescuezilla**.
2. **Backup** → origen: **disco interno (NVMe)** → destino: **disco externo** → nombre `firebat-win11-AAAA-MM-DD`.
3. **Verify Image** al terminar (que exista en tu versión: NO VERIFICADO).
4. **Prueba de lectura:** abre *Image Explorer*, monta la imagen y copia un fichero tuyo fuera de ella.
5. **Restauración de prueba** (la pide el maestro): restaura sobre un **SSD de prueba** o un disco vacío **de igual o mayor capacidad que el NVMe original**, **nunca sobre el NVMe interno**.
- ↳ **Si Rescuezilla no arranca o no ve el NVMe:** **Clonezilla live 3.3.3-37** (https://clonezilla.org/downloads.php) → `device-image` → `savedisk`, dejando activa la comprobación *"check the saved image"*.
- ↳ **Si no tienes disco para la restauración de prueba:** anótalo como pendiente. La PUERTA 0 no se cierra sin esa prueba o sin que asumas el riesgo **por escrito** en la bitácora.

## Paso 0.9 · BIOS/UEFI: anotar ahora y cambiar al empezar la Fase 1
**Haz foto de los valores actuales** antes de tocar nada (es tu forma de volver atrás). Valores objetivo:
- **Secure Boot → Off** (y **TPM → Off**, solo para la ruta A, porque lo exige el manual de Omarchy).
- **CSM/Legacy → Off** (UEFI puro) · **Fast Boot → Off** · **SVM (AMD-V) → On**.
- Memoria de vídeo **UMA**: déjala como está (se decide en la fase de IA).
- **No actualices la BIOS** sin confirmar el modelo y descargarla de la web oficial de Firebat (NO VERIFICADO).
- ↳ **Si no encuentras una opción:** suele estar en *Advanced → CPU Configuration* (SVM) o en *Security/Boot* (Secure Boot). Anota que no existe y sigue.
- ↳ **Si el equipo no arranca tras un cambio:** restaura los valores de la foto, o *Load Optimized Defaults*.

## PUERTA 0 · criterio de salida (todo marcado o decidido por escrito)
- [ ] Inventario 0.1 en la bitácora y conflictos de hardware anotados.
- [ ] Licencia vinculada a la cuenta Microsoft y clave OEM guardada fuera del repo.
- [ ] BitLocker descifrado (o nunca activado) y `powercfg /h off` aplicado.
- [ ] Datos personales y lista de programas en el disco externo.
- [ ] ISO de CachyOS con SHA256 **OK** y firma **Good signature** con la huella correcta.
- [ ] Imagen completa **verificada**, prueba de lectura y **restauración de prueba** hechas (o riesgo asumido por escrito).
- [ ] El USB arranca en el Firebat y muestra el menú de Ventoy.
- [ ] Foto de los valores actuales de la BIOS guardada (paso 0.9).
**Sin la PUERTA 0 cerrada no se empieza la Fase 1.** Siguiente: [`FASE1.md`](./FASE1.md).
