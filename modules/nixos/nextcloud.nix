# Nextcloud nativo, com Collabora (documentos), Whiteboard e Talk com o
# High Performance Backend (servidor de sinalização + Janus para as chamadas).
# O Pi publica tudo com HTTPS; aqui os serviços falam HTTP na rede de casa.
#
#   nextcloud.<domínio>   Nginx deste host → PHP-FPM (Postgres e Redis locais)
#   collabora.<domínio>   coolwsd :9980
#   whiteboard.<domínio>  servidor do Whiteboard :3002
#   talk.<domínio>        sinalização do Talk :8095 → Janus (só local, :8188)
#   Chamadas              mídia direto com o Janus (UDP 20000-20200): o server está na
#                         rede de casa, e a tailnet chega a ele pela rota do Pi
#
# Os arquivos dos usuários ficam no dataset ZFS tank/nextcloud (montado em
# /var/lib/nextcloud/data); configuração, apps e banco ficam no disco do sistema.
# A pasta de jogos do Switch (games/switch do dataset tank/data) aparece
# como armazenamento externo "Jogos do Switch" para o grupo admin.
#
# Segredos: gerados no primeiro boot em /var/lib/secrets (nextcloud-secrets.service).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dionix.homelab) domain pi;
  nc = config.services.nextcloud;
  occ = lib.getExe nc.occ;
  url = name: "https://${name}.${domain}";
  secrets = "/var/lib/secrets";
  jogos = "${config.dionix.storage.data}/games/switch";

  # Portas das chamadas (WebRTC) do Janus
  rtpPorts = {
    from = 20000;
    to = 20200;
  };

  # Configuração do Janus (formato libconfig). Só o plugin videoroom e o
  # transporte websockets são usados pela sinalização do Talk.
  janus = pkgs.janus-gateway;
  janusConfig = pkgs.writeTextDir "janus.jcfg" ''
    general: {
      configs_folder = "@CONFIGS@"
      plugins_folder = "${janus}/lib/janus/plugins"
      transports_folder = "${janus}/lib/janus/transports"
      events_folder = "${janus}/lib/janus/events"
      loggers_folder = "${janus}/lib/janus/loggers"
      debug_level = 4
      server_name = "janus-talk"
    }
    media: {
      rtp_port_range = "${toString rtpPorts.from}-${toString rtpPorts.to}"
    }
    nat: {
      full_trickle = true
      # Não oferece endereços da tailnet nem de bridges como candidatos ICE
      ice_ignore_list = "tailscale,docker,veth,virbr"
    }
    plugins: {
      disable = "libjanus_audiobridge.so,libjanus_echotest.so,libjanus_nosip.so,libjanus_recordplay.so,libjanus_sip.so,libjanus_streaming.so,libjanus_textroom.so,libjanus_videocall.so"
    }
    transports: {
      disable = "libjanus_http.so,libjanus_pfunix.so"
    }
    loggers: {
      disable = "libjanus_jsonlog.so"
    }
    events: {
      broadcast = false
    }
  '';
  janusConfigDir = pkgs.runCommand "janus-config" { } ''
    mkdir -p $out
    substitute ${janusConfig}/janus.jcfg $out/janus.jcfg --replace-fail @CONFIGS@ $out
    cat > $out/janus.transport.websockets.jcfg <<'EOF'
    general: {
      json = "compact"
      ws = true
      ws_port = 8188
      ws_ip = "127.0.0.1"
      wss = false
    }
    admin: {
      admin_ws = false
      admin_wss = false
    }
    EOF
    cat > $out/janus.plugin.videoroom.jcfg <<'EOF'
    general: {
      string_ids = false
    }
    EOF
  '';
