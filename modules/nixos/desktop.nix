# Só no desktop (i5-3470, Intel HD 2500, 8 GB de RAM e SSD SATA): prioriza
# desempenho e baixo uso de recursos.
{
  lib,
  pkgs,
  username,
  ...
}:
{
  # Decodificação de vídeo na GPU. Ivy Bridge usa o driver i965, não o iHD.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";

  # Pouca RAM: zram do tamanho da memória e preferência por ele em vez de
  # descartar cache. Sem leitura antecipada, que não ajuda em swap na RAM.
  zramSwap.memoryPercent = 100;
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  # Menos escritas no SSD
  fileSystems."/".options = [ "noatime" ];

  # Rebuilds não travam o uso da máquina: até 4 núcleos e prioridade mínima
  nix = {
    settings = {
      max-jobs = 2;
      cores = 2;
    };
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };

  # Boot sem esperar a rede e rebuild sem gerar o manual do NixOS
  systemd.services.NetworkManager-wait-online.enable = false;
  documentation.nixos.enable = false;

  # Blur, sombras e escurecimento pesam na HD 2500. Vem depois do fx.conf e
  # sobrescreve o que ele liga.
  home-manager.users.${username}.wayland.windowManager.sway.extraConfig = lib.mkAfter ''
    shadows disable
    blur disable
    default_dim_inactive 0
    layer_effects "waybar" blur disable; shadows disable
    layer_effects "swaync-control-center" blur disable; shadows disable
    layer_effects "swaync-notification-window" blur disable; shadows disable
    layer_effects "launcher" blur disable; shadows disable
    layer_effects "wlr_which_key" blur disable; shadows disable
    layer_effects "logout_dialog" blur disable
    layer_effects "swayosd" blur disable; shadows disable
  '';
}
