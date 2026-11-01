# Homelab

Dois hosts NixOS, na mesma rede de casa (`10.42.1.0/24`), sem hypervisor e sem containers:

| Host | Máquina | O que roda |
|---|---|---|
| `pi` | Raspberry Pi 4, `10.42.1.2` | proxy reverso (HTTPS de tudo), DNS (Technitium), LDAP (lldap), página de status (Gatus), roteador Tailscale da rede de casa e exit node |
| `server` | i7-4790, 32 GB, RX 580, `10.42.1.20` | Nextcloud + Collabora + Whiteboard + Talk (sinalização e Janus), Jellyfin, Seerr, suite Arr, qBittorrent, FTP dos jogos do Switch, Prometheus + Grafana |

O `server` guarda tudo num espelho ZFS de dois HDs de 1 TB (1 TB úteis, aguenta perder um disco); o sistema fica num HD de 500 GB.

```
cliente ──HTTPS──▶ Pi (Nginx, *.vault76.com.br) ──HTTP──▶ server ──▶ ZFS (tank)
Switch ──FTP──▶ server
tailnet ──▶ Pi (rota da 10.42.1.0/24) ──▶ server
```

## Endereços

| Serviço | Endereço |
|---|---|
| Nextcloud | `nextcloud.vault76.com.br` |
| Collabora / Whiteboard / Talk | `collabora.` / `whiteboard.` / `talk.` (usados pelo Nextcloud) |
| Jellyfin | `jellyfin.vault76.com.br` |
| Pedidos (Seerr) | `pedidos.vault76.com.br` |
| Sonarr, Radarr, Lidarr, Readarr, Prowlarr, Bazarr | `<nome>.vault76.com.br` |
| qBittorrent | `qbittorrent.vault76.com.br` |
| Grafana | `grafana.vault76.com.br` |
| Status | `status.vault76.com.br` (Pi) |
| LDAP / DNS | `ldap.` / `dns.vault76.com.br` (Pi) |
| Jogos do Switch (FTP) | `ftp://10.42.1.20`, usuário `switch`, só leitura e só na rede de casa |

## Tailscale

O Pi anuncia a `10.42.1.0/24` (`dionix.tailscaleRouter.routes` em `hosts/pi/default.nix`): de fora, pela tailnet, tudo é alcançado por ele. Aprove a rota e o exit node no painel do Tailscale (*Machines → pi → Edit route settings*) e, em *DNS → Nameservers*, aponte o DNS global para o IP 100.x do Pi.

## 1. Rede

No roteador da operadora, reserve por DHCP:

| IP | Para |
|---|---|
| `10.42.1.2` | Pi |
| `10.42.1.20` | server: o **MAC do adaptador USB Gigabit** (o server pega IP por DHCP em qualquer porta Ethernet) |

## 2. Instalar o server (nixos-anywhere)

A instalação roda do desktop, por SSH, sem pendrive: o `nixos-anywhere` entra no sistema atual (o Proxmox), troca para um instalador em memória, particiona os discos pelo `hosts/server/disko.nix` e instala o flake.

> **Apaga os três discos** (o Proxmox, as VMs e os dois HDs de 1 TB).

1. **Confira os discos.** No Proxmox, `ls -l /dev/disk/by-id/ | grep -v part` e troque em `hosts/server/disko.nix` os `/dev/sdX` pelos IDs (`/dev/disk/by-id/ata-…`): o de 500 GB em `sistema`, os dois de 1 TB em `espelho`. Os nomes `sdX` podem mudar no instalador; os IDs não.
2. **Placa de vídeo.** Com a RX 580 instalada, confira o endereço dela (`lspci | grep VGA`, costuma ser `01:00.0`) e, se for outro, ajuste o `device` do Jellyfin em `modules/nixos/media.nix`.
3. **Instale**, do desktop:

   ```sh
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#server \
     --generate-hardware-config nixos-generate-config hosts/server/hardware-configuration.nix \
     root@10.42.1.20
   ```

   O `--generate-hardware-config` sobrescreve `hosts/server/hardware-configuration.nix` com o que detectar: mantenha os módulos dos adaptadores USB (`r8152`, `ax88179_178a`) e apague eventuais `fileSystems` (vêm do disko). Faça commit do arquivo.

4. Se a máquina não voltar à rede, ligue monitor e teclado: o sistema está no ar e dá para ver o problema localmente (`journalctl -b`).

Atualizações depois, a partir do desktop:

```sh
nixos-rebuild switch --flake .#server --target-host dio@10.42.1.20 --sudo
```

## 3. Primeiro boot

Os segredos são gerados em `/var/lib/secrets` (nada vai para o repositório):

