# Paranoia 3: copre di piu' e sbaglia

Profilo: `make paranoid`

## Una ricerca legittima di un libro

**Input**

```console
$ curl -i -G --data-urlencode "q=C++ & C# -- guida" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 403 Forbidden
```

**Cosa ha scritto il WAF**

```
942440  SQL Comment Sequence Detected
942460  Meta-Character Anomaly Detection Alert - Repetitive Non-Word Characters
949110  Inbound Anomaly Score Exceeded (Total Score: 8)
```

## La SQL injection, sempre presa

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
942130  SQL Injection Attack: SQL Boolean-based attack detected
942180  Detects basic SQL authentication bypass attempts 1/3
942330  Detects classic SQL injection probings 1/3
942390  SQL Injection Attack using (X)OR
949110  Inbound Anomaly Score Exceeded (Total Score: 25)
```
