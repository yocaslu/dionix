# Máquina do server: i7-4790 (Haswell), 32 GB de RAM, RX 580, rede por adaptador
# USB 3.0 Gigabit. Os sistemas de arquivos vêm do disko.nix, não daqui.
#
# Escrito à mão: o HD é gravado no desktop, onde a detecção veria o hardware
# errado. Confira com `nixos-generate-config --show-hardware-config` no
# próprio server (docs/homelab.md), sem trazer fileSystems/swapDevices.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    # Adaptadores USB Gigabit (Realtek RTL8153, ASIX AX88179): rede já no initrd
    "r8152"
    "ax88179_178a"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
