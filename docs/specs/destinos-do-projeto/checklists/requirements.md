# Requirements Checklist: destinos do projeto no configurar.sh

**Purpose**: validar a qualidade dos requisitos (cli, segurança, testes) antes de `create-tasks`; não verifica implementação.
**Created**: 2026-10-05
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - O formato da chave `DESTINOS_DO_PROJETO` (relativo à raiz, separado por espaço, igual a destino de template) está definido? [Completude, Spec §FR-001] {auto}
- [x] CHK002 - Estão definidos os efeitos do destino listado sob `--forcar`, modo interativo e manifesto? [Completude, Spec §FR-002, §FR-003] {auto}
- [x] CHK003 - O texto de saída de cada resultado novo (`mantido (projeto)`, `copiado da árvore principal`, `mantido (ignorado pelo git)`) e a ordem das contagens estão especificados? [Completude, contracts/cli.md §Saída] {auto}
- [x] CHK004 - A mensagem de conflito alterada (D2) está especificada literalmente, sem mudar o exit 2? [Completude, Spec §FR-008, contracts/cli.md §stderr] {auto}
- [x] CHK005 - Os avisos de origem recusada e de árvore principal indisponível têm texto e frequência (uma vez por execução) definidos? [Completude, contracts/cli.md §stderr] {auto}
- [x] CHK006 - A documentação a atualizar (`cockpit.config.example`, uso, contrato e modelo de dados da feature `configurar`) está enumerada? [Completude, Spec §FR-007, plan.md §Configuração e documentação] {auto}

## Clareza

- [x] CHK007 - "Item vazio" está definido de forma não ambígua (só aspas), distinto de espaços repetidos e de valor em branco? [Clareza, Spec §Edge Cases] {auto}
- [x] CHK008 - "Worktree vinculada" e "ignorado pelo git" estão ligados a comandos verificáveis (`rev-parse` e `check-ignore -q`)? [Clareza, Spec §FR-009] {auto}
- [x] CHK009 - "Árvore principal" está definida (primeira entrada de `worktree list --porcelain`, recusando bare) sem depender de suposição? [Clareza, Spec §FR-009, research.md Decision 7] {auto}
- [x] CHK010 - "Mesmas guardas de contenção do destino" é concretizado em mecanismo nomeado (`exigir_contido` antes e depois do `mkdir -p`)? [Clareza, plan.md §Riscos] {auto}

## Consistência

- [x] CHK011 - FR-002/FR-005 (listado nunca gerado, mesmo semente ausente) são coerentes com a linha 1 da tabela de regra do contrato? [Consistência, Spec §FR-005, contracts/cli.md §Regra] {auto}
- [x] CHK012 - A recusa de origem link simbólico (Clarifications) é refletida em FR-009, Edge Cases, contrato e data-model sem contradição? [Consistência, Spec §Edge Cases, data-model.md] {auto}
- [x] CHK013 - Nenhum requisito reabre D1, D2 ou D3 nem inclui prefixos de branch ou conflito por arquivo? [Consistência, Spec §Fora de escopo] {auto}
- [x] CHK014 - A mudança de 18 para 19 respostas no modo interativo está registrada como intencional e consistente com FR-007? [Consistência, plan.md §Riscos] {auto}

## Segurança (fronteira de confiança)

- [x] CHK015 - As entradas inválidas (absoluto, `..`, só aspas, controle) são enumeradas, com exit 1 e "antes de qualquer escrita"? [Segurança, Spec §FR-006] {auto}
- [x] CHK016 - É exigido que a árvore principal seja só lida e que a escrita fique no projeto-alvo? [Segurança, Spec §FR-012] {auto}
- [x] CHK017 - A cópia só ocorre após as checagens de residual e conflito, para que a recusa do lote (exit 2) não deixe cópia feita? [Segurança, plan.md §Riscos] {auto}
- [x] CHK018 - O risco de troca da origem por link entre checagem e `cp` está declarado como aceito, com limite documentado? [Segurança, research.md Riscos aceitos] {auto}

## Cobertura de cenários e edge cases

- [x] CHK019 - Há cenário de aceite para cada comportamento de FR-001 a FR-011 (US1 a US4)? [Cobertura, Spec §Acceptance Scenarios] {auto}
- [x] CHK020 - Idempotência (2ª passada mantém a cópia) e criação do diretório-pai estão cobertas? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK021 - A compatibilidade (sem chave e fora de worktree, saída byte a byte igual) é mensurável e protegida pelos cenários 1 a 17? [Mensurabilidade, Spec §FR-011, plan.md §Riscos] {auto}
- [x] CHK022 - Os critérios SC-001 a SC-003 são objetivamente verificáveis (cenários passam, shellcheck sem findings, sem dependência nova)? [Mensurabilidade, Spec §Success Criteria] {auto}

## Testes (construção do cenário 19)

- [ ] CHK023 - [Gap] A construção do repositório bare do cenário 19 com `cp -R .git` + `core.bare true` está bem fundamentada? A research (Decision 10) e o quickstart (§14) só citam "sem rede"; o argumento de que o bash-guard bloquearia a clonagem não procede dentro do script: o bash-guard é hook PreToolUse que só inspeciona o comando digitado pelo agente, e comandos executados dentro de `scripts/testar-configurar.sh` (CI e execução direta) não passam por ele. Além disso, copiar `.git` e forçar `core.bare` depende da estrutura interna do git (`worktrees/`, `index`, `HEAD` apontando para branch em checkout). O requisito de teste deve preferir `git clone --bare` de caminho local (sem rede) dentro do script, ou `git init --bare` + push de um commit, seguido de `git worktree add`. Destino: `/create-tasks` (tarefa de ajuste em research Decision 10, quickstart §14 e no cenário 19). [Gap, research.md Decision 10, quickstart.md §14] {auto}
- [x] CHK024 - O cenário 19 exige commits com identidade explícita (`-c user.*`, sem gpgsign) e `.gitignore` commitado, sem depender da máquina? [Completude, research.md Decision 10] {auto}

## Julgamento do dono

- [ ] CHK025 - Aceitar que um item de `DESTINOS_DO_PROJETO` sem template correspondente seja só aviso (não erro) reflete o apetite de risco do produto? Já fixado em D1; só reconfirmar se surgir erro de digitação recorrente. [Risco, Spec §FR-006] {humano}

## Notes

- Resolução: 23 itens `{auto}` resolvidos com evidência (`[x]`) e 1 `[Gap]` (CHK023); 1 `{humano}` (CHK025) aguardando.
- CHK023 vira tarefa em `/create-tasks`; nenhum `[Ambiguity]`/`[Conflict]` aberto.
- O gate `requirement-coverage.sh` não existe neste projeto (script do plugin ausente); a cobertura FR→cenário foi conferida manualmente em CHK019.
