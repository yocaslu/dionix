# dionix

Configuração NixOS + [Home Manager](https://github.com/nix-community/home-manager) das minhas máquinas, num único flake:

| Host | Máquina | Papéis |
|---|---|---|
| `notebook` | Notebook de desenvolvimento (ideapad 3) | base + estação de trabalho + notebook (Wi-Fi, Bluetooth, touchpad, tampa) |
| `desktop` | Desktop de desenvolvimento (rede cabeada) | base + estação de trabalho |
| `server` | VM no Proxmox do homelab | base + VM Proxmox + host Docker |

A base é o **NixOS 26.05** (estável). Pacotes pontuais podem vir do `nixos-unstable` com `pkgs.unstable.<pacote>`.

O ambiente gráfico é o mesmo dos meus [dotfiles](https://github.com/yocaslu/dotfiles), agora declarado em Nix: **SwayFX** + Waybar + Fuzzel + Alacritty, tema **Catppuccin Mocha** e fonte **JetBrainsMono Nerd Font**. O **XFCE** fica como sessão alternativa, escolhida na tela de login.

## Estrutura

```
flake.nix                  hosts, inputs e o `nix flake check`
flake.lock                 versões fixadas (nixpkgs, home-manager, plugins)
overlays/default.nix       pkgs.unstable e plugins do tmux que não estão no nixpkgs
hosts/<host>/              default.nix (papéis do host) + hardware-configuration.nix
modules/nixos/
  common.nix               Nix, nh, idioma, usuário dio, SSH, zsh + home/cli
  workstation.nix          SwayFX, XFCE, tuigreet, áudio, fontes, podman + home/desktop
  laptop.nix               Bluetooth, touchpad, tampa
  desktop.nix              Desempenho e baixo uso de recursos (só no desktop)
  docker-host.nix          Docker, limpeza automática, oci-containers
  proxmox-vm.nix           agente QEMU, console serial, GRUB
home/
  cli/                     zsh, Bash, git, tmux, Neovim, Helix, Vim, yazi, btop…
  desktop/                 Sway, Waybar, menus, notificações, tema e apps
  */settings/*.nix         configs convertidas dos dotfiles (TOML/YAML/JSON → Nix)
  */files/                 o que continua como arquivo (CSS, Lua, scripts, módulos zsh)
```

Cada papel em `modules/nixos/` traz junto a parte do Home Manager que lhe corresponde: a `common.nix` importa `home/cli` em todas as máquinas, e a `workstation.nix` importa `home/desktop` só no notebook e no desktop. Os servidores recebem o mesmo shell e os mesmos editores, sem nada gráfico.

## Instalação

### Notebook ou desktop

1. Instale o NixOS pela ISO (instalador gráfico ou mínimo), com o usuário `dio`.
2. Clone o repositório e gere a configuração de hardware da máquina:

   ```sh
   nix-shell -p git
   git clone https://github.com/yocaslu/dionix ~/repos/dionix
   cd ~/repos/dionix
   sudo nixos-generate-config --show-hardware-config > hosts/notebook/hardware-configuration.nix
   ```

   O `hardware-configuration.nix` que está no repositório é **provisório**: serve só para o flake avaliar. Use `hosts/desktop/` no desktop.

3. Aplique (o flake precisa estar no git, inclusive o hardware-configuration novo):

   ```sh
   git add -A
   sudo nixos-rebuild switch --flake .#notebook
   ```

4. Reinicie. Na tela de login (tuigreet), escolha **Sway** ou **Xfce Session**.

Se os dotfiles do chezmoi já estiverem aplicados em `~`, o Home Manager renomeia os arquivos que vai substituir para `<arquivo>.hm-bak` em vez de falhar.

### Servidor (VM no Proxmox)

1. Crie a VM (SeaBIOS, disco SCSI/VirtIO, **QEMU Guest Agent** ativado) e instale o NixOS pela ISO mínima, com o disco em `/dev/sda`.
2. Antes do primeiro `switch`, coloque sua chave SSH pública em `users.users.dio.openssh.authorizedKeys.keys` (`modules/nixos/common.nix`): o login por senha via SSH fica desativado.
3. Gere o `hosts/server/hardware-configuration.nix` dentro da VM e aplique com `sudo nixos-rebuild switch --flake .#server`.

Depois da primeira instalação, dá para aplicar mudanças nos servidores a partir do notebook:

```sh
nixos-rebuild switch --flake .#server --target-host dio@<ip-do-servidor> --sudo
```

Para mais servidores, copie `hosts/server/` para `hosts/<nome>/` e adicione o nome na lista do `flake.nix`.

#### Containers

O `docker-host.nix` aceita as duas formas:

- **docker compose como hoje**: copie os `docker-compose.yml` e rode `docker compose up -d`. O NixOS só cuida do sistema.
- **declarados no Nix** (`virtualisation.oci-containers`, exemplo comentado no módulo): cada container vira um serviço systemd. O `compose2nix` converte os compose existentes.

## Uso diário

| Comando | O que faz |
|---|---|
| `rebuild` | Aplica a configuração (`nh os switch`) |
| `syu` | Atualiza o `flake.lock` e aplica (`nh os switch --update`) |
| `nh os switch --dry` | Mostra o que mudaria, sem aplicar |
| `nix flake check` | Avalia os três hosts (sem compilar nada) |
| `nix fmt` | Formata os arquivos `.nix` |

O `nh` também limpa gerações antigas sozinho (mantém as dos últimos 14 dias e no mínimo 5). Para voltar a uma geração anterior, escolha-a no menu do boot ou rode `sudo nixos-rebuild switch --rollback`.

O módulo `upd` da Waybar mostra há quantos dias o nixpkgs do `flake.lock` foi fixado, quando o canal tem commits novos. O clique roda o `syu`.

## O que mudou em relação aos dotfiles

A migração mantém atalhos, cores e comportamento. Algumas peças mudaram porque o NixOS faz de outro jeito:

| Antes (Arch + chezmoi) | Agora (NixOS + Home Manager) |
|---|---|
| `pacman`/`yay`, `install.sh`, `packages.yaml` | Pacotes declarados nos módulos; `syu` = `nh os switch --update` |
| `exec` no config do Sway (waybar, swaync, kanshi, cliphist, wlsunset, swayosd, autotiling, polkit, nm-applet, blueman-applet, awww-daemon) | Serviços systemd do Home Manager, ligados ao `sway-session.target` (não sobem no XFCE) |
| `fx.conf.tmpl` gerado só com o SwayFX instalado | Sempre SwayFX: o `fx.conf` entra direto na config |
| `exec_always gsettings …`, nwg-look, `papirus-folders` | `gtk`, `dconf.settings` e `catppuccin-papirus-folders` (mocha/mauve) |
| TPM e plugins do tmux | `tmuxPlugins` do nixpkgs; `tmux-ping` e `tmux-cargo` vêm de inputs do flake |
| `.chezmoiexternal.toml` (plugins do zsh, tema do bat) | `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-fzf-tab` do nixpkgs; o bat já traz o Catppuccin |
| `ya pkg add yazi-rs/flavors:catppuccin-mocha` | Flavor vindo do input `yazi-flavors` |
| Mason (LSPs do Neovim) | LSPs, stylua e compilador do treesitter vêm do Nix (`programs.neovim.extraPackages`); o lazy.nvim continua baixando os plugins |
| `updates.sh` contando pacman + AUR | Compara o nixpkgs do `flake.lock` com o canal |
| Sway iniciado pelo TTY + `environment.d` | Login pelo tuigreet; variáveis da sessão pelo Home Manager |

Ficaram de fora: as configs legadas de i3/X11 (`.xinitrc`, `.xmmp.sh`, `.screenlayout/`), o Nushell e o Xonsh, os scripts de teste em `sway/scripts/` e os aliases `fcode` (Flatpak), `install-yay` e `install-nvchad`.

## Pendências

- [ ] Gerar os `hardware-configuration.nix` reais em cada máquina.
- [ ] Preencher `user.name` e `user.email` em `home/cli/git.nix`.
- [ ] Adicionar as chaves SSH públicas em `modules/nixos/common.nix`.
- [ ] Definir a senha do usuário (`passwd`) depois da instalação.
- [ ] Conferir os temas do catppuccin/tmux: a versão do nixpkgs é a v2, que renomeou algumas opções `@catppuccin_*`.
