# yazi: `y` abre o gerenciador e, ao sair, muda o shell para a pasta onde você parou.
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd" || return
  fi
  rm -f -- "$tmp"
}
