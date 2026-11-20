#!/usr/bin/env bash
# Atualizações do forge: compila o flake.lock novo, abre (ou atualiza) o PR e
# aplica a `main` no próprio forge. Fala com o Pi (update-watch) em PI_URL.
# Tudo externo é chamado pelo nome (PATH), para os testes trocarem por falsos.
set -euo pipefail
set -E

PI_URL=${PI_URL:?}
REPO=${REPO:-https://github.com/yocaslu/dionix.git}
TOKEN_FILE=${TOKEN_FILE:-/var/lib/secrets/github-token}
WORKDIR=${WORKDIR:-/var/lib/forge-update}
HOSTS=${HOSTS:-notebook forge server pi}
JANELA=${JANELA:-8-22}
GCROOTS=${GCROOTS:-/nix/var/nix/gcroots/forge-update}
PERFIL=${PERFIL:-/nix/var/nix/profiles/system}
BRANCH=atualizacao/flake-lock
TITULO='chore(flake): atualiza o flake.lock'

# 0 se HORA (0-23) está dentro de JANELA (inicio-fim, fim exclusivo)
na_janela() {
  local hora=$((10#$1)) inicio=${JANELA%-*} fim=${JANELA#*-}
  ((hora >= inicio && hora < fim))
}

toplevel() { echo "$WORKDIR#nixosConfigurations.$1.config.system.build.toplevel"; }

# Lê o token (sem gravá-lo em disco nem nos logs): o gh usa o GH_TOKEN e o git
# manda o cabeçalho pelo ambiente, que não aparece na linha de comando.
carregar_token() {
  GH_TOKEN=$(<"$TOKEN_FILE")
  GH_REPO=${REPO#https://github.com/}
  GH_REPO=${GH_REPO%.git}
  export GH_TOKEN GH_REPO
  GIT_CONFIG_COUNT=1
  GIT_CONFIG_KEY_0=http.extraHeader
  GIT_CONFIG_VALUE_0="Authorization: Basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 -w0)"
  export GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
}

pi_enviar() { # caminho, corpo, [tipo]
  curl -fsS -X POST -H "Content-Type: ${3:-text/plain}" --data "$2" "$PI_URL/forge/$1" > /dev/null
}

# Clone próprio, parado na origin/main
atualizar_clone() {
  if [ ! -d "$WORKDIR/.git" ]; then
    git clone "$REPO" "$WORKDIR" || return 1
  fi
  # Com `||` na chamada o set -e não vale aqui dentro: cada passo é conferido
  cd "$WORKDIR" || return 1
  git fetch origin main || return 1
  git checkout -qf --detach origin/main || return 1
  git clean -fdq || return 1
}

# Compila o sistema do forge na origin/main e, se difere do próximo boot,
# instala para o boot seguinte. Fora da janela só baixa (sem compilar); se não
# der, não faz nada.
aplicar_main() {
  local jobs=() novo atual
  atualizar_clone || return 1
  if ! na_janela "$(date +%H)"; then
    jobs=(--max-jobs 0)
  fi
  if ! novo=$(nix build --no-link --print-out-paths "${jobs[@]}" "$(toplevel forge)"); then
    echo "aplicar_main: não deu para obter o sistema da main, nada a fazer" >&2
    return 0
  fi
  atual=$(readlink -f "$PERFIL")
  if [ "$novo" != "$atual" ]; then
    nixos-rebuild boot --flake "$WORKDIR#forge" || return 1
  fi
}

falhou() {
  trap - ERR
  echo "compilar: falhou, o PR não foi tocado" >&2
  pi_enviar falhou "$1" || true
  exit 1
}

compilar() {
  local rev=$1 host corpo url pr pronto
  declare -A antigo novo
  pi_enviar compilando "$rev"
  trap 'falhou "$rev"' ERR

  carregar_token
  mkdir -p "$GCROOTS"
  command rm -f "$GCROOTS"/novo-* "$GCROOTS"/main-*
  corpo=$(mktemp)

  atualizar_clone
  git checkout -B "$BRANCH" origin/main
  # Sistema da main de cada host, para o nvd (quase tudo já está no store)
  for host in $HOSTS; do
    antigo[$host]=$(nix build --out-link "$GCROOTS/main-$host" --print-out-paths "$(toplevel "$host")")
  done

  nix flake update
  for host in $HOSTS; do
    novo[$host]=$(nix build --out-link "$GCROOTS/novo-$host" --print-out-paths "$(toplevel "$host")")
  done
  nix flake check

  {
    echo "Atualização do \`flake.lock\` compilada pelo forge (todos os hosts e \`nix flake check\` passaram)."
    for host in $HOSTS; do
      printf '\n## %s\n\n%s\n%s\n%s\n' "$host" '```' "$(nvd diff "${antigo[$host]}" "${novo[$host]}")" '```'
    done
  } > "$corpo"

  git add flake.lock
  git -c user.name=forge -c user.email=forge@vault76.com.br commit -m "$TITULO"
  git push --force origin "$BRANCH"

  pr=$(gh pr list --head "$BRANCH" --state open --json number,url |
    jq -r '.[0] | if . then "\(.number) \(.url)" else empty end')
  if [ -n "$pr" ]; then
    url=${pr#* }
    pr=${pr%% *}
    gh pr edit "$pr" --body-file "$corpo"
  else
    url=$(gh pr create --base main --head "$BRANCH" --title "$TITULO" --body-file "$corpo")
    pr=${url##*/}
  fi

  # As raízes novas substituem as do PR anterior
  for host in $HOSTS; do
    mv -T "$GCROOTS/novo-$host" "$GCROOTS/$host"
  done
  command rm -f "$GCROOTS"/main-* "$corpo"

  pronto=$(jq -nc --arg rev "$rev" --argjson pr "$pr" --arg url "$url" \
    --arg resumo "$(nvd diff "${antigo[notebook]}" "${novo[notebook]}")" \
    '{rev: $rev, pr: $pr, url: $url, resumo: $resumo}')
  trap - ERR
  pi_enviar pronto "$pronto" application/json
}

main() {
  local rev
  aplicar_main || echo "aplicar_main: falhou, segue sem aplicar a main" >&2
  na_janela "$(date +%H)" || exit 0
  rev=$(curl -fsS "$PI_URL/forge/pendente") || exit 0
  rev=$(tr -d '[:space:]' <<< "$rev")
  [ -z "$rev" ] || compilar "$rev"
}

main "$@"
