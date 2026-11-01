# CLAUDE.md

Guia para o Claude trabalhar neste repositório.

## O que é

Flake NixOS + Home Manager (NixOS 26.05) de quatro hosts: `notebook`, `desktop`, `server` (VM Proxmox, 10.0.76.8, com todos os serviços nativos: Nextcloud, mídia, monitoramento) e `pi` (Raspberry Pi 4, aarch64: roteador Tailscale, DNS Technitium, proxy Nginx, LDAP lldap, TURN, FTP dos jogos do Switch, status e backup no Google Drive, gerado como imagem SD). Usuário: `dio`. O ambiente gráfico (SwayFX, JetBrainsMono Nerd Font, teclado `br`) foi migrado de `yocaslu/dotfiles` (chezmoi).

## Onde mexer

- Papéis do sistema: `modules/nixos/*.nix`. Cada papel importa sua parte do Home Manager (`common.nix` → `home/cli`, `workstation.nix` → `home/desktop`).
- Hosts: `hosts/<host>/default.nix` só escolhe papéis e boot. O `hardware-configuration.nix` do `desktop` é o real, gerado na máquina (já instalada); os de `notebook` e `server` ainda são provisórios; o `pi` não tem (a imagem SD define os discos). A arquitetura de cada host fica em `hosts` no `flake.nix`.
- Configs do usuário: `home/cli` (terminal, todas as máquinas) e `home/desktop` (gráfico).
- Dados convertidos dos dotfiles ficam em `home/*/settings/*.nix` (attrsets, ou funções de `colors` quando usam a paleta); arquivos que não viram Nix (CSS, Lua, scripts, módulos zsh) ficam em `home/*/files/`.
- Homelab: serviços nativos, sem containers; domínio e IPs em `modules/nixos/homelab.nix`, passo a passo em `docs/homelab.md`. Serviço novo na VM = papel em `modules/nixos/` + entrada em `dionix.proxy.hosts` no `hosts/pi` (vira checagem no status automaticamente). Pacotes fora do nixpkgs ficam em `pkgs/<nome>/package.nix` e entram pelo overlay.
- Backup: hosts NixOS usam `modules/nixos/backup.nix` (`dionix.backup.paths`); os demais (Proxmox, NAS, VMs Ubuntu) usam `scripts/backup/restic-gdrive.sh`.
- Pacotes do unstable: `pkgs.unstable.<nome>` (overlay em `overlays/default.nix`).

## Convenções

- Mantenha os atalhos estilo Vim e o visual TUI (cantos retos, bordas de 1px).
- Cores não ficam fixas: os temas estão em `home/desktop/themes.nix` (Stylix, trocados pelo comando `theme`). Novas configs leem `config.dionix.colors` ou passam o texto por `config.dionix.render` (tokens `@base00@`, `@base00-hex@`, `@base00-rgb@`). O padrão, usado também no `server`, é o Catppuccin Mocha (`home/cli/colors.nix`).
- Comentários em português.
- Serviços gráficos usam `wayland.systemd.target = "sway-session.target"` para não subirem no XFCE.
- Todo alias ou função novo do zsh precisa de uma seção `## nome` em `home/cli/files/zsh/commands.md` (lido pelo `cmds`).
- Formate com `nix fmt` (nixfmt).

## Validação

```sh
nix flake check                                                        # avalia todos os hosts
nix build .#nixosConfigurations.notebook.config.home-manager.users.dio.home-files   # valida a config do Sway e roda o shellcheck nos scripts
nix build .#nixosConfigurations.<host>.config.system.build.toplevel    # build completo
nix build .#checks.x86_64-linux.theme-script                           # testes do comando theme
nix build .#packages.aarch64-linux.pi-image                            # imagem SD do Pi (precisa da emulação ARM do desktop)
```

## Cuidados

- Não rode `nixos-rebuild switch` sem o usuário pedir.
- Não coloque segredos, senhas ou chaves privadas no repositório: os serviços leem de `/var/lib/secrets` (gerados no primeiro boot ou criados à mão; use sops-nix ou agenix se precisar versionar).
- IPs do homelab (Pi `10.42.1.2`, Proxmox `10.42.1.20`, pfSense LAN `10.0.76.1`, NAS `10.0.76.6`, VM server `10.0.76.8`; DietPi `10.42.1.10`) e saídas de monitor (`HDMI-A-1`, `eDP-1`) são do setup do usuário; não altere sem pedido.
- Commits no estilo Conventional Commits (`feat(sway): …`, `fix(waybar): …`).
