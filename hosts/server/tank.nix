# Pool do server: espelho ZFS nos dois HDs de 1 TB (1 TB úteis, aguenta perder um disco).
#   tank/data       /srv/data                  mídia, downloads e jogos
#   tank/nextcloud  /var/lib/nextcloud/data    arquivos do Nextcloud
#
# Criado no próprio server, com o `server-bootstrap` no ar, nunca em outra máquina
# (docs/homelab.md). O disko apaga os dois discos. Troque os caminhos abaixo pelos
# IDs reais (`ls -l /dev/disk/by-id/`); enquanto não existirem, ele não formata nada.
# Depois disso o NixOS monta pelo nome do pool e os caminhos não são mais usados.
let
  espelho = [
    "/dev/disk/by-id/TROCAR-PELO-ID-DO-HD-1TB-A"
    "/dev/disk/by-id/TROCAR-PELO-ID-DO-HD-1TB-B"
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
