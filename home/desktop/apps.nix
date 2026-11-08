# Terminal (Alacritty), PDF (zathura), imagens (imv), vídeo (mpv), capturas
# (grim + slurp + swappy), navegador (Firefox), editores gráficos (VS Code e
# Zed), escritório (OnlyOffice), arquivos compactados (Xarchiver), senhas
# (rbw), música (spotify_player) e os apps padrão
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

  # O rpi-imager 2.x só grava cartões como root. Pelo sudo, o DISPLAY do Xwayland
  # passa e o WAYLAND_DISPLAY não, e o Qt cai no X11, que recusa o root. Aqui o
  # pkexec (senha pelo agente do polkit) recebe o socket do Wayland pelo caminho
  # completo; o próprio programa aponta HOME e XDG_* de volta para o usuário.
  rpiImagerRoot = pkgs.writeShellApplication {
    name = "rpi-imager-root";
    text = ''
      exec /run/wrappers/bin/pkexec ${lib.getExe' pkgs.coreutils "env"} \
        WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" \
        QT_QPA_PLATFORM=wayland \
        ${lib.getExe pkgs.rpi-imager} "$@"
    '';
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
    # Documentos, planilhas e apresentações (formatos do Office e OpenDocument)
    onlyoffice-desktopeditors
    # Arquivos compactados (zip, 7z, rar, tar.*); já traz os programas de cada formato
    xarchiver
    # Cliente Bitwarden de terminal, sem Electron e com senha pedida no terminal
    rbw
    pinentry-curses
    sshKeyRestore
    # Grava imagens em cartões SD (Raspberry Pi OS, ou a imagem do pi deste flake)
    rpi-imager
    rpiImagerRoot
  ];

  # O atalho do menu abre já com permissão de gravar (mesmo nome do .desktop do
  # pacote, que fica escondido por este)
  xdg.desktopEntries."com.raspberrypi.rpi-imager" = {
    name = "Raspberry Pi Imager";
    genericName = "Gravador de cartões SD";
    exec = "rpi-imager-root %u";
    icon = "rpi-imager";
    categories = [ "Utility" ];
    mimeType = [
      "x-scheme-handler/rpi-imager"
      "application/vnd.raspberrypi.imager-manifest+json"
    ];
  };

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
      # O plugin de quadrinhos do zathura também declara application/zip; sem
      # isto, o zathura viraria o padrão para qualquer .zip
      // assoc "xarchiver.desktop" [
        "application/zip"
        "application/x-7z-compressed"
        "application/vnd.rar"
        "application/x-rar"
        "application/x-tar"
        "application/gzip"
        "application/x-compressed-tar"
        "application/x-bzip2"
        "application/x-bzip-compressed-tar"
        "application/x-xz"
        "application/x-xz-compressed-tar"
        "application/zstd"
        "application/x-zstd-compressed-tar"
      ]
      // assoc "org.pwmt.zathura-cb.desktop" [
        "application/x-cbz"
        "application/x-cbr"
      ]
      // assoc "onlyoffice-desktopeditors.desktop" [
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        "application/msword"
        "application/vnd.ms-excel"
        "application/vnd.ms-powerpoint"
        "application/vnd.oasis.opendocument.text"
        "application/vnd.oasis.opendocument.spreadsheet"
        "application/vnd.oasis.opendocument.presentation"
        "application/rtf"
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
