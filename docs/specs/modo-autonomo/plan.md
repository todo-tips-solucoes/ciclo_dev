# Implementation Plan: modo-autonomo

**Feature**: `modo-autonomo` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)
**Fonte normativa**: [decisoes-do-owner.md](decisoes-do-owner.md) (E1 a E8, D1 a D13, caminhos
previstos, smoke). Este plano não reabre nenhuma decisão. Arquivo fora de "Caminhos previstos" é
desvio e volta ao owner. O gate owasp-security do plan voltou ao owner (block-001, dec-022), que
escolheu A1 (a trava roda também na PR para a produção), A2 (config do semantic-release é
governança e o `TOKEN_AUTOMACAO` é restrito) e ratificou F1 (todo `decisoes-do-owner.md` é
governança). A1 troca a redação "a PR de promoção fica fora da trava" do D4 por "a PR de promoção
passa sozinha na trava"; a promoção segue autônoma (D8). O texto do registro é do owner e não muda
nesta frente.

## Summary

O plano liga, por projeto, o merge e a promoção sem leitura humana. Quatro barreiras substituem a
leitura, e nenhuma depende do agente conferir a si mesmo:

- **fonte da verdade**: a linha `Merge autônomo: ligado|desligado` na constituição da base,
  escrita pelo configurador a partir da chave opcional `MODO_AUTONOMO`; ausente ou inválida vale
  `desligado` (D1);
- **trava de caminhos**: workflow-template `caminhos-previstos` em `pull_request_target`, que lê o
  registro da Fase 0 na base e publica status no HEAD do PR, check obrigatório no ruleset (D3, D4).
  Também roda na PR para a produção: só a de promoção passa sozinha, as demais exigem dono
  (A1, block-001);
- **identidade e ruleset**: o agente só liga `gh pr merge --auto --squash` depois de conferir, na
  hora, a própria identidade sem privilégio de administração e o ruleset sem bypass com os três
  checks obrigatórios (D2, D5);
- **barreira de agentes**: o subcomando `historico.mjs plugin` calcula as regras
  `permissions.deny` dos agentes proibidos, e a skill as mescla na worktree (D9, D10).

Falhas têm teto: 2 correções de CI e 2 de smoke, depois estaciona ou reverte (D6). O smoke é
executável e congelado no Gate 0 (D7). A promoção é por lote com SHA fixado e rollback anotado
(D8). O ramo desligado do rito fica igual ao de hoje, e o cockpit mantém o gate humano (FR-026).

A research trouxe a sintaxe oficial da regra de subagente e a forma do nome de agente de plugin.
A composição das duas para agente de plugin é inferência e é provada no S4 (R1). Os itens que a
fonte oficial não confirmou estão marcados como não verificados e viram prova no S3, com
falha fechada até lá (research §Pendências).

## Technical Context

**Language/Version**: Bash (`configurar.sh`, `scripts/testar-configurar.sh`), JavaScript ESM em
Node (`historico.mjs`, só `node:` nativos), YAML de GitHub Actions (templates), Markdown (skills e
templates). Node no runner: o pré-instalado da imagem (R11); na máquina, o pré-requisito `node` do
Princípio VII.
**Primary Dependencies**: `git`, `gh`, `jq`, `node`. Nenhuma dependência nova (registro,
"Dependências novas"). Workflows usam só o `gh` e o `jq` do runner e as actions já fixadas por SHA.
**Storage**: N/A. Estado lido na hora: constituição e registro na base, API do GitHub,
`installed_plugins.json`, `.claude/settings.json` da worktree.
**Testing**: `scripts/testar-configurar.sh` (existente, com shellcheck e actionlint no CI) para
chave e templates; `skills/rito-descoberta/historico.test.mjs` (novo, Node sem dependência) para o
subcomando; smoke S1 a S5 pós-merge.
**Target Platform**: Linux, WSL e macOS para scripts (briefing, linha "Técnica"; constituição,
Princípio VII); runner GitHub `ubuntu-latest` para workflows (R11, com aviso de migração de imagem).
**Project Type**: toolkit de skills, templates e scripts (o cockpit).
**Performance Goals**: N/A. A trava pagina a lista de arquivos do PR até o teto da API (R8).
**Constraints**: Princípios I, II, IV, V, VI e VII da constituição; caminhos previstos; o
configurador só imprime a configuração do GitHub (FR-006).
**Scale/Scope**: 21 entradas no bloco "Caminhos previstos"; 22 arquivos fora do registro SDD
(2 novos: o workflow-template e o teste; 20 alterados).

