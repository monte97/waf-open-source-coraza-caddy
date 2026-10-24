#!/usr/bin/env bash
# Le cose che fa un utente vero su Nextcloud e Gitea, una riga ciascuna,
# contro il profilo acceso: funziona o si rompe, e con che codice.
#   make waf && make prove
# Ogni giro riparte pulito e ogni riga e' indipendente: cartella, file e repo
# di prova li prepara lo script passando DIETRO Caddy (vedi sotto).
set -u
cd "$(dirname "$0")/.."
CLOUD=http://cloud.localhost:8081
GIT=http://git.localhost:8081
U=prova; P=prova-demo2-2026
DAV=$CLOUD/remote.php/dav/files/$U
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

VERDE=$'\e[1;92m'; ROSSO=$'\e[1;91m'; TENUE=$'\e[37m'; BIANCO=$'\e[1;97m'; AZZURRO=$'\e[1;96m'; FINE=$'\e[0m'
W1=9; W2=4; W3=40; W4=24   # stretta: sul palco il carattere e' grande
linea() { local s="$1"; for w in $W1 $W2 $W3 $W4; do s+=$(printf '─%.0s' $(seq 1 $((w+2)))); s+="$2"; done; printf "  %s%s%s\n" "$TENUE" "${s%?}$3" "$FINE"; }
cella() { printf " %-*s ${TENUE}│${FINE}" "$1" "$2"; }
gruppo() { printf "  ${TENUE}│${FINE} ${AZZURRO}%-*s${FINE} ${TENUE}│${FINE}\n" $((W1+W2+W3+W4+9)) "$1"; }

OK=0; ROTTE=0
riga() { # codice ottenuto, codici attesi (regex), cosa fa l'utente, come
  local esito colore
  if [[ "$1" =~ ^($2)$ ]]; then esito=funziona; colore=$VERDE; OK=$((OK+1)); else esito=rotto; colore=$ROSSO; ROTTE=$((ROTTE+1)); fi
  printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$colore$(cella $W1 "$esito")" "$(cella $W2 "$1")" "$BIANCO$(cella $W3 "$3")" "$(cella $W4 "$4")"
  [ -n "${CSV:-}" ] && echo "$3;$1;$esito" >> "$CSV"
  return 0
}
FERMATI=0; PASSATI=0
attacco() { # codice ottenuto, cosa prova chi attacca, come
  local esito colore
  if [ "$1" = 403 ]; then esito=fermato; colore=$VERDE; FERMATI=$((FERMATI+1)); else esito=passato; colore=$ROSSO; PASSATI=$((PASSATI+1)); fi
  printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$colore$(cella $W1 "$esito")" "$(cella $W2 "$1")" "$BIANCO$(cella $W3 "$2")" "$(cella $W4 "$3")"
  [ -n "${CSV:-}" ] && echo "$2;$1;$esito" >> "$CSV"
}
c() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 -u "$U:$P" "$@"; }

# ── i file di prova ─────────────────────────────────────────────────────────
printf 'Lista della spesa: pane, latte, caffe.\n' > "$TMP/spesa.txt"
printf 'SELECT nome, email FROM clienti WHERE attivo = 1; -- query del report mensile\n' > "$TMP/report.sql"
# byte "a caso" ma sempre gli stessi: con byte davvero casuali il WAF a volte
# blocca col punteggio (403) e a volte con la 200007, troppi argomenti (400)
/usr/bin/python3 -c 'import random,sys; sys.stdout.buffer.write(random.Random(2026).randbytes(300000))' > "$TMP/foto.jpg"
head -c 20000000 /dev/zero > "$TMP/video.mp4"

