# Proxy reverso com Nginx: cada entrada de `dionix.proxy.hosts` vira
# <nome>.<domínio> apontando para um serviço do homelab. A entrada pode ser só
# o endereço ("http://10.42.1.20:8080") ou um attrset com rotas extras.
#
# Para os nomes resolverem dentro de casa, crie no Technitium a zona do domínio
# com um registro curinga `*` (A) apontando para o IP do Pi (DNS split-horizon:
# de fora continua valendo o DNS público da Cloudflare).
#
# HTTPS: certificado curinga Let's Encrypt pelo desafio DNS-01, que funciona
# sem abrir portas para a internet. O token do provedor fica fora do
# repositório, no `environmentFile` (ex.: CF_DNS_API_TOKEN=...).
{ config, lib, ... }:
let
  cfg = config.dionix.proxy;
  tls = cfg.acme.enable;

  hostType = lib.types.submodule {
    options = {
      upstream = lib.mkOption {
        type = lib.types.str;
        description = "Endereço do serviço (http:// ou https://).";
      };
      locations = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          "^~ /cool/" = "http://10.42.1.30:9980";
        };
        description = "Caminhos que vão para outro serviço (prefixo do Nginx → endereço). Todos com websocket.";
      };
      largeUploads = lib.mkEnableOption "uploads grandes e conexões longas (Nextcloud e afins)";
      hsts = lib.mkEnableOption "o cabeçalho HSTS (só com HTTPS)";
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Diretivas extras do server {} do Nginx.";
      };
    };
  };

  # Upload sem buffer e sem limite de tempo (equivale ao file-upload.conf antigo)
  uploadConfig = ''
    client_max_body_size 0;
    client_body_timeout 300s;
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
  '';

  mkVhost =
    name: h:
    lib.nameValuePair "${name}.${cfg.domain}" (
      {
        locations = {
          "/" = {
            proxyPass = h.upstream;
            proxyWebsockets = true;
          };
        }
        // lib.mapAttrs (_: upstream: {
          proxyPass = upstream;
          proxyWebsockets = true;
          extraConfig = "proxy_read_timeout 36000s;";
        }) h.locations;
        extraConfig = lib.concatStrings [
          (lib.optionalString h.largeUploads uploadConfig)
          (lib.optionalString (tls && h.hsts) ''
            add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
          '')
          h.extraConfig
        ];
      }
      // lib.optionalAttrs tls {
        forceSSL = true;
        useACMEHost = cfg.domain;
      }
    );
in
{
  options.dionix.proxy = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "home.arpa";
      description = "Domínio dos serviços (home.arpa é reservado para redes domésticas e só serve sem HTTPS).";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.coercedTo lib.types.str (upstream: { inherit upstream; }) hostType
      );
      default = { };
      example = {
        dns = "http://127.0.0.1:5380";
      };
      description = "Subdomínio → serviço.";
    };

    acme = {
      enable = lib.mkEnableOption "certificado curinga Let's Encrypt via DNS-01";
      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "E-mail da conta ACME (opcional, para avisos de expiração).";
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
      // lib.mapAttrs' mkVhost cfg.hosts;
    };

    security.acme = lib.mkIf tls {
      acceptTerms = true;
      defaults.email = cfg.acme.email;
      certs.${cfg.domain} = {
        extraDomainNames = [ "*.${cfg.domain}" ];
        inherit (cfg.acme) dnsProvider environmentFile;
        # Consulta um DNS público: o Technitium responde a zona interna (split-horizon)
        # e esconderia o registro TXT do desafio
        dnsResolver = "1.1.1.1:53";
        group = config.services.nginx.group;
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 ] ++ lib.optional tls 443;
  };
}
