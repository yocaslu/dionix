# forge: o desktop vira servidor headless

Data: 2026-11-09

Sub-projeto 1 do forge.

## Objetivo

Transformar o host `desktop` no servidor headless `forge`, em `10.42.1.3`,
convertendo a máquina já instalada, sem reinstalar. O forge fica pronto para
compilar com os 8 GB de RAM e o SSD de 240 GB da máquina, e aparece no
monitoramento do server.

## Requisitos

- `hosts/desktop` vira `hosts/forge`, com o `hardware-configuration.nix` real da
  máquina sem mudança. A entrada `desktop` em `hosts` no `flake.nix` vira `forge`.
- O forge importa só o `common.nix` (com o `home/cli`) e o `node-exporter.nix`.
  Saem o `workstation.nix` e o `desktop.nix`; o `desktop.nix` é apagado, porque
  só esse host o usava.
- Rede como no `hosts/server/base.nix`: systemd-networkd, DHCP em qualquer porta
  Ethernet. O IP `10.42.1.3` vem de uma reserva no roteador, feita pelo usuário.
- Opção `dionix.homelab.forge` (padrão `10.42.1.3`) no `homelab.nix`.
- Builds dentro de 8 GB: `max-jobs = 1`, `cores = 4`; zram (o do `common.nix`)
  mais um swapfile de 8 GB; daemon do Nix com prioridade de CPU e de E/S `idle`.
- Disco: o `nh clean` do `common.nix` continua; `min-free` e `max-free` do Nix
  limpam o store sozinhos quando o SSD enche.
- Node exporter no forge e um alvo novo no Prometheus do server.
- `CLAUDE.md`, `docs/homelab.md` e o comentário da chave SSH `desktop` no
  `common.nix` passam a falar do forge.
- A aplicação é feita pelo usuário, com `nixos-rebuild boot --target-host` e
  reboot. Nada aqui roda `nixos-rebuild switch`.

## Fora do escopo

- Usar o forge como builder remoto ou cache das outras máquinas (próximos
  sub-projetos).
- Emulação ARM no forge. Ela vinha do `workstation.nix`; sem ele, a imagem do Pi
  passa a compilar só no notebook.
- Wake-on-LAN e suspensão do forge.
- Renomear a entrada da chave SSH no Bitwarden (o `ssh-key-restore` não roda no
  forge, que não tem o `home/desktop`).

## Arquitetura

### Host: `hosts/forge/default.nix`

Só escolhe papéis e boot, como os outros hosts:

- importa `./hardware-configuration.nix`, `common.nix`, `node-exporter.nix` e o
  papel novo `forge.nix`;
- boot igual ao do desktop: systemd-boot, `canTouchEfiVariables`,
  `linuxPackages_latest`.

O `networking.hostName` já vem do nome do host no `flake.nix` (`forge`).

### Papel: `modules/nixos/forge.nix`

**Rede.** Igual ao `hosts/server/base.nix`: `networking.useNetworkd = true` e a
rede `10-ethernet` (todas as portas Ethernet, DHCP, IPv6 por RA,
`RequiredForOnline = "routable"`). O bloco fica copiado, não compartilhado: um
módulo comum mexeria no server, que está em produção, e são poucas linhas. O
NetworkManager sai junto com o `workstation.nix`.

**Builds.**

```nix
nix = {
  settings = {
    max-jobs = 1;
    cores = 4;
    min-free = 10 * 1024 * 1024 * 1024; # 10 GiB
    max-free = 30 * 1024 * 1024 * 1024; # 30 GiB
  };
  daemonCPUSchedPolicy = "idle";
  daemonIOSchedClass = "idle";
};
swapDevices = [ { device = "/var/lib/swapfile"; size = 8 * 1024; } ];
```

- `max-jobs = 1` e `cores = 4`: um build por vez, usando os 4 núcleos do
  i5-3470, para não estourar a RAM com vários compiladores ao mesmo tempo.
- Swap: o zram do `common.nix` (zstd, 50% da RAM) tem prioridade maior que o
  swapfile, que só é usado quando o zram enche. O NixOS cria o arquivo no
  primeiro boot.
