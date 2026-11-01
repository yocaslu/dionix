# Raspberry Pi 4 do homelab (10.42.1.2): roteador do Tailscale, DNS
# (Technitium), proxy reverso (Nginx), login central (lldap), TURN das chamadas
# do Talk, página de status e backup no Google Drive. Substitui o core-compose
# (Traefik, Technitium e Portainer em Docker). Não tem hardware-configuration.nix:
# a imagem SD já define os sistemas de arquivos (modules/nixos/raspberry-pi.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # VM `server` (NixOS), na LAN do pfSense
  vm = config.dionix.homelab.server;
  em = port: "http://${vm}:${toString port}";

  # IP da WAN do pfSense na rede de casa: as redes atrás dele são roteadas por
  # aqui (sem NAT). Reserve esse IP no roteador da operadora e preencha.
  pfsenseWan = null; # ex.: "10.42.1.4"
  redesPfsense = [
    "10.0.76.0/24" # LAN (VMs)
    "10.0.21.0/24" # DEV
  ];
in
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/raspberry-pi.nix
    ../../modules/nixos/tailscale-router.nix
    ../../modules/nixos/dns-server.nix
    ../../modules/nixos/reverse-proxy.nix
    ../../modules/nixos/ldap.nix
    ../../modules/nixos/talk-turn.nix
    ../../modules/nixos/status.nix
    ../../modules/nixos/node-exporter.nix
    ../../modules/nixos/backup.nix
  ];

  # Rede de casa anunciada para a tailnet (as do pfSense ele mesmo anuncia)
  dionix.tailscaleRouter = {
    routes = [ "10.42.1.0/24" ];
    exitNode = true;
  };

  # <serviço>.vault76.com.br. Dentro de casa (e pela tailnet) o Technitium
  # responde *.vault76.com.br com o IP do Pi; de fora vale o DNS da Cloudflare.
  dionix.proxy = {
    inherit (config.dionix.homelab) domain;
    acme.enable = true; # token em /var/lib/secrets/acme.env (CF_DNS_API_TOKEN=...)

    # ldap.<domínio> vem do ldap.nix e status.<domínio> do status.nix
    hosts = {
      dns = "http://127.0.0.1:5380"; # painel do Technitium
      proxmox = "https://10.42.1.20:8006";
      pfsense = "https://10.0.76.1";

      # VM server: Nextcloud e companhia (nextcloud.nix)
      nextcloud = {
        upstream = em 80;
        largeUploads = true;
        hsts = true;
      };
      collabora = em 9980;
      whiteboard = em 3002;
      talk = em 8095;

      # VM server: mídia (media.nix)
      jellyfin = em 8096;
      pedidos = em 5055; # Seerr
      sonarr = em 8989;
      radarr = em 7878;
      lidarr = em 8686;
      readarr = em 8787;
      prowlarr = em 9696;
      bazarr = em 6767;
      qbittorrent = em 8081;

      # VM server: jogos do Switch (switch-nut.nix), sem login próprio
      nut = {
        upstream = em 9000;
        basicAuthFile = "/var/lib/secrets/nut.htpasswd";
      };

      # VM server: monitoramento (monitoring.nix)
      grafana = em 3000;
    };
  };

  # Rota para as redes atrás do pfSense, aplicada quando a rede sobe
  systemd.services.rotas-pfsense = lib.mkIf (pfsenseWan != null) {
    description = "Rotas para as redes atrás do pfSense";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatMapStrings (rede: "ip route replace ${rede} via ${pfsenseWan}\n") redesPfsense;
    preStop = lib.concatMapStrings (rede: "ip route del ${rede} || true\n") redesPfsense;
  };

  # Backup diário no Google Drive (gdrive:homelab/pi)
  dionix.backup = {
    paths = [
      "/var/lib/private/technitium-dns-server" # zonas e configurações do DNS
      "/var/lib/acme" # certificados
      "/var/lib/tailscale" # identidade do Pi na tailnet
      "/var/lib/secrets" # tokens e senhas locais
      "/var/backup/lldap" # cópia consistente do banco do LDAP (abaixo)
    ];
    exclude = [ "/var/lib/private/technitium-dns-server/logs" ];
    prepare = ''
      install -d -m700 /var/backup/lldap
      ${lib.getExe pkgs.sqlite} /var/lib/private/lldap/users.db ".backup '/var/backup/lldap/users.db'"
    '';
  };

  # O DNS precisa de endereço fixo: reserve o 10.42.1.2 para o Pi no DHCP do
  # roteador ou fixe aqui (confira o nome da interface com `ip link`; no Pi 4 costuma ser end0).
  # networking.interfaces.end0.ipv4.addresses = [ { address = "10.42.1.2"; prefixLength = 24; } ];
  # networking.defaultGateway = "10.42.1.1";
  # networking.nameservers = [ "1.1.1.1" ];
}
