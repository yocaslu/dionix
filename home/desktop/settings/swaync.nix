# Convertido de dot_config/swaync/config.json (yocaslu/dotfiles)
{
  "$schema" = "/etc/xdg/swaync/configSchema.json";
  positionX = "right";
  positionY = "bottom";
  layer = "overlay";
  control-center-layer = "top";
  control-center-positionX = "right";
  control-center-positionY = "bottom";
  control-center-margin-top = 4;
  control-center-margin-bottom = 4;
  control-center-margin-right = 4;
  control-center-margin-left = 4;
  control-center-width = 420;
  control-center-height = 600;
  notification-window-width = 420;
  timeout = 8;
  timeout-low = 4;
  timeout-critical = 0;
  fit-to-screen = true;
  relative-timestamps = true;
  keyboard-shortcuts = true;
  notification-grouping = true;
  image-visibility = "when-available";
  transition-time = 100;
  hide-on-clear = false;
  hide-on-action = true;
  text-empty = "sem notificações";
  widgets = [
    "title"
    "dnd"
    "mpris"
    "notifications"
  ];
  widget-config = {
    title = {
      text = "notificações";
      clear-all-button = true;
      button-text = "limpar";
    };
    dnd = {
      text = "não perturbe";
    };
    mpris = {
      show-album-art = "never";
      autohide = true;
    };
    notifications = {
      vexpand = true;
    };
  };
}
