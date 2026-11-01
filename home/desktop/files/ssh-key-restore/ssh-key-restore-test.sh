# Testes do ssh-key-restore, com cofre falso e chaves geradas aqui.
# Uso: ssh-key-restore-test.sh <ssh-key-restore.sh>
set -u

script=$1
failures=0
root=$(mktemp -d)
trap 'chmod -R u+w "$root"; command rm -rf "$root"' EXIT
mkdir -p "$root/bin" "$root/vault" "$root/keys"

# Comando rbw falso: lê as entradas de $VAULT e respeita $RBW_LOCKED
cat > "$root/bin/rbw" << 'EOF'
#!/bin/sh
case "$1" in
  unlocked) [ -z "${RBW_LOCKED:-}" ] ;;
  get) cat "$VAULT/$3.json" 2> /dev/null ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$root/bin/rbw"

new_key() {
  ssh-keygen -q -t ed25519 -N '' -C '' -f "$root/keys/$1"
}

# Entrada SSH: nome, chave privada e chave pública
add_entry() {
  jq -n --rawfile priv "$root/keys/$2" --rawfile pub "$root/keys/$3.pub" \
    '{data: {private_key: $priv, public_key: ($pub | rtrimstr("\n")), fingerprint: "x"}}' \
    > "$root/vault/$1.json"
}

new_key certa
new_key outra
add_entry "$(uname -n)" certa certa
add_entry notebook outra outra
add_entry trocada certa outra
printf '{"data": {"username": "dio", "password": "senha-secreta"}}\n' > "$root/vault/site.json"

setup() {
  home=$root/home
  chmod -R u+w "$home" 2> /dev/null
  command rm -rf "$home"
  mkdir -p "$home"
  status=0
}

run() {
  HOME=$home VAULT=$root/vault PATH=$root/bin:$PATH bash "$script" "$@" > "$root/output" 2>&1
  status=$?
}

check() {
  if ! eval "$2"; then
    echo "FALHOU: $1 [$2]"
    sed 's/^/  | /' "$root/output"
    failures=$((failures + 1))
  fi
}

installed() { cmp -s "$home/.ssh/id_ed25519" "$root/keys/$1"; }
absent() { [ ! -e "$home/.ssh/id_ed25519" ] && [ ! -e "$home/.ssh/id_ed25519.pub" ]; }
no_leftovers() { [ "$(find "$home" -name '.restore.*' | wc -l)" = 0 ]; }
no_secret() { ! grep -q 'PRIVATE KEY' "$root/output"; }

setup
run
check "usa a entrada com o nome da máquina" '[ $status = 0 ] && installed certa'
check "protege a chave privada" '[ "$(stat -c %a "$home/.ssh/id_ed25519")" = 600 ] && [ "$(stat -c %a "$home/.ssh")" = 700 ]'
check "grava a chave pública do cofre" '[ "$(cut -d" " -f1,2 "$home/.ssh/id_ed25519.pub")" = "$(cut -d" " -f1,2 "$root/keys/certa.pub")" ]'
check "não mostra a chave nem deixa temporários" 'no_secret && no_leftovers'

setup
run notebook
check "aceita o nome da entrada" '[ $status = 0 ] && installed outra'

setup
mkdir -p "$home/.ssh"
echo antiga > "$home/.ssh/id_ed25519"
run notebook
check "não sobrescreve a chave privada" '[ $status != 0 ] && [ "$(cat "$home/.ssh/id_ed25519")" = antiga ] && [ ! -e "$home/.ssh/id_ed25519.pub" ]'

setup
mkdir -p "$home/.ssh"
echo antiga > "$home/.ssh/id_ed25519.pub"
run notebook
check "não sobrescreve a chave pública" '[ $status != 0 ] && [ "$(cat "$home/.ssh/id_ed25519.pub")" = antiga ] && [ ! -e "$home/.ssh/id_ed25519" ]'

setup
RBW_LOCKED=1 run notebook
check "cofre bloqueado pede rbw unlock" '[ $status != 0 ] && grep -q "rbw unlock" "$root/output" && absent'

setup
run inexistente
check "entrada inexistente falha" '[ $status != 0 ] && grep -q inexistente "$root/output" && absent'

setup
run site
check "entrada sem chave SSH falha sem mostrar a senha" '[ $status != 0 ] && grep -q site "$root/output" && ! grep -q senha-secreta "$root/output" && absent'

setup
run trocada
check "chave que não confere não é instalada" '[ $status != 0 ] && absent && no_leftovers && no_secret'

if [ "$failures" != 0 ]; then
  echo "$failures caso(s) falharam"
  exit 1
fi
echo "todos os casos passaram"
