# Testes do forge-update, com curl, gh, git, nh e pkill falsos.
# Uso: forge-update-test.sh <forge-update.sh>
set -u

script=$1
failures=0
root=$(mktemp -d)
trap 'command rm -rf "$root"' EXIT
mkdir -p "$root/bin"

# curl falso: serve $ESTADO em /forge/estado (falha com $PI_FORA) e registra os pedidos
cat > "$root/bin/curl" << 'EOF2'
#!/bin/sh
for a; do url=$a; done
echo "curl $*" >> "$CALLS"
case "$url" in
  */forge/estado) [ -z "${PI_FORA:-}" ] && printf '%s' "$ESTADO" ;;
  */nix-cache-info) [ -z "${CACHE_FORA:-}" ] ;;
  *) true ;;
esac
EOF2
cat > "$root/bin/gh" << 'EOF2'
#!/bin/sh
echo "gh $*" >> "$CALLS"
case "$1 $2" in
  "pr view") printf '{"mergeStateStatus": "%s", "baseRefOid": "abc"}\n' "$MERGE" ;;
esac
EOF2
for cmd in git nh pkill sleep; do
  printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\n' "$cmd" > "$root/bin/$cmd"
done
chmod +x "$root/bin/"*

run() {
  : > "$root/calls"
  CALLS=$root/calls DIONIX_DOMAIN=exemplo.test NH_FLAKE=/flake PATH=$root/bin:$PATH \
    bash "$script" "$@" > "$root/output" 2>&1 << EOF2
${RESPOSTA:-}

EOF2
  status=$?
}

check() {
  if ! eval "$2"; then
    echo "FALHOU: $1 [$2]"
    sed 's/^/  | /' "$root/output"
    sed 's/^/  > /' "$root/calls"
    failures=$((failures + 1))
  fi
}

calls_have() { grep -q -- "$1" "$root/calls"; }

export ESTADO='{"estado": "nada", "rev": null, "pr": null, "url": null, "resumo": ""}'
run
check "nada esconde o módulo" '[ "$(jq -r .class "$root/output")" = none ] && [ "$(jq -r .text "$root/output")" = "" ]'

export ESTADO='{"estado": "compilando", "rev": "r", "pr": null, "url": null, "resumo": ""}'
run
check "compilando" '[ "$(jq -r .class "$root/output")" = building ] && [ "$(jq -r .text "$root/output")" = "…" ]'

export ESTADO='{"estado": "pendente", "rev": null, "pr": null, "url": null, "resumo": ""}'
run
check "pendente" '[ "$(jq -r .class "$root/output")" = building ]'

export ESTADO='{"estado": "pronto", "rev": "r", "pr": 30, "url": "u", "resumo": "3 pacotes"}'
run
check "pronto: classe" '[ "$(jq -r .class "$root/output")" = pending ]'
check "pronto: texto" '[ "$(jq -r .text "$root/output")" = "#30" ]'
check "pronto: tooltip" '[ "$(jq -r .tooltip "$root/output")" = "$(printf "3 pacotes\nclique para aplicar")" ]'

export ESTADO='{"estado": "falhou", "rev": "r", "pr": null, "url": null, "resumo": ""}'
run
check "falhou: classe" '[ "$(jq -r .class "$root/output")" = failed ] && [ "$(jq -r .text "$root/output")" = "!" ]'
check "falhou: tooltip" 'jq -r .tooltip "$root/output" | grep -q "journalctl -u forge-update"'

PI_FORA=1 run
check "Pi fora" '[ "$(jq -r .class "$root/output")" = none ]'
unset PI_FORA

# --aplicar
export ESTADO='{"estado": "falhou", "rev": "r", "pr": null, "url": null, "resumo": ""}'
run --aplicar
check "aplicar falhou: tenta de novo" 'calls_have "POST .*/forge/tentar"'
check "aplicar falhou: avisa a Waybar" 'calls_have "pkill -RTMIN+8 waybar"'

export ESTADO='{"estado": "pronto", "rev": "r", "pr": 30, "url": "u", "resumo": "3 pacotes"}'
RESPOSTA=n run --aplicar
check "aplicar recusado: nada é feito" '! calls_have "gh pr merge" && ! calls_have "nh os switch"'

for m in BEHIND DIRTY; do
  MERGE=$m RESPOSTA=s run --aplicar
  check "$m: pede nova compilação" 'calls_have "POST .*/forge/tentar"'
  check "$m: não mescla" '! calls_have "gh pr merge" && ! calls_have "nh os switch"'
done

MERGE=UNKNOWN RESPOSTA=s run --aplicar
check "UNKNOWN: não mescla nem tenta" '! calls_have "gh pr merge" && ! calls_have "forge/tentar"'
check "UNKNOWN: avisa" 'grep -q "instantes" "$root/output"'

for m in CLEAN UNSTABLE BLOCKED; do
  MERGE=$m RESPOSTA=s run --aplicar
  check "$m: acorda o forge" 'calls_have "/acordar/forge"'
  check "$m: mescla" 'calls_have "gh pr merge 30 --squash --delete-branch"'
  check "$m: atualiza e aplica" 'calls_have "git -C /flake pull --ff-only" && calls_have "nh os switch /flake"'
done

MERGE=CLEAN CACHE_FORA=1 RESPOSTA=s run --aplicar
check "cache fora: não mescla" '! calls_have "gh pr merge" && grep -q "3 minutos" "$root/output"'
unset CACHE_FORA

[ "$failures" -eq 0 ] && echo "forge-update: tudo certo"
exit "$failures"
