# Testes do theme.sh, com geração e comandos falsos. Uso: theme-test.sh <theme.sh>
set -u

script=$1
failures=0
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

fake_activate() {
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\necho "%s skip=${DIONIX_THEME_SKIP_REAPPLY:-}" >> "$CALLS"\nexit "${ACTIVATE_STATUS:-0}"\n' "$2" > "$1"
  chmod +x "$1"
}

fake_command() {
  printf '#!/bin/sh\n%s\n' "$2" > "$root/bin/$1"
  chmod +x "$root/bin/$1"
}

# Cada caso começa do zero, com a geração base já registrada e o tema salvo em "$1"
setup() {
  rm -rf "${root:?}"/*
  mkdir -p "$root/bin" "$root/state/dionix"
  fake_activate "$root/gen/activate" base
  fake_activate "$root/gen/specialisation/nord/activate" nord
  fake_command swaymsg 'echo swaymsg >> "$CALLS"'
  fake_command systemctl 'echo systemctl >> "$CALLS"'
  fake_command fuzzel 'cat > /dev/null; echo "${FUZZEL_CHOICE:-}"'
  : > "$root/calls"
  printf '%s\n' "$root/gen" > "$root/state/dionix/base-generation"
  printf '%s\n' "$1" > "$root/state/dionix/theme"
  status=0
}

run() {
  CALLS=$root/calls XDG_STATE_HOME=$root/state PATH=$root/bin:$PATH \
    DIONIX_THEMES='catppuccin-mocha nord' DIONIX_DEFAULT_THEME=catppuccin-mocha \
    bash "$script" "$@" > "$root/output" 2>&1
  status=$?
}

check() {
  if ! eval "$2"; then
    echo "FALHOU: $1 [$2]"
    sed 's/^/  | /' "$root/output"
    failures=$((failures + 1))
  fi
}

called() { grep -qF -- "$1" "$root/calls"; }
saved() { [ "$(cat "$root/state/dionix/theme")" = "$1" ]; }

setup catppuccin-mocha
run nord
check "ativa uma specialisation" '[ $status = 0 ] && called "nord skip=" && saved nord && called swaymsg && called systemctl'

setup nord
run catppuccin-mocha
check "volta ao padrão sem reaplicar" '[ $status = 0 ] && called "base skip=1" && ! called "nord" && saved catppuccin-mocha'

setup nord
run invalido
check "nome inválido não muda nada" '[ $status != 0 ] && grep -q "catppuccin-mocha nord" "$root/output" && [ ! -s "$root/calls" ] && saved nord'

setup catppuccin-mocha
ACTIVATE_STATUS=3 run nord
check "falha na ativação mantém o estado" '[ $status != 0 ] && saved catppuccin-mocha'

setup catppuccin-mocha
rm "$root/state/dionix/base-generation"
run nord
check "sem geração base pede rebuild" '[ $status != 0 ] && grep -q rebuild "$root/output" && saved catppuccin-mocha'

setup catppuccin-mocha
fake_command swaymsg 'exit 1'
fake_command systemctl 'exit 1'
run nord
check "falha ao recarregar não é erro" '[ $status = 0 ] && saved nord'

setup catppuccin-mocha
run
check "menu cancelado não muda nada" '[ $status = 0 ] && [ ! -s "$root/calls" ] && saved catppuccin-mocha'

setup catppuccin-mocha
FUZZEL_CHOICE=nord run
check "menu aplica o escolhido" '[ $status = 0 ] && called "nord skip=" && saved nord'

setup nord
run --reapply "$root/novo"
check "reaplicação sem o tema na geração nova avisa" '[ $status = 0 ] && [ "$(cat "$root/state/dionix/base-generation")" = "$root/novo" ]'

setup nord
run --reapply "$root/gen"
check "reaplica o tema salvo" '[ $status = 0 ] && called "nord skip=" && saved nord'

setup nord
DIONIX_THEME_SKIP_REAPPLY=1 run --reapply "$root/gen"
check "variável impede a reaplicação" '[ $status = 0 ] && [ ! -s "$root/calls" ]'

setup catppuccin-mocha
run --reapply "$root/gen"
check "tema padrão não reaplica" '[ $status = 0 ] && [ ! -s "$root/calls" ]'

setup removido
run --reapply "$root/gen"
check "tema fora da lista avisa e fica o padrão" '[ $status = 0 ] && grep -q removido "$root/output" && [ ! -s "$root/calls" ]'

setup nord
rm "$root/state/dionix/theme"
run --reapply "$root/gen"
check "sem tema salvo fica o padrão" '[ $status = 0 ] && [ ! -s "$root/calls" ]'

setup nord
ACTIVATE_STATUS=3 run --reapply "$root/gen"
check "falha ao reaplicar não derruba o rebuild" '[ $status = 0 ] && grep -q nord "$root/output"'

if [ "$failures" != 0 ]; then
  echo "$failures caso(s) falharam"
  exit 1
fi
echo "todos os casos passaram"
