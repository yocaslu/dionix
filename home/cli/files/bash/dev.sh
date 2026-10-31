APPS="nvim nnn lazygit"
alias fdev="dev --fzf --apps $APPS"

PWD=$(pwd)
alias pdev="dev -d $(pwd) --apps $APPS"
