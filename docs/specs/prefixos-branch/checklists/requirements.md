# Requirements Checklist: prefixos-branch

**Purpose**: qualidade dos requisitos da chave `PREFIXOS_BRANCH` (completude, clareza, consistência, validação de entrada).
**Created**: 2026-10-05
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - A ordem posicional dos cinco tipos está definida de forma única? [Completude, Spec §FR-001] {auto}
- [x] CHK002 - O valor padrão quando a chave está ausente ou em branco está especificado? [Completude, Spec §FR-006] {auto}
- [x] CHK003 - Os cinco placeholders derivados estão nomeados e sua não-persistência declarada? [Completude, Spec §FR-007] {auto}
- [x] CHK004 - Os três lugares de literal (dois templates e a skill) têm requisito próprio? [Completude, Spec §FR-008, §FR-010] {auto}
- [x] CHK005 - Documentação da chave (exemplo de config e contrato do configurador) é exigida? [Completude, Spec §FR-011] {auto}
- [x] CHK006 - O requisito de testes cobre ausente, válido, inválido e interativo? [Completude, Spec §FR-012] {auto}

## Clareza e mensurabilidade

- [x] CHK007 - "Nome de branch válido" está ancorado numa autoridade verificável (git check-ref-format)? [Clareza, Spec §Premissas, §FR-003] {auto}
- [x] CHK008 - "Idêntico ao de hoje" é mensurável (byte a byte, 2 de 2 documentos)? [Mensurabilidade, Spec §SC-001] {auto}
- [x] CHK009 - "Sem escrita parcial" em valor inválido é observável como critério? [Mensurabilidade, Spec §SC-003] {auto}
- [x] CHK010 - O tratamento de espaços múltiplos, bordas e valor só de espaços está definido? [Clareza, Spec §Edge Cases] {auto}

## Consistência

- [x] CHK011 - A regra "templates nunca usam a chave opcional" é coerente com o cenário 15 e com FR-008? [Consistência, Spec §FR-008] {auto}
- [x] CHK012 - A decisão de contar só prefixos não vazios é consistente entre Edge Cases e FR-002? [Consistência, Spec §Edge Cases, §FR-002] {auto}
- [x] CHK013 - O escopo (três lugares) não conflita com os itens fora de escopo listados em Premissas? [Consistência, Spec §Premissas] {auto}

## Cobertura de cenários e edge cases

- [x] CHK014 - Cada regra de validação (quantidade, `/`, controle, nome inválido, repetição) tem cenário de aceite? [Cobertura, Spec §US3] {auto}
- [x] CHK015 - O caso de prefixo iniciando com `-` ou contendo `@{` aparece na spec ou no plano? [Cobertura, Plan §Design] {auto}
- [x] CHK016 - Projeto que mantém os documentos por conta própria está coberto como não afetado? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK017 - Idempotência na segunda execução com a mesma chave está coberta? [Cobertura, Plan §Constitution Check VII] {auto}

## Segurança e fronteira de confiança

- [x] CHK018 - A validação ocorre antes de qualquer escrita e antes de o valor chegar a template ou shell? [Segurança, Spec §US3, §SC-003] {auto}
- [x] CHK019 - Caracteres de controle e separador de caminho são rejeitados explicitamente? [Segurança, Spec §FR-003] {auto}

## Dependências e premissas

- [x] CHK020 - A ausência de dependência nova e o padrão shell/shellcheck estão exigidos? [Dependências, Spec §FR-013] {auto}
- [x] CHK021 - O hotfix residual em `constitution.md.semente.tmpl` entra no escopo? [Assumption, Spec §FR-016, §SC-007] {humano} — resolvido pelo owner em D5 (entra no escopo; sem issue)
- [x] CHK022 - O escopo mínimo de cinco tipos fixos (sem tipo extra) atende o apetite do produto? [Assumption, Spec §FR-017] {humano} — resolvido pelo owner em D6 (cinco tipos ficam)

## Incremento D4-D6 (round 2)

- [x] CHK023 - O conjunto de caracteres do prefixo (`^[a-z0-9][a-z0-9._-]*$`) está definido de forma única e testável? [Clareza, Spec §FR-014] {auto}
- [x] CHK024 - A regra de FR-014 vale igualmente na validação do configurador e na Fase 1 da skill rito-dev? [Consistência, Spec §FR-014, §FR-015] {auto}
- [x] CHK025 - Valores com maiúscula, `;`, `$(`, `|` e início por `-`, `.` ou `_` têm cenário de recusa e saída citando a chave? [Cobertura, Spec §SC-006, §Edge Cases] {auto}
- [x] CHK026 - A troca de `hotfix/<slug>` na semente é mensurável (idêntica byte a byte com a chave ausente)? [Mensurabilidade, Spec §FR-016, §SC-007] {auto}
- [x] CHK027 - FR-017 é coerente com FR-001 (ordem fixa) e com o fora de escopo (`tipo=prefixo`)? [Consistência, Spec §FR-001, §FR-017] {auto}
- [x] CHK028 - A exclusão de `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` do FR-014 está declarada como fora de escopo? [Completude, Spec §Premissas] {auto}

## Notes

- Items `{auto}` resolvidos contra spec/plan; `{humano}` CHK021/CHK022 decididos pelo owner (D5/D6), sem reabrir.
- Gate requirement-coverage: 17/17 FRs cobertos (FR-014..FR-017 no round 2), 0 findings.
- Sem `[Gap]`/`[Ambiguity]`/`[Conflict]` abertos.
