# dionix

Configuração NixOS + [Home Manager](https://github.com/nix-community/home-manager) das minhas máquinas, num único flake:

| Host | Máquina | Papéis |
|---|---|---|
| `notebook` | Notebook de desenvolvimento (ideapad 3) | base + estação de trabalho + notebook (Wi-Fi, Bluetooth, touchpad, tampa) |
| `desktop` | Desktop de desenvolvimento (rede cabeada) | base + estação de trabalho |
| `server` | VM no Proxmox do homelab (10.0.76.8) | base + VM Proxmox + Nextcloud (Collabora, Whiteboard, Talk) + mídia (Jellyfin, Arr, qBittorrent) + Prometheus/Grafana, tudo nativo |
| `pi` | Raspberry Pi 4 (aarch64) | base + imagem SD + roteador Tailscale + DNS (Technitium) + proxy reverso (Nginx) + LDAP (lldap) + TURN + FTP dos jogos do Switch + status (Gatus) + backup |

A base é o **NixOS 26.05** (estável). Pacotes pontuais podem vir do `nixos-unstable` com `pkgs.unstable.<pacote>`.

O ambiente gráfico é o mesmo dos meus [dotfiles](https://github.com/yocaslu/dotfiles), agora declarado em Nix: **SwayFX** + Waybar + Fuzzel + Alacritty, tema **Catppuccin Mocha** e fonte **JetBrainsMono Nerd Font**. O **XFCE** fica como sessão alternativa, escolhida na tela de login.

## Estrutura

```
flake.nix                  hosts, inputs e o `nix flake check`
flake.lock                 versões fixadas (nixpkgs, home-manager, plugins)
overlays/default.nix       pkgs.unstable, plugins do tmux e pacotes próprios (pkgs/)
pkgs/nut/                  NUT (servidor de títulos do Switch), que não está no nixpkgs (pausado)
docs/homelab.md            passo a passo dos serviços do homelab (rede, NAS, painéis)
hosts/<host>/              default.nix (papéis do host) + hardware-configuration.nix
modules/nixos/
  common.nix               Nix, nh, idioma, usuário dio, SSH, zsh + home/cli
  workstation.nix          SwayFX, XFCE, tuigreet, áudio, fontes, podman + home/desktop
  laptop.nix               Bluetooth, touchpad, tampa
  desktop.nix              Desempenho e baixo uso de recursos (só no desktop)
  docker-host.nix          Docker, limpeza automática, oci-containers (sem uso: tudo é nativo)
  proxmox-vm.nix           agente QEMU, console serial, GRUB
  raspberry-pi.nix         imagem do cartão SD do Pi 4, menos escrita no cartão
  tailscale-router.nix     subnet router e exit node da tailnet
  dns-server.nix           Technitium DNS Server (painel na 5380, só pelo proxy)
  reverse-proxy.nix        Nginx: <nome>.<domínio> → serviço, HTTPS opcional (ACME DNS-01)
  ldap.nix                 lldap: login central (LDAP/LDAPS + painel web)
  backup.nix               restic diário para o Google Drive (rclone)
  homelab.nix              domínio e IPs do homelab, usados pelos papéis abaixo
  nas.nix                  compartilhamentos NFS do NAS, grupo media
  nextcloud.nix            Nextcloud + Collabora + Whiteboard + Talk (sinalização + Janus)
  talk-turn.nix            coturn (TURN das chamadas), no Pi
  media.nix                Jellyfin, Seerr, suite Arr, qBittorrent
  switch-nut.nix           NUT para o Tinfoil (pausado, fora dos hosts)
  switch-ftp.nix           FTP só leitura dos jogos do Switch, no Pi
  monitoring.nix           Prometheus + Grafana
  node-exporter.nix        métricas dos hosts para o Prometheus
  status.nix               página de status (Gatus), no Pi
home/
  cli/                     zsh, Bash, git, tmux, Neovim, Helix, Vim, yazi, btop…
  desktop/                 Sway, Waybar, menus, notificações, tema e apps
  */settings/*.nix         configs convertidas dos dotfiles (TOML/YAML/JSON → Nix)
  */files/                 o que continua como arquivo (CSS, Lua, scripts, módulos zsh)
```

Cada papel em `modules/nixos/` traz junto a parte do Home Manager que lhe corresponde: a `common.nix` importa `home/cli` em todas as máquinas, e a `workstation.nix` importa `home/desktop` só no notebook e no desktop. Os servidores recebem o mesmo shell e os mesmos editores, sem nada gráfico.

## Instalação

### Instalação automática (notebook ou desktop)

Com a ISO do NixOS iniciada em modo UEFI, o script **apaga o disco escolhido**, particiona, clona o repositório, gera a configuração de hardware, instala e pede a senha de `dio`:

```sh
curl -fsSL https://raw.githubusercontent.com/yocaslu/dionix/main/scripts/install-nixos.sh -o install-nixos.sh
sudo bash install-nixos.sh desktop /dev/sda
```

Depois do primeiro boot, commite o `hardware-configuration.nix` gerado em `~/repos/dionix`.

### Notebook ou desktop (manual)

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

Todos os serviços rodam nativos, sem containers. O passo a passo (rede, NAS, primeiro boot e ligação dos serviços pelos painéis) está em [`docs/homelab.md`](docs/homelab.md).

1. Crie a VM (SeaBIOS, disco VirtIO, **QEMU Guest Agent** ativado) e instale o NixOS pela ISO mínima, com o disco em `/dev/sda`.
2. Gere o `hosts/server/hardware-configuration.nix` dentro da VM e aplique com `sudo nixos-rebuild switch --flake .#server`.

Depois da primeira instalação, dá para aplicar mudanças a partir do desktop:

```sh
nixos-rebuild switch --flake .#server --target-host dio@10.0.76.8 --sudo
```

Para mais servidores, copie `hosts/server/` para `hosts/<nome>/` e adicione o nome (e a arquitetura) em `hosts` no `flake.nix`.

### Raspberry Pi (roteador, DNS e proxy)

O `pi` não tem instalador: o flake gera a imagem do cartão SD já configurada. O `desktop` emula ARM (`boot.binfmt.emulatedSystems`), então a imagem compila nele depois de um `rebuild`:

```sh
nix build .#packages.aarch64-linux.pi-image
zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

1. Ligue o Pi no cabo e reserve o IP `10.42.1.2` para ele no DHCP do roteador (ou fixe em `hosts/pi/default.nix`).
2. Entre com `ssh dio@10.42.1.2` (só chave; o `sudo` não pede senha) e rode `sudo tailscale up`.
3. Crie o token da Cloudflare (permissão *Zone → DNS → Edit* em `vault76.com.br`) e grave no Pi:
   `sudo install -Dm600 /dev/stdin /var/lib/secrets/acme.env <<< 'CF_DNS_API_TOKEN=...'` e `sudo systemctl restart acme-vault76.com.br`.
4. No painel do Tailscale, aprove as rotas (`10.42.1.0/24`) e o exit node do `pi`, e em **DNS → Nameservers** aponte o DNS global para o IP 100.x do Pi.
5. Abra o painel do Technitium (`ssh -L 5380:localhost:5380 dio@10.42.1.2` e `http://localhost:5380`), defina a senha de admin e os encaminhadores (1.1.1.1, 8.8.8.8), e crie a zona `vault76.com.br` com um registro `*` (A) para `10.42.1.2`. A partir daí o painel também fica em `https://dns.vault76.com.br`.
6. Aponte o DNS do DHCP do roteador para o Pi, se quiser que a rede toda use o Technitium.

#### Acesso às VMs (rota pelo pfSense)

O Pi fica na rede de casa e as VMs atrás do pfSense. Em vez de NAT por serviço, o Pi tem uma rota para `10.0.76.0/24` e `10.0.21.0/24` pela WAN do pfSense:

1. Reserve um IP fixo para a WAN do pfSense no roteador da operadora e preencha `pfsenseWan` em `hosts/pi/default.nix`.
2. No pfSense, em *Firewall → Rules → WAN*, libere a origem `10.42.1.2` para *LAN net* e *DEV net*. *Block private networks* precisa ficar desligado na WAN.
3. Para abrir o painel do pfSense pelo proxy (`pfsense.vault76.com.br`), adicione esse nome em *System → Advanced → Alternate Hostnames* (senão o pfSense acusa DNS rebind).
4. No Nextcloud, troque o `TRUSTED_PROXIES` por `10.42.1.2`: com a rota, o Nextcloud vê o IP real do Pi.
5. Desligue *Accept Routes* no Tailscale do pfSense: ele aceitaria a `10.42.1.0/24` que o Pi anuncia, que é a rede da própria WAN.

Os serviços do proxy ficam em `dionix.proxy.hosts`: uma entrada pode ser só o endereço ou ter rotas extras, uploads grandes e HSTS (veja o Nextcloud). O certificado é um curinga `*.vault76.com.br`, renovado sozinho pelo `security.acme`.

#### Login central (lldap)

Antes do primeiro boot com o LDAP, crie a senha do admin: `sudo install -Dm600 /dev/stdin /var/lib/secrets/lldap-admin-pass <<< 'senha-forte'`. O painel fica em `https://ldap.vault76.com.br`. Os serviços usam `ldaps://ldap.vault76.com.br:6360` com base `dc=vault76,dc=com,dc=br`; crie um usuário só para o bind de cada serviço, no grupo `lldap_strict_readonly`.

#### Backup

O Pi faz backup diário no Google Drive (`gdrive:homelab/pi`). A configuração do Drive, da senha e dos outros hosts (Proxmox, NAS) está em [`scripts/backup/README.md`](scripts/backup/README.md).

Atualizações a partir do desktop:

```sh
nixos-rebuild switch --flake .#pi --target-host dio@<ip-do-pi> --sudo
```

## Uso diário

| Comando | O que faz |
|---|---|
| `rebuild` | Aplica a configuração (`nh os switch`) |
| `syu` | Atualiza o `flake.lock` e aplica (`nh os switch --update`) |
| `nh os switch --dry` | Mostra o que mudaria, sem aplicar |
| `nix flake check` | Avalia todos os hosts (sem compilar nada) |
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
