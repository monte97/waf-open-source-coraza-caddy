"""Quanto ferma il WAF delle richieste di Nuclei che portano qualcosa.

    python3 misure/nuclei_contenuto.py [profilo]     (default: block)

L'etichetta di un template (sqli, rce...) dice cosa cerca lo scanner, non
cosa contiene ogni richiesta: molti template prima chiedono se un prodotto
esiste (GET /adminer-4.7.3.php, GET /?HTTP_CLIENT_IP) e attaccano solo dopo.
Quelle sonde non portano niente, e un WAF fa bene a lasciarle passare.
Qui si contano solo le richieste con almeno un parametro con un valore, o con
un corpo. E' una stima prudente: fra queste ci sono anche richieste innocue
(?wt=json), che passando abbassano la percentuale.
"""
import collections
import pathlib
import re

CARTELLA = pathlib.Path(__file__).resolve().parent / "risultati" / "nuclei"


def carica(nome):
    conteggio = collections.Counter()
    for riga in (CARTELLA / nome).read_text(errors="ignore").splitlines():
        m = re.match(r"hit (\S+) (\S*) (b'.*'|b\".*\")$", riga)
        if m:
            conteggio[m.groups()] += 1
    return conteggio


def porta_qualcosa(richiesta):
    _, percorso, corpo = richiesta
    query = percorso.split("?", 1)[1] if "?" in percorso else ""
    valori = any("=" in p and p.split("=", 1)[1] for p in query.split("&"))
    return valori or corpo not in ("b''", 'b""')


import sys

profilo = sys.argv[1] if len(sys.argv) > 1 else "block"
totale = [0, 0]
for tipo in ("sqli", "xss", "lfi", "rce"):
    senza, con = carica(f"nowaf-{tipo}.txt"), carica(f"{profilo}-{tipo}.txt")
    inviate = sum(n for r, n in senza.items() if porta_qualcosa(r))
    passate = sum(min(n, con.get(r, 0)) for r, n in senza.items() if porta_qualcosa(r))
    totale[0] += inviate
    totale[1] += inviate - passate
    print(f"{tipo:5} {inviate - passate}/{inviate} fermate ({100 * (inviate - passate) / inviate:.0f}%)")
print(f"tutte {totale[1]}/{totale[0]} fermate ({100 * totale[1] / totale[0]:.0f}%)")
