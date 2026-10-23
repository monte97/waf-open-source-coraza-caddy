#!/usr/bin/env python3
"""Perché il WAF ha bloccato le richieste oneste della raffica.

Legge il registro di Caddy (ultimi 10 minuti), trova le richieste oneste di
`make raffica` che sono state bloccate e, per ognuna, le regole che sono
scattate: id, punti, messaggio, campo. Poi stampa la riga di esclusione per
ogni regola. Pensato per il palco, dopo `make paranoid && make raffica`.
"""
import json, re, subprocess, sys
from urllib.parse import urlsplit, parse_qs

ONESTE = ["tastiera meccanica", "O'Reilly", "SELECT * FROM menu", "C++ & C# -- guida"]
PUNTI = {"critical": 5, "error": 4, "warning": 3, "notice": 2}
# colori pensati per un terminale a sfondo nero: niente grigio scuro
TENUE, ROSSO, VERDE, GRASSETTO, AZZURRO, GIALLO, FINE = "\033[37m", "\033[1;91m", "\033[1;92m", "\033[1;97m", "\033[1;96m", "\033[1;93m", "\033[0m"

log = subprocess.run("cd demo && docker compose --profile paranoid --profile tuned --profile block "
                     "--profile detect --profile nowaf logs --no-color --since 10m",
                     shell=True, capture_output=True, text=True).stdout

campo = lambda m, k: (re.search(r'\[' + k + r' \\?"(.*?)\\?"\]', m) or [None, ""])[1]
regole, bloccate, totale = {}, set(), {}
for riga in log.splitlines():
    j = riga.split("| ", 1)[-1]
    if not j.startswith("{"):
        continue
    try:
        msg = json.loads(j).get("msg", "")
    except ValueError:
        continue
    if "Coraza:" not in msg:
        continue
    uri, uid = campo(msg, "uri"), campo(msg, "unique_id")
    q = parse_qs(urlsplit(uri).query).get("q", [""])[0]
    if q not in ONESTE:
        continue
    rid = campo(msg, "id")
    if rid == "949110":
        bloccate.add(uid)
        totale[uid] = (re.search(r"Total Score: (\d+)", msg) or [None, "?"])[1]
    elif "found within" in campo(msg, "data"):
        dove = re.search(r"found within (?:MATCHED_VARS:)?([A-Z_]+:[^:\s]+):", campo(msg, "data"))
        regole.setdefault((q, uid), []).append((rid, PUNTI.get(campo(msg, "severity"), "?"),
                                               campo(msg, "msg"), dove[1] if dove else "?"))

ultime = {}
for (q, uid), r in regole.items():
    if uid in bloccate:
        ultime[q] = (uid, r)
print(f"{AZZURRO}» richieste oneste bloccate, dal registro del WAF (ultimi 10 minuti)\n{FINE}")
if not ultime:
    print("  nessuna: nel registro non ci sono richieste oneste bloccate\n")
    sys.exit(0)
esclusioni = []
for q, (uid, r) in ultime.items():
    print(f"  {GRASSETTO}{q}{FINE}   {ROSSO}bloccata: {totale.get(uid, '?')} punti, soglia 5{FINE}")
    for rid, p, m, dove in r:
        print(f"    regola {GIALLO}{rid}{FINE}  {p} punti  {TENUE}{m[:58]:<58}{FINE}  in {dove}")
        riga = f'SecRuleUpdateTargetById {rid} "!{dove}"'
        if riga not in esclusioni:
            esclusioni.append(riga)
    print()
print(f"{AZZURRO}» per spegnere quelle regole solo su quel campo, una riga ciascuna:\n{FINE}")
for e in esclusioni:
    print(f"  {GRASSETTO}{e}{FINE}")
print(f"\n{AZZURRO}» sono già in demo/tuning/tuned/dopo/00-esclusioni.conf: make tuned && make raffica\n{FINE}")
