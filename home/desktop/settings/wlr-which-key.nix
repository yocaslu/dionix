# Convertido de dot_config/wlr-which-key/config.yaml (yocaslu/dotfiles)
{
  font = "JetBrainsMono Nerd Font 12";
  background = "#1e1e2ee6";
  color = "#cdd6f4";
  border = "#cba6f7";
  separator = " ❯ ";
  border_width = 1;
  corner_r = 0;
  padding = 12;
  rows_per_column = 8;
  column_padding = 32;
  anchor = "bottom";
  margin_bottom = 4;
  inhibit_compositor_keyboard_shortcuts = true;
  auto_kbd_layout = true;
  menu = [
    {
      key = "s";
      desc = "+screenshot";
      submenu = [
        {
          key = "a";
          desc = "área + anotar";
          cmd = "grim -g \"$(slurp -d -b 1e1e2e66 -c cba6f7ff -s 00000000 -w 1)\" - | swappy -f -";
        }
        {
          key = "t";
          desc = "tela inteira + anotar";
          cmd = "grim - | swappy -f -";
        }
        {
          key = "c";
          desc = "área → clipboard";
          cmd = "grim -g \"$(slurp -d -b 1e1e2e66 -c cba6f7ff -s 00000000 -w 1)\" - | wl-copy";
        }
      ];
    }
    {
      key = "c";
      desc = "+clipboard";
      submenu = [
        {
          key = "v";
          desc = "colar do histórico";
          cmd = "cliphist list | fuzzel --dmenu --with-nth 2 --prompt \"clip ❯ \" | cliphist decode | wl-copy";
        }
        {
          key = "d";
          desc = "remover item";
          cmd = "cliphist list | fuzzel --dmenu --with-nth 2 --prompt \"del ❯ \" | cliphist delete";
        }
        {
          key = "x";
          desc = "limpar histórico";
          cmd = "cliphist wipe";
        }
      ];
    }
    {
      key = "n";
      desc = "+notificações";
      submenu = [
        {
          key = "n";
          desc = "abrir central";
          cmd = "swaync-client -t -sw";
        }
        {
          key = "d";
          desc = "não perturbe";
          cmd = "swaync-client -d -sw";
        }
        {
          key = "x";
          desc = "limpar todas";
          cmd = "swaync-client -C -sw";
        }
      ];
    }
    {
      key = "a";
      desc = "+áudio";
      submenu = [
        {
          key = "m";
          desc = "mudo";
          cmd = "swayosd-client --output-volume mute-toggle";
          keep_open = true;
        }
        {
          key = "i";
          desc = "microfone mudo";
          cmd = "swayosd-client --input-volume mute-toggle";
          keep_open = true;
        }
        {
          key = [
            "k"
            "Up"
          ];
          desc = "volume +";
          cmd = "swayosd-client --output-volume raise";
          keep_open = true;
        }
        {
          key = [
            "j"
            "Down"
          ];
          desc = "volume -";
          cmd = "swayosd-client --output-volume lower";
          keep_open = true;
        }
        {
          key = "p";
          desc = "mixer (pavucontrol)";
          cmd = "pavucontrol";
        }
      ];
    }
    {
      key = "r";
      desc = "+rede";
      submenu = [
        {
          key = "w";
          desc = "wi-fi (nmtui)";
          cmd = "alacritty -e nmtui";
        }
        {
          key = "e";
          desc = "editar conexões";
          cmd = "nm-connection-editor";
        }
        {
          key = "b";
          desc = "bluetooth (blueman)";
          cmd = "blueman-manager";
        }
      ];
    }
    {
      key = "t";
      desc = "+alternar";
      submenu = [
        {
          key = "n";
          desc = "luz noturna";
          cmd = "pkill -x wlsunset || wlsunset -S 06:30 -s 18:30 -t 4000 -T 6500";
        }
        {
          key = "b";
          desc = "waybar";
          cmd = "pkill -SIGUSR1 -x waybar";
        }
        {
          key = "m";
          desc = "reaplicar monitores (kanshi)";
          cmd = "kanshictl reload";
        }
      ];
    }
    {
      key = "o";
      desc = "+abrir";
      submenu = [
        {
          key = "f";
          desc = "arquivos (yazi)";
          cmd = "alacritty -e yazi";
        }
        {
          key = "t";
          desc = "monitor do sistema (btop)";
          cmd = "alacritty -e btop";
        }
        {
          key = "d";
          desc = "posição dos monitores (nwg-displays)";
          cmd = "nwg-displays";
        }
        {
          key = "a";
          desc = "aparência GTK (nwg-look)";
          cmd = "nwg-look";
        }
        {
          key = "q";
          desc = "aparência Qt (qt6ct)";
          cmd = "qt6ct";
        }
      ];
    }
    {
      key = "m";
      desc = "tema";
      cmd = "theme";
    }
    {
      key = "w";
      desc = "papel de parede";
      cmd = "dir=\"$HOME/Pictures/Wallpapers\"; img=$(find \"$dir\" -path '*/.*' -prune -o -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) -printf '%P\\n' | sort | fuzzel --dmenu --prompt \"wall ❯ \") && ln -sf \"$dir/$img\" \"$dir/.current\" && awww img \"$dir/.current\" --transition-type grow";
    }
    {
      key = "p";
      desc = "+energia";
      submenu = [
        {
          key = "l";
          desc = "bloquear";
          cmd = "swaylock -f";
        }
        {
          key = "e";
          desc = "sair do sway";
          cmd = "swaymsg exit";
        }
        {
          key = "u";
          desc = "suspender";
          cmd = "systemctl suspend";
        }
        {
          key = "r";
          desc = "reiniciar";
          cmd = "systemctl reboot";
        }
        {
          key = "s";
          desc = "desligar";
          cmd = "systemctl poweroff";
        }
      ];
    }
  ];
}
