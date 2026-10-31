# Raspberry Pi 4 gerado como imagem de cartão SD (sem instalador): grave a
# imagem, ligue o Pi e entre por SSH com a chave do common.nix.
#   nix build .#packages.aarch64-linux.pi-image
#   zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
# Depois de instalado, as atualizações saem do próprio flake (veja o README).
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/sd-card/sd-image-aarch64.nix") ];

  # Firmware do Wi-Fi/Bluetooth e blobs do Pi
  hardware.enableRedistributableFirmware = true;

  # O perfil base da imagem habilita ZFS, que não é usado aqui e só atrasa o build
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # A imagem expande a partição raiz para o cartão inteiro no primeiro boot
  sdImage.expandOnBoot = true;

  # Sem senha no usuário (só chave SSH), então o sudo não pede senha.
  # Se preferir, defina uma com `passwd` e remova esta linha.
  security.sudo.wheelNeedsPassword = false;

  # Menos escrita no cartão SD: logs com teto e sem histórico de coredumps
  services.journald.extraConfig = ''
    SystemMaxUse=100M
  '';
  systemd.coredump.enable = false;
}
