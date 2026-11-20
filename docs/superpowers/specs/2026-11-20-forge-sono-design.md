# forge: dorme quando ninguém usa e compila as atualizações sozinho

Data: 2026-11-20

Sub-projeto 2 do forge (decisões de 16/11 a 20/11/2026). Os sub-projetos
seguintes (sops-nix; Forgejo e Vaultwarden; CI, cache e deploy; ambiente de
desenvolvimento) descem uma posição e passam a contar com este mecanismo.

## Por quê

O forge (i5-3470, 12 GB, SSD de 240 GB, `10.42.1.3`) gasta energia e faz
barulho ligado 24/7: a ventoinha não é silenciosa. Ele deve dormir como o
server e só acordar quando alguém o usa ou quando há atualização para compilar.

A spec do sub-projeto 1 (`2026-11-09-forge-design.md`) tratava o forge como
"sempre ligado" e deixava a suspensão fora. Esta spec muda isso: os serviços
planejados (Forgejo, Vaultwarden, CI, cache) acordam o forge sob demanda.

## Objetivos

1. **Dormir rápido.** O forge suspende (S3) após 20 min sem uso, com as mesmas
   regras de "parado" do server (sem acesso real pelo proxy do Pi, sem conexões
   abertas nos serviços, sem build ou unidade bloqueadora rodando).
2. **Acordar sob demanda.** Acesso pelo proxy do Pi a um serviço do forge
   acorda a máquina por Wake-on-LAN, como já acontece com o server.
3. **Atualização compilada e proposta.** Quando o canal `nixos-26.05` anda, o
   Pi acorda o forge (só entre 8h e 22h); o forge atualiza o `flake.lock`,
   compila os hosts e abre (ou atualiza) um PR no GitHub com o que mudou.
4. **Aviso no notebook.** Um widget na Waybar, alimentado pelo Pi, mostra que
   há atualização pronta; o clique leva ao merge e ao rebuild usando o que o
   forge já compilou.
5. **Um mecanismo só.** O dormir/acordar do server vira genérico, por host; o
   forge é o segundo usuário, não uma cópia.

## Não objetivos

- Forgejo, Vaultwarden, CI e deploy automático: sub-projetos seguintes. Este
  só garante que um serviço do forge publicado no proxy acorde a máquina.
- Git por SSH acordando o forge (não passa pelo Nginx): fica para o
  sub-projeto do Forgejo.
- Aplicar a atualização no server e no Pi: continuam manuais (o forge aplica
  em si mesmo, seção 5) (o PR só garante
  que compilam e deixa o resultado no cache).
- Attic: o cache deste sub-projeto é o store do próprio forge (abaixo); a
  escolha do Attic para o CI continua no sub-projeto de CI.

## Antiobjetivos (falhou mesmo se funcionar)

- O forge ligar a ventoinha sozinho fora das 8h–22h, ou acordar todo dia sem
  ter o que compilar.
- Um rebuild comum do notebook (`rebuild`, `syu`) acordar o forge ou ficar
  esperando por ele.
- Algo entrar na `main` sem o usuário ver: o forge só abre PR.
- Um PR com build quebrado: o PR só existe se os hosts compilaram.
- Mudar o comportamento do server (45 min, timers que o acordam, bloqueadores).

## Restrições

- Sem segredos no repositório: token do GitHub e chave do cache ficam em
  `/var/lib/secrets` do forge (criados à mão ou no primeiro boot). A chave
  **pública** do cache vai no repositório.
- O repositório `yocaslu/dionix` é público e só aceita squash merge.
- O Wake-on-LAN e o S3 do forge ainda não foram conferidos: a BIOS e a placa
  `enp2s0` precisam suportar. É o primeiro passo do plano; sem isso o
  sub-projeto não segue.
- Não alterar IPs nem o MAC do server.

## Abordagens

