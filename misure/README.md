# Misure con scanner automatici

Due scanner automatici lanciati contro i profili della demo. Servono a dare un numero a quello che il talk racconta: il WAF ferma gli attacchi comuni, e alzare la paranoia si paga in falsi positivi.

```bash
make misure
```

## Perché

1. **Dare un numero al racconto.** "Il WAF ferma gli attacchi" e "la paranoia costa falsi positivi" sono affermazioni. Uno scanner le trasforma in misure.
2. **Scegliere l'immagine.** La prima versione della demo usava `gbe0/coraza`, ferma al 2022 con CRS 4.0.0-rc1. Le misure hanno deciso il passaggio all'immagine del team CRS.
3. **Una slide per un pubblico generalista.** "Uno scanner ha mandato migliaia di richieste, ecco quante arrivano" si capisce senza sapere cos'è una regola.

## Come

### Il backend da misura

[`compose.yml`](compose.yml) sostituisce l'app della demo con [`catchall.py`](catchall.py), un backend che risponde 200 a qualunque metodo e percorso e stampa `hit` a ogni richiesta. L'app vera risponde 404 o 501 fuori da `/search`, e gli scanner classificherebbero quelle risposte come "non risolte". Contando gli `hit` si sa quante richieste hanno superato il WAF.

Caddy, Caddyfile e tuning sono quelli della demo, senza modifiche.

### Gli scanner

