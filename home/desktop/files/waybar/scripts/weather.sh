#!/bin/sh
# Clima para a Waybar via wttr.in (JSON).
#   weather.sh         temperatura no módulo, detalhes no tooltip
#   weather.sh --full  previsão completa no terminal
#
# Sem local definido, o wttr.in usa a localização aproximada do IP. Para fixar
# uma cidade sem colocá-la no repositório (público), use a variável
# WTTR_LOCATION ou o arquivo ~/.config/waybar/weather-location (ex.: Sao+Paulo).

loc="${WTTR_LOCATION:-}"
file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/weather-location"
if [ -z "$loc" ] && [ -r "$file" ]; then
  loc=$(head -n 1 "$file")
fi

if [ "$1" = "--full" ]; then
  curl -fsS "https://wttr.in/${loc}?lang=pt&m"
  exit 0
fi

# %t temperatura, %C condição, %f sensação, %h umidade, %w vento, %l local
data=$(curl -fsS --max-time 10 "https://wttr.in/${loc}?format=%t%7C%C%7C%f%7C%h%7C%w%7C%l&lang=pt&m" 2>/dev/null)
case "$data" in
  "" | *"Unknown location"* | *"<"*)
    printf '{"text": ""}\n'
    exit 0
    ;;
esac

# Remove aspas e barras invertidas para não quebrar o JSON
data=$(printf '%s' "$data" | tr -d '\\"')
IFS='|' read -r temp cond feels hum wind place <<EOF
$data
EOF

printf '{"text": "%s", "tooltip": "%s\\n%s, sensação %s\\numidade %s, vento %s"}\n' \
  "${temp#+}" "$place" "$cond" "${feels#+}" "$hum" "$wind"
