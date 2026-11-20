# forge: sono e atualizações — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o forge desliga quando ninguém o usa, o Pi o liga por Wake-on-LAN sob demanda e para compilar as atualizações do nixpkgs (8h–22h), o forge abre um PR com o `flake.lock` novo, serve o resultado como cache, aplica a `main` em si mesmo, e a Waybar do notebook avisa e aplica.

**Architecture:** o `server-sleep`/`server-wake` vira um mecanismo por host (`host-sleep.nix` em cada máquina que dorme, `host-wake.nix` no Pi). Um serviço novo no Pi (`update-watch`) guarda o estado das atualizações e acorda o forge; o `forge-update` no forge compila, abre o PR e aplica a `main`; o harmonia serve o store do forge; um script novo da Waybar lê o estado no Pi.

**Tech Stack:** NixOS 26.05 (módulos, systemd, networkd), Nginx, Python 3 (stdlib), bash, `gh`, `nvd`, harmonia.

**Spec:** `docs/superpowers/specs/2026-11-20-forge-sono-design.md`

## Global Constraints

- Comentários em português; `nix fmt` antes de cada commit; Conventional Commits; commits com `git -c user.name="Lucas Santos" -c user.email="fdscomvc69@gmail.com" commit` e a linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Sem segredos no repositório: token do GitHub em `/var/lib/secrets/github-token` (forge, à mão); chave do cache gerada no primeiro boot em `/var/lib/secrets/` do forge; só a chave **pública** entra no repositório.
- Não alterar IPs (`10.42.1.2/.3/.22`) nem o `serverMac`. MAC do forge: `00:e0:4b:01:57:96`.
- O server tem que se comportar como hoje: 45 min, porta 9090 ignorada, mesmos `blockers` e `wakeTimers`, suspensão (S3).
- O forge **desliga** (S5), após **20 min** sem uso, porta **9100** ignorada.
- Builds automáticos só entre **8h e 22h** (hora local, `America/Sao_Paulo`). Checagem do canal no Pi às **10:00**. Gatilho: só o canal `nixos-26.05` (`https://channels.nixos.org/nixos-26.05/git-revision`).
- Um PR por vez, branch `atualizacao/flake-lock`, título e commit `chore(flake): atualiza o flake.lock`, autor `forge`. Repositório `yocaslu/dionix`, só squash merge.
- Nada de `nixos-rebuild switch` nas máquinas durante a implementação; a aplicação é do usuário.
- Validação final: `nix flake check`, build do `home-files` do notebook e o `toplevel` de `forge`, `server`, `pi` (avaliação basta para o Pi).

## Review Focus

1. **Rebuild do notebook com o forge desligado** — `cache.<domínio>` precisa responder 404 na hora (sem acordar e sem retries); o rebuild segue pelo cache oficial sem esperar. Teste: Task 5, passo de verificação com o forge desligado.
2. **Canal anda fora do horário / forge acordado à mão de noite** — nada compila fora de 8h–22h; o pendente espera. Teste: `test_fora_da_janela_nao_compila` (Task 4) e `test_conferir_pendente_acorda_de_novo` (Task 3).
3. **Build que falha** — vira "falhou", não abre PR, não é retentado a cada 15 min nem no dia seguinte para a mesma revisão. Teste: `test_falha_nao_repete` (Task 3) e `test_falha_avisa_e_nao_abre_pr` (Task 4).
4. **PR fechado à mão ou `main` atualizada com `syu`** — o widget esconde e o Pi não pede build. Teste: `test_pr_fechado_volta_a_nada` e `test_main_ja_no_canal_nao_pendente` (Task 3); `main andou` no teste do widget (Task 6).
5. **Server inalterado** — a generalização não muda a lógica do server. Teste: os testes atuais do `server-wake` continuam passando, adaptados ao host `server` (Task 1), e o `diff` dos serviços do server (Task 2).

---

### Task 0: Conferir o Wake-on-LAN do forge a partir do S5 (manual, usuário)

Portão do projeto: se falhar, parar e voltar ao usuário.

- [ ] **Step 1:** no forge, `sudo ethtool enp2s0 | grep -i wake` → "Supports Wake-on" contém `g`.
- [ ] **Step 2:** `sudo ethtool -s enp2s0 wol g && sudo poweroff`; do notebook, `nix shell nixpkgs#wakeonlan -c wakeonlan 00:e0:4b:01:57:96` (na rede de casa) → o forge liga e responde `ping 10.42.1.3` em até 2 min.

