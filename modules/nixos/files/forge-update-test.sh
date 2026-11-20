# Testes do forge-update.sh, com comandos falsos no PATH que registram as
# chamadas. Uso: forge-update-test.sh <forge-update.sh>
set -u

script=$1
failures=0
root=$(mktemp -d)
trap 'command rm -rf "$root"' EXIT

fake_command() {
  printf '#!/bin/sh\n%s\n' "$2" > "$root/bin/$1"
  chmod +x "$root/bin/$1"
}

# Cada caso começa do zero: Pi sem pendência, hora 10, perfil igual à main
setup() {
  command rm -rf "${root:?}"/*
  mkdir -p "$root/bin" "$root/work" "$root/gc" "$root/store"
  : > "$root/calls"
  echo token-secreto > "$root/token"
  ln -s /nix/store/fake-forge "$root/perfil"
  fake_command date 'echo "${HORA:-10}"'
  fake_command curl 'echo "curl $*" >> "$CALLS"
case "$*" in *forge/pendente*) printf "%s" "${PENDENTE:-}" ;; esac'
  # git diff --quiet: sai 1 (lock mudou) salvo com LOCK_IGUAL
  fake_command git 'echo "git $*" >> "$CALLS"
case "$*" in "diff --quiet"*) [ -n "${LOCK_IGUAL:-}" ] || exit 1 ;; esac'
  fake_command nvd 'echo "nvd $*" >> "$CALLS"; [ -z "${FALHA_NVD:-}" ] || exit 1; echo "resumo de $3"'
  fake_command nixos-rebuild 'echo "nixos-rebuild $*" >> "$CALLS"'
  fake_command nix 'echo "nix $*" >> "$CALLS"
case "$*" in
  "flake update"*) [ -z "${TERMINA:-}" ] || kill -TERM "$PPID"; exit 0 ;;
  "flake "*) exit 0 ;;
esac
out= ; attr=
while [ $# -gt 0 ]; do
  case "$1" in
    --out-link) out=$2; shift ;;
    *nixosConfigurations.*) attr=$1 ;;
  esac
  shift
done
host=${attr#*nixosConfigurations.}; host=${host%%.*}
if [ -n "${FALHA_HOST:-}" ] && [ "$host" = "$FALHA_HOST" ] && { [ -n "${FALHA_ANTES:-}" ] || grep -q "^nix flake update" "$CALLS"; }; then
  exit 1
fi
[ -z "$out" ] || ln -sfn "/nix/store/fake-$host" "$out"
echo "/nix/store/fake-$host"'
  fake_command gh 'echo "gh $*" >> "$CALLS"
case "$*" in
  "pr list"*"--jq"*) echo "${PR_ABERTO:-}" ;;
  "pr list"*) echo "${PR_LISTA:-[]}" ;;
  "pr create"*) echo https://github.com/yocaslu/dionix/pull/31 ;;
esac'
  status=0
}

run() {
  CALLS=$root/calls PATH=$root/bin:$PATH PI_URL=https://pi.test \
    TOKEN_FILE=$root/token WORKDIR=$root/work GCROOTS=$root/gc \
    PERFIL=$root/perfil \
    bash "$script" > "$root/output" 2>&1
  status=$?
}

check() {
  if ! eval "$2"; then
    echo "FALHOU: $1 [$2]"
    sed 's/^/  | /' "$root/output"
    echo "  calls:"
    sed 's/^/  | /' "$root/calls"
    failures=$((failures + 1))
  fi
}

called() { grep -qF -- "$1" "$root/calls"; }
# Os padrões aparecem em ordem (cada um depois do anterior)
em_ordem() {
  local linha=0 achada padrao
  for padrao in "$@"; do
    achada=$(awk -v ini="$linha" -v p="$padrao" 'NR > ini && index($0, p) { print NR; exit }' "$root/calls")
    [ -n "$achada" ] || return 1
    linha=$achada
  done
}

# Fora da janela (23h) com pendência: não compila
setup
HORA=23 PENDENTE=B run
check "fora da janela não compila" '[ $status = 0 ] && ! called "flake update" && ! called "forge/compilando"'
check "fora da janela só baixa o sistema da main" 'called "--max-jobs 0"'

# Na janela, com pendência: compila, abre o PR e avisa
setup
HORA=10 PENDENTE=B run
check "compila e abre o PR" '[ $status = 0 ] && em_ordem "forge/compilando" "flake update" \
  "nixosConfigurations.notebook" "nixosConfigurations.forge" "nixosConfigurations.server" \
  "nixosConfigurations.pi" "flake check" "push --force" "pr create" "forge/pronto"'
check "pronto leva a revisão, o PR e o resumo" 'called "\"rev\":\"B\"" && called "\"pr\":31" && called "resumo de /nix/store/fake-notebook"'
check "o resumo do nvd compara a main com o novo" 'called "nvd diff /nix/store/fake-notebook /nix/store/fake-notebook"'
check "commit pelo forge" 'called "user.name=forge" && called "forge@vault76.com.br"'
check "raízes de GC trocadas" '[ -L "$root/gc/pi" ] && [ ! -e "$root/gc/novo-pi" ]'
check "token fora das chamadas" '! grep -rq token-secreto "$root/calls" "$root/output"'

# Sem pendência: nada a compilar
setup
HORA=10 run
check "sem pendência não compila" '[ $status = 0 ] && ! called "flake update" && ! called "forge/compilando"'

# PR já aberto: edita, não cria
setup
HORA=10 PENDENTE=B PR_LISTA='[{"number":30,"url":"https://github.com/yocaslu/dionix/pull/30"}]' run
check "edita o PR existente" '[ $status = 0 ] && called "pr edit 30" && ! called "pr create" && called "\"pr\":30"'

# Build do pi falha: avisa e não toca no PR
setup
HORA=10 PENDENTE=B FALHA_HOST=pi run
check "falha avisa e não abre PR" '[ $status != 0 ] && called "forge/falhou" && ! called "push" && ! called "pr " && ! called "forge/pronto"'
check "falhou leva a revisão" 'grep "forge/falhou" "$root/calls" | grep -q "B"'

# nvd falha (dentro de $(...)): um único falhou, sem push, PR nem pronto
setup
HORA=10 PENDENTE=B FALHA_NVD=1 run
check "falha do nvd avisa uma vez" '[ $status != 0 ] && [ "$(grep -c forge/falhou "$root/calls")" = 1 ] && ! called "push" && ! called "pr " && ! called "forge/pronto"'

# Build dentro de $(...) falha antes do flake update: também um único falhou
setup
HORA=10 PENDENTE=B FALHA_ANTES=1 FALHA_HOST=notebook run
check "falha de build em \$(...) avisa uma vez" '[ $status != 0 ] && [ "$(grep -c forge/falhou "$root/calls")" = 1 ] && ! called "push" && ! called "forge/pronto"'

# TERM durante a compilação (timeout do systemd): um único falhou
setup
HORA=10 PENDENTE=B TERMINA=1 run
check "TERM avisa falhou uma vez" '[ $status != 0 ] && [ "$(grep -c forge/falhou "$root/calls")" = 1 ] && ! called "push" && ! called "forge/pronto"'

# O Pi recebe os avisos com tentativas
setup
HORA=10 PENDENTE=B run
check "avisos ao Pi com retry" 'grep "forge/compilando" "$root/calls" | grep -q -- "--retry 3 --retry-all-errors" && grep "forge/pronto" "$root/calls" | grep -q -- "--retry 3 --retry-all-errors"'

# flake.lock igual: main já tem o canal; fecha o PR aberto e avisa em-dia
setup
HORA=10 PENDENTE=B LOCK_IGUAL=1 PR_ABERTO=30 run
check "lock igual: em-dia, fecha o PR" '[ $status = 0 ] && em_ordem "forge/compilando" "flake update" "pr close 30 --delete-branch" "forge/em-dia"'
check "lock igual: nada de push, PR novo, pronto ou falhou" '! called "push" && ! called "pr create" && ! called "pr edit" && ! called "forge/pronto" && ! called "forge/falhou" && ! called "flake check"'
check "lock igual: não compila os hosts novos" '! called "--out-link $root/gc/novo"'
check "lock igual: em-dia leva a revisão" 'grep "forge/em-dia" "$root/calls" | grep -q " B "'

# Lock igual sem PR aberto: só avisa
setup
HORA=10 PENDENTE=B LOCK_IGUAL=1 run
check "lock igual sem PR: em-dia sem close" '[ $status = 0 ] && ! called "pr close" && called "forge/em-dia"'

# A main aplicada só quando difere do perfil
setup
HORA=10 run
check "main igual ao perfil: nada" '[ $status = 0 ] && ! called "nixos-rebuild"'

setup
ln -sfn /nix/store/outro "$root/perfil"
HORA=10 run
check "main diferente: nixos-rebuild boot" '[ $status = 0 ] && called "nixos-rebuild boot --flake $root/work#forge"'

if [ "$failures" -ne 0 ]; then
  echo "$failures teste(s) falharam"
  exit 1
fi
echo "forge-update: ok"
