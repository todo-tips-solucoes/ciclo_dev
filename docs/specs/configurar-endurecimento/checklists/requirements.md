# Requirements Checklist: endurecimento do configurador (branches e manifesto)

**Purpose**: validar a qualidade dos requisitos de segurança e de borda da feature, antes das tarefas.
**Created**: 2026-10-06
**Feature**: [spec.md](../spec.md)

## Regra de caracteres (US1)

- [x] CHK001 - O conjunto aceito está definido de forma verificável (regex) para as duas chaves? [Clareza, Spec §FR-001] {auto}
- [x] CHK002 - Os valores recusados que motivam a regra estão enumerados (`;`, `$(`, crase, `|`, espaço)? [Completude, Spec §SC-001] {auto}
- [x] CHK003 - O comportamento em cada modo (interativo, `--respostas`, `--atualizar`) está especificado? [Cobertura, Spec §FR-003] {auto}
- [x] CHK004 - O conteúdo mínimo da mensagem de recusa (chave e conjunto aceito) e o código de saída 1 estão definidos? [Clareza, Spec §FR-002] {auto}
- [x] CHK005 - A relação entre a nova regra e a validação de referência do Git está explícita (soma, não substituição)? [Consistência, Spec §Edge Cases, §FR-001] {auto}
- [x] CHK006 - Valor vazio e primeiro caractere `.`, `/` ou `-` têm tratamento definido? [Edge Cases, Spec §Edge Cases] {auto}
- [x] CHK007 - O requisito de "não gravar nada" na recusa é mensurável (ausência de gravação)? [Mensurabilidade, Spec §FR-003, §SC-001] {auto}

## Config existente e skill (US1/US2)

- [x] CHK008 - O tratamento de `cockpit.config` existente fora da regra (fail-closed, com orientação de correção) está definido? [Cenários, Spec §FR-004] {auto}
- [x] CHK009 - A ordem da conferência na skill (após ler o config, antes de qualquer comando) é inequívoca? [Clareza, Spec §FR-005] {auto}
- [x] CHK010 - Está proibido colar o valor recusado num comando para testá-lo? [Segurança, Spec §FR-005] {auto}
- [x] CHK011 - A regra da skill é a mesma do configurador, sem duplicar divergência (referência ao padrão de `PREFIXOS_BRANCH`)? [Consistência, Spec §Premissas] {auto}
- [x] CHK012 - O que fica fora de escopo (`REPO_REMOTO`, `CMD_*`) está declarado com motivo? [Dependências, Spec §Fora de escopo] {auto}

## Manifesto (US3)

- [x] CHK013 - A condição de não gravar (sem linha registrável e sem manifesto anterior) está livre de ambiguidade? [Clareza, Spec §FR-006] {auto}
- [x] CHK014 - A preservação do comportamento com manifesto anterior é requisito explícito? [Completude, Spec §FR-007] {auto}
- [x] CHK015 - A distinção entre "linha registrável" e "template pulado" está definida, inclusive para pulo por cópia da árvore principal? [Edge Cases, Spec §FR-008, §Edge Cases] {auto}
- [x] CHK016 - O critério de sucesso do manifesto é objetivamente medível (0 arquivos sob `.cockpit/`)? [Mensurabilidade, Spec §SC-003] {auto}

## Testes e critérios de aceite

- [x] CHK017 - O cenário de teste novo (número 21, posição antes do 11) e seu conteúdo mínimo estão especificados? [Completude, Spec §FR-009] {auto}
- [x] CHK018 - Há critério de não regressão (suíte existente e shellcheck)? [Critérios de Aceite, Spec §SC-004] {auto}
- [x] CHK019 - A aceitação positiva (`main`, `release/2026`) está coberta além dos recusados? [Cenários, Spec §SC-002] {auto}
- [x] CHK020 - Cada FR tem ao menos um cenário de aceite associado? [Gap, Spec §FR-006..FR-008] {auto} — FR-007/FR-008 cobertos pelas US3-2 e Edge Cases; FR-009 é o próprio teste.
- [ ] CHK021 - Valores com acento, maiúsculas ou comprimento extremo estão cobertos como recusados/aceitos? [Gap] {humano} — o regex em `LC_ALL=C` os trata, mas o limite de tamanho não é requisito; decidir se interessa.

## Notes

- `requirement-coverage.sh` ausente neste repositório; cobertura de cenários conferida manualmente (CHK020).
- Decisões D1/D2/D3 do owner são normativas; nenhum item as reabre.
- Único item `{humano}` aberto (CHK021) não bloqueia: sem requisito de tamanho máximo na spec.
