# Security Checklist: Modo autônomo de merge por projeto

**Purpose**: validar a qualidade dos requisitos de segurança e governança do modo autônomo (trava de caminhos previstos, identidade, ruleset, irreversíveis).
**Created**: 2026-11-05
**Feature**: [spec.md](../spec.md)

## Fonte da verdade e fail-closed

- [x] CHK001 - O valor ausente, inválido ou duplicado da linha `Merge autônomo:` tem resultado definido (`desligado`)? [Completude, Spec §US1 cenário 4, FR-001, FR-003] {auto}
- [x] CHK002 - Está especificado de onde o modo é lido (base de integração) e quando é relido (antes de cada merge e promoção)? [Clareza, Spec §FR-003, Edge Cases] {auto}
- [x] CHK003 - A proibição de o agente editar a linha/chave está formulada de modo verificável (MUST NOT + trava de governança)? [Clareza, Spec §FR-004, Edge Cases] {auto}
- [x] CHK004 - O requisito de degradar para `desligado` quando identidade ou ruleset falham cobre merge e promoção? [Cobertura, Spec §FR-005, Edge Cases] {auto}
- [x] CHK005 - O cockpit está explicitamente excluído do modo (sem a linha)? [Completude, Spec §FR-026] {auto}

## Trava de caminhos previstos

- [x] CHK006 - Os casos de reprova (fora da lista, renomeação, total divergente, governança, manifesto) estão enumerados? [Completude, Spec §FR-009] {auto}
- [x] CHK007 - O teto de listagem da API tem tratamento definido (total diferente de `changed_files` reprova)? [Edge Case, Spec §FR-009, Edge Cases] {auto}
- [x] CHK008 - Está definido que a trava lê o plano da base e não da PR sob análise, e que não executa código da PR? [Consistência, Spec §FR-007, FR-008] {auto}
- [x] CHK009 - A forja de status por job homônimo é coberta por requisito de fonte fixada? [Cobertura, Spec §FR-008, Edge Cases] {auto}
- [x] CHK010 - A aprovação de dono no commit atual, com reexecução, está especificada para PR sem registro/governança? [Clareza, Spec §FR-010] {auto}
- [x] CHK011 - A PR para a produção (A1 do block-001) tem requisito próprio, e a promoção é a única exceção? [Completude, Spec §FR-011, US2 cenário 6] {auto}
- [x] CHK012 - A lista de governança da spec inclui a config do semantic-release (`.releaserc*`, `release.config.*`, chave `release`) e todo `decisoes-do-owner.md` (A2/F1)? [Gap, Spec §FR-009 diz "etc." sem citar A2/F1; só o plan §linha 219 os traz] [Resolvido pela tarefa 1.1] {auto}
- [x] CHK013 - O token de automação (`TOKEN_AUTOMACAO`) tem escopo mínimo especificado como requisito (A2), não só como obrigatoriedade? [Gap, Spec §FR-019 exige o token mas não define o escopo; plan §linha 146 sim] [Resolvido pela tarefa 1.2] {auto}
- [x] CHK014 - "Acréscimo puro em `permissions.deny`" é definido de forma objetiva (o que conta como puro)? [Ambiguity, Spec §US2 cenário 3, FR-009] [Resolvido pela tarefa 1.4] {auto}
- [x] CHK015 - A divergência entre a linha 140 de `decisoes-do-owner.md` (D4: "promoção fora da trava") e FR-011 (A1) está resolvida no registro normativo? [Conflict, Spec §FR-011 vs decisoes-do-owner.md:140; só o owner emenda] {humano} — resolvido pelo owner (dec-029, 2026-11-06)

## Identidade, ruleset e merge

