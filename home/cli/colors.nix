# Paleta lida pelas configs. O padrão é o Catppuccin Mocha, usado no servidor, que
# não tem Stylix; em notebook e desktop, home/desktop/themes.nix preenche com o Stylix.
{
  config,
  lib,
  ...
}:
let
  # "#rrggbb" para "r, g, b"
  rgb =
    hex:
    lib.concatMapStringsSep ", " (start: toString (lib.fromHexString (builtins.substring start 2 hex)))
      [
        1
        3
        5
      ];
  colors = config.dionix.colors;
  names = builtins.attrNames colors;
in
{
  options.dionix = {
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Paleta base16, de base00 a base0F, no formato #rrggbb.";
      default = {
        base00 = "#1e1e2e";
        base01 = "#313244";
        base02 = "#45475a";
        base03 = "#6c7086";
        base04 = "#a6adc8";
        base05 = "#cdd6f4";
        base06 = "#f5e0dc";
        base07 = "#b4befe";
        base08 = "#f38ba8";
        base09 = "#fab387";
        base0A = "#f9e2af";
        base0B = "#a6e3a1";
        base0C = "#94e2d5";
        base0D = "#89b4fa";
        base0E = "#cba6f7";
        base0F = "#f2cdcd";
      };
    };
    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Nome do tema ativo.";
    };
    nvchadTheme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin";
      description = "Tema do base46 equivalente ao tema ativo.";
    };
    # Troca @base00@ por #rrggbb, @base00-hex@ por rrggbb e @base00-rgb@ por "r, g, b"
    render = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      readOnly = true;
      description = "Substitui os tokens de cor em um texto.";
      default =
        builtins.replaceStrings
          (map (n: "@${n}@") names ++ map (n: "@${n}-hex@") names ++ map (n: "@${n}-rgb@") names)
          (
            map (n: colors.${n}) names
            ++ map (n: builtins.substring 1 6 colors.${n}) names
            ++ map (n: rgb colors.${n}) names
          );
    };
  };
}
