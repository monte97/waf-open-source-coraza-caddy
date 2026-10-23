"""Il WAF su misura, misurato.

    make su-misura      (oppure: python3 misure/su_misura/misura.py)

Tutte le richieste finiscono nel campo di ricerca `q` di /search, come se
fossero scritte da un utente. Le richieste vengono da GoTestWAF
(richieste.json): gli attacchi, e le richieste oneste costruite per sembrare
sospette. Le oneste sono divise in due gruppi: «visto» e «nuovo».

Il giro, come nella documentazione CRS:
  1. guarda    livello 3, soglia 10000: il WAF annota e non blocca. Gli si
               mandano solo le oneste «viste».
  2. escludi   dal registro si leggono le regole scattate nel campo q, e per
               ognuna si scrive SecRuleUpdateTargetById <id> "!ARGS:q".
  3. misura    livello 1, livello 3 e livello 3 su misura, su tutto: attacchi,
               oneste viste, oneste nuove. Le nuove il WAF non le ha mai viste:
               dicono quanto la correzione regge sul traffico che non conosce.
"""
import json
import pathlib
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

RADICE = pathlib.Path(__file__).resolve().parents[2]
QUI = pathlib.Path(__file__).resolve().parent
DC = ["docker", "compose", "-f", "demo/docker-compose.yml", "-f", "misure/compose.yml"]
PROFILI = ["nowaf", "detect", "block", "paranoid", "tuned", "toppa", "base64", "guarda", "sumisura"]
URL = "http://localhost:8080/search?q="


def compose(*argomenti):
    return subprocess.run(DC + list(argomenti), cwd=RADICE, capture_output=True, text=True)


def avvia(profilo):
    tutti = [x for p in PROFILI for x in ("--profile", p)]
    compose(*tutti, "down", "--remove-orphans")
    compose("--profile", profilo, "up", "-d")
    for _ in range(60):
        try:
            if urllib.request.urlopen("http://localhost:8080/", timeout=2).status == 200:
                return
        except Exception:
            pass
        time.sleep(1)
    raise SystemExit(f"il profilo {profilo} non parte")


# Header da browser: senza, il CRS al livello 3 segnala lo user agent di Python
# e l'Accept mancante, e ogni richiesta verrebbe bloccata per quello.
HEADER = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "it-IT,it;q=0.8,en;q=0.5",
}


def bloccata(q):
    try:
        richiesta = urllib.request.Request(URL + urllib.parse.quote(q, safe=""), headers=HEADER)
        urllib.request.urlopen(richiesta, timeout=10)
        return False
    except urllib.error.HTTPError as e:
        return e.code == 403


def quota(richieste):
    fermate = sum(bloccata(r["q"]) for r in richieste)
    return {"fermate": fermate, "totale": len(richieste)}


dati = json.loads((QUI / "richieste.json").read_text())
attacchi, oneste = dati["attacchi"], dati["oneste"]
viste = [o for o in oneste if o["gruppo"] == "visto"]
nuove = [o for o in oneste if o["gruppo"] == "nuovo"]

# 1-2. guarda ed escludi
avvia("guarda")
for o in viste:
    bloccata(o["q"])
registro = compose("logs", "--no-color", "caddy-guarda").stdout
regole = set()
for riga in registro.splitlines():
    if "ARGS:q" not in riga:
        continue
    for rid in re.findall(r'\[id \\?"(\d+)\\?"\]', riga):
        if not rid.startswith(("949", "959", "980")):
            regole.add(rid)
righe = [
    "# Generato da misura.py: esclusioni ricavate dal registro della fase «guarda».",
    "# Ogni regola che ha dato un falso allarme sulle oneste «viste» smette di",
    "# guardare il solo campo q. Ovunque altro resta accesa.",
] + [f'SecRuleUpdateTargetById {rid} "!ARGS:q"' for rid in sorted(regole)]
(QUI / "generato" / "10-esclusioni.conf").write_text("\n".join(righe) + "\n")

# 3. misura
risultati = {"esclusioni": sorted(regole)}
for profilo in ("block", "paranoid", "sumisura"):
    avvia(profilo)
    risultati[profilo] = {
        "attacchi": quota(attacchi),
        "attacchi_senza_base64": quota([a for a in attacchi if a["forma"] != "base64"]),
        "oneste_viste": quota(viste),
        "oneste_nuove": quota(nuove),
    }
avvia("block")
compose(*[x for p in PROFILI for x in ("--profile", p)], "down", "--remove-orphans")

(QUI / "risultati.json").write_text(json.dumps(risultati, indent=1) + "\n")
print(f"esclusioni ricavate: {len(regole)}")
for chiave in ("attacchi", "attacchi_senza_base64", "oneste_viste", "oneste_nuove"):
    celle = []
    for profilo in ("block", "paranoid", "sumisura"):
        r = risultati[profilo][chiave]
        celle.append(f"{profilo} {r['fermate']}/{r['totale']} ({100 * r['fermate'] / r['totale']:.0f}%)")
    print(f"  {chiave:22} " + " · ".join(celle))
