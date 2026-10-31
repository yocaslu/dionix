# Editores: Neovim (NvChad), Helix e Vim.
{ lib, pkgs, ... }:
{
  # Neovim baseado no NvChad v2.5. O lazy.nvim continua baixando os plugins,
  # mas os LSPs, formatadores e o compilador do treesitter vêm do Nix: os
  # binários que o Mason baixa não rodam no NixOS sem ajustes.
  programs.neovim = {
    enable = true;
    withPython3 = false;
    withRuby = false;
    extraPackages = with pkgs; [
      # LSPs de configs/lspconfig.lua
      vscode-langservers-extracted # html, cssls
      gopls
      rust-analyzer
      pyright
      lua-language-server
      # Formatador de configs/conform.lua
      stylua
      # Treesitter compila os parsers; o lazy.nvim precisa do git
      gcc
      gnumake
      tree-sitter
      git
      ripgrep
      fd
      unzip
    ];
  };
  # Só init.lua e lua/ ficam no Nix: o lazy-lock.json é gravado pelo lazy.nvim
  # em ~/.config/nvim e precisa continuar editável.
  xdg.configFile = {
    "nvim/init.lua".source = ./files/nvim/init.lua;
    "nvim/lua".source = ./files/nvim/lua;
    "nvim/.stylua.toml".source = ./files/nvim/.stylua.toml;
  };

  programs.helix = {
    enable = true;
    settings = import ./settings/helix.nix // {
      theme = lib.mkDefault "catppuccin_mocha";
    };
    languages = import ./settings/helix-languages.nix;
    extraPackages = with pkgs; [
      pyright
      ruff
      black
    ];
  };

  programs.vim = {
    enable = true;
    extraConfig = builtins.readFile ./files/vimrc;
  };
}