- [x] CHK016 - Os privilégios da identidade do agente estão listados (Contents e Pull requests; sem Administration/Workflows; token fora do repo)? [Clareza, Spec §FR-005] {auto}
- [x] CHK017 - Os checks obrigatórios do ruleset estão nomeados (`ci`, `commitlint`, `caminhos-previstos`) e a ausência de bypass é exigida? [Completude, Spec §FR-012] {auto}
- [x] CHK018 - `--admin`, push direto e status forjado têm cenário de aceite de recusa? [Cobertura, Spec §US3 cenário 4, FR-012] {auto}
- [x] CHK019 - Está delimitado que o configurador só imprime a configuração e não cria identidade/ruleset? [Clareza, Spec §FR-006] {auto}
- [x] CHK020 - O modo de checagem de "sem bypass" (qual endpoint/campo do GitHub é a evidência) é especificado? [Gap, Spec §FR-005, FR-012 não definem a fonte da conferência] [Resolvido pela tarefa 1.3] {auto}

## Falhas, irreversíveis e rollback

- [x] CHK021 - Os limites de correção (2) e o gatilho do 3º vermelho têm contagem definida (SHAs distintos; rerun não conta)? [Mensurabilidade, Spec §FR-014, FR-015] {auto}
- [x] CHK022 - A parada do revert com conflito ou CI vermelho está definida, evitando laço? [Edge Case, Spec §FR-016, SC-004] {auto}
- [x] CHK023 - Irreversibilidade diferente de "Nenhuma" e smoke manual param no gate humano na promoção? [Completude, Spec §FR-017, FR-018] {auto}
- [x] CHK024 - O smoke tem formato, comparação (substring literal) e caso negativo obrigatório? [Mensurabilidade, Spec §FR-017, Clarifications] {auto}
- [x] CHK025 - O rollback de produção (revert da promoção, da culpada e do revert do revert) está sequenciado? [Completude, Spec §FR-020] {auto}
- [x] CHK026 - Há requisito para o caso "culpada não isolável" além de "reverte o lote" (ex.: lote com frente irreversível já promovida)? [Ambiguity, Spec §FR-020] {humano} — resolvido pelo owner (dec-029, 2026-11-06)

## Barreira de plugins e agentes proibidos

- [x] CHK027 - A falha fechada para symlink e `installPath` fora do cache está especificada? [Completude, Spec §FR-021, US7 cenário 3] {auto}
- [x] CHK028 - Os critérios da lista fechada (`.in_use/`, `.orphaned_at`, `.md` na raiz) são objetivos e testáveis? [Mensurabilidade, Spec §FR-022] {auto}
- [x] CHK029 - A mescla de deny é idempotente e reexecutada no gate da Fase 11 e em SHA divergente? [Consistência, Spec §FR-023] {auto}
- [x] CHK030 - A parada do rito quando a regra deny não bloqueia no smoke está nos requisitos? [Cobertura, Spec §FR-023, Edge Cases] {auto}

## Critérios de aceite e risco residual

- [x] CHK031 - Os critérios de sucesso de segurança são mensuráveis (100% dos negativos param; 0 arquivos fora do previsto)? [Mensurabilidade, Spec §SC-002, SC-006, SC-007] {auto}
- [x] CHK032 - O requisito de não introduzir dependência nova está ligado a um critério verificável? [Rastreabilidade, Spec §FR-027, SC-007] {auto}
- [x] CHK033 - O risco residual de `extends` apontando para arquivo local (R17) é aceito no nível de spec? [Assumption, plan §linha 297; ausente da spec] {humano} — resolvido pelo owner (dec-029, 2026-11-06)
- [x] CHK034 - O apetite de risco de promover sem leitura humana em projetos com dados de produção é aceito pelo owner? [Risco, Spec §Contexto] {humano} — resolvido pelo owner (dec-029, 2026-11-06)

## Notes

- Items `{auto}` resolvidos pelo agente (`[x]` com citação, ou marcador `[Gap]`/`[Ambiguity]`/`[Conflict]`).
- Items `{humano}` ficam `[ ]` aguardando o dono do produto.
- Gate `requirement-coverage.sh`: requirements=27 covered=27 errors=0.
- Gaps (CHK012, CHK013, CHK014, CHK020): destino `/create-tasks` (ajuste de texto da spec) ou `/clarify` para CHK014.
- CHK015: a emenda da linha 140 do `decisoes-do-owner.md` cabe só ao owner; não editar.
