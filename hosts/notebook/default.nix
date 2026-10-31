# Notebook de desenvolvimento (ideapad 3): SwayFX + XFCE, Wi-Fi e Bluetooth
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/laptop.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
