# tmux com prefixo Ctrl+s e plugins do nixpkgs (antes instalados pelo TPM)
{ pkgs, ... }:
let
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
        extraConfig = ''
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