| Arquivo | Para quê |
|---|---|
| `nextcloud-admin-pass` | senha do `admin` do Nextcloud |
| `grafana-admin-pass` | senha do `admin` do Grafana |
| `talk-*`, `whiteboard.env`, `grafana-secret-key` | usados só pelos serviços |

Crie à mão:

```sh
# Senha do usuário "switch" do FTP (hash SHA-512); depois, aplique de novo a configuração
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512 | sudo install -Dm600 /dev/stdin /var/lib/secrets/switch-ftp.hash
```

E os do backup ([`docs/backup.md`](backup.md)).

Confira:

```sh
zpool status tank          # espelho ONLINE nos dois discos
vainfo --display drm --device /dev/dri/by-path/pci-0000:01:00.0-render   # VA-API da RX 580
```

## 4. Ligar os serviços pelos painéis

**Nextcloud**: Collabora, Whiteboard, Talk e a pasta *Jogos do Switch* são configurados sozinhos (`nextcloud-apps-config.service`). Confira em *Administração → Talk* que o servidor de sinalização aparece com ✔. Para o login pelo lldap, ative o app *LDAP user and group backend*:

| Campo | Valor |
|---|---|
| Servidor | `ldaps://ldap.vault76.com.br`, porta `6360` |
| Usuário (bind) | `uid=nextcloud,ou=people,dc=vault76,dc=com,dc=br` (crie no lldap, grupo `lldap_strict_readonly`) |
| Base | `dc=vault76,dc=com,dc=br` |
| Filtro de usuários | `(&(objectClass=person)(memberOf=cn=nextcloud,ou=groups,dc=vault76,dc=com,dc=br))` |
| Atributo de login | `uid` ou `mail` |

**qBittorrent**: a senha temporária do `admin` aparece em `journalctl -u qbittorrent` no primeiro start; troque em *Opções → WebUI*. Crie as categorias `filmes`, `series`, `musica` e `livros` (vão para `/srv/data/torrents/<categoria>`) e `switch` com o caminho `/srv/data/games/switch`.

**Prowlarr**: indexadores e, em *Settings → Apps*, o Sonarr, o Radarr, o Lidarr e o Readarr (`http://localhost:<porta>` e a API key de cada um). Para indexadores atrás da Cloudflare, use o FlareSolverr (`http://localhost:8191`).

**Sonarr / Radarr / Lidarr / Readarr**: *Download Client* → qBittorrent em `localhost:8081` com a categoria correspondente; *Root Folder* em `/srv/data/media/<categoria>`.

**Jellyfin**: bibliotecas em `/srv/data/media/{filmes,series,musica}`. A transcodificação na RX 580 já vem configurada. Login pelo lldap: plugin *LDAP Authentication* (mesmos dados do Nextcloud).

**Seerr**: conecte ao Jellyfin (`http://localhost:8096`), ao Sonarr e ao Radarr. **Bazarr**: ao Sonarr e ao Radarr.

**Jogos do Switch**: torrents na categoria `switch` caem em `/srv/data/games/switch`, que aparece no Nextcloud (*Jogos do Switch*, grupo `admin`) e no FTP. No Switch, no gerenciador que você usar (DBI, Tinfoil, Goldleaf…), adicione uma fonte FTP: host `10.42.1.20`, porta `21`, usuário `switch`, modo passivo.

**Grafana**: o Prometheus já é a fonte de dados. Painéis prontos: *Dashboards → New → Import* → `1860` (Node Exporter Full) e um de ZFS (procure "ZFS" em grafana.com/dashboards).

## Observações

- **Snapshots do ZFS**: a cada hora (24), dia (14) e mês (3), em `tank/data` e `tank/nextcloud`. Arquivo apagado: copie de `/srv/data/.zfs/snapshot/<snapshot>/…`.
- **Disco com defeito**: o pool continua funcionando com um disco. `zpool status` mostra qual falhou; troque e rode `zpool replace tank <antigo> /dev/disk/by-id/<novo>`.
- **Readarr**: descontinuado pelos autores em 2025. O pacote continua no nixpkgs, mas sem atualizações; se parar de funcionar, remova-o de `media.nix`.
- **RX 580**: decodifica H.264 e HEVC (8 e 10 bits) e codifica H.264 e HEVC de 8 bits. VP9 e AV1 ficam com a CPU.
- **Chamadas do Talk** funcionam em casa e pela tailnet. Para liberar pela internet, seria preciso um TURN com IP público e portas abertas no roteador.
- **Torrents**: para receber conexões de entrada, encaminhe a porta `51413` (TCP/UDP) no roteador para `10.42.1.20`.
- **NUT (servidor para o Tinfoil)**: pausado. O pacote (`pkgs/nut`) e o módulo (`modules/nixos/switch-nut.nix`) ficam no repositório; para voltar, importe o módulo no `server` e adicione `nut` ao proxy do Pi (com `basicAuthFile`, porque o NUT não tem login próprio).