### Task 1: `host-wake` — o Pi acorda vários hosts

**Files:**
- Rename: `modules/nixos/server-wake.nix` → `modules/nixos/host-wake.nix`
- Rename: `modules/nixos/files/server-wake.py` → `modules/nixos/files/host-wake.py`
- Rename: `modules/nixos/files/server-wake-test.py` → `modules/nixos/files/host-wake-test.py`
- Modify: `modules/nixos/homelab.nix` (opção `forgeMac`, padrão `"00:e0:4b:01:57:96"`)
- Modify: `hosts/pi/default.nix` (import), `flake.nix` (check `server-wake` → `host-wake`)

**Interfaces:**
- Produces (Python, `host-wake.py`), ambiente: `HOSTS` (JSON `{"server": {"ip": "...", "mac": "..."}, "forge": {...}}`), `BROADCAST`, `LOG_DIR` (uso em `$LOG_DIR/uso-<host>.log`), `PORT`, `STATE_DIRECTORY` (`dormindo` em `$STATE_DIRECTORY/<host>/dormindo`). Funções `acordar(host)`, `apagar_dormindo(host)`, `host_acordado(host)` (SSH :22), classe `Pedido` com `tratar()` e `responder(status, corpo, ...)` como hoje.
- Produces (HTTP, porta 8090):
  - pedidos do Nginx com `X-Dionix-Uso` e `X-Dionix-Host: <host>` → mesma lógica de hoje (`espera`), por host;
  - `GET /sono/<host>/uso`, `POST /sono/<host>/dormindo`, `POST /sono/<host>/acordado`;
  - `/acordar` (= server, compatível) e `/acordar/<host>`, ambos só com `X-Dionix-Uso: 1`;
  - host desconhecido → 404.
- Produces (Nix, `host-wake.nix`): opção `dionix.wake.hosts` (attrset `nome → { ip, mac }`; o Pi define `server` e `forge` a partir do `homelab.nix`) e `dionix.wake.ignore` (nomes de `dionix.proxy.hosts` que não acordam; Task 5 usa `[ "cache" ]`). Cada vhost cujo upstream começa com `http://<ip>:` de um host ganha o `error_page 502 504 = @acordar` com `X-Dionix-Host`. `map` do Nginx renomeado para `$dionix_uso`. No `pi.<domínio>`, `location /sono/<host>/` com `allow <ip do host>; deny all;`. No `home.<domínio>`, `= /acordar` e `= /acordar/<host>`.

- [ ] **Step 1: Adaptar o teste** — `host-wake-test.py` com `HOSTS` de dois hosts e os testes atuais reescritos por host (`/sono/server/acordado` → 200; espera com `X-Dionix-Host: server` e host acordado → 502). Novos:
  - `test_host_desconhecido_404`: `GET /sono/nada/uso` → 404.
  - `test_dormindo_por_host`: `POST /sono/forge/dormindo` cria `$STATE/forge/dormindo` e não cria `$STATE/server/dormindo`.
  - `test_acordar_forge_usa_mac_do_forge`: com `socket` trocado por um falso, `/acordar/forge` (uso 1) envia `b"\xff"*6 + mac_forge*16`.
  - `test_acordar_sem_host_e_server`: `/acordar` envia o MAC do server.
- [ ] **Step 2:** `nix build .#checks.x86_64-linux.host-wake` (após trocar o check no `flake.nix`) → FAIL.
- [ ] **Step 3: Implementar** `host-wake.py` (um `ultimo_pacote` por host) e `host-wake.nix` com as interfaces acima.
- [ ] **Step 4:** `nix build .#checks.x86_64-linux.host-wake` → PASS; `nix eval .#nixosConfigurations.pi.config.services.nginx.virtualHosts --apply 'v: builtins.attrNames v'` lista os vhosts de hoje; `nix flake check` → passa.
- [ ] **Step 5: Commit** `refactor(wake): o Pi acorda vários hosts por Wake-on-LAN`.

### Task 2: `host-sleep` — dormir por host, com desligar para o forge

