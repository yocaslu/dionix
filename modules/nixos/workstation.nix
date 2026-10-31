# Notebook e desktop: SwayFX como sessão principal, XFCE como alternativa,
# áudio, fontes, portais, rede e ferramentas de desenvolvimento.
# A parte do usuário (configs do Sway, Waybar, tema…) fica em home/desktop.
{
  config,
  inputs,
  pkgs,
  username,
  ...
}:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  # Sem alvos no sistema: o tema fica no Home Manager (home/desktop/themes.nix),
  # e o tuigreet e o XFCE não mudam
  stylix = {
    enable = true;
    autoEnable = false;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    homeManagerIntegration.followSystem = false;
  };

  # Sessões gráficas -------------------------------------------------------

  # SwayFX (Sway com blur, sombras e escurecimento). O Home Manager gera a
  # config; aqui ficam a sessão, o PAM do swaylock, o polkit e os portais.
  programs.sway = {
    enable = true;
    package = pkgs.swayfx;
    wrapperFeatures.gtk = true;
    extraPackages = [ ];
  };

  # XFCE como alternativa (X11), escolhido na tela de login
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
  };

  # Login no terminal (tuigreet) com as sessões Sway e XFCE
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
      command = builtins.concatStringsSep " " [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember"
        "--remember-user-session"
        "--asterisks"
        "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        "--xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions"
      ];
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Áudio, rede, energia -------------------------------------------------------

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  networking.networkmanager.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  users.users.${username}.extraGroups = [ "networkmanager" ];

  # Serviços de desktop usados pelos apps GTK, pelo tema e pelo yazi
  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.dbus.packages = [ pkgs.swaynotificationcenter ];

  # Fontes ---------------------------------------------------------------------

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Desenvolvimento ------------------------------------------------------------

  # Containers sem root para o distrobox (alias `box`)
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
  };

  # Binários genéricos baixados da internet (ex.: extensões, toolchains)
  programs.nix-ld.enable = true;

  # O rust-analyzer precisa do código da std para completar e navegar nela
  environment.sessionVariables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

  environment.systemPackages = with pkgs; [
    distrobox
    wl-clipboard
    # Rust (o gcc é o linker usado pelo cargo)
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    gcc
    # Go
    go
    gopls
    # Python
    uv
    ruff
    pyright
  ];

  home-manager.users.${username}.imports = [ ../../home/desktop ];
}
