# API/Contrato Checklist: templates-automacao

**Purpose**: Qualidade dos requisitos do contrato dos arquivos gerados e do render pelo `configurar.sh`
**Created**: 2026-09-30
**Feature**: [spec.md](../spec.md)

## Render e chaves

- [x] CHK001 - Cada template tem caminho de destino definido (mesmo caminho sem `.tmpl`)? [Completude, Spec §FR-001, §Key Entities] {auto}
- [x] CHK002 - O conjunto de chaves permitidas nos templates está fechado (quinze atuais + `DONOS_CODEOWNERS`, sem `URL_AMBIENTE_*`)? [Clareza, Spec §FR-003] {auto}
- [x] CHK003 - A regra que separa `{{CHAVE}}` de `${{ expr }}` está escrita e testável? [Clareza, Spec §Edge Cases, §FR-017, Clarifications] {auto}
- [x] CHK004 - A mudança permitida no `configurar.sh` está delimitada (só FR-015, motor intocado)? [Consistência, Spec §FR-002, §FR-015] {auto}
- [x] CHK005 - A migração de config antiga sem `DONOS_CODEOWNERS` está definida? [Edge Case, Spec §Edge Cases] {auto}
- [x] CHK006 - Os formatos aceitos e recusados de `BOARD` e `DONOS_CODEOWNERS` são objetivos? [Mensurabilidade, Spec §FR-015, Quickstart Cenários 5–6] {auto}
- [x] CHK007 - A idempotência da segunda execução (conteúdo e modo) tem critério mensurável? [Mensurabilidade, Spec §SC-004, §FR-014] {auto}

## Contrato dos fluxos

- [x] CHK008 - O nome de cada check é estável e igual entre contrato e quickstart (`ci`, `commitlint`, `aprovacao-de-dono`)? [Consistência, Contracts §Regras comuns, Quickstart §Validação manual] {auto}
- [x] CHK009 - O `promotion-pr` define o caso "PR já existe" (atualiza) e o caso branches iguais (no-op com sucesso)? [Cobertura, Spec §FR-008, Contracts §promotion-pr] {auto}
- [x] CHK010 - A deduplicação da issue de auditoria está definida (uma por merge)? [Clareza, Spec §FR-009, Contracts §audit-merge-vermelho] {auto}
- [x] CHK011 - O comportamento para `GERENCIADOR_PACOTES` fora de npm/pnpm/yarn/bun está definido? [Edge Case, Spec §FR-005, Research Decision 10] {auto}
- [x] CHK012 - A coerência com `PRINCIPIO_III` nos dois valores está explícita? [Consistência, Spec §FR-020] {auto}
- [x] CHK013 - A versão fixada de `semantic-release` (`<pin>`) tem fonte e critério de escolha definidos? Hoje o contrato deixa o placeholder. [Gap, Contracts §release, Princípio V] {auto}

## Contrato do `task.sh`

- [x] CHK014 - Cada modo de falha tem código de saída próprio (2, 3, 4)? [Completude, Contracts §task.sh] {auto}
- [x] CHK015 - O formato de saída de `discover` e `list` está especificado? [Clareza, Contracts §task.sh] {auto}
- [x] CHK016 - Está definido o que `move` faz quando o nome de status não existe no board ou o item não está no projeto (mensagem e código)? [Gap, Spec §FR-013, Contracts §task.sh] {auto}

## Idioma

- [x] CHK017 - Prosa e mensagens em pt-BR com diacríticos têm requisito explícito? [Completude, Spec §FR-018] {auto}

## Notes

- `requirement-coverage.sh` sobre spec.md: 20/20 FRs com cenário, 0 erros.
- CHK013 resolvido em research §Pins (P1, P2); CHK016 resolvido em contracts §task.sh (mensagens e código 1 de `move`).
