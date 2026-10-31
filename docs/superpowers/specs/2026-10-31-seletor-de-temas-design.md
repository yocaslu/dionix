# Seletor de temas com Stylix

Data: 2026-10-31

## Objetivo

Escolher uma paleta em um menu e aplicá-la aos aplicativos na hora, sem
`rebuild`, com todas as cores vindas de uma única fonte.

Hoje o Catppuccin Mocha está escrito à mão: 355 cores hexadecimais em 16
arquivos de `home/`, além de pacotes específicos em `home/desktop/theme.nix`.

## Requisitos

- Temas: `catppuccin-mocha` (padrão), `gruvbox-dark-medium`, `nord` e
  `tokyo-night-dark`, do pacote `base16-schemes`.
- A troca não exige `rebuild`. Adicionar um tema à lista exige.
- Vale para `notebook` e `desktop`. O `server` não recebe o Stylix.
- O visual TUI continua: cantos retos e bordas de 1px.
- O tema escolhido sobrevive a um `rebuild`.
- O `tuigreet` e a sessão XFCE não mudam.

## Fora do escopo

- Tema claro.
- Cores derivadas do wallpaper.
- Cursor e ícones por tema: os atuais do Catppuccin ficam em todos os temas.
- Host `server`.

## Arquitetura

### Temas

`home/desktop/themes.nix` define a lista de temas e o padrão. A configuração
base usa o padrão, e cada um dos outros temas vira uma
`specialisation.<tema>` do Home Manager, com as versões prontas geradas no
build.

O Stylix entra como input do flake (`github:nix-community/stylix/release-26.05`),
com `inputs.nixpkgs.follows = "nixpkgs"`, e é importado apenas em
`modules/nixos/workstation.nix`. Os alvos do Stylix são limitados para não
alterar a tela de login nem o XFCE.

### Cores

| Aplicativos | Como recebem as cores |
| --- | --- |
| Alacritty, btop, bat, tmux, yazi, Helix, fzf, zathura, mpv, spotify_player e outros com módulo | Módulo do Stylix |
| Waybar, swaync, wlogout, swayosd | CSS próprio mantido, com hexadecimais trocados por `config.lib.stylix.colors` |
| lsd, imv, vim | Templates com `config.lib.stylix.colors` |
| NvChad | Mapa de cada tema para o tema equivalente do base46 |

O módulo do Stylix para o Waybar não é usado no lugar do CSS atual, para
preservar o layout. O mesmo vale para o swaync.

### Comando `theme`

- `theme` sem argumento abre a lista no fuzzel. `theme <nome>` aplica direto.
- O menu `Super+x` (wlr-which-key) ganha uma entrada para o seletor.

Sequência da troca:

1. Valida o nome contra a lista de temas.
2. Ativa o tema: `specialisation/<tema>/activate` da geração atual do Home
   Manager, ou a geração base para o tema padrão.
3. Grava o nome em `~/.local/state/dionix/theme`.
4. Recarrega o que estiver aberto: Sway, Waybar, swaync e swayosd.

Nome inválido termina com mensagem de erro e não altera o estado. Se a ativação
falhar, o arquivo de estado também não muda.

### Persistência após `rebuild`

Um `rebuild` ativa a configuração base, ou seja, o tema padrão. Por isso, a base
tem um passo de ativação que lê o arquivo de estado e ativa o tema salvo.

As specialisations têm `specialisation = { }`, então não têm esse passo e não
há loop. Se o tema salvo não estiver mais na lista, fica o padrão e um aviso é
registrado.

## Riscos

- `specialisation` é uma opção experimental do Home Manager, e o processo de
  ativação pode mudar de forma incompatível. O ajuste fica concentrado no
  comando `theme` e no passo de reaplicação.
- Cada troca cria uma geração do Home Manager. O `nh clean` já remove as antigas.
- Cada tema aumenta a avaliação e o build, o que pesa no i5-3470 com 8 GB de RAM
  do desktop. A prova mede esse custo.
- Aplicativos abertos podem só mudar ao reiniciar, provavelmente GTK, Firefox e
  VS Code. A prova registra o comportamento real dos aplicativos que ela cobre.

## Etapa 1: prova

Feita em branch separada, com:

- Stylix no flake, os 4 temas como specialisations e o comando `theme` na forma
  final.
- Sway, Waybar e Alacritty usando as cores do tema. O restante continua em
  Catppuccin, e essa mistura é temporária.

| Critério | Passa se | Se falhar |
| --- | --- | --- |
| Tempo de troca | Até 5 s no desktop, medido com `time theme <tema>` | Parar e reavaliar |
| Tempo de `rebuild` | Até o dobro do atual, medido nos 2 casos | Apresentar os números; reduzir a lista é decisão do usuário |
| Apps abertos | Sway e Waybar mudam sem reabrir nada; Alacritty muda em janelas abertas | Registrar a limitação e seguir, se aceita pelo usuário |
| Tema após `rebuild` | O tema escolhido continua ativo | Parar, porque a arquitetura depende disso |
| Sessão | XFCE e `tuigreet` iguais a antes | Ajustar os alvos do Stylix |

A migração só começa depois que o usuário vir os números medidos e decidir seguir.

## Etapa 2: migração

Passar os demais aplicativos para a fonte única, em commits pequenos por grupo:
CLI, CSS, templates e NvChad.

## Testes

- Em cada commit: `nix fmt`, `nix flake check` e o build de `home-files`, que
  valida a configuração do Sway e roda o shellcheck nos scripts.
- Cores restantes: busca por hexadecimais do Catppuccin fora do que for
  intencional.
- Por tema: build das 4 versões e conferência das cores nos arquivos gerados.
- Comando: `theme` com nome inválido falha com mensagem clara e sem alterar o
  estado.
- Na tela: o usuário roda o `switch` e confere o resultado. O `switch` não é
  executado sem pedido do usuário.

## Documentação

- `home/cli/files/zsh/commands.md`: seção `## theme`.
- `CLAUDE.md`: as cores passam a vir de `home/desktop/themes.nix` e do Stylix,
  em vez de Catppuccin Mocha fixo. A regra de cantos retos e bordas de 1px fica.
