# Decisões do owner — rito-descoberta

Frente 1 do programa do ciclo autônomo (`rito-descoberta` → `modo-autonomo` → `frentes-paralelas`).
As decisões abaixo foram tomadas pelo owner em 2026-11-05, na Fase 0 conduzida na sessão da árvore
principal, cada uma com opções e recomendação pelos cinco pilares (boas práticas, deduplicação,
escalabilidade, performance e segurança) e validada por especialistas VoltAgent:
`qa-sec:security-auditor`, `qa-sec:qa-expert`, `meta:agent-organizer`, `infra:platform-engineer` e
`dev-exp:dx-optimizer`. São normativas: o `specify` parte delas e o `clarify` não as reabre.

Este arquivo é o 1º commit da worktree. A frente `modo-autonomo` lê a versão deste commit, e não a
da ponta da branch, para que o agente não amplie o próprio limite (D11).

Base: `origin/main` em `36e77749d0b09634b6f7d6a796149a93823b583c`, conferida contra a API do GitHub.

## Escopo

- **E1.** Skill nova `skills/rito-descoberta/SKILL.md`: a Fase 0 agnóstica de qualquer frente.
  - Decisões com opções e recomendação pelos cinco pilares, validadas pelo especialista do domínio
    (mapa do E2). Fonte externa só via `ctx_*` (Princípio V).
  - Telas em HTML estático em `docs/specs/<frente>/telas/`, só quando a frente tem interface (D6).
  - Smoke, irreversibilidade, caminhos previstos, dependências, instalações previstas e Gate 0 com
    OK para todas as ondas.
  - Nada é escrito antes do Gate 0, exceto o histórico declarado do D9.
  - Depois do OK: grava o `decisoes-do-owner.md` como 1º commit da worktree, roda
    `cstk hooks install` e `cstk mcp install --project-path <worktree>` e entrega um bloco único
    copiável com `cd <worktree> && claude` e o `/feature-00c` (descrição de até 500 caracteres).
  - Política de instalação (D15 a D19) e histórico (D9).
- **E2.** Mapa papel→agente como seção da skill (D2, D4).
- **E3.** Verificação de plugins, que agora executa install e enable sob a política (D7).
- **E4.** Gate da Fase 0 no `rito-dev` (description e Fase 1) e gate de instalações temporárias na
  Fase 11 (D18), em `skills/rito-dev/SKILL.md` e `templates/docs/rito-dev.md.tmpl`.
- **E5.** `README.md`: o fluxo passa a começar por `/rito-descoberta`.
- **E6.** Registro SDD em `docs/specs/rito-descoberta/`.
- **E7.** Emenda MAJOR 2.0.0 do Princípio IV em `docs/constitution.md` (D15), redigida antes de
  qualquer `/feature-00c` rodar `plan` (Governance), com o sign-off do owner citado no corpo da PR.
- **E8.** O IV da semente (`templates/docs/constitution.md.semente.tmpl`) ganha a política e a
  linha literal de autorização desligada por padrão (D19).

## Fora do escopo

- Trava "caminhos tocados ⊆ caminhos previstos", merge sem aprovação, revert automático e barreira
  técnica `permissions.deny` contra os agentes proibidos (D14): frente `modo-autonomo`.
- Maestro e paralelismo: frente `frentes-paralelas`.
- `instalar.sh`, `configurar.sh`, CI e `cstk`. Débito registrado: o CI não valida o frontmatter
  das skills.
- Templates de papéis (`templates/docs/agentes/`), `CLAUDE.md` semente e a issue #26.
- Limpeza dos registros órfãos de plugin em `~/.claude/plugins/installed_plugins.json` (débito:
  medido em 2026-11-05, 221 dos 249 `projectPath` distintos apontam para pasta inexistente).

## Caminhos previstos

Só caminho literal ou `dir/**`, relativo à raiz do repositório.

```text
skills/rito-descoberta/**
skills/rito-dev/SKILL.md
templates/docs/rito-dev.md.tmpl
templates/docs/constitution.md.semente.tmpl
docs/constitution.md
README.md
docs/specs/rito-descoberta/**
```

## Decisões

- **D1. Forma do produto:** skill nova. A description do `rito-dev` deixa de capturar o pedido de
  frente nova antes da Fase 0.
