#!/usr/bin/env bash
# Troca o tema: `theme` abre o menu e `theme <nome>` aplica direto.
# `theme --reapply <geração>` roda na ativação da configuração base: registra a
# geração e reaplica o tema salvo, porque um rebuild volta ao tema padrão.
set -euo pipefail

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/dionix
state_file=$state_dir/theme
base_file=$state_dir/base-generation

known_theme() {
  case " $DIONIX_THEMES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

reapply() {
  local generation=$1 saved=""
  mkdir -p "$state_dir"
  printf '%s\n' "$generation" > "$base_file"

  # A troca para o tema padrão ativa a base, que não pode desfazer a troca
  [ -z "${DIONIX_THEME_SKIP_REAPPLY:-}" ] || return 0
  [ -r "$state_file" ] && saved=$(< "$state_file")
  [ -n "$saved" ] && [ "$saved" != "$DIONIX_DEFAULT_THEME" ] || return 0

  if ! known_theme "$saved"; then
    echo "theme: o tema salvo '$saved' não existe mais; mantendo $DIONIX_DEFAULT_THEME" >&2
    return 0
  fi
  # Um tema que não aplica não pode derrubar o rebuild
  if "$generation/specialisation/$saved/activate"; then
    # A ativação aninhada não reinicia os serviços que a base acabou de subir
    reload_session
  else
    echo "theme: não foi possível reaplicar '$saved'; mantendo $DIONIX_DEFAULT_THEME" >&2
  fi
}

reload_session() {
  # Fora do Sway ou por SSH estes comandos falham, e o tema já foi aplicado
  swaymsg reload > /dev/null 2>&1 || true
  systemctl --user try-restart waybar.service swaync.service swayosd.service > /dev/null 2>&1 || true
}

if [ "${1:-}" = "--reapply" ]; then
  reapply "$2"
  exit 0
fi

name=${1:-}
if [ -z "$name" ]; then
  name=$(tr ' ' '\n' <<< "$DIONIX_THEMES" | fuzzel --dmenu --prompt "tema ❯ " || true)
  [ -n "$name" ] || exit 0
fi

if ! known_theme "$name"; then
  echo "theme: tema desconhecido '$name'. Temas: $DIONIX_THEMES" >&2
  exit 1
fi

if [ ! -r "$base_file" ]; then
  echo "theme: geração base desconhecida; rode um rebuild primeiro" >&2
  exit 1
fi
base=$(< "$base_file")

if [ "$name" = "$DIONIX_DEFAULT_THEME" ]; then
  DIONIX_THEME_SKIP_REAPPLY=1 "$base/activate"
else
  "$base/specialisation/$name/activate"
fi

mkdir -p "$state_dir"
printf '%s\n' "$name" > "$state_file"
reload_session
