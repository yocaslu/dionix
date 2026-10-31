#!/usr/bin/env bash
# Atualizações pendentes para a Waybar (JSON), versão NixOS.
#   updates.sh            compara o nixpkgs fixado no flake.lock com o canal no GitHub
#   updates.sh --upgrade  atualiza o flake.lock, aplica (nh os switch --update)
#                         e avisa a Waybar para recontar
# Com o flake em dia, o texto fica vazio e a Waybar esconde o módulo.
# O texto mostra há quantos dias o nixpkgs do flake.lock foi fixado.

flake="${NH_FLAKE:-$HOME/repos/dionix}"

if [ "${1:-}" = "--upgrade" ]; then
  nh os switch --update "$flake"
  pkill -RTMIN+8 waybar
  printf '\nPressione Enter para fechar.'
  read -r _
  exit 0
fi

empty() {
  printf '{"text": "", "class": "none"}\n'
  exit 0
}

lock="$flake/flake.lock"
[ -r "$lock" ] || empty

locked=$(jq -r '.nodes.nixpkgs.locked.rev // empty' "$lock")
ref=$(jq -r '.nodes.nixpkgs.original.ref // empty' "$lock")
since=$(jq -r '.nodes.nixpkgs.locked.lastModified // 0' "$lock")
{ [ -n "$locked" ] && [ -n "$ref" ]; } || empty

remote=$(git ls-remote https://github.com/NixOS/nixpkgs "refs/heads/$ref" 2>/dev/null | cut -f1)
{ [ -n "$remote" ] && [ "$remote" != "$locked" ]; } || empty

days=$(( ($(date +%s) - since) / 86400 ))
printf '{"text": "%sd", "tooltip": "%s tem atualizações\\nflake.lock fixado há %s dias\\nclique para atualizar", "class": "pending"}\n' \
  "$days" "$ref" "$days"
