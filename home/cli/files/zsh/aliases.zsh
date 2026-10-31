# Aliases. Cada um só existe se a ferramenta estiver instalada.
# Sem alias para grep→rg (flags incompatíveis) nem para tr.

# Listagem
(( $+commands[eza] )) && alias ls='eza --icons --group-directories-first'
(( $+commands[eza] )) && alias la='eza -a --icons --group-directories-first'
(( $+commands[eza] )) && alias ll='eza -lah --icons --git --group-directories-first'
(( $+commands[eza] )) && alias lt='eza --tree --level=2 --icons'

(( $+commands[bat] )) && alias cat='bat --paging=never'
(( $+commands[btop] )) && alias top='btop'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[duf] ))  && alias df='duf'

# Navegação
alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'

# Git
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
(( $+commands[lazygit] )) && alias lg='lazygit'

# Segurança
alias cp='cp -i'
alias mv='mv -i'

# Utilidades
alias reload='exec zsh'
alias path='print -l $path'
alias myip='curl -s ifconfig.me; echo'
alias grep='grep --color=auto'

# Vindos do antigo ~/.config/bashrc/terminal.sh
alias cl='clear'
(( $+commands[fastfetch] )) && alias fetch='fastfetch'
# NixOS: atualiza o flake.lock e aplica (nh usa o flake definido em NH_FLAKE)
(( $+commands[nh] )) && alias syu='nh os switch --update'
(( $+commands[nh] )) && alias rebuild='nh os switch'

return 0
