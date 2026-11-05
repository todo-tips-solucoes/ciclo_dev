# Quickstart: rito-descoberta

Cenários de verificação. Os de construção (1 a 7) rodam na worktree, sem instalar nada
(Vigência). Os de smoke (8 a 11) são os S1 a S5 de `decisoes-do-owner.md`, rodados depois do merge
na sessão da árvore principal.

## Scenario 1: Formato do registro da Fase 0 (US1, FR-007, SC-001)

1. Rode a validação do contrato `contracts/decisoes-do-owner.md` sobre o
   `decisoes-do-owner.md` desta frente.
2. Rode de novo sobre uma cópia temporária sem o bloco ```` ```text ```` de "Caminhos previstos".
3. **Expected**: o passo 1 aprova os 14 títulos e os 7 caminhos. O passo 2 reprova (falha
   fechado) e nomeia a seção.

## Scenario 2: Nada é escrito antes do Gate 0 (US1, FR-005, SC-002)

1. Leia `skills/rito-descoberta/SKILL.md`, da ordem das etapas até o Gate 0.
2. **Expected**: antes do OK, a única escrita instruída é o `historico-<frente>.log` e o `.base`.
   O `decisoes-do-owner.md`, a worktree, o `cstk hooks install`, o `cstk mcp install` e as
   instalações vêm depois do OK.

## Scenario 3: Mapa e proibidos (US2, FR-008, SC-003)

1. Para cada `plugin:agente` do mapa da skill, confira:
   - que ele está no array `agents` do `plugin.json` do clone no SHA registrado;
   - que o `tools:` dele passa nas regras (a) e (c).
2. Confira que os nomes da regra (b) existem no catálogo.
3. **Expected**: 13 de 13 agentes aprovados e 2 de 2 nomes da regra (b) encontrados (a medição de
   controle de 2026-11-05 está em `research.md`, Decision 11).

## Scenario 4: Gates no `rito-dev` (US4, FR-015, FR-016)

1. `grep` em `skills/rito-dev/SKILL.md` e em `templates/docs/rito-dev.md.tmpl` por:
   - `rito-descoberta ausente: rode instalar.sh`;
   - a dispensa em docs, trivial e hotfix com incidente;
   - o gate de temporárias na Fase 11.
2. Confira que a description do `rito-dev` manda frente nova de trilha completa para
   `/rito-descoberta`.
3. **Expected**: os três achados nos dois arquivos. A Fase 11 impede o "Encerrar" com pendente ou
   com diferença contra a linha de base.

## Scenario 5: Auxiliar `historico.mjs` (FR-014, contrato `historico.md`)

1. Rode `node --check skills/rito-descoberta/historico.mjs`.
2. Rode `foto` duas vezes seguidas e faça `diff` das saídas.
3. Rode `pendentes` sobre um log de teste com um `install` temporário sem `uninstall`, e depois
   com o par completo.
4. Repita o passo 3 com o log ausente.
5. **Expected**: sintaxe ok; `diff` vazio no passo 2 (controle negativo); `pendentes` termina
   com 1 e depois com 0; com o log ausente, termina com 2.

6. Retomada (FR-022): com `.log` e `.base` existentes, tire foto nova e confira que a diferença
   vira `rodada` ou `desvio` e que a base não é recriada.

O log de teste fica no scratchpad da sessão, nunca em `~/.claude/cockpit`.

## Scenario 6: Templates continuam passando nos testes do configurador (FR-015, FR-018)

1. Rode `scripts/testar-configurar.sh` em primeiro plano, com timeout. Nada de laço em background.
2. `grep -Fx 'Instalação pelo agente: desligada'` no `docs/constitution.md` gerado de um projeto
   de teste.
3. **Expected**:
   - cenários 15 e 17 verdes;
   - princípios na ordem `II II-bis III IV IV-bis V VI VII VIII`;
   - nenhum `{{` residual;
   - a linha literal desligada presente.

## Scenario 7: Agnosticismo e caminhos previstos (Princípio I, FR-019, SC-007)

1. Rode `scripts/verificar-agnostico.sh`.
2. Liste os arquivos alterados:
   ```text
   git diff --name-only origin/main...HEAD
   ```
   Confira cada um contra os 7 caminhos previstos.
3. **Expected**: zero ocorrências no agnóstico e nenhum arquivo fora dos caminhos previstos.
   `docs/constitution.md` aparece no diff só pelo commit `bf2eb06` (emenda 2.0.0). Para
   confirmar que a construção não o editou de novo:
   ```text
   git log --format=%h origin/main..HEAD -- docs/constitution.md
   ```
   A saída precisa ser só `bf2eb06`.

> **Regra**: os Scenarios 8 a 11 (S1 a S5) só rodam depois do merge, com a instalação feita pelo
> owner. O agente não os executa durante a construção.

## Scenario 8: S1, cópia das skills (pós-merge)

1. Rode `diff -r` de `skills/rito-descoberta` e de `skills/rito-dev` da `main` contra
   `~/.claude/skills/`.
2. Faça `cp -r`.
3. Rode `diff -r` de novo.
4. **Expected**: o passo 1 mostra o que já estava instalado. O passo 3 sai vazio, e o `name:` do
   frontmatter está correto nas duas skills.

## Scenario 9: S2, catálogo e mapa (pós-merge)

1. Rode `git -C ~/.claude/plugins/marketplaces/voltagent-subagents rev-parse HEAD`.
2. Repita o Scenario 3.
3. **Expected**: o clone está limpo. HEAD igual ao último SHA conferido: o mapa vale. HEAD diferente:
   o mapa é reverificado no HEAD atual e o SHA novo vai ao registro (revisão de código de 2026-11-05, decisão do owner; ver `review-findings.md`).
   O mapa tem N > 0 citações, todas aprovadas.

## Scenario 10: S3, ciclo de instalação temporária (pós-merge)

1. Numa worktree descartável, tire a linha de base. Confirme que
   `voltagent-core-dev@voltagent-subagents` não está nela.
2. Instale pelo comando exato do item da seção "Instalações previstas".
3. Confira o estado ok e o `gitCommitSha`.
4. Desinstale com `-s project`, dentro da worktree.
5. Caso negativo: peça um plugin fora da lista; ele é recusado antes do `install`.
6. **Expected**:
   - a foto final é igual à linha de base nas linhas `plugin`, `enabled` e de cache, e a pasta do
     `core-dev` sumiu do cache;
   - o histórico tem o par install e uninstall;
   - `pendentes` termina com 0.

Risco conhecido (`research.md`, Decision 4): o install com `@marketplace` atualiza o catálogo
antes da busca. O SHA instalado é reverificado (mapa e conteúdo só de agentes); reprovado, o smoke
falha. A pasta de versão no cache, depois do uninstall, precisa sumir ou ter a marca `.orphaned_at`;
sem ela, é sobra e o smoke falha (revisão de código de 2026-11-05, decisão do owner; ver `review-findings.md`).

## Scenario 11: S5, guarda de escrita (pós-merge)

1. Tire a linha de base.
2. Crie `~/.claude/skills/_smoke_qa/x`.
3. Tire uma foto nova.
4. Remova o arquivo e tire outra foto.
5. **Expected**:
   - no passo 3, só a raiz `skills` muda: a diferença lista o arquivo, o log registra e o rito
     para por mudança não declarada;
   - no passo 4, a foto volta igual à linha de base;
   - duas fotos sem mudança entre elas dão iguais.
