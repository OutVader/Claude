#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Simulador local de POST /api/alpha/decisions para pruebas sin key ni red.

Heurística fija: comandos de solo lectura conocidos -> noul alto; resto -> bajo.
Registra cada petición recibida en <dir>/peticiones.jsonl para verificar
que los bloqueos estáticos NO llaman a JEV.
"""
import json
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

LECTURA = re.compile(r"^(ls|dir|get-childitem|gci|git (status|log|diff|show)|cat|type|get-content|pwd|whoami|echo|"
                     r"get-service|get-process|sc query|get-winevent|get-date|hostname|uname|df|du|find|grep|select-string)\b", re.I)
REG = sys.argv[2] if len(sys.argv) > 2 else "peticiones.jsonl"


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(n) or b"{}")
        with open(REG, "a", encoding="utf-8") as f:
            f.write(json.dumps(body, ensure_ascii=False) + "\n")
        if not self.headers.get("Authorization", "").startswith("Bearer "):
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'{"error":"unauthorized"}')
            return
        st = body.get("state", {})
        cmds = st.get("commands", [])
        answers = {}
        for qid, q in (body.get("questions") or {}).items():
            if q["type"] == "noul":
                if isinstance(cmds, dict):
                    lista = [cmds.get(qid, "")]
                else:
                    lista = cmds or [st.get("texto", "")]
                ok = all(LECTURA.match(c.strip()) for c in lista) or st.get("texto") == "ping"
                answers[qid] = {"type": "noul", "noul": 0.97 if ok else 0.31}
            elif q["type"] == "choice":
                pet = json.dumps(st, ensure_ascii=False).lower()
                opciones = list(q["criteria"].keys())
                elegido, conf = "ninguna", 0.82
                for o in opciones:
                    if o != "ninguna" and ("servicio" in pet and "servicio" in o or o in pet):
                        elegido, conf = o, 0.91
                probs = {o: (conf if o == elegido else (1 - conf) / max(1, len(opciones) - 1)) for o in opciones}
                answers[qid] = {"type": "choice", "choice": elegido, "confidence": conf, "probabilities": probs}
            else:
                answers[qid] = {"type": "score", "score": 1.0, "confidence": 0.9, "probabilities": {}, "legend": {}}
        time.sleep(0.05)
        out = {"id": "gen-dec-mock%d" % int(time.time() * 1000), "model": "typesafe/jev-1.13-20260918",
               "provider": "TypeSafe", "answers": answers,
               "usage": {"input_tokens": 300, "output_tokens": 0, "cost": 0.0000126}}
        data = json.dumps(out).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
