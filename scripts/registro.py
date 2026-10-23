#!/usr/bin/env python3
"""Il registro di Caddy, leggibile: le ultime richieste arrivate al profilo acceso.

Per ogni richiesta: ora, esito, codice, metodo e indirizzo in chiaro, le regole
scattate se il WAF l'ha bloccata e un giudizio: falso positivo (onesta bloccata),
attacco passato, oppure giusto. Il giudizio c'e' solo per le richieste di
`make raffica`, di cui sappiamo se sono oneste o attacchi: per le altre il WAF
non ha modo di saperlo, e nemmeno noi.
  make registro           le ultime 20
  make registro N=50      le ultime 50
"""
import json, re, subprocess, sys, time
from urllib.parse import unquote_plus

AZZURRO, BIANCO, GIALLO, TENUE, VERDE, ROSSO, FINE = ("\033[1;96m", "\033[1;97m", "\033[1;93m",
                                                     "\033[37m", "\033[1;92m", "\033[1;91m", "\033[0m")
PUNTI = {"critical": 5, "error": 4, "warning": 3, "notice": 2}
# Le richieste di make raffica, lette da scripts/raffica.sh: cosi' le liste restano una sola.
import os, shlex
NOTE = {"tastiera": "onesta"}   # la prova di make <profilo>, per vedere se la demo risponde
gruppo = None
for riga in open(os.path.join(os.path.dirname(__file__), "raffica.sh")):
    if riga.startswith("gruppo "):
        gruppo = "onesta" if "oneste" in riga else "attacco"
    elif riga.startswith("prova ") and gruppo:
        NOTE[shlex.split(riga)[2]] = gruppo

def giudizio(uri, passa):
    q = re.search(r"[?&]q=([^&]*)", uri)
    tipo = NOTE.get(unquote_plus(q[1])) if q else None
    if tipo is None:
        return f"{TENUE}non so{FINE}"
    if tipo == "onesta":
        return f"{VERDE}giusto{FINE}" if passa else f"{GIALLO}FALSO POSITIVO{FINE}"
    return f"{VERDE}giusto{FINE}" if not passa else f"{ROSSO}ATTACCO PASSATO{FINE}"

N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 20

def sh(*a):
    return subprocess.run(a, capture_output=True, text=True)

nome = servizio = None
for riga in sh("docker", "ps", "--format", "{{.Names}}\t{{.Label \"com.docker.compose.service\"}}").stdout.splitlines():
    n, s = (riga.split("\t") + [""])[:2]
    if s.startswith("caddy-"):
        nome, servizio = n, s[len("caddy-"):]
if not nome:
    print(f"{ROSSO}nessun profilo acceso: prima make block (o un altro profilo){FINE}"); sys.exit(1)

p = sh("docker", "logs", nome)
righe = (p.stdout + "\n" + p.stderr).splitlines()
campo = lambda m, k: (re.search(r'\[' + k + r' "(.*?)"\]', m) or [None, ""])[1]

accessi, regole_per_id, id_per_uri = [], {}, {}
for r in righe:
    if not r.startswith("{"):
        continue
    try:
        j = json.loads(r)
    except ValueError:
        continue
    if j.get("logger") == "http.log.access" or j.get("msg") == "handled request":
        q = j.get("request", {})
        accessi.append((j.get("ts", 0), q.get("method", ""), q.get("uri", ""), j.get("status", 0)))
    elif j.get("logger") == "http.handlers.waf":
        m = j.get("msg", "")
        if m == "WAF rule violation detected":
            id_per_uri[j.get("uri", "")] = j.get("unique_id", "")
        elif "Coraza: Warning." in m:
            rid = campo(m, "id")
            if rid and not rid.startswith(("949", "959", "980")):
                regole_per_id.setdefault(campo(m, "unique_id"), []).append(f"{rid} ({PUNTI.get(campo(m, 'severity'), '?')})")

print(f"\n{AZZURRO}» il registro di Caddy, profilo {servizio}: le ultime {min(N, len(accessi))} richieste di {len(accessi)}{FINE}\n")
if not accessi:
    print(f"  {TENUE}nessuna richiesta da quando il profilo e' acceso: prova make raffica{FINE}\n"); sys.exit(0)
print(f"  {BIANCO}{'ORA':<9} {'ESITO':<9} {'HTTP':<5} {'GIUDIZIO':<16} {'RICHIESTA':<56} REGOLE (punti){FINE}")
for ts, metodo, uri, status in accessi[-N:]:
    ora = time.strftime("%H:%M:%S", time.localtime(ts))
    passa = status < 400
    esito = f"{VERDE}{'passa':<9}{FINE}" if passa else f"{ROSSO}{'bloccata':<9}{FINE}"
    richiesta = f"{metodo} {unquote_plus(uri)}"
    richiesta = richiesta if len(richiesta) <= 56 else richiesta[:55] + "…"
    regole = "" if passa else ", ".join(regole_per_id.get(id_per_uri.get(uri, ""), []))
    g = giudizio(uri, passa)
    pad = 16 - len(re.sub(r"\033\[[0-9;]*m", "", g))
    print(f"  {TENUE}{ora:<9}{FINE} {esito} {status:<5} {g}{' ' * pad} {BIANCO}{richiesta:<56}{FINE} {GIALLO}{regole}{FINE}")
print(f"\n  {TENUE}giudizio: solo per le richieste di make raffica, di cui sappiamo se sono oneste o attacchi;{FINE}")
print(f"  {TENUE}per tutte le altre «non so»: il WAF non ha modo di saperlo{FINE}\n")
