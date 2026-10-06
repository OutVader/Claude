# Proyecto: ordenar-escritorio-windows
Dos scripts reutilizables (PowerShell y Python) para ordenar el Escritorio de Windows 11 u
otra carpeta por tipo de archivo, **siempre en modo de prueba primero**.

- **Usuario:** Iñaki — ciberseguridad y sistemas, sector público, Windows 11.
- **Contexto:** [`CONTEXT.md`](./CONTEXT.md) · **Bitácora:** [`bitacora.md`](./bitacora.md)
- **Prompt mejorado:** [`PROMPT-mejorado.md`](./PROMPT-mejorado.md)
- **Scripts y manual:** [`scripts/`](./scripts/) → [`scripts/README.md`](./scripts/README.md)

## Estado
| Hito | Contenido | Estado |
|---|---|---|
| 1 | Prompt original revisado y mejorado (tendencias oct-2026) | ✅ |
| 2 | `ordenar_archivos.py` + `Ordenar-Archivos.ps1` + `mapeo-extensiones.json` | ✅ |
| 3 | Sandbox (`crear_sandbox.*`) y pruebas a–h (`ejecutar_pruebas.py`) | ✅ 16/16 en Linux (Python 3.13, pwsh 7.4) |
| 4 | Prueba en Windows 11 real (PS 5.1, PS 7.6, Python) sobre sandbox | ⏳ pendiente (lo ejecuta Iñaki) |
| 5 | Primer uso real: simulación sobre el Escritorio, revisar, luego `-Aplicar` | ⏳ pendiente |

## Reglas permanentes
- **Modo de prueba primero, siempre.** Sin `-Aplicar` solo se simula; con `-Aplicar` se
  simula, se enseña el plan y se confirma antes de ejecutarlo.
- Nunca borrar, mover ni sobrescribir sin OK. Por defecto: **simular y copiar**.
- Pruebas solo en sandbox, nunca contra el Escritorio ni rutas reales.
- Preguntar antes de hacer push o abrir un PR.

## Decisiones pendientes
- [ ] Ejecutar `py scripts\ejecutar_pruebas.py` en el Windows 11 y comprobar PS 5.1 (`--ps "$PSHOME\powershell.exe"`).
- [ ] ¿Firmar el `.ps1` con Authenticode si la política del organismo es `AllSigned`?
