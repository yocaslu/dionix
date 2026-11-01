# Servidor do homelab, direto no hardware (sem Proxmox): i7-4790, 32 GB, RX 580,
# sistema num HD de 500 GB e espelho ZFS nos dois HDs de 1 TB (tank.nix).
# Fica na rede de casa, em 10.42.1.20; o Pi publica cada serviço com HTTPS em
# <serviço>.vault76.com.br.
#
#   storage.nix       pool ZFS: snapshots, scrub, SMART
#   nextcloud.nix     Nextcloud + Collabora + Whiteboard + Talk (sinalização e Janus)
#   media.nix         Jellyfin (VA-API na RX 580), Seerr, suite Arr, qBittorrent
#   switch-ftp.nix    FTP só leitura dos jogos do Switch para a rede de casa
#   monitoring.nix    Prometheus + Grafana
#
# Instalação e atualização: docs/homelab.md.
{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./base.nix
    ./tank.nix
    ../../modules/nixos/storage.nix
    ../../modules/nixos/nextcloud.nix
    ../../modules/nixos/media.nix
    ../../modules/nixos/switch-ftp.nix
    # NUT pausado: precisa de preparativos no Switch (switch-nut.nix fica para depois)
    ../../modules/nixos/monitoring.nix
    ../../modules/nixos/backup.nix
  ];

  # O DNS é o Technitium do Pi (resolve *.vault76.com.br para o proxy:
  # o Nextcloud e o Collabora conversam entre si por esses nomes)
  systemd.network.networks."10-ethernet" = {
    dhcpV4Config.UseDNS = false;
    dns = [ config.dionix.homelab.pi ];
  };

  # RX 580: decodificação e codificação de vídeo (VA-API, Mesa)
  hardware.graphics.enable = true;
  environment.systemPackages = [ pkgs.libva-utils ]; # `vainfo` confere a aceleração

  # Backup diário no Google Drive (gdrive:homelab/server): configuração dos
  # serviços, dump do banco e os dados do pool
  dionix.backup = {
    paths = [
      "/var/lib/nextcloud/config"
      "/var/lib/nextcloud/data"
      "/var/backup/postgresql" # dump do banco do Nextcloud (abaixo)
      config.dionix.storage.data
      "/var/lib/jellyfin"
      "/var/lib/seerr"
      "/var/lib/sonarr"
      "/var/lib/radarr"
      "/var/lib/lidarr"
      "/var/lib/readarr"
      "/var/lib/private/prowlarr"
      "/var/lib/bazarr"
      "/var/lib/qBittorrent"
      "/var/lib/grafana"
      "/var/lib/secrets"
    ];
    exclude = [
      "/var/lib/jellyfin/transcodes"
      "/var/lib/jellyfin/metadata"
      # Downloads em andamento; o que terminou já está em media/ (mesmo arquivo, por hardlink)
      "${config.dionix.storage.data}/torrents"
      # Snapshots do ZFS (já são cópias do que está sendo salvo)
      ".zfs"
    ];
  };

  # Dump diário e consistente do Postgres do Nextcloud (lido pelo backup)
  services.postgresqlBackup = {
    enable = true;
    databases = [ "nextcloud" ];
    startAt = "02:30";
    compression = "zstd";
  };
}
