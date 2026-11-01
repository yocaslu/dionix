# Parte comum do `server` e do `server-bootstrap`: máquina, HD do sistema, boot,
# rede e suporte a ZFS.
{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko
    ../../modules/nixos/common.nix
  ];

  # O disko-install desliga canTouchEfiVariables ao gravar o HD no desktop (a
  # NVRAM dele fica intacta) e o firmware do server inicia pelo caminho padrão
  # do ESP; a entrada de boot própria é criada na primeira atualização no server.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Rede: qualquer porta Ethernet (o adaptador USB muda de nome conforme a porta),
  # por DHCP. Reserve 10.42.1.20 para o MAC do adaptador no roteador da operadora.
  networking.useNetworkd = true;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  boot.supportedFilesystems.zfs = true;
  # O ZFS exige um ID fixo por máquina, o mesmo nos dois sistemas: o pool criado
  # no bootstrap precisa ser importado pelo server sem forçar.
  networking.hostId = builtins.substring 0 8 (builtins.hashString "sha256" "server");
}
