# Estado das atualizações do nixpkgs para o forge. Uma vez por dia
# (`update-watch --conferir`) compara a revisão do canal nixos-26.05 com a da
# `main` e marca "pendente" quando há novidade; o forge consulta, compila,
# abre o PR e avisa por aqui. O widget do notebook lê /forge/estado.
# Estados: nada, pendente, compilando, pronto, falhou. Um `compilando` sem
# resposta do forge por mais de LIMITE_COMPILANDO vira `falhou`.
# Configuração por variáveis de ambiente (update-watch.nix).
import contextlib
import fcntl
import json
import os
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DIRETORIO = os.environ["STATE_DIRECTORY"]
ARQUIVO = os.path.join(DIRETORIO, "estado.json")
URL_CANAL = "https://channels.nixos.org/nixos-26.05/git-revision"
URL_LOCK = "https://raw.githubusercontent.com/yocaslu/dionix/main/flake.lock"
URL_PR = "https://api.github.com/repos/yocaslu/dionix/pulls/{}"
URL_ACORDAR = "http://127.0.0.1:8090/acordar/forge"
CACHE_PR = 600  # segundos entre duas consultas do mesmo PR
LIMITE_COMPILANDO = 6 * 3600  # igual ao TimeoutStartSec do forge-update

VAZIO = {
    "estado": "nada",
    "rev": None,
    "tentada": None,
    "pr": None,
    "url": None,
    "resumo": "",
    "conferido": 0,
    "desde": 0,  # quando entrou em `compilando`
}
# Campos que o widget enxerga
PUBLICOS = ("estado", "rev", "pr", "url", "resumo")

trava = threading.Lock()  # entre as threads do servidor
cache_pr = {}  # número -> (instante, aberto)


def buscar(url):
    with urllib.request.urlopen(url, timeout=15) as r:
        return r.read().decode()


def revisao_canal():
    return buscar(URL_CANAL).strip()


def revisao_main():
    lock = json.loads(buscar(URL_LOCK))
    return lock["nodes"]["nixpkgs"]["locked"]["rev"]


def pr_aberto(n):
    antes = cache_pr.get(n)
    if antes and time.monotonic() - antes[0] < CACHE_PR:
        return antes[1]
    try:
        aberto = json.loads(buscar(URL_PR.format(n)))["state"] == "open"
    except (OSError, ValueError, KeyError):
        return True  # sem resposta, mantém o PR como está
    cache_pr[n] = (time.monotonic(), aberto)
    return aberto


def acordar():
    req = urllib.request.Request(
        URL_ACORDAR, method="POST", headers={"X-Dionix-Uso": "1"}
    )
    try:
        urllib.request.urlopen(req, timeout=10).close()
    except OSError as erro:
        print(f"não acordou o forge: {erro}", file=sys.stderr)


@contextlib.contextmanager
def travado():
    """Exclusão entre threads e entre o servidor e o timer (processos)."""
    with trava, open(os.path.join(DIRETORIO, "lock"), "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        yield


def ler():
    try:
        with open(ARQUIVO) as f:
            return {**VAZIO, **json.load(f)}
    except (FileNotFoundError, ValueError):
        return dict(VAZIO)


def gravar(e):
    tmp = ARQUIVO + ".tmp"
    with open(tmp, "w") as f:
        json.dump(e, f)
    os.replace(tmp, ARQUIVO)


def sem_pr(e):
    return {**e, "estado": "nada", "rev": None, "pr": None, "url": None, "resumo": ""}


def vigente(e):
    """PR fechado ou mesclado: o estado volta a nada; compilando órfão: falhou."""
    if e["estado"] == "compilando" and time.time() - e["desde"] > LIMITE_COMPILANDO:
        e = {**e, "estado": "falhou"}
        gravar(e)
    if e["estado"] == "pronto" and e["pr"] is not None and not pr_aberto(e["pr"]):
        e = sem_pr(e)
        gravar(e)
    return e


def conferir():
    with travado():
        e = vigente(ler())
        if e["estado"] == "pendente":
            acordar()
            return
        try:
            canal, main = revisao_canal(), revisao_main()
        except (OSError, ValueError, KeyError) as erro:
            print(f"não leu as revisões: {erro}", file=sys.stderr)
            return  # mantém o estado anterior
        do_pr = e["rev"] if e["estado"] == "pronto" else None
        e["conferido"] = int(time.time())
        if canal not in (main, do_pr, e["tentada"]):
            e = {**sem_pr(e), "estado": "pendente", "rev": canal}
            gravar(e)
            acordar()
        else:
            gravar(e)


class Pedido(BaseHTTPRequestHandler):
    def log_message(self, formato, *args):
        pass  # o Nginx já registra os pedidos

    def responder(self, status, corpo="", tipo="text/plain"):
        dados = corpo.encode()
        self.send_response(status)
        self.send_header("Content-Type", tipo + "; charset=utf-8")
        self.send_header("Content-Length", str(len(dados)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(dados)

    def ler_corpo(self):
        return self.rfile.read(int(self.headers.get("Content-Length") or 0)).decode()

    def tratar(self):
        caminho = self.path.rstrip("/")
        leitura = self.command in ("GET", "HEAD")
        if caminho == "/forge/estado" and leitura:
            with travado():
                e = vigente(ler())
            publico = {k: e[k] for k in PUBLICOS}
            return self.responder(200, json.dumps(publico), "application/json")
        if caminho == "/forge/pendente" and leitura:
            with travado():
                e = vigente(ler())
            if e["estado"] == "pendente":
                return self.responder(200, e["rev"] + "\n")
            return self.responder(204)
        if self.command == "POST" and caminho.startswith("/forge/"):
            return self.escrever(caminho.removeprefix("/forge/"), self.ler_corpo())
        self.responder(404, "não encontrado\n")

    def escrever(self, acao, corpo):
        with travado():
            e = ler()
            if acao in ("compilando", "falhou"):
                rev = corpo.strip()
                e = {**sem_pr(e), "estado": acao, "rev": rev, "tentada": rev}
                if acao == "compilando":
                    e["desde"] = int(time.time())
            elif acao == "em-dia":
                # A main já tem o nixpkgs do canal: nada a compilar nem a repetir
                e = {**sem_pr(e), "tentada": corpo.strip()}
            elif acao == "pronto":
                try:
                    p = json.loads(corpo)
                    e = {
                        **e,
                        "estado": "pronto",
                        "rev": p["rev"],
                        "tentada": p["rev"],
                        "pr": p["pr"],
                        "url": p["url"],
                        "resumo": p["resumo"],
                    }
                except (ValueError, KeyError, TypeError):
                    return self.responder(400, "corpo inválido\n")
            elif acao == "tentar":
                try:
                    rev = revisao_canal()
                except (OSError, ValueError):
                    rev = e["rev"]  # sem rede, repete a revisão guardada
                if rev is None:
                    return self.responder(503, "revisão desconhecida\n")
                e = {**sem_pr(e), "estado": "pendente", "rev": rev}
                gravar(e)
                acordar()
                return self.responder(200, "ok\n")
            else:
                return self.responder(404, "não encontrado\n")
            gravar(e)
        self.responder(200, "ok\n")

    def do_GET(self):
        self.tratar()

    def do_HEAD(self):
        self.tratar()

    def do_POST(self):
        self.tratar()


if __name__ == "__main__":
    if "--conferir" in sys.argv:
        conferir()
    else:
        porta = int(os.environ["PORT"])
        ThreadingHTTPServer(("127.0.0.1", porta), Pedido).serve_forever()
