# Requirements Checklist: rito-descoberta

**Purpose**: Qualidade dos requisitos da spec (completude, clareza, consistencia, mensurabilidade).
**Created**: 2026-11-05
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - Cada etapa da Fase 0 (decisoes, telas, coleta, Gate 0, gravacao, entrega) tem ao menos um FR? [Completude, Spec §FR-001, FR-003, FR-004, FR-005, FR-006] {auto}
- [x] CHK002 - Os caminhos tocaveis e a proibicao de instalar na construcao estao em requisito proprio? [Completude, Spec §FR-019] {auto}
- [x] CHK003 - O formato do `decisoes-do-owner.md` (titulos, bloco de caminhos, Irreversibilidade) esta especificado? [Completude, Spec §FR-007] {auto}
- [x] CHK004 - Ha requisito para o gate do rito-dev na Fase 1 e na Fase 11? [Completude, Spec §FR-015, FR-016] {auto}
- [x] CHK005 - O padrao "desligada" da semente de constitution esta especificado? [Completude, Spec §FR-018] {auto}

## Clareza

- [x] CHK006 - A classificacao de plugins enumera todos os estados e os filtros (`scope`, `projectPath`)? [Clareza, Spec §FR-009] {auto}
- [x] CHK007 - Os proibidos de instalacao estao listados de forma enumerada e nao vaga? [Clareza, Spec §FR-011] {auto}
- [x] CHK008 - O limite de 500 caracteres da descricao do `/feature-00c` esta quantificado? [Clareza, Spec §FR-006] {auto}
- [x] CHK009 - A fonte da linha "Instalacao pelo agente" (`origin/<base>`, nao a worktree) esta inequivoca? [Clareza, Spec §FR-013] {auto}
- [ ] CHK010 - "Ruido conhecido" do fingerprint do historico e definido (lista ou criterio)? [Ambiguity, Spec §Edge Cases, FR-014] {auto}

## Consistencia

- [x] CHK011 - FR-005 (nada escrito antes do Gate 0) e consistente com FR-014 (historico) pela excecao D9 declarada? [Consistencia, Spec §FR-005, FR-014] {auto}
- [x] CHK012 - FR-012 (nunca remover o ja instalado) e consistente com o proibido de `--prune` na research? [Consistencia, Spec §FR-012, research Decision 5] {auto}
- [x] CHK013 - FR-019 (emenda 2.0.0 so referenciada) e consistente com o escopo de caminhos tocaveis incluindo `docs/constitution.md`? [Consistencia, Spec §FR-019] {auto}

## Criterios de aceite

- [x] CHK014 - Cada SC tem valor mensuravel (100%, 0 itens, 0 arquivos)? [Mensurabilidade, Spec §SC-001..SC-007] {auto}
- [x] CHK015 - O SC-004 cobre a pasta de cache, alem do estado de plugins? [Mensurabilidade, Spec §SC-004] {auto}
- [x] CHK016 - Todos os FR tem cenario associado segundo o gate de cobertura? [Cobertura, gate requirement-coverage: requirements=21 covered=21 errors=0] {auto}
- [ ] CHK017 - O SC-005 define como o gate encontra o par install/uninstall no log (chave de correspondencia)? [Gap, Spec §SC-005] {auto}

## Edge cases e fontes

- [x] CHK018 - Ha tratamento para linha de base ausente (falha fechada) e fonte oficial indisponivel? [Edge Case, Spec §Edge Cases] {auto}
- [x] CHK019 - Os dados factuais da CLI tem origem rastreavel e pendencia explicita (Principio VI)? [Rastreabilidade, Spec §FR-020, research Decision 5] {auto}
- [ ] CHK020 - Ha requisito para sessao interrompida no meio da Fase 0 (retomada do historico)? [Gap, Spec §FR-014] {auto}

## Julgamento do owner

- [ ] CHK021 - A regra "instalacao global temporaria: uma por vez entre frentes paralelas" e suficiente como controle de concorrencia? [Risco, Spec §Edge Cases] {humano}
- [ ] CHK022 - A dispensa do gate em docs, trivial e hotfix com incidente reflete o apetite de risco do owner? [Risco, Spec §FR-015] {humano}

## Notes

- Gaps abertos: CHK010 (ambiguidade, vai a decisao do plan/tasks, sem editar decisoes-do-owner.md), CHK017 e CHK020 (viram tarefas de especificacao em `/create-tasks`).
- Itens `{humano}` ficam `[ ]` ate o owner.
