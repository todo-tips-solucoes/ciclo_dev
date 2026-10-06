# Implementation Plan: PR de promoção decidido pelo conteúdo das árvores

**Feature**: `promotion-pr-arvores` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 e D2, normativas)

## Summary

O passo do fluxo `promotion-pr` passa a ler, quando há commits à frente, o SHA da árvore da ponta
da produção e da integração (`gh api repos/$REPO/commits/heads/<branch> --jq
'.commit.tree.sha'`, [research](research.md), Decision 1). SHAs iguais = mesmo conteúdo (Decision
2): o passo sai 0 com "nada a promover", sem criar nem editar PR, qualquer que tenha sido o tipo
de merge. SHAs diferentes seguem o caminho de hoje. Leitura que falha ou devolve valor que não é
SHA faz o passo falhar antes de qualquer `gh pr` (Decision 4). O cabeçalho do template registra
a promoção por merge commit e o efeito do squash (D2). Teste no cenário 23 novo de
`scripts/testar-configurar.sh`, com `gh` falso, no padrão do cenário 16.

## Technical Context

**Language/Version**: bash embutido em fluxo do GitHub Actions (`run:` com `set -euo pipefail`,
como hoje)
**Primary Dependencies**: nenhuma nova (FR-007): `gh api` e `GH_TOKEN`, já usados pelo passo
**Storage**: N/A
**Testing**: `scripts/testar-configurar.sh`, cenário 23 novo; actionlint e shellcheck sobre o
fluxo renderizado no cenário 16 (sem mudança); `verificar-agnostico.sh` no cenário 11
**Target Platform**: runner `ubuntu-latest` do GitHub Actions (fluxo gerado); a suíte de testes
roda em Linux, WSL e macOS (Princípio VII)
**Project Type**: template de fluxo de CI + script de teste
**Performance Goals**: N/A (duas chamadas de API a mais, só com commits à frente)
**Constraints**: gatilhos, permissões e tipo de merge sem mudança (FR-008); mensagens e saídas de
hoje sem mudança; prosa em pt-BR acentuado; nada que nomeie projeto real
**Scale/Scope**: 1 template (cabeçalho + 1 bloco no passo), 1 cenário de teste novo

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | nenhum literal de projeto; branches seguem vindo de `{{BRANCH_*}}` pelo `env:`; branch única inalterada (FR-004); cenário 11 roda `verificar-agnostico.sh` |
| II. Cockpit sob o próprio ciclo | PASS | branch `fix/promotion-pr-arvores` em worktree, via `/feature-00c`; registro SDD neste diretório |
| III. Identidade de commit | N/A | o fluxo não commita |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta, ação ou cópia nova |
| V. Fonte oficial antes de afirmar | PASS | FR-010: endpoint, `ref`, `commit.tree.sha`, permissões e semântica de árvore citados de F1 a F4 com link ([research](research.md)); o código de saída do `gh api` em HTTP 4xx/5xx não é documentado (F5, F6) e o desenho não depende dele (Decision 4) |
| VI. Português do Brasil | PASS | FR-011: mensagem nova, comentário de cabeçalho e cenário em pt-BR acentuado |
| VII. Portáveis, idempotentes, contidos | PASS | `set -euo pipefail` mantido; o passo não escreve nada além do PR; cenário 23 escreve só em `$TMP`; shellcheck do `testar-configurar.sh` no cenário 11 |

**Re-check pós-design**: PASS. Nenhum arquivo, passo, ação, permissão ou chave nova; o bloco novo
reusa `gh api` e o `GH_TOKEN` do passo. A guarda da Decision 4 é validação de fronteira (resposta
da API), não complexidade a justificar.

## Design

Referências de linha no commit `18a0df9`.

### `templates/.github/workflows/promotion-pr.yml.tmpl`

