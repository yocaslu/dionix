# Seletor de temas: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar a paleta dos aplicativos por um menu, sem `rebuild`, com as cores vindas de uma única fonte.

**Architecture:** O Stylix gera a paleta a partir de um esquema base16. Cada tema além do padrão é uma `specialisation` do Home Manager, e o comando `theme` ativa a escolhida. Os arquivos leem `config.dionix.colors`, que tem Catppuccin Mocha como padrão e recebe a paleta do Stylix em `home/desktop`.

**Tech Stack:** NixOS 26.05, Home Manager `release-26.05`, Stylix `release-26.05`, base16-schemes, Bash.

**Spec:** `docs/superpowers/specs/2026-10-31-seletor-de-temas-design.md`

## Global Constraints

- Temas: `catppuccin-mocha` (padrão), `gruvbox-dark-medium`, `nord`, `tokyo-night-dark`.
- Estado: `~/.local/state/dionix/theme` (respeitando `XDG_STATE_HOME`).
- `server` sem Stylix; `tuigreet` e XFCE sem mudança.
- Cantos retos e bordas de 1px continuam.
- Comentários em português. Commits em Conventional Commits, só com os arquivos da tarefa.
- Nunca rodar `nixos-rebuild switch` ou `rebuild`: esses passos são do usuário.
- Em cada commit: `nix fmt`, `nix flake check --no-build` e build de `home-files` passam.

## Review Focus

- Troca para o tema padrão com outro tema salvo: o passo de reaplicação não pode desfazer a troca (Tarefa 2).
- Tema salvo que saiu da lista: fica o padrão, com aviso, e a ativação não falha (Tarefa 2).
- `theme` depois de já estar em uma specialisation: a geração atual não tem `specialisation/`, então o comando precisa achar a base (Tarefa 2).
- `theme` fora do Sway, por SSH ou no XFCE: troca o tema e não falha ao recarregar (Tarefa 2).
- Abrir o Neovim depois de trocar o tema: o cache do base46 não pode manter as cores antigas (Tarefa 7).

## Pré-requisito

As alterações pendentes da conversa (`CLAUDE.md`, `git.nix`, `shell.nix`, `apps.nix`, `spotify-player.nix`, `hardware-configuration.nix`, `common.nix`, `workstation.nix`) precisam estar commitadas antes da Tarefa 1, porque esta branch altera os mesmos arquivos.

## Mapa de cores

`@baseXX@` no template vira `#rrggbb`; `@baseXX-rgb@` vira `r, g, b`.

| Catppuccin | Token | Catppuccin | Token |
| --- | --- | --- | --- |
| `#1e1e2e` base | `base00` | `#f38ba8` red | `base08` |
| `#313244` surface0 | `base01` | `#fab387` peach | `base09` |
| `#45475a` surface1 | `base02` | `#f9e2af` yellow | `base0A` |
| `#6c7086` overlay0 | `base03` | `#a6e3a1` green | `base0B` |
| `#a6adc8` subtext0 | `base04` | `#94e2d5` teal | `base0C` |
| `#cdd6f4` text | `base05` | `#89b4fa` blue | `base0D` |
| `#f5e0dc` rosewater | `base06` | `#cba6f7` mauve | `base0E` |
| `#b4befe` lavender | `base07` | `#f2cdcd` flamingo | `base0F` |

Fora do esquema base16: `#11111b` crust vira `base00`; `#9399b2` overlay2 vira `base04`; `#89dceb` sky e `#74c7ec` sapphire viram `base0C`; `#f5c2e7` pink vira `base0E`. Hexadecimais em maiúsculas seguem o mesmo mapa.

---

## Etapa 1: prova

### Tarefa 1: Stylix, opção de cores e specialisations

**Files:**
- Create: `home/cli/colors.nix`, `home/desktop/themes.nix`
- Modify: `flake.nix`, `flake.lock`, `home/cli/default.nix`, `home/desktop/default.nix`, `modules/nixos/workstation.nix`

**Interfaces:**
- Produces: `config.dionix.colors.base00`…`base0F` (`#rrggbb`), `config.dionix.render : string -> string` (substitui os tokens), `config.dionix.theme : string`, `config.dionix.nvchadTheme : string`.

- [ ] **Passo 1: Medir o tempo de referência**

Antes de mudar o código, no `main` com os pré-requisitos, sem cache de avaliação:
`time nix build --no-link --no-eval-cache .#nixosConfigurations.desktop.config.system.build.toplevel`.
Anotar o tempo para o critério da Tarefa 4. Medir de novo depois de mudar um arquivo `.md`, porque o store já tem quase tudo: esse é o caso real de um `rebuild`.

