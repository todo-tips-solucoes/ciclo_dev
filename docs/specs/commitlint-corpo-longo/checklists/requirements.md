# Requirements Checklist: commitlint sem limite de linha no corpo

**Purpose**: validar a qualidade dos requisitos da spec antes do create-tasks
**Created**: 2026-10-06
**Feature**: [spec.md](../spec.md)

## Completude e clareza

- [x] CHK001 - A regra a desligar está identificada de forma inequívoca (tamanho máximo de linha do corpo)? [Clareza, Spec §FR-001] {auto}
- [x] CHK002 - O escopo de autores está definido (todos, sem tratamento de bot)? [Completude, Spec §Edge Cases, §Fora de escopo] {auto}
- [x] CHK003 - O requisito de manter a extensão convencional está explícito e separado do de desligar a regra? [Completude, Spec §FR-002] {auto}
- [x] CHK004 - A fonte da forma de desligar a regra está exigida e rastreável (pesquisa da feature)? [Rastreabilidade, Spec §FR-003; research.md] {auto}
- [x] CHK005 - O limite do diff do fluxo (sem dependência nova, versões e gatilhos intactos) está declarado? [Completude, Spec §FR-004] {auto}

## Critérios de aceite e cenários

- [x] CHK006 - Cada FR tem cenário de aceite associado? [Cobertura, gate requirement-coverage: requirements=5 covered=5] {auto}
- [x] CHK007 - O critério de sucesso do cabeçalho é mensurável (cabeçalho fora do padrão continua reprovando)? [Mensurabilidade, Spec §SC-002] {auto}
- [x] CHK008 - O cenário de teste tem número reservado e posição definidos? [Clareza, Spec §FR-005] {auto}
- [x] CHK009 - Está explícito que o teste confere a configuração gerada e não executa o commitlint? [Assumption, decisoes-do-owner.md §Restrições] {auto}

## Consistência e edge cases

- [x] CHK010 - Spec e decisões do owner são consistentes quanto a escopo e fora de escopo? [Consistência, Spec §Fora de escopo vs decisoes-do-owner.md §Fora de escopo] {auto}
- [x] CHK011 - O comportamento para título de PR (sem corpo) está definido? [Edge Case, Spec §Edge Cases] {auto}
- [x] CHK012 - O comportamento do rodapé longo está delimitado como fora de escopo? [Edge Case, Spec §Edge Cases] {auto}
- [ ] CHK013 - SC-001 ("100% dos commits") é verificável sem rodar o commitlint real, dado que o teste só confere a configuração? [Ambiguity, Spec §SC-001 vs §FR-005] {humano}
