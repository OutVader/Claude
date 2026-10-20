# Versiones y enlaces validados · consulta 20-oct-2026 (Europe/Madrid)

Fuente única de versiones para `FASE0.md` y `FASE1.md`. **Vuelve a comprobarlas el día que instales**
(comando al final). Estados: CONFIRMADO · COMPATIBLE CON RESERVAS · INDICIO · NO VERIFICADO · INCOMPATIBLE.
Método: tags de los repos oficiales (`git ls-remote`), listados de mirrors oficiales y webs oficiales con respuesta HTTP 200.

## Sistema y escritorio
| Componente | Versión vigente | Estado | Enlace oficial | Alternativa si falla |
|---|---|---|---|---|
| ISO CachyOS Desktop | `260809` (`cachyos-desktop-linux-260809.iso` + `.sha256` + `.sig`) | CONFIRMADO (listado del mirror) | https://mirror.cachyos.org/ISO/desktop/260809/ · https://cachyos.org/download/ | SourceForge oficial: https://sourceforge.net/projects/cachyos-arch/ |
| Firma CachyOS | Clave `F3B607488DB35A47` · huella `882D CFE4 8E20 51D4 8E25 62AB F3B6 0748 8DB3 5A47` | CONFIRMADO (wiki del 10-ago-2026) | https://wiki.cachyos.org/cachyos_basic/download/ | Keyserver principal en la guía: `hkps://keyserver.ubuntu.com` (huella completa); alternativo, el de la wiki: `hkps://keys.openpgp.org` |
| Omarchy estable | `v4.0.6` | CONFIRMADO (tag) | https://github.com/omacom/omarchy/releases | Versión anterior `v4.0.5` (tag existente) |
| Omarchy pre-release | `v4.5.0-rc1` → **no usar** | CONFIRMADO (tag) | ídem | — |
| ISO Omarchy | `omarchy-4.0.6.iso` + `.sha256` + `.sig` | CONFIRMADO (HTTP 200) | https://iso.omarchy.org/omarchy-4.0.6.iso · manual: https://omarchy.org/manual/getting-started/ | — |
| Clave de firma Omarchy | Huella | NO VERIFICADO | El README de https://github.com/omacom/omarchy-iso (leído por git, commit `b88d35f`, 20-oct-2026) dice "verify the ISO against the Omarchy signing key" sin publicar la huella | Validar solo por SHA256 y anotarlo |
| Hyprland | `v0.56.2` (último tag) | CONFIRMADO el tag · NO VERIFICADO cuál usa Omarchy 4.0.6 | https://github.com/hyprwm/Hyprland | — |
| Aquamarine | `v0.15.1` (último tag) | ídem | https://github.com/hyprwm/aquamarine | — |
| Quickshell | `v0.3.2` (último tag) | ídem | https://quickshell.org/ · https://git.outfoxxed.me/quickshell/quickshell | — |

## Adaptadores Omarchy-sobre-CachyOS (comunitarios, NO oficiales)
| Adaptador | Último commit | Omarchy 4.x | Estado | Enlace |
|---|---|---|---|---|
| t1nk333r/omacachy | `b46236a` · 15-sep-2026 | Baseline **4.0.2** (`OMARCHY_RECONCILED_VERSION`); con 4.0.6 sin validar | COMPATIBLE CON RESERVAS (solo SSD de prueba) | https://github.com/t1nk333r/omacachy |
| AstroByte01/omarchy-on-cachyos | `d8d16f0` · 20-jul-2026 (anterior a Omarchy 4.0.0) | Modelo 3.x | INCOMPATIBLE (INDICIO fuerte) | https://github.com/AstroByte01/omarchy-on-cachyos |

## Herramientas en Windows (Fase 0)
| Herramienta | Versión vigente | Estado | Enlace oficial | Alternativa si falla |
|---|---|---|---|---|
| Rescuezilla (backup) | `2.6.2` | CONFIRMADO (tag) | https://rescuezilla.com/ · https://github.com/rescuezilla/rescuezilla/releases | Clonezilla |
| Clonezilla live (backup) | `3.3.3-37` (rama *stable*) | CONFIRMADO (web) | https://clonezilla.org/downloads.php | Rescuezilla |
| Ventoy (USB multiarranque) | `1.1.18` | CONFIRMADO (tag) | https://www.ventoy.net/ · https://github.com/ventoy/Ventoy/releases | Rufus o balenaEtcher |
| Rufus (USB) | `4.15` | CONFIRMADO (tag) | https://rufus.ie/ | balenaEtcher |
| balenaEtcher (USB; el que indica Omarchy) | `2.1.8` | CONFIRMADO (tag) | https://etcher.balena.io/ | Rufus en modo DD |
| Gpg4win (verificar firmas) | `5.1.1` | CONFIRMADO (web) | https://www.gpg4win.org/download.html | Verificar la firma desde el USB live de CachyOS (`gpg` incluido: NO VERIFICADO) |

