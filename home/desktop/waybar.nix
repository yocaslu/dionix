# Waybar: barra inferior no visual TUI, com gaveta "sys «", atualizações e clima
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # Scripts da barra empacotados com as dependências no PATH
  script =
    name: deps:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = deps;
      runtimeEnv = {
        DIONIX_DOMAIN = osConfig.dionix.homelab.domain;
      };
      text = builtins.readFile ./files/waybar/scripts/${name}.sh;
      bashOptions = [ ];
    };

  weatherScript = script "weather" (
    with pkgs;
    [
      curl
      coreutils
    ]
  );
  # O `nh` vem do sistema (programs.nh); o `gh` é o do próprio usuário
  forgeUpdateScript = script "forge-update" (
    with pkgs;
    [
      curl
      jq
      gh
      git
      coreutils
      procps
    ]
  );

  base = import ./settings/waybar.nix config.dionix.colors;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = config.dionix.render (builtins.readFile ./files/waybar/style.css);
    settings.main = lib.recursiveUpdate base {
      # Atualizações compiladas pelo forge: avisa, mescla o PR e aplica
      "custom/updates" = {
        exec = lib.getExe forgeUpdateScript;
        on-click = "alacritty -e ${lib.getExe forgeUpdateScript} --aplicar";
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
