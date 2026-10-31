# Waybar: barra inferior no visual TUI, com gaveta "sys «", cava, atualizações e clima
{ lib, pkgs, ... }:
let
  # Scripts da barra empacotados com as dependências no PATH
  script =
    name: deps:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = deps;
      text = builtins.readFile ./files/waybar/scripts/${name}.sh;
      bashOptions = [ ];
    };

  cavaScript = script "cava" (
    with pkgs;
    [
      cava
      gnused
      coreutils
    ]
  );
  weatherScript = script "weather" (
    with pkgs;
    [
      curl
      coreutils
    ]
  );
  # O `nh` vem do sistema (programs.nh); jq e git são as dependências da contagem
  updatesScript = script "updates" (
    with pkgs;
    [
      jq
      git
      coreutils
      procps
    ]
  );

  base = import ./settings/waybar.nix;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ./files/waybar/style.css;
    settings.main = lib.recursiveUpdate base {
      # Visualizador de áudio; some quando não há som
      "custom/cava".exec = lib.getExe cavaScript;
      # Atualizações: compara o nixpkgs do flake.lock com o canal (antes pacman + AUR)
      "custom/updates" = {
        exec = lib.getExe updatesScript;
        on-click = "alacritty -e ${lib.getExe updatesScript} --upgrade";
      };
      # Clima via wttr.in (local pelo IP, ou ~/.config/waybar/weather-location)
      "custom/weather" = {
        exec = lib.getExe weatherScript;
        on-click = "alacritty --hold -e ${lib.getExe weatherScript} --full";
      };
    };
  };

  home.packages = with pkgs; [
    pavucontrol
    networkmanagerapplet # nm-connection-editor (botão direito em "net")
  ];
}
