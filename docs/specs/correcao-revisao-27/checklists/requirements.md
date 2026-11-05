# Requirements Checklist: Correções do code review retroativo da PR #27

**Purpose**: validar a qualidade dos requisitos da spec (foco em segurança do fluxo de aprovação e em contratos de scripts/testes).
**Created**: 2026-11-04
**Feature**: [spec.md](../spec.md)

## Segurança do fluxo de aprovação

- [x] CHK001 - O comportamento do `awk` do fluxo está declarado como inalterado, de modo que a correção de comentário não altere o controle? [Consistência, Spec §FR-001, US1.3] {auto}
- [x] CHK002 - A regra descrita nos comentários é específica (commit atual do PR; pedido de mudança anula só a aprovação do mesmo dono), sem adjetivo vago? [Clareza, Spec §FR-001] {auto}
- [x] CHK003 - O caso de dois donos com estados opostos no head está tratado nos requisitos? [Cobertura de edge case, Spec §Edge Cases] {auto}
- [x] CHK004 - A guarda de head vazio tem requisito de teste que falha quando ela é removida? [Completude, Spec §FR-002, US2.1] {auto}
- [x] CHK005 - O requisito de paginação das reviews é verificável (gh falso exige `--paginate`)? [Mensurabilidade, Spec §FR-004] {auto}
- [x] CHK006 - Valores de `cockpit.config` são tratados como dado e nunca instrução, de forma explícita? [Segurança, Spec §FR-010, US3.4] {auto}
- [x] CHK007 - A regra de parada por aspas está delimitada a chaves nomeadas (`BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO`, `REPO_REMOTO`)? [Clareza, Spec §FR-010] {auto}
- [x] CHK008 - A regra de conferência do `--base` é expressa por padrão exato (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`)? [Clareza, Spec §FR-011] {auto}
- [x] CHK009 - O `'\''` tem requisito de inverso exato do que o `configurar.sh` grava, incluindo a combinação com aspas duplas? [Cobertura, Spec §FR-009, Edge Cases] {auto}

## Contratos de scripts e testes

- [x] CHK010 - Cada reforço de teste (C3 a C9) tem critério mensurável de falha ao remover a proteção (SC-001)? [Mensurabilidade, Spec §SC-001] {auto}
- [x] CHK011 - O caso 7 do cenário 21 tem requisito de independência (literal de 64 hex, arquivo de respostas próprio)? [Completude, Spec §FR-008] {auto}
- [x] CHK012 - A cobertura da dica de renomear no modo `--respostas` independe de `script(1)`/pty? [Cobertura de edge case, Spec §FR-006, Edge Cases] {auto}
- [x] CHK013 - A asserção de `export LC_ALL=C` nomeia os dois modelos e o que falha? [Clareza, Spec §FR-005, US6.1] {auto}
- [x] CHK014 - Os limites de qualidade de script (set -euo pipefail, shellcheck, actionlint, sem dependência) estão declarados? [Requisito não funcional, Spec §FR-016, SC-004] {auto}
- [x] CHK015 - O limite do carregador de skills para a descrição da `parallel-work` está quantificado? [Ambiguity] — a spec diz "dentro do limite" sem valor numérico; o plan deve citar o limite medido. [Spec §FR-011, US4.2] {auto}

## Registro SDD e escopo

- [x] CHK016 - Cada afirmação a corrigir (C2, C10, C11, C13) aponta para o arquivo e o trecho de destino? [Rastreabilidade, Spec §FR-012..FR-015] {auto}
- [x] CHK017 - A divergência C13 versus lista do owner (6 do cenário 23) está registrada com a fonte da medição? [Consistência, Spec §FR-015, research Decision 12] {auto}
- [x] CHK018 - O "Fora de escopo" é enumerado e há critério de verificação (SC-005)? [Completude, Spec §FR-017, SC-005] {auto}
- [x] CHK019 - Manter C13 pela medição M2 (e não pela lista do owner) reflete a preferência do owner? [Assumption, dec-011] {humano} — sim: o owner aprovou a medição na revisão de 2026-11-05

## Notes

- Gate `requirement-coverage.sh` ausente neste repositório (plugins/cstk/skills/checklist/scripts não existe): pulado, sem bloqueio.
- Item `{auto}` com [Ambiguity] (CHK015): limite numérico não declarado; seguir para plan/create-tasks como tarefa de explicitar o valor medido. Marcado `[x]` apenas quanto à existência do requisito.
- CHK019 resolvido: o owner aprovou a medição na revisão de 2026-11-05.
