---
name: gauntlet-loop
description: >-
  Bucle Constructor → Crítico Ciego para refinar un artefacto concreto (script, código,
  doc técnica, configuración, hoja o informe) contra un listón y una checklist
  verificable antes de darlo por bueno. El Crítico es un subagente con contexto limpio
  que solo ve el objetivo, el listón, la checklist y el resultado, nunca el razonamiento
  del Constructor. Úsala SOLO cuando Iñaki la pida por nombre ("gauntlet",
  "gauntlet-loop", "pásalo por el gauntlet", "revisión exhaustiva con crítico") sobre un
  artefacto identificable. No la dispares por peticiones genéricas de "calidad": cada
  ronda cuesta un subagente. No confundir con /loop (tareas recurrentes).
---

# Gauntlet Loop — Constructor vs. Crítico Ciego

Objetivo: que nada salga como primera versión autocomplaciente. Una IA evalúa mal su
propio trabajo (tiende a darlo por bueno), así que quien construye **no** se califica:
lo evalúa un subagente aislado, adversarial, contra un listón fijado **antes** de
empezar y con evidencia del **resultado**, no de las intenciones.

## 0. Precondiciones (si falta algo → preguntar, no improvisar)
- **Artefacto objetivo** concreto: rutas de archivos o carpeta. Sin objetivo no hay bucle.
- **Alcance de escritura:** qué puede tocar el Constructor. Todo lo demás, solo lectura.
- **Reglas del repo** (`CLAUDE.md`): español, por fases, nada destructivo ni push sin OK,
  no tocar credenciales, eficiencia. El bucle **no** las suspende.
- Si el trabajo es nuevo y no tiene carpeta → skill `nuevo-proyecto` primero.

## 1. Encargo en cuatro cajas (antes de construir)
Antes de tocar nada, redacta y muestra estas cuatro cajas:

1. **Tarea:** qué es, para quién y qué piezas incluye, en una o dos frases.
2. **Método:** las rondas (tope por defecto **3**, o lo que diga Iñaki: "2 rondas",
   "hasta que lo dé por bueno" = tope 5) y qué checks se ejecutarán.
3. **Listón:**
   - **Referencia concreta**, no un adjetivo. Por ejemplo: "que lo firmaría sin tocar
     una coma un auditor de seguridad exigente", "al nivel del playbook X". Nunca
     "bonito" ni "profesional".
   - **Checklist de 5 a 10 puntos verificables uno a uno**, cada uno con su forma de
     comprobarlo:
     - **Checks automáticos** que el entorno permita: tests, `bash -n`, `shellcheck`,
       `PSScriptAnalyzer`, typecheck, build. Si la herramienta no está, el punto queda
       "no verificable aquí"; no se aprueba.
     - **Pruebas de perturbación** cuando apliquen: cambiar una entrada y comprobar que
       la salida cambia como debe, **sobre una copia en el scratchpad** (nunca sobre
       originales fuera del alcance).
     - **Dominio:** idempotencia, que no imprima "ok" si algo falla, seguridad (sin
       secretos, mínimos privilegios, nada expuesto), reversibilidad, logs.
     - **Fidelidad a la fuente:** cada dato se puede rastrear hasta su origen; no hay
       nada inventado ni redondeado.
4. **Entregable:** formato y **restricciones no negociables**, numeradas `R1, R2…` para
   que el Crítico las evalúe una a una. Por ejemplo: sin
   placeholders ni TODO, en español, funciona sin instalar nada extra, nada se ejecuta
   sin confirmar. Incumplir una restricción es **siempre** bloqueante.

Si el artefacto no admite checks automáticos (documentación pura), se escribe "sin checks
automáticos" y el Crítico evalúa leyendo.

**Confirmación (regla "por fases" de `CLAUDE.md`):** dentro del gauntlet, el paso que
pide OK es **aprobar las cuatro cajas**. Se muestran y se espera, salvo que Iñaki diga
expresamente que se siga sin esperar ("dale", "sin esperar"). Aprobadas las cajas, las
rondas dentro del alcance no piden más confirmación. Las acciones con efectos (push,
borrados, ejecutar en hardware real, cualquier cosa fuera del alcance) piden **siempre**
confirmación aparte.

## 2. El bucle
En cada ronda:

1. **Constructor** (el agente principal).
   - Ronda 1: primero planifica qué piezas va a construir o cambiar y después
     implementa.
   - Rondas ≥2: corrige **todos** los bloqueantes señalados y no reescribe lo aprobado.
   - Autonomía dentro del alcance: las ambigüedades de detalle las decide él y las anota
     en "Decisiones tomadas". Las que cambian el objetivo o tienen efectos se consultan.
2. **Evidencia del resultado, no de las intenciones.** La genera **el Constructor**:
   ejecuta los checks, las pruebas de perturbación (sobre copias en el scratchpad) y,
   si se puede, el propio artefacto: renderizar y capturar, abrir la salida, comparar
   cifras con el documento original, `--help` o dry-run. La salida se pasa al Crítico. Si hay que
   guardarla, va al scratchpad, nunca suelta en el repo.
