# Acompanha as atualizações do nixpkgs para o forge (Pi). Uma vez por dia o
# `update-watch --conferir` compara o canal nixos-26.05 com a `main`; havendo
# novidade, marca "pendente" e acorda o forge (host-wake), que compila e abre o
# PR. O estado fica em /var/lib/update-watch e é servido em
# https://pi.<domínio>/forge/ (files/update-watch.py):
#
#   GET  /forge/estado       estado para o widget do notebook (livre)
#   POST /forge/tentar       regrava "pendente" e acorda o forge (livre)
#   GET  /forge/pendente     só o forge: revisão a compilar (204 se não há)
#   POST /forge/{compilando,pronto,falhou}   só o forge
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dionix.homelab) forge;
  port = 8092;
  programa = pkgs.writers.writePython3Bin "update-watch" { flakeIgnore = [ "E501" ]; } (
    builtins.readFile ./files/update-watch.py
  );
  # O servidor e o timer dividem o mesmo usuário (e a pasta de estado)
  comum = {
    User = "update-watch";
    DynamicUser = true;
    StateDirectory = "update-watch";
  };
  upstream = "http://127.0.0.1:${toString port}";
in
{
  imports = [
    ./homelab.nix
    ./host-wake.nix
  ];

  systemd.services.update-watch = {
    description = "Estado das atualizações do nixpkgs";
    wantedBy = [ "multi-user.target" ];
    environment.PORT = toString port;
    serviceConfig = comum // {
      ExecStart = lib.getExe programa;
      Restart = "on-failure";
    };
  };

  systemd.services.update-watch-conferir = {
    description = "Confere se o canal do nixpkgs andou";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = comum // {
      Type = "oneshot";
      ExecStart = "${lib.getExe programa} --conferir";
    };
  };

  systemd.timers.update-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 10:00:00";
      Persistent = false;
      Unit = "update-watch-conferir.service";
    };
  };

  services.nginx.virtualHosts."pi.${config.dionix.homelab.domain}".locations = {
    # Só o forge escreve o andamento; leitura e "tentar" são livres
    "/forge/" = {
      proxyPass = upstream;
      extraConfig = ''
        allow ${forge};
        deny all;
      '';
    };
    "= /forge/estado".proxyPass = upstream;
    "= /forge/tentar".proxyPass = upstream;
  };
}
