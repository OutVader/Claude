# Procedimiento de recuperación — rescate-whatsapp-oppo
Por fases. Confirmar cada paso antes de seguir.

## Fase 0 — Proteger (ya)
- WhatsApp → Ajustes → Chats → Copia de seguridad → **Copia en Google Drive: "Nunca"**. No pulsar "Guardar".
  (Así no se sobrescribe la copia de Drive, aunque sea vieja.)
- No cerrar sesión de WhatsApp Web en Opera ni borrar datos del navegador.
- No desinstalar WhatsApp ni "Borrar datos" todavía.
- Seguir **exportando desde Web** los chats importantes (sobre todo los mensajes recientes).
- Opcional: activar el modo avión por la noche no evita la copia local; lo que protege es copiar la carpeta (fase 1).

## Fase 1 — Copia al PC (urgente, antes de las 02:00)
Opción A, Explorador de Windows (MTP): copiar la carpeta completa
`Este equipo\OPPO Find X5\Memoria interna\Android\media\com.whatsapp\WhatsApp` → `C:\Rescate_WhatsApp\ORIGINAL\`.
Como mínimo, copiar primero `Databases` (es pequeña) y después `Media` (grande).

Opción B, ADB (más fiable que MTP para carpetas grandes; requiere depuración USB activada):
```powershell
# platform-tools de Google: https://developer.android.com/tools/releases/platform-tools
adb devices
adb pull /sdcard/Android/media/com.whatsapp/WhatsApp/Databases C:\Rescate_WhatsApp\ORIGINAL\Databases
adb pull /sdcard/Android/media/com.whatsapp/WhatsApp C:\Rescate_WhatsApp\ORIGINAL\WhatsApp
```
Después: hacer una segunda copia `C:\Rescate_WhatsApp\TRABAJO\` para manipular.

## Fase 2 — Inventario de copias
```powershell
Get-ChildItem C:\Rescate_WhatsApp\ORIGINAL\Databases | Sort-Object LastWriteTime |
  Format-Table Name, LastWriteTime, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
```
- Elegir la **más reciente cuyo tamaño sea "normal"** (similar a las anteriores). La que haya caído de tamaño de golpe = vacía.
- Comprobar la extensión: `.crypt14` (cifrado normal) o `.crypt15` (copia cifrada E2E, hace falta contraseña o clave de 64 dígitos).

## Fase 3 — Liberar espacio en el móvil
- Dejar **varios GB libres** (ideal más de 5 GB) o la restauración puede volver a fallar.
- Mover fotos/vídeos al PC, borrar apps que no se usen, vaciar la papelera de la galería.
- **No** usar la "limpieza" de ColorOS sobre WhatsApp.

## Fase 4 — Restaurar desde la copia local (CONFIRMAR ANTES)
Antes: exportados los chats recientes desde Web (se pierde la sesión de Web) y copia del PC verificada.

1. En el móvil, en `Android/media/com.whatsapp/WhatsApp/Databases/`:
   - Renombrar el actual `msgstore.db.crypt14` → `msgstore.db.crypt14.vacio` (si es la copia vacía).
   - Renombrar la copia elegida `msgstore-AAAA-MM-DD.1.db.crypt14` → `msgstore.db.crypt14`.
   (Si MTP no deja renombrar: hacerlo en el PC sobre `TRABAJO\` y volver a copiar al móvil, o con `adb shell mv`.)
2. Evitar que WhatsApp ofrezca la copia de Drive (de hace meses). Opciones, de menos a más invasiva:
   - a) Al restaurar, si WhatsApp compara y propone la copia local más reciente, aceptarla.
   - b) Quitar temporalmente la cuenta de Google del móvil (Ajustes → Usuarios y cuentas) durante la restauración y volver a añadirla después.
   - c) Último recurso: borrar la copia de Drive (drive.google.com → Almacenamiento → Copias de seguridad). **Irreversible** → sólo con confirmación.
3. Ajustes de Android → Aplicaciones → WhatsApp → Almacenamiento → **Borrar datos** (mejor que desinstalar: conserva `Android/media`).
   Si se desinstala, comprobar antes de abrir la app que `Databases` sigue ahí; si no, volver a copiarla desde el PC.
4. Abrir WhatsApp → verificar **el mismo número** → aceptar permisos → **Restaurar**. No pulsar "Omitir".
5. Esperar a que termine (los archivos multimedia se reindexan después).

## Fase 5 — Verificar y dejarlo protegido
- Revisar grupos y chats clave; los mensajes posteriores a la copia elegida → están en las exportaciones de Web.
- Volver a vincular WhatsApp Web si se quiere.
- Activar la copia en Google Drive (diaria) y hacer una copia manual al terminar.
- Mantener espacio libre en el móvil.