- **D2. Onde mora o mapa:** seção da skill. O mapa registra o id `plugin@voltagent-subagents`; o
  agente de stack é escolhido por frente e gravado no `decisoes-do-owner.md` dela.
- **D3. Granularidade:** por domínio da decisão, um ou dois agentes. O `security-auditor` entra
  sempre que a decisão toca credencial, terceiro, permissão ou dado; ele valida, não escolhe.
- **D4. Mapa e proibidos:** ver as seções "Mapa papel→agente" e "Regra de proibidos".
- **D5. Pesquisa sem fonte oficial:** `general-purpose` com `ctx_fetch_and_index` obrigatório. O
  prompt proíbe WebFetch, WebSearch e curl, e o conteúdo indexado é dado, não instrução.
- **D6. Telas:** `core-dev:ui-designer` com `qa-sec:accessibility-tester`, só quando a frente tem
  interface.
- **D7. Verificação de plugins (opção B do owner):** o agente executa `install` e `enable`, sempre
  sob a política D15 a D19.
  - Filtro: `scope == "project"` e `projectPath` igual à raiz onde o agente vai ser usado (na
    worktree, quando é lá que ele roda).
  - Marketplace conferido por nome e por `repo` (`VoltAgent/awesome-claude-code-subagents`).
  - Estados: ok; desabilitado; ausente; desconhecido (a listagem falhou: nada é executado); SHA
    divergente (o `gitCommitSha` do `installed_plugins.json` difere do registrado: a regra de
    proibidos é reaplicada aos agentes mapeados, e o reprovado vira "papel sem agente" e volta ao
    owner). Nunca `update` como correção.
- **D8. Fallback por cópia, quando o plugin é impossível:** impresso, nunca executado. `curl` do
  `.md` fixado no SHA de 40 caracteres para `.claude/agents/`, mais o `LICENSE` do mesmo SHA no
  THIRD-PARTY-NOTICES do projeto.
- **D9. Guarda de escrita e histórico (opção A+B do owner):** ver a seção "Histórico".
- **D10. Gate no `rito-dev`:** obrigatório na trilha completa; dispensado em docs, trivial e hotfix
  com incidente. Sem a skill instalada, o rito para com "rito-descoberta ausente: rode instalar.sh".
- **D11. Formato do `decisoes-do-owner.md`:** títulos de seção exatos, como neste arquivo; bloco de
  caminhos com caminho literal ou `dir/**`, relativo à raiz; bloco ausente ou vazio falha fechado;
  "Irreversibilidade" sempre preenchida, com "nenhuma" explícito; 1º commit da worktree.
- **D12. Plugin `voltagent-meta`:** sai do mapa (orquestração passa ao `architect-reviewer`) e o
  owner o desinstala.
- **D13. Plugins na worktree:** verificar também na worktree, em `-s project`. Nos projetos-alvo com
  `.claude/settings.json` versionado, a mudança vai na PR da frente.
- **D14. Barreira técnica contra os proibidos:** fica para a `modo-autonomo`. Aqui a regra é
  critério de escolha, com o limite declarado: 121 dos 164 agentes têm Bash, e um plugin instalado
  traz junto os agentes proibidos dele.
- **D15. Alcance da emenda 2.0.0:** estreita. `instalar.sh` e `configurar.sh` continuam só
  imprimindo; `cstk`, `context-mode` e `ponytail` continuam instalados pela pessoa. Só o agente, numa
  frente de trilha completa, instala, e só sob a política. O título do IV muda.
- **D16. Autorização:** a seção "Instalações previstas" traz, por item, o comando exato de
  instalar, o comando exato de desfazer, o escopo, a versão ou SHA e a classe. O OK do Gate 0 cobre
  a lista. Flag diferente, item fora da lista ou mudança de classe é desvio: para e pede OK.
