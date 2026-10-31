# Lançador (Fuzzel), menu de atalhos (wlr-which-key, Super+x), menu de energia
# (wlogout) e notificações (swaync)
{ config, pkgs, ... }:
let
  yaml = pkgs.formats.yaml { };
in
{
  programs.fuzzel = {
    enable = true;
    settings = import ./settings/fuzzel.nix config.dionix.colors;
  };

  home.packages = [ pkgs.wlr-which-key ];
  xdg.configFile."wlr-which-key/config.yaml".source = yaml.generate "wlr-which-key.yaml" (
    import ./settings/wlr-which-key.nix config.dionix.colors
  );

  programs.wlogout = {
    enable = true;
    layout = import ./settings/wlogout.nix;
    style = config.dionix.render (builtins.readFile ./files/wlogout/style.css);
  };

  services.swaync = {
    enable = true;
    settings = import ./settings/swaync.nix;
    style = config.dionix.render (builtins.readFile ./files/swaync/style.css);
  };
}
