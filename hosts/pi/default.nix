# Raspberry Pi 4 do homelab (10.42.1.2): roteador do Tailscale, DNS
# (Technitium), proxy reverso (Nginx), login central (lldap) e backup no
# Google Drive. Substitui o core-compose (Traefik, Technitium e Portainer em
# Docker). Não tem hardware-configuration.nix: a imagem SD já define os
# sistemas de arquivos (modules/nixos/raspberry-pi.nix).
{ lib, pkgs, ... }:
let
  # VM production (Ubuntu, services-compose), na LAN do pfSense
  vm = "10.0.76.8";

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
    domain = "vault76.com.br";
    acme.enable = true; # token em /var/lib/secrets/acme.env (CF_DNS_API_TOKEN=...)

    hosts = {
      dns = "http://127.0.0.1:5380"; # painel do Technitium
      # ldap.vault76.com.br vem do ldap.nix
      proxmox = "https://10.42.1.20:8006";
      pfsense = "https://10.0.76.1";

      # VM production
      portainer = "https://${vm}:9443";
      pgadmin = "http://${vm}:8090";
      nextcloud = {
        upstream = "http://${vm}:8080";
        largeUploads = true;
        hsts = true;
        locations = {
          # Collabora (edição de documentos) servido pelo mesmo endereço
          "^~ /browser" = "http://${vm}:9980";
          "^~ /hosting/discovery" = "http://${vm}:9980";
          "^~ /hosting/capabilities" = "http://${vm}:9980";
          "^~ /cool/" = "http://${vm}:9980";
          "/whiteboard/" = "http://${vm}:3002/";
        };
      };
      collabora = "http://${vm}:9980";
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
