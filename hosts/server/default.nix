# VM `server` no Proxmox (10.0.76.8, LAN do pfSense): todos os serviços do
# homelab rodando nativos, sem containers. O Pi publica cada um com HTTPS em
# <serviço>.vault76.com.br; os arquivos grandes ficam no NAS (NFS).
#
#   nextcloud.nix     Nextcloud + Collabora + Whiteboard + Talk (sinalização e Janus)
#   media.nix         Jellyfin, Seerr, Sonarr, Radarr, Lidarr, Readarr, Prowlarr, Bazarr, qBittorrent
#   monitoring.nix    Prometheus + Grafana
#
# Para mais servidores, copie esta pasta (ex.: hosts/server2) e adicione o
# nome em `hosts` no flake.nix.
{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/proxmox-vm.nix
    ../../modules/nixos/nextcloud.nix
    ../../modules/nixos/media.nix
    # NUT pausado: precisa de preparativos no Switch (switch-nut.nix fica para depois)
    ../../modules/nixos/monitoring.nix
    ../../modules/nixos/backup.nix
  ];

  # IP por reserva no DHCP do pfSense (Services → DHCP Server → LAN → Static Mappings,
  # com o MAC desta VM). O DNS é o Technitium do Pi, que resolve *.vault76.com.br
  # para o proxy: o Nextcloud e o Collabora conversam entre si por esses nomes.
  networking.nameservers = [ config.dionix.homelab.pi ];

  # Backup diário no Google Drive (gdrive:homelab/server). Os arquivos do NAS
  # (mídia, jogos e dados do Nextcloud) entram no backup do próprio NAS.
  dionix.backup = {
    paths = [
      "/var/lib/nextcloud/config"
      "/var/backup/postgresql" # dump do banco do Nextcloud (abaixo)
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
