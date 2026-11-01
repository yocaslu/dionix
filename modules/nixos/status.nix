# Página de status (Gatus) em status.<domínio>. Fica no Pi para continuar
# avisando mesmo com o server fora do ar. Não grava nada no disco (histórico em
# memória) e expõe /metrics para o Prometheus do server.
#
# Cada serviço do proxy (dionix.proxy.hosts) vira uma checagem HTTPS, feita
# pelo próprio Nginx do Pi e resolvida pelo Technitium local.
{ config, lib, ... }:
let
  domain = config.dionix.proxy.domain;
  port = 8085;
  local = {
    dns-resolver = "udp://127.0.0.1:53";
  };

  servico = name: _: {
    inherit name;
    group = "Serviços";
    url = "https://${name}.${domain}";
    interval = "1m";
    client = local;
    # 401 conta como no ar (serviços com login no proxy, como o NUT)
    conditions = [ "[STATUS] < 500" ];
  };

  porta = name: endpoint: {
    inherit name;
    group = "Servidores";
    url = "tcp://${endpoint}";
    interval = "1m";
    conditions = [ "[CONNECTED] == true" ];
  };
in
{
  services.gatus = {
    enable = true;
    settings = {
      web = {
        address = "127.0.0.1";
        inherit port;
      };
      metrics = true;
      ui = {
        title = "Status do homelab";
        header = "vault76";
      };
      endpoints =
        lib.mapAttrsToList servico (lib.filterAttrs (name: _: name != "status") config.dionix.proxy.hosts)
        ++ [
          (porta "server (SSH)" "${config.dionix.homelab.server}:22")
          (porta "server (FTP do Switch)" "${config.dionix.homelab.server}:21")
          {
            name = "DNS (Technitium)";
            group = "Servidores";
            url = "127.0.0.1";
            dns = {
              query-name = "nextcloud.${domain}";
              query-type = "A";
            };
            interval = "1m";
            conditions = [ "[DNS_RCODE] == NOERROR" ];
          }
        ];
    };
  };

  dionix.proxy.hosts.status = "http://127.0.0.1:${toString port}";
}
