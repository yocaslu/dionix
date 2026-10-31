#!/bin/sh
# Visualizador de áudio (cava) para a Waybar, em blocos ▁▂▃▄▅▆▇█.
# Imprime uma linha vazia quando não há som, e a Waybar esconde o módulo.
command -v cava >/dev/null 2>&1 || exit 0

conf="$(mktemp -t waybar-cava.XXXXXX)"
trap 'rm -f "$conf"' EXIT
trap 'exit 0' INT TERM

cat >"$conf" <<EOF
[general]
bars = 12
framerate = 30

[input]
# pulse funciona com o pipewire-pulse no Arch e no Debian
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

cava -p "$conf" | sed -u '
  s/;//g
  /^0*$/ { s/.*//; b }
  s/0/▁/g; s/1/▂/g; s/2/▃/g; s/3/▄/g; s/4/▅/g; s/5/▆/g; s/6/▇/g; s/7/█/g
'
