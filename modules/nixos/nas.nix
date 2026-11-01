# Pastas do NAS (OpenMediaVault, 10.0.76.6) montadas por NFS, por padrão em
# /mnt/nas/<nome>. Cada papel declara os compartilhamentos de que precisa.
# As montagens sobem sob demanda (automount): a VM liga mesmo com o NAS fora.
#
#   data       um único compartilhamento para downloads e biblioteca, assim o
#              qBittorrent e a suite Arr usam hardlinks em vez de copiar:
#                torrents/{filmes,series,musica,livros}
#                media/{filmes,series,musica,livros}
#                games/switch
#   nextcloud  arquivos dos usuários do Nextcloud (montado em /var/lib/nextcloud/data)
#
# Permissões no NAS (o NFS compara uid/gid numéricos):
#   data       grupo de GID 2000 ("media"), pastas com setgid (chmod 2775)
#   nextcloud  dono UID 2001 ("nextcloud"), chmod 0770
# Nas exportações do OMV use "rw,subtree_check,root_squash".
{ config, lib, ... }:
let
  cfg = config.dionix.nas;
in
{
  options.dionix.nas = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "10.0.76.6";
      description = "Endereço do NAS.";
    };
    shares = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Caminho exportado pelo NAS (o que vem depois de "host:" no mount).
                  No OMV, confira com `showmount -e 10.0.76.6`: costuma ser /<pasta>
                  no NFSv4 ou /export/<pasta>.
                '';
              };
              mountPoint = lib.mkOption {
                type = lib.types.str;
                default = "/mnt/nas/${name}";
              };
              readOnly = lib.mkEnableOption "montagem somente leitura";
            };
          }
        )
      );
      default = { };
      description = "Compartilhamentos montados nesta máquina.";
    };
  };

  config = {
    boot.supportedFilesystems = [ "nfs" ];

    fileSystems = lib.mapAttrs' (
      _: share:
      lib.nameValuePair share.mountPoint {
        device = "${cfg.host}:${share.path}";
        fsType = "nfs";
        options = [
          "nfsvers=4.2"
          "noatime"
          "x-systemd.automount"
          "noauto"
          "x-systemd.mount-timeout=30"
          "_netdev"
        ]
        ++ lib.optional share.readOnly "ro";
      }
    ) cfg.shares;

    # IDs fixos, iguais aos do NAS
    users.groups.media.gid = 2000;
  };
}
