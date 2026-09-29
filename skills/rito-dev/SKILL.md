---
name: rito-dev
description: "Rito oficial de desenvolvimento do projeto-alvo — do git pull até a PR mergeada, validada no ambiente de integração e promovida a produção. Use SEMPRE que a tarefa envolver desenvolver, customizar, corrigir ou alterar código do projeto-alvo, ou quando o dev pedir para 'seguir o rito', 'abrir PR', 'promover para produção', 'subir para produção' ou iniciar qualquer feature/fix/chore/docs. Lê os parâmetros do projeto em `cockpit.config` na raiz — nenhum nome de branch, repositório ou comando é fixo nesta skill."
---

# Rito de Desenvolvimento (cockpit)

Você (Claude) conduz o dev por este rito, fase a fase, **sem pular gates**.

## Parâmetros — leitura de `cockpit.config` (FR-004)

**Antes de qualquer fase**, leia `cockpit.config` na raiz do projeto-alvo (formato
`CHAVE=valor`, uma por linha — mesmo mecanismo de `versoes.env`). Todo valor que varia
entre projetos vem exclusivamente dele; nunca cite um valor fixo nesta skill. Se o
arquivo não existir ou faltar uma chave obrigatória, **nomeie exatamente a chave
ausente e PARE** — nunca siga com um valor presumido (ex.: nunca infira `npm run
build` porque `CMD_BUILD` está faltando; nunca infira `main` porque
`BRANCH_INTEGRACAO` está faltando).

Chaves consumidas por este rito (ver `cockpit.config.example` na raiz do cockpit):

| Chave | Fase(s) que consome |
|---|---|
| `PROJETO_NOME` | citada no relatório final de cada fase |
| `REPO_REMOTO` | preparatória (`gh api repos/<REPO_REMOTO>/...`), Fase 6 (`gh pr view`) |
| `BRANCH_INTEGRACAO` | Fase 1 (base padrão), Fase 4/7 (base da PR de feature), Fase 9 |
| `BRANCH_PRODUCAO` | Fase 1 (base de `hotfix/`), Fase 9, Fase 10, Fase 11 |
| `GERENCIADOR_PACOTES` | citado no relatório da Fase 2 (nunca invocado para instalar) |
| `CMD_TYPECHECK` / `CMD_LINT` / `CMD_BUILD` | citados na Fase 5 (rodam no CI, nunca localmente) |
| `CMD_DEPLOY_INTEGRACAO` | Fase 7 (relatório de deploy automático), Fase 8 |
| `CMD_DEPLOY_PRODUCAO` | Fase 9, Fase 10 |
| `URL_AMBIENTE_INTEGRACAO` (opcional) | Fase 8 — se ausente, pergunte a URL ao dev uma vez |
| `URL_AMBIENTE_PRODUCAO` (opcional) | Fase 10 — se ausente, pergunte a URL ao dev uma vez |

## Gates gerais (valem em toda fase)

- **Nunca** push direto na branch de integração ou de produção, force-push, ou merge sem PR.
- **Nunca** `git add -A` / `git add .` — stage sempre por paths explícitos.
- **Nunca** validar com ambiente local (dev server, typecheck ou build locais) — a
  validação é do **CI** (`gh pr checks`), do **smoke no ambiente de integração** e do
  **smoke em produção**.
- **Nunca** promover para produção com o ambiente de integração quebrado ou sem smoke
  feito nele; **nunca** smoke em produção sem rollback anotado antes.
- Identidade de quem aprova cada PR: se `cockpit.config` tiver `IDENTIDADES`
  (`nome:email;...`), use a tabela; se não tiver, pergunte ao dev/owner na hora
  (Fase 4/Fase 9). Valores do `cockpit.config` podem vir entre aspas simples —
  ao ler, remova o par envolvente.

## Etapa preparatória — Sincronizar

Em fluxo de worktree (o padrão) **não** há `checkout` na árvore principal: traga a base
e confirme que veio, comparando com uma fonte de rede diferente (o `gh`).

```bash
git fetch origin <BRANCH_INTEGRACAO>
[ "$(git rev-parse origin/<BRANCH_INTEGRACAO>)" = \
  "$(gh api repos/<REPO_REMOTO>/branches/<BRANCH_INTEGRACAO> --jq .commit.sha)" ] \
  && echo "✅ base em sincronia" || echo "❌ origin/<BRANCH_INTEGRACAO> local está VELHO — não comece nada"
```

