# Acorda hosts (server, forge) por Wake-on-LAN e responde no lugar deles
# enquanto ligam. O Nginx do Pi manda para cá os pedidos que o host não atendeu
# (502/504), com X-Dionix-Host (qual host) e X-Dionix-Uso: 1 para acessos reais
# ou 0 para as checagens do próprio Pi.
# Configuração por variáveis de ambiente (host-wake.nix).
import html
import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# {"server": {"ip": "...", "mac": "..."}, "forge": {...}}
HOSTS = json.loads(os.environ["HOSTS"])
BROADCAST = os.environ["BROADCAST"]
LOG_DIR = os.environ["LOG_DIR"]
ESTADO = os.environ["STATE_DIRECTORY"]
INTERVALO = 30  # segundos entre dois pacotes mágicos de cada host

ultimo_pacote = {}  # host -> instante do último pacote

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


def arquivo_dormindo(host):
    return os.path.join(ESTADO, host, "dormindo")


def acordar(host):
    if time.monotonic() - ultimo_pacote.get(host, -INTERVALO) < INTERVALO:
        return
    ultimo_pacote[host] = time.monotonic()
    mac = bytes.fromhex(HOSTS[host]["mac"].replace(":", ""))
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(b"\xff" * 6 + mac * 16, (BROADCAST, 9))


def apagar_dormindo(host):
    # Dois pedidos podem chegar juntos quando o host volta: o outro já apagou
    try:
        os.remove(arquivo_dormindo(host))
    except FileNotFoundError:
        pass


def host_acordado(host):
    # O SSH responde assim que a rede volta, antes dos outros serviços
    try:
        socket.create_connection((HOSTS[host]["ip"], 22), timeout=1).close()
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
        partes = self.path.strip("/").split("/")
        # /acordar (= server, compatível) e /acordar/<host>
        if partes[0] == "acordar" and len(partes) <= 2 and uso == "1":
            host = partes[1] if len(partes) == 2 else "server"
            if host not in HOSTS:
                return self.responder(404, "host desconhecido\n")
            acordar(host)
            return self.pagina(
                200,
                f"Acordando o {host}",
                f"Pacote enviado. O {host} responde em alguns segundos.",
                15,
                "/",
            )
        if uso is not None:
            host = self.headers.get("X-Dionix-Host")
            if host not in HOSTS:
                return self.responder(404, "host desconhecido\n")
            return self.espera(host, uso == "1")
        # /sono/<host>/{uso,dormindo,acordado}
        if partes[0] == "sono" and len(partes) == 3:
            _, host, acao = partes
            if host not in HOSTS:
                return self.responder(404, "host desconhecido\n")
            if acao == "uso" and self.command in ("GET", "HEAD"):
                log = os.path.join(LOG_DIR, f"uso-{host}.log")
                try:
                    ultimo = int(os.stat(log).st_mtime)
                except FileNotFoundError:
                    ultimo = 0
                return self.responder(200, f"{ultimo}\n")
            if acao == "dormindo" and self.command == "POST":
                os.makedirs(os.path.join(ESTADO, host), exist_ok=True)
                open(arquivo_dormindo(host), "w").close()
                return self.responder(200, "ok\n")
            if acao == "acordado" and self.command == "POST":
                apagar_dormindo(host)
                return self.responder(200, "ok\n")
        self.responder(404, "não encontrado\n")

    def espera(self, host, real):
        servico = self.headers.get("Host", "o serviço")
        if host_acordado(host):
            # A máquina está de pé: quem falhou foi o serviço
            apagar_dormindo(host)
            return self.pagina(
                502,
                "Serviço fora do ar",
                f"O {host} está ligado, mas {servico} não respondeu.",
                30,
            )
        if real:
            acordar(host)
            return self.pagina(
                503,
                "Aguarde: o servidor está ligando",
                f"{servico} volta em alguns segundos.",
                5,
            )
        # Checagens do Pi (Gatus, página inicial) não acordam a máquina
        if os.path.exists(arquivo_dormindo(host)):
            return self.responder(200, "dormindo\n")
        self.responder(503, f"{host} fora do ar\n")

    def do_GET(self):
        self.tratar()

    def do_HEAD(self):
        self.tratar()

    def do_POST(self):
        self.tratar()


if __name__ == "__main__":
    porta = int(os.environ["PORT"])
    ThreadingHTTPServer(("127.0.0.1", porta), Pedido).serve_forever()