Nenhum `NEEDS CLARIFICATION`. Nenhum eixo estrutural em aberto: linguagem, stack e plataforma são
as do repositório e foram fixadas nas decisões do owner.

## Constitution Check

*GATE: passa antes do Phase 0. Re-checado depois do Phase 1 (seção Re-check).*

| Princípio | Status | Notas |
|---|---|---|
| I. Agnosticismo verificável | PASS | Nenhum valor real: `MODO_AUTONOMO` é chave do `cockpit.config`; templates usam `{{...}}`; exemplos com `minha-org/meu-projeto`. Integração = produção continua válida (promoção no-op, D8). |
| II. Cockpit sob o próprio ciclo | PASS | Trilha completa: worktree com base `origin/main` (`0735cb4`, conferida contra a API na Fase 0), `/feature-00c`, `bmad-code-review`, PR e gate do owner. O cockpit não ganha a linha `Merge autônomo:` (FR-026). Este orquestrador não roda `git fetch`; a reverificação da base fica com a sessão na abertura da PR. |
| III. Identidade de commit | N/A | O plano não commita; a identidade do agente do D2 é dos projetos-alvo, não do cockpit. |
| IV. Script nunca instala | PASS | O configurador só imprime ruleset, auto-merge e identidade (FR-006). Instalações previstas: nenhuma. `historico.mjs plugin` é só leitura. |
| V. Fonte oficial antes de afirmar | PASS com pendências | Research feita com `ctx_fetch_and_index` por subagentes folha, link por item. O que a fonte não confirmou está marcado como não verificado, com falha fechada (research §Pendências). |
| VI. Português do Brasil | PASS | Artefatos e prosa nova em pt-BR; identificadores como no código. |
| VII. Portáveis, idempotentes, contidos | PASS | `configurar.sh` escreve só no projeto-alvo; a mescla de deny é união idempotente; o teste cria fixtures em diretório temporário; pré-requisitos seguem `git`, `gh`, `node`, `jq`, `curl`. |

## Project Structure

### Documentation (this feature)

```text
docs/specs/modo-autonomo/
├── decisoes-do-owner.md      # registro da Fase 0 (1º commit, normativo)
├── spec.md
├── plan.md                   # este arquivo
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    ├── caminhos-previstos.md # workflow-template da trava (D4)
    ├── historico-plugin.md   # subcomando plugin (D9, D10)
    └── modo-autonomo.md      # leitura do modo, merge, correções, promoção (D1, D2, D5 a D8)
```

### Source Code (repository root)

```text
configurar.sh                                     # chave MODO_AUTONOMO, placeholder, impressão do GitHub
cockpit.config.example                            # chave comentada, valor desligado
scripts/testar-configurar.sh                      # cenários da chave e do template novo
.github/workflows/ci.yml                          # job novo: testes do historico.mjs plugin
README.md                                         # modo autônomo
docs/specs/configurar/contracts/cli.md            # contrato do configurar
skills/rito-dev/SKILL.md                          # seção Modo autônomo + ponteiros Fases 6-10
skills/rito-descoberta/SKILL.md                   # PR de registro (D3), barreira deny (D9), lista fechada (D10)
skills/rito-descoberta/historico.mjs              # subcomando plugin
skills/rito-descoberta/historico.test.mjs         # NOVO: testes com fixtures temporários
templates/docs/rito-dev.md.tmpl                   # seção Modo autônomo + ponteiros
templates/docs/constitution.md.semente.tmpl       # linha Merge autônomo, Princípio II com dois ramos
templates/docs/project-context.md.semente.tmpl    # ponteiro ao Princípio II
templates/CLAUDE.md.semente.tmpl                  # ponteiro ao Princípio II
templates/docs/agentes/implementador.md.tmpl      # ponteiro ao Princípio II
templates/docs/agentes/revisor.md.tmpl            # ponteiro ao Princípio II
templates/.github/workflows/caminhos-previstos.yml.tmpl   # NOVO: trava
templates/.github/workflows/require-codeowner-approval.yml.tmpl  # modo ligado passa com aviso
templates/.github/workflows/audit-merge-vermelho.yml.tmpl # sem issue por merge autônomo
templates/.github/workflows/promotion-pr.yml.tmpl         # TOKEN_AUTOMACAO obrigatório no modo ligado
templates/.github/CODEOWNERS.tmpl                 # comentário: papel dos donos no modo ligado
templates/.cockpit/LEIAME.md.tmpl                 # ponteiro ao Princípio II
```

