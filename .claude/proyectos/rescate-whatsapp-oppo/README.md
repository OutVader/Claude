# Proyecto: rescate-whatsapp-oppo
Recuperar el historial de chats de WhatsApp desaparecido en el OPPO Find X5 sin perder los mensajes recientes.

- **Usuario:** Iñaki — admin de sistemas (Windows/AD); el móvil está conectado por USB a su PC Windows.
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Procedimiento:** [`PROCEDIMIENTO.md`](./PROCEDIMIENTO.md) · **Forense/ADB:** [`FORENSE-ADB.md`](./FORENSE-ADB.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)

## ⚠️ Prioridad absoluta (antes de las 02:00)
WhatsApp hace una **copia local automática cada noche (~02:00)** y conserva sólo unos 7 días.
Si no se copia antes la carpeta `Databases` al PC, las copias buenas se van sustituyendo por copias del estado vacío.
→ **Copiar YA** `Este equipo\OPPO Find X5\Memoria interna\Android\media\com.whatsapp\WhatsApp` entera a `C:\Rescate_WhatsApp\`.

## Estado
| Fase | Contenido | Estado |
|---|---|---|
| 0 | Proteger: no cerrar WhatsApp Web (Opera), no desinstalar/borrar datos, Drive en "Nunca", exportar chats clave desde Web | ▶ en curso (algunos chats ya exportados) |
| 1 | Copiar carpeta `com.whatsapp\WhatsApp` completa al PC (copiar, NO mover) + hashes | ⏳ pendiente — **urgente** (hay ficheros antiguos; falta inventario) |
| 1b | Archivar WhatsApp Web (Opera, PC trabajo) — única copia completa | ⏳ pendiente — antes de fase 4 |
| 2 | Inventario de `Databases\` (nombre, fecha, tamaño) → elegir la copia buena | ⏳ pendiente |
| 3 | Liberar espacio en el móvil (varios GB) | ⏳ pendiente |
| 4 | Restaurar desde copia local elegida (evitando que ofrezca la de Drive, de hace meses) | ⏳ pendiente — requiere confirmación |
| 5 | Verificación + reactivar copia en Drive + recuperar lo posterior desde exportaciones | ⏳ pendiente |

## Decisiones pendientes
- [ ] Qué copia `msgstore-AAAA-MM-DD.1.db.crypt1x` usar (la más reciente con tamaño "normal").
- [ ] Cómo evitar la restauración desde Drive (copia vieja): ver opciones en `PROCEDIMIENTO.md` fase 4.
- [ ] ¿La copia está cifrada E2E (`.crypt15`)? → hace falta contraseña o clave de 64 dígitos.

## Arranque en la sesión local (Claude Code en el PC)
Abrir Claude Code en la raíz del repo y pegar:
> Continúa el proyecto `.claude/proyectos/rescate-whatsapp-oppo`. Lee README, CONTEXT, PROCEDIMIENTO, FORENSE-ADB y bitácora.
> Estoy en mi equipo personal (Windows) con el OPPO Find X5 por USB y ADB disponible. Empieza por FORENSE-ADB §1–3:
> comprobar `adb devices`, inventario de `msgstore*` y copia íntegra con hashes. Luego dime qué copia usar. Nada destructivo sin confirmarme.
