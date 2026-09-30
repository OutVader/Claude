# Contexto — Acceso remoto personal

## Objetivo
Controlar el equipo personal de Iñaki (Windows 11 x64 y Arch Linux) desde su
móvil Android, de forma fluida y legítima.

## Alcance
- Equipos **personales** de Iñaki únicamente.
- Sin VPN corporativa ni políticas de terceros de por medio.
- Sin ningún objetivo de evasión de firewall/DPI/App-ID.

## Top 3 elegido

1. **RustDesk** (recomendado)
   - Open source, autoalojable, buen rendimiento nativo en Android.
   - Windows 11: instalador `.exe` x64 desde GitHub Releases.
   - Arch: paquete `rustdesk-bin` en AUR.
   - Android: Play Store o `.apk` desde GitHub Releases.

2. **Chrome Remote Desktop**
   - Cero configuración, solo navegador Chrome/Chromium.
   - Windows 11: setup vía remotedesktop.google.com/access.
   - Arch: paquete `chrome-remote-desktop` en AUR (requiere Chrome).
   - Android: Play Store.

3. **MeshCentral**
   - Autoalojado (Node.js), más potente, más curva de montaje.
   - Servidor propio; agente ligero en cliente Windows/Arch.
   - Android: se gestiona vía navegador (sin app dedicada).

## Pendiente / siguientes pasos
- [ ] Confirmar con Iñaki cuál de las 3 monta primero.
- [ ] Guía paso a paso de instalación en Windows 11.
- [ ] Guía paso a paso de instalación en Arch (paquete AUR o binario).
- [ ] Configuración del cliente Android.
- [ ] (Si RustDesk/MeshCentral) decidir si se autoaloja servidor/relay propio.
