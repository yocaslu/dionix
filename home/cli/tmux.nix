# tmux com prefixo Ctrl+s e plugins do nixpkgs (antes instalados pelo TPM)
{ config, pkgs, ... }:
let
  c = config.dionix.colors;
  # Cores do tema ativo para o plugin catppuccin
  thmColors = ''
    set -g @thm_bg "${c.base00}"
    set -g @thm_fg "${c.base05}"
    set -g @thm_rosewater "${c.base06}"
    set -g @thm_flamingo "${c.base0F}"
    set -g @thm_pink "${c.base0E}"
    set -g @thm_mauve "${c.base0E}"
    set -g @thm_red "${c.base08}"
    set -g @thm_maroon "${c.base08}"
    set -g @thm_peach "${c.base09}"
    set -g @thm_yellow "${c.base0A}"
    set -g @thm_green "${c.base0B}"
    set -g @thm_teal "${c.base0C}"
    set -g @thm_sky "${c.base0C}"
    set -g @thm_sapphire "${c.base0C}"
    set -g @thm_blue "${c.base0D}"
    set -g @thm_lavender "${c.base07}"
    set -g @thm_subtext_1 "${c.base04}"
    set -g @thm_subtext_0 "${c.base04}"
    set -g @thm_overlay_2 "${c.base04}"
    set -g @thm_overlay_1 "${c.base03}"
    set -g @thm_overlay_0 "${c.base03}"
    set -g @thm_surface_2 "${c.base02}"
    set -g @thm_surface_1 "${c.base02}"
    set -g @thm_surface_0 "${c.base01}"
    set -g @thm_mantle "${c.base00}"
    set -g @thm_crust "${c.base00}"
  '';

  # prefix + f: escolhe um projeto em ~/repos e abre/troca para a sessão dele
  tmux-sessionizer = pkgs.writeShellApplication {
    name = "tmux-sessionizer";
    runtimeInputs = with pkgs; [
      fd
      fzf
      tmux
      coreutils
    ];
    text = builtins.readFile ./files/tmux-sessionizer.sh;
  };
in
{
  home.packages = [ tmux-sessionizer ];

  programs.tmux = {
    enable = true;
    prefix = "C-s";
    terminal = "tmux-256color";
    mouse = true;
    baseIndex = 1;
    historyLimit = 50000;
    escapeTime = 0;
    keyMode = "vi";

    # A ordem importa: o catppuccin precisa vir antes dos plugins que usam a barra
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        # O tema do plugin só define o que ainda não existe (set -o)
        extraConfig = ''
          ${thmColors}
          set -g @catppuccin_window_left_separator ""
          set -g @catppuccin_window_right_separator " "
          set -g @catppuccin_window_middle_separator " █"
          set -g @catppuccin_window_number_position "right"
          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text "#W"
          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text "#W"
          set -g @catppuccin_status_modules_right "directory session"
          set -g @catppuccin_status_left_separator  " "
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_right_separator_inverse "no"
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"
          set -g @catppuccin_directory_text "#{pane_current_path}"
        '';
      }
      vim-tmux-navigator
      cargo # prefix + a
      {
        plugin = ping;
        extraConfig = ''
          # Ping do DietPi na barra de status
          set -g status-right '| DietPi:#{ping} #[fg=white] | #{prefix_highlight}'
          set -g @ping_host '10.42.1.10'
          set -g @ping_colorize true
        '';
      }
      prefix-highlight
      yank
      resurrect
      {
        # Restaura as sessões salvas ao iniciar o tmux
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
    ];

    extraConfig = ''
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config recarregada"

      set -ag terminal-overrides ",xterm-256color:RGB"

      # Janelas renumeradas, sem buracos ao fechar
      set -g renumber-windows on

      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R

      # Divisões: Ctrl+h / Ctrl+v, ou | e - abrindo na pasta do painel atual
      unbind C-h
      unbind C-v
      bind C-h split-window -h
      bind C-v split-window -v
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Alt+setas troca de painel sem o prefixo
      bind -n M-Left  select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up    select-pane -U
      bind -n M-Down  select-pane -D

      bind f display-popup -E -w 80% -h 60% "tmux-sessionizer"

      # Barra de status no topo
      set-option -g status-position top
    '';
  };
}
