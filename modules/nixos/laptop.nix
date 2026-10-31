# Só no notebook: Wi-Fi (via NetworkManager do workstation.nix), Bluetooth,
# touchpad, tampa e brilho.
{ username, ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Touchpad do ideapad 3 (antes comentado na config do Sway)
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      disableWhileTyping = true;
      middleEmulation = true;
    };
  };

  # Fechar a tampa com o monitor externo ligado não suspende; o Sway desliga
  # o eDP-1 (bindswitch). Sem monitor externo, suspende normalmente.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "suspend";
  };

  # Ícone de Bluetooth na bandeja da Waybar
  home-manager.users.${username}.services.blueman-applet.enable = true;
}