- [ ] **Passo 2: Criar `home/cli/colors.nix`**

Opções: `dionix.colors` (padrão: os 16 valores do Catppuccin Mocha do mapa), `dionix.theme` (padrão `"catppuccin-mocha"`), `dionix.nvchadTheme` (padrão `"catppuccin"`), `dionix.render` (somente leitura), que usa `builtins.replaceStrings` para os dois formatos de token. Importar em `home/cli/default.nix`.

- [ ] **Passo 3: Adicionar o input e o módulo**

Input `stylix` em `github:nix-community/stylix/release-26.05`, com `inputs.nixpkgs.follows = "nixpkgs"`. Em `workstation.nix`: `imports = [ inputs.stylix.nixosModules.stylix ]`, `stylix.enable = true`, `stylix.autoEnable = false`, `stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml"`, `stylix.homeManagerIntegration.followSystem = false`.

- [ ] **Passo 4: Criar `home/desktop/themes.nix`**

Define `stylix.enable = true`, `stylix.autoEnable = false`, o esquema padrão e `dionix.colors` lido de `config.lib.stylix.colors.withHashtag`. Lista: `catppuccin-mocha` → `catppuccin`, `gruvbox-dark-medium` → `gruvbox`, `nord` → `nord`, `tokyo-night-dark` → `tokyonight`. Para os 3 temas que não são o padrão, gerar `specialisation.<tema>.configuration` com `stylix.base16Scheme` em `lib.mkForce`, `dionix.theme` e `dionix.nvchadTheme`.

- [ ] **Passo 5: Verificar cores por tema e o servidor**

Run: `nix eval .#nixosConfigurations.desktop.config.home-manager.users.dio.specialisation.nord.configuration.dionix.colors.base00`
Expected: `"#2e3440"`

Run: `nix eval .#nixosConfigurations.desktop.config.home-manager.users.dio.dionix.colors.base00`
Expected: `"#1e1e2e"`

Run: `nix eval .#nixosConfigurations.server.config.home-manager.users.dio.dionix.colors.base00`
Expected: `"#1e1e2e"`

Run: `nix eval .#nixosConfigurations.server.options --apply 'o: o ? stylix'`
Expected: `false`

- [ ] **Passo 6: Validar e commitar**

Comparar `system.build.toplevel` do `server` com o do `main`: a única diferença aceitável é o caminho do source do flake. Commit: `feat(theme): adiciona Stylix e specialisations dos temas`.

### Tarefa 2: comando `theme` e reaplicação

**Files:**
- Create: `home/desktop/files/theme/theme.sh`, `home/desktop/files/theme/theme-test.sh`
- Modify: `home/desktop/themes.nix`, `home/desktop/settings/wlr-which-key.nix`, `home/cli/files/zsh/commands.md`, `flake.nix`

**Interfaces:**
- Consumes: `dionix.theme` e a lista de temas (Tarefa 1).
- Produces: `theme [nome]`; arquivos `$XDG_STATE_HOME/dionix/theme` e `$XDG_STATE_HOME/dionix/base-generation`; variável `DIONIX_THEME_SKIP_REAPPLY`.

A geração ativa pode ser uma specialisation, que não tem `specialisation/`. Por isso a base grava o próprio caminho em `base-generation` ao ativar, e o `theme` sempre parte desse arquivo.

- [ ] **Passo 1: Escrever o teste**

`theme-test.sh` usa uma geração falsa em diretório temporário, com `activate` que registra a chamada, e stubs de `swaymsg`, `systemctl` e `fuzzel` no `PATH`. Casos:

```text
theme nord               → roda base/specialisation/nord/activate; estado = nord; recarrega
theme catppuccin-mocha   → roda base/activate com DIONIX_THEME_SKIP_REAPPLY=1; estado = catppuccin-mocha
theme invalido           → sai com erro, cita os temas válidos; estado e ativação intactos
activate falha           → sai com erro; estado intacto
sem base-generation      → sai com erro pedindo um rebuild; estado intacto
swaymsg falha            → sai com sucesso; estado atualizado
fuzzel cancelado (vazio) → sai com sucesso; nada muda
```

- [ ] **Passo 2: Ligar o teste a `checks` e ver falhar**

`checks.x86_64-linux.theme-script` em `flake.nix`, um `runCommand` que roda o teste.
Run: `nix build .#checks.x86_64-linux.theme-script`
Expected: FAIL, `theme.sh` ainda não existe.

- [ ] **Passo 3: Implementar `theme.sh` e empacotar**