**Files:**
- Rename: `modules/nixos/server-sleep.nix` → `modules/nixos/host-sleep.nix`
- Modify: `hosts/server/default.nix` (`dionix.serverSleep` → `dionix.sleep`, valores explícitos, incluindo `ignoredPorts = [ 9090 ]`)
- Modify: `modules/nixos/forge.nix` (import, `dionix.sleep`, `.link` de Wake-on-LAN igual ao de `hosts/server/base.nix`)

**Interfaces:**
- Consumes: `/sono/<host>/…` da Task 1.
- Produces: opção `dionix.sleep` = `{ enable; mode ∈ [ "suspend" "poweroff" ] (padrão "suspend"); idleMinutes (padrão 45); ignoredPorts (padrão []); blockers; wakeTimers; }`. Serviços `host-sleep`, `host-sleep-volta`, timer `host-sleep`, diretório `/run/host-sleep`. O script fala com `https://pi.<domínio>/sono/${hostname}/…`; com `mode = "poweroff"`, chama `systemctl poweroff` e `wakeTimers` gera erro de asserção se não vazio. Bloqueio novo para os dois hosts: build do nix-daemon em andamento (como detectar fica com o implementador; o critério é "há derivação sendo construída").
- Forge: `idleMinutes = 20`, `ignoredPorts = [ 9100 ]`, `mode = "poweroff"`, `blockers = [ "forge-update.service" "nixos-rebuild-switch-to-configuration.service" ]` (o `forge-update` vem da Task 4; o nome entra já).

- [ ] **Step 1:** registrar a referência do server antes de mexer: `nix eval --json .#nixosConfigurations.server.config.systemd.services.server-sleep.serviceConfig.ExecStart > "$SCRATCH/server-sleep-antes.json"` (`$SCRATCH` = o scratchpad da sessão) e o script gerado (`cat` do ExecStart).
- [ ] **Step 2: Implementar** `host-sleep.nix` e migrar server e forge.
- [ ] **Step 3: Verificar o server** — `diff` do script novo do server com o antigo: só mudam o caminho `/sono/server/…`, o nome do diretório em `/run` e o bloqueio de build. Timers `postgresqlBackup-nextcloud`, `restic-backups-gdrive`, `zfs-scrub` continuam com `WakeSystem=true` (`nix eval`).
- [ ] **Step 4: Verificar o forge** — `nix eval .#nixosConfigurations.forge.config.systemd.network.links` tem `WakeOnLan = "magic"`; o script do forge contém `systemctl poweroff`, `20 * 60` e não contém `suspend`; `nix flake check` passa.
- [ ] **Step 5: Commit** `feat(forge): desliga quando ninguém usa e liga por Wake-on-LAN`.

### Task 3: `update-watch` no Pi — estado das atualizações

**Files:**
- Create: `modules/nixos/update-watch.nix`, `modules/nixos/files/update-watch.py`, `modules/nixos/files/update-watch-test.py`
- Modify: `hosts/pi/default.nix` (import), `flake.nix` (check `update-watch`)

**Interfaces:**
- Consumes: `POST http://127.0.0.1:8090/acordar/forge` com `X-Dionix-Uso: 1` (Task 1).
- Produces (HTTP, porta 8092, estado em `$STATE_DIRECTORY/estado.json`):
  - `{"estado": "nada"|"pendente"|"compilando"|"pronto"|"falhou", "rev": str|null, "tentada": str|null, "pr": int|null, "url": str|null, "resumo": str, "conferido": int}`;
  - `GET /forge/estado` → JSON acima sem `tentada`/`conferido` (leitura livre, para o widget);
  - `GET /forge/pendente` → 200 com a `rev` se estado é `pendente`, senão 204;
  - `POST /forge/compilando` (corpo: rev) → `compilando`, `tentada = rev`;
  - `POST /forge/pronto` (JSON `{rev, pr, url, resumo}`) → `pronto`;
  - `POST /forge/falhou` (corpo: rev) → `falhou`;
  - `POST /forge/tentar` → `pendente` (com a `rev` atual do canal) e acorda o forge.
- Produces (CLI): `update-watch --conferir` (timer `update-watch`, `OnCalendar = "*-*-* 10:00:00"`, `Persistent = false`). Funções testáveis: `revisao_canal() -> str`, `revisao_main() -> str` (nixpkgs do `flake.lock` da `main` via `raw.githubusercontent.com`), `pr_aberto(n) -> bool` (API pública do GitHub, cache de 10 min), `conferir()`.
- Regra de `conferir()`: se estado é `pendente`, acorda de novo. Senão, há pendente quando `canal ≠ main`, `canal ≠ rev do PR aberto` e `canal ≠ tentada`; grava `pendente` e acorda.
- Nginx (`pi.<domínio>`): `/forge/` → 8092; `pendente`, `compilando`, `pronto`, `falhou` só de `forge` (`allow 10.42.1.3; deny all;`); `estado` e `tentar` livres.

