#!/usr/bin/env python3
"""
Genera il materiale da impaginare nelle slide: per ogni momento della demo,
il comando che il pubblico vede e l'output che ne esce.

Non e' una registrazione: e' una ricostruzione fedele, rifatta ogni volta
eseguendo davvero le richieste contro i profili. Se cambi una regola e
rilanci `make cattura`, le slide si riallineano da sole.

Scrive in talk/cattura/, un file per profilo piu' un indice.
"""

import html
import json
import re
import subprocess
import sys
import time
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
USCITA = RADICE / "talk" / "cattura"
URL = "http://localhost:8080"

# Il rumore che non deve finire in slide: IP del client, timestamp, percorsi
# interni del container. Restano id, messaggio e punteggio, che sono il punto.
ID = re.compile(r'\[id "(\d+)"\]')
MSG = re.compile(r'\[msg "([^"]*)"\]')


def sh(*args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def avvia(profilo):
    sh("make", "-s", profilo, cwd=RADICE)
    for _ in range(40):
        if stato("tastiera") == "200":
            return True
        time.sleep(1)
    return False


def stato(q):
    r = sh("curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "5",
           "--get", "--data-urlencode", f"q={q}", f"{URL}/search")
    return r.stdout.strip()


def corpo(q):
    r = sh("curl", "-s", "--max-time", "5", "--get", "--data-urlencode", f"q={q}",
           f"{URL}/search")
    m = re.search(r"<code>(.*?)</code>", r.stdout, re.S)
    # L'app scappa l'HTML per mostrarlo a schermo. In slide serve la stringa
    # com'era, altrimenti si legge &#x27; al posto dell'apostrofo.
    return html.unescape(m.group(1)) if m else ""


def righe_log(servizio, da):
    """Le regole scattate dopo la riga `da`. Torna (nuovo_indice, [(id, msg)])."""
    r = sh("docker", "compose", "logs", "--no-color", servizio, cwd=RADICE / "demo")
    righe = r.stdout.splitlines()
    fuori, visti = [], set()
    for riga in righe[da:]:
        i = riga.find("{")
        if i < 0:
            continue
        try:
            msg = json.loads(riga[i:]).get("msg", "")
        except json.JSONDecodeError:
            continue
        mid, mmsg = ID.search(msg), MSG.search(msg)
        # 980170 e' il riepilogo dei punteggi del CRS 4: una riga lunga che in
        # slide non si legge. Il totale che conta sta gia' in 949110.
        if mid and mmsg and mid.group(1) not in visti and mid.group(1) != "980170":
            visti.add(mid.group(1))
            fuori.append((mid.group(1), mmsg.group(1)))
    return len(righe), fuori


def comando_visibile(q):
    """Il curl come va scritto in slide.

    La forma percent-encoded e' illeggibile da dieci metri: `q=1%27%20OR%201%3D1--`
    non dice niente a nessuno. Con -G e --data-urlencode il payload si legge in
    chiaro, ed e' letteralmente il comando che questo script esegue.
    """
    return f'curl -i -G --data-urlencode "q={q}" {URL}/search'


# Ogni scena: (etichetta, query, cosa spiegare)
SCENE = {
    "nowaf": [
        ("Una ricerca normale", "tastiera meccanica"),
        ("Una SQL injection", "1' OR 1=1--"),
    ],
    "detect": [
        ("La stessa SQL injection", "1' OR 1=1--"),
    ],
    "block": [
        ("Una ricerca normale", "tastiera meccanica"),
        ("Una SQL injection", "1' OR 1=1--"),
        ("Un XSS", "<script>alert(1)</script>"),
    ],
    "paranoid": [
        ("Una ricerca legittima di un libro", "C++ & C# -- guida"),
        ("La SQL injection, sempre presa", "1' OR 1=1--"),
    ],
    "tuned": [
        ("La stessa ricerca legittima", "C++ & C# -- guida"),
        ("La SQL injection, ancora presa", "1' OR 1=1--"),
    ],
}

TITOLI = {
    "nowaf": "Senza WAF: quello che arriva all'applicazione",
    "detect": "DetectionOnly: guarda e scrive, non blocca",
    "block": "Blocking: 403",
    "paranoid": "Paranoia 3: copre di piu' e sbaglia",
    "tuned": "Dopo il tuning: il falso positivo e' risolto",
}


def main():
    USCITA.mkdir(parents=True, exist_ok=True)
    indice = ["# Materiale per le slide",
              "",
              "Generato da `make cattura`. Ogni file e' un momento della demo, con il",
              "comando come va mostrato e l'output come e' uscito davvero.",
              "",
              "Rigenerabile: se cambi una regola o un payload, rilancia e le slide",
              "tornano allineate al repo.",
              ""]

    for profilo, scene in SCENE.items():
        print(f"  {profilo} ...", flush=True)
        if not avvia(profilo):
            print(f"  ATTENZIONE: il profilo {profilo} non risponde, salto", file=sys.stderr)
            continue
        servizio = f"caddy-{profilo}"
        cursore, _ = righe_log(servizio, 0)

        out = [f"# {TITOLI[profilo]}", "", f"Profilo: `make {profilo}`", ""]
        for etichetta, q in scene:
            code = stato(q)
            cursore, regole = righe_log(servizio, cursore)
            out += [f"## {etichetta}", "", "**Input**", "", "```console",
                    f"$ {comando_visibile(q)}", "```", "", "**Output**", "",
                    "```console", f"HTTP/1.1 {code} {'OK' if code == '200' else 'Forbidden'}", "```", ""]
            if profilo == "nowaf" and code == "200":
                ricevuto = corpo(q)
                if ricevuto:
                    out += ["**Cosa ha ricevuto l'applicazione**", "", "```",
                            ricevuto, "```", "",
                            "> Nessuno l'ha fermata: la stringa e' arrivata intera al backend.", ""]
            if regole:
                out += ["**Cosa ha scritto il WAF**", "", "```"]
                out += [f"{rid}  {msg}" for rid, msg in regole]
                out += ["```", ""]
            elif profilo != "nowaf":
                out += ["Nessuna regola scattata.", ""]

        percorso = USCITA / f"{profilo}.md"
        percorso.write_text("\n".join(out), encoding="utf-8")
        indice.append(f"- [{TITOLI[profilo]}]({profilo}.md)")

    (USCITA / "README.md").write_text("\n".join(indice) + "\n", encoding="utf-8")
    sh("make", "-s", "down", cwd=RADICE)
    print(f"\n  Scritto in {USCITA.relative_to(RADICE)}/\n")


if __name__ == "__main__":
    main()