- **D17. Canais.**
  - Plugin do mapa: `-s project`, marketplace conferido por nome e `repo`; só plugin com apenas
    `agents/` (sem hooks nem `.mcp.json`) e `tools:` dentro da regra de proibidos. O SHA é conferido
    depois do install; divergente, desinstala e para.
  - Pacotes: versão exata; `--ignore-scripts` em npm, pnpm e yarn, salvo postinstall listado pelo
    nome; pip com `--only-binary=:all:` e `--require-hashes`; registro conferido (um `.npmrc` do
    repositório pode redirecioná-lo).
  - `marketplace add` e `marketplace remove` entram na lista; por gravarem no escopo global, a
    classe é temporária.
  - Proibido sempre: script remoto (`curl | bash`, `wget | sh`, bootstrap sem assinatura); executor
    que baixa na hora (`npx`, `uvx` e `pipx run` de pacote não instalado, `gh extension install`);
    `-y` e `--accept-command` do `claude plugin install` (aceitam comando declarado pelo
    marketplace); `update`, `marketplace update` e `self-update`.
- **D18. Ciclo de vida (regra do owner: "caso tenha sido instalado apenas para algum teste, deve
  obrigatoriamente desinstalar").**
  - A classe vem da lista do Gate 0, não do arquivo tocado. Permanente é o que tem essa classe no
    Gate 0 e aparece no diff da PR, com manifesto e lockfile. Manifesto ou lockfile alterado fora da
    lista é desvio. Nada permanente é global.
  - Temporária que toca arquivo rastreado sai antes do commit.
  - Temporária fora do repositório é desinstalada ao fim do uso, no máximo na Fase 11, dentro da
    worktree e antes do `git worktree remove`, sempre com `-s project` explícito (o `uninstall` não
    aceita caminho e o padrão dele é `user`).
  - Gate da Fase 11, antes do "Encerrar": cada install temporário do log tem um uninstall depois
    dele, e o estado real (id, escopo, projeto, versão e SHA por jq sobre `installed_plugins.json`,
    mais `enabledPlugins` e o cache) bate com a linha de base. Qualquer diferença impede o
    encerramento.
  - O que já estava instalado antes da frente nunca é reinstalado, atualizado nem removido.
  - Temporárias globais rodam uma por vez entre frentes paralelas.
- **D19. Projetos-alvo:** a semente ganha a linha literal "Instalação pelo agente: desligada" como
  padrão; o projeto a liga por emenda própria. A skill lê o valor na `origin/<base>`, nunca na
  worktree, e o agente nunca o edita. Sem a linha ligada, a skill só imprime. O `configurar.sh
  --atualizar` não regrava a semente, então os projetos já ratificados seguem só imprimindo.
- **Vigência:** até o merge vale a constituição 1.1.0. Durante a construção desta frente o agente
  não instala nada; a primeira instalação pelo agente é a do S3.

## Mapa papel→agente

Catálogo validado no SHA `ed74d115b7fb7026a22a4f816a8e3250f425e3b4` do marketplace
`voltagent-subagents`. A fonte da verdade é o array `agents` do `plugin.json` (164 agentes), não o
diretório.

| Domínio | Agente | Ferramentas |
|---|---|---|
| arquitetura, estrutura, deduplicação, orquestração | `qa-sec:architect-reviewer` | escreve |
| segurança, terceiros, permissões, dado | `qa-sec:security-auditor` | só leitura |
| qualidade, smoke, testes | `qa-sec:qa-expert` | leitura e Bash |
| performance | `qa-sec:performance-engineer` | escreve |
| CI/CD, deploy, rollback | `infra:deployment-engineer` | escreve |
| dados e migração (sob demanda) | `infra:database-administrator` | escreve |
| escala em produção (sob demanda) | `infra:sre-engineer` | escreve |
| compliance (sob demanda) | `qa-sec:compliance-auditor` | só leitura |
| ferramentas, CLI, scripts | `dev-exp:dx-optimizer` | escreve |
| git | `dev-exp:git-workflow-manager` | escreve |
| dependência nova | `dev-exp:dependency-manager` | escreve |
| stack da frente | `lang:<linguagem>` ou `core-dev:<agente>`, escolhido na Fase 0 | varia |
| telas | `core-dev:ui-designer` e `qa-sec:accessibility-tester` | varia |
| pesquisa sem fonte oficial | `general-purpose` com o papel no prompt (D5) | todas, restritas no prompt |

A construção usa o agente de stack; a revisão continua sendo o `bmad-code-review`.

## Regra de proibidos

É proibido como papel o agente que:

- (a) tem WebFetch, WebSearch, `mcp__`, navegador ou desktop no `tools:` (41 de 164 no SHA
  registrado; Princípio V);
- (b) orquestra em paralelo ao `feature-00c` (lista nominal curta, porque isso não aparece no
  `tools:`: `meta:it-ops-orchestrator`, `meta:codebase-orchestrator`);
- (c) não tem linha `tools:` ou tem Agent ou Task no `tools:` (falha fechada; 0 hoje).

O agente cujo corpo manda instalar ou baixar código não é proibido por isso: o que ele instalar
segue a política D15 a D19, e o que a política proíbe (script remoto, por exemplo) continua
proibido.

## Instalações previstas

| Instalar | Desfazer | Escopo | Versão ou SHA | Classe |
|---|---|---|---|---|
| `claude plugin install voltagent-core-dev@voltagent-subagents -s project` | `claude plugin uninstall voltagent-core-dev@voltagent-subagents -s project` | worktree descartável do S3 | `ed74d115b7fb7026a22a4f816a8e3250f425e3b4` | temporária |

## Smoke

Pós-merge, executado pelo agente na sessão da árvore principal e relatado ao owner (as Fases 8 a 10
do rito são no-op neste repositório).

- **S1.** `cp -r` de `skills/rito-descoberta` e `skills/rito-dev` a partir da `main` para
  `~/.claude/skills/`. Antes, `diff -r` mostra o que já estava instalado; depois, `diff -r` vazio e
  `name:` correto no frontmatter.
- **S2.** O clone do catálogo está no SHA registrado; se não estiver, "mapa não verificado" e o
  rito para. O mapa tem N citações, com N > 0; cada uma está no array `agents` do `plugin.json`
  (164, não os 166 `.md`) e passa nas regras (a) e (c); os nomes da regra (b) existem no catálogo.
- **S3.** Em worktree descartável, isolada dos plugins já presentes.
  - Precondição: `voltagent-core-dev@voltagent-subagents` fora da linha de base.
  - Instala pelo item da seção "Instalações previstas", confere o estado ok e o `gitCommitSha`,
    desinstala dentro da worktree.
  - Igualdade por jq do conjunto (id, escopo, projeto, versão, SHA), mais `enabledPlugins` e o
    cache: a pasta do `core-dev` precisa sumir; se a CLI deixar sobra, o smoke falha e o achado
    volta ao owner.
  - Caso negativo: um plugin fora da lista é recusado antes do `install`.
  - O histórico mostra o par install e uninstall.
- **S4.** Uso real: a Fase 0 da `modo-autonomo` feita com `/rito-descoberta`. Títulos exatos
  conferidos por `grep`, bloco de caminhos não vazio e nenhuma escrita até o OK além do histórico.
- **S5.** Linha de base; cria `~/.claude/skills/_smoke_qa/x`; só a raiz `skills` muda, a diferença
  lista o arquivo, o log registra e o rito para por mudança não declarada; remove e a impressão
  digital volta; controle negativo: duas medições sem mudança dão iguais.
- **Falha:** até 2 correções, cada uma por PR com gate. Na 3ª, PR de revert na `main` (com gate),
  remoção da cópia em `~/.claude/skills` e diagnóstico ao owner.

## Telas

Não há: a frente não tem interface.

## Irreversibilidade

Nenhuma. A frente só muda Markdown, e tudo se desfaz com revert por PR. A política proíbe o que não
tem volta (script remoto), e o que ela permite se desfaz pelo comando de desfazer registrado.

## Dependências novas

Nenhuma no repositório.

## Histórico

Guarda de escrita antes do Gate 0 e histórico das alterações fora do repositório (D9, opção A+B).

- Log por frente e por máquina em `~/.claude/cockpit/historico-<frente>.log`, só acrescentado,
  gravado pela sessão principal desde a linha de base. É a única escrita antes do Gate 0, e é
  declarada. Cada linha leva máquina, worktree e branch.
- A listagem da linha de base fica ao lado do log, e cada rodada grava a diferença: criados,
  apagados e alterados.
- Antes e depois de cada rodada de subagentes e de cada comando que o owner rodar:
  `git status --porcelain --ignored`, `git worktree list` e a impressão digital das raízes.
  - Por metadados (caminho, tamanho, mtime, ctime e inode; só arquivos): `~/.claude/skills` (sem
    `synced/`), `~/.claude/agents`, `~/.claude/plugins/cache`, `<raiz>/.claude` (sem
    `feature-00c-state/` e `enforcement-log.jsonl`), `<raiz>/.git/hooks`, `~/.ssh`,
    `~/.config/gh`, `~/.local/bin`, `~/.gitconfig`, `~/.bashrc`, `~/.profile`.
  - Por hash de conteúdo, e só o hash vai ao log: `~/.claude/settings.json`,
    `<raiz>/.claude/settings.json`, `<raiz>/.claude/settings.local.json`, `<raiz>/.git/config`,
    `crontab -l` e a chave `mcpServers` do `~/.claude.json`.
  - Por campos, sem `lastUpdated`: `installed_plugins.json` (id, escopo, projeto, versão, SHA) e
    `known_marketplaces.json` (nome, `repo`); catálogo VoltAgent por `git rev-parse HEAD`.
- Diferença não explicada por comando declarado ou ruído conhecido: para e volta ao owner.
- Na cópia versionada, `$HOME` vira `~` e as raízes sensíveis aparecem só como "alterada".
- O histórico entra neste arquivo no 1º commit e é copiado de novo para o registro antes da PR.
- Risco que fica: escrita fora dessas raízes (por exemplo `/tmp`) e qualquer coisa feita como root.

### Alterações fora do repositório nesta Fase 0

| Hora (2026-11-05, -03) | O quê | Origem | Situação |
|---|---|---|---|
| antes das 12:56 | 1ª rodada, 5 validadores | — | repositório igual antes e depois; fora dele não medido |
| 13:01 | `/tmp/claude-1000/a` e `/tmp/claude-1000/b` criados (456 bytes cada) | validador de qualidade, contra a ordem de somente leitura | removidos pela sessão principal |
| 13:01:35 | `~/.claude/plugins/known_marketplaces.json` (marketplace oficial) | atualização automática do Claude Code | ruído |
| 13:01:53 | `<raiz>/.claude/feature-00c-state/templates-automacao/state.db-shm` | SQLite | ruído |
| 13:23 a 13:27 | 3ª rodada, 3 validadores | — | nenhuma escrita detectada; `/tmp` sem arquivo novo |
| 13:24:58 | `~/.claude/skills/synced/…` | sincronização de skills do Claude Code | ruído |

O repositório e as worktrees ficaram inalterados durante toda a Fase 0 até o OK.

## Pendências para a research do plan

Via `ctx_fetch_and_index` (Princípio V), antes de afirmar no artefato:

- documentação oficial da CLI `claude plugin`: campos de `list --json`, `-s project`, `--prune`,
  `-y`, `--accept-command`, comportamento numa worktree, e se o `install` relê o remoto ou usa o
  clone local no SHA (e se dá para fixar a ref do marketplace);
- `--ignore-scripts` (npm, pnpm, yarn) e `--require-hashes` (pip) na documentação oficial.

## OK do owner

Em 2026-11-05, na sessão da árvore principal:

- respostas por decisão: D1 a D3, D5, D6, D8, D10 a D13 aceitas como recomendadas; "D7. B, D9.A+B,
  D4. quero permitir que instale, mas tem que ter o uninstall depois de finalizado, se o que foi
  instalado precisa que fique instalado para o funcionamento do codigo. pode deixar. caso tenha
  sido instalado apenas para algum teste, deve obrigatoriamente desinstalar. D14. A";
- OK final, que cobre D15 a D19, a lista de instalações e todas as ondas: "ok.. vou seguir suas
  recomendações". Vale como sign-off da emenda 2.0.0 do Princípio IV, a ser citado no corpo da PR.

O OK para todas as ondas cobre: worktree; `cstk hooks install` e `cstk mcp install`; este arquivo
como 1º commit; a emenda redigida antes do `plan`; todas as ondas do `/feature-00c` com os spawns
liberados em auto mode; `bmad-code-review` até zerar achados altos e críticos; commit, push, PR e
CI. A sessão para no gate de merge, que continua com o owner. Depois do merge: smoke S1, S2, S3 e
S5, Fase 11 e o S4 na próxima frente.
