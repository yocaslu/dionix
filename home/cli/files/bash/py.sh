alias py="python3"

PY_SCRIPTS_PATH=$REPO_PATH/dotfiles/scripts/py_scripts
alias pyenv='python3 $PY_SCRIPTS_PATH/pyenv.py $(pwd) && source .env/bin/activate'

alias pp='poetry'

# pipx completions
# eval "$(register-python-argcomplete pipx)"
