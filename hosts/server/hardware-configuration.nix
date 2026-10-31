# PROVISÓRIO: substitua pelo arquivo gerado dentro da VM com
#   sudo nixos-generate-config --show-hardware-config > hosts/server/hardware-configuration.nix
# Este placeholder só existe para o flake avaliar (disco virtual /dev/sda, rótulo "nixos").
{ ... }:
{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
