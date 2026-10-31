# Convertido de dot_config/swaylock/config (yocaslu/dotfiles)
colors:
let
  noHash = builtins.substring 1 6;
in
{
  screenshots = true;
  effect-blur = "8x5";
  effect-vignette = "0.5:0.5";
  fade-in = 0.2;
  color = "${noHash colors.base00}ff";
  clock = true;
  timestr = "%H:%M";
  datestr = "%d/%m/%Y";
  font = "JetBrainsMono Nerd Font";
  font-size = 24;
  indicator = true;
  indicator-radius = 110;
  indicator-thickness = 6;
  ignore-empty-password = true;
  show-failed-attempts = true;
  inside-color = "${noHash colors.base00}cc";
  inside-clear-color = "${noHash colors.base00}cc";
  inside-ver-color = "${noHash colors.base00}cc";
  inside-wrong-color = "${noHash colors.base00}cc";
  inside-caps-lock-color = "${noHash colors.base00}cc";
  ring-color = "${noHash colors.base02}ff";
  ring-clear-color = "${noHash colors.base0A}ff";
  ring-ver-color = "${noHash colors.base0D}ff";
  ring-wrong-color = "${noHash colors.base08}ff";
  ring-caps-lock-color = "${noHash colors.base09}ff";
  key-hl-color = "${noHash colors.base0E}ff";
  bs-hl-color = "${noHash colors.base08}ff";
  caps-lock-key-hl-color = "${noHash colors.base09}ff";
  caps-lock-bs-hl-color = "${noHash colors.base08}ff";
  line-color = "00000000";
  line-clear-color = "00000000";
  line-ver-color = "00000000";
  line-wrong-color = "00000000";
  line-caps-lock-color = "00000000";
  separator-color = "00000000";
  text-color = "${noHash colors.base05}ff";
  text-clear-color = "${noHash colors.base0A}ff";
  text-ver-color = "${noHash colors.base0D}ff";
  text-wrong-color = "${noHash colors.base08}ff";
  text-caps-lock-color = "${noHash colors.base09}ff";
  layout-bg-color = "${noHash colors.base00}ff";
  layout-border-color = "${noHash colors.base02}ff";
  layout-text-color = "${noHash colors.base05}ff";
}
