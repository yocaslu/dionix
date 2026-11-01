# Backup do homelab no Google Drive

Os dois hosts NixOS fazem backup diário com **restic** num repositório próprio dentro de `homelab/` no Google Drive, acessado pelo **rclone** (`modules/nixos/backup.nix`). O restic criptografa e deduplica antes de enviar: o Drive só guarda blocos cifrados, e só o que mudou sobe a cada dia.

| Host | Repositório | O que vai |
|---|---|---|
| `pi` | `gdrive:homelab/pi` | Technitium, lldap, certificados, Tailscale, segredos |
| `server` | `gdrive:homelab/server` | pool ZFS (mídia, jogos, arquivos do Nextcloud), configuração dos serviços, dump do Postgres, segredos |

Retenção: 7 diários, 4 semanais e 6 mensais. Cada execução também confere 1% dos dados já enviados. Os snapshots do ZFS (`storage.nix`) cobrem o curto prazo, sem depender da internet: recuperar algo apagado hoje é copiar de `/srv/data/.zfs/snapshot/`.

## 1. Conta do Google Drive (uma vez, no desktop)

1. **Client ID próprio** (recomendado: o padrão do rclone é compartilhado e sofre limite de requisições). No [Google Cloud Console](https://console.cloud.google.com/), crie um projeto, ative a *Google Drive API*, configure a tela de consentimento (tipo *Externo*, publique o app para o token não expirar em 7 dias) e crie uma credencial *OAuth → App para computador*.
2. Gere o remote no desktop, que tem navegador:

   ```sh
   nix shell nixpkgs#rclone -c rclone config
   # n → nome: gdrive → tipo: drive → client_id/secret do passo 1
   # scope: drive.file   (o rclone só enxerga o que ele mesmo criou, não o resto do seu Drive)
   # o resto no padrão; autorize no navegador
   ```

3. O arquivo resultante (`~/.config/rclone/rclone.conf`) contém o token de acesso ao Drive: trate como senha. Ele é o mesmo para os dois hosts.

## 2. Senha dos repositórios

Gere uma senha forte (`openssl rand -base64 32`) e **guarde uma cópia fora do homelab** (gerenciador de senhas). Sem ela os backups são irrecuperáveis. Pode ser a mesma nos dois hosts.

## 3. Em cada host

```sh
sudo install -Dm600 rclone.conf /var/lib/secrets/rclone.conf
sudo install -Dm600 /dev/stdin /var/lib/secrets/restic-password <<< 'a-senha'
sudo systemctl start restic-backups-gdrive   # primeiro backup agora
sudo restic-gdrive snapshots
```

## Restaurar

```sh
sudo restic-gdrive snapshots
sudo restic-gdrive restore latest --target /tmp/restore --include /var/lib/jellyfin
sudo restic-gdrive mount /mnt/restic     # navegar pelos snapshots
```

## Espaço

A conta tem 5 TB e o pool tem 1 TB úteis: cabe com folga. Acompanhe o uso real (já deduplicado e comprimido) com `sudo restic-gdrive stats --mode raw-data`.

O Google Drive limita uploads a 750 GB por dia por conta: o primeiro backup do server pode levar mais de um dia. Os blocos já enviados são aproveitados na execução seguinte.
