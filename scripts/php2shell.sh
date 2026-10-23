#!/usr/bin/env bash
# La forma di PHP2Shell (CVE-2026-109618 e CVE-2026-109619) contro il profilo
# acceso. Nessun exploit: sono richieste innocue che hanno la stessa forma
# descritta negli avvisi pubblici (AWS, 21/10/2026), mandate a un PHP gia'
# corretto. Misurano cosa riconosce il WAF, non se l'attacco riuscirebbe.
#   make block && make php2shell
set -u
# -H "Expect:": curl aggiunge da solo «Expect: 100-continue» ai corpi grandi, e il
# CRS lo blocca (regola 920450). Lo togliamo, cosi' si misura la forma e non curl.
URL=http://localhost:8080/php/
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'una relazione qualunque\n' > "$TMP/relazione.txt"
head -c 1048576 /dev/zero | tr '\0' 'a' > "$TMP/grande.txt"

VERDE=$'\e[32m'; ROSSO=$'\e[31m'; GRIGIO=$'\e[90m'; FINE=$'\e[0m'

prova() { # tipo, descrizione, dettaglio, argomenti per curl
  local tipo=$1 descr=$2 dett=$3; shift 3
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -H "Expect:" "$@" "$URL")
  if [ "$code" = 200 ]; then esito="${VERDE}passa   ${FINE}"; else esito="${ROSSO}bloccata${FINE}"; fi
  printf "  %s  %-8s %-36s ${GRIGIO}%s${FINE}\n" "$esito" "$tipo" "$descr" "$dett"
}

echo ""
prova onesta "apre la pagina"                   "GET /php/"
prova onesta "carica un file piccolo"           "multipart, 24 byte" \
  -F "documento=@$TMP/relazione.txt"
prova forma  "campo upload progress (CVE …619)"     "multipart + PHP_SESSION_UPLOAD_PROGRESS" \
  -b "PHPSESSID=demo0000000000000000000000" \
  -F "PHP_SESSION_UPLOAD_PROGRESS=demo" -F "documento=@$TMP/relazione.txt"
prova forma  "corpo grande (CVE …618)"              "multipart, 1 MiB" \
  -F "documento=@$TMP/grande.txt"
prova forma  "user agent di un PoC pubblico"    "User-Agent: php2shell-verify/1.0" \
  -A "php2shell-verify/1.0"
echo ""
