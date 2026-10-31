# Funções utilitárias

mkcd() { mkdir -p "$1" && cd "$1"; }
port() { lsof -i :"$1"; }
serve() { python3 -m http.server "${1:-8000}"; }
bkp() { cp -r "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"; }

extract() {
  [[ -f "$1" ]] || { echo "Arquivo não encontrado: $1"; return 1; }
  case "$1" in
    *.tar.gz|*.tgz) tar xzf "$1" ;;
    *.tar.bz2)      tar xjf "$1" ;;
    *.tar.xz)       tar xJf "$1" ;;
    *.tar.zst)      tar --zstd -xf "$1" ;;
    *.tar)          tar xf "$1" ;;
    *.zip)          unzip "$1" ;;
    *.rar)          if (( $+commands[unrar] )); then unrar x "$1"; else 7z x "$1"; fi ;;
    *.7z)           7z x "$1" ;;
    *.gz)           gunzip "$1" ;;
    *) echo "Formato não suportado: $1"; return 1 ;;
  esac
}
