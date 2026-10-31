# Terminal (Alacritty), PDF (zathura), imagens (imv), vídeo (mpv), capturas
# (grim + slurp + swappy) e os apps padrão
{ lib, pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = lib.recursiveUpdate (import ./settings/alacritty.nix) (
      import ./settings/alacritty-catppuccin-mocha.nix
    );
  };

  programs.zathura = {
    enable = true;
    extraConfig = builtins.readFile ./files/zathura/zathurarc;
  };

  programs.imv = {
    enable = true;
    settings = import ./settings/imv.nix;
  };

  programs.mpv = {
    enable = true;
    config = import ./settings/mpv.nix;
    bindings = import ./settings/mpv-bindings.nix;
  };

  programs.swappy = {
    enable = true;
    settings = import ./settings/swappy.nix;
  };

  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    libnotify
    brightnessctl
    xdg-utils
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
      assoc "org.pwmt.zathura.desktop" [
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
