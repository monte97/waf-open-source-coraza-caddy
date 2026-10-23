"""
L'applicazione da proteggere. Volutamente stupida e volutamente ingenua:
prende quello che arriva nella query string e lo rimanda a schermo cosi'
com'e', senza validarlo e senza sanificarlo.

Serve a far vedere una cosa sola: cosa arriva all'applicazione. Con il
profilo `nowaf` la stringa di attacco si legge intera in pagina, perche'
nessuno l'ha fermata. Con `block` non arriva mai fin qui.

Solo libreria standard: nessuna dipendenza, nessuna build, parte in un
secondo anche sotto emulazione.
"""

from html import escape
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

PAGINA = """<!doctype html>
<meta charset="utf-8">
<title>Catalogo interno</title>
<style>
  body {{ font: 16px/1.6 system-ui, sans-serif; max-width: 42rem;
         margin: 4rem auto; padding: 0 1rem; color: #1f2430; }}
  input {{ font: inherit; padding: .5rem; width: 22rem; }}
  button {{ font: inherit; padding: .5rem 1rem; }}
  .box {{ margin-top: 2rem; padding: 1rem 1.25rem; border-left: 4px solid #d08326;
          background: #faf7f2; }}
  code {{ background: #eee; padding: .1rem .3rem; }}
</style>
<h1>Catalogo interno</h1>
<form action="/search" method="get">
  <input name="q" value="{valore}" placeholder="cerca un articolo" autofocus>
  <button>Cerca</button>
</form>
{risultato}
"""

RISULTATO = """<div class="box">
  <p>L'applicazione ha ricevuto questo testo:</p>
  <p><code>{ricevuto}</code></p>
  <p>Nessun controllo, nessuna sanificazione. Se leggi qui sopra una stringa
     di attacco, vuol dire che e' arrivata fino al backend.</p>
</div>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path not in ("/", "/search"):
            self.send_error(404)
            return

        q = parse_qs(url.query).get("q", [""])[0]
        risultato = RISULTATO.format(ricevuto=escape(q)) if q else ""
        corpo = PAGINA.format(valore=escape(q), risultato=risultato)

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(corpo.encode())

    def log_message(self, fmt, *args):
        # Una riga per richiesta, cosi' sul palco il log dell'app resta leggibile.
        print("app: " + fmt % args, flush=True)


if __name__ == "__main__":
    HTTPServer(("", 8000), Handler).serve_forever()
