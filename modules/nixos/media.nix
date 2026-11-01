# Mídia e downloads: Jellyfin, Seerr (pedidos), suite Arr e qBittorrent.
# Todos rodam no grupo "media" (GID 2000, o mesmo do NAS) com umask 002, então
# o que um baixa os outros conseguem mover, renomear e ler.
#
# Caminhos dentro do compartilhamento "data" do NAS (/mnt/nas/data):
#   torrents/<categoria>   downloads do qBittorrent (categorias: filmes, series, musica, livros)
#   media/<categoria>      biblioteca organizada pelos Arr, lida pelo Jellyfin
# Como os dois ficam no mesmo compartilhamento, a importação é por hardlink:
# o arquivo continua semeando sem ocupar espaço duas vezes.
#
#   jellyfin.<domínio>     :8096   biblioteca e streaming
#   pedidos.<domínio>      :5055   Seerr (pedidos de filmes e séries)
#   sonarr/radarr/lidarr/readarr/prowlarr/bazarr.<domínio>
#   qbittorrent.<domínio>  :8081   (porta de torrent 51413 TCP/UDP)
#
# Configure os caminhos e as ligações entre eles pelos painéis (passo a passo no README).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dionix.homelab) domain pi;
  data = "/mnt/nas/data";

  # Os Arr que organizam a biblioteca (o Prowlarr só cuida dos indexadores)
  arr = [
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
  ];
  # Serviços que escrevem na biblioteca: grupo media, arquivos 664/775 e o NAS montado
  mediaServices = arr ++ [
    "bazarr"
    "jellyfin"
    "qbittorrent"
  ];
in
{
  imports = [
    ./homelab.nix
    ./nas.nix
  ];

  dionix.nas.shares.data.path = "/data";

  services = {
    jellyfin = {
      enable = true;
      group = "media";
      openFirewall = true;
      # Transcodificação por hardware: passe a GPU (ou a iGPU) para a VM no Proxmox
      # e ative `hardwareAcceleration` com o device /dev/dri/renderD128.
    };

    seerr = {
      enable = true;
      openFirewall = true;
    };

    bazarr = {
      enable = true;
      group = "media";
      openFirewall = true;
    };

    # Indexadores (com usuário dinâmico próprio, sem acesso à biblioteca)
    prowlarr = {
      enable = true;
      openFirewall = true;
    };

    # Resolve o desafio da Cloudflare para os indexadores do Prowlarr que pedem
    flaresolverr.enable = true;

    qbittorrent = {
      enable = true;
      group = "media";
      webuiPort = 8081;
      torrentingPort = 51413;
      openFirewall = true;
      serverConfig = {
        LegalNotice.Accepted = true;
        BitTorrent.Session = {
          DefaultSavePath = "${data}/torrents";
          TempPathEnabled = false;
          # Categorias criam subpastas (torrents/filmes, torrents/series…)
          DisableAutoTMMByDefault = false;
        };
        Preferences = {
          General.Locale = "pt_BR";
          # Atrás do proxy do Pi: aceita o nome público e confia no X-Forwarded-For
          WebUI = {
            ServerDomains = "qbittorrent.${domain}";
            ReverseProxySupportEnabled = true;
            TrustedReverseProxiesList = pi;
            # Interface VueTorrent (mais leve e responsiva que a padrão)
            AlternativeUIEnabled = true;
            RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
          };
        };
      };
    };

  }
  # Suite Arr: as portas padrão, abertas para o proxy do Pi
  // lib.genAttrs arr (_: {
    enable = true;
    group = "media";
    openFirewall = true;
  });

  systemd.services = lib.genAttrs mediaServices (_: {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = data;
  });
}
