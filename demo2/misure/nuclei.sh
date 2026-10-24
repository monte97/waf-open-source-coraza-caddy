#!/usr/bin/env bash
# Nuclei contro Nextcloud e Gitea veri, senza WAF (porta 8082) e con il WAF
# acceso (porta 8081, il profilo che c'e': per la misura del talk su-misura).
# Stessi template e stesso ritmo della misura della demo principale
# (misure/scan.sh), un po' piu' lento per non affogare Nextcloud.
#
# Per ogni giro conta, dal registro di Caddy: le richieste arrivate, quelle che
# il WAF ha fermato prima dell'app, e cosa ha trovato Nuclei (i finding).
#   bash misure/nuclei.sh      (dalla cartella demo2, una decina di minuti)
set -u
cd "$(dirname "$0")/.."
OUT=misure/risultati; mkdir -p "$OUT"
NUCLEI="docker run --rm --add-host=host.docker.internal:host-gateway -v nuclei-templates:/root/nuclei-templates projectdiscovery/nuclei:v3.11.1"
$NUCLEI -ut -silent >/dev/null 2>&1   # template aggiornati: con il volume vuoto Nuclei non manda niente

PROFILO=$(docker compose ps --services | grep '^caddy-' | grep -v '^caddy-nowaf$' | head -1)
for porta in 8082 8081; do
  if [ $porta = 8082 ]; then servizio=caddy-nowaf; nome=senza-waf; else servizio=$PROFILO; nome=${PROFILO#caddy-}; fi
  for app in cloud git; do
    inizio=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    $NUCLEI -u "http://host.docker.internal:$porta" -H "Host: $app.localhost:$porta" \
      -tags exposure,lfi,sqli,xss,rce,misconfig -rl 100 -c 25 -nmhe -silent -duc -jsonl \
      > "$OUT/$nome-$app.jsonl" 2>/dev/null
    docker compose logs --no-log-prefix --since "$inizio" $servizio > "$OUT/$nome-$app.log" 2>&1
    /usr/bin/python3 - "$OUT/$nome-$app.log" "$OUT/$nome-$app.jsonl" "$nome" "$app" <<'EOF'
import json, re, sys
log, finding, nome, app = sys.argv[1:]
arrivate = bloccate = 0; ids = set(); stati = {}
for riga in open(log):
    try: r = json.loads(riga)
    except ValueError: continue
    if r.get("logger") == "http.log.access":
        arrivate += 1; s = r.get("status", 0); stati[s] = stati.get(s, 0) + 1
    m = r.get("msg", "")
    u = re.search(r'\[unique_id "([^"]+)"\]', m); rid = re.search(r'\[id "(\d+)"\]', m)
    if u and rid and (rid[1] == "949110" or rid[1].startswith("2000")): ids.add(u[1])
bloccate = len(ids)
f = [json.loads(l) for l in open(finding) if l.strip()]
nomi = sorted({x.get("template-id", "?") + ":" + x.get("info", {}).get("severity", "?") for x in f})
top = ", ".join(f"{k}:{v}" for k, v in sorted(stati.items(), key=lambda kv: -kv[1])[:6])
print(f"{nome:10} {app:6} richieste a Caddy {arrivate:6}   fermate dal WAF {bloccate:6}   stati {top}")
print(f"{'':17} finding {len(f):3}  {', '.join(nomi)[:400]}")
EOF
  done
done