| | Quem percebe a atualização e acorda o forge | Troca |
|---|---|---|
| **A (escolhida)** | O Pi confere o canal às 10h; se andou, marca "build pendente" e manda o Wake-on-LAN. O forge, a cada vez que acorda, pergunta ao Pi se há build pendente. | Forge só acorda quando há o que compilar; reaproveita o Wake-on-LAN e o `/sono` do Pi; sem SSH do Pi para o forge. Sem o Pi não há atualização (mas sem ele também não há DNS nem proxy). |
| B | O próprio forge acorda pelo RTC (`WakeSystem`) às 10h e confere. | Independente do Pi, mas liga a ventoinha todo dia mesmo sem novidade. |
| C | GitHub Actions confere e chama o Pi pela internet. | Expõe um endpoint do Pi para fora e espalha a lógica, sem ganho sobre A. |

## Desenho

### 1. Dormir e acordar por host

- `server-sleep.nix` vira `host-sleep.nix` (opção `dionix.sleep`, mesmas
  subopções de hoje: `idleMinutes`, `ignoredPorts`, `blockers`, `wakeTimers`).
  O server passa a usar `dionix.sleep` com os valores atuais (45 min, porta
  9090 ignorada, mesmos bloqueadores e timers): comportamento idêntico.
- O forge usa `dionix.sleep` com `idleMinutes = 20`, `ignoredPorts = [ 9100 ]`
  (o Prometheus do server raspa o node exporter) e `blockers` com o serviço de
  atualização (seção 2) e o `nixos-rebuild-switch-to-configuration.service`.
  Um build do nix-daemon em andamento também bloqueia (vale para os dois hosts).
- O script de checagem deixa de citar "server" e fala com o Pi em
  `/sono/<host>/…` (uso, dormindo, acordado).
- No Pi, `server-wake.nix` vira `host-wake.nix`: um processo atende vários
  hosts. Cada host tem nome, IP e MAC (`dionix.homelab.forgeMac` nova, ao lado
  de `serverMac`). O log de uso passa a ser por host
  (`uso-<host>.log`), e cada vhost do proxy cujo upstream é o IP de um host
  com sono ganha o tratamento de hoje (502/504 → página "Aguarde"). O
  `server-wake.py` e o teste dele são generalizados; o comportamento para o
  server não muda.
- Acordar à mão: `home.<domínio>/acordar` continua acordando o server;
  `/acordar/forge` acorda o forge.
- Status (Gatus) e página inicial mostram "dormindo" para o forge como já
  mostram para o server.

### 2. Ciclo de atualização

**No Pi (`forge-update` no papel do Pi):**

- Timer às 10h: lê `https://channels.nixos.org/nixos-26.05/git-revision`
  (o canal só anda depois que o Hydra compilou, então o cache oficial já tem
  os pacotes). Há build pendente quando essa revisão é diferente, ao mesmo
  tempo, do nixpkgs do `flake.lock` da `main` (lido do GitHub; cobre o `syu`
  feito à mão), da revisão do PR aberto e da última revisão **tentada** (com
  sucesso ou falha). Se houver, grava "pendente" e manda o Wake-on-LAN.
- Falha não se repete sozinha: uma revisão que falhou só é tentada de novo
  quando o canal anda outra vez ou quando o usuário pede (clique no widget em
  "falhou", que regrava "pendente" e acorda o forge). Assim o forge não fica
  recompilando a cada 15 min nem acorda todo dia pela mesma falha.
- Endpoints (só o forge escreve; restrição por IP como no `/sono` de hoje):
  `GET /forge/pendente`, `POST /forge/compilando`, `POST /forge/pronto`
  (número do PR e revisão), `POST /forge/falhou`.
- Endpoint de leitura para o widget: `GET /forge/estado` (JSON com estado,
  PR, URL e resumo). Enquanto houver PR, o Pi confere na API pública do
  GitHub se ele ainda está aberto (cache de 10 min, sem token); fechado ou
  mesclado, o estado volta a "nada".

**No forge (`forge-update.service`):**

