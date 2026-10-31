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
in
{
  stylix = {
    enable = true;
    # Só entram os alvos ligados um a um
    autoEnable = false;
    base16Scheme = scheme defaultTheme;
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
