# API Checklist: auditoria de merge vermelho sem falsos achados

**Purpose**: validar a qualidade dos requisitos das duas rotas REST do GitHub que o passo consulta (regras da branch base e listagem de issues).
**Created**: 2026-10-06
**Feature**: [spec.md](../spec.md)

## Contrato da rota de regras (D1)

- [x] CHK001 - A codificação do nome da branch está especificada de forma verificável (conjunto de bytes e caixa do hexadecimal)? [Clareza, Spec §FR-001, plan.md "Convenções de Borda"] {auto}
- [x] CHK002 - O comportamento para base sem caracteres especiais está definido como inalterado? [Completude, Spec §FR-003, US1 cenário 2] {auto}
- [x] CHK003 - O tratamento de `%2F` pela API está registrado como lacuna não medida, e não como fato? [Assumption, contracts/github-rest.md "F1"] {auto}
- [x] CHK004 - O comportamento em falha real da consulta de regras (permissão, rota inexistente) está definido? [Cobertura, Spec §Edge Cases, contracts/github-rest.md "Erro"] {auto}
- [x] CHK005 - Os caracteres além de `/` que exigem codificação estão cobertos por um requisito mensurável? [Cobertura, Spec §Edge Cases, FR-001 (regra geral RFC 3986)] {auto}

## Contrato da listagem de issues (D2)

- [x] CHK006 - "Título idêntico" está definido como igualdade exata, em qualquer estado? [Clareza, Spec §FR-004, FR-005] {auto}
- [x] CHK007 - O requisito de cobrir todas as páginas é mensurável por cenário de teste? [Mensurabilidade, Spec §FR-006, US2 cenário 3] {auto}
- [x] CHK008 - A exclusão de PRs (que a rota de issues também lista) está especificada? [Completude, contracts/github-rest.md "Response", plan.md Summary] {auto}
- [x] CHK009 - A fonte oficial de rota, parâmetros e paginação está citada, em vez de suposta? [Rastreabilidade, Spec §FR-006, plan.md Constitution Check V] {auto}
- [x] CHK010 - O comportamento em falha da listagem está definido (falhar o passo sem criar issue)? [Completude, Spec §FR-010, Clarifications] {auto}
- [ ] CHK011 - Não há requisito para limite de taxa (rate limit) da listagem paginada; falta decidir se isso importa. [Gap, plan.md "Performance Goals" (volume não medido)] {humano}

## Consistência e escopo

- [x] CHK012 - As decisões D1 e D2 são consistentes com FR-001 a FR-006, sem conflito entre spec e plan? [Consistência, decisoes-do-owner.md, Spec §FR-001..FR-006, plan.md Summary] {auto}
- [x] CHK013 - O que permanece inalterado (critério de vermelho, conteúdo da issue, gatilhos, permissões) está listado de forma testável? [Completude, Spec §FR-007] {auto}
- [x] CHK014 - A permissão exigida pelas duas rotas está documentada e reconciliada com as permissões já declaradas? [Dependências, contracts/github-rest.md "Auth"] {auto}
- [x] CHK015 - O requisito de sem dependência nova e sem findings de actionlint/shellcheck é objetivamente verificável? [Mensurabilidade, Spec §FR-008, SC-003] {auto}
- [x] CHK016 - Os critérios de sucesso SC-001 e SC-002 mapeiam para os cenários do FR-009? [Rastreabilidade, Spec §SC-001, SC-002, FR-009] {auto}
- [ ] CHK017 - A ordem da checagem de duplicada (movida para antes do `issue create`) é aceitável como efeito colateral de desempenho? [Assumption, plan.md "Mudanças no passo" item 6, research Decision 3] {humano}

## Notes

- Items `{auto}` resolvidos com citação; gate de cobertura `requirement-coverage.sh`: 10/10 FRs cobertos, 0 findings.
- Items `{humano}` (CHK011, CHK017) ficam `[ ]` aguardando o dono do produto; nenhum bloqueia o avanço.
- Gaps abertos: CHK011 (vira candidato a tarefa de requisito no create-tasks, não bloqueante).