Só quando você estiver trabalhando na **própria árvore principal** (sem worktree):

```bash
git branch --show-current   # confirme onde está ANTES de qualquer operação
git checkout <BRANCH_INTEGRACAO>
git pull --ff-only origin <BRANCH_INTEGRACAO>
```

`--ff-only` falhou → PARE e investigue (a base local divergiu). Nunca trabalhe sobre
estado stale.

## Fase 1 — Branch

A partir de `origin/<BRANCH_INTEGRACAO>` conferido: `feature/<slug>` · `fix/<slug>` ·
`chore/<slug>` · `docs/<slug>`. (`hotfix/<slug>` sai de `<BRANCH_PRODUCAO>` — só com
incidente real em produção.)

Nunca `git checkout -b` na árvore principal; a base vai explícita, senão o driver
deriva do `HEAD` da árvore principal.

```
/parallel-work <prefixo>/<slug> --base origin/<BRANCH_INTEGRACAO ou BRANCH_PRODUCAO em hotfix>
```

Entre na worktree que a skill `/parallel-work` devolver antes da Fase 3 — criar a
worktree não muda o diretório corrente, e sem o `cd` o commit cai na árvore principal.

## Fase 2 — Desenvolver

Antes de mudança não-trivial, consulte a convenção de domínio do próprio
projeto-alvo, se houver (docs internos, ADRs, `CONTRIBUTING.md`) — esta skill não
presume nenhuma regra de arquitetura de um provedor ou domínio específico (ex.:
multi-tenância, camadas de módulo, política de acesso a dado): isso é do
projeto-alvo documentar, não desta skill impor.

## Fase 3 — Commit

Conventional Commits em português do Brasil, escopo = módulo/área do diff:

```bash
git add <paths explícitos>
git commit -m "<tipo>(<escopo>): <descrição em pt-BR>"
```

`wip` **não** é tipo válido; para trabalho em progresso use tipo real com marcador:
`chore(<escopo>): wip — <resumo>`. Se o projeto tiver hook de `commit-msg`
(ex.: commitlint), ele valida automaticamente — sem hook, siga a convenção à mão.
Nunca `--no-verify`. A mensagem final do squash costuma virar o **título da PR**.

## Fase 4 — Abrir PR

```bash
git push -u origin <branch>
gh pr create --base <BRANCH_INTEGRACAO ou BRANCH_PRODUCAO em hotfix> \
  --title "<tipo>(<escopo>): <descrição ≤100 chars>"
```

- Base **sempre** `BRANCH_INTEGRACAO` (base `BRANCH_PRODUCAO` é só promoção/hotfix);
  PR empilhada numa base errada pode não disparar o CI — confira antes de abrir.
- Corpo: siga o template de PR do próprio repositório, se houver (o quê/porquê,
  módulo, checklist). Mudança visual → screenshot/GIF. Migração de dado → cole o
  reverso no corpo (é o rollback do smoke em produção).
- **Pergunte ao dev/owner agora quem aprova esta PR** (dev do time vs. owner/mantenedor)
  — `cockpit.config` não guarda essa identidade.

## Fase 5 — CI (loop até verde)

```bash
gh pr checks <número> --watch
```

Vermelho → corrigir no branch → push → re-checar. **Não** compensar com validação
local. Nem toda integração é coberta pelo typecheck do CI (ex.: código que roda num
runtime dinâmico/não-tipado do próprio projeto) — se o diff tocar numa área assim,
revise com atenção redobrada; o smoke no ambiente de integração é a rede de
segurança real.

## Fase 6 — Review (PONTO DE PARADA)

- Autor **dev do time**: aguardar aprovação de quem foi identificado na Fase 4. Sem
  aprovação = sem merge, sem exceção. Comentários → novos commits no branch.
- Autor **owner/mantenedor**: self-review — ele relê o diff completo na página da
  PR. Você (Claude) **para aqui e aguarda o OK explícito dele** antes de mergear.
- **Aqui a sessão pode encerrar e o rito ser retomado depois** — ao retomar, confira
  `gh pr view <número> --repo <REPO_REMOTO>` antes de agir.

**Ao parar, entregue o gate assim — não basta avisar que está pronto:**

1. **Pontos de alteração** — o que mudou e onde, no nível em que quem aprova decide.
   Não recole o diff inteiro.
2. **`RECOMENDAÇÃO: aprovar` ou `RECOMENDAÇÃO: pedir mudanças`, com o porquê medido.**
   Recomendar *pedir mudanças* quando for o caso é parte do trabalho.
