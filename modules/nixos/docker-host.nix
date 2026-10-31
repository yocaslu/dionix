# Servidores do homelab que rodam containers Docker.
#
# Duas formas de manter os containers:
#   1. docker compose como hoje: copie os docker-compose.yml para o servidor e
#      rode `docker compose up -d`. O NixOS só cuida do sistema.
#   2. Declarados no Nix (virtualisation.oci-containers, exemplo abaixo): cada
#      container vira um serviço systemd. O `compose2nix` converte os
#      docker-compose.yml existentes para esse formato.
{ pkgs, username, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  # O grupo docker equivale a root; mantido para usar o docker sem sudo
  users.users.${username}.extraGroups = [ "docker" ];

  virtualisation.oci-containers.backend = "docker";
  # Exemplo (descomente e ajuste):
  # virtualisation.oci-containers.containers.jellyfin = {
  #   image = "jellyfin/jellyfin:latest";
  #   ports = [ "8096:8096" ];
  #   volumes = [
  #     "/srv/jellyfin/config:/config"
  #     "/srv/media:/media:ro"
  #   ];
  # };

  # Abra aqui as portas dos serviços expostos (o SSH já é liberado pelo openssh)
  networking.firewall.allowedTCPPorts = [ ];

  environment.systemPackages = with pkgs; [
    docker-compose
    compose2nix
    lazydocker
  ];
}
