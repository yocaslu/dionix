# Raspberry Pi 4 do homelab (10.42.1.2): roteador do Tailscale, DNS
# (Technitium), proxy reverso (Nginx), login central (lldap), página de status,
# página inicial e backup no Google Drive. Substitui o core-compose (Traefik, Technitium e
# Portainer em Docker). Não tem hardware-configuration.nix: a imagem SD já
# define os sistemas de arquivos (modules/nixos/raspberry-pi.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Host `server` (NixOS no hardware), na mesma rede de casa
  server = config.dionix.homelab.server;
  em = port: "http://${server}:${toString port}";
in
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/raspberry-pi.nix
    ../../modules/nixos/tailscale-router.nix
    ../../modules/nixos/dns-server.nix
    ../../modules/nixos/reverse-proxy.nix
    ../../modules/nixos/ldap.nix
    ../../modules/nixos/homelab.nix
    ../../modules/nixos/status.nix
    ../../modules/nixos/homepage.nix
    ../../modules/nixos/node-exporter.nix
    ../../modules/nixos/backup.nix
  ];

  # Rede de casa anunciada para a tailnet: de fora, os serviços e o server são
  # alcançados por aqui
  dionix.tailscaleRouter = {
    routes = [ "10.42.1.0/24" ];
    exitNode = true;
  };

  # <serviço>.vault76.com.br. Dentro de casa (e pela tailnet) o Technitium
  # responde *.vault76.com.br com o IP do Pi; a Cloudflare tem o mesmo curinga,
  # para quem não usa o Pi como DNS (docs/homelab.md).
  dionix.dns = {
    zone = config.dionix.homelab.domain;
    records = {
      "@" = config.dionix.homelab.pi;
      "*" = config.dionix.homelab.pi;
      pi = config.dionix.homelab.pi;
      inherit server;
    };
  };

  dionix.proxy = {
    inherit (config.dionix.homelab) domain;
    acme.enable = true; # token em /var/lib/secrets/acme.env (CF_DNS_API_TOKEN=...)

    # ldap.<domínio> vem do ldap.nix, status.<domínio> do status.nix e
    # home.<domínio> do homepage.nix
    hosts = {
      dns = "http://127.0.0.1:5380"; # painel do Technitium

      # server: Nextcloud e companhia (nextcloud.nix)
      nextcloud = {
        upstream = em 80;
        largeUploads = true;
        hsts = true;
      };
      collabora = em 9980;
      whiteboard = em 3002;
      talk = em 8095;

      # server: mídia (media.nix)
      jellyfin = em 8096;
      pedidos = em 5055; # Seerr
      sonarr = em 8989;
      radarr = em 7878;
      lidarr = em 8686;
      readarr = em 8787;
      prowlarr = em 9696;
      bazarr = em 6767;
      qbittorrent = em 8081;

      # server: monitoramento (monitoring.nix)
      grafana = em 3000;
    };
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
