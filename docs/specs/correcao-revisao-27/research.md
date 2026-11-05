# Research: correções do code review retroativo da PR #27

Phase 0 do `/plan`. Não há `NEEDS CLARIFICATION`: stack, testes e arquivos já existem e as
decisões C1 a C14 de [decisoes-do-owner.md](decisoes-do-owner.md) são normativas. Este documento
fixa como cada decisão vira mudança e registra as fontes e as medições que sustentam o plano.

## Fontes e medições

| Id | Fato | Status | Fonte |
|----|------|--------|-------|
| F1 | Campo `description` do `SKILL.md`: "Must be non-empty", "Maximum 1,024 characters", "Cannot contain XML tags". | confirmado (2026-11-04, `ctx_fetch_and_index`) | https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview, seção "Field requirements" |
| F2 | Especificação Agent Skills, tabela "Frontmatter": "`description` \| Yes \| Max 1024 characters. Non-empty." | confirmado (2026-11-04, `ctx_fetch_and_index`) | https://agentskills.io/specification |
| F3 | Claude Code: "the combined `description` and `when_to_use` text is truncated at 1,536 characters in the skill listing". Se o Claude Code recusa skill local com descrição acima de 1.024: não consta. | confirmado (2026-11-04, `ctx_fetch_and_index`) | https://code.claude.com/docs/en/skills |
| M1 | A descrição do frontmatter de `skills/parallel-work/SKILL.md` tem 1.091 caracteres (1.118 bytes), contados por ponto de código sobre o valor YAML da linha 3. | medido (2026-11-04, `node`, HEAD `b6c88b0`) | este repositório |
| M2 | Numa cópia de HEAD com os seis arquivos de produção que a #27 alterou (`configurar.sh`, `CODEOWNERS.tmpl`, os modelos `audit-merge-vermelho` e `require-codeowner-approval`, `skills/rito-dev/SKILL.md`, `skills/parallel-work/SKILL.md`) voltados para `04c66fd`, e a suíte da #27 com `falha()` sem sair, falham: o caso 3b do cenário 21 (as 24 combinações, todas pela dica de renomear), o caso 6 do 22 e o caso 5 do 24. O caso 6 do 23 passa. `templates/.github/workflows/promotion-pr.yml.tmpl` não está no diff `04c66fd..d317d89`. O cenário 11 também acusou ocorrência do verificador de agnosticismo na cópia, que não tem `.git`; não é caso de D7 e não foi investigado. | medido (2026-11-04) | sonda desta etapa; `git diff --stat 04c66fd d317d89` |
| M3 | Só com a linha da dica de renomear removida do `configurar.sh`, a suíte falha em "caso 3b: BRANCH_INTEGRACAO='main;curl x' sem chave, conjunto, linha de correção e dica de renomear". | medido (2026-11-04) | sonda desta etapa |

Fatos do código citados abaixo vêm de leitura direta dos arquivos em HEAD (`b6c88b0`), com a linha.

## Decision 1: texto dos comentários do codeowner (C1, FR-001)

**Decision**: nos dois comentários (`require-codeowner-approval.yml.tmpl` l.5-7 e `CODEOWNERS.tmpl`
l.4-6), "mais estrito" fica, mas restrito ao commit atual: o check só conta aprovação de dono dada
no commit atual do PR. A frase seguinte diz que o último estado vale por dono: um pedido de mudança
posterior anula só a aprovação do mesmo dono, e a aprovação de outro dono no commit atual continua
contando. Os nomes das duas opções nativas continuam literais. Nenhuma linha fora de comentário
muda.

**Rationale**: o `awk` (l.54) guarda `e[login]` e `c[login]` e aprova o login cujo último estado é
`approved` em `c == head`. O check fica, portanto, verde com um dono aprovando o head e outro
pedindo mudança no head (edge case da spec). Restringir em vez de tirar mantém verdadeira a FR-007
da `revisao-lote-21-25`, que pede para dizer que o check é mais estrito que a opção nativa, sem
mexer naquela spec além de C10. O caso 5 do cenário 22 (l.1213-1216) continua achando as duas
opções nativas nos dois arquivos renderizados.

