# Convertido de dot_config/starship/starship.toml (yocaslu/dotfiles)
colors: {
  "$schema" = "https://starship.rs/config-schema.json";
  format = "$directory$git_branch$git_status$cmd_duration$status$line_break$character";
  add_newline = true;
  palette = "tema";
  directory = {
    style = "bold mauve";
    truncation_length = 3;
    truncate_to_repo = true;
  };
  git_branch = {
    format = "[$symbol$branch]($style) ";
    symbol = " ";
    style = "green";
  };
  git_status = {
    format = "([$all_status$ahead_behind]($style) )";
    style = "peach";
  };
  cmd_duration = {
    min_time = 2000;
    format = "[took $duration]($style) ";
    style = "yellow";
  };
  status = {
    disabled = false;
    format = "[✗ $status]($style) ";
    style = "red";
  };
  character = {
    success_symbol = "[❯](mauve)";
    error_symbol = "[❯](red)";
    vimcmd_symbol = "[❮](green)";
  };
  palettes = {
    tema = {
      rosewater = "${colors.base06}";
      flamingo = "${colors.base0F}";
      pink = "${colors.base0E}";
      mauve = "${colors.base0E}";
      red = "${colors.base08}";
      maroon = "${colors.base08}";
      peach = "${colors.base09}";
      yellow = "${colors.base0A}";
      green = "${colors.base0B}";
      teal = "${colors.base0C}";
      sky = "${colors.base0C}";
      sapphire = "${colors.base0C}";
      blue = "${colors.base0D}";
      lavender = "${colors.base07}";
      text = "${colors.base05}";
      subtext1 = "${colors.base04}";
      subtext0 = "${colors.base04}";
      overlay2 = "${colors.base04}";
      overlay1 = "${colors.base03}";
      overlay0 = "${colors.base03}";
      surface2 = "${colors.base02}";
      surface1 = "${colors.base02}";
      surface0 = "${colors.base01}";
      base = "${colors.base00}";
      mantle = "${colors.base00}";
      crust = "${colors.base00}";
    };
  };
}
