# Acorda hosts (server, forge) por Wake-on-LAN quando alguém acessa um serviço
# deles pelo proxy. Com o host desligado ou suspenso, o Nginx não conecta
# (502/504) e o pedido vai para o `host-wake` (files/host-wake.py), que manda o
# pacote mágico e responde com "Aguarde: o servidor está ligando"; a página
# recarrega até o serviço voltar. Apps de sincronização recebem 503 com
# Retry-After.
#
# Pedidos do próprio Pi (Gatus, página inicial) não acordam a máquina: enquanto
# ela dorme de propósito, recebem 200 "dormindo". Os acessos reais aos
# serviços de cada host ficam em uso-<host>.log, cuja data o host consulta para
# decidir quando dormir (host-sleep):
#
#   https://pi.<domínio>/sono/<host>/uso        último acesso real (epoch)
#   https://pi.<domínio>/sono/<host>/dormindo   POST do host antes de dormir
#   https://pi.<domínio>/sono/<host>/acordado   POST do host ao voltar
#   https://home.<domínio>/acordar[/<host>]     acorda à mão (SSH, FTP do Switch)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dionix.homelab) domain pi;
  cfg = config.dionix.wake;
  port = 8090;
  logDir = "/var/log/nginx";
  # A rede de casa é /24: o pacote mágico vai para o broadcast dela
  broadcast = lib.concatStringsSep "." (lib.take 3 (lib.splitString "." pi) ++ [ "255" ]);
  acordar = "http://127.0.0.1:${toString port}";

  # Serviços do proxy que ficam em cada host (menos os ignorados)
  doHost =
    h:
    lib.filterAttrs (
      name: p: !(lib.elem name cfg.ignore) && lib.hasPrefix "http://${h.ip}:" p.upstream
    ) config.dionix.proxy.hosts;

  vhost = host: name: _: {
    name = "${name}.${domain}";
    value = {
      # Com o host fora do ar a conexão falha em segundos (sem resposta ao ARP)
      extraConfig = ''
        proxy_connect_timeout 5s;
        error_page 502 504 = @acordar;
        access_log /var/log/nginx/access.log;
        access_log ${logDir}/uso-${host}.log combined if=$dionix_uso;
      '';
      locations."@acordar" = {
        proxyPass = acordar;
        extraConfig = ''
          proxy_set_header X-Dionix-Uso $dionix_uso;
          proxy_set_header X-Dionix-Host ${host};
        '';
      };
    };
  };
in
{
  imports = [ ./homelab.nix ];

  options.dionix.wake = {
    hosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            ip = lib.mkOption {
              type = lib.types.str;
              description = "IP do host na rede de casa.";
            };
            mac = lib.mkOption {
              type = lib.types.str;
              description = "MAC da rede do host, para o Wake-on-LAN.";
            };
          };
        }
      );
      default = { };
      description = "Hosts que o Pi acorda por Wake-on-LAN.";
    };
    ignore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Nomes de `dionix.proxy.hosts` que não recebem o tratamento de acordar.";
    };
  };

  config = {
    systemd.services.host-wake = {
      description = "Acorda hosts por Wake-on-LAN";
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOSTS = builtins.toJSON cfg.hosts;
        BROADCAST = broadcast;
        LOG_DIR = logDir;
        PORT = toString port;
      };
      serviceConfig = {
        ExecStart = lib.getExe (
          pkgs.writers.writePython3Bin "host-wake" { } (builtins.readFile ./files/host-wake.py)
        );
        DynamicUser = true;
        # Lê a data dos uso-<host>.log (a pasta é do grupo nginx)
        SupplementaryGroups = [ config.services.nginx.group ];
        StateDirectory = "host-wake";
        Restart = "on-failure";
      };
    };

    services.nginx = {
      # Acesso real = qualquer origem que não seja o próprio Pi
      appendHttpConfig = ''
        map $remote_addr $dionix_uso {
          default 1;
          127.0.0.1 0;
          ::1 0;
          ${pi} 0;
        }
      '';

      virtualHosts = lib.concatMapAttrs (host: h: lib.mapAttrs' (vhost host) (doHost h)) cfg.hosts // {
        # Só cada host fala com o /sono/<host>/ dele
        "pi.${domain}" = {
          forceSSL = true;
          useACMEHost = domain;
          locations =
            lib.mapAttrs' (
              host: h:
              lib.nameValuePair "/sono/${host}/" {
                proxyPass = acordar;
                extraConfig = ''
                  allow ${h.ip};
                  deny all;
                '';
              }
            ) cfg.hosts
            // {
              "/".return = "404";
            };
        };
        "home.${domain}".locations =
          lib.mapAttrs' (
            host: _:
            lib.nameValuePair "= /acordar/${host}" {
              proxyPass = acordar;
              extraConfig = "proxy_set_header X-Dionix-Uso 1;";
            }
          ) cfg.hosts
          // {
            # Compatível: sem host, acorda o server
            "= /acordar" = {
              proxyPass = acordar;
              extraConfig = "proxy_set_header X-Dionix-Uso 1;";
            };
          };
      };
    };
  };
}
