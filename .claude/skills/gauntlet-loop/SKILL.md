---
name: gauntlet-loop
description: >-
  Bucle Constructor → Crítico Ciego para refinar un artefacto concreto (script, código,
  doc técnica, configuración) contra una rúbrica explícita antes de darlo por bueno.
  El Crítico es un subagente con contexto limpio que solo ve el objetivo, la rúbrica y
  los archivos, nunca el razonamiento del Constructor. Úsala SOLO cuando Iñaki la pida
  por nombre ("gauntlet", "gauntlet-loop", "pásalo por el gauntlet", "revisión
  exhaustiva con crítico") sobre un artefacto identificable. No la dispares por
  peticiones genéricas de "calidad": cada iteración cuesta un subagente.
---

# Gauntlet Loop — Constructor vs. Crítico Ciego

Objetivo: que nada salga como borrador autocomplaciente. Quien construye **no** se
califica a sí mismo; lo evalúa un subagente aislado contra una rúbrica fijada **antes**
de empezar, y con evidencia ejecutable siempre que exista.

## 0. Precondiciones (si falta algo → preguntar, no improvisar)
- **Artefacto objetivo** concreto: rutas de archivos o carpeta. Sin objetivo no hay bucle.
- **Alcance de escritura:** qué puede tocar el Constructor. Todo lo demás, solo lectura.
- **Reglas del repo** (`CLAUDE.md`): español, por fases, nada destructivo ni push sin OK,
  no tocar credenciales. El bucle **no** las suspende.
- Si el trabajo es nuevo y no tiene carpeta → skill `nuevo-proyecto` primero.

## 1. Fijar la rúbrica (antes de construir)
Redacta 5–10 criterios **verificables**, cada uno con su forma de comprobarlo. Mezcla:
- **Checks automáticos** que el repo ya permita: tests, linters, `bash -n`, `shellcheck`,
  `PSScriptAnalyzer`, typecheck, build. Si la herramienta no está instalada, se indica
  como "no verificable aquí", no se da por aprobado.
- **Criterios del dominio:** idempotencia, manejo de errores, seguridad (sin secretos,
  mínimos privilegios, nada expuesto por defecto), reversibilidad, claridad para quien
  lo ejecute.
- **Criterios del objetivo** del usuario (lo que tiene que hacer el artefacto).

Muestra la rúbrica al usuario y espera su OK (regla "por fases" de `CLAUDE.md`). Con ese
OK quedan autorizadas las iteraciones dentro del alcance de escritura; nada más.
Si el artefacto no admite ningún check automático (p. ej. documentación pura), se dice
"sin checks automáticos" y el Crítico evalúa solo por lectura.

## 2. El bucle
Máximo **3 iteraciones** por defecto (el usuario puede subirlo). En cada una:

1. **Constructor** (el agente principal): implementa o corrige. En iteraciones ≥2 solo
   atiende los hallazgos bloqueantes del Crítico; no reescribe lo aprobado.
2. **Evidencia:** ejecuta los checks automáticos de la rúbrica. La salida se pasa en el
   prompt del Crítico; si hay que guardarla en disco, al scratchpad de la sesión, nunca
   suelta en el repo.
3. **Crítico Ciego:** lanza un subagente **nuevo** (herramienta `Agent`, sin heredar la
   conversación; tipo de solo lectura como `Explore` si basta con leer, o
   `general-purpose` si tiene que ejecutar checks) con un prompt que contenga **solo**:
   - el objetivo en una frase y la rúbrica;
   - las rutas de los archivos a revisar (que los lea él) y la salida de los checks;
   - las instrucciones de veredicto de abajo;
   - la orden explícita "no modifiques ningún archivo".
   **Prohibido** pasarle justificaciones, explicaciones del Constructor o "lo que se
   intentó". Si en la iteración anterior hubo hallazgos, se le pasan como lista para que
   verifique si siguen abiertos, sin argumentar.
4. **Veredicto** que debe devolver el Crítico, en este formato:
   ```
   VEREDICTO: APROBADO | RECHAZADO
   Por criterio: <id> — cumple / no cumple / no verificable — evidencia (archivo:línea o salida)
   Hallazgos bloqueantes: <lista, cada uno con ubicación y por qué rompe un criterio>
   Mejoras opcionales: <lista>
   ```
   Un hallazgo solo es **bloqueante** si rompe un criterio de la rúbrica con evidencia
   concreta. Gustos, estilo y "podría ser mejor" van a opcionales.
5. **Progreso visible:** al acabar cada iteración, una línea al usuario:
   `[Gauntlet] Iteración N/M — RECHAZADO: 2 bloqueantes (…). El Constructor corrige.`

## 3. Condición de parada
- **APROBADO** con todos los criterios en "cumple" o "no verificable" (lo justifica el
  Crítico y se lista aparte en el informe; no cuenta como cumplido), o
- **tope de iteraciones** alcanzado → se entrega lo que hay con los bloqueantes abiertos
  bien a la vista, o
- **no hay progreso** (mismo bloqueante = mismo criterio y misma ubicación, dos
  iteraciones seguidas) → parar y consultar, o
- el usuario frena ("tú eres el freno").

No se persigue un "100 %" abstracto: se persigue cumplir la rúbrica con evidencia.
Nada de bucles en segundo plano sin límite.

## 4. Informe final (en la terminal, español)
1. **Métricas:** iteraciones usadas, bloqueantes encontrados/cerrados, checks ejecutados.
2. **Cambios:** archivos tocados (rutas clicables) y resumen del diff. No se pega el
   artefacto entero salvo que sea corto.
3. **Informe del Crítico:** su último veredicto resumido, incluyendo opcionales no
   aplicados y lo que quedó "no verificable aquí" (p. ej. scripts que solo pueden
   probarse en el Firebat o en Windows).
4. **Siguiente paso:** commit/push **solo tras confirmación**; registrar en la
   `bitacora.md` del proyecto afectado.

## Notas
- En sesiones en la nube el Crítico tampoco ejecuta nada sobre el hardware real: lo que
  dependa del Firebat o de AD/Exchange se marca como "verificar en destino".
- Si hay un rol de dominio (p. ej. `cachyos-baseline`), su criterio entra en la rúbrica.
