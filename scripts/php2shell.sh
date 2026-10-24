#!/usr/bin/env bash
# Gli indicatori di PHP2Shell (CVE-2026-109618 e CVE-2026-109619) contro il
# profilo acceso. Nessun exploit: richieste innocue che portano gli indicatori
# usati dai difensori, mandate a un PHP gia' corretto. Misurano se il WAF
# riconosce gli indicatori, non se un attacco vero riuscirebbe o verrebbe fermato.
#   make block && make php2shell
set -u
# -H "Expect:": curl aggiunge da solo «Expect: 100-continue» ai corpi grandi, e il
# CRS lo blocca (regola 920450). Lo togliamo, cosi' si misura la forma e non curl.
URL=http://localhost:8080/php/
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'una relazione qualunque\n' > "$TMP/relazione.txt"
head -c 1048576 /dev/zero | tr '\0' 'a' > "$TMP/grande.txt"

VERDE=$'\e[1;92m'; ROSSO=$'\e[1;91m'; GRIGIO=$'\e[37m'; BIANCO=$'\e[1;97m'; AZZURRO=$'\e[1;96m'; FINE=$'\e[0m'
ONESTE=0; FORME=0

prova() { # tipo, descrizione, dettaglio, argomenti per curl
  local tipo=$1 descr=$2 dett=$3; shift 3
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -H "Expect:" "$@" "$URL")
  if [ "$code" = 200 ]; then esito="${VERDE}passa   ${FINE}"; [ "$tipo" = onesta ] && ONESTE=$((ONESTE+1))
  else esito="${ROSSO}bloccata${FINE}"; [ "$tipo" = indicatore ] && FORME=$((FORME+1)); fi
  printf "  %s  %-4s  %-10s %-30s ${GRIGIO}%s${FINE}\n" "$esito" "$code" "$tipo" "$descr" "$dett"
}

# Gli indicatori sono quelli che i difensori usano per riconoscere PHP2Shell:
# il campo dell'avanzamento dell'upload (PHP stesso, come mitigazione
# temporanea, suggerisce di spegnere session.upload_progress) e lo user agent
# dei PoC pubblici (bloccato dal CRS dal 22/10, PR #4893, non ancora rilasciato).
# Non e' l'attacco: misura se il WAF riconosce gli indicatori, non se un exploit
# passerebbe. L'ultima riga e' un limite, non un indicatore: un upload grande.
echo "${AZZURRO}» gli indicatori di PHP2Shell contro il servizio PHP (8.4.27, gia' corretto: nessun exploit)${FINE}"
echo ""
printf "  ${BIANCO}%-8s  %-4s  %-10s %-30s %s${FINE}\n" ESITO HTTP TIPO RICHIESTA COME
prova onesta     "apre la pagina"                "GET /php/"
prova onesta     "carica un file piccolo"        "multipart, 24 byte" \
  -F "documento=@$TMP/relazione.txt"
prova indicatore "campo dell'upload progress"    "multipart + PHP_SESSION_UPLOAD_PROGRESS" \
  -b "PHPSESSID=demo0000000000000000000000" \
  -F "PHP_SESSION_UPLOAD_PROGRESS=demo" -F "documento=@$TMP/relazione.txt"
prova indicatore "user agent di un PoC pubblico" "User-Agent: php2shell-verify/1.0" \
  -A "php2shell-verify/1.0"
prova limite     "un upload grande"              "multipart, 1 MiB" \
  -F "documento=@$TMP/grande.txt"
echo ""
echo "${AZZURRO}» oneste passate ${VERDE}$ONESTE${AZZURRO} su 2, indicatori bloccati ${ROSSO}$FORME${AZZURRO} su 2${FINE}"
echo "  ${GRIGIO}limite: un upload grande il WAF non lo distingue da un attacco; la cura e' aggiornare PHP${FINE}"
echo ""
