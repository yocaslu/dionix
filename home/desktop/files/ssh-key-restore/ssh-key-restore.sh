#!/usr/bin/env bash
# Instala em ~/.ssh a chave desta máquina, guardada no cofre do Bitwarden (rbw).
# Uso: `ssh-key-restore [entrada]`; sem argumento, usa a entrada com o nome da máquina.
set -euo pipefail

entry=${1:-$(uname -n)}
ssh_dir=$HOME/.ssh
key=$ssh_dir/id_ed25519

fail() {
  echo "ssh-key-restore: $1" >&2
  exit 1
}

if [ -e "$key" ] || [ -e "$key.pub" ]; then
  fail "$key já existe; nada foi alterado"
fi
rbw unlocked > /dev/null 2>&1 || fail "cofre bloqueado; rode rbw unlock"

# A saída do rbw traz segredos: fica só em variável, sem passar por argumentos
raw=$(rbw get --raw "$entry" 2> /dev/null) || fail "entrada '$entry' não encontrada no cofre"
public=$(jq -r '.data.public_key // empty' <<< "$raw")
[ -n "$public" ] || fail "a entrada '$entry' não tem chave SSH"

umask 077
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
tmp=$(mktemp -d "$ssh_dir/.restore.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# printf é embutido e deixa exatamente uma quebra de linha no fim
printf '%s\n' "$(jq -r '.data.private_key // empty' <<< "$raw")" > "$tmp/key"
# Só instala se a privada corresponde à pública; chave com senha pede a senha aqui
derived=$(ssh-keygen -y -f "$tmp/key" 2> /dev/null) || fail "não foi possível ler a chave privada de '$entry'"
if [ "$(cut -d' ' -f1,2 <<< "$derived")" != "$(cut -d' ' -f1,2 <<< "$public")" ]; then
  fail "as chaves privada e pública de '$entry' não conferem"
fi
printf '%s\n' "$public" > "$tmp/key.pub"
chmod 644 "$tmp/key.pub"

# ln falha se o destino tiver surgido nesse meio-tempo, em vez de sobrescrever
ln "$tmp/key" "$key" || fail "$key já existe; nada foi alterado"
ln "$tmp/key.pub" "$key.pub" || fail "$key.pub já existe; a chave privada foi instalada"

echo "ssh-key-restore: chave de '$entry' instalada em $key"