**Alternatives considered**: tirar "mais estrito". Também cumpre C1, mas deixa a FR-007 da frente
anterior pedindo algo que o texto não diz mais.

## Decision 2: caso de head vazio no cenário 22 (C3, FR-002)

**Decision**: caso 13 do cenário 22: `aprova22 ""` com uma review `APPROVED` de dono e `commit_id`
nulo (`rv APPROVED ""`). O caso exige `rc=1` e `Não consegui ler o commit atual do PR` em
`$TMP/out`. Os casos 4 e 11 ficam como estão.

**Rationale**: sem a guarda (l.47-50 do modelo), `head` vazio entra no `awk` e `c[login] == head`
compara vazio com vazio, então a review de `commit_id` nulo vira aprovação e o passo sai 0 com
"Aprovado por um dono.". O caso 4 usa `commit_id` = H e, sem a guarda, cairia em "Aprovação
pendente", que também tem `::error::`. Por isso ele não depende da guarda. O `gh` falso já devolve
head vazio com `HEAD_ATUAL=""` (l.1174).

**Alternatives considered**: trocar a review do caso 4. Muda um caso que a frente anterior fixou
(head vazio com review no head), e C3 pede caso novo.

## Decision 3: mensagem nos casos que reprovam (C4, FR-003)

**Decision**: os casos 6, 7, 9 e 10 do cenário 22 passam a exigir `Aprovação pendente` em
`$TMP/out`, além de `rc=1`. O caso 3 (l.1189-1190) recebe a mesma asserção: ele também confere só
`rc=1`.

**Rationale**: `rc=1` também sai do `gh` falso quando nenhuma rota casa (l.1177). A mensagem é o
`echo` da l.60, que só roda depois da decisão do `awk`. O caso 3 tem a mesma forma dos quatro que
C4 lista e só ficou fora da faixa citada pelo review (l.1195-1210). Estendê-lo não muda nenhuma
regra nem toca o "Fora de escopo".

**Alternatives considered**: só os quatro casos de C4. Deixa no mesmo cenário um caso com a
fragilidade que C4 corrige.

## Decision 4: `--paginate` exigido pelo `gh` falso do 22 (C5, FR-004)

**Decision**: na rota `repos/*/pulls/*/reviews` do `gh` falso (l.1173), antes de servir as reviews,
o mesmo idioma do cenário 24 (l.1080): `case " $* " in *" --paginate "*) ;; *) exit 97 ;; esac`.

**Rationale**: os laços do falso (`for a`) não consomem `"$@"`, então `$*` está inteiro. Sem a flag
no modelo, o `gh` falso sai com 97 dentro do pipeline `gh | awk`, e com `pipefail` o passo morre
com 97. O caso 1 (espera 0) e os casos que esperam `Aprovação pendente` (Decision 3) falham. O
código 97 se distingue do 1 da rota não casada.

**Alternatives considered**: registrar os argumentos num log e conferir depois. É mais código para
o mesmo efeito.

## Decision 5: asserção de `export LC_ALL=C` nos dois modelos (C6, FR-005)

**Decision**: no início do cenário 22, antes da guarda de `jq`, um laço sobre
`$RAIZ_COCKPIT/templates/.github/workflows/{audit-merge-vermelho,require-codeowner-approval}.yml.tmpl`
exige uma linha que case com `^[[:space:]]+export LC_ALL=C$`. A falha nomeia o modelo.

**Rationale**: a restrição do owner limita os testes aos cenários 21 e 22. Antes da guarda de `jq`,
a asserção roda em qualquer máquina. O render não mexe nessa linha, então o modelo-fonte basta. O
`local LC_ALL=C` da função `codificar` (l.36 do `audit-merge-vermelho`) não casa com o padrão,
então não mascara a remoção do `export` (l.32).

