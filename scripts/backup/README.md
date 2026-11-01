# Backup do homelab no Google Drive

Todos os hosts fazem backup com **restic** num repositório próprio dentro de `homelab/` no Google Drive, acessado pelo **rclone**. O restic criptografa e deduplica antes de enviar: o Drive só guarda blocos cifrados, e só o que mudou sobe a cada dia.

| Host | Como | O que vai |
|---|---|---|
| `pi` (NixOS) | `modules/nixos/backup.nix` | Technitium, lldap, certificados, Tailscale, segredos |
| `server` e outros NixOS | `modules/nixos/backup.nix` (defina `dionix.backup.paths`) | o que o host declarar |
| VM `production` (Ubuntu) | [`nxctl snapshot`](https://github.com/yocaslu/nxctl) | dados do Nextcloud + dump do Postgres |
| NAS (OpenMediaVault) | este script | pastas compartilhadas |
| Proxmox | este script | `/etc/pve` + backups das VMs (vzdump) |

Retenção em todos: 7 diários, 4 semanais e 6 mensais. Cada execução também confere 1% dos dados já enviados.

## 1. Conta do Google Drive (uma vez, no desktop)

1. **Client ID próprio** (recomendado: o padrão do rclone é compartilhado e sofre limite de requisições). No [Google Cloud Console](https://console.cloud.google.com/), crie um projeto, ative a *Google Drive API*, configure a tela de consentimento (tipo *Externo*, publique o app para o token não expirar em 7 dias) e crie uma credencial *OAuth → App para computador*.
2. Gere o remote no desktop, que tem navegador:

   ```sh
   nix shell nixpkgs#rclone -c rclone config
   # n → nome: gdrive → tipo: drive → client_id/secret do passo 1
   # scope: drive.file   (o rclone só enxerga o que ele mesmo criou, não o resto do seu Drive)
   # o resto no padrão; autorize no navegador
   ```

3. O arquivo resultante (`~/.config/rclone/rclone.conf`) contém o token de acesso ao Drive: trate como senha. Ele é o mesmo para todos os hosts.

## 2. Senha dos repositórios

Gere uma senha forte (`openssl rand -base64 32`) e **guarde uma cópia fora do homelab** (gerenciador de senhas). Sem ela os backups são irrecuperáveis. Pode ser a mesma em todos os hosts.

## 3. Hosts NixOS (`pi`, `server`)

```sh
sudo install -Dm600 rclone.conf /var/lib/secrets/rclone.conf
sudo install -Dm600 /dev/stdin /var/lib/secrets/restic-password <<< 'a-senha'
sudo systemctl start restic-backups-gdrive   # primeiro backup agora
sudo restic-gdrive snapshots
```

## 4. Hosts Debian/Ubuntu (Proxmox, NAS, production)

```sh
sudo apt install restic rclone
sudo install -m755 restic-gdrive.sh /usr/local/bin/
sudo install -m644 restic-gdrive.service restic-gdrive.timer /etc/systemd/system/
sudo install -Dm600 rclone.conf /etc/restic-gdrive/rclone.conf
sudo install -Dm600 /dev/stdin /etc/restic-gdrive/password <<< 'a-senha'
sudoedit /etc/restic-gdrive/env       # veja os exemplos abaixo
sudo systemctl daemon-reload
sudo systemctl start restic-gdrive    # primeiro backup (acompanhe com journalctl -fu restic-gdrive)
sudo systemctl enable --now restic-gdrive.timer
sudo restic-gdrive.sh snapshots
```

### Proxmox

No Proxmox, crie um job em *Datacenter → Backup* para as VMs, gravando num storage local, com **Compression: none** e **Retention: keep-last 1**. Sem compressão, o restic deduplica um dia contra o outro e só sobe o que mudou (com zstd, cada dump parece um arquivo novo). Agende o job antes das 03:00.

```sh
# /etc/restic-gdrive/env
BACKUP_PATHS="/etc/pve /var/lib/vz/dump"
```

### NAS (OpenMediaVault)

As pastas compartilhadas ficam em `/srv/dev-disk-by-uuid-…/` (veja em *Storage → Shared Folders*):

```sh
# /etc/restic-gdrive/env
BACKUP_PATHS="/srv/dev-disk-by-uuid-XXXX/documentos /srv/dev-disk-by-uuid-XXXX/fotos"
BACKUP_EXCLUDES="*.tmp .recycle"
```

### VM production (Nextcloud)

O [`nxctl`](https://github.com/yocaslu/nxctl) já faz o backup consistente: liga o modo de manutenção, faz o dump do Postgres e manda os dados para o restic. Basta apontar o repositório para o Drive no `.env` dele e deixar o rclone configurado para o root:

```sh
RESTIC_REPOSITORY=rclone:gdrive:homelab/production
# rclone.conf em /root/.config/rclone/rclone.conf
```

Agende o `nxctl snapshot` com um timer do systemd (copie `restic-gdrive.service`/`.timer` trocando o `ExecStart`).

## Restaurar

```sh
sudo restic-gdrive snapshots                                  # NixOS
sudo restic-gdrive.sh snapshots                               # Debian/Ubuntu
sudo restic-gdrive.sh restore latest --target /tmp/restore --include /etc/pve
sudo restic-gdrive.sh mount /mnt/restic                       # navegar pelos snapshots
```

## Espaço

A conta tem 5 TB. Acompanhe o uso real (já deduplicado e comprimido) com `restic stats --mode raw-data` em cada host. O que mais pesa são os dumps das VMs no Proxmox e os compartilhamentos do NAS; sem compressão no vzdump, o restic só sobe o que mudou de um dia para o outro.

O Google Drive limita uploads a 750 GB por dia por conta: o primeiro backup do NAS e das VMs pode levar mais de um dia. O restic retoma de onde parou na execução seguinte.
