# Homelab: serviços nativos

Todos os serviços rodam nativos no NixOS, sem containers, em dois hosts:

| Host | Onde | O que roda |
|---|---|---|
| `pi` | Raspberry Pi 4, `10.42.1.2` (rede de casa) | proxy reverso (HTTPS de tudo), DNS (Technitium), LDAP (lldap), TURN do Talk (coturn), FTP dos jogos do Switch (vsftpd), página de status (Gatus), roteador Tailscale da rede de casa (`10.42.1.0/24`) e exit node |
| `server` | VM no Proxmox, `10.0.76.8` (LAN do pfSense) | Nextcloud + Collabora + Whiteboard + Talk (sinalização e Janus), Jellyfin, Seerr, suite Arr, qBittorrent, Prometheus + Grafana |

Os arquivos grandes (mídia, downloads, jogos, dados do Nextcloud) ficam no NAS (OpenMediaVault, `10.0.76.6`) e chegam à VM por NFS.

Na tailnet, cada rede tem o seu roteador:

| Rede | Quem anuncia | Configuração |
|---|---|---|
| `10.42.1.0/24` (casa: Pi, Proxmox, roteador da operadora) | Tailscale do **Pi** | `dionix.tailscaleRouter.routes` em `hosts/pi/default.nix` |
| `10.0.76.0/24` (LAN: VMs e NAS) e `10.0.21.0/24` (DEV) | Tailscale do **pfSense** | pacote Tailscale do pfSense |

Aprove as rotas de cada um no painel do Tailscale (*Machines → … → Edit route settings*).

```
cliente ──HTTPS──▶ Pi (Nginx, *.vault76.com.br) ──HTTP──▶ VM server ──NFS──▶ NAS
   │                     ▲
   └──UDP (chamadas)──▶ Pi (coturn) ──▶ Janus na VM
```

## Endereços

| Serviço | Endereço | Onde |
|---|---|---|
| Nextcloud | `nextcloud.vault76.com.br` | VM |
| Collabora / Whiteboard / Talk | `collabora.` / `whiteboard.` / `talk.` | VM (usados pelo Nextcloud) |
| Jellyfin | `jellyfin.vault76.com.br` | VM |
| Pedidos (Seerr) | `pedidos.vault76.com.br` | VM |
| Sonarr, Radarr, Lidarr, Readarr, Prowlarr, Bazarr | `<nome>.vault76.com.br` | VM |
| qBittorrent | `qbittorrent.vault76.com.br` | VM |
| Jogos do Switch (FTP) | `ftp://10.42.1.2`, usuário `switch`, só leitura e só na rede de casa | Pi |
| Grafana | `grafana.vault76.com.br` | VM |
| Status | `status.vault76.com.br` | Pi |
| LDAP / DNS | `ldap.` / `dns.vault76.com.br` | Pi |
| Proxmox / pfSense | `proxmox.` / `pfsense.vault76.com.br` | — |

## 1. Rede (pfSense e roteador)

1. **WAN do pfSense com IP fixo** no roteador da operadora; preencha `pfsenseWan` em `hosts/pi/default.nix`.
2. **Regra na WAN**: origem `10.42.1.2`, destino *LAN net* e *DEV net*, protocolo *any* (HTTP do proxy e a mídia das chamadas).
3. **Sem NAT da LAN para o Pi**: em *Firewall → NAT → Outbound*, mude para *Hybrid* e crie uma regra *Do not NAT* com origem *LAN net* e destino `10.42.1.0/24`. Sem ela, o pfSense troca o IP da VM pelo da WAN e o coturn descarta a mídia das chamadas (e o Nextcloud deixa de ver o IP real do Pi).
4. **Reserva da VM**: *Services → DHCP Server → LAN → Static Mappings*, MAC da VM nova → `10.0.76.8`.
5. Desligue *Accept Routes* no Tailscale do pfSense (ele aceitaria a `10.42.1.0/24` que o Pi anuncia, que é a rede da própria WAN).

## 2. NAS (OpenMediaVault)

Crie dois compartilhamentos e exporte por NFS para `10.0.76.8` com `rw,subtree_check,root_squash`:

| Compartilhamento | Dono no NAS | Conteúdo |
|---|---|---|
| `data` | grupo GID **2000**, `chmod 2775` (setgid) | `torrents/{filmes,series,musica,livros}`, `media/{filmes,series,musica,livros}`, `games/switch` |
| `nextcloud` | usuário UID **2001**, `chmod 0770` | arquivos do Nextcloud |

Exporte o `data` também para o Pi (`10.42.1.2`), **só leitura** (`ro`): ele monta só a pasta `games/switch` para o FTP do Switch.

Downloads e biblioteca no **mesmo** compartilhamento: os Arr importam por hardlink, sem copiar. Confira o caminho exportado com `showmount -e 10.0.76.6` e, se não for `/data` e `/nextcloud`, ajuste `dionix.nas.shares.<nome>.path`.

## 3. Instalar a VM `server`

1. VM nova no Proxmox (SeaBIOS, disco VirtIO, QEMU Guest Agent, 4+ vCPUs e 8+ GB de RAM: o Collabora e o Jellyfin são os mais pesados). Instale pela ISO mínima.
2. Gere o `hosts/server/hardware-configuration.nix` dentro da VM e aplique: `sudo nixos-rebuild switch --flake .#server`.
3. No primeiro boot, os segredos são gerados em `/var/lib/secrets` (nada vai para o repositório):