`pkgs.writeShellApplication` com a lista de temas injetada em `DIONIX_THEMES` e `DIONIX_DEFAULT_THEME`, seguindo a sequência da especificação. O recarregamento usa `swaymsg reload` e `systemctl --user restart` de `waybar`, `swaync` e `swayosd`, e nenhuma falha nessa fase muda o resultado. Adicionar a `home.packages` e a entrada `t` ("+tema") em `wlr-which-key.nix`.

- [ ] **Passo 4: Adicionar a reaplicação**

Em `themes.nix`, `home.activation.dionixReapplyTheme` com `lib.hm.dag.entryAfter [ "reloadSystemd" ]`, só quando `config.specialisation != { }`:

```text
grava $newGenPath em base-generation
se DIONIX_THEME_SKIP_REAPPLY está definida: termina
tema salvo vazio ou igual ao padrão: termina
tema salvo na lista: roda $newGenPath/specialisation/<tema>/activate
senão: aviso com warnEcho e fica o padrão
```

Testes de avaliação: o script aparece na base; `nix eval` de `...specialisation.nord.configuration.home.activation` não tem `dionixReapplyTheme`.

- [ ] **Passo 5: Verificar e commitar**

Run: `nix build .#checks.x86_64-linux.theme-script`
Expected: sucesso. Rodar também o build de `home-files`. Documentar `## theme` em `commands.md`. Commit: `feat(theme): adiciona o comando theme`.

### Tarefa 3: Sway, Waybar e Alacritty

**Files:**
- Modify: `home/desktop/sway.nix`, `home/desktop/files/sway/fx.conf`, `home/desktop/waybar.nix`, `home/desktop/files/waybar/style.css`, `home/desktop/settings/waybar.nix`, `home/desktop/apps.nix`, `home/desktop/themes.nix`
- Delete: `home/desktop/settings/alacritty-catppuccin-mocha.nix`

**Interfaces:**
- Consumes: `config.dionix.colors`, `config.dionix.render`.

- [ ] **Passo 1: Trocar as cores pelos tokens**

Aplicar o mapa. Em `sway.nix`, ler de `config.dionix.colors`; `fx.conf` e `style.css` passam por `config.dionix.render`. `rgba(30, 30, 46, 0.85)` vira `rgba(@base00-rgb@, 0.85)`, e sombras com alfa concatenam o sufixo ao token.

- [ ] **Passo 2: Ligar o Alacritty ao Stylix**

`stylix.targets.alacritty.enable = true` e remoção do merge da paleta em `apps.nix`. Manter as fontes e a opacidade atuais; se houver conflito, desligar `stylix.targets.alacritty.fonts` e `.opacity`.

- [ ] **Passo 3: Conferir os arquivos gerados**

Construir `home-files` da base e de `nord`.
Expected: Catppuccin na base; no `nord`, `#2e3440` em `.config/waybar/style.css`, em `.config/sway/config` e em `.config/alacritty/alacritty.toml`. Nenhum `@base` restante nos arquivos gerados: `rg '@base[0-9A-F]{2}' <out>/.config` não retorna nada. Commit: `feat(theme): aplica os temas ao Sway, Waybar e Alacritty`.

### Tarefa 4: ponto de decisão da prova

- [ ] **Passo 1: Medir o build**

Repetir as duas medições da Tarefa 1, Passo 1.

- [ ] **Passo 2: Pedir ao usuário o `rebuild` e o teste na tela**

Roteiro: `rebuild`; `time theme nord`; olhar Sway, Waybar e um Alacritty já aberto; `rebuild` de novo, confirmando que `nord` continua; `time theme catppuccin-mocha`; `theme invalido`; sair e confirmar `tuigreet` e XFCE iguais.

- [ ] **Passo 3: Apresentar os números**

Comparar com os critérios da especificação e **parar**. A Tarefa 5 só começa quando o usuário decidir seguir.

---

## Etapa 2: migração

### Tarefa 5: aplicativos de terminal

**Files:**
- Modify: `home/cli/settings/starship.nix`, `home/cli/settings/lsd-colors.nix`, `home/cli/shell.nix`, `home/cli/tools.nix`, `home/cli/editors.nix`, `home/cli/tmux.nix`, `home/cli/files/vimrc`, `home/desktop/themes.nix`, `home/desktop/apps.nix`, `home/desktop/settings/mpv.nix`, `home/desktop/settings/imv.nix`, `home/desktop/files/zathura/zathurarc`
- Delete: `home/desktop/settings/spotify-player.nix`

- [ ] **Passo 1: Trocar cores fixas por tokens**

