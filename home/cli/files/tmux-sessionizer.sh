#!/usr/bin/env bash
# Escolhe um projeto com o fzf e abre (ou troca para) uma sessão do tmux nele.
# Pastas de projetos: ~/repos (empacotado com fd, fzf e tmux em home/cli/tmux.nix).
set -euo pipefail

dirs=("$HOME/repos")

# fd; sem ele, usa o find
if command -v fd >/dev/null 2>&1; then
  list() { fd --type d --max-depth 2 . "${dirs[@]}" 2>/dev/null; }
else
  list() { find "${dirs[@]}" -mindepth 1 -maxdepth 2 -type d -not -path '*/.*' 2>/dev/null; }
fi

dir=$(list | fzf --prompt 'projeto> ') || exit 0
[[ -n $dir ]] || exit 0
dir=${dir%/}
name=$(basename "$dir" | tr '.:' '__')

if ! tmux has-session -t "=$name" 2>/dev/null; then
  tmux new-session -ds "$name" -c "$dir"
fi

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "=$name"
else
  tmux attach -t "=$name"
fi
