# Roteador da tailnet: anuncia a rede de casa (subnet router) e, se quiser,
# serve de exit node. O tailscaled já vem do common.nix.
#
# Depois do primeiro boot:
#   sudo tailscale up
#   e aprove as rotas (e o exit node) no painel do Tailscale: Machines → pi → Edit route settings.
{ config, lib, ... }:
let
  cfg = config.dionix.tailscaleRouter;
in
{
  options.dionix.tailscaleRouter = {
    routes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "10.42.1.0/24" ];
      description = "Sub-redes locais anunciadas para a tailnet.";
    };
    exitNode = lib.mkEnableOption "o anúncio desta máquina como exit node";
  };

  config = {
    # Liga o encaminhamento de IP (IPv4 e IPv6) e ajusta o rp_filter
    services.tailscale = {
      useRoutingFeatures = "server";
      openFirewall = true;
      # Aplicado com `tailscale set` a cada boot, então vale mesmo sem auth key.
      # accept-dns=false: o Pi é o DNS da tailnet e não deve consultar a si mesmo pelo MagicDNS.
      extraSetFlags = [
        "--accept-dns=false"
        "--advertise-routes=${lib.concatStringsSep "," cfg.routes}"
        "--advertise-exit-node=${lib.boolToString cfg.exitNode}"
      ];
    };
  };
}
