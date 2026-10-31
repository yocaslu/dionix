# Convertido de dot_config/helix/languages.toml (yocaslu/dotfiles)
{
  language-server = {
    arduino-lsp = {
      command = "arduino-language-server";
      args = [
        "-cli"
        "arduino-cli"
        "-cli-config"
        "~/.arduino15/arduino-cli.yaml"
        "-clangd"
        "clangd"
      ];
    };
    pyright = {
      command = "pyright-langserver";
      args = [ "--stdio" ];
      config = {
        python = {
          analysis = {
            venvPath = ".";
            venv = ".venv";
            lint = true;
            inlayHint = {
              enable = true;
            };
            autoSearchPaths = true;
            diagnosticMode = "workspace";
            useLibraryCodeForType = true;
            logLevel = "Error";
            typeCheckingMode = "off";
            autoImoprtCompletion = true;
            reportOptionalSubscript = false;
            reportOptionalMemberAccess = false;
          };
        };
      };
    };
    ruff = {
      command = "ruff";
      args = [
        "server"
        "-q"
        "--preview"
      ];
    };
  };
  grammar = [
    {
      name = "cpp";
      source = {
        git = "https://github.com/tree-sitter/tree-sitter-cpp";
        rev = "a90f170f92d5d70e7c2d4183c146e61ba5f3a457";
      };
    }
    {
      name = "arduino";
      source = {
        git = "https://github.com/ObserverOfTime/tree-sitter-arduino";
        rev = "db929fc6822b9b9e1211678d508f187894ce0345";
      };
    }
  ];
  language = [
    {
      name = "arduino";
      grammar = "c";
      scope = "source.arduino";
      injection-regex = "arduino";
      file-types = [ "ino" ];
      roots = [ "sketch.yaml" ];
      language-servers = [ "arduino-lsp" ];
    }
    {
      name = "python";
      scope = "source.python";
      injection-regex = "python";
      file-types = [
        "py"
        "pyi"
        "py3"
        "pyw"
        "ptl"
        "rpy"
        "cpy"
        "ipy"
        "pyt"
        {
          glob = ".python_history";
        }
        {
          glob = ".pythonstartup";
        }
        {
          glob = ".pythonrc";
        }
        {
          glob = "SConstruct";
        }
        {
          glob = "SConscript";
        }
      ];
      shebangs = [ "python" ];
      roots = [
        "pyproject.toml"
        "setup.py"
        "poetry.lock"
        "pyrightconfig.json"
        "requirements.txt"
        ".venv/"
      ];
      comment-token = "#";
      language-servers = [
        {
          name = "pyright";
          except-features = [ "diagnostics" ];
        }
        "ruff"
      ];
      indent = {
        tab-width = 4;
        unit = "    ";
      };
      auto-format = true;
      formatter = {
        command = "bash";
        args = [
          "-c"
          "ruff format --line-length 80 -q . && black --line-length 80 -q -"
        ];
      };
    }
  ];
}
