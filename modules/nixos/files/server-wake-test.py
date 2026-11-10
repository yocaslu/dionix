# Testes do server-wake: dois pedidos ao mesmo tempo, quando o server volta,
# não podem quebrar ao apagar o arquivo `dormindo` (um apaga, o outro já não acha).
# Uso: python3 server-wake-test.py <caminho do server-wake.py>
import importlib.util
import os
import sys
import tempfile
import unittest

# Não deixa __pycache__ ao lado do script no repositório
sys.dont_write_bytecode = True

ESTADO = tempfile.mkdtemp()
os.environ.update(
    MAC="00:11:22:33:44:55",
    BROADCAST="127.255.255.255",
    SERVER="127.0.0.1",
    LOG=os.path.join(ESTADO, "uso.log"),
    STATE_DIRECTORY=ESTADO,
)
spec = importlib.util.spec_from_file_location("server_wake", sys.argv.pop(1))
wake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wake)


def pedido(caminho, metodo="GET", cabecalhos=None):
    """Handler sem socket: guarda o status em vez de responder."""
    h = object.__new__(wake.Pedido)
    h.path, h.command, h.headers = caminho, metodo, cabecalhos or {}
    h.status = None
    h.responder = lambda status, *a, **k: setattr(h, "status", status)
    return h


class Corrida(unittest.TestCase):
    def setUp(self):
        # O outro pedido já apagou o arquivo depois do os.path.exists deste
        self.exists = os.path.exists
        os.path.exists = lambda p: True if p == wake.DORMINDO else self.exists(p)
        self.acordado = wake.server_acordado
        wake.server_acordado = lambda: True

    def tearDown(self):
        os.path.exists = self.exists
        wake.server_acordado = self.acordado

    def test_espera_com_server_acordado_responde_502(self):
        h = pedido("/", cabecalhos={"X-Dionix-Uso": "1", "Host": "x"})
        h.tratar()
        self.assertEqual(h.status, 502)

    def test_sono_acordado_responde_200(self):
        h = pedido("/sono/acordado", "POST")
        h.tratar()
        self.assertEqual(h.status, 200)


if __name__ == "__main__":
    unittest.main()
