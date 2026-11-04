# Raspberry Pi 4 gerado como imagem de cartão SD (sem instalador): grave a
# imagem, ligue o Pi e entre por SSH com a chave do common.nix.
#   nix build .#packages.aarch64-linux.pi-image
#   zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
# Depois de instalado, as atualizações saem do próprio flake (veja o README).
{
  lib,
  modulesPath,
  options,
  ...
}:
{
  imports = [ (modulesPath + "/installer/sd-card/sd-image-aarch64.nix") ];

  # Firmware do Wi-Fi/Bluetooth e blobs do Pi
  hardware.enableRedistributableFirmware = true;

  # O glances (common.nix) não tem cache para aarch64, e os testes dele levam
  # dezenas de minutos na emulação ARM do notebook/desktop
  nixpkgs.overlays = [
    (final: prev: {
      glances = prev.glances.overridePythonAttrs { doCheck = false; };
    })
  ];

  # O perfil base da imagem habilita ZFS, que não é usado aqui e só atrasa o build
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # A imagem expande a partição raiz para o cartão inteiro no primeiro boot
  sdImage.expandOnBoot = true;

  # CPU fixa na frequência mínima (600 MHz) para o chip esquentar menos. Os
  # serviços do Pi sobram nela; backups e compilar a config no próprio Pi ficam
  # mais lentos. Para um build pesado: `sudo cpupower frequency-set -g schedutil`
  # (volta ao powersave no próximo boot). Temperatura: node_thermal_zone_temp.
  powerManagement.cpuFreqGovernor = "powersave";
  # O driver vem pelo udev, que pode chegar depois do cpufreq.service: carregado
  # junto com os módulos do boot, o governor já encontra o driver
  boot.kernelModules = [ "raspberrypi_cpufreq" ];

  # Sem senha no usuário (só chave SSH), então o sudo não pede senha.
  # Se preferir, defina uma com `passwd` e remova esta linha.
  security.sudo.wheelNeedsPassword = false;

  # Menos escrita no cartão SD: logs com teto e sem histórico de coredumps
  services.journald.extraConfig = ''
    SystemMaxUse=100M
  '';
  systemd.coredump.enable = false;

  # O Pi não tem relógio de bateria: liga com a hora errada, e com ela o DNSSEC do
  # Technitium falha ("SignatureNotYetValid") e nada resolve, nem o servidor de NTP.
  # Servidores por IP quebram esse ciclo; o timesyncd ainda guarda a última hora no disco.
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "162.159.200.123"
  ]
  ++ options.networking.timeServers.default;
}
