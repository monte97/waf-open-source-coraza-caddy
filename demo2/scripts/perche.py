#!/usr/bin/env python3
"""Perche' il WAF ha bloccato: per ogni richiesta fermata, le regole scattate.

Legge il log del Caddy acceso in demo2 (riparte a ogni cambio di profilo) e
stampa il percorso di ogni richiesta fermata, e sotto le regole scattate con
i punti e cosa hanno visto.
  make prove && make perche
"""
import json, re, subprocess, sys

AZZURRO, BIANCO, GIALLO, TENUE, ROSSO, FINE = "\033[1;96m", "\033[1;97m", "\033[1;93m", "\033[37m", "\033[1;91m", "\033[0m"
PUNTI = {"critical": 5, "error": 4, "warning": 3, "notice": 2}

def corto(uri, n=40):
    """La coda del percorso, quella che dice cosa: …/prove-waf/foto.jpg"""
    return uri if len(uri) <= n else "…" + uri[-(n - 1):]

def sh(*a):
    return subprocess.run(a, capture_output=True, text=True, cwd=sys.path[0] + "/..").stdout

servizio = next((s for s in sh("docker", "compose", "ps", "--services").split() if s.startswith("caddy-")), None)
if not servizio:
    print(f"{ROSSO}nessun profilo acceso: prima make waf (o plugin){FINE}"); sys.exit(1)
if servizio == "caddy-nowaf":
    print(f"{TENUE}profilo nowaf: senza WAF non c'e' niente da spiegare{FINE}"); sys.exit(0)

richieste, ordine, accessi = {}, [], []
for riga in sh("docker", "compose", "logs", "--no-log-prefix", servizio).splitlines():
    try:
        r = json.loads(riga)
    except ValueError:
        continue
    if r.get("logger") == "http.log.access" and r.get("status") in (400, 403):   # il metodo sta qui
        accessi.append((r["request"].get("method", ""), r["request"].get("uri", "")))
        continue
    m = r.get("msg", "")
    uid = re.search(r'\[unique_id "([^"]+)"\]', m)
    rid = re.search(r'\[id "(\d+)"\]', m)
    if not uid or not rid:
        continue
    g = lambda k: (re.search(r'\[' + k + r' "([^"]*)"\]', m) or [None, ""])[1]
    if uid[1] not in richieste:
        richieste[uid[1]] = {"uri": g("uri"), "regole": []}; ordine.append(uid[1])
    richieste[uid[1]]["regole"].append((rid[1], g("severity"), g("msg"), g("data")))
    tot = re.search(r"Inbound Scores: blocking=(\d+)", m)
    if tot:   # la 980170 riassume il punteggio vero: una regola con multiMatch conta piu' volte
        richieste[uid[1]]["punti"] = int(tot[1])

# bloccate dal punteggio (949110), o subito da una regola del motore che rifiuta
# un corpo che non riesce a leggere (200002, 200003, 200007: risposta 400)
FERMANO = {"949110", "200002", "200003", "200007"}
bloccate = [u for u in ordine if any(r[0] in FERMANO for r in richieste[u]["regole"])]
# Il log di Coraza non ha il metodo: lo prendo dal log di accesso di Caddy,
# accoppiando le richieste bloccate e le risposte 403 nello stesso ordine.
for u in bloccate:
    # se e' scattata la 911100 (metodo non ammesso), il metodo e' gia' nel suo dato;
    # una richiesta che Caddy chiude senza leggerne il corpo non ha la riga di accesso
    m911 = next((r[3] for r in richieste[u]["regole"] if r[0] == "911100"), None)
    i = next((k for k, (m, uri) in enumerate(accessi) if uri == richieste[u]["uri"] and (m911 is None or m == m911)), None)
    richieste[u]["metodo"] = m911 or (accessi.pop(i)[0] if i is not None else "")
    if m911 and i is not None:
        accessi.pop(i)
esteso = len(sys.argv) > 1 and sys.argv[1] == "tutto"
print(f"\n{AZZURRO}» {len(bloccate)} richieste bloccate ({servizio[6:]}): metodo, percorso, punti, regole scattate{FINE}\n")
for u in bloccate:
    x = richieste[u]
    regole = [r for r in x["regole"] if not r[0].startswith(("949", "980"))]
    punti = x.get("punti", sum(PUNTI.get(r[1], 0) for r in regole if not r[0].startswith("2000")))
    if not esteso:   # una riga per richiesta: sul palco sta in uno schermo
        ids = " ".join(r[0] for r in regole[:3]) + (f" +{len(regole) - 3}" if len(regole) > 3 else "")
        print(f"  {TENUE}{x.get('metodo', ''):<8}{FINE} {BIANCO}{corto(x['uri']):<40}{FINE}  {ROSSO}{punti:>5}{FINE}  {GIALLO}{ids}{FINE}")
        continue
    print(f"  {TENUE}{x.get('metodo', '')}{FINE} {BIANCO}{x['uri'][:80]}{FINE}  {ROSSO}{punti} punti{FINE}")
    for rid, sev, msg, data in regole:
        print(f"    {GIALLO}{rid}{FINE} {TENUE}+{PUNTI.get(sev, '?')}{FINE}  {msg[:48]:<48}  {TENUE}{data[:30]}{FINE}")
if not esteso:
    print(f"\n  {TENUE}cosa ha visto ogni regola: make perche-tutto{FINE}")
print(f"  {TENUE}le 413 (corpo troppo grande) non passano dalle regole: le decide SecRequestBodyLimit{FINE}\n")
