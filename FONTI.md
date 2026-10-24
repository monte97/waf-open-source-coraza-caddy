# Fonti

Le fonti citate nel talk «WAF open source: una difesa in più per i tuoi servizi», Linux Day Prato, 24 ottobre 2026, nell'ordine in cui compaiono. Verificate il 23/10/2026.

Le misure sono mie e stanno in [`misure/README.md`](misure/README.md).

## Lo scenario

- [Thales (Imperva), Bad Bot Report 2026, dati 2025, pp. 4-8](https://cpl.thalesgroup.com/sites/default/files/content/campaigns/badbot/2026-thales-bad-bot-report.pdf)
- [Thales, «AI-driven bot attacks surged 12.5x», 29/04/2026](https://cpl.thalesgroup.com/about-us/newsroom/ai-driven-bot-attacks-surged-according-to-bad-bot-report)
- [Anthropic, Detecting and countering misuse of AI, agosto 2025](https://www.anthropic.com/news/detecting-countering-misuse-aug-2025)
- [Google GTIG, From Prompting to Autonomy, 08/09/2026](https://cloud.google.com/blog/topics/threat-intelligence/from-prompting-to-autonomy-the-evolution-of-adversarial-ai)
- [Mojang, Log4j e Minecraft Java Edition, dicembre 2021](https://www.minecraft.net/en-us/article/important-message--security-vulnerability-java-edition)
- [NVD, CVE-2021-44228 (Log4Shell)](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)
- [C. Folini, Buying time against attack, BCS, 2019](https://www.bcs.org/content-hub/buying-time-against-attack/)
- [GreyNoise, Mass Internet Exploitation Report 2025](https://www.greynoise.io/blog/2025-mass-internet-exploitation-report)

## Come si configura

- [OWASP, ModSecurity passa a OWASP, 2024](https://owasp.org/blog/2024/01/09/ModSecurity)
- [OWASP CRS, Announcing Coraza, 22/12/2021](https://owasp.org/blog/2021/12/22/announcing-coraza.html)
- [OWASP Coraza](https://owasp.org/www-project-coraza-web-application-firewall/)
- [OWASP CRS (licenza Apache 2.0)](https://github.com/coreruleset/coreruleset)
- [Immagine coraza-crs del team CRS](https://github.com/coreruleset/coraza-crs-docker)
- [coraza-caddy, il plugin di Caddy](https://github.com/corazawaf/coraza-caddy)
- [Caddy, Automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Caddy, Caddyfile concepts (snippets)](https://caddyserver.com/docs/caddyfile/concepts)
- [OWASP CRS, Anomaly Scoring](https://coreruleset.org/docs/2-how-crs-works/2-1-anomaly_scoring/)

## Misurare e correggere

- [Wallarm, GoTestWAF 0.5.8](https://github.com/wallarm/gotestwaf)
- [ProjectDiscovery, Nuclei](https://github.com/projectdiscovery/nuclei)
- [OWASP CRS, Albedo](https://github.com/coreruleset/albedo)
- [C. Folini, Working with Paranoia Levels, 2021](https://coreruleset.org/20211028/working-with-paranoia-levels/)
- [OWASP CRS, False Positives and Tuning](https://coreruleset.org/docs/2-how-crs-works/2-3-false-positives-and-tuning/)
- [Coraza, coraza.conf-recommended](https://github.com/corazawaf/coraza/blob/main/coraza.conf-recommended)

## A casa tua

- [J. Reason, Human error: models and management, BMJ 2000](https://pmc.ncbi.nlm.nih.gov/articles/PMC1117770/)
- [CrowdSec, Community Blocklist](https://docs.crowdsec.net/docs/central_api/community_blocklist)
- [CrowdSec, AppSec e OWASP CRS](https://docs.crowdsec.net/docs/appsec/crs/intro)
- [OWASP CRS, Migrating CRS 3 to 4: plugins, 2026](https://coreruleset.org/20260413/migrating-crs-3-to-4-part-3-plugins/)
- [Caddy Community, Anyone actually using Coraza?, 2023](https://caddy.community/t/anyone-actually-using-coraza/21681)
- [Microsoft, Digital Defense Report 2026, pp. 14 e 48](https://cdn-dynmedia-1.microsoft.com/is/content/microsoftcorp/microsoft/msc/documents/presentations/CSR/2026-Microsoft-Digital-Defense-Report.pdf)

## PHP2Shell

- [PHP, avviso di sicurezza del 21/10/2026](https://www.php.net/archive/2026.php)
- [PHP, GHSA-w8hw-w9fx-j79w (CVE-2026-109618)](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)
- [PHP, GHSA-6wmf-4rv5-p3rp (CVE-2026-109619)](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
- [OWASP CRS, PR #4893: user agent dei PoC](https://github.com/coreruleset/coreruleset/pull/4893)
- [AWS, mitigazioni WAF per PHP2Shell, 21/10/2026](https://aws.amazon.com/blogs/security/using-aws-waf-to-apply-mitigations-for-php2shell-rce-vulnerabilities-cve-2026-109618-and-cve-2026-109619/)
- [PPC Land, le regole d'emergenza di Cloudflare, 21/10/2026](https://ppc.land/cloudflare-blocks-php2shell-exploits-9-hours-before-php-flaws-went-public/)
- [P. Pillitteri, regole per nginx, Apache e ModSecurity, 21/10/2026](https://pasqualepillitteri.it/en/news/26086/php2shell-nginx-apache-rules-block-php-before-patch)

## Alternative a Caddy e a Cloudflare

- [Cloudflare, WAF managed rules](https://developers.cloudflare.com/waf/managed-rules/)
- [Cloudflare, DDoS protection](https://developers.cloudflare.com/ddos-protection/about/)
- [Cloudflare, SSL/TLS encryption modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
- [Traefik Hub, middleware Coraza WAF](https://doc.traefik.io/traefik-hub/api-gateway/reference/routing/http/middlewares/ref-coraza-waf)
- [Traefik, plugin Coraza WAF](https://plugins.traefik.io/plugins/65f2aea146079255c9ffd1ec/coraza-waf)
- [BunkerWeb](https://github.com/bunkerity/bunkerweb)
- [Coraza, connettore Nginx sperimentale](https://github.com/corazawaf/coraza-nginx)
- [open-appsec per Nginx Proxy Manager](https://docs.openappsec.io/integrations/nginx-proxy-manager-integration)