- [ ] **Step 1: Testes** (`update-watch-test.py`, unittest, funções de rede trocadas por falsas):
  - `test_canal_novo_fica_pendente_e_acorda`: canal `B`, main `A` → `pendente`, rev `B`, `acordar` chamado uma vez.
  - `test_main_ja_no_canal_nao_pendente`: canal `B`, main `B` → `nada`, sem acordar.
  - `test_falha_nao_repete`: estado `falhou`, `tentada = B`, canal `B` → continua `falhou`, sem acordar.
  - `test_conferir_pendente_acorda_de_novo`: estado `pendente` → acorda de novo.
  - `test_pr_fechado_volta_a_nada`: estado `pronto`, `pr_aberto` → False → `GET /forge/estado` devolve `nada`.
  - `test_pronto_guarda_pr`: `POST /forge/pronto` com `{rev: "B", pr: 30, url: "u", resumo: "r"}` → `GET /forge/estado` = `{"estado": "pronto", "rev": "B", "pr": 30, "url": "u", "resumo": "r"}`.
  - `test_tentar_regrava_pendente`: estado `falhou` → `POST /forge/tentar` → `pendente`, acorda.
- [ ] **Step 2:** `nix build .#checks.x86_64-linux.update-watch` → FAIL.
- [ ] **Step 3: Implementar** `update-watch.py` e `update-watch.nix` (serviço com `DynamicUser`, `StateDirectory = "update-watch"`, timer, locations do Nginx).
- [ ] **Step 4:** check → PASS; `nix flake check` → passa.
- [ ] **Step 5: Commit** `feat(pi): acompanha as atualizações do nixpkgs e acorda o forge`.

### Task 4: `forge-update` no forge — compila, abre o PR e aplica a `main`

**Files:**
- Create: `modules/nixos/forge-update.nix`, `modules/nixos/files/forge-update.sh`, `modules/nixos/files/forge-update-test.sh`
- Modify: `modules/nixos/forge.nix` (import), `flake.nix` (check `forge-update`)

**Interfaces:**
- Consumes: `/forge/pendente|compilando|pronto|falhou` (Task 3).
- Produces: `forge-update.service` (oneshot, `wantedBy = [ "multi-user.target" ]`, `after = [ "network-online.target" ]`) e timer a cada 15 min. Ambiente: `PI_URL` (`https://pi.<domínio>`), `REPO` (`https://github.com/yocaslu/dionix.git`), `TOKEN_FILE` (`/var/lib/secrets/github-token`), `WORKDIR` (`/var/lib/forge-update`), `HOSTS` (`notebook forge server pi`), `JANELA` (`8-22`). Raízes de GC em `/nix/var/nix/gcroots/forge-update/<host>`.
- Funções do script (testadas): `na_janela HORA` (0 se `8 ≤ HORA < 22`), `aplicar_main`, `compilar REV`, `main`.
- `aplicar_main`: `git fetch` da `main`, compila o `toplevel` do forge (fora da janela com `--max-jobs 0`, só baixando; se não der, não faz nada) e, se difere de `readlink /nix/var/nix/profiles/system`, `nixos-rebuild boot --flake $WORKDIR#forge`.
- `compilar REV`: avisa `compilando`; branch `atualizacao/flake-lock` a partir de `origin/main`; `nix flake update`; `nix build` do `toplevel` de cada host de `HOSTS`; `nix flake check`; `nvd diff` (toplevel da `main` → novo) por host no corpo; commit (autor `forge <forge@vault76.com.br>`); `git push --force`; `gh pr create` ou `gh pr edit --body-file` se já houver PR da branch; troca as raízes de GC; avisa `pronto` com `{rev, pr, url, resumo}`, onde `resumo` é o `nvd` do notebook. Qualquer falha → `falhou` com a rev, sem push.
- `main`: `aplicar_main`; se `na_janela` da hora atual e o Pi devolve rev pendente, `compilar REV`.

