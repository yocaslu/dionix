# Testes do update-watch: a conferência diária do canal e os endpoints que o
# forge e o widget usam. As funções de rede são trocadas por falsas.
# Uso: python3 update-watch-test.py <caminho do update-watch.py>
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest

# Não deixa __pycache__ ao lado do script no repositório
sys.dont_write_bytecode = True

ESTADO = tempfile.mkdtemp()
os.environ.update(STATE_DIRECTORY=ESTADO)
spec = importlib.util.spec_from_file_location("update_watch", sys.argv.pop(1))
uw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(uw)


def pedido(caminho, metodo="GET", corpo=""):
    """Handler sem socket: guarda status e corpo em vez de responder."""
    dados = corpo.encode()
    h = object.__new__(uw.Pedido)
    h.path, h.command = caminho, metodo
    h.headers = {"Content-Length": str(len(dados))}
    h.rfile = io.BytesIO(dados)
    h.status = h.corpo = None

    def responder(status, texto="", *a, **k):
        h.status, h.corpo = status, texto

    h.responder = responder
    return h


def chamar(caminho, metodo="GET", corpo=""):
    h = pedido(caminho, metodo, corpo)
    h.tratar()
    return h


class Base(unittest.TestCase):
    def setUp(self):
        self.acordou = 0
        self.canal, self.main, self.pr_vivo = "B", "A", True
        self.salvo = (uw.acordar, uw.revisao_canal, uw.revisao_main, uw.pr_aberto)
        uw.acordar = self.acordar
        uw.revisao_canal = lambda: self.canal
        uw.revisao_main = lambda: self.main
        uw.pr_aberto = lambda n: self.pr_vivo
        if os.path.exists(uw.ARQUIVO):
            os.remove(uw.ARQUIVO)

    def tearDown(self):
        uw.acordar, uw.revisao_canal, uw.revisao_main, uw.pr_aberto = self.salvo

    def acordar(self):
        self.acordou += 1

    def estado(self):
        return json.loads(chamar("/forge/estado").corpo)


class Conferir(Base):
    def test_canal_novo_fica_pendente_e_acorda(self):
        uw.conferir()
        e = self.estado()
        self.assertEqual((e["estado"], e["rev"]), ("pendente", "B"))
        self.assertEqual(self.acordou, 1)

    def test_main_ja_no_canal_nao_pendente(self):
        self.main = "B"
        uw.conferir()
        self.assertEqual(self.estado()["estado"], "nada")
        self.assertEqual(self.acordou, 0)

    def test_falha_nao_repete(self):
        chamar("/forge/falhou", "POST", "B")
        uw.conferir()
        self.assertEqual(self.estado()["estado"], "falhou")
        self.assertEqual(self.acordou, 0)

    def test_conferir_pendente_acorda_de_novo(self):
        uw.conferir()
        uw.conferir()
        self.assertEqual(self.estado()["estado"], "pendente")
        self.assertEqual(self.acordou, 2)

    def test_pr_aberto_da_mesma_revisao_nao_pendente(self):
        corpo = json.dumps({"rev": "B", "pr": 30, "url": "u", "resumo": "r"})
        chamar("/forge/pronto", "POST", corpo)
        uw.conferir()
        self.assertEqual(self.estado()["estado"], "pronto")
        self.assertEqual(self.acordou, 0)

    def test_falha_de_rede_nao_marca_pendente(self):
        def erro():
            raise OSError("sem rede")

        uw.revisao_main = erro
        uw.conferir()
        self.assertEqual(self.estado()["estado"], "nada")
        self.assertEqual(self.acordou, 0)


class Endpoints(Base):
    def test_pr_fechado_volta_a_nada(self):
        corpo = json.dumps({"rev": "B", "pr": 30, "url": "u", "resumo": "r"})
        chamar("/forge/pronto", "POST", corpo)
        self.pr_vivo = False
        self.assertEqual(self.estado()["estado"], "nada")

    def test_pronto_guarda_pr(self):
        corpo = json.dumps({"rev": "B", "pr": 30, "url": "u", "resumo": "r"})
        self.assertEqual(chamar("/forge/pronto", "POST", corpo).status, 200)
        self.assertEqual(
            self.estado(),
            {"estado": "pronto", "rev": "B", "pr": 30, "url": "u", "resumo": "r"},
        )

    def test_tentar_regrava_pendente(self):
        chamar("/forge/falhou", "POST", "B")
        self.assertEqual(chamar("/forge/tentar", "POST").status, 200)
        self.assertEqual(self.estado()["estado"], "pendente")
        self.assertEqual(self.acordou, 1)

    def test_pendente_so_quando_pendente(self):
        self.assertEqual(chamar("/forge/pendente").status, 204)
        uw.conferir()
        h = chamar("/forge/pendente")
        self.assertEqual((h.status, h.corpo.strip()), (200, "B"))

    def test_compilando_guarda_tentada(self):
        chamar("/forge/compilando", "POST", "B\n")
        self.assertEqual(self.estado()["estado"], "compilando")
        self.assertEqual(uw.ler()["tentada"], "B")


if __name__ == "__main__":
    unittest.main()
