---
name: ahorro-tokens
description: >-
  Reduce el gasto de tokens/coste de las sesiones de Claude Code de Iñaki. Úsala
  cuando el usuario diga "ahorra tokens", "estoy gastando mucho", "por qué cuesta
  tanto", "vamos justos de límite semanal", "resume y sigue", "limpia el contexto",
  o al detectar señales de derroche: sesión muy larga, contexto >150k, uso casi
  exclusivo de Opus, MCP de navegador inyectando páginas enteras, o cambio de tema
  sin limpiar. Da la pauta de cuándo usar /compact, /clear, cambiar de modelo y
  moderar herramientas, y cómo diagnosticar el gasto con el panel de Uso.
---

# Ahorro de tokens — rol "guardián del gasto" (Iñaki)

Objetivo: que una sesión NO dispare el coste ni queme el **límite semanal**. El gasto casi
nunca está en lo que escribes tú (entrada/salida son cientos de tokens); está en el
**contexto acumulado que se relee en cada turno** (lectura de caché de millones de tokens) y
en el **modelo** con el que se relee. Atacar eso es el 90 % del ahorro.

## Regla mental (por qué se dispara)
- Cada turno **relee todo el contexto** de la sesión. Sesión larga = releer millones de
  tokens una y otra vez → "Lectura de caché" enorme aunque tus mensajes sean cortos.
- **Opus** cuesta varias veces más que **Haiku** por token. Releer contexto gigante en Opus
  es el peor caso, y es justo lo que muestra un panel con "Opus 99 %".
- Las herramientas que **inyectan texto externo** (navegador MCP, leer archivos enormes,
  volcados de comandos) engordan el contexto de forma permanente durante el resto de la sesión.

## Diagnóstico rápido (panel de Uso)
Mira el panel de Uso y decide con estos umbrales:
- **Contexto de la sesión** (barra "% ejecutado con más de 150k"): si buena parte va por
  encima de 150k → toca **/compact** o **/clear** ya.
- **Modelo**: "Opus ~99 %" en tareas simples → o baja de modelo o parte tareas triviales a
  otra sesión en Haiku.
- **Lectura de caché** en millones + coste alto → el problema es la longitud, no tus mensajes.
- **Límite semanal**: si queda poco (p. ej. <25 %) hasta el reset → modo ahorro agresivo
  (ver más abajo) y avisar a Iñaki.
- **Herramientas/MCP**: si "Claude Browser MCP" o similar encabeza el desglose → moderar su uso.

## Palanca 1 — `/compact` (resumir a mitad de tarea)
- **Cuándo**: sigues con la MISMA tarea pero el hilo ya arrastra mucha "paja" (exploración,
  salidas largas de comandos, callejones sin salida) y el contexto se acerca/supera 150k.
- **Qué hace**: resume lo anterior y descarta el detalle, conservando el objetivo. Bajas
  drásticamente la lectura de caché de los siguientes turnos **sin perder el hilo**.
- **Consejo**: cómpacta ANTES de arrancar un bloque nuevo y pesado (otra fase, otro archivo
  grande), no después.

## Palanca 2 — `/clear` (vaciar al cambiar de tema)
- **Cuándo**: **cambias de actividad** (terminas la Fase 1 y empiezas otra cosa, o pasas de
  CachyOS a un tema de Windows/Exchange sin relación).
- **Qué hace**: vacía el contexto acumulado. Los millones de tokens de la tarea anterior dejan
  de releerse → coste por turno vuelve casi a cero.
- **Regla**: **una tarea distinta = un hilo distinto.** No mantengas un chat eterno para todo.
  Si el trabajo tiene bitácora en `.claude/proyectos/<nombre>/`, puedes `/clear` sin miedo:
  el estado vive en los archivos del proyecto, no en el chat.

### `/compact` vs `/clear` — cuál usar
| Situación | Acción |
|---|---|
| Misma tarea, hilo cargado de paja | `/compact` |
| Cambio de tema/actividad | `/clear` |
| Contexto >150k y aún queda tarea | `/compact` (y si además cambias de tema, luego `/clear`) |
| Empiezas algo nuevo con proyecto/bitácora ya guardados | `/clear` |

## Palanca 3 — Modelo (no todo necesita Opus)
- Opus para lo que de verdad lo pide: diseño, decisiones de arquitectura, depuración difícil,
  redacción cuidada.
- Para tareas simples (traducir, corregir texto, renombrar, preguntas rápidas, formateo) →
  **Haiku** cuesta una fracción. Cambia con `/model` o abre una sesión aparte en Haiku para
  esos encargos triviales y así no ensucias (ni encareces) la sesión principal.
- Señal de alarma: panel con "Opus 99 %" mientras la mayoría de lo hecho era trivial.

## Palanca 4 — Moderar herramientas que inyectan contexto
- **Navegador MCP / web**: trae páginas enteras al contexto y ahí se quedan. Úsalo solo cuando
  necesites datos actualizados en tiempo real; si no, evítalo.
- Evita `cat`/volcados de archivos enormes al chat: lee solo el fragmento necesario.
- Tras una consulta web pesada que ya diste por buena, valora `/compact` para no arrastrar el
  texto crudo el resto de la sesión.

## Palanca 5 — Sesión demasiado larga → cambiar de conversación
Si tras compactar la sesión **sigue siendo enorme** o el hilo ya mezcla muchas tareas:
- **Sugiere a Iñaki cambiar de conversación** (abrir un hilo nuevo). Es lo más efectivo:
  arranca con contexto casi vacío y corta de raíz la lectura de caché acumulada.
- Antes de cambiar, deja el estado en la **bitácora del proyecto** (`bitacora.md`) para no
  perder nada. El chat es desechable; el proyecto es la memoria.

## Modo ahorro agresivo (límite semanal casi agotado)
Cuando quede poco margen semanal hasta el reset:
1. Avisar a Iñaki del margen restante y del día/hora del reset.
2. `/clear` o hilo nuevo en cuanto cambie el tema; `/compact` frecuente dentro de la tarea.
3. Bajar a Haiku todo lo que no exija Opus.
4. Cero navegador MCP salvo dato imprescindible en tiempo real.
5. Respuestas y exploración al grano: no releer archivos ya vistos, no volcar salidas largas.

## Qué decir a Iñaki (plantilla)
> Vamos con el contexto muy cargado (X% por encima de 150k) y casi todo en Opus. Propongo:
> `/compact` ahora para seguir con esta tarea, y `/clear`/hilo nuevo cuando pasemos a lo
> siguiente. Para los encargos simples, Haiku. Dejo el estado en la bitácora antes de limpiar.

## Coherencia con el workspace
- No es destructivo: `/compact` y `/clear` no borran archivos del repo, solo el contexto del chat.
- Aun así, **antes de `/clear` en un trabajo en curso**, confirma que el estado está en
  `bitacora.md`/`README.md` del proyecto (regla de organización de `CLAUDE.md`).
