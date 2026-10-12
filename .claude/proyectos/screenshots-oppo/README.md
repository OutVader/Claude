# Proyecto: screenshots-oppo
Vaciar la carpeta *Screenshots* del móvil **OPPO** al PC **por años y por bloques**, vía **ADB**,
verificando cada archivo antes de borrarlo del móvil.

- **Usuario:** Iñaki — PC Windows de trabajo + móvil OPPO por USB
- **Hogar definitivo:** `AGENTES_WD\.claude\Proyectos\Screenshots-OPPO` (lo instala `00-Instalar-en-AGENTES_WD.ps1`)
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)
- **Seguir en una conversación nueva:** [`HANDOFF-CONTEXTO.md`](./HANDOFF-CONTEXTO.md) + [`PROMPT-NUEVA-CONVERSACION.md`](./PROMPT-NUEVA-CONVERSACION.md) → v2 genérica en `AGENTES_WD\.claude\Proyectos\Traspaso-Archivos`

## Estado
| Hito | Contenido | Estado |
|---|---|---|
| 0 | Proyecto creado en AGENTES_WD + recuperar la memoria y los scripts del intento anterior | ⏳ pendiente de ejecutar en el PC |
| 1 | Inventario por año en el móvil (`-SoloInventario`) | ⏳ |
| 2 | **2023**: copiar → verificar → borrar del móvil | ▶ a medias (según la memoria) |
| 3 | Resto de años, uno a uno | ⏳ |
| 4 | Cierre: el móvil sin capturas antiguas y el registro CSV completo | ⏳ |

## Uso (PowerShell, en `scripts\`)
```powershell
# 0) Instalar en AGENTES_WD y ver qué se hizo la otra vez (simula; luego -Aplicar)
.\00-Instalar-en-AGENTES_WD.ps1
.\00-Instalar-en-AGENTES_WD.ps1 -Aplicar

# 1) Inventario: capturas y MB por año (no copia nada)
.\01-Vaciar-Screenshots.ps1 -SoloInventario

# 2) Copiar un año (sin borrar), en bloques de 200 con pausa
.\01-Vaciar-Screenshots.ps1 -Anio 2023 -Destino '<carpeta destino>'

# 3) Repetir con -Borrar: no descarga lo ya copiado; borra del móvil solo lo verificado
.\01-Vaciar-Screenshots.ps1 -Anio 2023 -Destino '<carpeta destino>' -Borrar
```
Requisitos: `adb` (Android platform-tools) en el PATH o con `-Adb 'C:\ruta\adb.exe'`, la
depuración USB activada en el OPPO y el PC autorizado (`adb devices` → `device`).

## Garantías del script
- No borra nada sin `-Borrar` **y** sin escribir `BORRAR` para confirmar.
- Borra **archivo a archivo** y solo si la copia local existe **y tiene el mismo tamaño**.
- Se puede reanudar: lo que ya se copió no se vuelve a descargar. Hay un registro en `<Destino>\_registro-screenshots.csv`.
- `adb pull -a` conserva la fecha original de cada captura.

## Decisiones pendientes
- [ ] **Carpeta destino** de las capturas (¿la misma que usaste para 2023? estará en la memoria original → hito 0).
- [ ] ¿Organizar por `<Destino>\<Año>\` (por defecto) o también por mes?
