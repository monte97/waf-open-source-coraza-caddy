#!/usr/bin/env python3
"""Informazioni sul WAF acceso, lette dal container di Caddy + Coraza.

  make info                 cosa gira: immagine, versioni, modalita', soglie, correzioni caricate
  make regole               le regole del CRS: quante per famiglia e per livello di paranoia
  make regola ID=942440     la scheda di una regola: cosa cerca, gravita', livello, file
"""
import json, re, subprocess, sys, os

AZZURRO, BIANCO, GIALLO, TENUE, VERDE, ROSSO, FINE = ("\033[1;96m", "\033[1;97m", "\033[1;93m",
                                                     "\033[37m", "\033[1;92m", "\033[1;91m", "\033[0m")
PUNTI = {"CRITICAL": 5, "ERROR": 4, "WARNING": 3, "NOTICE": 2}
FAMIGLIE = {"911": "metodi HTTP", "913": "scanner noti", "920": "protocollo HTTP", "921": "attacchi al protocollo",
            "922": "multipart", "930": "lettura di file (LFI)", "931": "file remoti (RFI)", "932": "comandi (RCE)",
            "933": "PHP", "934": "attacchi generici", "941": "XSS", "942": "SQL injection",
            "943": "fissazione di sessione", "944": "Java", "950": "fughe di dati", "951": "fughe di dati SQL",
            "952": "fughe di dati Java", "953": "fughe di dati PHP", "954": "fughe di dati IIS",
            "955": "web shell", "956": "fughe di dati Ruby"}

def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout.strip()

def container():
    for riga in sh("docker", "ps", "--format", "{{.Names}}\t{{.Label \"com.docker.compose.service\"}}").splitlines():
        nome, servizio = (riga.split("\t") + [""])[:2]
        if servizio.startswith("caddy-"):
            return nome, servizio[len("caddy-"):]
    print(f"{ROSSO}nessun profilo acceso: prima make block (o un altro profilo){FINE}")
    sys.exit(1)

def env(c):
    return dict(r.split("=", 1) for r in sh("docker", "exec", c, "env").splitlines() if "=" in r)

def livello(c, e):
    """Il livello vero: una correzione in config.d (SecAction ... blocking_paranoia_level=N) vince sulla variabile d'ambiente."""
    testo = sh("docker", "exec", c, "sh", "-c", "cat /opt/coraza/config.d/*.conf 2>/dev/null")
    attive = "\n".join(r for r in testo.splitlines() if not r.lstrip().startswith("#"))
    m = re.search(r"blocking_paranoia_level=(\d)", attive)
    return int(m[1]) if m else int(e.get("BLOCKING_PARANOIA", "1"))

def regole(c):
    testo = sh("docker", "exec", c, "sh", "-c", "for f in /opt/coraza/owasp-crs/rules/*.conf; do echo \"@@@FILE $f\"; cat \"$f\"; done")
    out, file = [], ""
    for blocco in re.split(r"\n(?=SecRule|SecAction|@@@FILE )", testo):
        if blocco.startswith("@@@FILE "):
            file = os.path.basename(blocco[8:].splitlines()[0]); continue
        m = re.search(r'"id:(\d+)', blocco)
        if not m:
            continue
        g = lambda k: (re.search(k + r":'([^']*)'", blocco) or [None, ""])[1]
        pl = re.search(r"paranoia-level/(\d)", blocco)
        out.append({"id": m[1], "file": file, "msg": g("msg"), "severita": g("severity"),
                    "pl": int(pl[1]) if pl else 0, "testo": blocco})
    return out

def info():
    c, profilo = container(); e = env(c)
    immagine = sh("docker", "inspect", c, "--format", "{{.Config.Image}}")
    caddy = sh("docker", "exec", c, "caddy", "version").split()[0]
    crs = (re.search(r"ver:'OWASP_CRS/([\d.]+)'", sh("docker", "exec", c, "grep", "-m1", "ver:'OWASP_CRS/",
           "/opt/coraza/owasp-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf")) or [None, "?"])[1]
    print(f"\n{AZZURRO}» il WAF acceso{FINE}\n")
    righe = [("profilo", profilo), ("immagine", immagine), ("Caddy", caddy), ("regole OWASP CRS", crs),
             ("modalità", {"On": "On: blocca", "DetectionOnly": "DetectionOnly: guarda e annota, non blocca",
                           "Off": "Off: spento"}.get(e.get("CORAZA_RULE_ENGINE"), e.get("CORAZA_RULE_ENGINE", "?"))),
             ("livello di paranoia", livello(c, e)),
             ("soglia in ingresso", e.get("ANOMALY_INBOUND", "?") + " punti"),
             ("soglia in uscita", e.get("ANOMALY_OUTBOUND", "?") + " punti"),
             ("corpo massimo", f"{int(e.get('CORAZA_REQ_BODY_LIMIT', '0')) // 1048576} MB")]
    if profilo == "nowaf":
        righe = righe[:3] + [("WAF", "nessuno: questo profilo e' solo reverse proxy")]
    for k, v in righe:
        print(f"  {TENUE}{k:<22}{FINE} {BIANCO}{v}{FINE}")
    if profilo == "nowaf":
        print(); return
    print(f"\n{AZZURRO}» le vostre correzioni caricate{FINE}\n")
    for dove, quando in (("/opt/coraza/config.d", "prima del CRS"), ("/opt/coraza/rules.d", "dopo il CRS")):
        for f in sh("docker", "exec", c, "sh", "-c", f"ls {dove}/*.conf 2>/dev/null").split():
            attive = [r for r in sh("docker", "exec", c, "cat", f).splitlines() if r.strip() and not r.lstrip().startswith("#")]
            stato = f"{len(attive)} righe attive" if attive else "vuoto"
            print(f"  {TENUE}{quando:<22}{FINE} {BIANCO}{os.path.basename(f)}{FINE}  {stato}")
            for r in attive[:6]:
                print(f"  {'':<22} {GIALLO}{r.strip()}{FINE}")
    print()

