# Acorda o server por Wake-on-LAN e responde no lugar dele enquanto liga.
# O Nginx do Pi manda para cá os pedidos que o server não atendeu (502/504),
# com X-Dionix-Uso: 1 para acessos reais e 0 para as checagens do próprio Pi.
# Configuração por variáveis de ambiente (server-wake.nix).
import html
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAC = bytes.fromhex(os.environ["MAC"].replace(":", ""))
BROADCAST = os.environ["BROADCAST"]
SERVER = os.environ["SERVER"]
LOG = os.environ["LOG"]
DORMINDO = os.path.join(os.environ["STATE_DIRECTORY"], "dormindo")
INTERVALO = 30  # segundos entre dois pacotes mágicos

ultimo_pacote = 0.0

PAGINA = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="{espera}{destino}">
<title>{titulo}</title>
<style>
  :root {{ color-scheme: dark light; }}
  body {{
    margin: 0; min-height: 100vh; display: grid; place-items: center;
    background: Canvas; color: CanvasText;
    font-family: "JetBrainsMono Nerd Font", monospace;
  }}
  main {{
    border: 1px solid GrayText; padding: 1.5rem 2rem; max-width: 36rem;
  }}
  h1 {{ font-size: 1rem; margin: 0 0 1rem; }}
  p {{ margin: .5rem 0; }}
  .fraco {{ color: GrayText; }}
</style>
</head>
<body>
<main>
<h1>{titulo}</h1>
<p>{texto}</p>
<p class="fraco">{rodape}</p>
</main>
</body>
</html>
"""


def acordar():
    global ultimo_pacote
    if time.monotonic() - ultimo_pacote < INTERVALO:
        return
    ultimo_pacote = time.monotonic()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(b"\xff" * 6 + MAC * 16, (BROADCAST, 9))


def server_acordado():
    # O SSH responde assim que a rede volta, antes dos outros serviços
    try:
        socket.create_connection((SERVER, 22), timeout=1).close()
        return True
    except OSError:
        return False


class Pedido(BaseHTTPRequestHandler):
    def log_message(self, formato, *args):
        pass  # o Nginx já registra os pedidos

    def responder(self, status, corpo, tipo="text/plain", extra=None):
        dados = corpo.encode()
        self.send_response(status)
        self.send_header("Content-Type", tipo + "; charset=utf-8")
        self.send_header("Content-Length", str(len(dados)))
        self.send_header("Cache-Control", "no-store")
        for nome, valor in (extra or {}).items():
            self.send_header(nome, valor)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(dados)

    def pagina(self, status, titulo, texto, espera, destino=""):
        if "text/html" not in self.headers.get("Accept", ""):
            extra = {"Retry-After": str(espera)}
            return self.responder(status, texto + "\n", extra=extra)
        corpo = PAGINA.format(
            titulo=html.escape(titulo),
            texto=html.escape(texto),
            rodape="Esta página recarrega sozinha.",
            espera=espera,
            destino=f"; url={destino}" if destino else "",
        )
        extra = {"Retry-After": str(espera)}
        self.responder(status, corpo, "text/html", extra)

    def tratar(self):
        uso = self.headers.get("X-Dionix-Uso")
        if self.path == "/acordar" and uso == "1":
            acordar()
            return self.pagina(
                200,
                "Acordando o server",
                "Pacote enviado. O server responde em alguns segundos.",
                15,
                "/",
            )
        if uso is not None:
            return self.espera(uso == "1")
        if self.path == "/sono/uso":
            try:
                ultimo = int(os.stat(LOG).st_mtime)
            except FileNotFoundError:
                ultimo = 0
            return self.responder(200, f"{ultimo}\n")
        if self.path == "/sono/dormindo" and self.command == "POST":
            open(DORMINDO, "w").close()
            return self.responder(200, "ok\n")
        if self.path == "/sono/acordado" and self.command == "POST":
            if os.path.exists(DORMINDO):
                os.remove(DORMINDO)
            return self.responder(200, "ok\n")
        self.responder(404, "não encontrado\n")

    def espera(self, real):
        host = self.headers.get("Host", "o serviço")
        if server_acordado():
            # A máquina está de pé: quem falhou foi o serviço
            if os.path.exists(DORMINDO):
                os.remove(DORMINDO)
            return self.pagina(
                502,
                "Serviço fora do ar",
                f"O server está ligado, mas {host} não respondeu.",
                30,
            )
        if real:
            acordar()
            return self.pagina(
                503,
                "Aguarde: o servidor está ligando",
                f"{host} volta em alguns segundos.",
                5,
            )
        # Checagens do Pi (Gatus, página inicial) não acordam a máquina
        if os.path.exists(DORMINDO):
            return self.responder(200, "dormindo\n")
        self.responder(503, "server fora do ar\n")

    def do_GET(self):
        self.tratar()

    def do_HEAD(self):
        self.tratar()

    def do_POST(self):
        self.tratar()


porta = int(os.environ["PORT"])
ThreadingHTTPServer(("127.0.0.1", porta), Pedido).serve_forever()
