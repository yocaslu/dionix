# Convertido de dot_config/starship/starship.toml (yocaslu/dotfiles)
{
  "$schema" = "https://starship.rs/config-schema.json";
  format = "$directory$git_branch$git_status$cmd_duration$status$line_break$character";
  add_newline = true;
  palette = "catppuccin_mocha";
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
    catppuccin_mocha = {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
      text = "#cdd6f4";
      subtext1 = "#bac2de";
      subtext0 = "#a6adc8";
      overlay2 = "#9399b2";
      overlay1 = "#7f849c";
      overlay0 = "#6c7086";
      surface2 = "#585b70";
      surface1 = "#45475a";
      surface0 = "#313244";
      base = "#1e1e2e";
      mantle = "#181825";
      crust = "#11111b";
    };
  };
}
