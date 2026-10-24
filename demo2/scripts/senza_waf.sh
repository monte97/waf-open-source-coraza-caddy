#!/usr/bin/env bash
# I sei attacchi di prove.sh, ma senza WAF: direttamente alle app, sulla porta
# 8082 (il Caddy senza WAF, sempre acceso). Per ognuno: arriva all'app? e
# l'app cosa ne fa? Non basta il codice HTTP: lo script controlla l'effetto.
#   make senza-waf
set -u
cd "$(dirname "$0")/.."
CLOUD=http://cloud.localhost:8082
GIT=http://git.localhost:8082
U=prova; P=prova-demo2-2026
DAV=$CLOUD/remote.php/dav/files/$U

VERDE=$'\e[1;92m'; ROSSO=$'\e[1;91m'; TENUE=$'\e[37m'; BIANCO=$'\e[1;97m'; AZZURRO=$'\e[1;96m'; FINE=$'\e[0m'
W1=9; W2=4; W3=36; W4=34   # stretta: sul palco il carattere e' grande
linea() { local s="$1"; for w in $W1 $W2 $W3 $W4; do s+=$(printf '─%.0s' $(seq 1 $((w+2)))); s+="$2"; done; printf "  %s%s%s\n" "$TENUE" "${s%?}$3" "$FINE"; }
cella() { printf " %-*s ${TENUE}│${FINE}" "$1" "$2"; }

RESPINTI=0; RIUSCITI=0
riga() { # respinto si/no, codice, attacco, cosa ha fatto l'app
  local esito colore
  if [ "$1" = si ]; then esito=respinto; colore=$VERDE; RESPINTI=$((RESPINTI+1)); else esito=riuscito; colore=$ROSSO; RIUSCITI=$((RIUSCITI+1)); fi
  printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$colore$(cella $W1 "$esito")" "$(cella $W2 "$2")" "$BIANCO$(cella $W3 "$3")" "$(cella $W4 "$4")"
}
c() { curl -s --max-time 30 -u "$U:$P" "$@"; }

# preparazione: la cartella e il repo di prova, senza WAF non serve passare da dietro
c -o /dev/null -X MKCOL "$DAV/prove-waf"
c -o /dev/null -X DELETE "$DAV/prove-waf/shell.php"
[ "$(c -o /dev/null -w '%{http_code}' "$GIT/api/v1/repos/$U/prove-waf")" = 200 ] || \
  c -o /dev/null -X POST -H 'Content-Type: application/json' -d '{"name":"prove-waf","auto_init":true}' "$GIT/api/v1/user/repos"

echo "${AZZURRO}» gli stessi sei attacchi, senza WAF: direttamente a Nextcloud e Gitea (porta 8082)${FINE}"
echo ""
linea "┌" "┬" "┐"
printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$BIANCO$(cella $W1 ESITO)" "$BIANCO$(cella $W2 HTTP)" "$BIANCO$(cella $W3 ATTACCO)" "$BIANCO$(cella $W4 "COSA NE FA L'APP")"
linea "├" "┼" "┤"

# 1. SQL injection nel login: se l'app la rifiuta, torna al form di login
out=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --data-urlencode "user=admin' OR 1=1--" --data-urlencode 'password=x' "$CLOUD/login")
code=${out%% *}; dove=${out#* }
[[ "$dove" == *"/login"* ]] && riga si "$code" "SQL injection nel login di Nextcloud" "rifiuta, torna al login" \
                             || riga no "$code" "SQL injection nel login di Nextcloud" "ha fatto entrare: $dove"

# 2. uscire dalla cartella dei file con ../
code=$(c -o /dev/null -w '%{http_code}' "$DAV/prove-waf/..%2f..%2f..%2f..%2fetc%2fpasswd")
[ "$code" = 404 ] && riga si "$code" "esce dalla cartella dei file" "file non trovato" \
                  || riga no "$code" "esce dalla cartella dei file" "ha risposto $code: da guardare"

# 3. una web shell PHP: la carica, ma il codice gira? riletta, deve tornare il sorgente
printf '<?php system($_GET["c"]); ?>\n' > /tmp/demo2-shell.php
code=$(c -o /dev/null -w '%{http_code}' -T /tmp/demo2-shell.php "$DAV/prove-waf/shell.php")
letta=$(c "$DAV/prove-waf/shell.php?c=id")
[[ "$letta" == *'<?php system'* ]] && riga si "$code" "carica una web shell PHP" "la salva: riletta, e' solo testo" \
                                   || riga no "$code" "carica una web shell PHP" "risposta diversa dal file: da guardare"
rm -f /tmp/demo2-shell.php

# 4. SQL injection nella ricerca di Gitea: la query deve tornare come testo nel campo
pagina=$(curl -s -w '\n%{http_code}' --get --data-urlencode "q=' UNION SELECT passwd FROM user--" "$GIT/explore/repos")
code=${pagina##*$'\n'}
[ "$code" = 200 ] && [[ "$pagina" == *'value="&#39; UNION SELECT passwd FROM user--"'* ]] \
  && riga si "$code" "SQL injection nella ricerca di Gitea" "la cerca come testo" \
  || riga no "$code" "SQL injection nella ricerca di Gitea" "risposta inattesa: da guardare"

# 5 e 6. XSS in una issue: la crea, poi la pagina deve mostrare lo script come testo
xss() { # campo, descrizione
  local json n code pagina
  if [ "$1" = title ]; then json='{"title":"<script>alert(1)</script>","body":"ciao"}'; else json='{"title":"ciao","body":"<script>alert(1)</script>"}'; fi
  out=$(c -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' -d "$json" "$GIT/api/v1/repos/$U/prove-waf/issues")
  code=${out##*$'\n'}; n=$(printf '%s' "${out%$'\n'*}" | /usr/bin/python3 -c 'import sys,json; print(json.load(sys.stdin).get("number",""))' 2>/dev/null)
  pagina=$(c "$GIT/$U/prove-waf/issues/$n")
  if [[ "$pagina" == *'&lt;script&gt;alert(1)&lt;/script&gt;'* ]] && [[ "$pagina" != *'<script>alert(1)</script>'* ]]; then
    riga si "$code" "$2" "la mostra come testo"
  else
    riga no "$code" "$2" "lo script e' nella pagina"
  fi
}
xss title "XSS nel titolo di una issue"
xss body  "XSS nel testo di una issue"
linea "└" "┴" "┘"
echo ""
echo "${AZZURRO}» arrivano tutti e 6; respinti dalle app ${VERDE}$RESPINTI${AZZURRO}, riusciti ${ROSSO}$RIUSCITI${FINE}"
echo "  ${TENUE}con questi attacchi classici le app si difendono da sole: il WAF serve per quelli che non conoscono${FINE}"
echo ""
