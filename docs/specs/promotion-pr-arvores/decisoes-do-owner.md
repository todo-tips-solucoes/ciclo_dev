# Decisões do owner — promotion-pr-arvores

Frente para a issue #7 (`templates/.github/workflows/promotion-pr.yml.tmpl`). As decisões abaixo
foram tomadas pelo owner em 2026-10-06, antes do `/feature-00c`, e são normativas: o `specify`
parte delas e o `clarify` não as reabre.

Contexto: o fluxo decide se há o que promover por
`gh api "repos/$REPO/compare/$PRODUCAO...$INTEGRACAO" --jq '.ahead_by'`. Quando a integração
entra na produção por squash, a produção nunca passa a conter os commits da integração; o
`ahead_by` continua positivo e o PR de promoção é reaberto a cada push na integração, mesmo sem
nada novo de fato. A Fase 9 da skill `rito-dev` já manda promover por merge commit, mas o fluxo
não pode depender disso.

## D1 — decidir pelo conteúdo, não pela ancestralidade

- Se a árvore de arquivos do commit da produção é igual à do commit da integração, não há o que
  promover: o fluxo não abre nem reabre PR, seja qual for o tipo de merge usado antes.
- Com árvores diferentes, o comportamento de hoje continua (PR único aberto ou atualizado,
  FR-008 da frente `templates-automacao`).
- O modelo de branch única (integração = produção), que já sai sem chamar nada, não muda.

## D2 — documentar o efeito do tipo de merge

- O comentário de cabeçalho do fluxo registra que a promoção recomendada é por merge commit (como
  na Fase 9 do `rito-dev`) e que, com squash, o fluxo deixa de reabrir o PR quando o conteúdo já é
  igual.

## Fora de escopo

- Mudar o tipo de merge da promoção ou a Fase 9 do `rito-dev`.
- Gatilhos e permissões do fluxo além do necessário para ler as duas árvores.

## Restrições

- YAML dos fluxos com shell embutido em bash, sem dependência nova; actionlint e shellcheck sem
  findings (rodam no CI).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I). Todo comportamento da API do GitHub citado vem da documentação oficial, com o
  link na research.
- Teste em `scripts/testar-configurar.sh`, num cenário novo **23** (número reservado), logo antes
  do cenário 11, no padrão do cenário 16 (passo do `promotion-pr` extraído e executado com `gh`
  falso): árvores iguais com `ahead_by` positivo não abrem PR; árvores diferentes seguem o
  caminho de hoje.
- Frente paralela a outras quatro (#8, #9, #10 e a de #18/#19). No rebase sobre `main`, conflito
  de inserção em `scripts/testar-configurar.sh` se resolve mantendo os dois blocos.
- Registro SDD em `docs/specs/promotion-pr-arvores/`.
