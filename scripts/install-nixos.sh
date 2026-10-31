#!/usr/bin/env bash
# Instala um host de boot UEFI (notebook ou desktop) a partir da ISO do NixOS.
# APAGA o disco inteiro: particiona, clona o repositório, gera a configuração
# de hardware, instala e define a senha do usuário.
#
# Uso: sudo bash install-nixos.sh [--branch <nome>] [--sem-bootloader] <host> <disco>
#   --branch          clona outra branch em vez da main
#   --sem-bootloader  não instala o boot nem exige UEFI (só para testes em VM)
set -euo pipefail

REPO_URL="https://github.com/yocaslu/dionix"
ALVO="/mnt"
USUARIO="dio"
USUARIO_UID="1000"
USUARIO_GID="100"

erro() {
  echo "erro: $*" >&2
  exit 1
}

uso() {
  sed -n '6p' "$0" | sed 's/^# //' >&2
  exit 2
}

branch="main"
bootloader="sim"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      [[ $# -ge 2 ]] || uso
      branch="$2"
      shift 2
      ;;
    --sem-bootloader)
      bootloader="nao"
      shift
      ;;
    -*) uso ;;
    *) break ;;
  esac
done
[[ $# -eq 2 ]] || uso
host="$1"
disco="$2"

[[ $EUID -eq 0 ]] || erro "rode como root (sudo)"
# O servidor usa GRUB em BIOS e segue o caminho do README
case "$host" in
  notebook | desktop) ;;
  *) erro "host inválido: $host (use notebook ou desktop)" ;;
esac
if [[ "$bootloader" == "sim" && ! -d /sys/firmware/efi ]]; then
  erro "a ISO não iniciou em modo UEFI"
fi
[[ -b "$disco" ]] || erro "$disco não é um dispositivo de bloco"
[[ "$(lsblk -dno TYPE "$disco")" =~ ^(disk|loop)$ ]] || erro "$disco não é um disco inteiro"
if [[ -n "$(lsblk -nro MOUNTPOINTS "$disco" | tr -d '[:space:]')" ]]; then
  erro "$disco tem partições montadas"
fi
if mountpoint -q "$ALVO"; then
  erro "$ALVO já está montado (rode: umount -R $ALVO)"
fi

# A ISO mínima pode não trazer as ferramentas no PATH
if ! command -v git >/dev/null || ! command -v parted >/dev/null; then
  opcoes=(--branch "$branch")
  [[ "$bootloader" == "sim" ]] || opcoes+=(--sem-bootloader)
  printf -v args '%q ' "$0" "${opcoes[@]}" "$host" "$disco"
  exec nix-shell -p git parted --run "bash $args"
fi

lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL "$disco"
echo
echo "TODOS os dados de $disco serão apagados. Host: $host, branch: $branch."
read -rp "Digite o caminho do disco para confirmar: " confirmacao
[[ "$confirmacao" == "$disco" ]] || erro "confirmação diferente de $disco; nada foi alterado"

echo "==> Particionando"
wipefs -af "$disco" >/dev/null
parted -s "$disco" \
  mklabel gpt \
  mkpart BOOT fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart nixos ext4 513MiB 100%
partprobe "$disco"
udevadm settle

# Nos caminhos reais, para não pegar um rótulo igual em outro disco
mapfile -t particoes < <(lsblk -lnpo NAME,TYPE "$disco" | awk '$2 == "part" { print $1 }')
[[ ${#particoes[@]} -eq 2 ]] || erro "esperava 2 partições em $disco, achei ${#particoes[@]}"
mkfs.fat -F32 -n BOOT "${particoes[0]}" >/dev/null
mkfs.ext4 -q -F -L nixos "${particoes[1]}"
udevadm settle

mount --mkdir "${particoes[1]}" "$ALVO"
mount --mkdir -o fmask=0077,dmask=0077 "${particoes[0]}" "$ALVO/boot"

echo "==> Clonando $branch"
repo="$ALVO/home/$USUARIO/repos/dionix"
git clone --branch "$branch" "$REPO_URL" "$repo"

echo "==> Gerando a configuração de hardware"
nixos-generate-config --root "$ALVO" --show-hardware-config \
  >"$repo/hosts/$host/hardware-configuration.nix"
# Flakes só enxergam o que está no índice do git
git -C "$repo" add "hosts/$host/hardware-configuration.nix"

echo "==> Instalando $host (baixa vários GB)"
export NIX_CONFIG="experimental-features = nix-command flakes"
# O /tmp da ISO fica na RAM
mkdir -p "$ALVO/tmp"
args_instalacao=(--no-root-passwd --no-channel-copy --flake "$repo#$host")
[[ "$bootloader" == "sim" ]] || args_instalacao+=(--no-bootloader)
TMPDIR="$ALVO/tmp" nixos-install "${args_instalacao[@]}"

chown -R "$USUARIO_UID:$USUARIO_GID" "$ALVO/home/$USUARIO"

echo "==> Defina a senha de $USUARIO"
until nixos-enter --root "$ALVO" -c "passwd $USUARIO"; do
  echo "Tente de novo."
done

echo
echo "Instalação concluída. Rode reboot e remova a ISO."
echo "Depois, commite hosts/$host/hardware-configuration.nix em ~/repos/dionix."
