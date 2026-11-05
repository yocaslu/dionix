# Máquina do server: i7-4790 (Haswell), 32 GB de RAM, vídeo pela iGPU (HD 4600),
# rede pela Intel I217-LM onboard (placa-mãe trocada; a Realtek PCIe saiu).
# Os sistemas de arquivos vêm do disko.nix, não daqui.
#
# Conferido com `nixos-generate-config --show-hardware-config` no próprio server
# (docs/homelab.md), sem trazer fileSystems/swapDevices.
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
    # Rede onboard (Intel I217-LM): já no initrd
    "e1000e"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
