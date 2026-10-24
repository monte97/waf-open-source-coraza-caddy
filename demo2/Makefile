.PHONY: help senza-waf waf plugin su-misura prove perche perche-tutto matrice utenti down clean

URL   := http://git.localhost:8081
TUTTI := --profile nowaf --profile waf --profile plugin --profile su-misura

DESCR_waf       := Caddy + Coraza + CRS, livello 1, come esce dall'immagine: nessuna correzione
DESCR_plugin    := livello 1 + il plugin Nextcloud del CRS (v1.7.1)
DESCR_su-misura := livello 1 + plugin Nextcloud + le correzioni di correzioni/ (Nextcloud e Gitea)

# Come in demo/: spegne il profilo precedente, accende quello chiesto, aspetta
# che Caddy risponda. Nextcloud e Gitea restano accesi fra un profilo e
# l'altro (non hanno profili): cambia solo il Caddy davanti.
define avvia
	@echo ""
	@printf "\033[1;96m» spengo il profilo precedente\033[0m\n"
	@for s in caddy-waf caddy-plugin caddy-su-misura; do docker compose $(TUTTI) rm -sf $$s >/dev/null 2>&1; done; true
	@printf "\033[1;96m» accendo $(1):\033[0m \033[1;97m%s\033[0m\n" "$(DESCR_$(1))"
	@out=$$(docker compose --profile $(1) up -d 2>&1) || { echo "$$out"; exit 1; }
	@printf "\033[1;96m» aspetto Nextcloud e Gitea su :8081\033[0m "; \
	 for i in $$(seq 1 120); do \
	   [ "$$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 '$(URL)/api/v1/version')" = 200 ] && \
	   [ "$$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 'http://cloud.localhost:8081/status.php')" = 200 ] && { printf " \033[1;92mpronto\033[0m\n"; exit 0; }; \
	   printf "."; sleep 1; \
	 done; printf " \033[1;91mnon risponde dopo due minuti: guarda docker compose logs\033[0m\n"; exit 1
	@$(MAKE) -s utenti
	@echo ""
endef

all: help

## I comandi a disposizione
help:
	@printf "\n\033[1;96mdemo2: il WAF davanti a Nextcloud e Gitea veri\033[0m (8081 con il WAF, 8082 senza; utente prova, password prova-demo2-2026)\n"
	@printf "\033[37mI comandi si danno da qui dentro: cd demo2\033[0m\n"
	@printf "\n\033[1;96mI profili\033[0m (uno per volta)\n"
	@printf "  \033[1;97m%-24s\033[0m %s\n" "make waf" "$(DESCR_waf)" \
	       "make plugin" "$(DESCR_plugin)" \
	       "make su-misura" "$(DESCR_su-misura)"
	@printf "  \033[37m%-24s %s\033[0m\n" "sempre acceso" "Caddy senza WAF sulla porta 8082, davanti alle stesse app"
	@printf "\n\033[1;96mLe prove\033[0m\n"
	@printf "  \033[1;97m%-24s\033[0m %s\n" "make senza-waf" "i 6 attacchi direttamente alle app (8082): arrivano, e cosa ne fanno le app" \
	       "make prove" "17 cose che fa un utente e 6 attacchi, in tabella" \
	       "make perche" "per ogni richiesta bloccata, i punti e le regole scattate (una riga)" \
	       "make perche-tutto" "lo stesso, con cosa ha visto ogni regola" \
	       "make matrice" "le prove sui quattro profili, una tabella sola (circa due minuti)"
	@printf "\n\033[1;96mServizio\033[0m\n"
	@printf "  \033[1;97m%-24s\033[0m %s\n" "make down" "spegne tutto" \
	       "make clean" "spegne tutto e cancella i dati di Nextcloud e Gitea"
	@printf "\n"

## Gli attacchi senza WAF, sulla 8082: cosa ne fanno le app da sole
senza-waf:
	@bash scripts/senza_waf.sh

waf:
	$(call avvia,waf)

plugin:
	$(call avvia,plugin)

su-misura:
	$(call avvia,su-misura)

## Le prove contro il profilo acceso
prove:
	@bash scripts/prove.sh

## Perche' il WAF ha bloccato: una riga per richiesta, o tutto il dettaglio
perche:
	@/usr/bin/python3 scripts/perche.py

perche-tutto:
	@/usr/bin/python3 scripts/perche.py tutto

## Tutti i profili, una tabella
matrice:
	@bash scripts/matrice.sh

# L'utente di prova di Gitea: al primo avvio non c'e', poi esiste gia'.
# Nextcloud lo crea da solo (NEXTCLOUD_ADMIN_USER).
utenti:
	@docker compose exec -T gitea gitea admin user create --username prova --password prova-demo2-2026 \
	   --email prova@example.test --admin --must-change-password=false >/dev/null 2>&1 || true

down:
	@docker compose $(TUTTI) down --remove-orphans

clean:
	@docker compose $(TUTTI) down --remove-orphans -v
