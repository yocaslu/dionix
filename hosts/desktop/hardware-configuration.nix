# PROVISÓRIO: substitua pelo arquivo gerado na própria máquina com
#   sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
# Este placeholder só existe para o flake avaliar (rótulos de partição genéricos).
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-amd"
    "kvm-intel"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  hardware.enableRedistributableFirmware = true;
  nixpkgs.hostPlatform = "x86_64-linux";
}
