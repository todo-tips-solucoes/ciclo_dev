# Requirements Checklist: templates de governança do cockpit

**Purpose**: validar a qualidade dos requisitos da feature antes de gerar tarefas
**Created**: 2026-09-29
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - Os nove arquivos de saída estão enumerados com caminho de destino? [Completude, Spec §FR-001] {auto}
- [x] CHK002 - Os nove princípios obrigatórios estão listados por identificador? [Completude, Spec §FR-004] {auto}
- [x] CHK003 - Cada papel de agente tem as quatro seções obrigatórias definidas? [Completude, Spec §FR-009] {auto}
- [x] CHK004 - O conteúdo mínimo de `CLAUDE.md` (cinco ponteiros e parada no review) está especificado? [Completude, Spec §FR-007] {auto}
- [x] CHK005 - O conteúdo de `CICLO-GIT.md` (branches, commits, squash/merge, identidades) está especificado? [Completude, Spec §FR-008] {auto}

## Clareza

- [x] CHK006 - O comportamento do Princípio III para `ligado` e `desligado` está descrito sem ambiguidade? [Clareza, Spec §FR-005, Clarifications] {auto}
- [x] CHK007 - As trilhas de mudança do Princípio II estão definidas de forma fixa e verificável? [Clareza, Spec §Clarifications] {auto}
- [x] CHK008 - O formato de inserção de `IDENTIDADES` está definido? [Clareza, Spec §Clarifications] {auto}
- [x] CHK009 - "Placeholder residual" é mensurável (ausência de `{{`)? [Clareza, Spec §SC-001, US1] {auto}

## Consistência

- [x] CHK010 - A regra "integração = produção" é tratada de forma consistente entre constituição e rito? [Consistência, Spec §US1-4, FR-006] {auto}
- [x] CHK011 - FR-003 (só chaves conhecidas, sem opcionais) é consistente com o edge case de URLs ausentes? [Consistência, Spec §FR-003, Edge Cases] {auto}
- [x] CHK012 - O papel do implementador via `/feature-00c` é consistente com o Princípio IV da constituição do projeto? [Consistência, Spec §FR-009, Assumptions] {auto}

## Critérios de aceite e mensurabilidade

- [x] CHK013 - Cada FR tem ao menos um cenário ou critério de sucesso associado (gate de cobertura: 14/14)? [Mensurabilidade, Spec §FR-001..FR-014] {auto}
- [x] CHK014 - As 11 fases do rito têm critério de sucesso objetivo? [Mensurabilidade, Spec §SC-005] {auto}
- [x] CHK015 - Idempotência é verificável (0 arquivos alterados na segunda execução)? [Mensurabilidade, Spec §FR-014, SC-004] {auto}

## Edge cases e não-funcionais

- [x] CHK016 - O caso `BOARD` vazio está coberto com redação definida? [Cobertura, Spec §Edge Cases, Clarifications] {auto}
- [x] CHK017 - Caracteres especiais em comandos configurados têm tratamento definido? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK018 - Agnosticismo (sem valor de projeto real) tem verificador e meta numérica? [Não-funcional, Spec §FR-011, SC-003] {auto}
- [x] CHK019 - O idioma e a acentuação exigidos estão especificados? [Não-funcional, Spec §FR-012] {auto}

## Dependências e premissas

- [x] CHK020 - A premissa de que o conteúdo dos princípios é derivado das skills está registrada como inferência? [Premissa, Spec §Assumptions] {auto}
- [ ] CHK021 - O conteúdo genérico inferido para os Princípios II a VIII reflete o que o dono do produto pretende? [Assumption, Spec §Assumptions] {humano}
- [ ] CHK022 - A decisão de tratar o Princípio III em texto único (sem condicional no motor) é aceitável para o produto? [Assumption, Spec §Assumptions] {humano}

## Notes

- Gate `requirement-coverage.sh`: requirements=14 covered=14 errors=0.
- Itens `{humano}` (CHK021, CHK022) não bloqueiam o plano já ratificado no clarify; ficam para revisão do dono na PR.
- Nenhum `[Gap]`, `[Ambiguity]` ou `[Conflict]` aberto.