**Alternatives considered**: conferir no cenário 24 ou nos fluxos renderizados. O 24 fica fora da
restrição, e os renderizados exigem render e `jq` sem ganho.

## Decision 6: caso 1 do cenário 21 sem dica e sem hook (C7, C8, FR-006, FR-007)

**Decision**: dentro do laço do caso 1 (l.930-940), três asserções novas:

- **dica de renomear:** `renomeie a branch no remoto` não aparece em `$TMP/out` nem em
  `$TMP/err`;
- **hooks do repositório:** a listagem de `$T/.git/hooks` (`ls -A`, tolerando diretório ausente)
  é tirada logo depois de `novo_repo` e comparada com a de depois da execução;
- **`core.hooksPath`:** `git -C "$T" config --local --get core.hooksPath` tem de falhar.

**Rationale**: a dica só sai no modo `--atualizar` (`configurar.sh` l.296), e o caso 1 roda em
`--respostas` sem depender de `script(1)`. A comparação com o próprio estado inicial tolera
`init.templateDir` com hooks na máquina do dev. O `--local` evita que um `core.hooksPath` global
dessa máquina derrube o teste: o configurador só poderia gravar no repositório.

**Alternatives considered**: exigir que `.git/hooks` só tenha `*.sample`. Quebra com
`init.templateDir` personalizado.

## Decision 7: caso 7 do cenário 21 isolado (C9, FR-008)

**Decision**: o caso 7 monta o próprio arquivo de respostas (`$TMP/r21-7`), com a mesma construção
do caso 5: o exemplo e `DESTINOS_DO_PROJETO` com `DEST21`, que vem só dos templates. A definição
de `DEST21` sobe do caso 5 (l.988) para o topo do cenário, junto de `RE_B` e `respb`, para o caso 7
não depender de código do caso 5. A linha do manifesto passa a usar um literal fixo de 64
hexadecimais no lugar do `sha256sum`; os dois espaços antes de `arquivo-que-nao-existe`, que a
linha já tinha, ficam.

