# Máquina do server: i7-4790 (Haswell), 32 GB de RAM, vídeo pela iGPU (HD 4600),
# rede pela placa Realtek RTL8168 PCIe (a Intel I217-LM onboard fica de reserva).
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
    # Placas de rede (Realtek RTL8168 e Intel I217-LM): rede já no initrd
    "r8169"
    "e1000e"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
