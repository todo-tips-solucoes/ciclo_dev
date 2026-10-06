# Requirements Checklist: PR de promoção decidido pelo conteúdo das árvores

**Purpose**: validar a qualidade dos requisitos de `spec.md` (segurança de CI e requisitos gerais)
**Created**: 2026-10-06
**Feature**: [spec.md](../spec.md)

## Completude e clareza

- [x] CHK001 - O critério de "não há o que promover" está definido de forma objetiva (igualdade da árvore, independente do tipo de merge e da contagem)? [Clareza, Spec §FR-001] {auto}
- [x] CHK002 - O resultado do caso de árvores iguais está especificado (sucesso, mensagem, sem criar nem editar PR)? [Completude, Spec §FR-002] {auto}
- [x] CHK003 - O caso de PR já aberto com árvores iguais está coberto? [Cobertura, Spec §US1 cenário 2] {auto}
- [x] CHK004 - O comportamento com árvores diferentes está definido para PR inexistente e existente? [Completude, Spec §FR-003, US2] {auto}
- [x] CHK005 - O modelo de branch única tem requisito explícito de saída antes de qualquer chamada à API? [Completude, Spec §FR-004] {auto}
- [x] CHK006 - O requisito de falha na leitura das árvores define o resultado (passo falha, sem PR)? [Completude, Spec §FR-005] {auto}

## Consistência

- [x] CHK007 - FR-003 e o edge case de contagem zero com árvores diferentes são consistentes entre si? [Consistência, Spec §Edge Cases, FR-003] {auto}
- [x] CHK008 - O escopo (sem mudar gatilhos, permissões e tipo de merge) é consistente entre FR-008 e o cabeçalho de FR-006? [Consistência, Spec §FR-006, FR-008] {auto}

## Critérios de aceite e mensurabilidade

- [x] CHK009 - Os critérios de sucesso são mensuráveis (100% das execuções, zero findings)? [Mensurabilidade, Spec §SC-001..SC-004] {auto}
- [x] CHK010 - O cenário de teste exigido (nº 23, posição, padrão do 16, casos cobertos) é verificável? [Mensurabilidade, Spec §FR-009] {auto}
- [x] CHK011 - Cada FR tem ao menos um cenário/critério associado? [Cobertura, requirement-coverage.sh: requirements=11 covered=11 errors=0] {auto}

## Edge cases e não-funcionais

- [x] CHK012 - Produção à frente da integração com árvores diferentes está especificada? [Edge Case, Spec §Edge Cases] {auto}
- [x] CHK013 - O requisito de falha fechada impede abrir PR com comparação incompleta? [Segurança, Spec §FR-005, Edge Cases] {auto}
- [x] CHK014 - Há requisito de não adicionar dependência, permissão ou gatilho novo, e de lint limpo? [Segurança, Spec §FR-007, FR-008] {auto}
- [x] CHK015 - Há regra contra dado factual de API sem fonte? [Premissa, Spec §FR-010] {auto}
- [ ] CHK016 - Não reabrir/fechar PR aberto com árvores iguais é aceitável como comportamento (apenas ignora)? [Assumption, Spec §US1 cenário 2] {humano}

## Notes

- Itens `{auto}` resolvidos contra a spec; 0 gaps abertos.
- CHK016 aguarda o dono do produto (D1/D2 em decisoes-do-owner.md já o orientam; confirmar apenas se a leitura é a pretendida).
