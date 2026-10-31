# Convertido de dot_config/fuzzel/fuzzel.ini (yocaslu/dotfiles)
colors:
let
  noHash = builtins.substring 1 6;
in
{
  main = {
    font = "JetBrainsMono Nerd Font:size=12";
    use-bold = "yes";
    terminal = "alacritty -e";
    prompt = "\"run ❯ \"";
    placeholder = "\"buscar…\"";
    match-counter = "yes";
    icons-enabled = "no";
    layer = "overlay";
    width = "50";
    lines = "12";
    horizontal-pad = "12";
    vertical-pad = "8";
    inner-pad = "6";
    line-height = "20";
  };
  colors = {
    background = "${noHash colors.base00}e6";
    text = "${noHash colors.base05}ff";
    message = "${noHash colors.base04}ff";
    prompt = "${noHash colors.base0E}ff";
    placeholder = "${noHash colors.base03}ff";
    input = "${noHash colors.base05}ff";
    match = "${noHash colors.base0E}ff";
    selection = "${noHash colors.base0E}ff";
    selection-text = "${noHash colors.base00}ff";
    selection-match = "${noHash colors.base00}ff";
    counter = "${noHash colors.base03}ff";
    border = "${noHash colors.base0E}ff";
  };
  border = {
    width = "1";
    radius = "0";
    selection-radius = "0";
  };
}
