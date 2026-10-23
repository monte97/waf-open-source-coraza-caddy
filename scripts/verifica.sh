#!/usr/bin/env bash
# Accende i cinque profili uno per uno e verifica che ognuno si comporti come
# promesso dal talk. Ogni riga e' un momento della demo.
set -u
URL=http://localhost:8080
ATTESO_OK=200

chiedi() { curl -s -o /dev/null -w "%{http_code}" --max-time 5 --get --data-urlencode "q=$1" "$URL/search"; }

riga() { # profilo, atteso_pulita, atteso_attacco, atteso_falsopositivo
  make -s "$1" >/dev/null 2>&1
  for _ in $(seq 1 30); do [ "$(chiedi tastiera)" = "200" ] && break; sleep 1; done
  local pulita attacco fp esito
  pulita=$(chiedi "tastiera meccanica")
  attacco=$(chiedi "1' OR 1=1--")
  fp=$(chiedi "C++ & C# -- guida")
  esito="ok"
  [ "$pulita" = "$2" ] || esito="DIVERSO"
  [ "$attacco" = "$3" ] || esito="DIVERSO"
  [ "$fp" = "$4" ] || esito="DIVERSO"
  printf "  %-9s pulita %s (atteso %s)   attacco %s (atteso %s)   legittima-strana %s (atteso %s)   %s\n" \
    "$1" "$pulita" "$2" "$attacco" "$3" "$fp" "$4" "$esito"
  [ "$esito" = "ok" ]
}

echo ""
echo "  Verifica dei cinque profili."
echo ""
ko=0
riga nowaf    200 200 200 || ko=1   # nessuno filtra: passa tutto, anche l'attacco
riga detect   200 200 200 || ko=1   # il WAF guarda e scrive nel log, non blocca
riga block    200 403 200 || ko=1   # blocca l'attacco, il traffico onesto passa
riga paranoid 200 403 403 || ko=1   # copre di piu' e sbaglia: falso positivo
riga tuned    200 403 200 || ko=1   # falso positivo risolto, attacco ancora preso
echo ""
if [ "$ko" = "0" ]; then echo "  Tutti e cinque i profili si comportano come promesso."; else
  echo "  ATTENZIONE: almeno un profilo non si comporta come promesso. Non salire sul palco cosi'."; fi
echo ""
make -s down >/dev/null 2>&1
exit "$ko"