3. **Crítico Ciego.** Lanza un subagente **nuevo** con la herramienta `Agent`, sin
   heredar la conversación y **siempre de solo lectura** (`Explore`). No ejecuta checks
   ni nada con efectos, y no modifica nada: juzga la evidencia del paso 2 y los archivos. Si echa en falta
   evidencia, la pide como bloqueante y el Constructor la genera en la ronda siguiente.
   El prompt contiene **solo**:
   - la tarea en una frase, el listón (referencia + checklist) y las restricciones;
   - las rutas a revisar (que las lea él) y la evidencia del paso 2;
   - los bloqueantes de la ronda anterior (con sus ids `Bn`), como lista sin argumentar,
     para que confirme cuáles siguen abiertos, y el **último id usado** ("los nuevos
     empiezan en Bn+1"; en la ronda 1, B1);
   - **literales**: la postura (paso 4), el formato de veredicto (paso 5), la definición
     de bloqueante, la regla de APROBADO (sección 3) y la orden "no modifiques ningún
     archivo".

   **Prohibido** pasarle justificaciones del Constructor o "lo que se intentó".
4. **Postura del Crítico** (va literal en su prompt):
   - Adversarial: busca fallos a propósito, como si quisiera tumbar el trabajo.
   - **Prohibido elogiar** y **prohibidas las críticas vagas** ("podría ser más
     robusto"). Cada hallazgo dice **qué está mal, dónde (evidencia) y cómo debería
     ser**.
   - Basa su juicio en el resultado: la salida de los checks, las capturas o los datos
     comparados. Leer el código no basta si hay evidencia ejecutable.
   - Sin cuota de fallos: no inventa problemas para llenar una lista.
5. **Veredicto** que devuelve el Crítico:
   ```
   VEREDICTO: APROBADO | RECHAZADO
   Por punto: <Pn o Rn> — cumple / no cumple / no verificable — evidencia (archivo:línea, salida o captura)
   Bloqueantes (ordenados por gravedad): Bn: <qué está mal> · <dónde> · <cómo debería ser> · <Pn o restricción>
   Siguen abiertos de la ronda anterior: <ids Bn previos o "ninguno">
   Mejoras opcionales: <lista breve>
   ```
   Un hallazgo es **bloqueante** solo si rompe un punto de la checklist o una restricción,
   con evidencia. Gustos y estilo van a opcionales.
   **Ids globales a todo el gauntlet:** un `Bn` que sigue abierto conserva su id, y los
   nuevos continúan la numeración desde el último usado (nunca se reinicia en B1).
   Si el VEREDICTO del Crítico contradice la regla de APROBADO, manda la regla y se trata
   como RECHAZADO.
6. **Progreso visible:** una línea por ronda:
   `[Gauntlet] Ronda N/M — RECHAZADO: 2 bloqueantes (errores ignorados; SSH abierto). El Constructor corrige.`

## 3. Condición de parada
- **APROBADO** = cero "no cumple", cero bloqueantes, ninguna restricción (`Rn`) en "no
  verificable" y al menos la mitad de los puntos (`Pn`) en "cumple". Los "no verificable" (los
  justifica el Crítico) se listan aparte como "verificar en destino". O bien:
- **tope de rondas** alcanzado: se entrega lo que hay con los bloqueantes abiertos bien
  a la vista. Si hubo correcciones después del último veredicto, se marcan como "sin
  revisar por el Crítico". O bien:
- **no hay progreso**: un mismo `Bn` (mismo punto y misma ubicación) sigue abierto en
  dos veredictos consecutivos posteriores al que lo creó. Se para y se consulta. O bien:
- Iñaki lo frena: él es el freno de emergencia.

No se persigue un "100 %" abstracto: se persigue superar el listón con evidencia. Nada
de bucles en segundo plano sin límite.

## 4. Informe final (en la terminal, en español)
1. **Resumen de la revisión:** cuántas rondas, qué rechazó el Crítico en cada una y qué
   se corrigió. Con esto Iñaki decide en un minuto si se puede fiar.
2. **Cambios:** archivos tocados (rutas clicables) y resumen del diff. No se pega el
   artefacto entero salvo que sea corto.
3. **Decisiones tomadas** por el Constructor ante ambigüedades.
4. **Pendientes:** bloqueantes abiertos, opcionales no aplicados y lo "no verificable
   aquí" o "verificar en destino" (Firebat, Windows, AD/Exchange).
5. **Siguiente paso:** Iñaki es el último filtro. Commit/push **solo tras confirmación**;
   registrar en la `bitacora.md` del proyecto afectado.

## Notas
- Úsala cuando el resultado importa. Tarda más y gasta más; para respuestas rápidas no
  compensa.
- En la nube el Crítico tampoco toca el hardware real: lo que dependa del Firebat o de
  AD/Exchange se marca como "verificar en destino".
- Si hay un rol de dominio (p. ej. `cachyos-baseline`), su criterio entra en el listón.
- Versión portable para otros modelos: `.claude/proyectos/gauntlet-portable/`.
  Mantenerla alineada con esta skill.
