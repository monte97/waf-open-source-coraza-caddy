.PHONY: su-misura nowaf detect block paranoid tuned toppa base64 down logs logs-waf attack falso-positivo status clean caddyfile-diff verifica cattura misure raffica php2shell

COMPOSE := cd demo && docker compose
URL     := http://localhost:8080

# `docker compose down` da solo NON spegne i servizi di un profilo che non e'
# attivo in quel momento, e la porta 8080 resta occupata dal profilo
# precedente. Vanno nominati tutti. Misurato, non dedotto: senza questa riga
# il secondo `make <profilo>` fallisce con "port is already allocated".
TUTTI := --profile nowaf --profile detect --profile block --profile paranoid --profile tuned --profile toppa --profile base64

# Ogni profilo fa `down` prima di salire: le cinque varianti di Caddy
# pubblicano la stessa porta, quindi ne puo' vivere una per volta.
define avvia
	@$(COMPOSE) $(TUTTI) down --remove-orphans >/dev/null 2>&1 || true
	@$(COMPOSE) --profile $(1) up -d
	@echo ""
	@echo ">>> profilo $(1) attivo su $(URL)"
	@echo ""
endef

all: block

# ── i cinque stati del racconto ────────────────────────────────────────────────────────────────────────────────────────

## L'attacco arriva all'applicazione: nessuno lo ferma
nowaf:
	$(call avvia,nowaf)

## Il WAF guarda e scrive nel log, ma lascia passare
detect:
	$(call avvia,detect)

## Il WAF blocca: 403
block:
	$(call avvia,block)

## Il WAF blocca, ma la regola che fermava il traffico legittimo e' spenta
tuned:
	$(call avvia,tuned)

# ── strumenti da palco ──────────────────────────────────────────────────────

## Le tre richieste della demo: pulita, SQL injection, XSS
attack:
	@echo "=== richiesta pulita ==="
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" "$(URL)/search?q=tastiera"
	@echo "=== SQL injection ==="
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" "$(URL)/search?q=1'%20OR%201=1--"
	@echo "=== XSS ==="
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" "$(URL)/search?q=%3Cscript%3Ealert(1)%3C/script%3E"

## Dodici richieste in un secondo, una riga ciascuna: quattro oneste, otto
## attacchi classici. Da lanciare dopo ogni profilo, anche dal vivo
raffica:
	@bash scripts/raffica.sh

## La forma di PHP2Shell contro il servizio PHP: richieste innocue, PHP gia'
## corretto. Misura cosa riconosce il WAF, non se l'attacco riuscirebbe
php2shell:
	@bash scripts/php2shell.sh

## La ricerca legittima che il WAF scambia per un attacco (slide 10)
## Misurata: passa a paranoia 1, viene bloccata a paranoia 3, torna a passare
## dopo l'esclusione del profilo `tuned`.
falso-positivo:
	@echo "=== ricerca legittima: un libro su C++ e C# ==="
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" --get --data-urlencode "q=C++ & C# -- guida" "$(URL)/search"

## Pre-volo: accende i cinque profili in fila e stampa la matrice.
## Da lanciare la sera prima del talk. Se una cella non torna, lo scopri li'.
verifica:
	@bash scripts/verifica.sh

## Il diff che spiega il talk in dieci righe
caddyfile-diff:
	@diff -u demo/caddy/nowaf.Caddyfile demo/caddy/waf.Caddyfile || true

down:
	@$(COMPOSE) $(TUTTI) down --remove-orphans

logs:
	$(COMPOSE) logs -f

## Solo il WAF: qui compaiono i rule ID
logs-waf:
	$(COMPOSE) logs -f | grep -i coraza

status:
	@$(COMPOSE) ps

clean:
	@$(COMPOSE) $(TUTTI) down -v --remove-orphans
	@echo "Volumi rimossi."

## Livello 1 con la toppa su misura per PHP2Shell (tuning/toppa)
toppa:
	$(call avvia,toppa)

## Livello 1 che guarda anche dentro il Base64 (tuning/base64)
base64:
	$(call avvia,base64)

## Paranoia alzata: copre di piu' e comincia a bloccare traffico onesto
paranoid:
	$(call avvia,paranoid)

## Rigenera il materiale delle slide: input e output di ogni momento
cattura:
	@python3 scripts/cattura.py

## Il WAF su misura: guarda, escludi, misura (misure/su_misura). Circa un minuto
su-misura:
	@/usr/bin/env python3 misure/su_misura/misura.py

## GoTestWAF e Nuclei contro i profili. Lento: circa venti minuti
misure:
	@bash misure/scan.sh
