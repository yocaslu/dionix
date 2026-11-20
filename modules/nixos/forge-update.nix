# Atualizações no forge: quando o Pi (update-watch) diz que há build pendente e
# é dia (8h-22h), compila o flake.lock novo de todos os hosts, abre ou atualiza
# o PR no GitHub e avisa o Pi. Também aplica a `main` no próprio forge
# (`nixos-rebuild boot`). Roda ao ligar e a cada 15 min; enquanto roda, segura
# o sono (dionix.sleep.blockers, em forge.nix). Token do GitHub em
# /var/lib/secrets/github-token, criado à mão.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  tokenFile = "/var/lib/secrets/github-token";
  programa = pkgs.writeShellApplication {
    name = "forge-update";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gh
      git
      jq
      config.nix.package
      nixos-rebuild
      nvd
    ];
    text = builtins.readFile ./files/forge-update.sh;
  };
in
{
  imports = [ ./homelab.nix ];

  systemd.services.forge-update = {
    description = "Compila as atualizações, abre o PR e aplica a main no forge";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      PI_URL = "https://pi.${config.dionix.homelab.domain}";
      REPO = "https://github.com/yocaslu/dionix.git";
      TOKEN_FILE = tokenFile;
      WORKDIR = "/var/lib/forge-update";
      HOSTS = "notebook forge server pi";
      JANELA = "8-22";
      HOME = "/root";
    };
    serviceConfig = {
      Type = "oneshot";
      # Root: o nixos-rebuild boot e as raízes de GC em /nix/var/nix/gcroots
      ExecStart = lib.getExe programa;
      StateDirectory = "forge-update";
      PrivateTmp = true;
    };
  };

  systemd.timers.forge-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "15min";
    };
  };
}