- [ ] **Step 1: Testes** (`forge-update-test.sh`, no estilo de `theme-test.sh`; `curl`, `git`, `nix`, `gh`, `nvd`, `nixos-rebuild`, `date` como funções/stubs no PATH que registram as chamadas):
  - `test_fora_da_janela_nao_compila`: hora 23, Pi pendente → nenhuma chamada a `nix flake update` nem a `/forge/compilando`.
  - `test_na_janela_compila_e_abre_pr`: hora 10, pendente `B` → chamadas em ordem: `compilando B`, `flake update`, builds dos 4 hosts, `flake check`, `push --force`, `pr create`, `pronto` com `"rev": "B"`.
  - `test_pr_existente_e_editado`: `gh pr list` devolve o PR 30 → `gh pr edit 30`, sem `pr create`; `pronto` com `"pr": 30`.
  - `test_falha_avisa_e_nao_abre_pr`: build do `pi` falha → `falhou B`, sem `push`, sem `pr`.
  - `test_aplica_main_quando_difere`: toplevel da main ≠ perfil → `nixos-rebuild boot`; igual → não chama.
- [ ] **Step 2:** `nix build .#checks.x86_64-linux.forge-update` → FAIL.
- [ ] **Step 3: Implementar** o script e o módulo (dependências no PATH: git, gh, nvd, jq, curl, nix, nixos-rebuild, coreutils; `GH_TOKEN` lido do `TOKEN_FILE`).
- [ ] **Step 4:** check → PASS; `nix build .#nixosConfigurations.forge.config.system.build.toplevel` → OK; `nix flake check` → passa.
- [ ] **Step 5: Commit** `feat(forge): compila as atualizações, abre o PR e aplica a main`.

### Task 5: cache do forge (harmonia) e substituter no notebook

**Files:**
- Create: `modules/nixos/forge-cache.nix`
- Modify: `modules/nixos/forge.nix` (import), `modules/nixos/homelab.nix` (opção `cachePublicKey`, `nullOr str`, padrão `null`), `hosts/pi/default.nix` (`cache = "http://${forge}:5000"` em `dionix.proxy.hosts`; `dionix.wake.ignore = [ "cache" ]`), `modules/nixos/workstation.nix` (substituter)

**Interfaces:**
- Produces: harmonia na porta 5000 (firewall aberto só para o Pi, `10.42.1.2`), chave em `/var/lib/secrets/cache-key` gerada por um oneshot `forge-cache-chave` antes do harmonia (`nix-store --generate-binary-cache-key forge-1 …`, pública em `/var/lib/secrets/cache-key.pub`).
- Vhost `cache.<domínio>`: `proxy_connect_timeout 2s;` e `error_page 502 504 =404 /404;` (forge desligado = "não tenho", sem acordar e sem retries do Nix).
- Notebook: com `cachePublicKey != null`, `nix.settings.extra-substituters = [ "https://cache.<domínio>" ]` e `extra-trusted-public-keys = [ cachePublicKey ]`. Sem chave, nada muda (primeira aplicação).

- [ ] **Step 1: Implementar** os módulos.
- [ ] **Step 2: Verificar** — `nix eval .#nixosConfigurations.notebook.config.nix.settings.substituters` sem o forge (chave nula); com uma chave de teste temporária no `homelab.nix`, contém `https://cache.vault76.com.br` (desfazer depois). `nix flake check` passa.
- [ ] **Step 3: Verificação depois da aplicação (registrar no `docs/homelab.md`)** — com o forge desligado, `curl -s -o /dev/null -w '%{http_code} %{time_total}' https://cache.vault76.com.br/nix-cache-info` → `404` em menos de 3 s, e o forge continua desligado.
- [ ] **Step 4: Commit** `feat(forge): serve o store como cache binário para o notebook`.

### Task 6: widget da Waybar

**Files:**
- Delete: `home/desktop/files/waybar/scripts/updates.sh`
- Create: `home/desktop/files/waybar/scripts/forge-update.sh`, `home/desktop/files/waybar/scripts/forge-update-test.sh`
- Modify: `home/desktop/waybar.nix` (`updatesScript` → `forgeUpdateScript`, deps `curl jq gh git coreutils procps`), `home/desktop/settings/waybar.nix` (`custom/updates`: mesmo `format`, `interval = 1800`, `signal = 8`), `flake.nix` (check `forge-widget`)

