# Suspende o server (S3) quando ninguém usa os serviços; o Pi o acorda por
# Wake-on-LAN no próximo acesso (server-wake.nix).
#
# A cada 5 minutos o `server-sleep` confere, e só suspende se tudo passar:
#   - pelo menos 15 min desde o boot ou desde a última volta da suspensão
#   - Wake-on-LAN armado na placa de rede (sem ele a máquina não volta sozinha)
#   - nenhum acesso real pelo proxy do Pi há `idleMinutes` (data vinda do Pi)
#   - nenhuma conexão de fora aberta nos serviços: vídeo no Jellyfin, apps com
#     websocket (Nextcloud, Talk), SSH, FTP do Switch. Portas em `ignoredPorts`
#     não contam (o Prometheus é consultado pela página inicial do Pi)
#   - nenhuma unidade de `blockers` rodando, nenhum scrub ou resilver do ZFS e
#     nenhuma trava de suspensão (systemd-inhibit)
# Backup, dump do banco e scrub acordam a máquina no horário (WakeSystem).
# O motivo de cada decisão fica em `journalctl -u server-sleep`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dionix.serverSleep;
  sono = "https://pi.${config.dionix.homelab.domain}/sono";

  verificar = pkgs.writeShellApplication {
    name = "server-sleep";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      ethtool
      gawk
      gnugrep
      iproute2
      systemd
      config.boot.zfs.package
    ];
    text = ''
      agora=$(date +%s)

      boot=$(( agora - $(cut -d. -f1 /proc/uptime) ))
      volta=$(cat /run/server-sleep/volta 2>/dev/null || echo 0)
      acordado=$(( agora - (boot > volta ? boot : volta) ))
      if (( acordado < 15 * 60 )); then
        echo "acordado há $(( acordado / 60 )) min: espera"
        exit 0
      fi

      iface=$(ip -o route show default | awk '{ print $5; exit }')
      if ! ethtool "$iface" | grep -Eq '^\s+Wake-on: \S*g'; then
        echo "Wake-on-LAN desarmado em $iface: não suspende"
        exit 0
      fi

      if ! uso=$(curl -sf --max-time 10 "${sono}/uso"); then
        echo "o Pi não respondeu: não suspende"
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
      if zpool status | grep -Eq '(scrub|resilver) in progress'; then
        echo "ZFS em scrub ou resilver"
        exit 0
      fi
      if systemd-inhibit --list --no-legend | awk '$NF == "block" && /sleep/' | grep -q .; then
        echo "trava de suspensão ativa"
        exit 0
      fi

      echo "sem uso há $(( ocioso / 60 )) min: suspendendo"
      curl -sf --max-time 10 -X POST "${sono}/dormindo" >/dev/null || true
      systemctl suspend
    '';
  };
in
{
  options.dionix.serverSleep = {
    enable = lib.mkEnableOption "a suspensão automática do server quando ninguém o usa";
    idleMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 45;
      description = "Minutos sem acesso real pelo proxy do Pi antes de suspender.";
    };
    ignoredPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 9090 ];
      description = "Portas cujas conexões não impedem a suspensão.";
    };
    blockers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "restic-backups-gdrive.service" ];
      description = "Unidades que impedem a suspensão enquanto rodam.";
    };
    wakeTimers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "restic-backups-gdrive" ];
      description = "Timers que acordam a máquina no horário (WakeSystem=true).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.server-sleep = {
      description = "Suspende o server quando ninguém o usa";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe verificar;
      };
    };
    systemd.timers = {
      server-sleep = {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = "*:0/5";
      };
    }
    // lib.genAttrs cfg.wakeTimers (_: {
      timerConfig.WakeSystem = true;
    });

    # Ao voltar (e no boot): marca a hora, para a carência de 15 min, e avisa o
    # Pi que a máquina não está mais dormindo. O suspend.target só é alcançado
    # depois que a máquina acorda, então `After` faz o serviço rodar na volta
    systemd.tmpfiles.rules = [ "d /run/server-sleep 0755 root root -" ];
    systemd.services.server-sleep-volta = {
      description = "Marca a volta do server";
      wantedBy = [
        "suspend.target"
        "multi-user.target"
      ];
      after = [
        "suspend.target"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      path = with pkgs; [
        coreutils
        curl
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        date +%s > /run/server-sleep/volta
        curl -sf --max-time 10 --retry 10 --retry-all-errors --retry-delay 3 \
          -X POST "${sono}/acordado" >/dev/null || echo "o Pi não respondeu"
      '';
    };
  };
}
