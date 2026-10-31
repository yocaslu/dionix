# fzf: variáveis e funções. Tudo aqui depende do fzf; sem ele, o módulo para.
# Dentro das funções, `command` evita aliases (cat→bat, grep etc.).
# Todas retornam 0 quando a seleção é cancelada (Esc).

(( $+commands[fzf] )) || return 0

# FZF_DEFAULT_COMMAND, FZF_DEFAULT_OPTS (cores Catppuccin) e os previews do
# Ctrl+T / Alt+C vêm do programs.fzf do Home Manager (home/cli/shell.nix).

# fe [busca]: escolhe um ou mais arquivos (Tab marca) e abre no $EDITOR
fe() {
  local -a files
  files=("${(@f)$(fzf --multi --select-1 --exit-0 --query="$*" \
    --preview 'bat --color=always --style=numbers --line-range :200 {}')}")
  [[ -n ${files[1]} ]] || return 0
  "${EDITOR:-vim}" -- "${files[@]}"
}

# rgf [busca]: ripgrep interativo; Enter abre o arquivo na linha encontrada
rgf() {
  (( $+commands[rg] )) || { echo "rgf: precisa do ripgrep" >&2; return 1; }
  local rg_cmd='command rg --column --line-number --no-heading --color=always --smart-case'
  : | fzf --ansi --disabled --query "$*" \
    --bind "start:reload:$rg_cmd {q} || true" \
    --bind "change:reload:sleep 0.1; $rg_cmd {q} || true" \
    --delimiter : \
    --preview 'bat --color=always --highlight-line {2} {1}' \
    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
    --bind "enter:become(${EDITOR:-vim} {1} +{2})" || return 0
}

# fbr: troca de branch (locais e remotas, as mais recentes primeiro)
fbr() {
  command git rev-parse --git-dir >/dev/null 2>&1 || { echo "fbr: não é um repositório git" >&2; return 1; }
  local branch remote
  branch=$(command git for-each-ref --sort=-committerdate --format='%(refname)' refs/heads refs/remotes |
    command grep -v '^refs/remotes/[^/]*/HEAD$' |
    sed -e 's#^refs/heads/##' -e 's#^refs/remotes/##' |
    fzf --no-multi --prompt 'branch> ' \
      --preview 'git log --oneline --graph --color=always -20 {}') || return 0
  [[ -n $branch ]] || return 0
  # origin/feat → feat (o git switch cria a branch local rastreando o remoto)
  for remote in $(command git remote); do
    if [[ $branch == $remote/* ]]; then
      branch=${branch#$remote/}
      break
    fi
  done
  command git switch "$branch"
}

# fkill [sinal]: escolhe processos (Tab marca vários) e manda o sinal (padrão 15)
fkill() {
  local sig="${1:-15}"
  local -a pids
  pids=(${(f)"$(command ps -u "$USER" -o pid,%cpu,%mem,etime,args |
    fzf --multi --header-lines=1 --header="kill -$sig (Tab marca vários)" |
    command awk '{print $1}')"})
  (( ${#pids} )) || return 0
  kill -"$sig" "${pids[@]}"
}
