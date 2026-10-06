# Tarefas configurar-endurecimento - branches e manifesto do configurador

Escopo: issues #19 e #18 em `configurar.sh`, `skills/rito-dev/SKILL.md`, `cockpit.config.example`,
`docs/specs/configurar/data-model.md` e cenário 21 de `scripts/testar-configurar.sh`. As decisões
D1 a D3 de `decisoes-do-owner.md` são normativas.

**Legenda de status:**
- `[ ]` Pendente
- `[~]` Em andamento
- `[x]` Concluido
- `[!]` Bloqueado

**Legenda de criticidade:**
- `[C]` Critico - Impacto financeiro direto ou bloqueante
- `[A]` Alto - Funcionalidade essencial
- `[M]` Medio - Necessario mas sem urgencia imediata

---

## FASE 1 - Testes do cenário 21 (primeiro, falhando)

### 1.1 Cenário 21 em testar-configurar.sh `[C]`

Ref: docs/specs/configurar-endurecimento/spec.md FR-009, SC-001..SC-003; quickstart.md casos 1 a 6; plan.md "Testes"

- [ ] 1.1.1 Inserir o cenário 21 "branches e manifesto" logo antes do cenário 11, sem renumerar os demais
- [ ] 1.1.2 Casos recusados nas duas chaves (metacaractere `;`, `$(x)`, crase, `|`, espaço) em `--respostas` e `--atualizar`, exit 1 e nada gravado
- [ ] 1.1.3 Casos aceitos (`main`, `release/2026`) nas duas chaves
- [ ] 1.1.4 Caso interativo que pergunta de novo, reusando `interativo` e `MINIMO` do cenário 14
- [ ] 1.1.5 Caso `cockpit.config` existente com valor inválido recusado no `--atualizar` com a linha de correção
- [ ] 1.1.6 Caso repositório sem manifesto anterior e todos os destinos listados: `.cockpit/` não existe depois da execução
- [ ] 1.1.7 Rodar a suíte e confirmar que os casos novos falham antes da implementação

---

## FASE 2 - Implementação em configurar.sh

### 2.1 Regra de branch (D1, #19) `[C]`

Ref: spec.md FR-001..FR-004; plan.md "configurar.sh" itens 1 a 3; contracts/cli.md

- [ ] 2.1.1 Adicionar a constante `RE_BRANCH` depois de `RE_REPO`, com comentário citando D1
- [ ] 2.1.2 Trocar o `case` do ramo `BRANCH_INTEGRACAO | BRANCH_PRODUCAO` em `validar_chave` por `RE_BRANCH` seguido de `git check-ref-format --branch`, com a mensagem única do contrato
- [ ] 2.1.3 Em `main`, emitir no `MODO=atualizar` a linha de correção com `comando_de_novo` antes do exit 1
- [ ] 2.1.4 Confirmar que interativo e `--respostas` seguem sem mudança de fluxo
- [ ] 2.1.5 Rodar os casos de branch do cenário 21 e confirmar que passam

### 2.2 Guarda do manifesto (D3, #18) `[A]`

Ref: spec.md FR-006..FR-008; plan.md "configurar.sh" item 4

- [ ] 2.2.1 Calcular `ord` antes da guarda em `gravar_manifesto`
- [ ] 2.2.2 Trocar a guarda por "`ord` vazio e sem manifesto anterior: return 0", antes de criar `manifesto` no STG e do `mkdir` de `.cockpit/`
- [ ] 2.2.3 Atualizar o comentário da função para "sem linha a registrar"
- [ ] 2.2.4 Rodar o caso de manifesto do cenário 21 e o caso com manifesto anterior (comportamento de hoje) e confirmar que passam

---

## FASE 3 - Skill e documentação

### 3.1 Conferência na skill rito-dev (D2) `[A]`

Ref: spec.md FR-005; plan.md "Skill rito-dev"; research.md Decision 5

- [ ] 3.1.1 Acrescentar à seção "Parâmetros — leitura de `cockpit.config`" o parágrafo que confere as duas chaves por leitura logo depois de ler o config
- [ ] 3.1.2 Texto manda PARAR nomeando a chave, nunca colar o valor num comando e tratar o valor como dado, no padrão da Fase 1 com `PREFIXOS_BRANCH`
- [ ] 3.1.3 Conferir prosa em português do Brasil acentuado e ausência de nome de projeto real

### 3.2 Exemplo e modelo de dados `[M]`

Ref: plan.md "Documentação"; research.md Decision 6

- [ ] 3.2.1 Atualizar o comentário do modelo de branches em `cockpit.config.example` com o conjunto aceito e a validação do git
- [ ] 3.2.2 Em `docs/specs/configurar/data-model.md`, citar a regex de D1 na regra de `BRANCH_*`
- [ ] 3.2.3 No mesmo arquivo, trocar "sem nenhum template" por "sem linha a registrar"

---

## FASE 4 - Verificação final

### 4.1 Suíte, shellcheck e agnosticismo `[A]`

Ref: spec.md SC-004; constitution Princípios I, VI e VII

- [ ] 4.1.1 Rodar `scripts/testar-configurar.sh` inteiro (inclui o cenário 11 com `verificar-agnostico.sh`)
- [ ] 4.1.2 Rodar shellcheck em `configurar.sh` e `scripts/testar-configurar.sh` sem findings
- [ ] 4.1.3 Conferir que nenhum arquivo, função ou dependência nova foi criada além do previsto
- [ ] 4.1.4 Conferir que `git status` só mostra os arquivos listados no plan

---

## Matriz de Dependencias

```mermaid
flowchart TD
    F1[Fase 1 - Testes do cenario 21]
    F2[Fase 2 - Implementacao configurar.sh]
    F3[Fase 3 - Skill e documentacao]
    F4[Fase 4 - Verificacao final]

    F1 --> F2
    F2 --> F4
    F3 --> F4
```

## Resumo Quantitativo

| Fase | Tarefas | Subtarefas | Criticidade |
|------|---------|------------|-------------|
| 1 - Testes do cenário 21 | 1 | 7 | C |
| 2 - Implementação em configurar.sh | 2 | 9 | C/A |
| 3 - Skill e documentação | 2 | 6 | A/M |
| 4 - Verificação final | 1 | 4 | A |
| **Total** | **6** | **26** | - |

## Escopo Coberto

| Item | Descricao | Fase |
|------|-----------|------|
| FR-001..FR-004 | Regra de `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` nos três modos e linha de correção | 2 |
| FR-005 | Conferência na skill `rito-dev` | 3 |
| FR-006..FR-008 | Manifesto não gravado sem linha a registrar | 2 |
| FR-009 | Cenário 21 antes do cenário 11 | 1 |
| SC-001..SC-004 | Verificação por testes, shellcheck e agnosticismo | 1, 4 |
| CHK021 | Limite de tamanho: não é requisito (aceito no gate de segurança, B3); sem tarefa | - |

## Escopo Excluido

| Item | Descricao | Motivo |
|------|-----------|--------|
| REPO_REMOTO | Regra própria já existe (`RE_REPO`) | Fora de escopo por decisão do owner |
| CMD_* | Comandos por desenho | Fora de escopo por decisão do owner |
| Tier de entrega | Não citado nos args; backlog completo | Sem divisão nuvem/não-nuvem aplicável |