def elenco():
    c, profilo = container(); e = env(c); pl = livello(c, e)
    # come nella slide: le regole sulle richieste (REQUEST-9xx) che hanno un livello di paranoia
    tutte = regole(c)
    rr = [r for r in tutte if r["file"].startswith("REQUEST") and r["pl"]]
    risposte = [r for r in tutte if r["file"].startswith("RESPONSE") and r["pl"]]
    servizio = len(tutte) - len(rr) - len(risposte)
    print(f"\n{AZZURRO}» le regole del CRS a disposizione, in tutto{FINE}\n")
    print(f"  {BIANCO}{len(tutte):>4}{FINE} regole nel CRS di questa immagine, qualunque sia il livello")
    print(f"  {TENUE}{len(rr):>4} sulle richieste, ognuna con il suo livello di paranoia{FINE}")
    print(f"  {TENUE}{len(risposte):>4} sulle risposte (fughe di dati, web shell){FINE}")
    print(f"  {TENUE}{servizio:>4} di servizio: impostazioni, salti di livello, conteggio dei punti{FINE}")
    print(f"\n{AZZURRO}» quelle sulle richieste, per livello di paranoia{FINE}  (profilo {profilo}, livello {pl})\n")
    for n in range(1, 5):
        tot = sum(1 for r in rr if r["pl"] <= n)
        segno = f"  {VERDE}← acceso{FINE}" if n == pl else ""
        print(f"  {TENUE}fino al livello {n}{FINE}  {BIANCO}{tot:>4}{FINE} regole{segno}")
    print(f"\n{AZZURRO}» per famiglia: accese al livello {pl}, su tutte{FINE}\n")
    conta = {}
    for r in rr:
        fam = re.search(r"-(\d{3})-", r["file"])[1]
        conta.setdefault(fam, [0, 0]); conta[fam][1] += 1
        if r["pl"] <= pl: conta[fam][0] += 1
    for fam, (accese, tutte) in sorted(conta.items()):
        print(f"  {GIALLO}{fam}{FINE}  {FAMIGLIE.get(fam, ''):<26} {BIANCO}{accese:>3}{FINE} {TENUE}di {tutte}{FINE}")
    print(f"\n  {TENUE}escluse dal conto: le regole sulle risposte (RESPONSE-9xx) e quelle di servizio senza livello{FINE}\n")

def scheda(rid):
    c, _ = container()
    r = next((r for r in regole(c) if r["id"] == rid), None)
    if not r:
        print(f"{ROSSO}regola {rid} non trovata nel CRS di questa immagine{FINE}"); sys.exit(1)
    variabili = re.match(r"SecRule\s+(\S+)\s+\"([^\"]*)\"", r["testo"])
    print(f"\n{AZZURRO}» regola {rid}{FINE}\n")
    for k, v in (("cosa segnala", r["msg"]), ("gravità", f"{r['severita'].lower()}, {PUNTI.get(r['severita'], '?')} punti"),
                 ("livello di paranoia", r["pl"]), ("famiglia", r["file"]),
                 ("dove guarda", variabili[1] if variabili else "?"),
                 ("cosa cerca", (variabili[2][:90] + ("…" if len(variabili[2]) > 90 else "")) if variabili else "?")):
        print(f"  {TENUE}{k:<20}{FINE} {BIANCO}{v}{FINE}")
    print(f"\n  {TENUE}per spegnerla solo su un campo:{FINE} {GIALLO}SecRuleUpdateTargetById {rid} \"!ARGS:<campo>\"{FINE}\n")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "info"
    if cmd == "info": info()
    elif cmd == "regole": elenco()
    elif cmd == "regola":
        if len(sys.argv) < 3 or not sys.argv[2].isdigit():
            print(f"{ROSSO}uso: make regola ID=942440{FINE}"); sys.exit(1)
        scheda(sys.argv[2])
