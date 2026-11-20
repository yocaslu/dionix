# Faz o host dormir quando ninguém usa os serviços; o Pi o acorda por
# Wake-on-LAN no próximo acesso (host-wake.nix). `mode` escolhe como dorme:
#   - "suspend": suspende (S3), como o server; timers com WakeSystem acordam
#   - "poweroff": desliga (S5), para placas sem S3 (forge); só o Wake-on-LAN
#     liga de volta, então `wakeTimers` não é aceito
#
# A cada 5 minutos o `host-sleep` confere, e só dorme se tudo passar:
#   - pelo menos 15 min desde o boot ou desde a última volta da suspensão
#   - Wake-on-LAN armado na placa de rede (sem ele a máquina não volta sozinha)
#   - nenhum acesso real pelo proxy do Pi há `idleMinutes` (data vinda do Pi)
#   - nenhuma conexão de fora aberta nos serviços: vídeo no Jellyfin, apps com
#     websocket (Nextcloud, Talk), SSH, FTP do Switch. Portas em `ignoredPorts`
#     não contam (o Prometheus é consultado pela página inicial do Pi)
#   - nenhuma unidade de `blockers` rodando, nenhum build do nix-daemon em
#     andamento, nenhum scrub ou resilver do ZFS (se o host usa ZFS) e
#     nenhuma trava de suspensão ou desligamento (systemd-inhibit)
# Backup, dump do banco e scrub acordam a máquina no horário (WakeSystem).
# O motivo de cada decisão fica em `journalctl -u host-sleep`.
{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dionix.sleep;
  sono = "https://pi.${config.dionix.homelab.domain}/sono/${hostname}";
  suspende = cfg.mode == "suspend";
  # Só confere o ZFS nos hosts que o usam (o zpool nem existe nos outros)
  zfs = config.boot.zfs.enabled;

  verificar = pkgs.writeShellApplication {
    name = "host-sleep";
    runtimeInputs =
      with pkgs;
      [
        coreutils
        curl
        ethtool
        gawk
        gnugrep
        iproute2
        procps
        systemd
      ]
      ++ lib.optional zfs config.boot.zfs.package;
    text = ''
      agora=$(date +%s)

      boot=$(( agora - $(cut -d. -f1 /proc/uptime) ))
      volta=$(cat /run/host-sleep/volta 2>/dev/null || echo 0)
      acordado=$(( agora - (boot > volta ? boot : volta) ))
      if (( acordado < 15 * 60 )); then
        echo "acordado há $(( acordado / 60 )) min: espera"
        exit 0
      fi

      iface=$(ip -o route show default | awk '{ print $5; exit }')
      if ! ethtool "$iface" | grep -Eq '^\s+Wake-on: \S*g'; then
        echo "Wake-on-LAN desarmado em $iface: não ${if suspende then "suspende" else "desliga"}"
        exit 0
      fi

      if ! uso=$(curl -sf --max-time 10 "${sono}/uso"); then
        echo "o Pi não respondeu: não ${if suspende then "suspende" else "desliga"}"
        exit 0
      fi
      ocioso=$(( agora - uso ))
      if (( ocioso < ${toString cfg.idleMinutes} * 60 )); then
        echo "último acesso há $(( ocioso / 60 )) min"
        exit 0
      fi

      # Conexões de fora que chegam numa porta de serviço deste host
      portas=$(ss -Htln | awk '{ n = split($4, p, ":"); print p[n] }' | sort -u |
        grep -vxF -f <(printf '%s\n' ${lib.concatMapStringsSep " " toString cfg.ignoredPorts}) || true)
      conexoes=$(ss -Htn state established | awk -v portas="$portas" '
        BEGIN { n = split(portas, p, "\n"); for (i = 1; i <= n; i++) ouvindo[p[i]] = 1 }
        {
          n = split($3, l, ":")
          if (!(l[n] in ouvindo)) next
          if ($4 ~ /^(127\.|\[::1\]|\[::ffff:127\.)/) next
          print $4 " → :" l[n]
        }')
      if [ -n "$conexoes" ]; then
        echo "conexões abertas: $(tr '\n' ' ' <<< "$conexoes")"
        exit 0
      fi

      for unidade in ${lib.escapeShellArgs cfg.blockers}; do
        if systemctl is-active -q "$unidade"; then
          echo "$unidade rodando"
          exit 0
        fi
      done
      # Build do nix-daemon em andamento: o builder roda como um usuário do
      # grupo nixbld, que o daemon ocioso (root) não tem. Cobre builds locais,
      # inclusive os de `nixos-rebuild` e de outras máquinas (builder remoto)
      if pgrep -G nixbld >/dev/null; then
        echo "build do nix em andamento"
        exit 0
      fi
      ${lib.optionalString zfs ''
        if zpool status | grep -Eq '(scrub|resilver) in progress'; then
          echo "ZFS em scrub ou resilver"
          exit 0
        fi
      ''}if systemd-inhibit --list --no-legend | awk '$NF == "block" && /${
        if suspende then "sleep" else "shutdown"
      }/' | grep -q .; then
        echo "trava de ${if suspende then "suspensão" else "desligamento"} ativa"
        exit 0
      fi

      echo "sem uso há $(( ocioso / 60 )) min: ${if suspende then "suspendendo" else "desligando"}"
      curl -sf --max-time 10 -X POST "${sono}/dormindo" >/dev/null || true
      systemctl ${if suspende then "suspend" else "poweroff"}
    '';
  };
in
{
  options.dionix.sleep = {
    enable = lib.mkEnableOption "o sono automático do host quando ninguém o usa";
    mode = lib.mkOption {
      type = lib.types.enum [
        "suspend"
        "poweroff"
      ];
      default = "suspend";
      description = "Como o host dorme: suspende (S3) ou desliga (S5, para placas sem S3).";
    };
    idleMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 45;
      description = "Minutos sem acesso real pelo proxy do Pi antes de dormir.";
    };
    ignoredPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Portas cujas conexões não impedem o sono.";
    };
    blockers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "restic-backups-gdrive.service" ];
      description = "Unidades que impedem o sono enquanto rodam.";
    };
    wakeTimers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "restic-backups-gdrive" ];
      description = "Timers que acordam a máquina no horário (WakeSystem=true).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mode != "poweroff" || cfg.wakeTimers == [ ];
        message = "dionix.sleep.wakeTimers não funciona com mode = \"poweroff\": máquina desligada só volta por Wake-on-LAN.";
      }
    ];

    systemd.services.host-sleep = {
      description = "Põe o host para dormir quando ninguém o usa";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe verificar;
      };
    };
    systemd.timers = {
      host-sleep = {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = "*:0/5";
      };
    }
    // lib.genAttrs cfg.wakeTimers (_: {
      timerConfig.WakeSystem = true;
    });

    # Ao voltar (e no boot): marca a hora, para a carência de 15 min, e avisa o
    # Pi que a máquina não está mais dormindo. O suspend.target só é alcançado
    # depois que a máquina acorda, então `After` faz o serviço rodar na volta.
    # Ao desligar não há volta de suspensão: só o boot conta
    systemd.tmpfiles.rules = [ "d /run/host-sleep 0755 root root -" ];
    systemd.services.host-sleep-volta = {
      description = "Marca a volta do host";
      wantedBy = lib.optional suspende "suspend.target" ++ [ "multi-user.target" ];
      after = lib.optional suspende "suspend.target" ++ [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [
        coreutils
        curl
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        date +%s > /run/host-sleep/volta
        curl -sf --max-time 10 --retry 10 --retry-all-errors --retry-delay 3 \
          -X POST "${sono}/acordado" >/dev/null || echo "o Pi não respondeu"
      '';
    };
  };
}
