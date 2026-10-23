#!/usr/bin/env bash
# GoTestWAF e Nuclei contro i profili della demo, con il backend da misura al
# posto dell'app. Report grezzi in misure/risultati/, fuori da git.
set -u
cd "$(dirname "$0")/.."
DC="docker compose -f demo/docker-compose.yml -f misure/compose.yml"
TUTTI="--profile nowaf --profile detect --profile block --profile paranoid --profile tuned"
URL=http://localhost:8080
OUT=$PWD/misure/risultati
mkdir -p "$OUT"

avvia() {
  $DC $TUTTI down --remove-orphans >/dev/null 2>&1
  $DC --profile "$1" up -d >/dev/null 2>&1
  for _ in $(seq 1 60); do [ "$(curl -s -o /dev/null -w '%{http_code}' $URL/)" = 200 ] && return 0; sleep 1; done
  echo "  $1 non parte"; return 1
}
hits() { $DC logs --no-color app | grep -c hit; }

echo "GoTestWAF"
for p in nowaf detect block paranoid tuned; do
  avvia $p || continue
  extra=""; case $p in nowaf|detect) extra="--skipWAFBlockCheck";; esac
  docker run --rm --add-host=host.docker.internal:host-gateway -v "$OUT:/app/reports" wallarm/gotestwaf:0.5.8 \
    --url=http://host.docker.internal:8080/ --noEmailReport --reportFormat=json --reportName="$p" \
    --skipWAFIdentification $extra > "$OUT/$p.log" 2>&1
done
python3 misure/sintesi.py "$OUT"

echo "Nuclei: richieste arrivate al backend"
# I template stanno in un volume Docker. -duc spegne anche lo scaricamento
# automatico, quindi vanno aggiornati qui: con il volume vuoto Nuclei non manda
# niente e il conteggio esce a zero.
docker run --rm -v nuclei-templates:/root/nuclei-templates projectdiscovery/nuclei:v3.11.1 -ut -silent >/dev/null 2>&1
for p in nowaf block paranoid; do
  avvia $p || continue
  prima=$(hits)
  docker run --rm --add-host=host.docker.internal:host-gateway -v nuclei-templates:/root/nuclei-templates \
    projectdiscovery/nuclei:v3.11.1 -u http://host.docker.internal:8080 \
    -tags exposure,lfi,sqli,xss,rce,misconfig -rl 200 -c 50 -nmhe -silent -duc >/dev/null 2>&1
  echo "  $p: $(( $(hits) - prima ))"
done

$DC $TUTTI down --remove-orphans >/dev/null 2>&1