## Opcional tras la Fase 1
| Componente | Versión | Estado | Enlace oficial | Alternativa |
|---|---|---|---|---|
| Claude Code | `2.1.305` (`latest` en npm) | CONFIRMADO (registro npm) | https://code.claude.com/docs/en/setup · instalador https://claude.ai/install.sh · https://registry.npmjs.org/@anthropic-ai/claude-code/latest | Instalación por npm (Node 22+) |

## Recomprobar el día de la instalación (Linux o el USB live, solo lectura)
```bash
git ls-remote --tags --refs https://github.com/omacom/omarchy | awk -F/ '{print $3}' | sort -V | tail -3
curl -s https://mirror.cachyos.org/ISO/desktop/ | grep -oE '[0-9]{6}/' | sort -u | tail -1
git ls-remote --tags --refs https://github.com/t1nk333r/omacachy | tail -3   # y su último commit en la web
```
En Windows: abre los enlaces de las tablas y compara con la columna "Versión vigente".

## Hechos citados en las guías ([Hn])
| Id | Hecho | Estado | Fuente (tipo) · fecha de consulta |
|---|---|---|---|
| H1 | El AUR sufrió un compromiso (~2000 paquetes), anunciado por CachyOS el 11/12-jun-2026: usar el AUR lo mínimo y revisar el PKGBUILD | CONFIRMADO | Tema 31040 "AUR Compromised - Almost 2000 packages affected - 20260611" (creado el 2026-06-12 00:12 UTC): https://discuss.cachyos.org/t/aur-compromised-almost-2000-packages-affected-20260611/31040 (oficial) · consultado el 20-oct-2026 |
| H2 | Omarchy 4.0.6 instala el kernel `linux-omarchy` (+ headers). El maestro lo llamaba `linux-omarchy-bore`; prevalece el código | CONFIRMADO | `install/omarchy-other.packages` del tag v4.0.6 de https://github.com/omacom/omarchy (oficial) · 20-oct-2026 |
| H3 | `omarchy-settings` reasigna los HOOKS de mkinitcpio y puede dejar sin arranque un sistema con LUKS | INDICIO (fuente comunitaria) · NO VERIFICADO en esta sesión (la web de GitHub da 403 desde aquí) | https://github.com/mroboff/omarchy-on-cachyos/issues/74 (comunitaria) · consultado el 20-oct-2026 por el traspaso v1.1 (ver CHANGELOG), no en esta sesión |
| H4 | omacachy mantiene `sd-encrypt` (`zz-cachyos-keep-hooks.conf`) y restaura `pacman.conf`/mirrorlist; baseline Omarchy 4.0.2 | CONFIRMADO lo que dice su README; su eficacia con 4.0.6, NO VERIFICADO | README de https://github.com/t1nk333r/omacachy, commit `b46236a` (comunitaria) · 20-oct-2026 |
| H5 | `install/config/firewall.sh` de Omarchy: `ufw default deny incoming`, `allow outgoing`, abre `53317/udp+tcp` y reglas DNS de Docker; ninguna regla para SSH; `ENABLED=yes` | CONFIRMADO | Código del tag v4.0.6 de https://github.com/omacom/omarchy (oficial) · 20-oct-2026 |
| H6 | `config/hypr/hyprland.lua` carga `/usr/share/omarchy/default/hypr/bootstrap.lua` (paquete `omarchy`): la configuración no funciona copiada sin el paquete | CONFIRMADO | Código del tag v4.0.6 de https://github.com/omacom/omarchy (oficial) · 20-oct-2026 |
| H7 | El instalador de Omarchy exige Secure Boot y/o TPM en Off, cifra por defecto, borra la unidad en el modo de disco completo y recomienda balenaEtcher | CONFIRMADO | https://omarchy.org/manual/getting-started/ (oficial) · 20-oct-2026 |
