# Auto-complete dos nossos aliases e funções com o fzf, documentado.
#   Ctrl+Espaço   completa a palavra atual (ou escolhe um comando)
#   cmds [busca]  escolhe um item e o coloca no prompt
#   cmds --check  lista aliases e funções sem documentação
# A documentação fica em ~/.config/zsh/commands.md.

(( $+commands[fzf] )) || return 0
zmodload -F zsh/parameter p:functions_source 2>/dev/null

ZSH_CMDS_DOC="${ZSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/commands.md"

# Lê o commands.md: _cmds_doc_summary[nome], _cmds_doc_body[nome], _cmds_doc_group[nome]
_cmds_read_doc() {
  typeset -gA _cmds_doc_summary _cmds_doc_body _cmds_doc_group
  _cmds_doc_summary=() _cmds_doc_body=() _cmds_doc_group=()
  [[ -r $ZSH_CMDS_DOC ]] || return 0
  local line name="" group="" in_comment=0
  while IFS= read -r line || [[ -n $line ]]; do
    if (( in_comment )); then
      [[ $line == *'-->'* ]] && in_comment=0
      continue
    fi
    if [[ $line == '<!--'* ]]; then
      [[ $line == *'-->'* ]] || in_comment=1
      continue
    fi
    if [[ $line == '## '* ]]; then
      name="${line#\#\# }"
      _cmds_doc_group[$name]="$group"
      _cmds_doc_body[$name]=""
    elif [[ $line == '# '* ]]; then
      group="${line#\# }"
      name=""
    elif [[ -n $name ]]; then
      [[ -z ${_cmds_doc_summary[$name]} && -n $line ]] && _cmds_doc_summary[$name]="$line"
      _cmds_doc_body[$name]+="$line"$'\n'
    fi
  done <"$ZSH_CMDS_DOC"
}

# Aliases e funções que são nossos: os documentados, os aliases que não são
# do próprio zsh e as funções definidas em ~/.config/zsh ou ~/.config/bashrc
_cmds_names() {
  local name dir="${ZSH_CONFIG_DIR:-$HOME/.config/zsh}" bashrc="${XDG_CONFIG_HOME:-$HOME/.config}/bashrc"
  local -aU names
  names=(${(k)_cmds_doc_summary} ${(k)aliases:#(run-help|which-command)})
  for name in ${(k)functions}; do
    [[ $name == _* ]] && continue
    [[ ${functions_source[$name]} == ($dir|$bashrc)/* ]] && names+=("$name")
  done
  # Só o que existe nesta sessão (um alias de ferramenta não instalada some)
  for name in ${(o)names}; do
    (( $+aliases[$name] || $+functions[$name] )) && print -r -- "$name"
  done
}

# Monta a lista e os previews em $1; imprime "índice<TAB>nome<TAB>tipo<TAB>grupo<TAB>resumo"
_cmds_prepare() {
  local dir="$1" name kind def i=0
  _cmds_read_doc
  for name in ${(f)"$(_cmds_names)"}; do
    (( i++ ))
    if (( $+aliases[$name] )); then
      kind=alias
      def="alias ${(q)name}=${(q)aliases[$name]}"
    else
      kind=função
      def="$(functions -- "$name")"
    fi
    {
      print -r -- "# $name ($kind)"
      print
      if [[ -n ${_cmds_doc_body[$name]} ]]; then
        print -r -- "${_cmds_doc_body[$name]}"
      else
        print -r -- '*(sem documentação: adicione uma seção `## '"$name"'` em ~/.config/zsh/commands.md)*'
        print
      fi
      print -r -- '```zsh'
      print -r -- "$def"
      print -r -- '```'
    } >"$dir/$i.md"
    # Só as colunas visíveis são alinhadas; o índice (usado no preview) não
    print -r -- "$i"$'\t'"${(r:16:)name}"$'\t'"${(r:7:)kind}"$'\t'"${(r:19:)${_cmds_doc_group[$name]:--}}"$'\t'"${_cmds_doc_summary[$name]:-(sem documentação)}"
  done
}

# Abre o fzf e imprime o nome escolhido. $1 = busca inicial.
_cmds_pick() {
  emulate -L zsh
  local dir sel preview
  dir="$(mktemp -d -t zsh-cmds.XXXXXX)" || return 1
  if (( $+commands[bat] )); then
    preview="bat --color=always --style=plain --language=md $dir/{1}.md"
  else
    preview="cat $dir/{1}.md"
  fi
  # --nth conta as colunas exibidas: nome, tipo, grupo, resumo
  sel=$(_cmds_prepare "$dir" |
    fzf --delimiter=$'\t' --with-nth=2.. --nth=1,3,4 --no-multi \
      --query="$1" --prompt='cmds> ' \
      --header='Enter insere · Ctrl+/ esconde a ajuda' \
      --preview="$preview" --preview-window='right,55%,wrap' \
      --bind='ctrl-/:toggle-preview')
  # `command`: este arquivo é carregado depois do trash.zsh, que troca o rm por um aviso
  command rm -rf -- "$dir"
  [[ -n $sel ]] || return 1
  sel="${${(@ps:\t:)sel}[2]}"
  print -r -- "${sel// /}"
}

cmds() {
  if [[ $1 == --check ]]; then
    _cmds_read_doc
    local name missing=0
    for name in ${(f)"$(_cmds_names)"}; do
      if [[ -z ${_cmds_doc_summary[$name]} ]]; then
        print -r -- "sem documentação: $name"
        missing=1
      fi
    done
    (( missing )) || print "todos os aliases e funções estão documentados"
    return $missing
  fi
  local sel
  sel="$(_cmds_pick "$*")" || return 0
  # Coloca no próximo prompt, pronto para completar os argumentos
  print -z -- "$sel "
}

# Widget: completa a palavra antes do cursor (a palavra vira a busca inicial)
_cmds_widget() {
  local word="${LBUFFER##*[[:space:]]}" sel
  sel="$(_cmds_pick "$word")"
  if [[ -n $sel ]]; then
    LBUFFER="${LBUFFER[1,$(( ${#LBUFFER} - ${#word} ))]}$sel "
  fi
  zle reset-prompt
}
zle -N _cmds_widget
# Ctrl+Espaço chega como ^@
bindkey '^@' _cmds_widget
