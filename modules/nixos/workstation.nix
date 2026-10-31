# Notebook e desktop: SwayFX como sessão principal, XFCE como alternativa,
# áudio, fontes, portais, rede e ferramentas de desenvolvimento.
# A parte do usuário (configs do Sway, Waybar, tema…) fica em home/desktop.
{
  config,
  pkgs,
  username,
  ...
}:
{
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

  environment.systemPackages = with pkgs; [
    distrobox
    wl-clipboard
  ];

  home-manager.users.${username}.imports = [ ../../home/desktop ];
}
