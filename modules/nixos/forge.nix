# Só no forge: rede cabeada, builds dentro de 12 GB de RAM, o store do Nix
# contido no seu pedaço do SSD de 240 GB e o desligamento quando ninguém usa
# (a placa não tem S3; o Pi liga por Wake-on-LAN).
{ config, ... }:
{
  imports = [
    ./homelab.nix
    ./forge-update.nix
    ./forge-cache.nix
    ./host-sleep.nix
  ];

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
    # O DNS é o Technitium do Pi (como no server): o sono e as atualizações
    # chamam pi.<domínio> e não dependem do DNS do roteador
    dhcpV4Config.UseDNS = false;
    dns = [ config.dionix.homelab.pi ];
  };

  # Wake-on-LAN permanente, para o Pi ligar o forge depois do desligamento
  # (host-wake.nix). Igual ao do hosts/server/base.nix: mantém a política
  # padrão de nomes, que um .link próprio substituiria.
  systemd.network.links."10-wake-on-lan" = {
    matchConfig.Type = "ether";
    linkConfig = {
      NamePolicy = "keep kernel database onboard slot path";
      AlternativeNamesPolicy = "database onboard slot path";
      MACAddressPolicy = "persistent";
      WakeOnLan = "magic";
    };
  };

  # Desliga (S5) após 20 min sem uso. O forge-update (atualizações) e um
  # nixos-rebuild em andamento o seguram acordado.
  dionix.sleep = {
    enable = true;
    mode = "poweroff";
    idleMinutes = 20;
    # O node exporter é consultado pelo Prometheus do server
    ignoredPorts = [ 9100 ];
    blockers = [
      "forge-update.service"
      "nixos-rebuild-switch-to-configuration.service"
    ];
  };

  # O forge fica na rede de casa, que o Pi anuncia para a tailnet: aceitando essa
  # rota, as respostas para a 10.42.1.0/24 saíam pelo tailscale0 e o forge sumia
  # da rede (sem ping nem SSH). Aplicado com `tailscale set` a cada boot, como no Pi.
  services.tailscale.extraSetFlags = [ "--accept-routes=false" ];

  nix = {
    settings = {
      # Dois builds por vez, com 2 núcleos cada (os 4 do i5-3470 sem sobrar
      # compilador na fila): os 12 GB de RAM aguentam dois, mais estourariam
      max-jobs = 2;
      cores = 2;
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
