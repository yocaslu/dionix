# Página inicial do homelab (Homepage) em home.<domínio>: um cartão por serviço
# do proxy (dionix.proxy.hosts), com link e status, e o uso de CPU, memória,
# disco e temperatura do server e do Pi, lidos do Prometheus do server.
#
# Serviço novo no proxy aparece sozinho em "Outros"; para dar nome, grupo e
# ícone, acrescente-o em `catalogo` (ícones: https://dashboardicons.com).
{ config, lib, ... }:
let
  inherit (config.dionix.homelab) domain server;
  port = 8082;
  prometheus = "http://${server}:9090";
  gatus = "http://127.0.0.1:${toString config.services.gatus.settings.web.port}";
  url = name: "https://${name}.${domain}";

  # Grupos na ordem em que aparecem
  grupos = [
    "Nuvem"
    "Mídia"
    "Downloads"
    "Infraestrutura"
    "Outros"
  ];

  # Nome no proxy → grupo, título, ícone (dashboard-icons ou mdi-*) e descrição
  item = grupo: titulo: icone: descricao: {
    inherit
      grupo
      titulo
      icone
      descricao
      ;
  };
  catalogo = {
    nextcloud = item "Nuvem" "Nextcloud" "nextcloud.png" "arquivos, agenda e contatos";
    collabora = item "Nuvem" "Collabora" "collabora-online.png" "documentos no Nextcloud";
    talk = item "Nuvem" "Talk" "nextcloud-talk.png" "sinalização das chamadas";
    whiteboard = item "Nuvem" "Whiteboard" "excalidraw.png" "quadro branco do Nextcloud";
    jellyfin = item "Mídia" "Jellyfin" "jellyfin.png" "filmes, séries e música";
    pedidos = item "Mídia" "Pedidos" "jellyseerr.png" "pedidos de filmes e séries (Seerr)";
    sonarr = item "Downloads" "Sonarr" "sonarr.png" "séries";
    radarr = item "Downloads" "Radarr" "radarr.png" "filmes";
    lidarr = item "Downloads" "Lidarr" "lidarr.png" "música";
    readarr = item "Downloads" "Readarr" "readarr.png" "livros";
    bazarr = item "Downloads" "Bazarr" "bazarr.png" "legendas";
    prowlarr = item "Downloads" "Prowlarr" "prowlarr.png" "indexadores";
    qbittorrent = item "Downloads" "qBittorrent" "qbittorrent.png" "torrents";
    grafana = item "Infraestrutura" "Grafana" "grafana.png" "métricas e painéis";
    status = item "Infraestrutura" "Status" "gatus.png" "checagens de todos os serviços";
    dns = item "Infraestrutura" "DNS" "technitium.png" "Technitium, no Pi";
    ldap = item "Infraestrutura" "LDAP" "lldap.png" "usuários e grupos (lldap)";
  };

  servico =
    name: _:
    let
      c = catalogo.${name} or (item "Outros" name "mdi-web" "");
    in
    {
      inherit (c) grupo;
      cartao.${c.titulo} = {
        href = url name;
        icon = c.icone;
        description = c.descricao;
        siteMonitor = url name;
      }
      // lib.optionalAttrs (name == "status") {
        widget = {
          type = "gatus";
          url = gatus;
        };
      };
    };

  cartoes = lib.mapAttrsToList servico (lib.removeAttrs config.dionix.proxy.hosts [ "home" ]);
  noGrupo =
    g:
    lib.sort (a: b: lib.head (lib.attrNames a) < lib.head (lib.attrNames b)) (
      map (s: s.cartao) (lib.filter (s: s.grupo == g) cartoes)
    );

  # Estatísticas de um host (rótulo `host` do Prometheus; até 4 métricas por cartão)
  pct = label: query: {
    inherit label query;
    format = {
      type = "percent";
      options.maximumFractionDigits = 0;
    };
  };
  temperatura = query: {
    label = "temp.";
    inherit query;
    format = {
      type = "number";
      suffix = " °C";
      options.maximumFractionDigits = 0;
    };
  };
  maquina = host: description: disco: tempType: {
    ${host} = {
      inherit description;
      icon = "mdi-server";
      # Detalhes no Node Exporter Full, provisionado no Grafana (monitoring.nix)
      href = "${url "grafana"}/d/rYdddlPWk/node-exporter-full?var-nodename=${host}";
      widget = {
        type = "prometheusmetric";
        url = prometheus;
        refreshInterval = 15000;
        metrics = [
          (pct "CPU" ''100 * (1 - avg(rate(node_cpu_seconds_total{host="${host}",mode="idle"}[2m])))'')
          (pct "memória" ''100 * (1 - node_memory_MemAvailable_bytes{host="${host}"} / node_memory_MemTotal_bytes{host="${host}"})'')
          disco
          (temperatura ''max(node_thermal_zone_temp{host="${host}",type="${tempType}"})'')
        ];
      };
    };
  };
in
{
  imports = [ ./homelab.nix ];

  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    allowedHosts = "home.${domain}";

    settings = {
      title = "vault76";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";
      statusStyle = "dot";
      hideVersion = true;
      layout = [
        {
          Servidores = {
            style = "row";
            columns = 2;
          };
        }
      ]
      ++ map (g: {
        ${g} = {
          style = "row";
          columns = 4;
        };
      }) grupos;
    };

    widgets = [
      {
        datetime = {
          text_size = "md";
          format = {
            dateStyle = "full";
            timeStyle = "short";
          };
        };
      }
    ];

    services = [
      {
        Servidores = [
          (maquina "server" "NixOS, espelho ZFS (tank)"
            (pct "tank" ''100 * zfs_pool_allocated_bytes{pool="tank"} / zfs_pool_size_bytes{pool="tank"}'')
            "x86_pkg_temp"
          )
          (maquina "pi" "Raspberry Pi 4: proxy, DNS e LDAP"
            (pct "cartão SD" ''100 * (1 - node_filesystem_avail_bytes{host="pi",mountpoint="/"} / node_filesystem_size_bytes{host="pi",mountpoint="/"})'')
            "cpu-thermal"
          )
        ];
      }
    ]
    ++ map (g: { ${g} = noGrupo g; }) (lib.filter (g: noGrupo g != [ ]) grupos);

    # Visual TUI: cantos retos e bordas de 1px
    customCSS = ''
      * { border-radius: 0 !important; }
      body { font-family: "JetBrainsMono Nerd Font", monospace; }
      .service-card { border: 1px solid rgb(255 255 255 / 0.12); box-shadow: none; }
    '';
  };

  dionix.proxy.hosts.home = "http://127.0.0.1:${toString port}";
}
