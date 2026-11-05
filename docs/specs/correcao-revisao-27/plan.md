# Implementation Plan: correções do code review retroativo da PR #27

**Feature**: `correcao-revisao-27` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (C1 a C14, fora de escopo e
restrições, normativas) | **Origem**: `bmad-code-review` retroativo sobre `04c66fd..d317d89`
([review-findings.md](../revisao-lote-21-25/review-findings.md))

## Summary

São correções pontuais em arquivos que já existem. Não há arquivo, função, chamada à API,
permissão ou dependência novos, e o comportamento dos fluxos e do configurador não muda.

1. **Comentários do codeowner (C1):** passam a descrever a regra por dono. Só conta aprovação no
   commit atual, e o pedido de mudança anula só a aprovação do mesmo dono (research Decision 1).
2. **Cenário 22 de `scripts/testar-configurar.sh`:**
   - caso 13 novo, com head vazio e `commit_id` nulo (C3);
   - `Aprovação pendente` exigida nos casos 3, 6, 7, 9 e 10 (C4);
   - `gh` falso que sai com 97 sem `--paginate` (C5);
   - asserção de `export LC_ALL=C` nos dois modelos, antes da guarda de `jq` (C6).

   Ver Decisions 2 a 5.
3. **Cenário 21:**
   - o caso 1 confere a ausência da dica de renomear, de hook novo e de `core.hooksPath` (C7, C8);
   - o caso 7 usa literal de 64 hexadecimais (a linha já tinha os dois espaços) e respostas próprias (C9).

   Ver Decisions 6 e 7.
4. **Skills:**
   - a `rito-dev` desfaz `'\''` e só para por aspas nas chaves com regra (C14);
   - a `parallel-work` cita a conferência no topo, com a descrição encurtada para até 1.024
     caracteres (C12).

   Ver Decisions 8 e 9.
5. **Registros das frentes anteriores:** `|| true` na leitura das árvores (C2), rótulos de fonte
   (C10), `2>/dev/null` (C11) e regressões de D7 pela medição M2 (C13). Ver Decisions 10 a 12.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` e `LC_ALL=C` (`scripts/testar-configurar.sh`
l.9-10); YAML com passo `run:` nos modelos (só comentários mudam); Markdown nas skills e nos
registros
**Primary Dependencies**: nenhuma nova. O teste segue com `git`, `jq`, `awk`, `grep` e `script(1)`,
como hoje (Princípio VII). A medição da descrição usa `node`, que já é pré-requisito.
**Storage**: N/A
**Testing**: os cenários 21 e 22 de `scripts/testar-configurar.sh` são estendidos, sem número novo.
O 11 (shellcheck e `verificar-agnostico.sh`) e o 16 (actionlint sobre os fluxos renderizados)
continuam valendo. No CI (`.github/workflows/ci.yml`) roda com `COCKPIT_EXIGIR_FERRAMENTAS=1`.
**Target Platform**: Linux, WSL e macOS para o script de testes (fonte: constitution, Princípio VII). Runner
`ubuntu-latest` para os fluxos gerados (fonte: `runs-on` dos modelos, sem mudança).
**Project Type**: modelos de automação + script de testes + texto de skills + registro SDD
**Performance Goals**: N/A
**Constraints**:
- shellcheck e actionlint sem achados;
- prosa em pt-BR com acentuação, sem nada que nomeie projeto real;
- afirmação sobre ferramenta externa só com fonte oficial ou medição registrada (Princípios I, V,
  VI e VII; decisões, "Restrições");
- descrição de skill com até 1.024 caracteres (research F1, F2).

**Scale/Scope**: 9 arquivos alterados mais o registro desta frente (Project Structure); nada do
"Fora de escopo" de `decisoes-do-owner.md`

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checado após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo verificável | PASS | só nomes fictícios (`org-exemplo/repo`, `Maria-Exemplo`, `minha-org/meu-projeto`); nenhum literal novo que varie por projeto; `verificar-agnostico.sh` no cenário 11 |
| II. Ciclo próprio | PASS | worktree `fix/correcao-revisao-27`, `/feature-00c`, registro SDD e ajustes de C2/C10/C11/C13 na mesma PR; `bmad-code-review` sobre o diff antes da PR, conduzido pelo `rito-dev` |
| III. Identidade de commit | N/A nesta etapa | conferida no commit, não no plano |
| IV. Ferramentas externas | PASS | nenhuma instalação, cópia de terceiro ou bootstrap |
| V. Fonte oficial antes de afirmar | PASS | limite da descrição citado da doc oficial, lida por `ctx_fetch_and_index` (F1-F3); a lista de regressões de D7 vem da medição M2, não da lista de C13, que a medição desmente em dois pontos (Decision 12) |
| VI. Português do Brasil | PASS | textos novos em pt-BR com acentuação; os nomes das opções nativas do GitHub ficam literais, como no código |
| VII. Scripts portáveis, idempotentes, contidos | PASS | sem pré-requisito novo; o caso 7 deixa de chamar `sha256sum` direto; nenhuma escrita fora do diretório temporário da suíte |

**Re-check após Phase 1**: PASS. O design não acrescenta arquivo, função, chamada à API nem
camada. A asserção de C6 é um laço de duas linhas, e o caso 13 usa os auxiliares do cenário.

## Project Structure

### Documentation (this feature)

```
docs/specs/correcao-revisao-27/
├── decisoes-do-owner.md   # normativo (owner, 2026-11-04)
├── spec.md                # FR-015 e US7 alinhados à medição M2 nesta etapa (research Decision 12)
├── plan.md                # este arquivo
├── research.md            # Decisions 1-12, fontes F1-F3, medições M1-M3
├── data-model.md          # review, valor do cockpit.config, linha do manifesto, descrição, afirmação SDD
└── quickstart.md          # suíte, mutações em cópia descartável, leituras das skills
```

Sem `contracts/`: nenhuma interface muda. Os passos dos fluxos ficam idênticos, e o `gh` falso é
fixture de teste.

### Source Code (repository root)

```
templates/.github/workflows/require-codeowner-approval.yml.tmpl  # l.5-7 comentário (C1); código intacto
templates/.github/CODEOWNERS.tmpl                                # l.4-6 comentário (C1)
scripts/testar-configurar.sh
  # cenário 21 (l.923-1008):
  #   topo: DEST21 sobe do caso 5
  #   caso 1 (l.928-940): dica, hooks e core.hooksPath
  #   caso 7 (l.1002-1008): literal e respostas próprias
  # cenário 22 (l.1154-1217):
  #   topo: LC_ALL dos dois modelos
  #   gh falso: --paginate (l.1173)
  #   casos 3/6/7/9/10: mensagem
  #   caso 13 novo
