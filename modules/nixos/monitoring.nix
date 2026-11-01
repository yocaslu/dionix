# Prometheus + Grafana. Fica no server (o Prometheus grava o tempo todo, o que
# desgastaria o cartão SD do Pi); a página de status (Gatus) fica no Pi.
#
#   grafana.<domínio>  :3000   painéis; o Prometheus já vem como fonte de dados
#   Prometheus         :9090   só local (consultado pelo Grafana)
#
# Painel pronto para os hosts: Dashboards → New → Import → ID 1860 (Node Exporter Full).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dionix.homelab) domain pi;
  secrets = "/var/lib/secrets";
  node = host: "${host}:9100";
in
{
  imports = [
    ./homelab.nix
    ./node-exporter.nix
  ];

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    retentionTime = "90d";
    globalConfig.scrape_interval = "30s";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ (node "127.0.0.1") ];
            labels.host = "server";
          }
          {
            targets = [ (node pi) ];
            labels.host = "pi";
          }
        ];
      }
      {
        # Pool ZFS (estado, espaço, erros) e saúde dos discos (SMART)
        job_name = "discos";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}"
              "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}"
            ];
            labels.host = "server";
          }
        ];
      }
      {
        # Resultados das checagens da página de status (Gatus, no Pi)
        job_name = "gatus";
        scheme = "https";
        static_configs = [ { targets = [ "status.${domain}" ]; } ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "grafana.${domain}";
        root_url = "https://grafana.${domain}/";
      };
      security = {
        admin_user = "admin";
        admin_password = "$__file{${secrets}/grafana-admin-pass}";
        secret_key = "$__file{${secrets}/grafana-secret-key}";
        cookie_secure = true;
      };
      analytics.reporting_enabled = false;
      "auth.anonymous".enabled = false;
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
    };
  };

  # Senha do admin e chave de criptografia do Grafana (só no primeiro boot)
  systemd.services.grafana-secrets = {
    description = "Segredos do Grafana";
    wantedBy = [ "multi-user.target" ];
    before = [ "grafana.service" ];
    requiredBy = [ "grafana.service" ];
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      mkdir -p ${secrets}
      for f in grafana-admin-pass grafana-secret-key; do
        [ -s ${secrets}/$f ] || openssl rand -hex 16 > ${secrets}/$f
      done
      chown grafana:grafana ${secrets}/grafana-admin-pass ${secrets}/grafana-secret-key
    '';
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];
}
