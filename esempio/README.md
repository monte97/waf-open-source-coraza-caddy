# La versione da leggere

Un `docker-compose.yml` e un `Caddyfile` senza le complicazioni della demo: niente profili, il WAF acceso al livello 1, tre servizi dietro (Nextcloud, Gitea, Jellyfin). Sono gli stessi file delle slide, interi.

Servono da mostrare e da copiare. Per provare il WAF davvero c'è la demo, nella cartella sopra: `make help`.

| File | Cosa contiene |
|---|---|
| `docker-compose.yml` | Caddy con il WAF, unica porta verso fuori; i servizi senza porte |
| `Caddyfile` | il WAF scritto una volta (`(waf)`), poi un blocco per servizio con `import waf` |
| `tuning/00-correzioni.conf` | dove vanno le correzioni ai falsi allarmi, con un esempio commentato |

Per usarlo a casa: sostituite gli indirizzi `*.example.com` con i vostri, completate i servizi con i loro volumi e database (vedete la documentazione di ognuno), e partite con `CORAZA_RULE_ENGINE: DetectionOnly` per qualche giorno prima di passare a `On`.