**Structure Decision**: nenhum diretório novo. O teste do subcomando fica ao lado do
`historico.mjs`, dentro de `skills/rito-descoberta/**` (caminho previsto). Os demais caminhos do
bloco já existem.

## Design por arquivo

### `configurar.sh` (E1, D1, FR-001, FR-002, FR-004, FR-006)

- `MODO_AUTONOMO` entra em `CHAVES_ORDEM` como chave **opcional**. A validação não usa o ramo de
  erro do `PRINCIPIO_III`: valor fora de `ligado`/`desligado` (inclusive vazio e `Ligado`) vira
  `desligado` com aviso no stderr, e o fluxo segue (o `--atualizar` não quebra, SC-001).
- A pergunta interativa sugere `desligado` (mesmo mecanismo `definido || setar` do
  `PRINCIPIO_III`).
- Novo placeholder `{{MODO_AUTONOMO}}`, renderizado com o valor já normalizado. Só a semente da
  constituição o usa.
- Ao final, só no modo `ligado`, imprime a configuração do GitHub a fazer pela pessoa: identidade
  do D2 (permissões), ruleset da integração (sem bypass; `ci`, `commitlint` e `caminhos-previstos`
  obrigatórios; fonte esperada do status), auto-merge e apagar branch no merge habilitados,
  `TOKEN_AUTOMACAO` quando integração ≠ produção. Nada é criado (Princípio IV, FR-006). Os nomes
  dos campos citados saem da research (R3, R4, R13).
- Quando integração ≠ produção, a impressão inclui o ruleset da produção: sem bypass, com
  `caminhos-previstos-producao` obrigatório e a mesma fonte esperada (A1, block-001; D-P11).
- Sobre o `TOKEN_AUTOMACAO` (A2, block-001; R17): token de GitHub App ou fine-grained de uma
  identidade que não está no CODEOWNERS, só deste repositório, com Contents e Pull requests, sem
  Administration nem Workflows; nunca o token pessoal do owner. Motivo impresso junto: o
  `release.yml` e o `promotion-pr` rodam com ele sobre código que, no modo ligado, chega à produção
  sem leitura humana.
- A impressão inclui também (R16): permissões padrão do `GITHUB_TOKEN` na opção restrita (só
  leitura); todo workflow do projeto que roda em `pull_request` declara `permissions:` sem
  `statuses: write`, porque status do `GITHUB_TOKEN` vem da mesma app que a trava e passaria pela
  fonte esperada; e que desligar o modo é trocar a linha da constituição **e** devolver aos
  rulesets da integração e, quando difere, da produção o gate humano de hoje (no desligado a trava publica `success` e o `require-codeowner-approval`
  não é obrigatório no ruleset do modo ligado).

### `cockpit.config.example` (E1)

Linha `MODO_AUTONOMO='desligado'` com comentário: opcional, ausente ou inválida vale `desligado`;
o rito não lê esta chave, lê a linha da constituição.

### `templates/docs/constitution.md.semente.tmpl` (E1, D1, FR-002, FR-004)

- Linha literal `Merge autônomo: {{MODO_AUTONOMO}}`, sozinha na linha, no Princípio II.
- O Princípio II ganha os dois ramos, no padrão do III: **desligado** é o texto de hoje (nenhuma PR
  mergeada sem aprovação humana); **ligado** é CI verde, trava e smoke no lugar da leitura, com as
  condições de identidade e ruleset e o teto de correções.
