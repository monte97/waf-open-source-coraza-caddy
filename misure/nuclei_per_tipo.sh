#!/usr/bin/env bash
# Nuclei per tipo di template (sqli, xss, lfi, rce), senza WAF e con il WAF al
# livello 1. Il backend da misura scrive ogni richiesta che riceve: i log vanno
# in misure/risultati/nuclei/ e misure/nuclei_contenuto.py li confronta.
#   bash misure/nuclei_per_tipo.sh && python3 misure/nuclei_contenuto.py
set -u
cd "$(dirname "$0")/.."
docker run --rm -v nuclei-templates:/root/nuclei-templates projectdiscovery/nuclei:v3.11.1 -ut -silent >/dev/null 2>&1
DC="docker compose -f demo/docker-compose.yml -f misure/compose.yml"
ALL="--profile nowaf --profile block --profile detect --profile paranoid --profile tuned --profile toppa --profile guarda --profile sumisura"
mkdir -p misure/risultati/nuclei
for p in ${PROFILI:-nowaf block}; do
  for t in sqli xss lfi rce; do
    $DC $ALL down --remove-orphans >/dev/null 2>&1
    $DC --profile $p up -d >/dev/null 2>&1
    for _ in $(seq 1 60); do [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)" = 200 ] && break; sleep 1; done
    docker run --rm --add-host=host.docker.internal:host-gateway -v nuclei-templates:/root/nuclei-templates projectdiscovery/nuclei:v3.11.1 -u http://host.docker.internal:8080 -tags "$t" -rl 200 -c 50 -nmhe -silent -duc >/dev/null 2>&1
    $DC logs --no-color app | grep " hit " | sed 's/^[^|]*| //' > misure/risultati/nuclei/$p-$t.txt
    echo "$p $t $(wc -l < misure/risultati/nuclei/$p-$t.txt)"
  done
done
$DC $ALL down --remove-orphans >/dev/null 2>&1