- Disparado ao acordar, no boot e por um timer a cada 15 min enquanto estiver
  acordado. Só roda entre 8h e 22h; fora disso não faz nada (o pendente
  espera o dia seguinte).
- Se o Pi diz "pendente":
  1. Avisa "compilando".
  2. Atualiza um clone próprio do repositório (`/var/lib/forge-update`), parte
     da `origin/main` na branch `atualizacao/flake-lock`, roda
     `nix flake update`.
  3. Compila o `toplevel` de `notebook`, `forge`, `server` e `pi` (o Pi pela
     emulação ARM; quase tudo vem do cache oficial) e roda o `nix flake check`.
  4. Gera o resumo do que mudou por host com `nvd diff` entre o `toplevel` da
     `main` e o novo.
  5. Commit (autor `forge`, mensagem `chore(flake): atualiza o flake.lock`),
     push forçado da branch e abre o PR, ou atualiza o corpo do PR já aberto.
     O corpo traz o resumo do `nvd` por host.
  6. Registra raízes de GC para os `toplevel` novos (o `min-free` do forge
     não pode apagar o que o notebook vai baixar) e solta as do PR anterior.
  7. Avisa o Pi: "pronto" com o número do PR. Em qualquer falha: "falhou"
     (o motivo fica no `journalctl -u forge-update`) e nenhum PR é aberto ou
     atualizado.
- O GitHub é acessado com um token fine-grained (conteúdo e PRs só no
  `yocaslu/dionix`) em `/var/lib/secrets/github-token`, criado à mão.

### 3. O forge como cache

- O forge serve o próprio `/nix/store` como cache binário com o **harmonia**,
  assinando com uma chave gerada no primeiro boot em `/var/lib/secrets`. A
  chave pública vai no repositório (opção em `homelab.nix`).
- Publicado no proxy do Pi como `cache.<domínio>`. Esse vhost **não** acorda o
  forge: acesso com o forge dormindo responde erro na hora, o Nix desiste dele
  e segue com o cache oficial. Assim um rebuild comum não acorda nem espera o
  forge (antiobjetivo).
- O notebook passa a ter `cache.<domínio>` como substituter extra, com a chave
  pública como confiável.

### 4. Widget na Waybar

- O widget `upd` atual (compara o `flake.lock` com o canal) é substituído: ele
  avisava antes de o forge compilar e confundiria com o novo.
- Estados, lidos de `https://pi.<domínio>/forge/estado` a cada 30 min e pelo
  sinal 8 da Waybar:
  - nada: escondido;
  - compilando: `upd …`;
  - pronto: `upd #N` (tooltip com o resumo do `nvd` do notebook);
  - falhou: `upd !` (tooltip pede para ver o `journalctl` no forge).
- Clique com PR pronto: abre o Alacritty com o resumo e pergunta se aplica.
  Antes do merge, confere no GitHub se a branch do PR está em dia com a `main`.
  Se a `main` andou (o PR deixaria de ser exatamente o que o forge compilou),
  não faz o merge: regrava "pendente", acorda o forge para refazer o build em
  cima da `main` atual e avisa. Se a `main` já tem o nixpkgs do canal (o
  usuário atualizou à mão), fecha o PR e o estado volta a "nada". Se está em dia: acorda o forge (`/acordar/forge`), espera o `cache.<domínio>`
  responder, faz `gh pr merge --squash --delete-branch`, `git pull` no flake
  local e `nh os switch`; por fim manda o sinal 8 para a Waybar.
- O alias `syu` continua existindo para atualizar à mão, sem o forge.

### 5. O forge aplica a `main` em si mesmo

- A cada execução do `forge-update` (ao acordar, no boot e a cada 15 min),
  entre 8h e 22h: se o `toplevel` do forge na `origin/main` difere do sistema
  configurado para o próximo boot, roda `nixos-rebuild boot` com ele (quase
  sempre já está no store, compilado pelo ciclo da seção 2).
