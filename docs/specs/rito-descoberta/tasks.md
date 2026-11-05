# Tarefas rito-descoberta - Fase 0 agnostica (skill, auxiliar, gates do rito-dev)

Escopo: construir a skill `rito-descoberta`, `historico.mjs`, os gates no `rito-dev`, a politica na semente de constituicao e o README, tocando somente os caminhos previstos. Nada e instalado na construcao. A emenda 2.0.0 do Principio IV (bf2eb06) e `decisoes-do-owner.md` nao sao editados.

**Legenda de status:**
- `[ ]` Pendente
- `[~]` Em andamento
- `[x]` Concluido
- `[!]` Bloqueado

**Legenda de criticidade:**
- `[C]` Critico - Impacto financeiro direto ou bloqueante
- `[A]` Alto - Funcionalidade essencial
- `[M]` Medio - Necessario mas sem urgencia imediata

---

## FASE 1 - Fundacao e requisitos (gaps do checklist)

### 1.1 Fechar CHK010: definir "ruido conhecido" do fingerprint `[A]`

Ref: checklists/requirements.md CHK010; spec Edge Cases, FR-014

- [x] 1.1.1 Acrescentar a `contracts/historico.md` a lista fechada de ruido conhecido (sincronizacao de `skills/synced`, atualizacao automatica de `known_marketplaces.json` do marketplace oficial, arquivos `-shm`/`-wal` do SQLite) e a regra "qualquer outro e desvio"
- [x] 1.1.2 Acrescentar ao FR-014 de `spec.md` a remissao a essa lista, sem tocar em `decisoes-do-owner.md`
- [x] 1.1.3 Conferir por `grep` que a lista aparece igual em `plan.md` (secao Linha de base) e em `contracts/historico.md`
- [x] 1.1.4 Marcar CHK010 `[x]` em `checklists/requirements.md` citando o contrato

### 1.2 Fechar CHK017: chave de correspondencia install/uninstall do SC-005 `[A]`

Ref: checklists/requirements.md CHK017; spec SC-005, FR-016

- [x] 1.2.1 Declarar em `spec.md` (SC-005) que a chave de correspondencia e a tripla `id`, `escopo`, `projeto` do log, no mesmo texto de `contracts/historico.md` (`pendentes`)
- [x] 1.2.2 Registrar o caso de uninstall sem install previo (ignorado) e de install repetido (um uninstall fecha o ultimo) em `contracts/historico.md`
- [x] 1.2.3 Marcar CHK017 `[x]` em `checklists/requirements.md`

### 1.3 Fechar CHK020: requisito de sessao interrompida na Fase 0 `[A]`

Ref: checklists/requirements.md CHK020; spec FR-014

- [x] 1.3.1 Acrescentar requisito (novo FR-022) em `spec.md`: ao retomar, a skill le o `.log`/`.base` da frente, tira nova foto, a diferenca vira evento `rodada` ou `desvio`, e a linha de base existente nunca e recriada
- [x] 1.3.2 Descrever o passo de retomada em `contracts/historico.md` e como cenario no `quickstart.md`
- [x] 1.3.3 Atualizar a contagem de requisitos citada em CHK016 de `checklists/requirements.md`
- [x] 1.3.4 Marcar CHK020 `[x]` em `checklists/requirements.md`

### 1.4 Registrar as respostas do owner a CHK021 e CHK022 `[M]`

Ref: decisoes-do-owner.md D18 e D10 (somente leitura); checklists/requirements.md

- [x] 1.4.1 Marcar CHK021 `[x]` em `checklists/requirements.md` citando D18 ("Temporarias globais rodam uma por vez entre frentes paralelas")
- [x] 1.4.2 Marcar CHK022 `[x]` em `checklists/requirements.md` citando D10 (gate dispensado em docs, trivial e hotfix com incidente)
- [x] 1.4.3 Atualizar a linha Notes do checklist para refletir que nao restam gaps nem itens `{humano}` abertos
- [x] 1.4.4 Conferir por `git diff --stat` que `decisoes-do-owner.md` nao foi alterado

