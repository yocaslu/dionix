# Pool do server: espelho ZFS nos dois HDs de 1 TB (1 TB úteis, aguenta perder um disco).
#   tank/data       /srv/data                  mídia, downloads e jogos
#   tank/nextcloud  /var/lib/nextcloud/data    arquivos do Nextcloud
#
# Criado no próprio server, com o `server-bootstrap` no ar, nunca em outra máquina
# (docs/homelab.md). O disko apaga os dois discos. Depois de criado, o NixOS monta
# pelo nome do pool e os caminhos abaixo não são mais usados.
let
  espelho = [
    "/dev/disk/by-id/ata-ST1000LM035-1RK172_ZDEKJ3GX" # Seagate 2,5" (SMR)
    "/dev/disk/by-id/ata-ST1000NM0008-2F2100_ZDR00M62" # Seagate Exos 3,5"
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
      # Montados só pelo systemd (fileSystems, gerado pelo disko): com o
      # mountpoint do ZFS, o zfs-mount.service disputava o mesmo ponto no boot e
      # quem perdia derrubava o local-fs.target (modo de emergência). Legacy
      # também mantém o RequiresMountsFor dos serviços, que precisa da unidade .mount.
      datasets = {
        # Arquivos grandes e sequenciais: blocos de 1 MiB
        data = {
          type = "zfs_fs";
          mountpoint = "/srv/data";
          options = {
            mountpoint = "legacy";
            recordsize = "1M";
          };
        };
        nextcloud = {
          type = "zfs_fs";
          mountpoint = "/var/lib/nextcloud/data";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
