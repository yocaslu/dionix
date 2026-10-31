# Troca o papel de parede (awww) com transição animada.
# Uso: wall ~/Downloads/foto.jpg   ou   wall backgrounds/foto.jpg (relativo a $WALLPAPER_DIR)
# O Sway carrega $WALLPAPER_DIR/.current ao iniciar; esta função atualiza esse link.
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

wall() {
  local img="$1"
  [ -f "$img" ] || img="$WALLPAPER_DIR/$1"
  if [ -z "$1" ] || [ ! -f "$img" ]; then
    echo "uso: wall <imagem>  (caminho ou nome dentro de $WALLPAPER_DIR)" >&2
    return 1
  fi
  mkdir -p "$WALLPAPER_DIR"
  ln -sf "$(realpath "$img")" "$WALLPAPER_DIR/.current"
  awww img "$WALLPAPER_DIR/.current" --transition-type grow
}
