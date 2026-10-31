# Tema: adw-gtk3 com as cores do tema ativo, Kvantum Catppuccin no Qt, ícones
# Papirus (pastas mauve), cursor Catppuccin Mocha Mauve e JetBrainsMono Nerd Font.
# Substitui o nwg-look/qt6ct manuais, o papirus-folders e o gsettings do Sway.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cursor = "catppuccin-mocha-mauve-cursors";
  iconTheme = "Papirus-Dark";
  font = "JetBrainsMono Nerd Font";
  themeCss = config.dionix.render (builtins.readFile ./files/gtk/theme.css);

  kvantumTheme = "catppuccin-mocha-mauve";
  kvantum = pkgs.catppuccin-kvantum.override {
    variant = "mocha";
    accent = "mauve";
  };
in
{
  home.pointerCursor = {
    name = cursor;
    package = pkgs.catppuccin-cursors.mochaMauve;
    size = 24;
    gtk.enable = true;
    sway.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = iconTheme;
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "mauve";
      };
    };
    font = {
      name = font;
      size = 10;
    };
    gtk3 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = themeCss;
    };
    gtk4 = {
      theme = null;
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = themeCss;
    };
  };

  # Apps GTK4/libadwaita leem do gsettings (antes aplicado por exec_always no Sway)
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
    icon-theme = iconTheme;
    cursor-theme = cursor;
    cursor-size = 24;
    font-name = "${font} 10";
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };
  xdg.configFile = {
    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=${kvantumTheme}
    '';
    "Kvantum/${kvantumTheme}".source = "${kvantum}/share/Kvantum/${kvantumTheme}";
    "qt6ct/qt6ct.conf".text = ''
      [Appearance]
      style=kvantum
      icon_theme=${iconTheme}
      custom_palette=false
      standard_dialogs=default
    '';
  };

  home.packages = with pkgs; [
    nwg-look
    nwg-displays
  ];
}
