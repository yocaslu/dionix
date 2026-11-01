# TURN/STUN (coturn) para as chamadas do Nextcloud Talk. Fica no Pi porque ele
# está na rede de casa e na tailnet e tem rota para a LAN do pfSense: os
# clientes alcançam o Pi, e o Pi repassa a mídia para o Janus na VM.
#
# O segredo é o mesmo do Nextcloud: copie /var/lib/secrets/turn-secret da VM
# para /var/lib/secrets/turn-secret aqui (root, chmod 600).
{ config, lib, ... }:
let
  inherit (config.dionix.homelab) server;
  relayPorts = {
    from = 49160;
    to = 49200;
  };
in
{
  imports = [ ./homelab.nix ];

  services.coturn = {
    enable = true;
    realm = "turn.${config.dionix.homelab.domain}";
    use-auth-secret = true;
    # Entregue pelo systemd: o coturn roda com usuário próprio
    static-auth-secret-file = "/run/credentials/coturn.service/turn-secret";
    min-port = relayPorts.from;
    max-port = relayPorts.to;
    # Só UDP/TCP simples na rede interna (sem certificado)
    no-tls = true;
    no-dtls = true;
    no-tcp-relay = true;
    no-cli = true;
    extraConfig = ''
      fingerprint
      no-multicast-peers
      # Só repassa mídia para o Janus; nada de usar o Pi como ponte para o resto da rede
      denied-peer-ip=0.0.0.0-255.255.255.255
      allowed-peer-ip=${server}
    '';
  };

  systemd.services.coturn.serviceConfig.LoadCredential = [
    "turn-secret:/var/lib/secrets/turn-secret"
  ];

  networking.firewall = {
    allowedTCPPorts = [ 3478 ];
    allowedUDPPorts = [ 3478 ];
    allowedUDPPortRanges = [ relayPorts ];
  };
}
