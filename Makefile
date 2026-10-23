.PHONY: help info regole regola falsi-allarmi su-misura nowaf detect block paranoid tuned toppa down logs logs-waf attack falso-positivo status clean caddyfile-diff verifica cattura misure raffica php2shell

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
	 done; printf " \033[1;91mnon risponde dopo 30 secondi: guarda make logs\033[0m\n"; exit 1
	@echo ""
endef

all: block

# ── aiuto ───────────────────────────────────────────────────────────────────

## I comandi a disposizione, divisi per uso
help:
	@printf "\n\033[1;96mI profili\033[0m (uno acceso per volta, sulla porta 8080)\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make nowaf"    "solo Caddy, senza WAF: passa tutto" \
	                                        "make detect"   "WAF in DetectionOnly: guarda e scrive nel log, non blocca" \
	                                        "make block"    "WAF livello 1: blocca (il default di make)" \
	                                        "make paranoid" "WAF livello 3: piu' severo, blocca anche qualche richiesta onesta" \
	                                        "make tuned"    "livello 3 con le correzioni di tuning/tuned" \
	                                        "make toppa"    "livello 1 con le regole per PHP2Shell"
	@printf "\n\033[1;96mSul palco\033[0m (dopo aver acceso un profilo)\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make raffica"        "dodici richieste in tabella: quattro oneste, otto attacchi" \
	                                        "make falsi-allarmi"  "perche' le oneste sono state bloccate, e le righe di esclusione" \
	                                        "make attack"         "tre richieste: pulita, SQL injection, XSS" \
	                                        "make falso-positivo" "la ricerca onesta \"C++ & C# -- guida\"" \
	                                        "make php2shell"      "la forma di PHP2Shell contro il servizio PHP"
	@printf "\n\033[1;96mCosa sta girando\033[0m\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make info"   "cosa sta girando: WAF si' o no, versioni, modalita', livello, soglie, correzioni" \
	                                        "make regole" "quante regole del CRS sono accese, per famiglia e per livello" \
	                                        "make regola ID=942440" "la scheda di una regola: cosa segnala, punti, livello, dove guarda"
	@printf "\n\033[1;96mControlli\033[0m\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make verifica" "accende i profili in fila e controlla che facciano cosa promettono" \
	                                        "make status"   "i container accesi" \
	                                        "make logs"     "il registro di tutti i container, in diretta" \
	                                        "make logs-waf" "solo le righe del WAF, in diretta (Ctrl+C per uscire)" \
	                                        "make down"     "spegne tutto" \
	                                        "make clean"    "spegne tutto e cancella i volumi"
	@printf "\n\033[1;96mMisure e materiale\033[0m (lenti)\n"
	@printf "  \033[1;97m%-22s\033[0m %s\n" "make su-misura"      "il WAF su misura: guarda, escludi, misura (circa un minuto)" \
	                                        "make misure"         "GoTestWAF e Nuclei contro i profili (circa venti minuti)" \
	                                        "make cattura"        "rigenera il materiale delle slide" \
	                                        "make caddyfile-diff" "il diff fra i Caddyfile dei profili"
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

## Il WAF acceso: immagine, versioni, modalita', soglie, correzioni caricate
info:
	@/usr/bin/python3 scripts/coraza.py info

## Le regole del CRS: quante per famiglia e per livello di paranoia
regole:
	@/usr/bin/python3 scripts/coraza.py regole

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
