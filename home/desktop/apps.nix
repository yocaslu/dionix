# Terminal (Alacritty), PDF (zathura), imagens (imv), vídeo (mpv), capturas
# (grim + slurp + swappy), navegador (Firefox), editores gráficos (VS Code e
# Zed), senhas (rbw), música (spotify_player) e os apps padrão
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sshKeyRestore = pkgs.writeShellApplication {
    name = "ssh-key-restore";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      openssh
      rbw
    ];
    text = builtins.readFile ./files/ssh-key-restore/ssh-key-restore.sh;
  };
in
{
  programs.firefox.enable = true;

  programs.alacritty = {
    enable = true;
    settings = import ./settings/alacritty.nix;
  };

  programs.zathura = {
    enable = true;
    extraConfig = config.dionix.render (builtins.readFile ./files/zathura/zathurarc);
  };

  programs.imv = {
    enable = true;
    settings = import ./settings/imv.nix config.dionix.colors;
  };

  programs.mpv = {
    enable = true;
    config = import ./settings/mpv.nix config.dionix.colors;
    bindings = import ./settings/mpv-bindings.nix;
  };

  programs.swappy = {
    enable = true;
    settings = import ./settings/swappy.nix;
  };

  programs.spotify-player.enable = true;

  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    libnotify
    brightnessctl
    xdg-utils
    # Configs continuam editáveis em ~/.config, fora do Nix
    vscode
    zed-editor
    # Cliente Bitwarden de terminal, sem Electron e com senha pedida no terminal
    rbw
    pinentry-curses
    sshKeyRestore
  ];

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        assoc = app: types: lib.genAttrs types (_: [ app ]);
      in
      assoc "firefox.desktop" [
        "text/html"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ]
      // assoc "org.pwmt.zathura.desktop" [
        "application/pdf"
        "application/epub+zip"
      ]
      // assoc "imv.desktop" [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
        "image/svg+xml"
      ]
      // assoc "mpv.desktop" [
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/quicktime"
        "video/x-msvideo"
        "video/mpeg"
      ];
  };
}
