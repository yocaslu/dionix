# Ferramentas de terminal: usadas em todas as máquinas (notebook, desktop e servidores)
{
  imports = [
    ./colors.nix
    ./shell.nix
    ./git.nix
    ./tmux.nix
    ./editors.nix
    ./tools.nix
  ];

  programs.home-manager.enable = true;
}
