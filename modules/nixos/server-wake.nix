# Acorda o server por Wake-on-LAN quando alguém acessa um serviço dele pelo
# proxy. Com o server suspenso, o Nginx não conecta (502/504) e o pedido vai
# para o `server-wake` (files/server-wake.py), que manda o pacote mágico e
# responde com "Aguarde: o servidor está ligando"; a página recarrega até o
# serviço voltar. Apps de sincronização recebem 503 com Retry-After.
#
# Pedidos do próprio Pi (Gatus, página inicial) não acordam a máquina: enquanto
# ela dorme de propósito, recebem 200 "dormindo". Os acessos reais aos
# serviços do server ficam em uso-server.log, cuja data o server consulta para
# decidir quando suspender (server-sleep.nix):
#
#   https://pi.<domínio>/sono/uso        último acesso real (epoch)
#   https://pi.<domínio>/sono/dormindo   POST do server antes de suspender
#   https://pi.<domínio>/sono/acordado   POST do server ao voltar
#   https://home.<domínio>/acordar       acorda à mão (SSH, FTP do Switch)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dionix.homelab)
    domain
    pi
    server
    serverMac
    ;
  port = 8090;
  log = "/var/log/nginx/uso-server.log";
  # A rede de casa é /24: o pacote mágico vai para o broadcast dela
  broadcast = lib.concatStringsSep "." (lib.take 3 (lib.splitString "." server) ++ [ "255" ]);
  acordar = "http://127.0.0.1:${toString port}";

  # Serviços do proxy que ficam no server
  doServer = lib.filterAttrs (
    _: h: lib.hasPrefix "http://${server}:" h.upstream
  ) config.dionix.proxy.hosts;

  vhost = name: _: {
    name = "${name}.${domain}";
    value = {
      # Com o server suspenso a conexão falha em segundos (sem resposta ao ARP)
      extraConfig = ''
        proxy_connect_timeout 5s;
        error_page 502 504 = @acordar;
        access_log /var/log/nginx/access.log;
        access_log ${log} combined if=$dionix_uso_server;
      '';
      locations."@acordar" = {
        proxyPass = acordar;
        extraConfig = "proxy_set_header X-Dionix-Uso $dionix_uso_server;";
      };
    };
  };
in
{
  imports = [ ./homelab.nix ];

  systemd.services.server-wake = {
    description = "Acorda o server por Wake-on-LAN";
    wantedBy = [ "multi-user.target" ];
    environment = {
      MAC = serverMac;
      BROADCAST = broadcast;
      SERVER = server;
      LOG = log;
      PORT = toString port;
    };
    serviceConfig = {
      ExecStart = lib.getExe (
        pkgs.writers.writePython3Bin "server-wake" { } (builtins.readFile ./files/server-wake.py)
      );
      DynamicUser = true;
      # Lê a data do uso-server.log (a pasta é do grupo nginx)
      SupplementaryGroups = [ config.services.nginx.group ];
      StateDirectory = "server-wake";
      Restart = "on-failure";
    };
  };

  services.nginx = {
    # Acesso real = qualquer origem que não seja o próprio Pi
    appendHttpConfig = ''
      map $remote_addr $dionix_uso_server {
        default 1;
        127.0.0.1 0;
        ::1 0;
        ${pi} 0;
      }
    '';

    virtualHosts = lib.mapAttrs' vhost doServer // {
      # Só o server fala com o /sono/
      "pi.${domain}" = {
        forceSSL = true;
        useACMEHost = domain;
        locations."/sono/" = {
          proxyPass = acordar;
          extraConfig = ''
            allow ${server};
            deny all;
          '';
        };
        locations."/".return = "404";
      };
      "home.${domain}".locations."= /acordar" = {
        proxyPass = acordar;
        extraConfig = "proxy_set_header X-Dionix-Uso 1;";
      };
    };
  };
}
