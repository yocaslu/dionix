# Raspberry Pi 4 do homelab (10.42.1.2): roteador do Tailscale, DNS
# (Technitium) e proxy reverso (Nginx). Substitui o core-compose (Traefik,
# Technitium e Portainer em Docker). Não tem hardware-configuration.nix: a
# imagem SD já define os sistemas de arquivos (modules/nixos/raspberry-pi.nix).
{ ... }:
let
  # VM do Proxmox com os serviços do services-compose (Nextcloud e afins)
  # vm = "10.42.1.X";
in
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/raspberry-pi.nix
    ../../modules/nixos/tailscale-router.nix
    ../../modules/nixos/dns-server.nix
    ../../modules/nixos/reverse-proxy.nix
  ];

  # Rede de casa anunciada para a tailnet
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
      proxmox = "https://10.42.1.20:8006";

      # Serviços da VM: descomente o `vm` acima com o IP dela.
      # portainer = "https://${vm}:9443";
      # nextcloud = {
      #   upstream = "http://${vm}:8080";
      #   largeUploads = true;
      #   hsts = true;
      #   locations = {
      #     # Collabora (edição de documentos) servido pelo mesmo endereço
      #     "^~ /browser" = "http://${vm}:9980";
      #     "^~ /hosting/discovery" = "http://${vm}:9980";
      #     "^~ /hosting/capabilities" = "http://${vm}:9980";
      #     "^~ /cool/" = "http://${vm}:9980";
      #     "/whiteboard/" = "http://${vm}:3002/";
      #   };
      # };
      # collabora = "http://${vm}:9980";
    };
  };

  # O DNS precisa de endereço fixo: reserve o 10.42.1.2 para o Pi no DHCP do
  # roteador ou fixe aqui (confira o nome da interface com `ip link`; no Pi 4 costuma ser end0).
  # networking.interfaces.end0.ipv4.addresses = [ { address = "10.42.1.2"; prefixLength = 24; } ];
  # networking.defaultGateway = "10.42.1.1";
  # networking.nameservers = [ "1.1.1.1" ];
}