| Arquivo | Para quê |
|---|---|
| `nextcloud-admin-pass` | senha do `admin` do Nextcloud |
| `grafana-admin-pass` | senha do `admin` do Grafana |
| `turn-secret` | **copie para o Pi**: `/var/lib/secrets/turn-secret` (root, `chmod 600`), depois `sudo systemctl restart coturn` lá |
| `talk-*`, `whiteboard.env`, `grafana-secret-key` | usados só pelos serviços |

## 4. Pi: segredos dos serviços novos

```sh
# TURN (o mesmo arquivo gerado na VM)
sudo install -Dm600 turn-secret /var/lib/secrets/turn-secret

# Senha do usuário "switch" do FTP (hash SHA-512); depois, aplique de novo a configuração
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512 | sudo install -Dm600 /dev/stdin /var/lib/secrets/switch-ftp.hash
```

## 5. Ligar os serviços pelos painéis

**Nextcloud**: Collabora, Whiteboard e Talk são configurados sozinhos (`nextcloud-apps-config.service`). Confira em *Administração → Talk* que o servidor de sinalização aparece com ✔. Para o login pelo lldap, ative o app *LDAP user and group backend*:

| Campo | Valor |
|---|---|
| Servidor | `ldaps://ldap.vault76.com.br`, porta `6360` |
| Usuário (bind) | `uid=nextcloud,ou=people,dc=vault76,dc=com,dc=br` (crie no lldap, grupo `lldap_strict_readonly`) |
| Base | `dc=vault76,dc=com,dc=br` |
| Filtro de usuários | `(&(objectClass=person)(memberOf=cn=nextcloud,ou=groups,dc=vault76,dc=com,dc=br))` |
| Atributo de login | `uid` ou `mail` |

**qBittorrent**: a senha temporária do `admin` aparece em `journalctl -u qbittorrent` no primeiro start. Troque-a em *Opções → WebUI*. Crie as categorias `filmes`, `series`, `musica` e `livros`.

**Prowlarr**: adicione os indexadores e, em *Settings → Apps*, o Sonarr, o Radarr, o Lidarr e o Readarr (`http://localhost:<porta>` e a API key de cada um). Para indexadores atrás da Cloudflare, use o FlareSolverr (`http://localhost:8191`).

**Sonarr / Radarr / Lidarr / Readarr**: *Download Client* → qBittorrent em `localhost:8081` com a categoria correspondente; *Root Folder* em `/mnt/nas/data/media/<categoria>`.

**Jellyfin**: bibliotecas em `/mnt/nas/data/media/{filmes,series,musica}`. Login pelo lldap: plugin *LDAP Authentication* (mesmos dados do Nextcloud).

**Seerr**: conecte ao Jellyfin (`http://localhost:8096`), ao Sonarr e ao Radarr.

**Bazarr**: conecte ao Sonarr e ao Radarr (`http://localhost:<porta>`).

**Jogos do Switch**:

- **qBittorrent**: crie a categoria `switch` com o caminho `/mnt/nas/data/games/switch`. Torrents nessa categoria vão direto para a pasta de jogos.
- **Nextcloud**: a pasta aparece para o grupo `admin` como armazenamento externo *Jogos do Switch* (configurado sozinho pelo `nextcloud-apps-config.service`). Dá para renomear, organizar e apagar pelo navegador. Para liberar a outros usuários, *Administração → Armazenamento externo*.
- **No Switch**: no gerenciador que você usar (DBI, Tinfoil, Goldleaf…), adicione uma fonte FTP com host `10.42.1.2`, porta `21`, usuário `switch` e a senha do passo 4, modo passivo. O FTP só aceita conexões da rede de casa (`10.42.1.0/24`) e é só leitura.

**Grafana**: o Prometheus já é a fonte de dados. Painel dos hosts: *Dashboards → New → Import → 1860*. No Proxmox e no NAS, `apt install prometheus-node-exporter` para eles aparecerem.

## Observações

- **NUT (servidor para o Tinfoil)**: pausado. O pacote (`pkgs/nut`) e o módulo (`modules/nixos/switch-nut.nix`) ficam no repositório; para voltar, importe o módulo no `server` e adicione `nut` ao proxy do Pi (com `basicAuthFile`, porque o NUT não tem login próprio).

- **Readarr**: o projeto foi descontinuado pelos autores em 2025. O pacote continua no nixpkgs, mas sem atualizações; se ele parar de funcionar, remova-o de `media.nix`.
- **Chamadas do Talk** só funcionam em casa e pela tailnet (sem portas abertas na internet). Para liberar de fora, o coturn precisaria de IP público e portas abertas no roteador e no pfSense.
- **Transcodificação por hardware no Jellyfin**: passe a GPU (ou iGPU) para a VM no Proxmox e ative `services.jellyfin.hardwareAcceleration` em `media.nix`.
- **Torrents**: para receber conexões de entrada, encaminhe a porta `51413` (TCP/UDP) no roteador da operadora → WAN do pfSense → `10.0.76.8`.
- **Backup**: a VM faz backup diário da configuração dos serviços e do dump do Postgres (`gdrive:homelab/server`). Os arquivos do NAS entram no backup do próprio NAS ([`scripts/backup`](../scripts/backup/README.md)).
