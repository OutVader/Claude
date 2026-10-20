# Herramientas forenses y ADB — rescate-whatsapp-oppo
Para usar desde el **equipo personal** (en el de trabajo ADB y estas herramientas están bloqueados).
Todo lo de este documento es de **solo lectura o copia**, salvo lo marcado ⚠️.

## Qué se puede y qué no (sin root)
| Fuente | ¿Accesible? | Uso |
|---|---|---|
| `/sdcard/Android/media/com.whatsapp/WhatsApp/Databases` (copias diarias `msgstore*.crypt14/15`) | ✅ ADB / MTP | **Vía principal**: restaurar en el móvil |
| `/sdcard/WhatsApp/Databases` (ruta antigua) | ✅ ADB / MTP | Posibles copias antiguas olvidadas |
| `/sdcard/Android/media/com.whatsapp/WhatsApp/Media` | ✅ | Fotos, vídeos, audios (siguen ahí) |
| `/data/data/com.whatsapp/` (base viva `msgstore.db` + clave `files/key`) | ❌ sin root | Rootear un OPPO borra el teléfono → descartado |
| Archivo borrado (carving) | ❌ | Almacenamiento cifrado (FBE) + TRIM → no recuperable |
| **Rootear el OPPO** | ❌ **NO** | Exige desbloquear el bootloader → **borrado total** (incluye `/sdcard` con las copias). La base vieja ya no existe en `/data` |
| `adb backup` + WhatsApp antiguo (truco "downgrade") | ❌ | Ya no funciona en Android/WhatsApp actuales |
| WhatsApp Web en **Brave del PC del trabajo** | ✅ mientras siga la sesión | **Única copia completa y actual** → exportar/archivar |
| Google Drive | ⚠️ solo 1 copia (la última, de hace meses) | Último recurso; **no borrar** |
| Google Takeout | ❌ | No exporta las copias de WhatsApp (zona oculta de apps) |

