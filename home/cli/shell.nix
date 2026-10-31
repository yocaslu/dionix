# zsh (shell padrão) e Bash.
#
# A ordem do antigo ~/.zshrc é mantida pelas prioridades do Home Manager:
#   compinit (570) → fzf-tab (600) → autosuggestions (700) → fzf (910)
#   → atuin/starship (1000) → nossos módulos (1050) → syntax-highlighting (1200)
# Os módulos com funções e aliases (aliases, functions, fzf, trash, cmds) continuam
# como arquivos .zsh em ~/.config/zsh, porque o `cmds` lê a documentação
# deles em ~/.config/zsh/commands.md.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  zshDir = "${config.xdg.configHome}/zsh";
  bashDir = "${config.xdg.configHome}/bashrc";

  # Módulos do Bash que também são carregados pelo zsh (só aliases e funções POSIX)
  bashModules = [
    "cpufreq"
    "dev"
    "distrobox"
    "download"
    "lazygit"
    "nnn"
    "py"
    "shell"
    "wallpaper"
    "yazi"
  ];
  sourceBashModules = lib.concatMapStrings (m: ''
    [[ -r ${bashDir}/${m}.sh ]] && source ${bashDir}/${m}.sh
  '') bashModules;
in
{
  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
    # Usado pelos módulos do Bash reaproveitados (py.sh, shell.sh)
    REPO_PATH = "$HOME/repos";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
  ];

  programs.zsh = {
    enable = true;
    defaultKeymap = "emacs";

    history = {
      path = "${config.xdg.stateHome}/zsh/history";
      size = 50000;
      save = 50000;
      share = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };
    setOptions = [
      "HIST_REDUCE_BLANKS"
      "AUTO_CD"
      "INTERACTIVE_COMMENTS"
      "NO_BEEP"
    ];

    enableCompletion = true;
    completionInit = ''
      autoload -Uz compinit
      () {
        local dump="${config.xdg.cacheHome}/zsh/zcompdump-$ZSH_VERSION"
        [[ -d ''${dump:h} ]] || mkdir -p "''${dump:h}"
        compinit -d "$dump"
      }
    '';

    autosuggestion = {
      enable = true;
      # base03 do tema ativo
      highlight = "fg=${config.dionix.colors.base03}";
    };
    syntaxHighlighting.enable = true;

    initContent = lib.mkMerge [
      # Estilos da completação (antes do compinit)
      (lib.mkOrder 560 ''
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*:descriptions' format '[%d]'
        # O fzf-tab substitui o menu da completação
        zstyle ':completion:*' menu no
      '')

      # fzf-tab: depois do compinit e antes do zsh-autosuggestions
      (lib.mkOrder 600 ''
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'
      '')

      # O `fzf --zsh` toma o Tab para a completação `**`; devolve o Tab ao fzf-tab
      (lib.mkOrder 920 ''
        (( $+widgets[fzf-tab-complete] )) && bindkey '^I' fzf-tab-complete
      '')

      # Nossos módulos: aliases, funções, fzf, lixeira e o `cmds` (Ctrl+Espaço)
      (lib.mkOrder 1050 ''
        ZSH_CONFIG_DIR="${zshDir}"
        for module in aliases functions; do
          [[ -r $ZSH_CONFIG_DIR/$module.zsh ]] && source "$ZSH_CONFIG_DIR/$module.zsh"
        done
        ${sourceBashModules}
        for module in fzf trash cmds; do
          [[ -r $ZSH_CONFIG_DIR/$module.zsh ]] && source "$ZSH_CONFIG_DIR/$module.zsh"
        done
        unset module
      '')
    ];
  };

  xdg.configFile = {
    "zsh/aliases.zsh".source = ./files/zsh/aliases.zsh;
    "zsh/functions.zsh".source = ./files/zsh/functions.zsh;
    "zsh/fzf.zsh".source = ./files/zsh/fzf.zsh;
    "zsh/trash.zsh".source = ./files/zsh/trash.zsh;
    "zsh/cmds.zsh".source = ./files/zsh/cmds.zsh;
    "zsh/commands.md".source = ./files/zsh/commands.md;
  }
  // lib.listToAttrs (
    map (m: lib.nameValuePair "bashrc/${m}.sh" { source = ./files/bash/${m}.sh; }) bashModules
  );

  # Bash: carrega os mesmos módulos de ~/.config/bashrc
  programs.bash = {
    enable = true;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    shellAliases = {
      rc = "source ~/.bashrc";
      cl = "clear";
    };
    initExtra = ''
      PS1='\u@\h \w \$ '
      ${lib.replaceStrings [ "[[ -r" "]] &&" ] [ "[ -r" "] &&" ] sourceBashModules}
    '';
  };

  # Integrações com o shell (os inits que ficavam no fim do ~/.zshrc)
  programs.starship = {
    enable = true;
    settings = import ./settings/starship.nix config.dionix.colors;
  };
  programs.zoxide.enable = true;
  programs.atuin = {
    enable = true;
    # A seta para cima continua sendo o histórico normal do zsh
    flags = [ "--disable-up-arrow" ];
    settings = import ./settings/atuin.nix;
  };
  programs.fzf = {
    enable = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    fileWidgetOptions = [ "--preview 'bat --color=always --line-range :200 {}'" ];
    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    changeDirWidgetOptions = [ "--preview 'eza --tree --level=2 --icons {}'" ];
    defaultOptions = [
      "--height 60%"
      "--layout=reverse"
      "--border"
    ];
    # Cores do tema ativo
    colors = {
      "bg+" = "${config.dionix.colors.base01}";
      bg = "${config.dionix.colors.base00}";
      spinner = "${config.dionix.colors.base06}";
      hl = "${config.dionix.colors.base08}";
      fg = "${config.dionix.colors.base05}";
      header = "${config.dionix.colors.base08}";
      info = "${config.dionix.colors.base0E}";
      pointer = "${config.dionix.colors.base06}";
      marker = "${config.dionix.colors.base07}";
      "fg+" = "${config.dionix.colors.base05}";
      prompt = "${config.dionix.colors.base0E}";
      "hl+" = "${config.dionix.colors.base08}";
      selected-bg = "${config.dionix.colors.base02}";
      border = "${config.dionix.colors.base03}";
      label = "${config.dionix.colors.base05}";
    };
  };
}
