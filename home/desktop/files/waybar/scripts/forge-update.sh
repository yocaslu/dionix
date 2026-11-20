#!/usr/bin/env bash
# Atualizações compiladas pelo forge, para a Waybar (JSON).
#   forge-update.sh           lê o estado no Pi e mostra o módulo
#   forge-update.sh --aplicar clique: tenta de novo (falhou) ou mescla o PR e
#                             reconstrói o notebook com o cache do forge
# Precisa de DIONIX_DOMAIN no ambiente (o waybar.nix define). Com o estado
# "nada" ou o Pi fora, o texto fica vazio e a Waybar esconde o módulo.

domain="${DIONIX_DOMAIN:?defina DIONIX_DOMAIN}"
flake="${NH_FLAKE:-$HOME/repos/dionix}"
# O gh roda de qualquer pasta (a Waybar abre o terminal no $HOME)
repo="yocaslu/dionix"
# Quanto esperar o cache do forge ligar, em segundos
espera="${ESPERA_CACHE:-180}"
pi="https://pi.$domain"
cache="https://cache.$domain/nix-cache-info"
acordar="https://home.$domain/acordar/forge"

# Estado do Pi (JSON); falha se o Pi estiver fora
estado() {
  curl -fsS --max-time 10 "$pi/forge/estado"
}

mostrar() {
  local json nome
  json=$(estado 2> /dev/null) || json='{"estado": "nada"}'
  nome=$(jq -r '.estado // "nada"' <<< "$json" 2> /dev/null) || nome=nada
  case "$nome" in
    pendente | compilando)
      printf '{"text": "…", "tooltip": "o forge está compilando as atualizações", "class": "building"}\n'
      ;;
    pronto)
      jq -c '{text: "#\(.pr)", tooltip: "\(.resumo)\nclique para aplicar", class: "pending"}' <<< "$json"
      ;;
    falhou)
      printf '{"text": "!", "tooltip": "o build falhou: journalctl -u forge-update no forge\\nclique para tentar de novo", "class": "failed"}\n'
      ;;
    *)
      printf '{"text": "", "class": "none"}\n'
      ;;
  esac
}

# Marca como pendente e acorda o forge para compilar de novo
tentar() {
  curl -fsS --max-time 10 -X POST "$pi/forge/tentar" > /dev/null
}

# Acorda o forge e espera o cache binário responder (até $espera segundos,
# medidos pelo relógio)
esperar_cache() {
  local fim=$((SECONDS + espera))
  curl -fsS --max-time 10 "$acordar" > /dev/null 2>&1
  while ((SECONDS < fim)); do
    curl -fs --max-time 5 -o /dev/null "$cache" 2> /dev/null && return 0
    sleep 5
  done
  return 1
}

aplicar() {
  local json nome pr resumo resposta merge
  if ! json=$(estado); then
    echo "Pi fora do ar, tente depois."
    return 1
  fi
  nome=$(jq -r '.estado // "nada"' <<< "$json")
  case "$nome" in
    falhou)
      tentar && echo "Pedi ao forge para compilar de novo."
      return
      ;;
    pronto) ;;
    pendente | compilando)
      echo "O forge ainda está compilando."
      return
      ;;
    *)
      echo "Nada para aplicar."
      return
      ;;
  esac

  pr=$(jq -r '.pr' <<< "$json")
  resumo=$(jq -r '.resumo' <<< "$json")
  printf '%s\n\nAplicar o PR #%s? [s/N] ' "$resumo" "$pr"
  read -r resposta
  [ "$resposta" = s ] || return 0

  # Falha fechada: sem resposta clara do GitHub, nem acorda o forge nem mescla
  if ! merge=$(gh pr view "$pr" -R "$repo" --json mergeStateStatus -q .mergeStateStatus); then
    echo "Não consegui consultar o PR no GitHub. Tente de novo em instantes."
    return 1
  fi
  case "$merge" in
    CLEAN | UNSTABLE | HAS_HOOKS) ;;
    BEHIND | DIRTY)
      tentar
      echo "A main andou: pedi ao forge para compilar de novo. Tente quando o módulo voltar a mostrar o PR."
      return
      ;;
    *)
      echo "Estado do PR: ${merge:-desconhecido}. Tente de novo em instantes."
      return
      ;;
  esac

  echo "Acordando o forge e esperando o cache..."
  if ! esperar_cache; then
    echo "O cache do forge não respondeu em $espera segundos."
    return 1
  fi
  gh pr merge "$pr" -R "$repo" --squash --delete-branch || return
  git -C "$flake" pull --ff-only || return
  nh os switch "$flake"
}

if [ "${1:-}" = "--aplicar" ]; then
  aplicar
  pkill -RTMIN+8 waybar
  printf '\nPressione Enter para fechar.'
  read -r _
  exit 0
fi

mostrar
