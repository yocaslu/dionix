# Mídia e downloads: Jellyfin, Seerr (pedidos), suite Arr e qBittorrent.
# Todos rodam no grupo "media" (GID 2000) com umask 002, então
# o que um baixa os outros conseguem mover, renomear e ler.
#
# Caminhos dentro do dataset ZFS tank/data (/srv/data, criados pelo storage.nix):
#   torrents/<categoria>   downloads do qBittorrent (categorias: filmes, series, musica, livros)
#   media/<categoria>      biblioteca organizada pelos Arr, lida pelo Jellyfin
#   games/switch           jogos do Switch: categoria "switch" do qBittorrent;
#                          aparece no Nextcloud e no FTP (switch-ftp.nix)
# Como torrents/ e media/ ficam no mesmo dataset, a importação é por hardlink:
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
  data = config.dionix.storage.data;

  # Os Arr que organizam a biblioteca (o Prowlarr só cuida dos indexadores)
  arr = [
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
  ];
  # Serviços que escrevem na biblioteca: grupo media, arquivos 664/775 e o pool montado
  mediaServices = arr ++ [
    "bazarr"
    "jellyfin"
    "qbittorrent"
  ];
in
{
  imports = [
    ./homelab.nix
    ./storage.nix
  ];

  services = {
    jellyfin = {
      enable = true;
      group = "media";
      openFirewall = true;
      # Transcodificação na RX 580 (VA-API). Endereço PCI em vez de renderD128 porque a
      # numeração muda se a iGPU também estiver ativa; confira com `ls /dev/dri/by-path`.
      hardwareAcceleration = {
        enable = true;
        type = "vaapi";
        device = "/dev/dri/by-path/pci-0000:01:00.0-render";
      };
      # O que a RX 580 (Polaris) faz por hardware: decodifica H.264 e HEVC de 8 e 10 bits,
      # codifica H.264 e HEVC de 8 bits. VP9 e AV1 ficam com a CPU.
      transcoding = {
        enableHardwareEncoding = true;
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          mpeg2 = true;
          vc1 = true;
        };
        hardwareEncodingCodecs.hevc = true;
      };
      # Grava a configuração de transcodificação mesmo se já existir uma do painel
      forceEncodingConfig = true;
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

  # Acesso à placa de vídeo
  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  systemd.services = lib.genAttrs mediaServices (_: {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = data;
  });
}
