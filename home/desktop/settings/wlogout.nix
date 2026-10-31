# Convertido de dot_config/wlogout/layout (yocaslu/dotfiles)
[
  {
    label = "lock";
    action = "swaylock -f";
    text = "[l] bloquear";
    keybind = "l";
  }
  {
    label = "logout";
    action = "swaymsg exit";
    text = "[e] sair";
    keybind = "e";
  }
  {
    label = "suspend";
    action = "systemctl suspend";
    text = "[u] suspender";
    keybind = "u";
  }
  {
    label = "reboot";
    action = "systemctl reboot";
    text = "[r] reiniciar";
    keybind = "r";
  }
  {
    label = "shutdown";
    action = "systemctl poweroff";
    text = "[s] desligar";
    keybind = "s";
  }
]
