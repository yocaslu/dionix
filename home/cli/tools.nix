# Utilitários de terminal (antes em .chezmoidata/packages.yaml) e suas configs
{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    # Substitutos modernos usados pelos aliases (ls→eza, du→dust, df→duf…)
    eza
    fd
    ripgrep
    dust
    duf
    tealdeer
    trash-cli
    lsof
    unrar
    _7zz
    jq
    nnn
    fastfetch
    python3
  ];

  programs.bat = {
    enable = true;
    # O bat do nixpkgs já traz o Catppuccin Mocha embutido
    config = {
      theme = "Catppuccin Mocha";
      style = "numbers,changes,header";
    };
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_mocha";
      theme_background = false;
      truecolor = true;
      rounded_corners = false;
      vim_keys = true;
    };
    themes.catppuccin_mocha = builtins.readFile ./files/btop-catppuccin_mocha.theme;
  };

  programs.yazi = {
    enable = true;
    # O `y` (entra na pasta onde você parou) vem de ~/.config/bashrc/yazi.sh,
    # documentado no commands.md, em vez do wrapper do Home Manager
    enableZshIntegration = false;
    enableBashIntegration = false;
    flavors.catppuccin-mocha = "${inputs.yazi-flavors}/catppuccin-mocha.yazi";
    theme.flavor = {
      dark = "catppuccin-mocha";
      light = "catppuccin-mocha";
    };
    extraPackages = with pkgs; [
      ffmpegthumbnailer
      poppler-utils
      _7zz
      jq
      fd
      ripgrep
      fzf
      zoxide
    ];
  };

  programs.lsd = {
    enable = true;
    settings = import ./settings/lsd.nix;
    colors = import ./settings/lsd-colors.nix;
    icons = import ./settings/lsd-icons.nix;
  };
}
