# Senza WAF: quello che arriva all'applicazione

Profilo: `make nowaf`

## Una ricerca normale

**Input**

```console
$ curl -i -G --data-urlencode "q=tastiera meccanica" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 200 OK
```

**Cosa ha ricevuto l'applicazione**

```
tastiera meccanica
```

> Nessuno l'ha fermata: la stringa e' arrivata intera al backend.

## Una SQL injection

**Input**

```console
$ curl -i -G --data-urlencode "q=1' OR 1=1--" http://localhost:8080/search
```

**Output**

```console
HTTP/1.1 200 OK
```

**Cosa ha ricevuto l'applicazione**

```
1' OR 1=1--
```

> Nessuno l'ha fermata: la stringa e' arrivata intera al backend.
