# Requirements Checklist: configurar

**Purpose**: Validar a qualidade dos requisitos de `configurar.sh` (completude, clareza, consistência, cobertura) antes de gerar tarefas.
**Created**: 2026-09-28
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - Cada pergunta do configurador tem chave e regra de validação definidas? [Completude, Spec §FR-001, §FR-004; data-model §Validação] {auto}
- [x] CHK002 - O formato do `cockpit.config` e as chaves novas estão especificados, incluindo retrocompatibilidade? [Completude, Spec §FR-002, §FR-003] {auto}
- [x] CHK003 - O comportamento sem `templates/` (nenhum template) está definido? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK004 - O ponto exato da checagem do `cstk` e o que permanece gravado em caso de falha estão definidos? [Completude, Spec §FR-013, §FR-014] {auto}
- [x] CHK005 - Está definido o que acontece com interrupção (Ctrl-C) durante a gravação? [Cobertura, Spec §FR-017, §Edge Cases] {auto}
- [x] CHK006 - O contrato de linha de comando (opções, códigos de saída) está documentado? [Completude, contracts/cli.md] {auto}

## Clareza

- [x] CHK007 - A sintaxe do placeholder é inequívoca, com regra para texto entre chaves fora do padrão? [Clareza, Spec §FR-009] {auto}
- [x] CHK008 - "Editado à mão" é definido de forma verificável (hash do manifesto)? [Clareza, Spec §FR-007] {auto}
- [x] CHK009 - A representação de board não usado e de identidades é sem ambiguidade (`BOARD=""`, `nome:email;…`)? [Clareza, Spec §FR-003] {auto}
- [x] CHK010 - A fonte do modo não interativo é única e exclui variáveis de ambiente? [Clareza, Spec §FR-016] {auto}
- [x] CHK011 - "Comando oficial exato" do `cstk` tem origem indicada (piso em `versoes.env`, nunca repetido)? [Clareza, Spec §FR-014] {auto}

## Consistência

- [x] CHK012 - Branch de integração = produção é tratado igual em US1, FR-005 e no Check de Princípio I do plan? [Consistência, Spec §US1-3, §FR-005; plan §Constitution Check] {auto}
- [x] CHK013 - A ordem "gravar config → renderizar → hooks por último" é a mesma em FR-013, FR-014 e US4? [Consistência, Spec §FR-013, §FR-014, §US4] {auto}
- [x] CHK014 - A obrigatoriedade de ≥1 identidade (Edge Cases, FR-018) é coerente com o Princípio III e com `IDENTIDADES` opcional para `rito-dev`? [Consistência, Spec §FR-003, §FR-018] {auto}
- [x] CHK015 - O texto do plan diz que `skills/rito-dev/SKILL.md` muda só nas notas mínimas, coerente com FR-003 (retrocompatível)? [Consistência, plan §Source Code] {auto}

## Critérios de aceite e mensurabilidade

- [x] CHK016 - Cada FR tem ao menos um cenário de aceite associado? [Mensurabilidade, gate requirement-coverage.sh: requirements=21 covered=21 errors=0] {auto}
- [x] CHK017 - SC-001 (< 5 min) é mensurável e SC-002/SC-003/SC-004 são contagens objetivas? [Mensurabilidade, Spec §SC-001–SC-004] {auto}
- [ ] CHK018 - SC-001 ("menos de 5 minutos") tem método de medição definido? [Ambiguity, Spec §SC-001] {humano}

## Cobertura de edge cases e segurança

- [x] CHK019 - Caminhos hostis (`..`, symlink, diretório não git) estão cobertos por requisito e critério? [Cobertura, Spec §FR-015, §SC-007, §Edge Cases] {auto}
- [x] CHK020 - Valores com caracteres especiais e valores com quebra de linha/controle têm tratamento definido? [Cobertura, Spec §FR-011; plan §Superfície de segurança] {auto}
- [x] CHK021 - Config existente com chave ausente/desconhecida e config de outro projeto estão cobertos? [Cobertura, Spec §Edge Cases] {auto}

## Dependências, premissas e princípios

- [x] CHK022 - Português do Brasil com acentuação e agnosticismo verificável são requisitos testáveis? [Completude, Spec §FR-020, §FR-021, §SC-006] {auto}
- [ ] CHK023 - Princípio V: a fonte oficial de `cstk hooks install` (doc oficial, lida via `context-mode`) está registrada? [Gap, plan §Constitution Check (V), research Decision 10] {auto}
- [ ] CHK024 - FR-018: a conciliação da pergunta `nome <email>` com a gravação `nome:email` foi ratificada pelo owner? [Conflict, Spec §FR-018; plan §Decisões e pendências; dec-020] {humano}
- [ ] CHK025 - O aviso (sem recusa) para e-mail não `noreply` reflete o apetite de risco do owner, versus recusar? [Risco, Spec §FR-018] {humano}

## Notes

- CHK023 é `[Gap]` de implementação: vira tarefa "registrar a fonte oficial do cstk (hooks install)" no backlog (Princípio V).
- CHK024/CHK025/CHK018 `{humano}` ficam abertos; CHK024 deve virar pedido de confirmação na descrição da PR.
- Gate `requirement-coverage.sh` sobre a spec: exit 0, 0 findings.
