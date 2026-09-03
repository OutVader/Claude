# Bitácora — CachyOS / Firebat F1 P

Registro cronológico de lo que se ejecuta y sus resultados. Una entrada por sesión/bloque.

Formato:
```
## AAAA-MM-DD — <bloque/acción>
- Comando(s):
- Resultado:
- Decisiones / pendientes:
```

---

## 2026-09-03 — Fase 1F: preparación del playbook (sesión Claude en la nube)
- La sesión de Claude corre en un contenedor remoto (Ubuntu), **no** sobre el Firebat:
  no se ejecutó nada en el hardware real. Entregado el playbook `fase-1-baseline/`.
- Pendiente del usuario (en el Firebat, en este orden):
  1. `bash 00-diagnostico.sh` y pegar la salida.
  2. Confirmar bloque a bloque A→G.
  3. Cerrar con `H-resumen.md`.
- Pendientes de decisión: RAM soldada vs ampliable; motor de firewall (firewalld/ufw);
  WM de Fase 2.
