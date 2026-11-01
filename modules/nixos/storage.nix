# Armazenamento do server: pool ZFS em espelho (hosts/server/disko.nix) com
# snapshots automáticos, verificação mensal e métricas para o Prometheus.
#
# /srv/data (tank/data), um dataset só para que downloads e biblioteca fiquem no
# mesmo sistema de arquivos e os Arr importem por hardlink:
#   torrents/{filmes,series,musica,livros}   downloads do qBittorrent
#   media/{filmes,series,musica,livros}      biblioteca do Jellyfin
#   games/switch                             jogos do Switch (Nextcloud e FTP)
# Grupo "media" (GID 2000) com setgid nas pastas: tudo que os serviços gravam
# fica legível e editável pelos outros.
#
# Recuperar um arquivo apagado: os snapshots ficam em /srv/data/.zfs/snapshot/
# (e /var/lib/nextcloud/data/.zfs/snapshot/); é só copiar de lá.
{
  config,
  lib,
  hostname,
  ...
}:
let
  data = config.dionix.storage.data;
  categorias = [
    "filmes"
    "series"
    "musica"
    "livros"
  ];
  pasta = p: "d ${data}/${p} 2775 root media -";
in
{
  options.dionix.storage.data = lib.mkOption {
    type = lib.types.str;
    default = "/srv/data";
    description = "Raiz do dataset de mídia, downloads e jogos.";
  };

  config = {
    boot.supportedFilesystems.zfs = true;
    # O pool só é importado se foi exportado direito (padrão do NixOS a partir do 26.11)
    boot.zfs.forceImportRoot = false;
    # O ZFS exige um ID fixo por máquina; derivado do nome, sempre o mesmo
    networking.hostId = builtins.substring 0 8 (builtins.hashString "sha256" hostname);
    # O cache do ZFS (ARC) usa no máximo 8 GiB dos 32: o resto fica para os serviços
    boot.kernelParams = [ "zfs.zfs_arc_max=${toString (8 * 1024 * 1024 * 1024)}" ];

    users.groups.media.gid = 2000;

    systemd.tmpfiles.rules = [
      "d ${data} 2775 root media -"
      (pasta "games/switch")
    ]
    ++ map (c: pasta "torrents/${c}") categorias
    ++ map (c: pasta "media/${c}") categorias;

    services.zfs = {
      # Lê os dois discos inteiros e corrige o que estiver divergente
      autoScrub = {
        enable = true;
        interval = "monthly";
      };
    };

    # Snapshots: protegem contra apagar ou sobrescrever algo sem querer
    services.sanoid = {
      enable = true;
      templates.padrao = {
        hourly = 24;
        daily = 14;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
      datasets = {
        "tank/data".useTemplate = [ "padrao" ];
        "tank/nextcloud".useTemplate = [ "padrao" ];
      };
    };

    # Saúde dos discos (SMART) e do pool, coletadas pelo Prometheus
    services.smartd.enable = true;
    services.prometheus.exporters = {
      zfs.enable = true;
      smartctl.enable = true;
    };
  };
}