**Clave:** las copias `.crypt14` están cifradas con una clave que vive en `/data` → **no se pueden leer en el PC**, solo restaurar en el móvil.
**Excepción:** si la copia es **`.crypt15` con cifrado E2E** y tienes la **clave de 64 dígitos** (no la contraseña), se puede descifrar en el PC
con [`wa-crypt-tools`](https://github.com/ElDavoo/wa-crypt-tools) y leer los mensajes (p. ej. con `whatsapp-chat-exporter`) **sin tocar el móvil**.
Así se puede **comprobar qué copia tiene los chats antes de restaurar**.

## 1. Preparar ADB (equipo personal)
1. Descargar **platform-tools** oficiales: https://developer.android.com/tools/releases/platform-tools (descomprimir en `C:\platform-tools`).
2. Móvil: Ajustes → Acerca del teléfono → pulsar 7 veces "Versión" → Opciones de desarrollador → **Depuración USB** ON.
3. Conectar por USB, aceptar la huella RSA en el móvil.
```powershell
cd C:\platform-tools
.\adb devices          # debe salir el número de serie con "device"
```

## 2. Inventario (solo lectura)
```powershell
.\adb shell ls -la /sdcard/Android/media/com.whatsapp/WhatsApp/Databases
.\adb shell ls -la /sdcard/WhatsApp/Databases
.\adb shell "find /sdcard -iname 'msgstore*' 2>/dev/null"
.\adb shell "find /sdcard -iname '*.crypt1*' 2>/dev/null"
.\adb shell df -h /data                         # espacio libre
.\adb shell dumpsys package com.whatsapp | findstr versionName
```

## 3. Adquisición (copia íntegra al PC + hashes)
```powershell
$D = "D:\Rescate_WhatsApp\ORIGINAL"   # disco del equipo personal
mkdir $D
.\adb pull /sdcard/Android/media/com.whatsapp/WhatsApp "$D\WhatsApp_media"
.\adb pull /sdcard/WhatsApp "$D\WhatsApp_legacy"        # si existe
# Hashes para cadena de custodia / comprobar que no cambian
Get-ChildItem "$D" -Recurse -Filter "msgstore*" | Get-FileHash -Algorithm SHA256 |
  Export-Csv "$D\hashes_msgstore.csv" -NoTypeInformation
Get-ChildItem "$D" -Recurse -Filter "msgstore*" | Sort-Object LastWriteTime |
  Format-Table FullName, LastWriteTime, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
```
Trabajar siempre sobre una copia (`TRABAJO\`), nunca sobre `ORIGINAL\`.

## 4. Preservar WhatsApp Web (PC del trabajo, Brave)
WhatsApp **no permite volcar el historial de Web/Escritorio al móvil**: Web es la fuente para **archivar**, no para restaurar.
Un dispositivo vinculado nuevo (p. ej. Web en el equipo personal) **solo recibe historial del móvil**, que está vacío → no copiaría nada.
Por eso la sesión de Brave del trabajo es irrepetible:
- **No cerrar sesión**, no borrar datos de Brave, no "Cerrar sesión en todos los dispositivos" desde el móvil.
- Al **restaurar o volver a registrar** WhatsApp en el móvil, Web se desconecta y su historial se pierde → **archivar antes de la fase 4**.
- Exportar: chat a chat (lo que ya se hizo) o con una herramienta de volcado del navegador (técnica de *live acquisition* por consola JS,
  ver Soares 2022, SCITEPRESS). ⚠️ Las extensiones que leen WhatsApp Web ven **todos** los chats: usar solo código abierto y revisado,
  y valorar la política del PC corporativo antes de instalar nada.
- Preservación en bruto (sin garantía de poder descifrarlo): con Brave cerrado, copiar el perfil (si se usa otro perfil de Brave, cambiar `Default` por `Profile N`)
  `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\IndexedDB\https_web.whatsapp.com_0.indexeddb.leveldb` (y `Local Storage`) a otra carpeta.
- Resultado: un archivo (HTML/JSON/TXT) legible de todos los chats, aunque no vuelva a entrar en la app.

## 4b. ¿Y rootear? — NO
- Rootear exige **desbloquear el bootloader**, y eso hace **siempre un borrado de fábrica**: se pierde `/data` **y también la memoria interna**
  (`/sdcard`, con las copias `msgstore*` y la multimedia). Sería destruir justo lo que queremos salvar.
- En el **Find X5**, OPPO no ofrece desbloqueo oficial en la mayoría de regiones (solo métodos no oficiales con riesgo de brickeo y pérdida de garantía).
- Aunque se consiguiera root, la base antigua de `/data` ya fue borrada o sobrescrita por la nueva vacía; y la clave `files/key` que descifraría los `.crypt14`
  desaparecería con el borrado.
- Las **Opciones de desarrollador** sirven solo para **Depuración USB** (ADB). **No activar "Desbloqueo OEM"** ni usar herramientas de desbloqueo.

## 5. Herramientas forenses: utilidad real aquí
| Herramienta | ¿Sirve en este caso? |
|---|---|
| ADB platform-tools | ✅ Inventario y copia de `Databases`/`Media` |
| wa-crypt-tools (+ whatsapp-chat-exporter) | ✅ solo si `.crypt15` E2E con **clave de 64 dígitos**; si no, no |
| ALEAPP / Autopsy / Andriller | ⚠️ poco: sin `/data` no hay base de WhatsApp que analizar |
| Cellebrite / MOBILedit / Belkasoft | ❌ requieren root/exploit para `/data` en Android moderno; caros |
| Dr.Fone, iMyFone, etc. | ❌ de pago y sin eficacia real; evitar |
| MVT (Amnesty) | ❌ es para detectar spyware, no para recuperar |

## 6. Ideas del artículo de Xataka (jun 2026)
Google está llevando la gestión de copias de WhatsApp a los **ajustes de Android** (Servicios de Google Play, despliegue gradual).
Sirve para **ver fechas y gestionar** la copia, pero la sigue creando WhatsApp: **no recupera nada que no se haya copiado** y no consta que guarde varias versiones.
Útil solo para comprobar en Ajustes → Google → Copia de seguridad si aparece una copia de WhatsApp más reciente que la de la app.

## 7. Otras comprobaciones en el OPPO
- Gestor de archivos → **Eliminados recientemente** (ColorOS guarda ~30 días).
- Ajustes → Ajustes adicionales → **Copia de seguridad y migración** (copias locales de ColorOS antiguas).

## Fuentes
- Hilo Google Drive (copias anteriores): https://support.google.com/drive/thread/2246683
- Xataka Móvil, 18/06/2026: https://www.xatakamovil.com/aplicaciones/copia-whatsapp-era-punto-debil-al-cambiar-movil-google-empieza-a-arreglarlo-propios-ajustes-android
- Soares (2022), extracción de WhatsApp Web: https://www.scitepress.org/Papers/2022/110064/110064.pdf
- Belkasoft, Android WhatsApp forensics: https://belkasoft.com/android-whatsapp-forensics-analysis