- O reboot não acontece na hora: quando a regra de sono decidiria suspender
  (ninguém usando) e há sistema novo esperando, dentro das 8h–22h, o forge
  **reinicia em vez de suspender**. Volta, cumpre a carência de 15 min e dorme
  pelas regras normais. Ninguém é derrubado no meio do uso.
- Fora do horário, o sistema novo espera; o forge suspende normalmente.
- O `forge-update` também bloqueia o sono enquanto roda o `nixos-rebuild boot`.

## Arquivos (visão geral)

| Arquivo | Mudança |
|---|---|
| `modules/nixos/server-sleep.nix` → `host-sleep.nix` | genérico por host |
| `modules/nixos/server-wake.nix` → `host-wake.nix`, `files/server-wake*.py` | vários hosts, log por host, `/acordar/<host>` |
| `modules/nixos/forge-update.nix` (novo) | lado do forge: serviço, timer, raízes de GC, `nixos-rebuild boot` da `main` |
| papel do Pi para o estado das atualizações (novo ou dentro do `host-wake`) | timer das 10h e endpoints `/forge/…` |
| `modules/nixos/forge.nix`, `hosts/forge` | sono, harmonia, atualização |
| `hosts/server/default.nix` | `dionix.serverSleep` → `dionix.sleep` |
| `hosts/pi/default.nix` | `cache` no proxy, papel novo |
| `modules/nixos/homelab.nix` | `forgeMac`, chave pública do cache |
| `modules/nixos/workstation.nix` (ou o papel do notebook) | substituter do forge |
| `home/desktop/waybar.nix`, `files/waybar/scripts/` | widget novo no lugar do `updates.sh` |
| `flake.nix` | checks dos scripts novos |
| `docs/homelab.md`, `README.md`, `CLAUDE.md`, spec do forge | forge dorme; ordem dos sub-projetos |

## Escolhas do autor da spec (o usuário pode corrigir)

- 20 min sem uso para o forge dormir.
- Checagem do canal uma vez por dia, às 10h; a revisão do canal (não a da
  branch) como gatilho.
- O `nix flake update` atualiza todas as entradas, mas o gatilho é só o
  `nixos-26.05` (o unstable anda todo dia e acordaria o forge à toa).
- Um PR por vez: atualizações seguintes reescrevem a mesma branch e o mesmo PR.
- Harmonia em vez de Attic neste momento; vhost do cache sem acordar o forge.
- O widget novo substitui o `upd` atual.
- Com o forge acordado à mão fora das 8h–22h, ele não compila o pendente.
- Falha não tem nova tentativa automática para a mesma revisão do canal; o
  clique em "falhou" pede outra.
- Merge só com o PR em dia com a `main`; senão o forge refaz o build.
- O forge segue a `main` inteira, não só o `flake.lock`: qualquer mudança no
  forge que entra na `main` é aplicada sozinha. Um deploy manual de outra
  branch (`--target-host`) é substituído pela `main` no próximo ciclo.
- O reboot acontece no lugar de uma suspensão, nunca com alguém usando.

## Fica para quem constrói

- Formato exato do JSON dos endpoints e onde o Pi guarda o estado
  (`StateDirectory`).
- Como detectar "build do nix-daemon em andamento" no script de sono.
- Como esperar o cache responder no clique do widget (tempo limite e
  mensagens).
- Testes: estender o check `server-wake` para vários hosts e testar os
  scripts novos no mesmo estilo dos checks atuais.

## Aplicação

A primeira aplicação é feita pelo usuário (depois o forge se mantém sozinho): `nixos-rebuild switch` no Pi, no server e no notebook;
no forge, `nixos-rebuild boot --target-host` + reboot (como no sub-projeto 1).
Antes, à mão: ativar Wake-on-LAN na BIOS do forge, anotar o MAC da `enp2s0`,
criar o token do GitHub em `/var/lib/secrets/github-token`.