# ── pulizia e preparazione, DIETRO il WAF ───────────────────────────────────
# Dal container di Nextcloud, direttamente ai servizi: il WAF sta in Caddy e
# qui non c'e'. Cosi' ogni riga della tabella e' indipendente dalle altre:
# se il WAF blocca il caricamento, lo scaricamento ha comunque il suo file.
dietro() { docker compose exec -T nextcloud curl -s -o /dev/null -u "$U:$P" "$@"; }
NC=(-H 'Host: cloud.localhost:8081'); NCDAV=http://localhost/remote.php/dav/files/$U
dietro "${NC[@]}" -X DELETE "$NCDAV/prove-waf"
dietro "${NC[@]}" -X MKCOL "$NCDAV/prove-waf"
dietro "${NC[@]}" -T - "$NCDAV/prove-waf/spesa.txt" < "$TMP/spesa.txt"
dietro "${NC[@]}" -T - "$NCDAV/prove-waf/foto.jpg" < "$TMP/foto.jpg"
for r in prove-waf prove-waf-nuovo; do dietro -X DELETE "http://gitea:3000/api/v1/repos/$U/$r"; done
dietro -X POST -H 'Content-Type: application/json' -d '{"name":"prove-waf","auto_init":true}' "http://gitea:3000/api/v1/user/repos"

echo "${AZZURRO}» faccio quello che fa un utente, su Nextcloud e Gitea (porta 8081)${FINE}"
echo ""
linea "┌" "┬" "┐"
printf "  ${TENUE}│${FINE}%s%s%s%s\n" "$BIANCO$(cella $W1 ESITO)" "$BIANCO$(cella $W2 HTTP)" "$BIANCO$(cella $W3 "COSA FA L'UTENTE")" "$BIANCO$(cella $W4 COME)"
linea "├" "┴" "┤"
gruppo "Nextcloud: browser, client di sincronizzazione, API"
linea "├" "┬" "┤"
riga "$(curl -s -o /dev/null -w %{http_code} "$CLOUD/login")"                                            200     "apre la pagina di login"              "GET /login"
riga "$(c -X PROPFIND -H 'Depth: 1' "$DAV/")"                            207     "il client elenca i file"              "PROPFIND (WebDAV)"
riga "$(c -X MKCOL "$DAV/prove-waf/nuova")"                                    201     "crea una cartella"                    "MKCOL"
riga "$(c -T "$TMP/spesa.txt" "$DAV/prove-waf/spesa.txt")"               '201|204' "carica un file di testo"            "PUT, senza Content-Type"
riga "$(c -T "$TMP/report.sql" "$DAV/prove-waf/report.sql")"             '201|204' "carica un file con dentro una query" "PUT, testo come SQL"
riga "$(c -T "$TMP/foto.jpg" -H 'Content-Type: image/jpeg' "$DAV/prove-waf/foto.jpg")" '201|204' "carica una foto dal browser" "PUT, image/jpeg"
riga "$(c -T "$TMP/video.mp4" -H 'Content-Type: video/mp4' -H 'Expect:' "$DAV/prove-waf/video.mp4")" '201|204' "carica un video da 20 MB" "PUT, video/mp4"
riga "$(c "$DAV/prove-waf/spesa.txt")"                                   200     "scarica un file"                      "GET"
riga "$(c -X MOVE -H "Destination: $DAV/prove-waf/foto-mare.jpg" "$DAV/prove-waf/foto.jpg")" '201|204' "rinomina un file" "MOVE"
riga "$(c -X POST -H 'OCS-APIRequest: true' --data 'path=/prove-waf/spesa.txt&shareType=3' "$CLOUD/ocs/v2.php/apps/files_sharing/api/v1/shares")" 200 "condivide un file con un link" "POST /ocs, form"
riga "$(c -X DELETE "$DAV/prove-waf/spesa.txt")"                          204     "cancella un file"                     "DELETE"
linea "├" "┴" "┤"
gruppo "Gitea: browser, git, API"
linea "├" "┬" "┤"
riga "$(c "$GIT/explore/repos")"                                         200     "apre l'elenco dei repository"         "GET /explore/repos"
riga "$(c -X POST -H 'Content-Type: application/json' -d '{"name":"prove-waf-nuovo","auto_init":true}' "$GIT/api/v1/user/repos")" 201 "crea un repository" "POST /api/v1, JSON"
git -c credential.helper= clone -q "http://$U:$P@git.localhost:8081/$U/prove-waf.git" "$TMP/repo" >/dev/null 2>&1; e=$?
riga "$([ $e = 0 ] && echo 200 || echo git)" 200 "clona il repository" "git clone (HTTP)"
if [ -d "$TMP/repo" ]; then
  cp "$TMP/report.sql" "$TMP/repo/"; git -C "$TMP/repo" add . >/dev/null 2>&1
  git -C "$TMP/repo" -c user.name=prova -c user.email=prova@example.test commit -qm "report mensile" >/dev/null 2>&1
  git -C "$TMP/repo" push -q origin HEAD >/dev/null 2>&1; e=$?