**Interfaces:**
- Consumes: `GET https://pi.<domínio>/forge/estado`, `POST /forge/tentar`, `/acordar/forge` (Tasks 1 e 3), `https://cache.<domínio>/nix-cache-info`.
- Produces: `forge-update.sh` sem argumento → JSON da Waybar:
  - `nada` ou Pi fora → `{"text": "", "class": "none"}`;
  - `pendente`/`compilando` → `{"text": "…", "class": "building"}`;
  - `pronto` → `{"text": "#30", "tooltip": "<resumo>\nclique para aplicar", "class": "pending"}`;
  - `falhou` → `{"text": "!", "tooltip": "o build falhou: journalctl -u forge-update no forge\nclique para tentar de novo", "class": "failed"}`.
- `forge-update.sh --aplicar`:
  - `falhou` → `POST /forge/tentar`.
  - `pronto` → mostra o resumo e pergunta `[s/N]`. Com `s`:
    1. `gh pr view N --json mergeStateStatus,baseRefOid`.
    2. Se a `main` andou (`mergeStateStatus` ≠ `CLEAN`), faz `POST /forge/tentar` e avisa.
    3. Se não, acorda o forge e espera `nix-cache-info` responder 200 (até 3 min).
    4. Roda `gh pr merge N --squash --delete-branch`, `git -C $flake pull --ff-only` e `nh os switch`.
  - Ao final, sempre `pkill -RTMIN+8 waybar`.

- [ ] **Step 1: Testes** (`forge-update-test.sh`, com `curl` e `gh` como stubs):
  - estados `nada`, `compilando`, `pronto` (pr 30), `falhou` → JSONs acima;
  - Pi fora (curl falha) → classe `none`;
  - `--aplicar` com `mergeStateStatus = BEHIND` → chama `/forge/tentar` e não chama `gh pr merge` (main andou).
- [ ] **Step 2:** `nix build .#checks.x86_64-linux.forge-widget` → FAIL.
- [ ] **Step 3: Implementar** o script e ligar na Waybar (CSS: `building`/`failed` com as cores do tema via `@base…@` se o `style.css` tiver classes de `custom-updates`).
- [ ] **Step 4:** check → PASS; `nix build .#nixosConfigurations.notebook.config.home-manager.users.dio.home-files` → OK (shellcheck).
- [ ] **Step 5: Commit** `feat(waybar): avisa e aplica as atualizações compiladas pelo forge`.

### Task 7: documentação e validação final

**Files:**
- Modify: `docs/homelab.md` (seção do forge: desliga, Wake-on-LAN, ciclo de atualização, cache, token e chave à mão, `journalctl -u host-sleep`/`forge-update`; o que era `server-sleep`/`server-wake`), `README.md` (papéis novos), `CLAUDE.md` (forge "sempre ligado" → dorme; `host-sleep`/`host-wake`), `docs/superpowers/specs/2026-11-09-forge-design.md` (nota: sub-projetos renumerados, forge dorme), `hosts/forge/default.nix` e `hosts/server/default.nix` (comentários).

- [ ] **Step 1:** atualizar os textos.
- [ ] **Step 2:** `nix fmt`; `nix flake check`; `nix build .#nixosConfigurations.notebook.config.home-manager.users.dio.home-files`; `nix build .#nixosConfigurations.forge.config.system.build.toplevel`; `nix build .#nixosConfigurations.server.config.system.build.toplevel` → todos OK; `grep -rn "server-sleep\|server-wake\|serverSleep" --exclude-dir=superpowers .` → nada.
- [ ] **Step 3: Commit** `docs(forge): sono, Wake-on-LAN e atualizações do forge`.

### Aplicação (usuário, depois do merge)

1. Forge: criar `/var/lib/secrets/github-token`; `nixos-rebuild boot --flake .#forge --target-host dio@10.42.1.3 --sudo --ask-sudo-password` + reboot.
2. Copiar `/var/lib/secrets/cache-key.pub` do forge para `cachePublicKey` no `homelab.nix` (commit pequeno).
3. Pi e server: `nixos-rebuild switch --target-host`. Notebook: `sudo nixos-rebuild switch --flake .#notebook`.
4. Conferir: `journalctl -u host-sleep` no forge e no server; `curl https://pi.vault76.com.br/forge/estado`; passo 3 da Task 5.
