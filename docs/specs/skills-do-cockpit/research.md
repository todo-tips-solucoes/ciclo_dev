# Research: Skills do cockpit + alinhamento do briefing

Documento produzido no Phase 0 do `/plan`. Resolve o mapeamento fino que o
clarify (Q3, dec-012/dec-015) deferiu explicitamente para esta fase — não há
`NEEDS CLARIFICATION` estrutural pendente no Technical Context (linguagem,
stack, arquitetura, persistência e ambiente-alvo já estão fixados pelo
briefing/constitution deste repositório, herdados de `esqueleto-e-instalador`).

## Decision 1: Fonte-base do conteúdo de `rito-dev` e correspondência de fases

**Decision**: o conteúdo da skill `rito-dev` é derivado da seção "## Fases" de
`~/.claude/skills/rito-dev-nav/SKILL.md` (MEDIDO — arquivo lido integralmente
nesta onda), mapeando 1:1 Fase 1 (Branch) → Fase 11 (Encerramento) da fonte
para as 11 fases numeradas da skill nova. A Fase 0 (Sincronizar) da fonte é
preservada como etapa preparatória **não numerada** dentro das 11 (dec-011),
citada no início do documento como pré-requisito de toda fase 1.

**Rationale**: resposta do owner ao block-001 (dec-013) fixou a fonte; dec-011
(score 3) resolveu a divergência de contagem (12 seções vs "11 fases" do
briefing) sem exigir emenda do briefing. Descartar a Fase 0 do conteúdo da
skill seria perda de fidelidade ao ciclo (prioridade 2 do briefing, §4): a
fonte documenta um incidente real de trabalhar sobre base desatualizada.

**Alternatives considered**: (a) definir as 11 fases do zero, ignorando a
fonte candidata — rejeitada pelo owner (dec-013 escolheu a opção A); (b)
incluir a Fase 0 como uma das 11, forçando o briefing a "12 fases" — rejeitada
por dec-011 (o briefing já ratificado fixa 11, e a Fase 0 é preparatória, não
uma fase do rito em si).

## Decision 2: Esquema mínimo de `cockpit.config` — chaves e formato de arquivo

**Decision**: `cockpit.config` usa o mesmo formato já estabelecido em
`versoes.env` neste repositório — `CHAVE=valor`, uma por linha, linhas
iniciadas por `#` são comentário, sem aninhamento. As 10 chaves mínimas do
FR-005 mapeiam assim:

| Chave | FR-005 (mínimo) |
|---|---|
| `PROJETO_NOME` | nome do projeto |
| `REPO_REMOTO` | identificador do repositório remoto (`org/repo`) |
| `BRANCH_INTEGRACAO` | branch de integração |
| `BRANCH_PRODUCAO` | branch de produção (pode repetir `BRANCH_INTEGRACAO` — Princípio I do cockpit) |
| `GERENCIADOR_PACOTES` | gerenciador de pacotes |
| `CMD_TYPECHECK` | comando de qualidade (typecheck) |
| `CMD_LINT` | comando de qualidade (lint) |
| `CMD_BUILD` | comando de qualidade (build) |
| `CMD_DEPLOY_INTEGRACAO` | comando de deploy — ambiente de integração |
| `CMD_DEPLOY_PRODUCAO` | comando de deploy — ambiente de produção (pode repetir o de integração) |

