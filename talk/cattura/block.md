# Blocking: 403

Profilo: `make block`

## Una ricerca normale

**Input**

```console
$ curl -i -G --data-urlencode "q=tastiera meccanica" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 200 OK
```

Nessuna regola scattata.

## Una SQL injection

**Input**

```console
$ curl -i -G --data-urlencode "q=1' OR 1=1--" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 403 Forbidden
```

**Cosa ha scritto il WAF**

```
942100  SQL Injection Attack Detected via libinjection
949110  Inbound Anomaly Score Exceeded (Total Score: 5)
```

## Un XSS

**Input**

```console
$ curl -i -G --data-urlencode "q=<script>alert(1)</script>" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 403 Forbidden
```

**Cosa ha scritto il WAF**

```
941100  XSS Attack Detected via libinjection
941110  XSS Filter - Category 1: Script Tag Vector
941160  NoScript XSS InjectionChecker: HTML Injection
941390  Javascript method detected
949110  Inbound Anomaly Score Exceeded (Total Score: 20)
```
