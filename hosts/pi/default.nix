# Raspberry Pi 4 do homelab: roteador do Tailscale, DNS (Technitium) e proxy
# reverso (Nginx). Não tem hardware-configuration.nix: a imagem SD já define
# os sistemas de arquivos (modules/nixos/raspberry-pi.nix).
{ ... }:
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

  dionix.proxy = {
    domain = "home.arpa";
    hosts = {
      dns = "http://127.0.0.1:5380"; # painel do Technitium
      proxmox = "https://10.42.1.20:8006";
      # jellyfin = "http://10.42.1.30:8096";
    };
    # Com um domínio seu (troque o domain acima):
    # acme = {
    #   enable = true;
    #   email = "voce@exemplo.com";
    #   dnsProvider = "cloudflare";
    # };
  };

  # O DNS precisa de endereço fixo: reserve o IP do Pi no DHCP do roteador
  # ou fixe aqui (a interface cabeada do Pi 4 se chama end0).
  # networking.interfaces.end0.ipv4.addresses = [ { address = "10.42.1.2"; prefixLength = 24; } ];
  # networking.defaultGateway = "10.42.1.1";
  # networking.nameservers = [ "1.1.1.1" ];
}
