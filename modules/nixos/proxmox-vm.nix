# VM no Proxmox (QEMU/KVM): agente do convidado, console serial e boot pelo
# GRUB no disco virtual. Combina com o hardware-configuration.nix gerado
# dentro da VM pelo `nixos-generate-config`.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Ative "QEMU Guest Agent" nas opções da VM no Proxmox
  services.qemuGuest.enable = true;

  # Console serial (habilite "Serial port" na VM para usar o xterm.js do Proxmox)
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty1"
  ];

  # BIOS padrão do Proxmox (SeaBIOS). Para OVMF/UEFI, troque por systemd-boot.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}