**Rationale**: reusar o formato de `versoes.env` evita introduzir um parser
novo (nenhuma dependência acrescentada — briefing §6, "Skills e templates:
... sem engine"); `rito-dev` lê o arquivo com `source`/`grep` em bash puro, o
mesmo mecanismo que `instalar.sh` já usa para `versoes.env`. É também o
formato mais simples que atende ao Princípio VII (scripts portáveis) sem
exigir `jq`/YAML parser para um shell script.

**Alternatives considered**: (a) YAML — mais expressivo para aninhamento, mas
exige parser (`yq` não é pré-requisito fechado do Princípio VII) — rejeitada;
(b) JSON — mesma objeção, mais verboso para edição manual (o público-alvo
ainda preenche à mão, User Story 1); (c) `.env` com aninhamento via prefixo
(`AMBIENTE_STAGING_URL`) — adotado parcialmente na Decision 3 abaixo, sem
introduzir uma sintaxe de aninhamento real.

## Decision 3: Extensão do conjunto mínimo — duas chaves opcionais para smoke test

**Decision**: além das 10 chaves mínimas (Decision 2), `cockpit.config` aceita
duas chaves **opcionais**: `URL_AMBIENTE_INTEGRACAO` e `URL_AMBIENTE_PRODUCAO`
— usadas pela Fase 8 (Smoke no ambiente de integração) e Fase 10 (Smoke em
produção) da skill `rito-dev`. Quando ausentes, a skill pergunta a URL ao dev
uma vez, na hora (mesmo padrão que a fonte já usa para dados não
parametrizáveis), sem bloquear a fase.

**Rationale**: Q3 (dec-012) autorizou o `/plan` a mapear chaves adicionais
além do mínimo do FR-005 ("no mínimo" é extensível por natureza). As duas
chaves de URL emparelham diretamente com `CMD_DEPLOY_INTEGRACAO`/
`CMD_DEPLOY_PRODUCAO`, que já são obrigatórias — o mesmo par
ambiente/ação que already exists no esquema mínimo, sem introduzir um
conceito novo.

**Alternatives considered**: (a) tornar as URLs obrigatórias — rejeitada,
pois nem todo projeto-alvo tem URL pública fixa por ambiente (ex: mobile,
CLI) e isso quebraria a User Story 1 para esses casos; (b) não ter URL
alguma no config e sempre perguntar — aceito como fallback, mas ter a chave
opcional evita repetir a pergunta a cada execução do rito no mesmo projeto.

## Decision 4: Identidade de revisor/aprovador — fora do escopo desta feature

**Decision**: `cockpit.config` **não** ganha chave de identidade de revisor
(GitHub handle do reviewer dev-time, do owner/CODEOWNER). Quando a skill
`rito-dev` chega à Fase 6 (Review) ou Fase 9 (Promoção), ela pergunta ao
dev/owner quem é o responsável pela aprovação daquela PR, em vez de ler de
config.

**Rationale**: o briefing (item 2 do MVP) já reserva "tabela de identidades"
como responsabilidade do `configurar.sh` — uma feature futura, ainda não
aberta. Introduzir uma chave de identidade parcial aqui duplicaria/anteciparia
esse desenho antes de ele existir (risco de conflito de schema quando
`configurar.sh` for especificado). Mantém `cockpit.config` restrito ao que
FR-005 e a Decision 3 já justificam.

**Alternatives considered**: adicionar `REVIEWER_DEV`/`OWNER_HANDLE` agora —
rejeitada por escopo (YAGNI: nenhuma user story desta feature depende disso;
a fonte já resolve isso perguntando/checando `gh pr view --json reviewRequests`
quando necessário, sem exigir estado persistido).

## Decision 5: Adaptação de referências de CI específicas do projeto de origem (nomes de workflow)

**Decision**: a Fase 8 (Smoke no ambiente de integração) e a Fase 9
(Promoção) da fonte citam nome de arquivo de workflow e número de execução
reais do projeto de origem (redigidos aqui — nunca versionados neste
repositório; ver dec-029/block-002). A
skill `rito-dev` **não** reproduz esses literais — descreve o comportamento
de forma agnóstica ("confira o workflow de deploy do ambiente de integração
mais recente via `gh run list` filtrando pela branch de integração", "se o
projeto usa um radar de promoção automático, confira `gh pr list --base
<branch-produção> --head <branch-integração>`; senão, abra a PR de promoção
manualmente"), condicionando o passo à presença do artefato (workflow/PR
draft) em vez de assumir que ele existe.

**Rationale**: FR-003/FR-009 proíbem literal específico de projeto; um nome
de workflow é tão específico quanto um nome de organização. Descrever o
comportamento (o quê) em vez do artefato exato (nome do arquivo `.yml`)
mantém a fidelidade ao ciclo sem reintroduzir acoplamento.

**Alternatives considered**: acrescentar chaves `WORKFLOW_DEPLOY_NOME` /
`WORKFLOW_PROMOCAO_NOME` ao config — rejeitada por escopo (mesma lógica da
Decision 4: nenhuma user story exige nomear o workflow; `gh run list`
filtrado por branch/evento já resolve sem chave nova).

## Decision 6: Gates invioláveis específicos de infraestrutura do projeto de origem ficam de fora

**Decision**: os itens do "Gates invioláveis" da fonte que citam
infraestrutura real (ex: identificador do projeto de produção no provedor de backend) **não** são
copiados para `rito-dev` — o clarify (dec-013/dec-015) restringiu a fonte-base
à seção "## Fases", não a "Gates invioláveis" inteira. Gates genéricos que já
aparecem DENTRO das próprias seções de fase (nunca `git add -A`, nunca
validar com ambiente local, deploy de prod sempre com rollback anotado antes)
são preservados por já estarem redigidos de forma agnóstica dentro das
seções de fase correspondentes (Fase 2, Fase 3, Fase 10).

**Rationale**: consistente com o próprio recorte que dec-010/dec-013
resolveram (a pergunta era sobre "## Fases", especificamente). Itens de
infraestrutura de um provedor específico (identificador de projeto) são o tipo
exato de literal que FR-003/FR-009 proíbem, e não têm equivalente de
propósito geral em `cockpit.config`.

**Alternatives considered**: copiar os gates invioláveis inteiros e
parametrizar o project ref como nova chave — rejeitada por escopo: nenhuma
user story pede verificação de infraestrutura de banco de dados; a
constitution do cockpit não assume nenhum provedor de backend como dependência de nenhum
projeto-alvo.

## Decision 7: `bmad-code-review` é cópia literal, sem adaptação de conteúdo

**Decision**: `skills/bmad-code-review/` é `cp -r` de
`~/.claude/skills/bmad-code-review/` (SKILL.md + `customize.toml` +
`steps/*.md`), sem qualquer edição de texto.

**Rationale**: FR-007 exige reproduzir o comportamento da skill de origem
"sem mudança de comportamento". Auditoria desta onda (grep por termos de
projetos reais nos 5 arquivos da skill instalada) não encontrou nenhuma
citação de projeto/organização real — a skill já é agnóstica por construção
(usa `{project-root}` como token, nunca um path fixo). Não há, portanto,
adaptação a fazer, apenas cópia + registro de proveniência (FR-008).

**Alternatives considered**: reescrever a skill para "cockpitizar" a
prosa — rejeitada, violaria o próprio FR-007 (mudança de comportamento) sem
nenhum ganho, já que a fonte já está em conformidade com FR-009.

## Decision 8: Proveniência e licença de `bmad-code-review` (FR-008)

**Decision**: `THIRD-PARTY-NOTICES.md` registra a cópia da skill
`bmad-code-review` com atribuição ao projeto de origem **BMAD-METHOD**
(repositório oficial `bmad-code-org/BMAD-METHOD`,
<https://github.com/bmad-code-org/BMAD-METHOD>), licença **MIT** com aviso de
marca registrada adicional, texto integral a ser copiado verbatim do arquivo
oficial (FONTE OFICIAL, consultada nesta onda via fetch da URL raw
`https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/LICENSE`):
copyright `(c) 2025 BMad Code, LLC`, cláusula MIT padrão, mais nota de
contribuidores (`CONTRIBUTORS.md`) e nota de marca registrada (`TRADEMARK.md`)
— ambas referenciadas dentro do próprio arquivo de licença oficial, sem texto
adicional além do reproduzido.

**Rationale**: Princípio V da constitution deste repositório exige fonte
oficial citada com link para toda afirmação sobre projeto/ferramenta externa;
FR-008 exige a licença "reproduzida na íntegra". A verificação desta onda
buscou o arquivo LICENSE diretamente na raiz do repositório oficial — a única
fonte de verdade para o texto legal exato.

**Confirmação por `context-mode` (Princípio V — ferramenta `ctx_*`, nunca
WebFetch/curl/wget)**: o texto acima foi re-confirmado nesta mesma onda via
`ctx_fetch_and_index` sobre a mesma URL raw, byte a byte idêntico ao
reportado antes (que havia usado `WebFetch`, fora do canal exigido pela
constitution). A citação FONTE OFICIAL desta Decision passa a se apoiar na
chamada `ctx_fetch_and_index`, não na consulta anterior.

**Nota de execução (para `/create-tasks`/`/execute-task`)**: ao escrever
`THIRD-PARTY-NOTICES.md`, o texto do LICENSE MUST ser colado verbatim (sem
paráfrase) — inclusive a nota de marca registrada, que não é boilerplate MIT
padrão e por isso não pode ser gerada de memória; deve ser conferida contra a
fonte oficial no momento da escrita do arquivo, não copiada de memória desta
onda.

**Alternatives considered**: citar só o boilerplate MIT genérico sem a nota
de marca registrada — rejeitada, violaria "licença reproduzida na íntegra"
(FR-008), já que o arquivo oficial real contém a cláusula extra.

## Decision 9: `parallel-work` é cópia quase literal, com uma ressalva documentada (não corrigida nesta fase)

**Decision**: `skills/parallel-work/` é cópia de
`~/.claude/skills/parallel-work/` (SKILL.md + `driver.mjs`). Auditoria desta
onda (grep por termos reais) não encontrou nome de projeto/organização real —
FR-002/FR-009 já são satisfeitos pela fonte tal como está. Uma referência
interna de manutenção (`docs/skills/instalar.sh`, `docs/skills/CICLO-GIT.md`)
descreve a convenção de reinstalação do projeto de **origem** da skill (nav),
que não corresponde ao layout deste cockpit (`instalar.sh` na raiz,
`scripts/` para ferramental — Princípio II). Fica registrado como Edge Case
de conteúdo a resolver em `/create-tasks`: ajustar essas duas referências
para os paths reais deste cockpit ao copiar o arquivo (não é violação de
agnosticismo — é uma referência à própria skill, não a um projeto-alvo —
mas ficaria factualmente incorreta se copiada sem ajuste).

**Rationale**: distinguir "literal de projeto-alvo real" (proibido por FR-009)
de "referência de manutenção da própria skill que aponta para o path errado"
(bug de cópia, não violação de princípio) evita tratar os dois problemas com
a mesma solução. A correção é factual/textual, não uma decisão de design —
cabe à tarefa de cópia em `/create-tasks`, não a este plano.

**Alternatives considered**: deixar como está (o texto ficaria descrevendo um
caminho que não existe neste repositório) — rejeitada, gera confusão para
quem ler a skill copiada; reescrever o driver `.mjs` — fora de escopo, o
driver não contém a referência textual (só o `SKILL.md` a contém).

## Decision 10: `docs/skills/rito-dev.md` (documento completo) fica fora do MVP desta feature

**Decision**: a fonte (`rito-dev-nav`) referencia um documento irmão mais
extenso (`docs/rito-dev-nav.md`) para contexto e troubleshooting. Esta feature
entrega só a skill (`SKILL.md`), conforme escopo do FR-001/FR-003 (item 3 do
MVP do briefing cita só "três skills"); o documento irmão extenso não está
listado em nenhum FR desta spec.

**Rationale**: escopo fechado pela spec — FR-001 lista exatamente as três
skills; não há FR que exija um `docs/rito-dev.md` companheiro nesta feature
(esse artefato aparece no item 4 do MVP do briefing, "Templates de
governança", que é outra frente, ainda não aberta).

**Alternatives considered**: gerar o documento companheiro agora, por
completude — rejeitada por escopo (YAGNI): a spec desta feature não pede, e
antecipá-lo arrisca desalinhar com o formato que a frente de "Templates de
governança" venha a definir.
