# Temas: o padrão fica na configuração base e os outros viram specialisations,
# prontas para o comando `theme` ativar sem rebuild.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  defaultTheme = "catppuccin-mocha";
  # Esquema base16 → tema equivalente do base46 (NvChad)
  themes = {
    catppuccin-mocha = "catppuccin";
    gruvbox-dark-medium = "gruvbox";
    nord = "nord";
    tokyo-night-dark = "tokyonight";
  };
  scheme = name: "${pkgs.base16-schemes}/share/themes/${name}.yaml";

  themeCommand = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv = {
      DIONIX_THEMES = lib.concatStringsSep " " (builtins.attrNames themes);
      DIONIX_DEFAULT_THEME = defaultTheme;
    };
    text = builtins.readFile ./files/theme/theme.sh;
  };
in
{
  home.packages = [ themeCommand ];

  # Só na base: as specialisations não têm specialisations e não reaplicam
  home.activation = lib.mkIf (config.specialisation != { }) {
    dionixReapplyTheme = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      run ${themeCommand}/bin/theme --reapply "$newGenPath"
    '';
  };

  stylix = {
    enable = true;
    # Só entram os alvos ligados um a um
    autoEnable = false;
    base16Scheme = scheme defaultTheme;
    targets.alacritty = {
      enable = true;
      # Fonte e opacidade continuam em settings/alacritty.nix
      fonts.enable = false;
      opacity.enable = false;
    };
  };

  dionix = {
    theme = defaultTheme;
    nvchadTheme = themes.${defaultTheme};
    colors = lib.genAttrs (map (n: "base0${n}") (lib.stringToCharacters "0123456789ABCDEF")) (
      name: config.lib.stylix.colors.withHashtag.${name}
    );
  };

  specialisation = lib.mapAttrs (name: nvchadTheme: {
    configuration = {
      stylix.base16Scheme = lib.mkForce (scheme name);
      dionix = {
        theme = lib.mkForce name;
        nvchadTheme = lib.mkForce nvchadTheme;
      };
    };
  }) (removeAttrs themes [ defaultTheme ]);
}
