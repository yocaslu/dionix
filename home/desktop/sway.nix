# SwayFX: tiling com navegação estilo Vim, gaps de 4px, bordas de 1px e
# cores do tema ativo. Os programas que ficavam no "Autostart" do config
# antigo agora são serviços systemd (waybar, swaync, kanshi, cliphist,
# wlsunset, swayosd, autotiling, polkit…), presos ao sway-session.target.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  c = config.dionix.colors;
  mod = "Mod4";
  left = "h";
  down = "j";
  up = "k";
  right = "l";

  term = "alacritty";
  menu = "fuzzel";
  swaylock = "${config.programs.swaylock.package}/bin/swaylock";
  noHash = lib.removePrefix "#";
  slurp = "slurp -d -b ${noHash c.base00}66 -c ${noHash c.base0E}ff -s 00000000 -w 1";

  # Super+1…0 vai para o workspace; Super+Shift+1…0 move a janela
  workspaces = lib.genList (i: toString (i + 1)) 10;
  keyFor = ws: if ws == "10" then "0" else ws;
  workspaceBindings = lib.listToAttrs (
    lib.concatMap (ws: [
      (lib.nameValuePair "${mod}+${keyFor ws}" "workspace number ${ws}")
      (lib.nameValuePair "${mod}+Shift+${keyFor ws}" "move container to workspace number ${ws}")
    ]) workspaces
  );

  # Carrega ~/Pictures/Wallpapers/.current (link para a imagem escolhida),
  # ou a cor base quando não há papel de parede
  wallpaperRestore = pkgs.writeShellScript "wallpaper-restore" ''
    for _ in $(seq 25); do awww query >/dev/null 2>&1 && break; sleep 0.2; done
    if [ -e "$HOME/Pictures/Wallpapers/.current" ]; then
      awww img "$HOME/Pictures/Wallpapers/.current" --transition-type grow
    else
      awww clear ${noHash c.base00}
    fi
  '';
