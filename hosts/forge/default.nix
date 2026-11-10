# Servidor de desenvolvimento, sem interface gráfica e ligado 24/7.
# Máquina: o antigo desktop (i5-3470, 8 GB de RAM e SSD de 240 GB).
# Os serviços (Git, segredos, CI, cache e deploy) vêm nos próximos sub-projetos.
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/node-exporter.nix
    ../../modules/nixos/forge.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
