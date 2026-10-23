.PHONY: help info regola registro falsi-allarmi su-misura nowaf detect block paranoid tuned toppa down clean verifica misure raffica php2shell

COMPOSE := cd demo && docker compose
URL     := http://localhost:8080

# `docker compose down` da solo NON spegne i servizi di un profilo che non e'
# attivo in quel momento, e la porta 8080 resta occupata dal profilo
# precedente. Vanno nominati tutti. Misurato, non dedotto: senza questa riga
# il secondo `make <profilo>` fallisce con "port is already allocated".
TUTTI := --profile nowaf --profile detect --profile block --profile paranoid --profile tuned --profile toppa

# Cosa fa ogni profilo, in una riga: la stampa `make <profilo>` mentre lo accende.
DESCR_nowaf    := solo Caddy, reverse proxy senza WAF: passa tutto
DESCR_detect   := Caddy + Coraza + regole OWASP CRS, in DetectionOnly: guarda e scrive nel log, non blocca
DESCR_block    := Caddy + Coraza + regole OWASP CRS, livello 1: blocca
DESCR_paranoid := Caddy + Coraza + regole OWASP CRS, livello 3: piu' severo
DESCR_tuned    := livello 3 con le correzioni di tuning/tuned
DESCR_toppa    := livello 1 con le regole per PHP2Shell di tuning/toppa

# Ogni profilo fa `down` prima di salire: le cinque varianti di Caddy
# pubblicano la stessa porta, quindi ne puo' vivere una per volta.
# L'output di Docker resta nascosto (pensato per il palco); se un comando
# fallisce, il suo output viene stampato e make si ferma.
define avvia
	@echo ""
	@printf "\033[1;96m» spengo il profilo precedente\033[0m\n"
	@$(COMPOSE) $(TUTTI) down --remove-orphans >/dev/null 2>&1 || true
	@printf "\033[1;96m» accendo $(1):\033[0m \033[1;97m%s\033[0m\n" "$(DESCR_$(1))"
	@out=$$($(COMPOSE) --profile $(1) up -d 2>&1) || { echo "$$out"; exit 1; }
	@# aspetta che la catena risponda: subito dopo `up` Caddy non e' ancora pronto
	@# e le prime richieste falliscono (misurato: senza attesa, dodici "bloccata" su dodici)
	@printf "\033[1;96m» aspetto che risponda su $(URL)\033[0m "; \
	 for i in $$(seq 1 60); do \
	   [ "$$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 '$(URL)/search?q=tastiera')" = 200 ] && { printf " \033[1;92mpronto\033[0m\n"; exit 0; }; \
	   printf "."; sleep 0.5; \
	 done; printf " \033[1;91mnon risponde dopo 30 secondi: guarda cd demo && docker compose logs\033[0m\n"; exit 1
	@echo ""
endef

all: block

# ── aiuto ───────────────────────────────────────────────────────────────────

## I comandi a disposizione, divisi per uso
help:
	@printf "\n\033[1;96mI profili\033[0m (uno acceso per volta, sulla porta 8080)\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make nowaf" "solo Caddy, senza WAF: passa tutto" \
	       "make detect" "WAF in DetectionOnly: guarda e scrive nel registro, non blocca" \
	       "make block" "WAF livello 1: blocca (il default di make)" \
	       "make paranoid" "WAF livello 3: piu' severo, blocca anche qualche richiesta onesta" \
	       "make tuned" "livello 3 con le correzioni di tuning/tuned" \
	       "make toppa" "livello 1 con le regole per PHP2Shell"
	@printf "\n\033[1;96mSul palco\033[0m (dopo aver acceso un profilo)\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make raffica" "dodici richieste in tabella: quattro oneste, otto attacchi" \
	       "make falsi-allarmi" "perche' le oneste sono state bloccate, e le righe di esclusione" \
	       "make php2shell" "la forma di PHP2Shell contro il servizio PHP"
	@printf "\n\033[1;96mCosa sta girando\033[0m\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make info" "come e' messo: WAF si' o no, versioni, modalita', livello, soglie, correzioni, regole" \
	       "make registro" "le ultime 20 richieste, con esito e regole scattate (N=50 per vederne di piu)" \
	       "make regola ID=942440" "la scheda di una regola: cosa segnala, punti, livello, dove guarda"
	@printf "\n\033[1;96mControlli\033[0m\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make verifica" "accende i profili in fila e controlla che facciano cosa promettono" \
	       "make down" "spegne tutto" \
	       "make clean" "spegne tutto e cancella i volumi"
	@printf "\n\033[1;96mMisure\033[0m (lente)\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make su-misura" "il WAF su misura: guarda, escludi, misura (circa un minuto)" \
	       "make misure" "GoTestWAF e Nuclei contro i profili (circa venti minuti)"
	@printf "\n"

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

## Dodici richieste in un secondo, una riga ciascuna: quattro oneste, otto
## attacchi classici. Da lanciare dopo ogni profilo, anche dal vivo
raffica:
	@bash scripts/raffica.sh

## La forma di PHP2Shell contro il servizio PHP: richieste innocue, PHP gia'
## corretto. Misura cosa riconosce il WAF, non se l'attacco riuscirebbe
php2shell:
	@bash scripts/php2shell.sh

## Tutto sul WAF acceso: versioni, modalita', livello, soglie, correzioni, regole del CRS
info:
	@/usr/bin/python3 scripts/coraza.py info

## Il registro di Caddy, leggibile: le ultime richieste, con esito e regole scattate
registro:
	@/usr/bin/python3 scripts/registro.py $(N)

## La scheda di una regola: make regola ID=942440
regola:
	@/usr/bin/python3 scripts/coraza.py regola $(ID)

## Perché il WAF ha bloccato le richieste oneste della raffica: regole, punti,
## campo, e la riga di esclusione. Dopo `make paranoid && make raffica`
falsi-allarmi:
	@/usr/bin/python3 scripts/falsi_allarmi.py

## Pre-volo: accende i cinque profili in fila e stampa la matrice.
## Da lanciare la sera prima del talk. Se una cella non torna, lo scopri li'.
verifica:
	@bash scripts/verifica.sh

down:
	@$(COMPOSE) $(TUTTI) down --remove-orphans

clean:
	@$(COMPOSE) $(TUTTI) down -v --remove-orphans
	@echo "Volumi rimossi."

## Livello 1 con la toppa su misura per PHP2Shell (tuning/toppa)
toppa:
	$(call avvia,toppa)


## Paranoia alzata: copre di piu' e comincia a bloccare traffico onesto
paranoid:
	$(call avvia,paranoid)

## Il WAF su misura: guarda, escludi, misura (misure/su_misura). Circa un minuto
su-misura:
	@/usr/bin/env python3 misure/su_misura/misura.py

## GoTestWAF e Nuclei contro i profili. Lento: circa venti minuti
misure:
	@bash misure/scan.sh