- `min-free`/`max-free`: quando sobram menos de 10 GiB durante um build, o Nix
  coleta lixo até liberar 30 GiB.

**Vem do `desktop.nix`.** `noatime` na raiz (menos escrita no SSD) e
`documentation.nixos.enable = false`. Saem a VA-API da GPU, o zram com 100% da
RAM e `swappiness` 180 (ajustes para uso só do zram, sem swap em disco), o
`NetworkManager-wait-online` e os ajustes do Sway.

### Monitoramento

- `hosts/forge` importa o `node-exporter.nix` (porta 9100, firewall aberto,
  como no Pi).
- `modules/nixos/monitoring.nix`: o job `node` ganha o alvo
  `${forge}:9100` com `labels.host = "forge"`, lendo `dionix.homelab.forge`.

### Referências ao desktop

| Arquivo | Mudança |
|---|---|
| `flake.nix` | `desktop` → `forge` em `hosts`; descrição e comentários |
| `modules/nixos/common.nix` | comentário da chave: `# forge (antigo desktop)` |
| `CLAUDE.md` | lista de hosts, `hardware-configuration.nix`, emulação ARM |
| `docs/homelab.md` | forge nas tabelas de máquinas e de IPs, seção de conversão; a gravação do HD do server passa a ser no forge |
| `README.md` | tabela de hosts, `desktop.nix`, instalação, atualizações, emulação ARM |
| `docs/backup.md` | o remote do rclone é gerado no notebook (o forge não tem navegador) |
| `scripts/install-nixos.sh` | hosts aceitos: `notebook` ou `forge` |
| `home/cli/files/zsh/commands.md` | `theme`, `ssh-key-restore` e `rpi-imager-root`: só no notebook |
| comentários | `workstation.nix`, `raspberry-pi.nix`, `home/cli/default.nix`, `hosts/server/base.nix`, `hosts/server/disko.nix`, `hosts/server-bootstrap/default.nix` |

## Aplicação (pelo usuário)

1. No roteador, reservar `10.42.1.3` para o MAC da rede cabeada do desktop.
2. Da máquina de administração, com o desktop no IP atual:

   ```sh
   nixos-rebuild boot --flake .#forge --target-host dio@<ip-atual> --sudo --ask-sudo-password
   ssh -t dio@<ip-atual> sudo reboot
   ```

3. Depois do reboot: `ssh dio@10.42.1.3`, e conferir `hostname`, `ip -br a`,
   `swapon --show` e o alvo `forge` em *Status → Targets* no Prometheus.
4. Aplicar o server (`nixos-rebuild switch --flake .#server …`) para o alvo novo
   entrar no Prometheus.

O `boot` deixa a geração atual ativa até o reboot. Se a rede não subir no forge,
a geração anterior (`desktop`) continua no menu do systemd-boot, mas para isso é
preciso monitor e teclado.

## Riscos

| Risco | Mitigação |
|---|---|
| Rede não sobe após o reboot (NetworkManager → networkd) | mesma config já validada no server; eval confere networkd ligado e NetworkManager desligado; geração anterior no menu de boot |
| Tailscale mantém o nome `desktop` | o painel atualiza o nome se não foi renomeado à mão; se não, renomear em *Machines* |
| Arquivos do `home/desktop` sobrando em `~` | o Home Manager remove os que gerou; o que já existia antes vira `.hm-bak` |

## Testes

- `nix flake check`: avalia todos os hosts; o check `forge` substitui o `desktop`.
- `nix build` do `forge` e do `server`.
- Avaliações que conferem:
  - `networking.hostName = "forge"`, `useNetworkd = true`, `networkmanager.enable = false`;
  - `max-jobs = 1`, `cores = 4`, `min-free`/`max-free`, daemon `idle`;
  - swapfile de 8 GB e zram ligados;
  - node exporter ligado no forge;
  - o Prometheus do server com o alvo `10.42.1.3:9100` e `host = "forge"`;
  - o Home Manager do forge sem o Sway (`wayland.windowManager.sway.enable` falso);
  - nenhuma menção ao host `desktop` fora do histórico (`grep`).