else e=128; fi
riga "$([ $e = 0 ] && echo 200 || echo git)" 200 "fa push di un commit" "git push (HTTP)"
riga "$(c -X POST -H 'Content-Type: application/json' -d '{"title":"Il report è lento","body":"La query `SELECT * FROM clienti WHERE attivo = 1` ci mette 4 secondi."}' "$GIT/api/v1/repos/$U/prove-waf/issues")" 201 "apre una issue con una query nel testo" "POST /api/v1, JSON"
riga "$(c -X POST -H 'Content-Type: application/json' -d '{"title":"Permessi sbagliati","body":"Sul server: `ls -la /etc/passwd` dice -rw-r--r--."}' "$GIT/api/v1/repos/$U/prove-waf/issues")" 201 "apre una issue con un comando di shell" "POST /api/v1, JSON"
linea "├" "┴" "┤"
gruppo "e gli attacchi, sugli stessi servizi"
linea "├" "┬" "┤"
printf '<?php system($_GET["c"]); ?>\n' > "$TMP/shell.php"
attacco "$(curl -s -o /dev/null -w '%{http_code}' --data-urlencode "user=admin' OR 1=1--" --data-urlencode 'password=x' "$CLOUD/login")" "SQL injection nel login di Nextcloud" "POST /login, form"
attacco "$(c "$DAV/prove-waf/..%2f..%2f..%2f..%2fetc%2fpasswd")"          "esce dalla cartella dei file"          "GET WebDAV, ../"
attacco "$(c -T "$TMP/shell.php" "$DAV/prove-waf/shell.php")"            "carica una web shell PHP"             "PUT WebDAV"
attacco "$(curl -s -o /dev/null -w '%{http_code}' --get --data-urlencode "q=' UNION SELECT passwd FROM user--" "$GIT/explore/repos")" "SQL injection nella ricerca di Gitea" "GET ?q="
attacco "$(c -X POST -H 'Content-Type: application/json' -d '{"title":"<script>alert(1)</script>","body":"ciao"}' "$GIT/api/v1/repos/$U/prove-waf/issues")" "XSS nel titolo di una issue" "POST /api/v1, JSON"
attacco "$(c -X POST -H 'Content-Type: application/json' -d '{"title":"ciao","body":"<script>alert(1)</script>"}' "$GIT/api/v1/repos/$U/prove-waf/issues")" "XSS nel testo di una issue" "POST /api/v1, JSON"
linea "└" "┴" "┘"
echo ""
echo "${AZZURRO}» attacchi fermati ${VERDE}$FERMATI${AZZURRO}, passati ${ROSSO}$PASSATI${FINE}  ${TENUE}(passato = arrivato all'app, non vuol dire che l'app ci caschi)${FINE}"
echo "${AZZURRO}» funzionano ${VERDE}$OK${AZZURRO}, rotte ${ROSSO}$ROTTE${FINE}  ${TENUE}(perché: make perche)${FINE}"
echo ""