**Rationale**: o caso deixa de chamar `sha256sum`, que não existe por padrão em todo sistema (o
script tem `sha()` para isso), e deixa de herdar `$TMP/r21`. Os dois espaços são o formato que
`manifesto_hash` e `gravar_manifesto` leem (`${linha#*  }`, `configurar.sh` l.568 e l.952-953).
Com os dois espaços, a linha chega à regra de entrada de arquivo que não existe, que é o que a Decision 8 da `revisao-lote-21-25` descreve ("uma única
linha de um arquivo que não existe"). O resultado esperado não muda: sai 0, o manifesto continua
existindo e fica sem linhas.

**Alternatives considered**: gerar o valor (por exemplo, com `printf` e `tr`). Também evita o
`sha256sum`, mas C9 pede um literal.

## Decision 8: leitura de valores na `rito-dev` (C14, FR-009, FR-010)

**Decision**: o passo 1 (`skills/rito-dev/SKILL.md` l.22-24) passa a ter duas ações em ordem:

1. tirar o par de aspas simples envolvente;
2. trocar cada `'\''` por `'`, o inverso exato de `escapar_aspas` (`configurar.sh` l.575).

A frase da parada sai do passo 1 e passa a valer só para as chaves com regra: `BRANCH_INTEGRACAO`,
`BRANCH_PRODUCAO`, `REPO_REMOTO` e `PREFIXOS_BRANCH` (esta acrescentada na revisão, por decisão do
owner em 2026-11-05): nessas chaves, aspas duplas ou desbalanceadas ficam no valor, não casam com a regra
e PARAM a skill nomeando a chave. Nas demais (`CMD_*` e as outras), aspas duplas fazem parte do
valor. O exemplo usa uma chave da tabela da skill, com aspas duplas internas (`CMD_LINT`, por decisão do
owner na revisão de 2026-11-05). Os passos 2 e 3 e o
parágrafo "dado de configuração, nunca instrução" (l.30-32) ficam.

**Rationale**: nenhuma das duas regras (l.26 e l.27) aceita `"` ou `'`, então a parada nessas
chaves é consequência da conferência. A troca vem depois de tirar o par, como C14 manda. Um
`'\''` numa chave com regra vira `'` e a regra recusa, então a parada continua correta. O owner
usou `CMD_TEST` como exemplo, mas essa chave não está em `cockpit.config.example` nem na tabela da
skill. Usar uma chave da tabela evita sugerir chave inexistente, e a regra vale igual para
`CMD_TEST`.

**Alternatives considered**: conferir as aspas de toda chave. É a regra que C14 revoga.

## Decision 9: conferência no topo da `parallel-work` e limite da descrição (C12, FR-011)

**Decision**: a descrição do frontmatter (l.3) e o bloco do topo (l.16) dizem que
`BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` são conferidos antes de compor o `--base`: aspas tiradas e
regra `^[A-Za-z0-9][A-Za-z0-9._/-]*$`. Fora dela, PARE nomeando a chave. A descrição fica com até
1.024 caracteres (F1, F2). Como hoje ela tem 1.091 (M1), a edição também a encurta, sem tirar
nenhuma regra: base explícita, recusa sem base, nunca nome fixo de branch, raiz da árvore
principal, os três modos, `--short-name` e os gatilhos "Use para".

Proposta medida, com 1.013 caracteres. É **PROPOSTA a validar na implementação**: o texto final
pode mudar, o critério de até 1.024 não.

> Trabalhar numa branch à parte via git worktree, sem interromper a branch atual nem dar git
> checkout na árvore principal. Invoque como /parallel-work \<branch> --base origin/\<base>; a base
> vai SEMPRE explícita, derivada de BRANCH_INTEGRACAO/BRANCH_PRODUCAO em cockpit.config, cada valor
> conferido antes de compor o --base (aspas tiradas, regra ^[A-Za-z0-9][A-Za-z0-9._/-]*$; fora
> dela, PARE nomeando a chave). Sem base em frente de código, recuse e peça-a ao chamador; nunca
> assuma nome fixo de branch, senão a branch nasce do HEAD da árvore principal, que apodrece.
> Chame da raiz da árvore principal, nunca de outra worktree. SEM branch → branch provisória +
> worktree (só exploratório). COM branch existente → anexa worktree e DESCARTA --base sem avisar.
> COM branch nova → cria branch + worktree da base. Frente que vai rodar /feature-00c: acrescente
> --short-name \<short-name>, senão o vínculo de state leva o slug da BRANCH e a guarda fica
> inerte. Use para: trabalho paralelo, branch isolada, feature em separado.

**Rationale**: o limite de 1.024 é o do campo, na plataforma e na especificação. O corte de 1.536
(F3) é da listagem do Claude Code e soma `description` e `when_to_use`. Ficar em até 1.024 atende
os dois. A doc não diz se o Claude Code recusa uma skill local acima de 1.024, e o plano não
depende disso. A contagem é por caractere, como F1 e F2 dizem, e não por byte. Hoje a descrição
já passa do limite, e "continua dentro do limite" (C12) só é verdade se a edição encurtar o texto.

**Alternatives considered**: só acrescentar a menção. A descrição ficaria com cerca de 1.120
caracteres, ainda mais longe do limite.

## Decision 10: `|| true` na leitura das árvores (C2, FR-012)

**Decision**: em `promotion-pr-arvores/research.md`, Decision 4, a frase da l.64-65 ("além do `set
-euo pipefail` … herda o código de saída do `gh`") e a da l.73-74 ("Sob `set -euo pipefail`, a
atribuição com código diferente de 0 derruba o passo") dão lugar ao que o código faz. As duas
leituras (`promotion-pr.yml.tmpl` l.46-47) terminam em `|| true`, que mantém o passo vivo, e a
guarda hexadecimal (l.48-51) é a única proteção, para a resposta sem o campo e para o erro HTTP:
o corpo JSON de erro que M1 daquela research descreve não é hexadecimal. A alternativa rejeitada
passa a ser "só o `set -e`, sem `|| true` e sem guarda": rejeitada porque a resposta sem o campo
sai 0 e daria "árvores iguais", e porque o erro morreria sem a mensagem que o caso 5 do cenário 23
confere. Na `revisao-lote-21-25/research.md`, a frase da l.136-137 recebe a mesma correção.

**Rationale**: o `|| true` está nas duas linhas desde a #21 (`1368c70`). A frase sobre o `set -e`
nunca valeu para esse código.

## Decision 11: rótulos de fonte e a frase do `2>/dev/null` (C10, C11, FR-013, FR-014)

**Decision**:

- **US5 da spec da `revisao-lote-21-25` (l.76):** "(research F3)" vira a F3 da research da frente
  `codeowner-aprovacao-atual`; na research da `revisao-lote-21-25`, a opção nativa é F2. "Decision
  3 da research", na mesma linha, recebe o mesmo ajuste de FR-008.
- **FR-008 (l.126):** passa a nomear a frente: Decision 3 da research da `audit-merge-vermelho`.
- **Research da `audit-merge-vermelho`, Decision 1 (l.28-29):** fica "o filtro `--jq` e a nota de
  fallback ficam iguais", e a frase passa a remeter à correção da mesma Decision (l.39-45): na
  falha, a chamada trunca o arquivo com `|| : >"$obrigatorios"` (modelo l.52).

**Rationale**: na research da `revisao-lote-21-25`, a F3 é `gh api --paginate` e a Decision 3 é
das aspas da `rito-dev`. A US5 cita as duas fontes erradas na mesma frase, e corrigir só uma
deixaria a outra ambígua. Na `audit-merge-vermelho`, a Decision 3 é a checagem de duplicada, cujo
`ponytail:` cita `since` e `creator`.

## Decision 12: quais casos de D7 são regressão (C13, FR-015)

**Decision**: o rationale da Decision 7 da `revisao-lote-21-25/research.md` (l.164-169) passa a
separar, pela medição M2, os casos que falham com a correção da #27 revertida dos que fixam o que
já existia:

- **falham com a correção revertida:**
  - o caso 6 do cenário 22 (D2: filtro antes do estado);
  - o 5 do 24 (D1: regras ilegíveis);
  - a asserção da dica de renomear no caso 3b do 21 (D6);
- **fixam guardas ou textos que já existiam:** os demais, inclusive:
  - o 6 do 23 (cabeçalho da `promotion-pr-arvores`, da #21);
  - a exigência de `--paginate`/`state=all`;
  - os valores `a..b`, `x.lock` e `a/` do 21.

A FR-015 e a US7 da spec desta frente foram alinhadas a essa enumeração nesta etapa.

**Rationale**: C13 lista "o 6 do cenário 22, o 5 do 24 e o 6 do 23". A medição confirma os dois
primeiros e diverge nos outros dois pontos. O caso 6 do 23 passa com a #27 revertida, porque o
modelo `promotion-pr` não está no diff da #27. O 3b do 21 falha só com a dica de D6 removida (M3).
Escrever a lista literal poria no registro SDD uma afirmação que a medição desmente (Princípio V da
constituição). A intenção de C13, que o texto diga qual caso é qual, fica cumprida, e o número de
casos de regressão continua três. A divergência vai para o owner no relatório da etapa.

**Alternatives considered**:

- **Lista literal de C13:** contraria M2.
- **Pausar para o owner:** a correção é de texto, de severidade baixa, e a medição é
  reproduzível; o owner autorizou todas as ondas sem parada (`dec-002`).