1. **Cabeçalho** (l.1-4, FR-006, D2): duas linhas de comentário a mais — promova por merge commit,
   como na Fase 9 do `rito-dev`; com squash a produção não passa a conter os commits da
   integração, e o fluxo compara o conteúdo das duas pontas para não reabrir o PR quando ele já é
   igual ([research](research.md), Decision 8).
2. **Bloco novo no `run:`**, entre l.42 (`fi` da contagem zero) e l.43 (`corpo="$(mktemp)"`)
   (Decision 3):
   - lê o SHA da árvore de `heads/$PRODUCAO` e de `heads/$INTEGRACAO` com `gh api ... --jq
     '.commit.tree.sha'` (Decision 1);
   - se algum não casa com hexadecimal não vazio: stderr `Não consegui ler as árvores de
     $PRODUCAO e $INTEGRACAO: nada promovido.` e `exit 1` (FR-005, Decision 4);
   - se iguais: `Produção e integração têm o mesmo conteúdo: nada a promover.` e `exit 0`
     (FR-001, FR-002).

Sem mudança em `on:`, `permissions:`, `env:` do passo, contagem, corpo, `gh pr list`, `gh pr
edit` e `gh pr create` (FR-003, FR-008; Decision 5). A tabela de decisão completa do passo está
no [data-model](data-model.md).

### `scripts/testar-configurar.sh` (FR-009)

- Bloco `# --- 23 ---` com `cenario "23: promotion-pr decide pelas árvores"`, logo antes da l.922
  (bloco do cenário 11). Reusa `$TMP/promocao.sh` extraído no cenário 16; `gh` falso próprio que
  responde por `case "$*"` e registra as chamadas; casos 1 a 6 do [quickstart](quickstart.md)
  (Decision 9). `grep -q 'merge commit'` no template cobre US3.
- No rebase sobre `main`, conflito de inserção com outra frente nessa região se resolve mantendo
  os dois blocos (decisoes-do-owner.md, Restrições).

### Fora do escopo

Tipo de merge da promoção e a Fase 9 do `rito-dev` (FR-008); fechar PR aberto com árvores
iguais (Decision 6).

## Project Structure

### Documentation (this feature)

```text
docs/specs/promotion-pr-arvores/
├── decisoes-do-owner.md
├── spec.md
├── plan.md          # este arquivo
├── research.md
├── data-model.md
└── quickstart.md
```

Sem `contracts/`: o passo não expõe interface nova; as chamadas de API consumidas estão na
[research](research.md) (F1, F2) e as saídas no [data-model](data-model.md).

### Source Code (repository root)

```text
templates/.github/workflows/promotion-pr.yml.tmpl   # cabeçalho + bloco novo no run:
scripts/testar-configurar.sh                         # cenário 23
```

## Convenções de Borda

N/A — single-layer (um passo de shell num fluxo de CI).

## Complexity Tracking

Sem violação de constitution a justificar.

## Gate de segurança (owasp-security sobre o desenho)

0 crítico, 0 alto, 0 médio. Foco em CI/CD (PPE, credenciais, falha aberta) e entrada não
confiável.

| # | Severidade | Achado | Tratamento |
|---|------------|--------|------------|
| B1 | baixa | O nome da branch entra sem codificação no caminho da URL das duas leituras novas; nome com `#` ou `%` desviaria a leitura para outro recurso do mesmo repositório. Mesmo limite do `compare` de hoje (l.38); só leitura, com `contents: read` | aceito com `ponytail:` ([research](research.md), Decision 4) |
| B2 | informativo | Nenhuma expressão `${{ }}` nova dentro de `run:`: as branches seguem chegando pelo `env:` e entram no shell sempre entre aspas, sem risco de injeção de script | nenhum |
| B3 | informativo | A resposta da API é validada (SHA hexadecimal não vazio) antes da comparação e só é comparada, nunca executada; leitura que falha encerra o passo antes de qualquer `gh pr` (falha fechada, FR-005) | nenhum |
| B4 | informativo | Gatilho (`push` na integração), permissões e token sem mudança; nenhum segredo novo; mensagens só citam nomes de branch | nenhum |
