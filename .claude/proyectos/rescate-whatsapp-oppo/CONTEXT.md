# Contexto — rescate-whatsapp-oppo

## Dispositivo y entorno
- **Móvil:** OPPO Find X5 (Android, ColorOS). Conectado por USB al PC Windows (modo transferencia de archivos/MTP).
- **Ruta de WhatsApp vista desde Windows:**
  `Este equipo\OPPO Find X5\Memoria interna\Android\media\com.whatsapp\WhatsApp`
  (en el móvil: `/sdcard/Android/media/com.whatsapp/WhatsApp/`)
- **WhatsApp Web:** sesión abierta en **Opera** en el PC con **todos los chats visibles** (incluidos grupos y archivados).
- La sesión de Claude Code en la nube no tiene acceso al móvil ni al PC; por eso se continúa en local.

## Qué pasó (relato del usuario, 2026-10-19)
1. El móvil tenía **muy poco espacio libre**; WhatsApp tardaba mucho en abrir.
2. Tras cerrar la app y volver a entrar, **todos los chats aparecían vacíos** (grupos sin mensajes).
3. El móvil "parece que ha liberado espacio": sólo ha desaparecido el historial de WhatsApp.
4. Después el usuario **reinició** el móvil y **actualizó WhatsApp** a la última versión (no tenía la última). Ninguna de las dos cosas borra copias.
5. En WhatsApp Web el historial sigue entero. Ya ha **exportado algunas conversaciones** desde Web.
6. **Última copia en Google Drive: de hace unos meses** → no sirve como opción principal (se perderían meses).

## Diagnóstico probable
- Con el almacenamiento lleno, la base de datos interna (`/data/data/com.whatsapp/databases/msgstore.db`)
  se corrompió o se vació, o la limpieza automática de ColorOS ("liberar espacio") borró los datos de la app.
- La base interna **no es accesible sin root** (y rootear un OPPO obliga a borrar el teléfono → descartado).
- Recuperar el archivo borrado con programas de recuperación **no es viable**: almacenamiento cifrado (FBE) + TRIM.
  Se desaconsejan programas tipo Dr.Fone/iMyFone (de pago y con poca o ninguna eficacia).

## Lo que sí se puede salvar
1. **Copias locales diarias** en `...\WhatsApp\Databases\`:
   - `msgstore.db.crypt14` (o `.crypt15` si la copia está cifrada E2E) = la más reciente.
   - `msgstore-AAAA-MM-DD.1.db.crypt14` = copias de días anteriores (unos 7 días).
   - Se generan cada noche (~02:00). **Riesgo:** las noches siguientes se guardan copias del estado vacío y van rotando las buenas.
   - Están cifradas con una clave guardada en el teléfono: **no se pueden leer en el PC**, sólo restaurar en el móvil con el mismo número.
2. **WhatsApp Web (Opera):** lectura y exportación de chats. Su historial **se pierde** cuando el móvil se vuelva a registrar o restaurar
   (se desconectan los dispositivos vinculados). Hay que exportar lo importante ANTES de la fase 4.
3. **Contactos:** están en la agenda del móvil / cuenta Google (contacts.google.com), no dependen de WhatsApp.
4. **Multimedia:** fotos, vídeos y audios siguen en `...\WhatsApp\Media\` (no se borran con la base de datos).

## Reglas para esta recuperación
- Nada destructivo (borrar datos de la app, desinstalar, renombrar en el móvil, quitar cuenta Google) sin confirmación expresa.
- Copiar siempre, nunca mover. Mantener la copia del PC intacta como "original"; trabajar sobre otra copia.
- No cerrar la sesión de WhatsApp Web ni borrar datos de Opera hasta terminar.