---

## FASE 2 - Auxiliar historico.mjs

### 2.1 Implementar `foto` e `pendentes` em `skills/rito-descoberta/historico.mjs` `[C]`

Ref: contracts/historico.md; plan.md; FR-014, FR-016, FR-020

- [x] 2.1.1 Criar o `.mjs` (Node ESM, so biblioteca padrao, `git` por `execFileSync` com argumentos em array)
- [x] 2.1.2 Implementar `foto [--raiz <dir>]`: tipos `meta`, `hash`, `plugin`, `enabled`, `marketplace`, `catalogo`, `git`, ordenacao byte a byte, nunca imprimir conteudo de arquivo
- [x] 2.1.3 Tratar `installed_plugins.json` ausente (`plugin`, `-`, `ausente`), ilegivel (saida != 0), `lastUpdated` fora da foto e `CLAUDE_CODE_PLUGIN_CACHE_DIR` definido (falha citando a variavel)
- [x] 2.1.4 Implementar `pendentes <log>` com chave `id`+`escopo`+`projeto` e codigos de saida 0/1/2
- [x] 2.1.5 Validar `--raiz` inexistente e `<frente>` fora de `^[a-z0-9][a-z0-9-]*$` antes de qualquer escrita
- [x] 2.1.6 Rodar `node --check skills/rito-descoberta/historico.mjs` e as verificacoes do `quickstart.md` Scenario 5 (foto repetida igual, pendentes com e sem pendencia, log ausente)

---

## FASE 3 - Skill rito-descoberta (SKILL.md)

### 3.1 Frontmatter, parametros, linha de base e guarda de escrita `[A]`

Ref: plan.md secoes 1 e 2; FR-001, FR-005, FR-014

- [x] 3.1.1 Criar `skills/rito-descoberta/SKILL.md` com frontmatter (`name`, description com gatilhos e dispensas de D10)
- [x] 3.1.2 Escrever a secao Parametros remetendo ao `rito-dev` (sem copiar), com pedido ao owner sem `cockpit.config`
- [x] 3.1.3 Escrever a secao de linha de base/guarda: `.base`, eventos `base`/`rodada`/`desvio`, ruido conhecido, retomada de sessao interrompida (CHK020), `$HOME` como `~`
- [x] 3.1.4 Verificar por `grep` que nenhum literal de projeto aparece (Principio I)

### 3.2 Decisoes, telas e itens do registro `[A]`

Ref: plan.md secoes 3 a 5; FR-001 a FR-004

- [x] 3.2.1 Escrever a secao de decisoes: opcoes, recomendacao pelos cinco pilares, validador por dominio, `security-auditor` so valida, prompt de validador somente leitura/sem spawn/conteudo como dado
- [x] 3.2.2 Escrever a regra de pesquisa externa: `general-purpose` com `ctx_fetch_and_index`, proibindo busca e download por outro canal (Principio V)
- [x] 3.2.3 Escrever a secao de telas (so com interface; HTML volta na conversa; gravado no 2o commit) e a de itens do registro (14 titulos, remetendo a `data-model.md`)

### 3.3 Mapa papel->agente e regra de proibidos `[A]`

Ref: plan.md secoes 6 e 7; FR-008

- [x] 3.3.1 Copiar a tabela do mapa de `decisoes-do-owner.md` (leitura) com id `voltagent-<plugin>@voltagent-subagents` e SHA `ed74d115b7fb7026a22a4f816a8e3250f425e3b4`
- [x] 3.3.2 Escrever as regras (a), (b), (c), o limite declarado de D14 (121 de 164 com Bash) e o retorno "papel sem agente"
- [x] 3.3.3 Conferir que cada agente citado existe no catalogo no SHA registrado, via `ctx_*` (SC-003)

