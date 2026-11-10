# Só no forge: rede cabeada, builds dentro de 8 GB de RAM e o store do Nix
# contido no seu pedaço do SSD de 240 GB.
{ ... }:
{
  imports = [ ./homelab.nix ];

  # Rede: qualquer porta Ethernet, por DHCP; o 10.42.1.3 vem da reserva no
  # roteador. Cópia da do hosts/server/base.nix, em vez de um módulo comum,
  # para não mexer no server em produção.
  networking.useNetworkd = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  # O forge fica na rede de casa, que o Pi anuncia para a tailnet: aceitando essa
  # rota, as respostas para a 10.42.1.0/24 saíam pelo tailscale0 e o forge sumia
  # da rede (sem ping nem SSH). Aplicado com `tailscale set` a cada boot, como no Pi.
  services.tailscale.extraSetFlags = [ "--accept-routes=false" ];

  nix = {
    settings = {
      # Um build por vez, com os 4 núcleos: vários compiladores juntos estouram a RAM
      max-jobs = 1;
      cores = 4;
      # Com menos de 10 GiB livres durante um build, o Nix coleta lixo até
      # sobrarem 30 GiB (o nh clean do common.nix continua limpando por idade)
      min-free = 10 * 1024 * 1024 * 1024;
      max-free = 30 * 1024 * 1024 * 1024;
    };
    # Builds não atrasam os serviços da máquina
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };

  # Contra OOM: o zram do common.nix (prioridade maior) é usado primeiro e o
  # swapfile só quando ele enche. O NixOS cria o arquivo no primeiro boot.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];

  # Emula ARM (QEMU) para compilar a imagem e as atualizações do Raspberry Pi
  # (e, depois, o CI)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Menos escritas no SSD e rebuild sem gerar o manual do NixOS
  fileSystems."/".options = [ "noatime" ];
  documentation.nixos.enable = false;
}
