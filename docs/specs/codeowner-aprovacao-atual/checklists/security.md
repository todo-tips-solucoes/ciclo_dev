# Security Checklist: Aprovação de dono sobre o commit atual

**Purpose**: validar a qualidade dos requisitos de segurança do check `require-codeowner-approval` (falha fechada, origem do head, entrada não confiável).
**Created**: 2026-10-06
**Feature**: [spec.md](../spec.md)

## Autorização e falha fechada

- [x] CHK001 - O requisito define que só aprovação sobre o head atual conta, sem ambiguidade de "atual"? [Clareza, Spec §FR-001, FR-003] {auto}
- [x] CHK002 - Está especificado o que ocorre quando o head não pode ser obtido (falha, não aprovação)? [Completude, Spec §FR-005] {auto}
- [x] CHK003 - Review sem `commit_id` utilizável ou lista vazia tem resultado definido como pendente? [Edge Cases, Spec §Edge Cases] {auto}
- [x] CHK004 - O estado de review descartada (dismissed) sobre o head tem tratamento explícito? [Edge Cases, Spec §Edge Cases, FR-002] {auto}
- [x] CHK005 - Aprovação de não-dono nunca conta, e o cenário de aceite cobre dono antigo + não-dono no head? [Cobertura, Spec §US1.4, FR-006] {auto}
- [x] CHK006 - O requisito de push novo invalidar a aprovação anterior é mensurável (SC-002)? [Mensurabilidade, Spec §FR-004, SC-002] {auto}
- [x] CHK007 - A guarda contra head vazio igualando `commit_id` vazio está exigida no desenho? [Risco, Plan §Gate de segurança S1] {auto}

## Entrada não confiável e superfície do pipeline

- [x] CHK008 - Está definido que dados lidos da API não viram código (head por `awk -v`, programa `--jq` fixo)? [Completude, Plan §Gate de segurança] {auto}
- [x] CHK009 - A restrição de não alterar permissões nem gatilhos além do necessário está explícita? [Completude, Spec §Fora de escopo, FR-005] {auto}
- [x] CHK010 - A proibição de dependência nova e de nomear projeto real está declarada? [Completude, Spec §FR-010] {auto}
- [x] CHK011 - A natureza forjável do check e o papel de verificação extra estão preservados no texto? [Consistência, Spec §FR-008, Plan §S4] {auto}

## Consistência e rastreabilidade

- [x] CHK012 - O nome da opção nativa vem de fonte oficial rastreável, não de memória? [Assumption, Spec §FR-007, Research] {auto}
- [x] CHK013 - Os casos do cenário 22 cobrem todos os cenários de aceite da US1 e US3? [Cobertura, Spec §FR-009, Plan §Design] {auto}
- [x] CHK014 - A inconsistência "mais estrito que a opção nativa" (commit sem mudança de diff) está documentada como aceita? [Conflict, Plan §Riscos] {auto}
- [x] CHK015 - O delta no contrato `templates-automacao` está previsto para evitar contradição de regra? [Consistência, Plan §Documentação] {auto}

## Decisões de risco

- [ ] CHK016 - Aceitar S2 (formato do head não validado, falha fechada por não coincidir) é adequado ao apetite de risco do produto? [Risco, Plan §S2] {humano}
- [ ] CHK017 - Aceitar S3 (corrida push entre leitura do head e das reviews) é adequado? [Risco, Plan §S3] {humano}

## Notes

- Itens `{auto}` resolvidos com citação; `{humano}` aguardam o dono do produto.
- Gate `requirement-coverage.sh` ausente neste repositório: pulado (sem findings a converter).
- Nenhum `[Gap]`, `[Ambiguity]` ou `[Conflict]` aberto.
