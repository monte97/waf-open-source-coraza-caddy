"""Riassunto dei CSV di GoTestWAF per codifica, posizione e famiglia.

    python3 misure/per_codifica.py misure/risultati block paranoid

GoTestWAF manda ogni attacco in piu' varianti: in chiaro, codificato per
l'URL e codificato in Base64. Il WAF non decodifica il Base64, quindi quelle
varianti passano tutte; sono pericolose solo per un'app che decodifica da sola
il Base64 che riceve. Questo script separa i conti.
"""
import collections
import csv
import sys

csv.field_size_limit(sys.maxsize)
cartella, profili = sys.argv[1], sys.argv[2:]


def quota(righe):
    fermati = sum(r["Test Result"] == "passed" for r in righe)
    return f"{fermati}/{len(righe)} ({100 * fermati / max(len(righe), 1):.0f}%)"


for profilo in profili:
    righe = list(csv.DictReader(open(f"{cartella}/{profilo}.csv")))
    attacchi = [r for r in righe if r["Set"] != "false-pos"]
    oneste = [r for r in righe if r["Set"] == "false-pos"]
    senza_b64 = [r for r in attacchi if r["Encoder"] != "Base64Flat"]
    print(f"== {profilo}")
    print(f"  tutti gli attacchi:     {quota(attacchi)}")
    print(f"  senza le varianti Base64: {quota(senza_b64)}")
    print(f"  oneste bloccate:        {len(oneste) - sum(r['Test Result'] == 'passed' for r in oneste)}/{len(oneste)}")
    per_codifica = collections.defaultdict(list)
    for r in attacchi:
        per_codifica[r["Encoder"]].append(r)
    print("  per codifica:  " + "; ".join(f"{k} {quota(v)}" for k, v in per_codifica.items()))
    per_famiglia = collections.defaultdict(list)
    for r in senza_b64:
        per_famiglia[r["Case"] if r["Set"] == "owasp" else r["Set"]].append(r)
    print("  per famiglia, senza Base64:  " + "; ".join(
        f"{k} {quota(v)}" for k, v in sorted(per_famiglia.items(), key=lambda x: -len(x[1]))))