- MUST NOT ao lado da linha de instalação: o agente não edita nenhuma das duas linhas nem a chave.

### `skills/rito-dev/SKILL.md` e `templates/docs/rito-dev.md.tmpl` (E2, D5 a D8, D11, FR-024)

- Seção nova "Modo autônomo", escrita uma vez, com o contrato
  [modo-autonomo.md](contracts/modo-autonomo.md): regra de leitura da linha (os dois `grep`,
  igual à linha "Instalação pelo agente"), modo efetivo, pré-condições, merge, correções,
  estacionamento, smoke, promoção e rollback.
- Fases 6 a 10: uma linha de ponteiro cada ("No modo ligado, ver Modo autônomo §…"). O texto atual
  das fases não muda (ramo desligado idêntico).
- `MODO_AUTONOMO` entra na lista de chaves que o rito não consome.
- O template não renderiza o valor (D1): cita a linha da constituição.

### `skills/rito-descoberta/SKILL.md` (E4, D3, D9, D10)

- Depois do Gate 0, lê o modo pela regra da `rito-dev` (citada, não copiada). No modo ligado, abre
  a PR de registro só com `docs/specs/<frente>/decisoes-do-owner.md` a partir de
  `origin/<BRANCH_INTEGRACAO>` e para até o merge do owner; aberta, avisa e retoma só por comando
  explícito; fechada sem merge, encerra a frente como não aprovada (Clarifications, Q3). No modo
  desligado, o fluxo de hoje.
- Barreira (D9): depois da verificação de plugins, roda `historico.mjs plugin` em cada plugin do
  mapa e mescla `deny` (união, idempotente) no `.claude/settings.json` da worktree, mais as negações
  de edição de `.claude/settings*.json` (R1, D-P1). Roda de novo no gate da Fase 11 e no estado
  "SHA divergente"; reprova se o arquivo não cobre o conjunto atual.
- Lista fechada (D10): a tabela "Conteúdo só de agentes" ganha `.in_use/`, `.orphaned_at` e o `.md`
  da raiz fora do array, com remissão ao subcomando como verificador.
- "Limite declarado (D14)" passa a apontar para a barreira técnica.

### `skills/rito-descoberta/historico.mjs` e `historico.test.mjs` (E6, D9, D10, FR-021, FR-022)

- Subcomando `plugin <installPath>` conforme [historico-plugin.md](contracts/historico-plugin.md).
  Reusa `instalados()`, `dentro()`, `norma()`, `falha()` e o leitor de JSON existentes; nenhum
  módulo novo.
- Teste: script Node que cria os fixtures num diretório temporário, roda o subcomando com `HOME`
  apontado para ele e confere exit e JSON (quickstart Scenario 5). Nada de symlink ou executável
  versionado.

### `.github/workflows/ci.yml` (E6, FR-025)

Job novo `historico`, no padrão dos demais (checkout fixado por SHA, `contents: read`): confere
`node --version` e roda `node skills/rito-descoberta/historico.test.mjs`.

### `templates/.github/workflows/caminhos-previstos.yml.tmpl` (E5, D4, FR-008 a FR-011)

Contrato em [caminhos-previstos.md](contracts/caminhos-previstos.md). Resumo: `pull_request_target`
filtrado nas branches de integração e de produção; sem checkout, só `gh api` e `jq`; lê a linha de
modo na integração e o registro na base; publica status no SHA do HEAD, com contexto
`caminhos-previstos` na integração e `caminhos-previstos-producao` na produção (D-P11); no modo
desligado publica sucesso "modo desligado" (D-P3). Na produção, passa sozinha só a PR de promoção
(cabeça = branch de integração do mesmo repositório); as demais caem na aprovação de dono (A1).
A lista de governança inclui a config do semantic-release (A2) e todo `decisoes-do-owner.md` (F1).

### `templates/.github/workflows/require-codeowner-approval.yml.tmpl` (D5, FR-013)

Lê a linha de modo na base (API, nunca a árvore do PR). No modo ligado, passa com aviso no resumo
do job; no desligado, o comportamento de hoje. A conclusão do job no modo ligado é sucesso, para
não cair no critério de vermelho do `audit-merge-vermelho`.

