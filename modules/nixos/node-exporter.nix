# Métricas do sistema (CPU, memória, disco, rede, serviços systemd) para o
# Prometheus do `server`. Porta 9100.
{ ... }:
{
  services.prometheus.exporters.node = {
    enable = true;
    openFirewall = true;
    enabledCollectors = [ "systemd" ];
  };
}
