# Ajuda

<!--
Documentação dos aliases e funções, usada pelo `cmds` e pelo Ctrl+Espaço
(~/.config/zsh/cmds.zsh). Formato:

  # Categoria                 agrupa os itens seguintes
  ## nome                     um alias ou função
  Resumo em uma linha.        aparece na lista do fzf
  Detalhes, uso, exemplos.    aparecem no preview

Ao criar um alias ou função, documente aqui. `cmds --check` lista os que
estão sem documentação.
-->

## cmds
Busca nos aliases e funções, com esta documentação no preview.
Enter coloca o item escolhido no prompt. Também abre com Ctrl+Espaço
no meio de um comando, completando a palavra atual.

Uso: `cmds [busca]` · `cmds --check` lista o que está sem documentação.

# Listagem

## ls
Lista arquivos com ícones, pastas primeiro (eza).

## la
Como `ls`, incluindo arquivos ocultos.

## ll
Lista detalhada: permissões, tamanho, datas e status do git.

## lt
Árvore de diretórios com 2 níveis.

Exemplo: `lt src`

# Arquivos e sistema

## bat
`bat` no Debian, onde o binário se chama `batcat`.

## cat
Mostra arquivos com destaque de sintaxe (bat), sem paginar.
Para o `cat` original: `\cat` ou `command cat`.

## top
Monitor do sistema (btop).

## du
Uso de disco por pasta, em árvore (dust).

## df
Espaço livre nos discos, em tabela (duf).

## cp
`cp` que pergunta antes de sobrescrever.

## mv
`mv` que pergunta antes de sobrescrever.

## grep
`grep` com cores. É o grep de verdade: para ripgrep use `rg`.

## mkcd
Cria uma pasta (com as intermediárias) e entra nela.

Uso: `mkcd projetos/novo`

## bkp
Copia um arquivo ou pasta para `<nome>.bak.<data-hora>`.

Uso: `bkp config.toml` → `config.toml.bak.20261026-101500`

## extract
Extrai qualquer arquivo compactado pela extensão.

Formatos: tar.gz, tgz, tar.bz2, tar.xz, tar.zst, tar, zip, rar, 7z, gz.

Uso: `extract arquivo.tar.xz`

## port
Mostra qual processo está usando uma porta (lsof).

Uso: `port 8080`

## serve
Servidor HTTP da pasta atual (python), na porta 8000 ou na informada.

Uso: `serve` · `serve 3000`

## myip
Mostra o IP público (ifconfig.me).

# Navegação

## ..
Sobe uma pasta.

## ...
Sobe duas pastas.

## -
Volta para a pasta anterior (`cd -`).

## y
Abre o yazi; ao sair, o shell entra na pasta onde você parou.

## nnn
Abre o nnn; ao sair, o shell entra na pasta onde você parou.

# Busca (fzf)

## fe
Escolhe um ou mais arquivos com preview e abre no `$EDITOR`.
Tab marca vários; a busca inicial é opcional.

Uso: `fe` · `fe zshrc`

## rgf
Busca no conteúdo com ripgrep, ao vivo; Enter abre o arquivo na linha.

Uso: `rgf` · `rgf TODO`

## fbr
Troca de branch do git (locais e remotas, as mais recentes primeiro).
Escolher `origin/feat` cria a branch local `feat` rastreando o remoto.

## fkill
Escolhe processos e manda um sinal (padrão 15/TERM).
Tab marca vários.

Uso: `fkill` · `fkill 9` · `fkill KILL`

# Lixeira

## tp
Move para a lixeira (trash-put).

Uso: `tp arquivo pasta/`

## tl
Lista o que está na lixeira.

## trr
Restaura da lixeira, escolhendo pelo número (trash-restore).

## te
Apaga da lixeira os itens com mais de 30 dias.

## ftr
Escolhe itens da lixeira com o fzf (Tab marca vários) e restaura.

## rm
Bloqueado para evitar apagar sem querer: use `tp` (lixeira).
Para apagar de vez: `\rm` ou `command rm`.

# Git

## g
Atalho para `git`.

## gs
Status curto, com a branch (`git status -sb`).

## gl
Log das últimas 20 entradas em grafo.

## lg
Abre o lazygit.

## lgit
Abre o lazygit (alias antigo do Bash).

# Shell

## reload
Reinicia o zsh, recarregando toda a config.

## path
Mostra o PATH, um diretório por linha.

## cl
Limpa a tela.

## fetch
Informações do sistema (fastfetch).

## syu
Atualiza o `flake.lock` e aplica a nova configuração (`nh os switch --update`).

## rebuild
Aplica a configuração do dionix sem atualizar o `flake.lock` (`nh os switch`).

## theme
Troca a paleta de cores sem rebuild (só em notebook e desktop).

Uso: `theme` abre o menu (também em Super+x m) · `theme nord` aplica direto.
Temas: `catppuccin-mocha`, `gruvbox-dark-medium`, `nord`, `tokyo-night-dark`.

## ssh-key-restore
Instala em `~/.ssh` a chave SSH desta máquina, guardada no cofre do Bitwarden (só em notebook e desktop).

Uso: rode `rbw unlock` e depois `ssh-key-restore` (usa a entrada com o nome da máquina)
ou `ssh-key-restore notebook`. Nunca sobrescreve uma chave existente.

## wall
Troca o papel de parede (awww) com transição.

Uso: `wall foto.png` (caminho completo ou relativo a `~/Pictures/Wallpapers`)

# Desenvolvimento

## py
Atalho para `python3`.

## pp
Atalho para `poetry`.

## pyenv
Cria ou ativa o virtualenv `.env` da pasta atual (script em `~/repos/dotfiles/scripts`).

## fdev
Abre o ambiente `dev` escolhendo o projeto com o fzf.

## pdev
Abre o ambiente `dev` na pasta onde o shell foi aberto.
Atenção: a pasta é fixada quando o shell inicia, não quando o alias roda.

## box
Atalho para `distrobox`.

# Instalação

## download-sdkman
Instala o SDKMAN (gerenciador de SDKs Java/Kotlin).

# CPU

## info-frequency
Mostra as frequências e o governor da CPU (cpupower).

## set-frequency
Define a frequência máxima da CPU.

Uso: `set-frequency 2000Mhz`

## base-freq
Limita a CPU a 1400 MHz.
