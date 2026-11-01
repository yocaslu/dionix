# HD do sistema do server (500 GB): ESP (1 GB) + swap (8 GB) + raiz ext4.
#
# Formatado no desktop, com o HD ligado por SATA (docs/homelab.md): o dispositivo
# abaixo não existe de propósito, o disko-install o recebe em `--disk sistema`.
# O sistema monta tudo por rótulo de partição, então esse caminho não fica
# gravado e o boot funciona com o HD na SATA do server.
{
  disko.devices.disk.sistema = {
    type = "disk";
    device = "/dev/disk/by-id/INFORMADO-NO-DISKO-INSTALL";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        swap = {
          size = "8G";
          content.type = "swap";
        };
        raiz = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