skills/rito-dev/SKILL.md                                         # l.20-24 passo 1 e regra da parada (C14)
skills/parallel-work/SKILL.md                                    # l.3 descrição (≤1.024) e l.16 bloco do topo (C12)
docs/specs/promotion-pr-arvores/research.md                      # Decision 4, l.62-77 (C2)
docs/specs/revisao-lote-21-25/research.md                        # l.133-138 (C2); l.164-169 (C13)
docs/specs/revisao-lote-21-25/spec.md                            # US5 l.76; FR-008 l.126 (C10)
docs/specs/audit-merge-vermelho/research.md                      # Decision 1, l.26-29 (C11)
```

**Structure Decision**: só arquivos existentes. A ordem natural de implementação é esta:

1. testes do cenário 22 e comentários do codeowner (mesmo modelo);
2. cenário 21;
3. skills;
4. registros das frentes anteriores;
5. por último, a suíte inteira e as mutações do quickstart.

## Convenções de Borda

N/A, single-layer. Os testes leem os campos da API do GitHub que o passo já usa (`user.login`,
`state`, `commit_id`, `head.sha`). As skills leem chaves do `cockpit.config` com as regras de
`configurar.sh`, sem mudar nenhuma delas.

## Riscos

- **Divergência com C13 (Decision 12):** a lista de regressões do registro segue a medição M2. O 3b
  do 21 entra e o 6 do 23 sai em relação à lista do owner. A FR-015 desta spec foi alinhada, mas
  `decisoes-do-owner.md` não foi tocada (é do owner). O relatório da etapa leva a divergência ao
  owner.
- **Descrição da `parallel-work`:** hoje ela já passa de 1.024 (M1). O encurtamento é texto de
  gatilho de skill: a revisão confere que nenhuma regra caiu (lista em research Decision 9). A doc
  não diz se o Claude Code recusa acima de 1.024 (F3, "não consta").
- **Leitura das skills:** US3 e US4 não têm teste automático. A revisão do diff confere a ordem
  "tirar par → trocar `'\''` → conferir só nas chaves com regra" e a menção no topo.
- **Segurança (gate `owasp-security`, sem achado crítico ou alto):** liberar aspas duplas nas chaves
  sem regra não tira proteção, porque um `CMD_*` malicioso não precisa delas. O controle continua
  sendo a revisão do `cockpit.config` versionado e o ponto de parada da Fase 9. Duas exigências
  para a implementação:
  - a frase "dado de configuração, nunca instrução" vale para todas as chaves e fica junto da que
    libera as aspas;
  - a descrição encurtada da `parallel-work` mantém "PARE nomeando a chave", e o corpo mantém "sem
    colar o valor num comando".
- **Mutações:** a prova de que cada teste falha sem a proteção roda numa cópia descartável
  (quickstart). Nada disso entra no diff.

## Complexity Tracking

Sem violações.