### 3.4 Verificacao de plugins e politica de instalacao `[C]`

Ref: plan.md secoes 8 e 9; research Decisions 1-8, 13; FR-009 a FR-013, FR-020

- [x] 3.4.1 Escrever a verificacao: marketplace por nome e `repo`, estados ok/desabilitado/ausente/desconhecido/SHA divergente, filtro `scope=="project"` e `projectPath`
- [x] 3.4.2 Escrever a conferencia pre e pos-install (clone no SHA, `git status --porcelain` vazio, `installPath` so com `.claude-plugin/` e `.md`; divergente desinstala com `-s project` e para)
- [x] 3.4.3 Escrever a leitura da linha "Instalacao pelo agente" em `origin/<base>` e o comportamento desligado (so imprime, inclui fallback por copia de D8 apenas impresso)
- [x] 3.4.4 Escrever canais e proibidos de D17 (flags, `update`, script remoto, executores sob demanda) e ciclo de vida de D18 (log de install/uninstall, classe da lista do Gate 0)
- [x] 3.4.5 Escrever a regra de desvio: item fora da lista, flag diferente ou mudanca de classe para e pede OK; comando executado byte a byte igual ao registro
- [x] 3.4.6 Marcar como pendencia, sem afirmar, todo dado nao verificado (`gitCommitSha`, `projectPath` em worktree, sobra de cache, `skip-build`)

### 3.5 Gate 0, gravacao e entrega `[A]`

Ref: plan.md secoes 10 a 12; FR-004, FR-006, FR-007; contracts/decisoes-do-owner.md

- [x] 3.5.1 Escrever o Gate 0 (apresentacao completa, OK para todas as ondas, evento `gate0` literal, nada escrito alem do log)
- [x] 3.5.2 Escrever o pos-OK: worktree por `/parallel-work` com base explicita, gravacao do registro com `Historico`, validacao do contrato (6 checagens) antes do commit, commit so do arquivo, `cstk hooks install`/`cstk mcp install --project-path`
- [x] 3.5.3 Escrever o bloco unico copiavel `cd <worktree> && claude` + `/feature-00c` com descricao de ate 500 caracteres e a recopia do historico antes da PR
- [x] 3.5.4 Rodar as checagens de `contracts/decisoes-do-owner.md` sobre o proprio `decisoes-do-owner.md` desta frente como teste de referencia (quickstart Scenario 1)

---

## FASE 4 - Gates no rito-dev (skill e template)

### 4.1 Alterar `skills/rito-dev/SKILL.md` `[A]`

Ref: plan.md; FR-015, FR-016

- [x] 4.1.1 Ajustar a description: frente nova de trilha completa comeca por `/rito-descoberta`; rito segue da Fase 1 com Gate 0 dado
- [x] 4.1.2 Acrescentar na Fase 1 o gate da Fase 0 (trilha completa; sem a skill instalada para com `rito-descoberta ausente: rode instalar.sh`; sem registro na branch conduz a `/rito-descoberta`; docs, trivial e hotfix com incidente dispensados)
- [x] 4.1.3 Acrescentar na Fase 11, antes de "Encerrar", o gate de temporarias (`historico.mjs pendentes`, foto igual a base, falha fechado sem `.log`/`.base`)
- [x] 4.1.4 Conferir por `grep` os textos literais exigidos (quickstart Scenario 4)

### 4.2 Alterar `templates/docs/rito-dev.md.tmpl` `[A]`

Ref: research Decision 10; FR-015, FR-016

- [x] 4.2.1 Acrescentar as duas regras em prosa curta dentro de `## Fase 1` e `## Fase 11`, remetendo a skill `rito-descoberta` para o comando
- [x] 4.2.2 Garantir zero placeholder novo e zero titulo novo no template
- [x] 4.2.3 Rodar `scripts/testar-configurar.sh` em primeiro plano, com timeout, sem laco em background, e conferir o cenario 15

---

## FASE 5 - Semente de constituicao e README

