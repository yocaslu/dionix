# Testes do host-wake: pedidos por host, estado separado, pacote mágico com o
# MAC certo e a corrida de dois pedidos ao mesmo tempo quando o host volta
# (um apaga o arquivo `dormindo`, o outro já não acha).
# Uso: python3 host-wake-test.py <caminho do host-wake.py>
import importlib.util
import json
import os
import sys
import tempfile
import unittest

# Não deixa __pycache__ ao lado do script no repositório
sys.dont_write_bytecode = True

ESTADO = tempfile.mkdtemp()
MAC_SERVER = "00:11:22:33:44:55"
MAC_FORGE = "66:77:88:99:aa:bb"
os.environ.update(
    HOSTS=json.dumps(
        {
            "server": {"ip": "127.0.0.1", "mac": MAC_SERVER},
            "forge": {"ip": "127.0.0.1", "mac": MAC_FORGE},
        }
    ),
    BROADCAST="127.255.255.255",
    LOG_DIR=ESTADO,
    STATE_DIRECTORY=ESTADO,
)
spec = importlib.util.spec_from_file_location("host_wake", sys.argv.pop(1))
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
        os.path.exists = lambda p: True if p == wake.arquivo_dormindo("server") else self.exists(p)
        self.acordado = wake.host_acordado
        wake.host_acordado = lambda host: True

    def tearDown(self):
        os.path.exists = self.exists
        wake.host_acordado = self.acordado

    def test_espera_com_host_acordado_responde_502(self):
        h = pedido("/", cabecalhos={"X-Dionix-Uso": "1", "X-Dionix-Host": "server", "Host": "x"})
        h.tratar()
        self.assertEqual(h.status, 502)

    def test_sono_acordado_responde_200(self):
        h = pedido("/sono/server/acordado", "POST")
        h.tratar()
        self.assertEqual(h.status, 200)


class PorHost(unittest.TestCase):
    def setUp(self):
        self.socket = wake.socket
        self.enviados = []
        enviados = self.enviados

        class Falso:
            AF_INET, SOCK_DGRAM, SOL_SOCKET, SO_BROADCAST = 2, 2, 1, 6

            def socket(self, *a):
                return self

            def __enter__(self):
                return self

            def __exit__(self, *a):
                pass

            def setsockopt(self, *a):
                pass

            def sendto(self, dados, destino):
                enviados.append(dados)

        wake.socket = Falso()
        wake.ultimo_pacote.clear()

    def tearDown(self):
        wake.socket = self.socket

    def test_host_desconhecido_404(self):
        h = pedido("/sono/nada/uso")
        h.tratar()
        self.assertEqual(h.status, 404)

    def test_dormindo_por_host(self):
        h = pedido("/sono/forge/dormindo", "POST")
        h.tratar()
        self.assertEqual(h.status, 200)
        self.assertTrue(os.path.exists(os.path.join(ESTADO, "forge", "dormindo")))
        self.assertFalse(os.path.exists(os.path.join(ESTADO, "server", "dormindo")))
        pedido("/sono/forge/acordado", "POST").tratar()

    def test_acordar_forge_usa_mac_do_forge(self):
        pedido("/acordar/forge", cabecalhos={"X-Dionix-Uso": "1"}).tratar()
        self.assertEqual(self.enviados, [b"\xff" * 6 + bytes.fromhex(MAC_FORGE.replace(":", "")) * 16])

    def test_acordar_sem_host_e_server(self):
        pedido("/acordar", cabecalhos={"X-Dionix-Uso": "1"}).tratar()
        self.assertEqual(self.enviados, [b"\xff" * 6 + bytes.fromhex(MAC_SERVER.replace(":", "")) * 16])


if __name__ == "__main__":
    unittest.main()
