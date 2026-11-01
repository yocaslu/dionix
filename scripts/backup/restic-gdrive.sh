#!/usr/bin/env bash
# Backup com restic para o Google Drive (rclone) nos hosts que não rodam NixOS:
# Proxmox, NAS (OpenMediaVault) e VMs Debian/Ubuntu. Faz o mesmo que o
# modules/nixos/backup.nix: um repositório por host em gdrive:homelab/<host>,
# retenção 7 diários / 4 semanais / 6 mensais e checagem de 1% dos dados.
#
# Configuração em /etc/restic-gdrive/ (veja scripts/backup/README.md):
#   env           BACKUP_PATHS e, opcionalmente, BACKUP_EXCLUDES e BACKUP_NAME
#   password      senha do repositório (guarde uma cópia fora do homelab!)
#   rclone.conf   remote "gdrive"
#   pre.sh        opcional: roda antes do backup (ex.: dump de banco)
#
# Uso: restic-gdrive.sh            faz o backup
#      restic-gdrive.sh <comando>  repassa para o restic (snapshots, restore, mount…)
set -euo pipefail

CONF=${RESTIC_GDRIVE_CONF:-/etc/restic-gdrive}

# shellcheck source=/dev/null
source "$CONF/env"

export RESTIC_REPOSITORY="rclone:gdrive:homelab/${BACKUP_NAME:-$(hostname -s)}"
export RESTIC_PASSWORD_FILE="$CONF/password"
export RCLONE_CONFIG="$CONF/rclone.conf"
export RCLONE_DRIVE_CHUNK_SIZE=64M
export RESTIC_CACHE_DIR=/var/cache/restic

# Atalho para o restic com o repositório já configurado
if [[ $# -gt 0 ]]; then
	exec restic "$@"
fi

log() { echo "[restic-gdrive] $*"; }

# Cria o repositório na primeira execução
if ! restic cat config >/dev/null 2>&1; then
	log "criando o repositório $RESTIC_REPOSITORY"
	restic init
fi

if [[ -x "$CONF/pre.sh" ]]; then
	log "rodando pre.sh"
	"$CONF/pre.sh"
fi

read -r -a paths <<<"$BACKUP_PATHS"
excludes=()
for e in ${BACKUP_EXCLUDES:-}; do
	excludes+=(--exclude "$e")
done

log "backup de: ${paths[*]}"
restic backup --one-file-system --tag auto "${excludes[@]}" "${paths[@]}"

log "aplicando a retenção"
restic forget --tag auto --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6

log "checando 1% dos dados"
restic check --read-data-subset=1%

log "concluído"
