# DetectionOnly: guarda e scrive, non blocca

Profilo: `make detect`

## La stessa SQL injection

**Input**

```console
$ curl -i -G --data-urlencode "q=1' OR 1=1--" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 200 OK
```

**Cosa ha scritto il WAF**

```
942100  SQL Injection Attack Detected via libinjection
949110  Inbound Anomaly Score Exceeded (Total Score: 5)
```
