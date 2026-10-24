# demo2: il WAF davanti a servizi veri

`demo/` misura il WAF da solo, con un backend finto che risponde «ok» a tutto. Qui dietro ci sono Nextcloud 29 e Gitea 1.27, con le cose che fa un utente vero: il client che sincronizza, un upload dal browser, `git clone`, una issue. La domanda è cosa si rompe il giorno che accendi il WAF, e cosa lo ripara.

```bash
cd demo2
make waf        # accende Nextcloud, Gitea e il WAF livello 1 (la prima volta: circa un minuto)
make senza-waf  # i 6 attacchi direttamente alle app, senza WAF: arrivano, e cosa ne fanno le app
make prove      # 17 cose da utente e 6 attacchi, in tabella, attraverso il WAF
make perche     # le regole che hanno bloccato, richiesta per richiesta
make matrice    # le stesse prove sui quattro profili (circa due minuti)
make help       # tutti i comandi
```

Porta 8081 con il WAF, 8082 senza: un Caddy senza WAF davanti alle stesse app resta sempre acceso, così il giro senza WAF non richiede di cambiare profilo. `demo/` sta sulla 8080: le due demo possono restare accese insieme. `cloud.localhost` e `git.localhost` risolvono da soli a 127.0.0.1. Utente `prova`, password `prova-demo2-2026`: valori di prova, solo in locale.

## I profili

| Profilo | Cosa c'è davanti |
|---|---|
| (sempre acceso, porta 8082) | solo Caddy, nessun WAF: lo usano `make senza-waf` e `make matrice` |
| `waf` | Coraza + CRS 4.30, livello 1, configurazione dell'immagine così com'è |
| `plugin` | come `waf`, più il [plugin Nextcloud del CRS](https://github.com/coreruleset/nextcloud-rule-exclusions-plugin) v1.7.1, in `plugins/nextcloud/` |
| `su-misura` | come `plugin`, più le correzioni di `correzioni/` (una per Nextcloud, una per Gitea) |

## Cosa è venuto fuori

Misurato il 24/10/2026, immagine `coraza-crs:4.30.0-caddy-alpine-202610110510`, Mac Apple M5.

| | nowaf | waf | plugin | su-misura |
|---|---|---|---|---|
| operazioni da utente che funzionano (su 17) | 17 | 5 | 9 | 17 |
| attacchi fermati (su 6) | 0 | 6 | 6 | 4, più 2 lasciati all'app |

- **Al livello 1, così com'è, Nextcloud non sincronizza.** PROPFIND, MKCOL, PUT, MOVE e DELETE non sono fra i metodi ammessi (911100).
- **Il plugin ripara i metodi, non gli upload.** Coraza legge come form anche un corpo senza Content-Type o con un tipo che non conosce (image/jpeg): il contenuto del file finisce in `ARGS_NAMES` e le regole lo leggono. Una foto da 300 KB accende più di dieci regole e prende 10.285 punti (una regola con multiMatch conta per ogni pezzo); un file `.sql` con una query, la 942100. In più c'è il limite del corpo: un video da 20 MB riceve 413.
- **`git clone` e `git push` via HTTP si fermano su Gitea.** La 930130 vede `.git/` nel percorso (`/prova/prove-waf.git/info/refs`) e lo tratta come un file riservato.
- **Una issue che parla di codice si ferma.** Una query o un `ls -la /etc/passwd` nel testo accendono le regole SQL e RCE su `ARGS:json.body`.
- **Senza WAF gli attacchi arrivano, ma non riescono.** Nextcloud rifiuta il login con la SQL injection, il `../` dà 404, la web shell resta un file (riletta, è solo testo), Gitea mostra lo `<script>` come testo e la ricerca con la UNION come testo nel campo. Con questi attacchi classici le app si difendono da sole: il WAF serve per le falle che non conoscono.
- **Il su misura esclude solo dove l'app si difende da sola.** Le due esclusioni (il corpo dei PUT WebDAV, il testo delle issue) cadono proprio dove `make senza-waf` mostra che l'app respinge l'attacco: la web shell caricata resta un file di testo, l'XSS nel testo di una issue resta testo. In tabella quei due attacchi compaiono come «all'app», non come «passato». Gli altri restano al WAF. La regola: si esclude dove l'app è sicura, mai per coprire un'app vulnerabile.

## Nuclei contro le app vere

Misurato il 24/10/2026 con `bash misure/nuclei.sh` (stessi template della demo principale: `exposure,lfi,sqli,xss,rce,misconfig`, 100 richieste al secondo), senza WAF sulla 8082 e con il profilo `su-misura` sulla 8081.

| | richieste | fermate dal WAF | cosa trova Nuclei, oltre agli info |
|---|---|---|---|
| Nextcloud, senza WAF | 19.780 | 0 | CVE-2026-109618 (critica) |
| Nextcloud, su misura | 19.783 | 6.384 (32%) | CVE-2026-109618 (critica) |
| Gitea, senza WAF | 19.809 | 0 | CVE-2026-59774 (critica), repository pubblici esposti |
| Gitea, su misura | 19.805 | 6.392 (32%) | repository pubblici esposti |

- Con il WAF tarato un terzo delle richieste dello scanner non arriva alle app, e su Gitea Nuclei non trova più la CVE critica.
- Nextcloud viene segnalato vulnerabile a PHP2Shell con e senza WAF: l'immagine `nextcloud:29-apache` porta un PHP più vecchio della versione corretta. È un rilevamento di Nuclei, non confermato. Per questo i Caddy pubblicano le porte solo su 127.0.0.1: la demo non deve essere raggiungibile dalla rete.

## I file

- `docker-compose.yml`: Nextcloud, Gitea e le quattro varianti di Caddy
- `caddy/`: un Caddyfile per profilo
- `plugins/nextcloud/`: il plugin, copiato dal repository del CRS al tag v1.7.1
- `correzioni/`: le correzioni del profilo `su-misura`, commentate
- `scripts/prove.sh`, `scripts/perche.py`, `scripts/matrice.sh`: le prove, le regole scattate, la tabella
