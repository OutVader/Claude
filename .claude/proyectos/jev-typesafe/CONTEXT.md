# Contexto — jev-typesafe

## JEV en una línea
Modelo de decisión de TypeSafe (`typesafe/jev-1.13`, fijado: los umbrales se calibran contra esa versión).
No genera texto: recibe `state` + `questions` tipadas (`noul`, `choice`, `score`) y devuelve probabilidades.
`POST https://openrouter.ai/api/alpha/decisions` (API **alpha**), `Authorization: Bearer <key OpenRouter>`.
~0,042 $/M tokens de entrada, salida gratis, contexto 32k. **No existe versión local**: toda consulta sale a la red.

## Entorno objetivo
Windows corporativo: Check Point + Palo Alto (GlobalProtect), inspección SSL probable, filtrado de URL
("Generative AI"), DLP, operaciones restringidas, EDR/antivirus. Claude Code en Windows usa la herramienta
**PowerShell** (o Bash vía Git Bash): por eso el matcher es `Bash|PowerShell`.

## Reglas de diseño (no negociables)
1. **Fail-closed**: error de red, timeout (8 s), HTTP ≠ 200, JSON ilegible, valor fuera de 0–1, sin key →
   no aprobar y dejar el aviso normal. El hook siempre sale con código 0.
2. **La lista estática (`reglas.json`) es la frontera de seguridad**, no JEV. Lo que coincide ni se envía ni se aprueba.
3. Umbral Noul ≥ **0.90** (configurable, nunca < 0.80: se fuerza en código).
4. La key nunca en `settings.json`, logs ni chat (DPAPI en Windows).
5. Sin dependencias: PowerShell nativo (5.1/7) o Python stdlib.

## Rediseño corporativo (decidido 2026-09-27)
- **Redacción antes de enviar**: DN de AD → `<DN>`, SID → `<SID>`, correo/UPN → `<USUARIO@DOMINIO>`,
  UNC → `<UNC>`, IPs → `<IP>`, hosts `.local/.corp/.lan/...` → `<HOST>`, dominios internos (config +
  `%USERDNSDOMAIN%`) → `<DOM>`, `C:\Users\<x>` → `<USR>`, usuario/equipo actuales → `<USR>`/`<PC>`.
- **Nunca se envían**: herramientas de infraestructura/red (ssh, RDP, `net`, ds*, repadmin, ldap*,
  kerberos, `curl`/`iwr`/`irm`, `ping`, nslookup, PSRemoting, `Connect-*`) y todos los cmdlets
  AD/Exchange/Graph/Azure/Teams/SharePoint/DNS/DHCP/GPO (`*-AD*`, `*-Mailbox*`, `*-Mg*`…).
  Tampoco posibles secretos (passwords, tokens, cadenas largas tipo clave).
- **Exclusiones genéricas**: rutas UNC, `//servidor/recurso`, unidades distintas de C:, `/mnt`, `/media`,
  palabras `corp`/`trabajo`. Editables en `rutas_excluidas`.
- **Cortacircuitos**: 2 fallos seguidos → JEV suspendido 15 min (el hook sale al instante; un cortafuegos
  que descarta paquetes no cuesta 8 s por aviso).
- **Red corporativa**: PowerShell usa proxy del sistema con credenciales integradas (NTLM/Kerberos) y el
  almacén de certificados de Windows (CA de inspección incluida). Python: `proxy` y `ca_bundle` en config.
  `diag` detecta proxy, DNS, emisor TLS (posible inspección) y página de bloqueo del cortafuegos.

## Local-first (criterio de JEV sin red cuando ya se conoce)
- Cada comando se reduce a un **patrón** (`git status`, `ls -la <RUTA_EXT>`, `get-childitem -recurse <RUTA_INT>`).
  `<RUTA_INT>`/`<RUTA_EXT>` distinguen dentro/fuera del proyecto, para que un `cp` aprobado dentro no
  valga fuera.
- Orden: estática → regla local confirmada → caché (≤ 30 días) → JEV (solo patrones nuevos).
- La caché guarda solo `reversible`; `serves_task` depende de la tarea y solo se evalúa en consultas nuevas.
- Patrón aprobado ≥ 5 veces con ≥ 0.95 → **propuesta**; solo pasa a **regla** si tú la confirmas en
  `/jev-panel` (`reglas aprobar <id>`, que pide permiso a propósito).
- **Sync semanal por lotes** (hook `SessionStart`): revalida patrones caducados y la cola en **una**
  petición de hasta 20 preguntas (JEV las evalúa en paralelo).
- Modos (`red.modo`): `nuevo_y_sync` (elegido) · `solo_sync` (cero tráfico automático; lo nuevo va a cola) · `online`.
- Cada decisión muestra una línea (`systemMessage`): `[JEV] permitido · caché 8512f350 · reversible 0.97 · 2026-09-27`.
  Los errores no muestran nada (fail-closed silencioso); se ven en `/jev-panel`.

## Runtime: PowerShell primero, Python si es más óptimo
El instalador prueba cada PowerShell **ejecutando un .ps1 desde `~/.claude/jev`** (AppLocker/WDAC
filtran por ruta) y comprueba `FullLanguage`. Mide el arranque. Elige PowerShell salvo que esté bloqueado
(CLM, GPO AllSigned) o tarde ≥ 1,2 s y más del doble que Python. `-Runtime` lo fuerza.
Referencia en contenedor: hook Python ~70–180 ms; hook pwsh 7 ~700–1100 ms (arranque del motor).

## Módulos (evaluación para el entorno corporativo)
| Módulo | Envía | Veredicto |
|---|---|---|
| permisos_shell (núcleo) | comando redactado, solo si pasa la lista y es un patrón nuevo | ✅ activo |
| router_manual `/elige-skill` | tu petición redactada, solo cuando lo invocas | ✅ activo |
| `/jev-panel` (coste + criterio) | nada | ✅ activo |
| runit-admin | nada | ❌ no aplica (Windows); sustituible por un skill de servicios Windows en el futuro |
| sugeridor_auto | **cada prompt** | ❌ no en el trabajo (DLP, latencia) |
| triaje_logs | líneas de log | ❌ contenido más sensible por llamada |
| check_commit | el diff | ❌ contradictorio; si se hace, detector 100 % local |

## Limitaciones conocidas
- Solo probado en contenedor Linux: Python 3.11 y PowerShell 7.6 contra un simulador. **No probado aún**:
  Windows PowerShell 5.1 real, el descifrado DPAPI desde Python (ctypes), GlobalProtect/inspección SSL,
  ni una llamada real con key válida (la real sin key devuelve `http_401` → fail-closed, comprobado).
- La API de JEV es alpha: si cambia el formato, todo falla cerrado (aviso normal), nunca aprueba.
- Un script ejecutado por ruta o por intérprete (`.\x.ps1`, `python x.py`) nunca se auto-aprueba: JEV no ve su contenido.

## Referencias
- https://openrouter.ai/docs/guides/community/jev-tutorial
- https://openrouter.ai/docs/cookbook/coding-agents/auto-approve-permission-prompts-with-jev
- https://code.claude.com/docs/en/hooks (PermissionRequest `decision.behavior`, `systemMessage`, exec form `args`, `Bash|PowerShell`)
- https://code.claude.com/docs/en/skills (`disable-model-invocation`, `allowed-tools`, `$ARGUMENTS`)
