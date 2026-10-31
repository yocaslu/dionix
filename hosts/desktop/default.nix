# Desktop de desenvolvimento: igual ao notebook, sem Wi-Fi e Bluetooth (rede cabeada)
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/desktop.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Emula ARM (QEMU) para compilar a imagem e as atualizações do Raspberry Pi
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
