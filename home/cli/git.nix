# git com o delta como pager (antes em ~/.config/git/config)
{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      # Preencha com o seu nome e e-mail (antes ficavam no ~/.gitconfig):
      # user.name = "";
      # user.email = "";
      merge.conflictstyle = "zdiff3";
      diff.colorMoved = "default";
      init.defaultBranch = "main";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Catppuccin Mocha";
    };
  };

  # gh: `gh auth login` continua manual (o token não vai para o repositório)
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.lazygit.enable = true;
}