### 5.1 Politica no IV de `templates/docs/constitution.md.semente.tmpl` `[A]`

Ref: plan.md; FR-018; docs/constitution.md 2.0.0 (somente referencia)

- [x] 5.1.1 Acrescentar no `### IV.` a regra de que script nunca instala e os MUST do agente, espelhando a redacao do IV 2.0.0 sem reescrever a emenda
- [x] 5.1.2 Acrescentar a linha literal `Instalação pelo agente: desligada`, sozinha em uma linha, e a regra de que o agente nunca a edita
- [x] 5.1.3 Rodar `scripts/testar-configurar.sh` (cenarios 15 e 17) e conferir a linha por `grep -cFx`

### 5.2 README comeca o fluxo por `/rito-descoberta` `[M]`

Ref: plan.md; FR-017

- [x] 5.2.1 Alterar o diagrama do fluxo: `/rito-descoberta` (Fase 0, Gate 0) antes de `/parallel-work`
- [x] 5.2.2 Acrescentar uma frase sobre a dispensa em docs, trivial e hotfix com incidente
- [x] 5.2.3 Conferir por `grep` e por `validate-docs-rendered` que o diagrama renderiza

---

## FASE 6 - Verificacoes de construcao e PR

### 6.1 Verificacoes automatizaveis (sem instalar nada) `[A]`

Ref: quickstart.md Scenarios 1-7; FR-019, FR-021, SC-001, SC-002, SC-007

- [x] 6.1.1 Rodar `scripts/verificar-agnostico.sh` e conferir que passa (o CI usa lista mais ampla: juiz final)
- [x] 6.1.2 Conferir que o diff contra a base so tem caminhos previstos (SC-007) e que `decisoes-do-owner.md` e `docs/constitution.md` nao mudaram nesta construcao
- [x] 6.1.3 Conferir que nenhum processo em background ficou da worktree e que nada foi instalado (`~/.claude/skills/rito-descoberta` ausente)
- [ ] 6.1.4 Rodar `bmad-code-review` ate zerar achados alto/critico e declarar a trilha no corpo da PR (delegada a sessao pai, antes da PR)

---

## FASE 7 - Pos-merge documental (smoke S1-S5)

### 7.1 Roteiro dos smokes S1-S5 (executado depois do merge, fora da construcao) `[M]`

Ref: quickstart.md Scenarios 8-11; decisoes-do-owner.md Smoke

- [x] 7.1.1 Conferir que `quickstart.md` Scenarios 8 a 11 cobrem S1 a S5, com criterio de passagem e caso negativo
- [x] 7.1.2 Registrar em `quickstart.md` que S1 a S5 so rodam apos o merge, com instalacao pelo owner, e que o agente nao os executa na construcao
- [x] 7.1.3 Registrar o achado de R1 (install atualiza o catalogo) como ponto a levar ao owner antes do S3 (quickstart.md, Scenario 10 "Risco conhecido"; research.md Decision 4)

---

## Matriz de Dependencias

```mermaid
flowchart TD
    F1[Fase 1 - Fundacao e requisitos (gaps do checklist)]
    F2[Fase 2 - Auxiliar historico.mjs]
    F3[Fase 3 - Skill rito-descoberta (SKILL.md)]
    F4[Fase 4 - Gates no rito-dev (skill e template)]
    F5[Fase 5 - Semente de constituicao e README]
    F6[Fase 6 - Verificacoes de construcao e PR]
    F7[Fase 7 - Pos-merge documental (smoke S1-S5)]

    F1 --> F2
    F1 --> F3
    F2 --> F3
    F3 --> F4
    F3 --> F5
    F4 --> F6
    F5 --> F6
    F6 --> F7
```

## Resumo Quantitativo

