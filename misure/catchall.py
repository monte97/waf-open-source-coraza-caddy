# Backend da misura: risponde 200 a qualunque metodo e percorso e stampa "hit".
# Contando gli hit si sa quante richieste hanno superato il WAF.
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def _ok(self):
        n = int(self.headers.get("Content-Length") or 0)
        corpo = self.rfile.read(n) if n else b""
        self.send_response(200); self.send_header("Content-Type", "text/plain"); self.end_headers()
        if self.command != "HEAD": self.wfile.write(b"ok\n")
        print("hit", self.command, self.path[:300], corpo[:200], flush=True)
    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = _ok
    def log_message(self, *a): pass
ThreadingHTTPServer(("", 8000), H).serve_forever()