### `templates/.github/workflows/audit-merge-vermelho.yml.tmpl` (D5, FR-013)

Lê a linha de modo na base. No modo ligado, não abre issue por merge cujo único "vermelho" seja o
`require-codeowner-approval`; outro check vermelho num merge autônomo continua abrindo issue. A
execução confere o critério de vermelho atual do template antes de editar.

### `templates/.github/workflows/promotion-pr.yml.tmpl` (D8, FR-019)

Lê a linha de modo na base. No modo ligado, sem `TOKEN_AUTOMACAO` o job falha com mensagem e não
cria a PR com o `GITHUB_TOKEN`, porque evento criado por ele não dispara o CI (R6). No modo
desligado, o comportamento de hoje (segredo opcional).

### `templates/.github/CODEOWNERS.tmpl` (D4, D5)

A linha `* {{DONOS_CODEOWNERS}}` já cobre todos os caminhos de governança: nenhuma entrada nova
(seria redundante). Só o comentário do arquivo muda: no modo ligado, os donos daqui são os que a
trava aceita como "aprovação de dono no commit atual" (PR sem registro, de governança ou para a
produção que não é a de promoção; D4, A1), e a aprovação deixa de ser exigida nas PRs de frente
(D5).

### Ponteiros ao Princípio II (E2, D11, FR-024)

`templates/CLAUDE.md.semente.tmpl`, `templates/docs/agentes/implementador.md.tmpl`,
`templates/docs/agentes/revisor.md.tmpl`, `templates/docs/project-context.md.semente.tmpl` e
`templates/.cockpit/LEIAME.md.tmpl`: onde hoje dizem "merge só com aprovação humana", passam a
apontar para o Princípio II da constituição do projeto, sem repetir a regra.

### `scripts/testar-configurar.sh` (FR-025, quickstart Scenarios 1 e 2)

Casos novos: chave ausente, vazia, `Ligado`, `desligado`, `ligado` e `--atualizar` sem a chave;
contagem exata da linha na semente; o workflow novo passa no actionlint junto com os demais,
renderizado com integração ≠ produção e com integração = produção (filtro com o mesmo nome duas
vezes).

### `README.md` e `docs/specs/configurar/contracts/cli.md` (E7, FR-025)

README: seção curta do modo autônomo (o que liga, o que o owner configura no GitHub, o que fica
humano, que o cockpit não usa). Contrato do configurar: chave opcional, normalização, aviso e a
impressão da configuração do GitHub.

## Convenções de Borda

N/A no sentido de camadas de dados (não há DB nem DTO). As bordas são formatos de texto, cada um
com uma fonte da verdade:

| Borda | Formato | Fonte da verdade |
|---|---|---|
| configurador → semente | `Merge autônomo: ligado\|desligado`, linha inteira | `templates/docs/constitution.md.semente.tmpl` |
| base → rito e workflows | regra "1 e 1" dos dois `grep` | seção "Modo autônomo" da `rito-dev` |
| registro → trava | 1º bloco cercado após `## Caminhos previstos` | [data-model.md](data-model.md) §Registro |
| PR de correção → trava | linha `Origem: #<n>` no corpo | [caminhos-previstos.md](contracts/caminhos-previstos.md) |
| `historico.mjs plugin` → skill | uma linha JSON | [historico-plugin.md](contracts/historico-plugin.md) |
| skill → settings | `permissions.deny` em `.claude/settings.json` | research R1 |

## Riscos