| Strumento | Versione | Cosa fa | Cosa si misura |
|---|---|---|---|
| [GoTestWAF](https://github.com/wallarm/gotestwaf) | 0.5.8 | Circa 670 attacchi noti (payload diretti, varianti offuscate, API) e 141 richieste legittime costruite apposta per sembrare sospette | Attacchi bloccati e richieste oneste bloccate per errore |
| [Nuclei](https://github.com/projectdiscovery/nuclei) | 3.11.1 | Lo scanner che usano anche i bot veri, con i template `exposure,lfi,sqli,xss,rce,misconfig`, a 200 richieste al secondo | Solo le richieste arrivate al backend |

Il backend da misura non ha vulnerabilità, quindi i "risultati" di Nuclei non dicono niente: conta solo quante richieste passano.

[`scan.sh`](scan.sh) accende un profilo per volta, lancia gli scanner e scrive i report grezzi in `misure/risultati/`, fuori da git. [`sintesi.py`](sintesi.py) riassume i report di GoTestWAF.

## Numeri

Misurati il 2026-10-11.

### GoTestWAF

| Profilo | Attacchi bloccati | Legittime bloccate per errore |
|---|---|---|
| nowaf | 0% | 0% |
| detect | 0% | 0% |
| block | 329/669 (49,2%) | 13/141 (9,2%) |
| paranoid | 382/669 (57,1%) | 58/141 (41,1%) |
| tuned | 383/670 (57,2%) | 56/137 (40,9%) |

I totali cambiano di qualche unità da un giro all'altro per i test che GoTestWAF non riesce a classificare. Uno o due punti di differenza fra paranoid e tuned sono rumore.

### GoTestWAF per famiglia di attacco

Attacchi bloccati sul totale inviato.

| Famiglia | block | paranoid |
|---|---|---|
| community (payload diretti) | 146/159 | 143/159 |
| owasp/sql-injection | 20/48 | 21/48 |
| owasp/xss-scripting | 91/224 | 100/224 |
| owasp/nosql-injection | 11/50 | 23/50 |
| owasp/path-traversal | 6/20 | 8/20 |
| owasp/shell-injection | 6/32 | 10/32 |
| owasp/sst-injection | 10/24 | 12/24 |
| owasp/ldap-injection | 2/24 | 8/24 |
| owasp/mail-injection | 3/24 | 12/24 |
| owasp/xml-injection | 2/7 | 2/7 |
| owasp/crlf | 6/7 | 7/7 |

### Nuclei

| Profilo | Richieste arrivate al backend | Fermate dal WAF |
|---|---|---|
| nowaf | 19.104 | nessuna |
| block | 12.682 | 34% |
| paranoid | 11.505 | 40% |

Nuclei dichiara circa 24.800 richieste, ma senza WAF al backend ne arrivano circa 19.100, stabili da un giro all'altro. Lo scarto viene da come Nuclei conta (template con più passaggi, richieste che non partono). Per questo il riferimento è il profilo nowaf, misurato nello stesso giro.

### Nuclei, separato per tipo

Misurato il 2026-10-23 con `bash misure/nuclei_per_tipo.sh && python3 misure/nuclei_contenuto.py`. Il backend da misura ora scrive ogni richiesta che riceve, e i log restano in `misure/risultati/nuclei/`.

L'etichetta di un template dice cosa cerca lo scanner, non cosa contiene ogni richiesta. Molti template prima chiedono se un prodotto esiste (`GET /adminer-4.7.3.php`, `GET /?HTTP_CLIENT_IP`) e attaccano solo dopo: quelle sonde non portano niente, e un WAF fa bene a lasciarle passare. Per questo il 34% della tabella qui sopra le mescola agli attacchi. Contando solo le richieste con un parametro che ha un valore, o con un corpo:

| Tipo di template | Fermate dal WAF, livello 1 |
|---|---|
| sqli | 402/464 (87%) |
| xss | 802/876 (92%) |
| lfi | 656/710 (92%) |
| rce | 675/906 (75%) |
| **Tutti** | **2535/2956 (86%)** |

Stessa misura al livello 3 e al livello 3 su misura (`PROFILI="paranoid sumisura" bash misure/nuclei_per_tipo.sh`, poi lo stesso conteggio):

| | Livello 1 | Livello 3 | Livello 3 su misura |
|---|---|---|---|
| Attacchi fermati | 2535/2956 (86%) | 2664/2956 (90%) | 2664/2956 (90%) |
| sqli | 87% | 91% | 92% |
| xss | 92% | 94% | 95% |
| lfi | 92% | 95% | 95% |
| rce | 75% | 81% | 81% |

Il profilo su misura esclude il solo campo `q` da 12 regole (sezione «Il WAF su misura»): Nuclei ci manda pochi attacchi, quindi che il totale non cambi è in parte scontato. Conferma però che le esclusioni non aprono buchi altrove.

- È una stima prudente: fra le richieste contate ci sono anche richieste innocue (`?wt=json`) che passando abbassano la percentuale.
- Fra quelle che passano ci sono exploit veri di prodotti specifici, per esempio comandi dentro un JSON verso un'API di gestione. Lì il WAF generico non basta: serve aggiornare il prodotto.

### L'immagine precedente

Stesse misure sulla prima versione della demo, con l'immagine `gbe0/coraza` con CRS 4.0.0-rc1.

| Profilo | Attacchi bloccati | Legittime bloccate per errore |
|---|---|---|
| block | 265/666 (39,8%) | 29/141 (20,6%) |
| paranoid | 368/670 (54,9%) | 66/140 (47,1%) |
| tuned | 363/662 (54,8%) | 67/141 (47,5%) |

### Il 49% e il Base64

Ricalcolato il 2026-10-23 dagli stessi report dell'11/10 con [`per_codifica.py`](per_codifica.py): `python3 misure/per_codifica.py misure/risultati block paranoid`.

GoTestWAF manda ogni attacco in più varianti: in chiaro, codificato per l'URL e codificato in Base64. Il WAF non decodifica il Base64, quindi quelle varianti passano tutte. Sono un terzo del totale, e contano solo per un'app che decodifica da sola il Base64 che riceve.

| | block | paranoid |
|---|---|---|
| Tutti gli attacchi | 329/670 (49%) | 382/670 (57%) |
| Varianti Base64 | 0/233 (0%) | 0/235 (0%) |
| **Senza le varianti Base64** | **329/437 (75%)** | **382/435 (88%)** |
| SQL injection, senza Base64 | 20/24 | 21/24 |
| XSS, senza Base64 | 91/112 | 100/112 |
| Legittime bloccate per errore | 13/141 (9%) | 58/141 (41%) |

### Il WAF su misura

Misurato il 2026-10-23 con `make su-misura` ([`su_misura/misura.py`](su_misura/misura.py)). Le richieste sono quelle di GoTestWAF, senza duplicati e decodificate ([`su_misura/richieste.json`](su_misura/richieste.json)): 192 attacchi e 47 richieste oneste, tutte nel campo `q` di `/search`, come se le scrivesse un utente. Le oneste sono divise a righe alterne in 24 «viste» e 23 «nuove».

Il giro è quello della documentazione CRS ([Anomaly Scoring](https://coreruleset.org/docs/2-how-crs-works/2-1-anomaly_scoring/), [False Positives and Tuning](https://coreruleset.org/docs/2-how-crs-works/2-3-false-positives-and-tuning/)):

1. **Guarda.** Livello 3 con soglia 10000 ([`su_misura/guarda/00-guarda.conf`](su_misura/guarda/00-guarda.conf)): il WAF annota e non blocca. Riceve solo le oneste viste.
2. **Escludi.** Dal registro, le regole scattate nel campo `q`: 12, nove della famiglia 942 (SQL injection) e tre della 932 (comandi Unix: 932190, 932236, 932250). Per ognuna `SecRuleUpdateTargetById <id> "!ARGS:q"`, in [`su_misura/generato/10-esclusioni.conf`](su_misura/generato/10-esclusioni.conf).
3. **Misura.** Livello 1, livello 3 e livello 3 con le esclusioni, su tutto. Le oneste nuove il WAF non le ha mai viste.

| | Livello 1 | Livello 3 | Livello 3 su misura |
|---|---|---|---|
| Attacchi fermati | 102/192 (53%) | 125/192 (65%) | 124/192 (65%) |
| Attacchi fermati, senza Base64 | 102/137 (74%) | 125/137 (91%) | 124/137 (91%) |
| Oneste viste bloccate | 3/24 (12%) | 11/24 (46%) | **0/24 (0%)** |
| Oneste nuove bloccate | 2/23 (9%) | 12/23 (52%) | 8/23 (35%) |
| **Oneste bloccate, tutte** | 5/47 (11%) | 23/47 (49%) | 8/47 (17%) |

- Nel talk le richieste oneste vengono tutte da questa misura (11% e 49% nella slide della severità, la divisione viste e nuove nella slide delle correzioni), gli attacchi tutti da Nuclei.
- Le esclusioni non costano attacchi: le altre regole sullo stesso campo continuano a lavorare.
- Sulle richieste viste i falsi allarmi spariscono; su quelle nuove calano, ma restano sopra il livello 1. Per questo è un giro da ripetere: più traffico vero guarda, meglio funziona. Le oneste di GoTestWAF sono costruite per sembrare attacchi e sono tutte diverse fra loro, il traffico vero si ripete di più.
- I numeri differiscono da quelli della tabella GoTestWAF qui sopra perché qui non ci sono duplicati fra posizioni e tutto passa dallo stesso campo.
- `misura.py` manda header da browser: con lo user agent di Python e senza `Accept`, al livello 3 il CRS bloccherebbe tutto per quello.

### Guardare dentro il Base64

Misurato il 2026-10-23, GoTestWAF 0.5.8, `block` e `base64` nello stesso giro (report `block-2310` e `base64-2310`).

Il CRS decodifica il Base64 solo in tre regole sulle iniezioni Node.js (934100 e vicine): per tutte le altre famiglie un attacco in Base64 resta invisibile. Il profilo `base64` (`make base64`) è il livello 1 più cinque regole in [`demo/tuning/base64/dopo/10-base64.conf`](../demo/tuning/base64/dopo/10-base64.conf): decodificano solo i valori che hanno la forma del Base64 (almeno 12 caratteri dell'alfabeto, niente spazi) e ci cercano SQL injection e XSS con gli stessi rilevatori del CRS, più le forme più comuni di percorsi di sistema, codice PHP, Log4Shell, comandi di shell, LDAP, NoSQL, template, SSI e comandi di posta. Una regola fa lo stesso sui pezzi del percorso.

| | block | base64 |
|---|---|---|
| Varianti Base64 fermate | 0/230 (0%) | **123/231 (53%)** |
| Tutti gli attacchi | 327/665 (49%) | **450/668 (67%)** |
| Senza le varianti Base64 | 327/435 (75%) | 327/437 (75%) |
| Legittime bloccate per errore | 13/141 | 13/139 |

- Le richieste legittime bloccate non cambiano: su questo set le regole non costano falsi allarmi. Le legittime di GoTestWAF non contengono Base64, quindi è una misura debole: su un servizio che riceve token o dati codificati va rifatta col proprio traffico.
- Restano fuori le varianti negli header e buona parte di quelle nel JSON, e tutto quello che le espressioni qui sopra non descrivono. Sono regole scritte a mano: coprono le forme note, non il resto.
- Perché il CRS non lo fa di suo, per quanto si vede dalle regole: decodificare ogni valore costa a ogni richiesta, e il testo normale decodificato diventa byte a caso, che possono accendere regole a caso. Le regole qui sopra limitano il costo ai soli valori con la forma del Base64.

### PHP2Shell: la forma della richiesta

Misurato il 2026-10-23 con `make <profilo> && make php2shell`. [`scripts/php2shell.sh`](../scripts/php2shell.sh) manda al servizio PHP della demo (immagine `php:8.4.27-apache`, già corretta) richieste innocue con la forma descritta negli avvisi pubblici di [CVE-2026-109618 e CVE-2026-109619](https://www.php.net/archive/2026.php#2026-10-20-1). Nessun exploit: si misura cosa riconosce il WAF, non se l'attacco riuscirebbe.

| Richiesta | nowaf | block | paranoid | toppa |
|---|---|---|---|---|
| Apre la pagina | passa | passa | passa | passa |
| Carica un file piccolo | passa | passa | passa | passa |
| Campo `PHP_SESSION_UPLOAD_PROGRESS` (…619) | passa | passa | passa | **bloccata** |
| Corpo multipart da 1 MiB (…618) | passa | passa | passa | passa |
| User agent di un PoC pubblico | passa | passa | passa | **bloccata** |

- Il CRS 4.30, a qualunque livello, non riconosce la forma: non ha regole per queste CVE. Ha senso: la forma, da sola, è quella di un caricamento normale.
- Il profilo `toppa` aggiunge due regole su misura in [`demo/tuning/toppa/dopo/10-php2shell.conf`](../demo/tuning/toppa/dopo/10-php2shell.conf), ispirate alle regole personalizzate che [AWS](https://aws.amazon.com/blogs/security/using-aws-waf-to-apply-mitigations-for-php2shell-rce-vulnerabilities-cve-2026-109618-and-cve-2026-109619/) propone per il proprio WAF. Il blocco degli user agent dei PoC è entrato nel CRS il 22/10 ([PR #4893](https://github.com/coreruleset/coreruleset/pull/4893)), non ancora in una versione rilasciata.
- Il corpo grande passa anche con la toppa. Da solo non riproduce la …618, che esaurisce la memoria con richieste multipart costruite apposta (avviso GHSA-w8hw-w9fx-j79w); qui misura solo se il WAF guarda la dimensione. AWS lo ferma con un limite di 8 KB sul corpo, che però blocca anche i caricamenti veri: su un servizio con upload non si può fare.
- Secondo [Frederik Himpe](https://blog.frehi.be/2026/10/21/php2shell-mitigating-with-crs-and-apparmor-before-the-patch/), nel canale Slack del CRS gli attacchi noti sono stati fermati da più regole del livello 1. È una fonte di seconda mano (il canale Slack non è pubblico) e qui non lo possiamo verificare, perché non usiamo exploit. Un'ipotesi, non verificata: gli exploit portano anche il codice da eseguire, e il CRS riconosce quello. Qui mandiamo solo la forma.
- **L'unica correzione è aggiornare PHP.** Il WAF compra tempo.
- `curl` aggiunge da solo `Expect: 100-continue` ai corpi grandi e il CRS lo blocca (regola 920450): lo script lo toglie, altrimenti si misura curl e non la forma.

## Cosa ne esce

1. **I payload diretti passano raramente:** 146 su 159 bloccati a paranoia 1. Le percentuali basse vengono dalle varianti offuscate e dalle famiglie che il CRS copre poco (LDAP, NoSQL, XML).
2. **Il prezzo della paranoia:** da paranoia 1 a 3 gli attacchi fermati salgono dal 49% al 57%, le richieste oneste bloccate dal 9% al 41%. Anche con Nuclei il guadagno è piccolo: le richieste fermate passano dal 34% al 40%.
3. **Aggiornare il CRS rende:** rispetto alla 4.0.0-rc1, la 4.30 blocca di più (49% contro 40%) e sbaglia meno della metà delle volte (9% contro 21%).
4. **Il profilo tuned non sposta le medie, com'era prevedibile:** l'esclusione riguarda il solo parametro `q`, che GoTestWAF usa poco.

## Cautele

- **"Blocca il 49%" detto da solo suona come "funziona a metà".** Va accompagnato dai payload diretti fermati quasi tutti, e dal WAF presentato come uno strato in più, che non sostituisce un'applicazione scritta bene.
- **GoTestWAF viene da Wallarm, che vende un WAF.** Il set è costruito per mettere in difficoltà i WAF e le richieste legittime sono volutamente ambigue: il 9% sovrastima i falsi positivi di un servizio reale.
- **Misura in laboratorio, un giro per profilo.** Nessuna ripetizione, nessun intervallo di confidenza. Fra due giri GoTestWAF si sposta di qualche unità.
- **Il backend da misura deve reggere il carico.** La prima versione serviva una richiesta alla volta e a 200 richieste al secondo ne perdeva: i conteggi di Nuclei oscillavano fra 6.000 e 18.000. Con `ThreadingHTTPServer` e `-nmhe` (Nuclei non abbandona il bersaglio dopo 30 errori) due giri consecutivi sono rimasti entro l'1%.
