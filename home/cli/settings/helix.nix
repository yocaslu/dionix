# Convertido de dot_config/helix/config.toml (yocaslu/dotfiles)
{
  theme = "catppuccin_mocha";
  editor = {
    cursorline = true;
    bufferline = "always";
    end-of-line-diagnostics = "warning";
    inline-diagnostics = {
      cursor-line = "error";
    };
    cursor-shape = {
      insert = "bar";
      normal = "block";
      select = "block";
    };
    file-picker = {
      hidden = true;
    };
    statusline = {
      left = [
        "mode"
        "spinner"
      ];
      center = [
        "file-absolute-path"
        "file-modification-indicator"
        "read-only-indicator"
      ];
      right = [
        "diagnostics"
        "version-control"
      ];
      separator = "][";
      mode = {
        normal = "NORMAL";
        insert = "INSERT";
        select = "SELECT";
      };
    };
    lsp = {
      display-progress-messages = true;
      display-inlay-hints = true;
    };
    whitespace = {
      characters = {
        space = "·";
        nbsp = "⍽";
        nnbsp = "␣";
        tab = "→";
        newline = "⏎";
        tabpad = "·";
      };
    };
    indent-guides = {
      render = true;
      character = "|";
      skip-levels = 1;
    };
    soft-wrap = {
      enable = true;
      max-wrap = 25;
      max-indent-retain = 0;
      wrap-indicator = "";
    };
  };
  keys = {
    normal = {
      C-s = ":w";
      C-o = ":open ~/.config/helix/config.toml";
      C-b = {
        n = ":buffer-next";
        p = ":buffer-previous";
        x = ":buffer-close";
      };
    };
    insert = {
      j = {
        k = "normal_mode";
      };
      C-j = "move_line_down";
      C-k = "move_line_up";
      C-l = "move_char_right";
      C-h = "move_char_left";
    };
  };
}
