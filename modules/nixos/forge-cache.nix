# Cache binário do forge (harmonia): serve o store para o notebook baixar o que
# o forge compilou, em vez de compilar de novo. O Pi publica em
# https://cache.<domínio> (hosts/pi) e responde 404 com o forge desligado.
#
# A chave de assinatura nasce no primeiro boot em /var/lib/secrets/cache-key;
# a pública (cache-key.pub) vai para `dionix.homelab.cachePublicKey`, que liga
# o substituter no notebook (modules/nixos/workstation.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  chave = "/var/lib/secrets/cache-key";
  porta = 5000;
in
{
  imports = [ ./homelab.nix ];

  systemd.services.forge-cache-chave = {
    description = "Gera a chave de assinatura do cache binário";
    wantedBy = [ "multi-user.target" ];
    before = [ "harmonia.service" ];
    requiredBy = [ "harmonia.service" ];
    unitConfig.ConditionPathExists = "!${chave}";
    path = [ config.nix.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      install -d -m 0711 /var/lib/secrets
      nix-store --generate-binary-cache-key forge-1 ${chave} ${chave}.pub
      chmod 0644 ${chave}.pub
    '';
  };

  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ chave ];
  };

  # Só o Pi (proxy do cache) chega à porta do harmonia
  networking.firewall = {
    extraCommands = "iptables -A nixos-fw -p tcp -s ${config.dionix.homelab.pi} --dport ${toString porta} -j nixos-fw-accept";
    extraStopCommands = "iptables -D nixos-fw -p tcp -s ${config.dionix.homelab.pi} --dport ${toString porta} -j nixos-fw-accept || true";
  };
}