3. **O comando pronto** para quem aprova colar (quem escreve a aprovação é sempre um
   humano).

Você nunca aprova nem mergeia sozinho — a aprovação é o registro de que um humano
leu o diff.

## Fase 7 — Merge

```bash
gh pr merge <número> --squash --delete-branch
```

**A limpeza local da worktree não é aqui — é a Fase 11.** As fases seguintes (smoke
no ambiente de integração, promoção, smoke em produção) ainda podem precisar ler
código da worktree.

Se o projeto tem deploy automático no push para `BRANCH_INTEGRACAO`, ele dispara
aqui (comando/gatilho configurado: `CMD_DEPLOY_INTEGRACAO`, quando presente em
`cockpit.config`). Merges que só tocam documentação costumam não disparar deploy,
se o projeto tiver esse filtro configurado.

## Fase 8 — Smoke no ambiente de integração

1. Confira o workflow de deploy mais recente do ambiente de integração via
   `gh run list` filtrando pela branch (`BRANCH_INTEGRACAO`) — sem assumir nome de
   workflow fixo.
2. Exercite **o fluxo alterado** em `URL_AMBIENTE_INTEGRACAO` (se a chave não estiver
   preenchida em `cockpit.config`, pergunte a URL ao dev uma vez).
3. Console/log limpo no que foi exercitado.
4. Falhou → corrija com **nova PR** (volte à Fase 1). Ambiente de integração
   inutilizável → reverta a PR primeiro. **Nunca promova com ele quebrado.**

## Fase 9 — Promoção para produção

**Se `BRANCH_INTEGRACAO` for igual a `BRANCH_PRODUCAO`** (modelo de branch única —
Princípio I do cockpit: "integração = produção" é caso válido, não modo separado),
esta fase inteira é **no-op**: não há promoção a fazer, o deploy da Fase 7 já foi
para produção.

Caso contrário:

```bash
gh pr list --base <BRANCH_PRODUCAO> --head <BRANCH_INTEGRACAO>   # existe PR de promocao?
```

- Se existir um PR draft `<BRANCH_INTEGRACAO> → <BRANCH_PRODUCAO>` (radar automático
  do projeto), promova-o: `gh pr ready <número>`. Senão, abra você mesmo:
  `gh pr create --base <BRANCH_PRODUCAO> --head <BRANCH_INTEGRACAO>`.
- Corpo: liste o delta desde a última promoção; complemente com o que exige atenção
  (migração de dado, mudança de contrato).
- Dev precisa da aprovação de quem foi identificado; owner é coberto por
  self-review consciente. **PONTO DE PARADA igual à Fase 6.**
- Merge: `gh pr merge <número> --merge` — **merge commit, nunca squash, nunca
  `--delete-branch`** (squash aqui divergiria o histórico entre as duas branches).
- Se o projeto tem deploy manual de produção, dispare-o agora (comando configurado:
  `CMD_DEPLOY_PRODUCAO`, quando presente em `cockpit.config`) — **confira o alvo**:
  o seletor de um workflow manual costuma pré-selecionar a branch default, que pode
  não ser `BRANCH_PRODUCAO`.

## Fase 10 — Smoke em produção (rollback ANTES)

1. **Anote o rollback antes de testar:** SHA de `BRANCH_PRODUCAO` pré-promoção, e o
   reverso de qualquer migração de dado aplicada nesta promoção.
2. Exercite **o fluxo promovido** em `URL_AMBIENTE_PRODUCAO` (se a chave não estiver
   preenchida, pergunte a URL ao dev uma vez).
3. Console/log limpo no que foi exercitado.
4. **Falhou → restore-to-green imediato:** execute o rollback anotado, confirme
   produção verde, só depois diagnostique. Avise o dev/owner.

## Fase 11 — Encerramento

Rode a etapa **"Encerrar"** da skill `/parallel-work` (guards, exit codes e passo a
passo completos de remoção da worktree e da branch estão lá — não duplicados
aqui), usando `<branch>` desta frente e a base atualizada (`BRANCH_INTEGRACAO`, ou
`BRANCH_PRODUCAO` quando a fase 9 foi no-op ou em hotfix).

## Formato de report ao dev

Ao final de cada fase, informe em 1-2 linhas: fase concluída, evidência (nº da PR,
status dos checks, run do deploy, resultado do smoke) e próxima ação. Se um gate
bloquear (ex.: aguardando aprovação ou self-review), diga explicitamente o que se
espera de quem.
