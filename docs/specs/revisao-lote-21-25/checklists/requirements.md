# Requirements Checklist: Correções do code review retroativo do lote 21-25

**Purpose**: Gate de qualidade dos requisitos da frente (spec, plan, contracts, decisões do owner).
**Created**: 2026-11-04
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - Cada achado D1 a D7 das decisões do owner tem ao menos um FR correspondente? [Completude, Spec §FR-001..FR-010, decisoes-do-owner D1-D7] {auto}
- [x] CHK002 - Os casos de teste de D7 estão cobertos por um FR explícito (cenários 21-24)? [Completude, Spec §FR-010] {auto}
- [x] CHK003 - Há critério de aceite para cada user story prioritária (P1 a P3)? [Completude, Spec §User Stories 1-6] {auto}
- [x] CHK004 - As entidades (review, regra de checks, valor do cockpit.config) estão definidas? [Completude, Spec §Key Entities] {auto}
- [x] CHK005 - O requisito de FR-006 define o texto exato da orientação de renomear a branch? [Gap, Spec §FR-006] {auto} — fechado em contracts/passos.md (texto da linha nova do `--atualizar`)

## Clareza

- [x] CHK006 - "Regra ilegível" está definida por critério objetivo (código de saída diferente de 0)? [Clareza, Spec §FR-001] {auto}
- [x] CHK007 - A regra de validação de branch está dada como expressão literal? [Clareza, Spec §FR-005] {auto}
- [x] CHK008 - "Head atual do PR" está ligado a um campo verificável (`commit_id`)? [Clareza, Spec §FR-002] {auto}
- [x] CHK009 - A regra `RE_REPO` é referenciada a uma fonte única (`configurar.sh`) em vez de duplicada? [Clareza, Spec §FR-004] {auto}
- [x] CHK010 - "Comentário segue a Decision 3 da research" aponta para um artefato localizável? [Clareza, Spec §FR-008] {auto}

## Consistência

- [x] CHK011 - FR-003 (tirar aspas) precede FR-004/FR-005 (validar) na mesma ordem em ambas as skills? [Consistência, Spec §FR-003..FR-005] {auto}
- [x] CHK012 - FR-007 é coerente com FR-002 (check mais estrito que a opção nativa)? [Consistência, Spec §FR-002, FR-007] {auto}
- [x] CHK013 - A exclusão "branch com `/` fora da frente" é coerente com a regra de FR-005, que aceita `/`? [Conflict resolvido: leitura de regras com nome cru fica fora; validação de nome aceita `/`, Spec §Edge Cases, FR-005] {auto}

## Critérios de aceite e mensurabilidade

- [x] CHK014 - SC-001 é mensurável (100% dos casos de falha listam todos os vermelhos)? [Mensurabilidade, Spec §SC-001] {auto}
- [x] CHK015 - SC-002 exige que cada caso novo falhe sem a correção (teste de regressão real)? [Mensurabilidade, Spec §SC-002] {auto}
- [x] CHK016 - SC-004 tem limiar objetivo (zero findings de shellcheck/actionlint)? [Mensurabilidade, Spec §SC-004, FR-011] {auto}

## Cenários e edge cases

- [x] CHK017 - Reviews com estados mistos em commits diferentes estão cobertas? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK018 - Resposta 404 com corpo JSON no stdout está tratada? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK019 - Valor com aspas simples e sem aspas estão tratados? [Cobertura, Spec §Edge Cases, FR-003] {auto}
- [x] CHK020 - Aspas duplas ou aspas desbalanceadas no `cockpit.config` têm comportamento especificado? [Gap, Spec §FR-003] {auto} — fechado em spec.md (FR-003, Edge Cases)
- [x] CHK021 - Review `COMMENTED` como último estado de um usuário tem tratamento especificado? [Ambiguity, Spec §FR-002] {auto} — fechado em spec.md (FR-002, Edge Cases) e data-model.md

## Não funcionais, dependências e premissas

- [x] CHK022 - Restrições de shell (`set -euo pipefail`, `LC_ALL=C`, sem nova dependência) estão especificadas? [NFR, Spec §FR-011] {auto}
- [x] CHK023 - O requisito de idioma/acentuação e anonimato de projeto real está explícito? [NFR, Spec §FR-011] {auto}
- [x] CHK024 - A isenção de Delta Requirements tem justificativa e autoria? [Premissa, Spec §Delta Requirements] {auto}
- [x] CHK025 - As correções de FR-009 mantêm rastreio aos fatos medidos de D1/D6? [Dependência, Spec §FR-009] {auto}
- [ ] CHK026 - O trade-off de PARAR (falhar fechado) versus seguir com aviso quando o valor está fora da regra reflete o apetite de risco do owner? [Risco, Spec §FR-004, FR-005] {humano} — confirmado nas decisões D4/D5; revisão do owner na PR (plan.md, Riscos)