| Fase | Tarefas | Subtarefas | Criticidade |
|------|---------|------------|-------------|
| 1 - Fundacao e requisitos (gaps do checklist) | 4 | 15 | A/M |
| 2 - Auxiliar historico.mjs | 1 | 6 | C |
| 3 - Skill rito-descoberta (SKILL.md) | 5 | 20 | C/A |
| 4 - Gates no rito-dev (skill e template) | 2 | 7 | A |
| 5 - Semente de constituicao e README | 2 | 6 | A/M |
| 6 - Verificacoes de construcao e PR | 1 | 4 | A |
| 7 - Pos-merge documental (smoke S1-S5) | 1 | 3 | M |
| **Total** | **16** | **61** | - |

## Escopo Coberto

| Item | Descricao | Fase |
|------|-----------|------|
| FR-014, FR-022, CHK010, CHK017, CHK020 | Historico, ruido conhecido, chave install/uninstall, retomada | 1, 2, 3 |
| CHK021, CHK022 | Respostas do owner (D18, D10) marcadas no checklist | 1 |
| FR-001 a FR-013, FR-020 | Skill `rito-descoberta` | 3 |
| FR-015, FR-016 | Gates do `rito-dev` | 4 |
| FR-017, FR-018 | README e semente | 5 |
| FR-019, FR-021, SC-007 | Caminhos tocaveis, registro SDD, verificacoes | 6 |
| S1-S5 | Roteiro pos-merge (somente documental) | 7 |

Tier de entrega usado na geracao deste backlog: nao informado nos args (backlog completo).

## Escopo Excluido

| Item | Descricao | Motivo |
|------|-----------|--------|
| EX-1 | Reescrita da emenda 2.0.0 do Principio IV | Ja commitada em bf2eb06 (E7) |
| EX-2 | Edicao de `decisoes-do-owner.md` | Normativo, 1o commit da branch |
| EX-3 | Execucao de S1-S5 e qualquer install/enable | Vigencia: agente nao instala na construcao |
| EX-4 | Alterar `instalar.sh` e `configurar.sh` | Fora dos caminhos tocaveis; ja copiam `skills/*/` |
| EX-5 | Barreira tecnica de proibidos | Fica com a frente `modo-autonomo` (D14) |


---

## FASE 8 - Convergência

> Fase gerada automaticamente pela skill `converge` (reconciliação
> spec-vs-código). Cada tarefa abaixo corresponde a um achado (`Gap`)
> entre o que `spec.md`/`plan.md`/`tasks.md` descreveram e o estado
> presente do código. Tarefas sem o prefixo `[Revisar]` são acionáveis
> (`missing`/`partial`/`contradicts`); tarefas com `[Revisar]` são item de
> revisão (`unrequested`, FR-013) — nunca "implementar", o código já
> existe. Append-only: esta fase nunca reescreve fases/tarefas anteriores
> do arquivo (FR-009).

### 8.1 Skill autocontida: as 6 checagens do registro `[C]`

Ref: 3.5 (3.5.2; FR-006, FR-007, US1) · tipo: `partial` · severidade: `HIGH`

`skills/rito-descoberta/SKILL.md` (seção "Itens do registro" e passo 3 de "Depois do OK") manda
validar o registro pelo contrato `docs/specs/rito-descoberta/contracts/decisoes-do-owner.md` e cita
`docs/specs/rito-descoberta/data-model.md`. Esses arquivos só existem no repositório do cockpit.
Instalada em `~/.claude/skills/` e usada num projeto-alvo, a skill fica sem as regras (regex dos
caminhos, cabeçalho exato de "Instalações previstas", formas de comando permitidas, conferência do
1º commit), e a validação que falha fechado (FR-007, cenário 4 da US1) não tem como rodar.

- [ ] 8.1.1 Trazer para `skills/rito-descoberta/` as 6 checagens de `contracts/decisoes-do-owner.md` (no `SKILL.md` ou em arquivo ao lado, citado por caminho relativo à skill), sem depender de `docs/specs/rito-descoberta/`
- [ ] 8.1.2 Conferir por `grep` que nenhum caminho `docs/specs/rito-descoberta/` resta no `SKILL.md` como fonte normativa