`starship`, `lsd-colors`, `shell.nix` e `imv` leem `config.dionix.colors`. Os arquivos de `settings/` que hoje são attrsets puros passam a receber `colors` como argumento. O `vim` recebe as cores por `config.dionix.render` no `extraConfig`, se tiver cores fixas.

- [ ] **Passo 2: Ligar os módulos do Stylix**

Em `themes.nix`, ativar `btop`, `bat`, `tmux`, `yazi`, `helix`, `fzf`, `zathura`, `mpv` e `spotify-player`. Em `home/cli`, marcar com `lib.mkDefault` os valores que conflitarem (`btop.color_theme`, `bat.theme`, flavor do yazi), mantendo Catppuccin no `server`. Remover o tema fixo do `spotify_player`.

- [ ] **Passo 3: Verificar e commitar**

`nord` nos arquivos gerados de cada aplicativo, e o `server` ainda com Catppuccin no `starship` e no `btop`. Commit: `feat(theme): aplica os temas aos aplicativos de terminal`.

### Tarefa 6: restante do ambiente gráfico

**Files:**
- Modify: `home/desktop/menus.nix`, `home/desktop/sway.nix`, `home/desktop/theme.nix`, `home/desktop/settings/fuzzel.nix`, `home/desktop/settings/swaylock.nix`, `home/desktop/settings/wlr-which-key.nix`, `home/desktop/files/swaync/style.css`, `home/desktop/files/wlogout/style.css`, `home/desktop/files/swayosd/style.css`, `home/desktop/files/swaynag.conf`, `home/desktop/files/gtk/catppuccin.css`

- [ ] **Passo 1: Trocar as cores pelos tokens**

Aplicar o mapa e passar cada arquivo por `config.dionix.render`, incluindo os valores de `slurp` em `wlr-which-key.nix`, sem `#`. O `stylePath` do swayosd passa a apontar para `pkgs.writeText`, o que também acaba com o reinício desnecessário do swayosd a cada `rebuild`. Renomear o CSS do GTK para `theme.css`.

- [ ] **Passo 2: Verificar e commitar**

`nord` nos arquivos gerados e nenhum `@base` restante. Cursor, ícones e Kvantum não mudam. Commit: `feat(theme): aplica os temas ao restante do ambiente gráfico`.

### Tarefa 7: NvChad

**Files:**
- Modify: `home/cli/editors.nix`, `home/cli/files/nvim/lua/chadrc.lua`, `home/cli/files/nvim/init.lua`

- [ ] **Passo 1: Gerar o nome do tema**

`xdg.configFile."nvim/dionix-theme.lua".text = ''return "${config.dionix.nvchadTheme}"''`, fora de `lua/`, que é um diretório vindo do store. Em `chadrc.lua`, `M.base46.theme` lê esse arquivo com `dofile`.

- [ ] **Passo 2: Renovar o cache do base46**

Em `init.lua`, antes dos `dofile` do cache, comparar o tema com um carimbo em `vim.g.base46_cache .. "theme"`. Se for diferente, rodar `require("base46").load_all_highlights()` depois de carregar os plugins e atualizar o carimbo.

- [ ] **Passo 3: Verificar e commitar**

Com `XDG_CONFIG_HOME` temporário apontando para o `home-files` de `nord`:
`nvim --headless +'lua print(require("nvconfig").base46.theme)' +qa`
Expected: `nord`. Abrir de novo com a geração da base e conferir `catppuccin`, sem cache antigo. Commit: `feat(theme): aplica os temas ao NvChad`.

### Tarefa 8: fechamento

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Passo 1: Procurar cores restantes**

Run: `rg -i -l '1e1e2e|313244|45475a|6c7086|a6adc8|cdd6f4|f38ba8|fab387|f9e2af|a6e3a1|94e2d5|89b4fa|cba6f7|b4befe|11111b' home modules`
Expected: só `home/cli/colors.nix` e os arquivos de tema usados no `server` (`btop`).

- [ ] **Passo 2: Atualizar o `CLAUDE.md`**

Em Convenções: cores vêm de `home/desktop/themes.nix` e do Stylix, novos arquivos usam `config.dionix.colors` ou `config.dionix.render`, e a regra de cantos retos e bordas de 1px fica. Adicionar o build de `checks.x86_64-linux.theme-script` à Validação.

- [ ] **Passo 3: Validação final**

Build completo de `desktop` e `notebook`, `nix flake check` com build, e os 4 temas conferidos. Pedir ao usuário um `rebuild` e a troca entre os 4 temas na tela. Commit: `docs(theme): atualiza o CLAUDE.md para o seletor de temas`.
