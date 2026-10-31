# Servidor do homelab: VM no Proxmox rodando containers Docker.
# Para mais servidores, copie esta pasta (ex.: hosts/server2) e adicione o
# nome na lista de nixosConfigurations do flake.nix.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/proxmox-vm.nix
    ../../modules/nixos/docker-host.nix
  ];

  # IP fixo (opcional): por padrão usa DHCP
  # networking.interfaces.ens18.ipv4.addresses = [ { address = "10.42.1.30"; prefixLength = 24; } ];
  # networking.defaultGateway = "10.42.1.1";
  # networking.nameservers = [ "10.42.1.1" ];
}
