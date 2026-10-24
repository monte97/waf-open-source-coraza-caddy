# WAF Open Source: Coraza + Caddy

Slide, demo e misure del talk **"WAF open source: una difesa in più per i tuoi servizi"**, Linux Day Prato, 24 ottobre 2026.

- **Slide:** [`slides/waf-open-source-linux-day-prato-2026.pdf`](slides/waf-open-source-linux-day-prato-2026.pdf), anche su [montelli.dev](https://montelli.dev/talks/waf-open-source-coraza-caddy/)
- **Fonti citate nel talk:** [`FONTI.md`](FONTI.md)
- **Misure:** [`misure/README.md`](misure/README.md)

> Solo da leggere? [`esempio/`](esempio/) ha un `docker-compose.yml` e un `Caddyfile` semplici, senza profili: il WAF acceso al livello 1 davanti a tre servizi.

> Con servizi veri? [`demo2/`](demo2/) mette lo stesso WAF davanti a Nextcloud e Gitea e prova 17 cose da utente e 6 attacchi: al livello 1, così com'è, ne funzionano 5 su 17. Comandi, numeri e correzioni nel suo [README](demo2/README.md).

## Cos'è

Uno stack WAF (Web Application Firewall) completamente open source davanti a un servizio self-hosted. Ferma SQL injection, XSS e le altre famiglie di attacco coperte dall'OWASP Core Rule Set.

Niente cloud, niente vendor, niente costi. Tutto gira sul tuo server.

## Stack

| Componente | Ruolo | Licenza |
|-----------|-------|---------|
| **[Coraza](https://coraza.io/)** | Engine WAF, interpreta le regole OWASP CRS | Apache 2.0 |
| **[Caddy](https://caddyserver.com/)** | Reverse proxy con HTTPS automatico, Coraza come plugin | Apache 2.0 |
| **[OWASP CRS](https://coreruleset.org/)** | Le regole: SQLi, XSS, RCE, LFI e altro | Apache 2.0 |

Caddy con il plugin Coraza e il CRS arrivano già pronti nell'immagine del team CRS, [`ghcr.io/coreruleset/coraza-crs`](https://github.com/coreruleset/coraza-crs-docker): Caddy 2.11.4, CRS 4.30.0, amd64 e arm64. Niente build locale. Il tag con la data, nel `docker-compose.yml`, fissa la build su cui sono state fatte catture e misure.

## Come funziona

```
curl / browser
    │
    ▼  :8080
┌──────────────────────────────┐
│ Caddy                        │
│  ├─ coraza_waf   (first)     │  valuta la richiesta contro il CRS
│  │    anomaly score ≥ soglia → 403, la richiesta si ferma qui
│  └─ reverse_proxy app:8000   │
└──────────────┬───────────────┘
               ▼
        app.py (:8000)            rimanda a schermo quello che riceve
```

Ogni regola CRS che scatta aggiunge punti all'anomaly score. Se il totale supera la soglia, Coraza risponde 403 prima che la richiesta arrivi all'applicazione.

`order coraza_waf first` nel Caddyfile è la riga che conta. `coraza_waf` arriva da un plugin e Caddy non sa in che punto della catena metterlo: senza quella riga si rifiuta di partire ("directive 'coraza_waf' is not an ordered HTTP handler"). `first` lo mette davanti a tutto, quindi la richiesta viene controllata prima di arrivare all'applicazione.

L'applicazione (`demo/app/app.py`) è volutamente ingenua: prende la query string e la mostra così com'è. Serve a vedere cosa arriva al backend.

## Prerequisiti

- Docker e Docker Compose v2
- Porta 8080 libera

## I profili

`make help` elenca tutti i comandi, divisi per uso.

Ogni profilo è un momento del talk. Ne gira uno per volta: tutti pubblicano la 8080, e ogni `make <profilo>` spegne il precedente prima di salire.

| Comando | Cosa succede | Pulita | SQL injection | Ricerca "C++ & C# -- guida" |
|---------|--------------|:------:|:-------------:|:---------------------------:|
| `make nowaf` | Solo reverse proxy: passa tutto | 200 | 200 | 200 |
| `make detect` | WAF in DetectionOnly: logga, non blocca | 200 | 200 | 200 |
| `make block` | WAF attivo, paranoia 1 | 200 | 403 | 200 |
| `make paranoid` | Paranoia 3: copre di più e blocca traffico onesto | 200 | 403 | 403 |
| `make tuned` | Paranoia 3 con il falso positivo escluso | 200 | 403 | 200 |
| `make toppa` | Paranoia 1 più due regole su misura per PHP2Shell | 200 | 403 | 200 |

Poi:

```bash
make raffica          # dodici richieste in un secondo, in tabella: quattro oneste, otto attacchi
make falsi-allarmi    # dopo make paranoid && make raffica: perché le oneste sono state bloccate, e le righe di esclusione
make info             # come è messo: WAF sì o no, versioni, modalità, livello, soglie, correzioni, regole del CRS
make registro         # le ultime 20 richieste (N=50 per di più): esito, regole scattate, falso positivo o no
make regola ID=942440 # la scheda di una regola: cosa segnala, punti, livello, dove guarda
make php2shell        # la forma di PHP2Shell contro il servizio PHP
```

## PHP2Shell, ottobre 2026

Il 21 ottobre 2026 PHP ha corretto [CVE-2026-109618 e CVE-2026-109619](https://www.php.net/archive/2026.php#2026-10-20-1), due falle che permettono di eseguire codice sul server senza login. La demo ha un servizio PHP sotto `/php/` (immagine `php:8.4.27-apache`, già corretta) per vedere cosa fa il WAF:

```bash
make block && make php2shell    # livello 1: la forma dell'attacco passa
make toppa && make php2shell    # con due regole su misura: due richieste su tre si fermano
```

`scripts/php2shell.sh` manda richieste innocue con la forma dell'attacco, nessun exploit. Le regole del profilo `toppa` stanno in [`demo/tuning/toppa/dopo/10-php2shell.conf`](demo/tuning/toppa/dopo/10-php2shell.conf). Numeri e cautele in [`misure/README.md`](misure/README.md#php2shell-la-forma-della-richiesta). L'unica correzione vera è aggiornare PHP: il WAF compra tempo.

## Strumenti da palco

| Comando | Descrizione |
|---------|-------------|
| `make verifica` | Pre-volo: accende i cinque profili in fila e stampa la matrice qui sopra. Da lanciare la sera prima |
| `make help` | Tutti i comandi, divisi per uso |
| `make misure` | Lancia GoTestWAF e Nuclei contro i profili. Numeri e metodo in [`misure/README.md`](misure/README.md) |
| `make down` | Spegne qualunque profilo sia attivo |
| `make clean` | Spegne tutto e rimuove i volumi |

## Servizi veri: demo2

```bash
cd demo2                   # la demo principale puo' restare accesa
make senza-waf             # i 6 attacchi senza WAF (porta 8082): arrivano, e le app li respingono
make waf && make prove     # livello 1 cosi' com'e': attacchi fermati 6 su 6, cose da utente 5 su 17
make perche                # chi ha fermato cosa: metodo, percorso, punti, regole
make su-misura && make prove   # plugin Nextcloud del CRS + quattro correzioni: 17 su 17, ma 4 attacchi su 6
```

Le due demo possono restare accese insieme: `demo/` sta sulla porta 8080, `demo2/` sulla 8081 con il WAF e sulla 8082 senza, e ogni comando legge solo il registro della sua. Dettagli, profili e il prezzo di ogni correzione in [`demo2/README.md`](demo2/README.md).

## Configurazione e tuning

I due Caddyfile in `demo/caddy/` sono montati davvero: quello che si vede a schermo è quello che gira.

- **DetectionOnly / On**: variabile `CORAZA_RULE_ENGINE` nel `docker-compose.yml`, diversa per profilo.
- **Paranoia**: `demo/tuning/<profilo>/prima/`, incluso dopo `crs-setup.conf` e prima delle regole. Ci sta la `SecAction` che alza `blocking_paranoia_level`.
- **`MANUAL_MODE`**: l'immagine, di suo, riscrive `crs-setup.conf` dalle variabili d'ambiente e attiva la stessa regola `900000` del file di paranoia. Le due si scontrano ("duplicated rule id") e Caddy non parte. `MANUAL_MODE=1` lascia `crs-setup.conf` com'è distribuito e la configurazione nei file del repo, leggibili a schermo.
- **Esclusioni**: `demo/tuning/<profilo>/dopo/`, incluso dopo le regole perché le nomina. Il profilo `tuned` esclude il parametro `q` da due regole:
  ```
  SecRuleUpdateTargetById 942440 "!ARGS:q"
  SecRuleUpdateTargetById 942460 "!ARGS:q"
  ```
  Gli ID si leggono nel log del profilo `paranoid` (`make falsi-allarmi`, o `make registro`) quando la richiesta legittima viene fermata. Un'esclusione mirata su un parametro toglie meno copertura di un `SecRuleRemoveById`, che spegne la regola ovunque.

### Aggiungere un servizio da proteggere

1. Aggiungi il servizio in `demo/docker-compose.yml` nella rete `waf`
2. Nel Caddyfile, un blocco con `coraza_waf` (stesse `include` di `waf.Caddyfile`) e `reverse_proxy tuo-servizio:porta`
3. Rilancia il profilo

### HTTPS in produzione

La demo usa HTTP su `:80` dentro il container. Con un dominio reale al posto di `:80`, Caddy ottiene il certificato Let's Encrypt da solo:

```
example.com {
	coraza_waf { ... }
	reverse_proxy app:8000
}
```

## Struttura del repo

```
├── esempio/                      # la versione da leggere: un compose e un Caddyfile, WAF al livello 1
├── demo2/                        # il WAF davanti a Nextcloud e Gitea veri: cd demo2 && make help
├── demo/
│   ├── docker-compose.yml        # app, servizio PHP e una variante di Caddy per profilo
│   ├── app/app.py                # l'applicazione da proteggere, solo libreria standard
│   ├── php/php/index.php         # un servizio PHP, per la prova su PHP2Shell
│   ├── caddy/
│   │   ├── nowaf.Caddyfile       # solo reverse proxy
│   │   └── waf.Caddyfile         # reverse proxy + coraza_waf
│   └── tuning/<profilo>/
│       ├── prima/                # incluso prima delle regole: paranoia
│       └── dopo/                 # incluso dopo le regole: esclusioni
├── scripts/
│   ├── verifica.sh               # make verifica
│   ├── raffica.sh                # make raffica
│   ├── php2shell.sh              # make php2shell
│   ├── falsi_allarmi.py          # make falsi-allarmi
│   ├── coraza.py                 # make info, make regola
│   └── registro.py               # make registro
├── misure/                       # make misure: GoTestWAF e Nuclei contro i profili
├── slides/                       # il PDF delle slide
├── FONTI.md                      # le fonti citate nel talk, con i link
└── Makefile
```

## License

- Demo code: MIT
- Talk content (slides/): CC BY-SA 4.0
- OWASP CRS: Apache 2.0