| Risco | Mitigação |
|---|---|
| Regra deny de agente de plugin não bloquear: a forma `Agent(<plugin>:<agente>)` pode ser lida como regra de parâmetro (R1) | o subcomando emite as duas formas; o S4 prova qual bloqueia; nenhuma bloqueando, o rito para (D9) |
| Status publicado por `pull_request_target` não valer como check obrigatório no HEAD, ou a fonte esperada não fixar o GitHub Actions (R2, R13) | S3 prova; sem isso o modo não liga no repositório de teste e volta ao owner |
| Deny de Edit não cobre subprocesso (R1: "don't apply to … arbitrary subprocesses") | a barreira é sobre agentes; a trava reprova `.claude/**` no PR, e o ruleset é conferido na hora |
| Identidade sem Workflows não é verificável por API (sem fonte) | declarada pelo owner na configuração impressa; S3 prova push de workflow recusado; o agente para se o push de workflow passar |
| A identidade não enxerga `bypass_actors` (R3) | confere `current_user_can_bypass` = `never` e os checks; a lista vazia é instrução impressa e conferida pelo owner (D-P7) |
| `ubuntu-latest` migrando de imagem (R11) | jobs conferem `node`, `gh` e `jq` antes de usar; falha fechada |
| `gh pr revert` sem versão mínima confirmada (R7) | detecção pelo próprio comando; ausente, para e volta ao owner |
| Auto-merge não disparar `push`/`closed` como o merge manual (R5, não confirmado) | S3 confere a execução do CI de `push` e do audit depois do merge autônomo |
| Status `caminhos-previstos` forjado por outro workflow do projeto que roda código do PR com `statuses: write` (a fonte esperada não distingue workflows da mesma app, R16) | templates do cockpit já usam `contents: read` e `persist-credentials: false`; o configurador imprime a regra para os demais workflows e o padrão restrito do token; S3 inclui o caso |
| Modo desligado com o ruleset do modo ligado: nada exige aprovação | o configurador imprime que desligar inclui devolver o gate humano aos rulesets das duas branches (com A1, a trava publica "modo desligado" também na produção) |
| PR direta para a produção com arquivo de governança, mergeada com CI verde (gate owasp-security, F-PROD) | A1: a trava roda na PR para a produção e só a de promoção passa sozinha; ruleset da produção sem bypass com `caminhos-previstos-producao` obrigatório, conferido na P3 e na P4 |
| Status verde da integração valer na produção, porque o status fica no commit e o mesmo SHA pode ser HEAD das duas PRs (R2) | contexto próprio por base (D-P11) |
| Config do semantic-release vinda do repositório rodar com o `TOKEN_AUTOMACAO` (gate owasp-security, F2; R17) | A2: `.releaserc*`, `release.config.*` e a chave `release` do `package.json` são governança; token restrito de identidade não dona. Residual: arquivo local apontado por `extends` ("file paths", R17) não casa com a lista (a mudança da referência casa); o dano fica no escopo do token restrito |

## Re-check

Depois do Phase 1:

- Nenhum componente novo além dos 2 arquivos previstos (workflow-template e teste); nenhuma
  dependência; nenhum diretório novo.
- Princípio IV: a única escrita automática nova é a mescla de `deny` pela skill, feita pelo agente
  na worktree, não por script; o configurador continua só imprimindo.
- Princípio V: cada afirmação sobre GitHub ou Claude Code nos contratos aponta para um R da
  research; o não confirmado está marcado e tem falha fechada.
- Princípio I: o workflow-template recebe só placeholders; nenhum ID numérico de app ou de
  repositório é escrito (a fonte esperada é escolhida pelo owner, R13).
- Princípio II do cockpit: inalterado (FR-026).
- Resposta do block-001 (A1, A2, F1): só muda texto dos contratos e o desenho de arquivos já
  previstos (workflow-template da trava, `configurar.sh`); nenhum arquivo novo, e o `release.yml`
  fica como está.

Resultado: PASS, sem violação a justificar.

## Complexity Tracking

Vazio: nenhuma violação de constituição.

## Artefatos

| Arquivo | Status |
|---|---|
| docs/specs/modo-autonomo/plan.md | Criado |
| docs/specs/modo-autonomo/research.md | Criado |
| docs/specs/modo-autonomo/data-model.md | Criado |
| docs/specs/modo-autonomo/contracts/caminhos-previstos.md | Criado |
| docs/specs/modo-autonomo/contracts/historico-plugin.md | Criado |
| docs/specs/modo-autonomo/contracts/modo-autonomo.md | Criado |
| docs/specs/modo-autonomo/quickstart.md | Criado |

### Próximos passos

1. `/checklist`: quality gate dos requisitos.
2. `/create-tasks`: backlog por caminho previsto.
3. `/analyze`: consistência entre spec, plan e tasks.
