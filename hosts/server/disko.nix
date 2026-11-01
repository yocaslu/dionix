# Discos do server, aplicados pelo disko na instalação (nixos-anywhere).
# Depois de instalado, o NixOS monta tudo por rótulo e pelo pool ZFS: os nomes
# abaixo só importam na hora de formatar.
#
#   sistema  HD de 500 GB: ESP (1 GB) + swap (8 GB) + raiz ext4
#   tank     espelho ZFS nos dois HDs de 1 TB (1 TB úteis, aguenta perder um disco)
#              tank/data       /srv/data                  mídia, downloads e jogos
#              tank/nextcloud  /var/lib/nextcloud/data    arquivos do Nextcloud
#
# ATENÇÃO: a instalação apaga os três discos. Os nomes /dev/sdX podem mudar entre
# boots; antes de instalar, troque pelos IDs fixos (`ls -l /dev/disk/by-id/`) ou
# confira com `lsblk` no instalador que sdb é o de 500 GB.
let
  sistema = "/dev/sdb";
  espelho = [
    "/dev/sda"
    "/dev/sdc"
  ];

  discoZfs = device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions.zfs = {
        size = "100%";
        content = {
          type = "zfs";
          pool = "tank";
        };
      };
    };
  };
in
{
  disko.devices = {
    disk = {
      sistema = {
        type = "disk";
        device = sistema;
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
      zfs-a = discoZfs (builtins.elemAt espelho 0);
      zfs-b = discoZfs (builtins.elemAt espelho 1);
    };

    zpool.tank = {
      type = "zpool";
      mode = "mirror";
      # Setores de 4 KiB (HDs atuais), mesmo que o disco anuncie 512
      options.ashift = "12";
      rootFsOptions = {
        compression = "lz4";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
        mountpoint = "none";
      };
      datasets = {
        # Arquivos grandes e sequenciais: blocos de 1 MiB
        data = {
          type = "zfs_fs";
          mountpoint = "/srv/data";
          options.recordsize = "1M";
        };
        nextcloud = {
          type = "zfs_fs";
          mountpoint = "/var/lib/nextcloud/data";
        };
      };
    };
  };
}
