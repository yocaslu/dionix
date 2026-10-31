# Proxy reverso com Nginx: cada entrada de `dionix.proxy.hosts` vira
# <nome>.<domínio> apontando para um serviço do homelab.
#
# Para os nomes resolverem, crie no Technitium uma zona do domínio com um
# registro curinga `*` (A) apontando para o IP do Pi (o da LAN e, se quiser
# usar pela tailnet sem a rota da LAN, o 100.x do Tailscale).
#
# HTTPS (opcional): com um domínio seu, ative `acme` para emitir um certificado
# curinga pelo desafio DNS-01 (funciona sem abrir portas para a internet).
# O token do provedor fica fora do repositório, no `environmentFile`.
{ config, lib, ... }:
let
  cfg = config.dionix.proxy;
  tls = cfg.acme.enable;
in
{
  options.dionix.proxy = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "home.arpa";
      description = "Domínio dos serviços (home.arpa é reservado para redes domésticas e só serve sem HTTPS).";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        dns = "http://127.0.0.1:5380";
      };
      description = "Subdomínio → endereço do serviço (http:// ou https://).";
    };

    acme = {
      enable = lib.mkEnableOption "certificado curinga Let's Encrypt via DNS-01";
      email = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "E-mail da conta ACME (avisos de expiração).";
      };
      dnsProvider = lib.mkOption {
        type = lib.types.str;
        default = "cloudflare";
        description = "Provedor do lego (https://go-acme.github.io/lego/dns/).";
      };
      environmentFile = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/secrets/acme.env";
        description = "Arquivo com as credenciais do provedor (ex.: CF_DNS_API_TOKEN=...), criado à mão no Pi.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !tls || cfg.domain != "home.arpa";
        message = "dionix.proxy.acme precisa de um domínio seu em dionix.proxy.domain.";
      }
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;

      virtualHosts = {
        # Nomes desconhecidos são recusados (fecha a conexão sem resposta)
        "_" = {
          default = true;
          rejectSSL = tls;
          locations."/".return = "444";
        };
      }
      // lib.mapAttrs' (
        name: upstream:
        lib.nameValuePair "${name}.${cfg.domain}" (
          {
            locations."/" = {
              proxyPass = upstream;
              proxyWebsockets = true;
            };
          }
          // lib.optionalAttrs tls {
            forceSSL = true;
            useACMEHost = cfg.domain;
          }
        )
      ) cfg.hosts;
    };

    security.acme = lib.mkIf tls {
      acceptTerms = true;
      defaults.email = cfg.acme.email;
      certs.${cfg.domain} = {
        extraDomainNames = [ "*.${cfg.domain}" ];
        inherit (cfg.acme) dnsProvider environmentFile;
        group = config.services.nginx.group;
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 ] ++ lib.optional tls 443;
  };
}
