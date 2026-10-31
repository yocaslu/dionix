# Ambiente gráfico (notebook e desktop): SwayFX + Waybar + Fuzzel + Alacritty,
# tudo em Catppuccin Mocha. Importado por modules/nixos/workstation.nix.
{
  imports = [
    ./sway.nix
    ./waybar.nix
    ./menus.nix
    ./theme.nix
    ./apps.nix
  ];

  # Os papéis de parede ficam em ~/Pictures/Wallpapers (Super+x w ou `wall <imagem>`)
  home.file."Pictures/Wallpapers/.keep".text = "";
}
