# Post-instalación: primeros pasos en CachyOS + Claude Code (cuenta Pro)

> Qué hacer **justo después** de instalar CachyOS y reiniciar: abrir terminal, actualizar
> repos, instalar Claude Code, vincular tu cuenta **Pro**, importar skills y dar permisos,
> para seguir configurando el equipo **en local** con Claude. Enlaza con `fase-1-baseline/`.

---

## 1. Primeros pasos (básico)

1. **Abrir terminal.** Si instalaste con escritorio (KDE), abre **Konsole**. Si instalaste
   mínimo/None, ya estás en una **TTY** (texto). Inicia sesión con tu usuario.
2. **Red.** Cableada suele funcionar sola (`ip -br a` para ver IP). Para Wi-Fi en texto:
   `nmtui` (NetworkManager) → *Activate a connection*.
3. **Actualizar mirrors + sistema** (equivale al bloque A del baseline, pero conviene hacerlo ya):
   ```bash
   sudo cachyos-rate-mirrors    # reordena mirrors por velocidad (si está disponible)
   sudo pacman -Syu             # actualización COMPLETA (nunca parcial)
   ```
   Si actualiza el kernel, **reinicia** antes de seguir.

---

## 2. Instalar Claude Code

**Opción A — instalador nativo (RECOMENDADO, sin Node):**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```
Instala el binario en `~/.local/bin`. Asegúrate de que está en el PATH (en Bash):
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
claude --version
```

**Opción B — vía npm (alternativa; requiere Node 22+):**
```bash
sudo pacman -S --needed nodejs npm
npm install -g @anthropic-ai/claude-code   # ⚠️ NUNCA con sudo (rompe permisos de npm global)
```
> Si `npm -g` da error de permisos, configura un prefijo de usuario:
> `npm config set prefix ~/.local` y añade `~/.local/bin` al PATH.

---

## 3. Vincular tu cuenta **Claude Pro**

1. Lanza Claude Code en una carpeta cualquiera:
   ```bash
   claude
   ```
2. En el primer arranque pide autenticación (o escribe `/login`). Elige
   **“Claude account with subscription”** (tu plan **Pro**), **no** la opción de API.
3. Copia la **URL** que imprime, ábrela en el navegador, inicia sesión con tu cuenta Pro y
   **pega de vuelta el código** en la terminal. Listo: Claude Code usa tu suscripción Pro.

La configuración de usuario queda en `~/.claude/` (`settings.json`, credenciales, etc.).

---

## 4. Importar el proyecto y las skills

Todo el material (skills + guías + playbook) vive en el repo **OutVader/Claude**. Dos formas:

**A — Clonar el repo (recomendado): las skills viajan con el proyecto.**
```bash
sudo pacman -S --needed git
git clone https://github.com/OutVader/Claude.git ~/Claude
cd ~/Claude
git checkout claude/cachyos-baseline-firebat-tglfuy   # rama de trabajo de Fase 1
claude                                                  # ábrelo AQUÍ
```
Al abrir `claude` en `~/Claude` se **autocargan**: `CLAUDE.md` (reglas), las skills de
`.claude/skills/` y el proyecto `.claude/proyectos/cachyos-firebat-f1p/`.

> Si el repo es **privado**, el `git clone` pedirá credenciales de GitHub: usa un **Personal
> Access Token** (GitHub → Settings → Developer settings → Tokens), o descarga la rama como
> **ZIP** desde la web de GitHub, o cópiala por **USB**. Da igual el método: lo que importa es
> tener la carpeta `~/Claude` en el equipo.

**B — Skills globales (opcional).** Si quieres las skills disponibles en **cualquier** carpeta
(no solo en el repo), cópialas a tu config de usuario:
```bash
mkdir -p ~/.claude/skills
cp -r ~/Claude/.claude/skills/* ~/.claude/skills/
```

### ¿Qué skills importar?
| Skill | Para qué |
|---|---|
| `nuevo-proyecto` | Crear la carpeta estándar de cada proyecto en `.claude/proyectos/` |
| `cachyos-baseline` | Rol asistente de sistemas (baseline/uso de CachyOS, fases 1–5) |
| `migracion-windows-cachyos` | Referencia de la pre-instalación (por si repites el proceso) |

---

## 5. Permisos de Claude Code

Claude Code, por defecto, **pide confirmación** antes de ejecutar comandos o editar archivos.
Para configurar el equipo en local hay tres niveles:

- **Recomendado (equilibrado):** deja las confirmaciones para lo destructivo, pero **autoriza
  en lista blanca** lo repetitivo y seguro. Dentro de Claude usa `/permissions` para permitir,
  por ejemplo, `pacman -S…`, `pacman -Syu`, lectura de archivos, `git status`, etc. Y activa
  **acceptEdits** (auto-aceptar ediciones de archivos) con la tecla que indica la propia UI.
- **Acceso total (lo que pediste):** salta TODAS las confirmaciones:
  ```bash
  claude --dangerously-skip-permissions
  ```
  ⚠️ **Aviso honesto:** en este modo Claude puede ejecutar comandos **destructivos sin
  preguntar** (borrar, formatear, sobrescribir). Contradice tu regla de “nada destructivo sin
  confirmación”. Úsalo solo en este equipo de tu confianza y para tareas acotadas; para el día
  a día es más seguro el modo equilibrado de arriba.
- Puedes fijar el modo por defecto y la lista blanca en `~/.claude/settings.json`
  (`permissions.allow`, `defaultMode`) para no repetirlo en cada sesión.

> Mi recomendación como tu asistente: **modo equilibrado** (lista blanca + acceptEdits). Si en
> algún momento quieres que trabaje sin interrupciones en una tarea concreta, lanzas esa sesión
> con `--dangerously-skip-permissions` y al acabar vuelves al modo normal.

---

## 6. Seguir desde aquí

Con Claude Code funcionando en `~/Claude` y las skills cargadas:
1. Ejecuta el diagnóstico del baseline: `bash .claude/proyectos/cachyos-firebat-f1p/fase-1-baseline/00-diagnostico.sh`.
2. Pásame la salida y seguimos con los bloques A→G (firewall = **firewalld**, snapshot **baseline**).
3. Cerramos con `H-resumen.md` y pasamos a **Fase 2** (escritorio) cuando confirmes el WM.
