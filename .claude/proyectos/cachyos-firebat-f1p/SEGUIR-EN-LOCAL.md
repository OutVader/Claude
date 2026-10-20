# Seguir en local · Contexto + Prompt (v2.1 · 20-oct-2026)

Para continuar con **Claude Code en tu equipo**: primero en el Windows del Firebat (Fase 0) y
después en el propio Firebat con CachyOS (Fase 1).

## 1. Cómo arrancar
1. Trae el repo a tu equipo (requiere que antes se haya hecho el push de la rama):
   ```bash
   git clone https://github.com/OutVader/Claude.git
   cd Claude && git checkout claude/cachyos-baseline-firebat-tglfuy
   ```
   - ↳ **Si falla** (repo privado sin credenciales): usa un token de GitHub, o descarga la rama como ZIP desde la web.
2. Abre Claude Code **en la raíz del repo** (`Claude/`). Así se cargan solos el `CLAUDE.md` raíz y las skills de `.claude/skills/`.
3. Pega el **Prompt** de la sección 3. Claude leerá el contexto completo de los ficheros, sin depender del chat.

## 2. Contexto (estado a 20-oct-2026)
- **Quién:** Iñaki, admin de sistemas (AD/Exchange, PowerShell), infra MS + ciber + cloud. Todo en español de España.
- **Objetivo:** mini PC Firebat (hoy con Windows 11) → base **CachyOS** + Hyprland con estilo **Omarchy**, como nodo inicial del homelab (IA/LLM locales con 16 GB, laboratorios). Prioridades: mantenible, seguro, recuperable y bajo control de Iñaki.
- **Proyecto:** `.claude/proyectos/cachyos-firebat-f1p/`.
  - Vigente en la raíz: `FASE0.md`, `FASE1.md`, `VERSIONES.md`, `scripts/` y `bitacora.md`.
  - Traspaso v2.0: `CLAUDE.md` (normas **bloqueantes**), contexto maestro, `RUBRICA.md` y `CHANGELOG.md`.
  - Histórico: `v1-2026-09/`.
- **Hardware: sin confirmar.**
  - CPU: probablemente Ryzen 7 H 255 (8745H, Radeon 780M); "Ryzen AI 9 HX 255" no existe.
  - Disco: 512 GB o 1 TB.
  - RAM: soldada o SO-DIMM.
  - 2.º M.2: sin comprobar.
  - Se resuelve en el paso 0.1 (Windows) y en el 1.1 (USB live).
- **Decisiones tomadas:**
  - Omarchy con **3 rutas y puerta** (D recomendada provisionalmente; A solo con la ISO oficial; C solo en un SSD de prueba).
  - Backup con **Rescuezilla** (alternativa: Clonezilla).
  - Cortafuegos firewalld (decisión de sept-2026), a revisar porque Omarchy activa ufw.
- **Versiones vigentes:**
  - CachyOS ISO `260809` (firma `F3B6 0748 8DB3 5A47`).
  - Omarchy `4.0.6` (RC `4.5.0-rc1`: no usar).
  - omacachy `b46236a`, con baseline Omarchy 4.0.2.
  - Herramientas y fuentes: en `VERSIONES.md`.
- **Hallazgos clave:**
  - La configuración de Hyprland de Omarchy 4.0.6 depende del paquete `omarchy` (ruta D = recrear, no copiar).
  - El kernel de Omarchy es `linux-omarchy` (corrige al maestro).
  - Omarchy abre ufw 53317 (LocalSend) y no tiene regla para SSH.
- **Estado:** Fase 0 y Fase 1 diseñadas y revisadas (gauntlet: 2 rondas + cierre; B1-B7 cerrados; B8-B9 corregidos sin revisar). **Nada ejecutado todavía en el equipo real.**
- **Pendiente:**
  - Ejecutar la Fase 0 hasta la PUERTA 0.
  - Paso 1.1, para confirmar el hardware y elegir la ruta.
  - Instalar.
  - Probar `Verificar-ISO.ps1` en Windows PowerShell 5.1 real.
  - Confirmar la huella de la firma de Omarchy.

## 3. Prompt (copiar y pegar tal cual)
```text
Eres mi asistente de sistemas para el proyecto del mini PC Firebat (CachyOS + Omarchy). Trabaja en español de España.

1. Lee, en este orden: .claude/proyectos/cachyos-firebat-f1p/CLAUDE.md (normas BLOQUEANTES), README.md,
   SEGUIR-EN-LOCAL.md, bitacora.md (lo último ejecutado) y VERSIONES.md. Después, según dónde estemos,
   FASE0.md o FASE1.md. No leas v1-2026-09/ salvo que te lo pida.
2. Detecta dónde estás (Windows del Firebat, USB live o CachyOS instalado) y dime en qué paso
   y en qué PUERTA estamos, según la bitácora.
3. Guíame paso a paso con los comandos de la guía. Antes de cada paso con efectos (BitLocker,
   Ventoy, BIOS, borrar disco, instalar, pacman, Omarchy) explícame qué hace, el riesgo y la vuelta
   atrás, y ESPERA mi OK. Puedes ejecutar sin preguntar solo lo que sea de lectura (inventario,
   verificaciones, scripts/comprobar-sistema.sh, Verificar-ISO.ps1).
4. Si un paso falla, aplica su "↳ Si falla". Si no basta, para y propón opciones con su riesgo.
5. Antes de usar una versión o un enlace, recomprueba VERSIONES.md (sección "Recomprobar").
   Lo que no puedas comprobar, márcalo NO VERIFICADO.
6. Nunca: números de serie, UUID ni credenciales en el chat o el repo; curl|bash sin leerlo;
   Omarchy, omacachy u otro instalador sin pasar su PUERTA y sin mi OK escrito en la bitácora.
7. Tras cada paso, añade a bitacora.md la fecha, lo hecho, el resultado y lo pendiente (sin datos
   sensibles). Si cambias un documento, crea antes su .bak y anótalo en CHANGELOG.md.
   Commit local sí; push solo con mi OK.

Empieza diciéndome dónde estamos y cuál es el siguiente paso.
```
