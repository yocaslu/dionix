# CLAUDE.md

Guia para o Claude trabalhar neste repositório.

## O que é

Flake NixOS + Home Manager (NixOS 26.05) de três hosts: `notebook`, `desktop` e `server` (VM Proxmox com Docker). Usuário: `dio`. O ambiente gráfico (SwayFX, Catppuccin Mocha, JetBrainsMono Nerd Font, teclado `br`) foi migrado de `yocaslu/dotfiles` (chezmoi).

## Onde mexer

- Papéis do sistema: `modules/nixos/*.nix`. Cada papel importa sua parte do Home Manager (`common.nix` → `home/cli`, `workstation.nix` → `home/desktop`).
- Hosts: `hosts/<host>/default.nix` só escolhe papéis e boot. Os `hardware-configuration.nix` do repositório são provisórios.
- Configs do usuário: `home/cli` (terminal, todas as máquinas) e `home/desktop` (gráfico).
- Dados convertidos dos dotfiles ficam em `home/*/settings/*.nix` (attrsets puros); arquivos que não viram Nix (CSS, Lua, scripts, módulos zsh) ficam em `home/*/files/`.
- Pacotes do unstable: `pkgs.unstable.<nome>` (overlay em `overlays/default.nix`).

## Convenções

- Mantenha o Catppuccin Mocha (base `#1e1e2e`, surface `#313244`, texto `#cdd6f4`, mauve `#cba6f7`, vermelho `#f38ba8`), atalhos estilo Vim e o visual TUI (cantos retos, bordas de 1px).
- Comentários em português.
- Serviços gráficos usam `wayland.systemd.target = "sway-session.target"` para não subirem no XFCE.
- Todo alias ou função novo do zsh precisa de uma seção `## nome` em `home/cli/files/zsh/commands.md` (lido pelo `cmds`).
- Formate com `nix fmt` (nixfmt).

## Validação

```sh
nix flake check                                                        # avalia os 3 hosts
nix build .#nixosConfigurations.notebook.config.home-manager.users.dio.home-files   # valida a config do Sway e roda o shellcheck nos scripts
nix build .#nixosConfigurations.<host>.config.system.build.toplevel    # build completo
```

## Cuidados

- Não rode `nixos-rebuild switch` sem o usuário pedir.
- Não coloque segredos, senhas ou chaves privadas no repositório (use sops-nix ou agenix se precisar).
- IPs do homelab (DietPi `10.42.1.10`, Proxmox `10.42.1.20`) e saídas de monitor (`HDMI-A-1`, `eDP-1`) são do setup do usuário; não altere sem pedido.
- Commits no estilo Conventional Commits (`feat(sway): …`, `fix(waybar): …`).
