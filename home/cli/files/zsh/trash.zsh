# Lixeira (trash-cli). Sem o trash-cli, o rm continua normal.

(( $+commands[trash-put] )) || return 0

alias tp='trash-put'
alias tl='trash-list'
alias trr='trash-restore'
alias te='trash-empty 30'
# print -r: o echo do zsh leria o "\r" de "\rm" como retorno de carro
alias rm='print -r -- "Use tp (lixeira) ou \\rm (definitivo)"; false'

# ftr: escolhe itens da lixeira (Tab marca vários) e restaura.
# O trash-restore só é interativo: ele lista os itens com um índice e lê os
# índices escolhidos da entrada padrão (ex.: "0,3"). Os dois comandos usam
# --sort path em "/", então a numeração é a mesma na listagem e na restauração.
ftr() {
  (( $+commands[fzf] )) || { echo "ftr: precisa do fzf" >&2; return 1; }
  local -a items indexes
  items=("${(@f)$(command trash-restore --sort path / </dev/null 2>/dev/null |
    command grep -E '^ *[0-9]+ ')}")
  if [[ -z ${items[1]} ]]; then
    echo "ftr: a lixeira está vazia"
    return 0
  fi
  indexes=(${(f)"$(print -rl -- "${items[@]}" |
    fzf --multi --prompt 'restaurar> ' --header 'Tab marca vários' |
    command awk '{print $1}')"})
  (( ${#indexes} )) || return 0
  print -r -- "${(j:,:)indexes}" | command trash-restore --sort path / >/dev/null
}
