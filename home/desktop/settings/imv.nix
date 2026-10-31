# Convertido de dot_config/imv/config (yocaslu/dotfiles)
colors:
let
  noHash = builtins.substring 1 6;
in
{
  options = {
    background = "${noHash colors.base00}";
    overlay_font = "JetBrainsMono Nerd Font:11";
    overlay_text_color = "${noHash colors.base05}";
    overlay_background_color = "${noHash colors.base01}";
    overlay_background_alpha = "ee";
  };
}