in
{
  imports = [
    ./homelab.nix
    ./storage.nix
  ];

  # Arquivos dos usuários no dataset tank/nextcloud (montado em /var/lib/nextcloud/data)
  users.users.nextcloud = {
    # Lê e organiza a pasta de jogos baixados pelo qBittorrent
    extraGroups = [ "media" ];
  };
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud35;
    hostName = "nextcloud.${domain}";
    # O HTTPS termina no Pi; os links gerados usam https://
    https = true;
    database.createLocally = true;
    configureRedis = true;
    maxUploadSize = "16G";
    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = "${secrets}/nextcloud-admin-pass";
    };
    extraApps = {
      inherit (nc.package.packages.apps)
        calendar
        contacts
        richdocuments
        spreed
        whiteboard
        ;
    };
    extraAppsEnable = true;
    # Notificações instantâneas (sincronização sem polling)
    notify_push.enable = true;
    settings = {
      trusted_proxies = [ pi ];
      overwriteprotocol = "https";
      "overwrite.cli.url" = url "nextcloud";
      default_phone_region = "BR";
      # Tarefas pesadas de madrugada (UTC)
      maintenance_window_start = 6;
      # Login pelo lldap: ative o app "LDAP user and group backend" e configure
      # em Administração → LDAP/AD (dados no README)
    };
    phpOptions."opcache.interned_strings_buffer" = "32";
  };

  # O setup e o PHP só sobem com os datasets do ZFS montados
  systemd.services.nextcloud-setup.unitConfig.RequiresMountsFor = "${nc.home}/data";
  systemd.services.phpfpm-nextcloud.unitConfig.RequiresMountsFor = [
    "${nc.home}/data"
    jogos
  ];

  # Documentos: o Pi publica collabora.<domínio> com HTTPS
  services.collabora-online = {
    enable = true;
    port = 9980;
    settings = {
      server_name = "collabora.${domain}";
      ssl = {
        enable = false;
        termination = true;
      };
      net = {
        listen = "any";
        # Só o Pi (proxy) e esta máquina chamam as APIs administrativas
        post_allow.host = [
          ''127\.0\.0\.1''
          (lib.replaceStrings [ "." ] [ ''\.'' ] pi)
        ];
      };
      storage.wopi."@allow" = true;
    };
    aliasGroups = [ { host = url "nextcloud"; } ];
  };

  # Whiteboard colaborativo
  services.nextcloud-whiteboard-server = {
    enable = true;
    settings = {
      NEXTCLOUD_URL = url "nextcloud";
      PORT = "3002";
    };
    secrets = [ "${secrets}/whiteboard.env" ];
  };

  # Talk: servidor de sinalização (High Performance Backend)
  services.nextcloud-spreed-signaling = {
    enable = true;
    hostName = "talk.${domain}";
    backends.nextcloud = {
      urls = [ (url "nextcloud") ];
      secretFile = "${secrets}/talk-backend-secret";
    };
    settings = {
      http.listen = "0.0.0.0:8095";
      clients.internalsecretFile = "${secrets}/talk-internal-secret";
      sessions = {
        hashkeyFile = "${secrets}/talk-hashkey";
        blockkeyFile = "${secrets}/talk-blockkey";
      };
      mcu = {
        type = "janus";
        url = "ws://127.0.0.1:8188";
      };
    };
  };

  # Janus: o servidor de mídia das chamadas (sem módulo no nixpkgs)
  systemd.services.janus = {
    description = "Janus WebRTC Server (chamadas do Nextcloud Talk)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "nextcloud-spreed-signaling.service" ];
    serviceConfig = {
      ExecStart = "${lib.getExe' janus "janus"} --configs-folder=${janusConfigDir} --disable-colors --log-stdout";
      DynamicUser = true;
      Restart = "on-failure";
      LimitNOFILE = 65536;
    };
  };

  # Gera os segredos que faltam (só no primeiro boot; nunca sobrescreve)
  systemd.services.nextcloud-secrets = {
    description = "Segredos do Nextcloud, Whiteboard e Talk";
    wantedBy = [ "multi-user.target" ];
    before = [
      "nextcloud-setup.service"
      "nextcloud-whiteboard-server.service"
      "nextcloud-spreed-signaling.service"
    ];
    requiredBy = [
      "nextcloud-setup.service"
      "nextcloud-whiteboard-server.service"
      "nextcloud-spreed-signaling.service"
    ];
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      mkdir -p ${secrets}
      gen() { [ -s "${secrets}/$1" ] || printf '%s%s' "$3" "$(openssl rand -hex "$2")" > "${secrets}/$1"; }
      gen nextcloud-admin-pass 16
      gen talk-backend-secret 32
      gen talk-internal-secret 32
      gen talk-hashkey 32
      gen talk-blockkey 16          # 32 caracteres: chave AES-256
      gen whiteboard.env 32 JWT_SECRET_KEY=
      chown nextcloud:nextcloud ${secrets}/nextcloud-admin-pass
    '';
  };

  # Liga os apps aos serviços (idempotente: roda a cada boot e a cada rebuild)
  systemd.services.nextcloud-apps-config = {
    description = "Configura Collabora, Whiteboard e Talk no Nextcloud";
    wantedBy = [ "multi-user.target" ];
    after = [
      "nextcloud-setup.service"
      "nextcloud-secrets.service"
    ];
    requires = [ "nextcloud-setup.service" ];
    path = [ pkgs.jq ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      occ() { ${occ} "$@"; }

      # Collabora
      occ config:app:set richdocuments wopi_url --value=${url "collabora"}
      occ config:app:set richdocuments public_wopi_url --value=${url "collabora"}
      occ config:app:set richdocuments wopi_allowlist --value=${config.dionix.homelab.server},${pi},127.0.0.1
      occ richdocuments:activate-config || echo "Collabora ainda não respondeu; tenta de novo no próximo boot"

      # Whiteboard
      occ config:app:set whiteboard collabBackendUrl --value=${url "whiteboard"}
      occ config:app:set whiteboard jwt_secret_key --value="$(sed 's/^JWT_SECRET_KEY=//' ${secrets}/whiteboard.env)"

      # Talk: sinalização própria (o STUN padrão do Nextcloud continua)
      backend="$(cat ${secrets}/talk-backend-secret)"
      if ! occ talk:signaling:list --output=json | jq -e '.[] | select(.server == "${url "talk"}")' >/dev/null; then
        occ talk:signaling:add ${url "talk"} "$backend" --verify
      fi

      # Jogos do Switch como armazenamento externo (pasta local, no dataset tank/data)
      occ app:enable files_external
      if ! occ files_external:list --output=json | jq -e '.[] | select(.mount_point == "/Jogos do Switch")' >/dev/null; then
        id="$(occ files_external:create "/Jogos do Switch" local null::null -c datadir=${jogos} | grep -o '[0-9]*$')"
        occ files_external:applicable --add-group=admin "$id"
      fi
    '';
  };

  # Portas que o Pi (proxy) e os clientes das chamadas acessam
  networking.firewall = {
    allowedTCPPorts = [
      80 # Nextcloud
      9980 # Collabora
      3002 # Whiteboard
      8095 # sinalização do Talk
    ];
    allowedUDPPortRanges = [ rtpPorts ];
  };
}