<!-- converge-key: e37d18f29eb7 -->

### 8.2 Skill autocontida: formato do log do histórico `[C]`

Ref: 3.1 (3.1.3; FR-005, FR-014, US1) · tipo: `partial` · severidade: `HIGH`

`skills/rito-descoberta/SKILL.md` (seção "Linha de base e guarda de escrita") remete o formato do
log e da foto a `docs/specs/rito-descoberta/contracts/historico.md`, que não existe no
projeto-alvo. O `pendentes` de `skills/rito-descoberta/historico.mjs` lê `install` e `uninstall`
pelas colunas TAB 5 a 9 (id, escopo, projeto, versão ou SHA, classe). Se o detalhe for gravado com
outro separador, o install temporário não entra na conta e o gate da Fase 11 passa sem a
desinstalação.

- [ ] 8.2.1 Trazer para a skill o formato do log: 6 campos TAB; detalhe de `install`/`uninstall` em campos TAB na ordem que `pendentes` lê; linhas de continuação da `rodada` começando por TAB; eventos `base`, `rodada`, `desvio`, `gate0`
- [ ] 8.2.2 Conferir, com um log de exemplo no diretório temporário da sessão, que `historico.mjs pendentes` termina com 1 para install temporário aberto e com 0 depois do uninstall

<!-- converge-key: 79f07982eda4 -->

### 8.3 Comandos do gate da Fase 11 na skill indicada pelo template `[A]`

Ref: 4.2 (4.2.1; FR-016, US4) · tipo: `partial` · severidade: `MEDIUM`

`templates/docs/rito-dev.md.tmpl` (`## Fase 11 — Encerramento`) remete à skill `rito-descoberta`
para os comandos do gate de instalações temporárias. Só que `skills/rito-descoberta/SKILL.md` não
traz `historico.mjs pendentes` nem a comparação da foto com a `.base`: hoje esses comandos estão
apenas na Fase 11 de `skills/rito-dev/SKILL.md`.

- [ ] 8.3.1 Acrescentar a `skills/rito-descoberta/SKILL.md` os dois comandos do gate da Fase 11 e a regra de falha fechado sem `.log` ou `.base`, mantendo a remissão do template (plan.md) sem placeholder nem título novo
- [ ] 8.3.2 Rodar `scripts/testar-configurar.sh` em primeiro plano, com timeout, e conferir o cenário 15

<!-- converge-key: ef4fd96af3e4 -->

### 8.4 Semente: o IV contradiz a política do agente quando ligada `[A]`

Ref: 5.1 (5.1.1; FR-018, US5) · tipo: `contradicts` · severidade: `MEDIUM`

Em `templates/docs/constitution.md.semente.tmpl`, o MUST que já existia ("Ferramentas externas MUST
ser instaladas e atualizadas pela pessoa") ficou sem ressalva e contradiz os MUST do agente quando a
linha diz `ligada`. O espelho do IV 2.0.0 também deixou de fora o MUST de canais (plugin no escopo
do projeto, marketplace conferido por nome e repositório, SHA conferido e desinstalação quando
diverge; pacote com versão exata e sem scripts de ciclo de vida, salvo exceção listada) e o "dentro
da worktree e antes da remoção dela" da temporária.

- [ ] 8.4.1 Ressalvar o MUST que já existia para a instalação pelo agente sob a política ligada, sem nomear ferramenta de projeto real (Princípio I)
- [ ] 8.4.2 Acrescentar o MUST de canais e o "dentro da worktree e antes da remoção dela", espelhando o IV 2.0.0 de `docs/constitution.md`
- [ ] 8.4.3 Rodar `scripts/testar-configurar.sh` (cenários 15 e 17) e conferir que `grep -cFx 'Instalação pelo agente: desligada'` na semente dá 1

<!-- converge-key: ce9451eaac36 -->