in
{
  # Os serviços gráficos só sobem na sessão do Sway (não na do XFCE)
  wayland.systemd.target = "sway-session.target";

  wayland.windowManager.sway = {
    enable = true;
    # O mesmo SwayFX instalado pelo NixOS (programs.sway em workstation.nix)
    package = osConfig.programs.sway.package;
    # O `sway --validate` do SwayFX tenta criar o renderizador de efeitos (GLES2)
    # e falha no sandbox do Nix, sem GPU. A config é validada com o Sway comum
    # (veja "Validação" no CLAUDE.md).
    checkConfig = false;
    systemd.enable = true;
    wrapperFeatures.gtk = true;

    config = {
      modifier = mod;
      inherit
        left
        down
        up
        right
        menu
        ;
      terminal = term;

      fonts = {
        names = [ "JetBrainsMono Nerd Font" ];
        size = 11.0;
      };

      # Visual TUI: bordas de 1px; a barra de título só aparece em tabbed/stacking
      window = {
        border = 1;
        titlebar = false;
      };
      floating = {
        border = 1;
        titlebar = false;
        modifier = mod;
      };

      gaps = {
        inner = 4;
        outer = 4;
        smartGaps = true;
      };

      # Inativas em base02, foco em base0E
      colors = {
        focused = {
          border = c.base0E;
          background = c.base0E;
          text = c.base00;
          indicator = c.base0E;
          childBorder = c.base0E;
        };
        focusedInactive = {
          border = c.base02;
          background = c.base01;
          text = c.base05;
          indicator = c.base02;
          childBorder = c.base02;
        };
        unfocused = {
          border = c.base02;
          background = c.base00;
          text = c.base03;
          indicator = c.base02;
          childBorder = c.base02;
        };
        urgent = {
          border = c.base08;
          background = c.base08;
          text = c.base00;
          indicator = c.base08;
          childBorder = c.base08;
        };
        placeholder = {
          border = c.base02;
          background = c.base00;
          text = c.base03;
          indicator = c.base02;
          childBorder = c.base02;
        };
        background = c.base00;
      };

      input."type:keyboard".xkb_layout = "br";

      # A Waybar roda como serviço (programs.waybar.systemd)
      bars = [ ];

      # Atalhos completos (sem os padrões do Home Manager)
      keybindings = workspaceBindings // {
        # Básico
        "${mod}+Return" = "exec ${term}";
        "${mod}+Shift+q" = "kill";
        "${mod}+d" = "exec ${menu}";
        "${mod}+Shift+c" = "reload";
        "${mod}+Escape" = "exec ${swaylock} -f";

        # Menu de atalhos (wlr-which-key): screenshot, clipboard, áudio, rede, energia…
        "${mod}+x" = "exec wlr-which-key";

        # Central de notificações (swaync) e "não perturbe"
        "${mod}+n" = "exec swaync-client -t -sw";
        "${mod}+Shift+n" = "exec swaync-client -d -sw";

        # Histórico do clipboard (cliphist): colar e remover um item
        "${mod}+c" =
          ''exec cliphist list | fuzzel --dmenu --with-nth 2 --prompt "clip ❯ " | cliphist decode | wl-copy'';
        "${mod}+Shift+v" =
          ''exec cliphist list | fuzzel --dmenu --with-nth 2 --prompt "del ❯ " | cliphist delete'';

        # Menu de energia (wlogout)
        "${mod}+Shift+e" = "exec wlogout -b 5 -T 440 -B 440";

        # Foco
        "${mod}+${left}" = "focus left";
        "${mod}+${down}" = "focus down";
        "${mod}+${up}" = "focus up";
        "${mod}+${right}" = "focus right";
        "${mod}+Left" = "focus left";
        "${mod}+Down" = "focus down";
        "${mod}+Up" = "focus up";
        "${mod}+Right" = "focus right";

        # Mover janelas
        "${mod}+Shift+${left}" = "move left";
        "${mod}+Shift+${down}" = "move down";
        "${mod}+Shift+${up}" = "move up";
        "${mod}+Shift+${right}" = "move right";
        "${mod}+Shift+Left" = "move left";
        "${mod}+Shift+Down" = "move down";
        "${mod}+Shift+Up" = "move up";
        "${mod}+Shift+Right" = "move right";

        # Layout
        "${mod}+b" = "splith";
        "${mod}+v" = "splitv";
        "${mod}+s" = "layout stacking";
        "${mod}+w" = "layout tabbed";
        "${mod}+e" = "layout toggle split";
        "${mod}+f" = "fullscreen";
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+space" = "focus mode_toggle";
        "${mod}+a" = "focus parent";

        # Scratchpad
        "${mod}+Shift+minus" = "move scratchpad";
        "${mod}+minus" = "scratchpad show";

        "${mod}+r" = ''mode "resize"'';

        # Teclas de mídia com indicador na tela (swayosd)
        "--locked XF86AudioMute" = "exec swayosd-client --output-volume mute-toggle";
        "--locked XF86AudioLowerVolume" = "exec swayosd-client --output-volume lower";
        "--locked XF86AudioRaiseVolume" = "exec swayosd-client --output-volume raise";
        "--locked XF86AudioMicMute" = "exec swayosd-client --input-volume mute-toggle";
        "--locked XF86MonBrightnessDown" = "exec swayosd-client --brightness lower";
        "--locked XF86MonBrightnessUp" = "exec swayosd-client --brightness raise";
        "--release Caps_Lock" = "exec swayosd-client --caps-lock";

        # Capturas: área + anotação, tela inteira + anotação, área direto para o clipboard
        "Print" = ''exec grim -g "$(${slurp})" - | swappy -f -'';
        "Shift+Print" = "exec grim - | swappy -f -";
        "Ctrl+Print" = ''exec grim -g "$(${slurp})" - | wl-copy'';
      };

      modes.resize = {
        "${left}" = "resize shrink width 100px";
        "${down}" = "resize grow height 100px";
        "${up}" = "resize shrink height 100px";
        "${right}" = "resize grow width 100px";
        "Left" = "resize shrink width 100px";
        "Down" = "resize grow height 100px";
        "Up" = "resize shrink height 100px";
        "Right" = "resize grow width 100px";
        "Return" = ''mode "default"'';
        "Escape" = ''mode "default"'';
      };

      startup = [
        # Papel de parede (o awww-daemon é o serviço services.awww)
        {
          command = "${wallpaperRestore}";
          always = true;
        }
      ];
    };

    extraConfig = ''
      # Tampa fechada: desliga a tela do notebook e mantém o monitor externo
      bindswitch --reload --locked lid:on output eDP-1 disable
      bindswitch --reload --locked lid:off output eDP-1 enable

      # Barras de título (tabbed/stacking) no estilo das abas do tmux
      title_align left
      titlebar_padding 8 2
      titlebar_border_thickness 1
      for_window [all] title_format " %title "
      client.focused_tab_title ${c.base02} ${c.base01} ${c.base05}

      ${config.dionix.render (builtins.readFile ./files/sway/fx.conf)}
    '';
  };

  # Avisos e erros do Sway
  xdg.configFile."swaynag/config".source = ./files/swaynag.conf;

  # Bloqueia em 5 min, desliga as telas em 10 min e bloqueia antes de suspender.
  # O módulo idle_inhibitor da Waybar pausa esses timeouts.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${swaylock} -f";
      }
      {
        timeout = 600;
        command = ''${osConfig.programs.sway.package}/bin/swaymsg "output * power off"'';
        resumeCommand = ''${osConfig.programs.sway.package}/bin/swaymsg "output * power on"'';
      }
    ];
    events = {
      before-sleep = "${swaylock} -f";
      lock = "${swaylock} -f";
    };
  };

  # Bloqueio de tela com fundo desfocado e relógio (swaylock-effects)
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = import ./settings/swaylock.nix;
  };

  # Perfis de monitor: externo à esquerda + notebook, só o notebook, só o externo
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "dual";
        profile.outputs = [
          {
            criteria = "HDMI-A-1";
            mode = "2560x1080@75Hz";
            position = "0,0";
          }
          {
            criteria = "eDP-1";
            mode = "1920x1080@60Hz";
            position = "2560,0";
          }
        ];
      }
      {
        profile.name = "notebook";
        profile.outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080@60Hz";
            position = "0,0";
          }
        ];
      }
      {
        profile.name = "monitor";
        profile.outputs = [
          {
            criteria = "HDMI-A-1";
            mode = "2560x1080@75Hz";
            position = "0,0";
          }
        ];
      }
    ];
  };

  # Serviços que antes eram `exec` no config do Sway
  services.awww.enable = true;
  services.cliphist.enable = true;
  services.autotiling.enable = true;
  services.swayosd = {
    enable = true;
    stylePath = ./files/swayosd/style.css;
  };
  # Luz noturna: 4000K entre 18:30 e 06:30 (horários fixos, sem localização)
  services.wlsunset = {
    enable = true;
    sunrise = "06:30";
    sunset = "18:30";
    temperature = {
      day = 6500;
      night = 4000;
    };
  };
  services.polkit-gnome.enable = true;
  services.network-manager-applet.enable = true;
}
