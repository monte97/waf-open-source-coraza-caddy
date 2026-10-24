#!/usr/bin/env bash
# Le prove di prove.sh su tutti e quattro i profili, in una tabella sola.
# Accende i profili uno per volta: circa due minuti.
#   make matrice
set -u
cd "$(dirname "$0")/.."
VERDE=$'\e[1;92m'; ROSSO=$'\e[1;91m'; TENUE=$'\e[37m'; BIANCO=$'\e[1;97m'; AZZURRO=$'\e[1;96m'; FINE=$'\e[0m'
PROFILI=(nowaf waf plugin su-misura)
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
for p in "${PROFILI[@]}"; do
  if [ "$p" = nowaf ]; then   # senza WAF e' sempre acceso, sulla 8082
    printf "${AZZURRO}» provo senza WAF (porta 8082)${FINE}\n"
    PORTA=8082 CSV="$D/$p.csv" bash scripts/prove.sh >/dev/null 2>&1; continue
  fi
  make -s "$p" >/dev/null || { echo "${ROSSO}il profilo $p non parte${FINE}"; exit 1; }
  printf "${AZZURRO}» provo il profilo %s${FINE}\n" "$p"
  CSV="$D/$p.csv" bash scripts/prove.sh >/dev/null 2>&1
done
echo ""
printf "  ${BIANCO}%-44s" "COSA"; for p in "${PROFILI[@]}"; do printf " %-10s" "$p"; done; printf "${FINE}\n"
n=$(wc -l < "$D/nowaf.csv")
for i in $(seq 1 "$n"); do
  cosa=$(sed -n "${i}p" "$D/nowaf.csv" | cut -d';' -f1)
  printf "  %-44s" "$cosa"
  for p in "${PROFILI[@]}"; do
    e=$(sed -n "${i}p" "$D/$p.csv" | cut -d';' -f3)
    case "$e" in funziona|fermato) col=$VERDE ;; *) col=$ROSSO ;; esac
    printf " %s%-10s%s" "$col" "$e" "$FINE"
  done
  printf "\n"
done
echo ""
for p in "${PROFILI[@]}"; do
  printf "  ${TENUE}%-10s${FINE} funzionano %s su 17 · attacchi fermati %s su 6\n" "$p" "$(head -17 "$D/$p.csv" | grep -c ';funziona$')" "$(tail -6 "$D/$p.csv" | grep -c ';fermato$')"
done
printf "  ${TENUE}passato = l'attacco arriva all'applicazione: se ci casca, dipende dall'applicazione${FINE}\n\n"
