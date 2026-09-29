# Tarefas Configurar - Configurador do projeto-alvo

Escopo: entregar `configurar.sh` (perguntas ou arquivo de respostas,
gravação de `cockpit.config`, motor de templates com manifesto de hashes,
provisionamento de guard hooks via `cstk`), a lib `scripts/lib/versao.sh`, o
template de prova, o script de teste, o job de CI e o registro das 3 chaves
novas. Decomposição de [plan.md](./plan.md) + [research.md](./research.md) +
[data-model.md](./data-model.md) + [contracts/cli.md](./contracts/cli.md) +
[quickstart.md](./quickstart.md) + [spec.md](./spec.md) FR-001..FR-021, com os
gaps de [checklists/requirements.md](./checklists/requirements.md): CHK023
vira a tarefa 4.2 (Princípio V); CHK024, CHK025 e CHK018 (`{humano}`) viram a
tarefa 6.1 (itens de decisão do owner, levados na descrição da PR).

**Legenda de status:**
- `[ ]` Pendente
- `[~]` Em andamento
- `[x]` Concluído
- `[!]` Bloqueado

**Legenda de criticidade:**
- `[C]` Crítico - Impacto financeiro direto ou bloqueante
- `[A]` Alto - Funcionalidade essencial
- `[M]` Médio - Necessário mas sem urgência imediata

---

## FASE 1 - Fundação: lib de versão e formato do config

### 1.1 Extrair `scripts/lib/versao.sh` de `instalar.sh` `[A]`

Ref: plan.md §Structure Decision, research.md Decision 10, spec.md FR-014

- [ ] 1.1.1 Criar `scripts/lib/versao.sh` com `versao_ge` e `ler_cstk_min` movidas de `instalar.sh`, sem alterar comportamento
- [ ] 1.1.2 Alterar `instalar.sh` para carregar a lib (`source` por caminho relativo ao próprio script)
- [ ] 1.1.3 Teste: `instalar.sh` continua passando nos cenários existentes e no shellcheck

### 1.2 Registrar as 3 chaves novas no formato `[A]`

Ref: spec.md FR-002/FR-003, research.md Decision 4, data-model.md

- [ ] 1.2.1 Acrescentar `IDENTIDADES`, `BOARD` e `PRINCIPIO_III` a `cockpit.config.example`, com valores entre aspas simples e nomes fictícios
- [ ] 1.2.2 Registrar as 3 chaves em `docs/specs/skills-do-cockpit/data-model.md` como extensão retrocompatível
- [ ] 1.2.3 Ajustar `skills/rito-dev/SKILL.md` (nota de valores entre aspas; remover a afirmação de que não há tabela de identidades)
- [ ] 1.2.4 Teste: `source cockpit.config.example` em bash puro com `set -u` sem erro; `verificar-agnostico.sh` sem ocorrências

---

## FASE 2 - Núcleo: leitura, validação e gravação do config (US1, US5)

### 2.1 Esqueleto de `configurar.sh` e parsing de opções `[C]`

Ref: contracts/cli.md, spec.md FR-008/FR-016/FR-019/FR-021

- [ ] 2.1.1 Criar `configurar.sh` com `set -euo pipefail`, `uso` e opções `--projeto`, `--respostas`, `--atualizar`, `--forcar`
- [ ] 2.1.2 Implementar `resolver_raiz`: exige raiz de repositório git, usa `pwd -P`, recusa subdiretório e diretório sem git (exit 1)
- [ ] 2.1.3 Implementar `ler_config` sem `source`/`eval` (research Decision 2), aceitando aspas simples e duplas

### 2.2 Validação de chaves `[C]`

Ref: data-model.md §Validação, spec.md FR-004/FR-005/FR-018

- [ ] 2.2.1 Implementar `validar_chave` (`org/repo`, nomes de branch, comandos não vazios, URL opcional, recusa de quebra de linha e caractere de controle)
- [ ] 2.2.2 Aceitar `BRANCH_PRODUCAO` igual a `BRANCH_INTEGRACAO` sem aviso
- [ ] 2.2.3 Validar `IDENTIDADES` (ao menos uma; converter `nome <email>` em `nome:email`; avisar, sem recusar, e-mail não `noreply`)

### 2.3 Perguntas interativas e modo não interativo `[C]`

Ref: spec.md FR-001/FR-004/FR-006/FR-016, research.md Decision 5

- [ ] 2.3.1 Implementar `perguntar`, repetindo a pergunta em valor inválido e oferecendo o valor atual como padrão quando o config já existe
- [ ] 2.3.2 Implementar `perguntar_identidades` isolada em uma função (FR-018 é proposta pendente; a troca por nome e e-mail separados deve ficar restrita a ela)
- [ ] 2.3.3 Implementar `--respostas`: mesmo formato do config, falha citando a chave faltante, variáveis de ambiente não são fonte
- [ ] 2.3.4 Implementar `--atualizar`: sem perguntas, exit 1 com mensagem clara se não houver config

### 2.4 Gravação atômica do `cockpit.config` `[C]`

Ref: research.md Decisions 3 e 7, spec.md FR-002/FR-017

- [ ] 2.4.1 Implementar `gravar_config` com aspas simples, ordem fixa e sem data, em temporário no mesmo diretório + `mv`; `trap` limpa temporários
- [ ] 2.4.2 Recusar `cockpit.config` de destino que seja link simbólico
- [ ] 2.4.3 Teste: cenários 1, 3 e 9 do quickstart (config do zero, `--atualizar`, validação)

---

## FASE 3 - Motor de templates, manifesto e contenção (US2, US3)

### 3.1 Motor de render `[C]`

Ref: research.md Decisions 1 e 9, spec.md FR-009/FR-010/FR-011

- [ ] 3.1.1 Implementar `renderizar` em awk (`index()`/`substr()`, valor via `ENVIRON`), placeholder `{{[A-Z][A-Z0-9_]*}}` somente
- [ ] 3.1.2 Descobrir templates com `find -type f` sob `templates/`; destino = mesmo caminho relativo sem o sufixo `.tmpl`
- [ ] 3.1.3 Recusar placeholder residual: listar arquivo e placeholder, exit 2, sem deixar arquivo nem temporário no projeto
- [ ] 3.1.4 Criar template de prova `templates/.cockpit/LEIAME.md.tmpl`, genérico e sem conteúdo de projeto real (FR-012)

### 3.2 Contenção, manifesto e edição local `[C]`

Ref: research.md Decisions 6, 7 e 8, spec.md FR-007/FR-015

- [ ] 3.2.1 Implementar `destino_contido` (`pwd -P` + prefixo; checagem refeita imediatamente antes de cada `mv`; recusa de destino link simbólico)
- [ ] 3.2.2 Implementar manifesto `.cockpit/manifesto.sha256` (`sha256sum` ou `shasum -a 256`), gravado a cada renderização
- [ ] 3.2.3 Implementar `aplicar_render`: arquivo com hash diferente do manifesto é edição local, preservado com exit 2 e aviso citando `--forcar`; `--forcar` sobrescreve e atualiza o manifesto
- [ ] 3.2.4 Renderizar tudo em temporários e só então mover, para nenhuma interrupção deixar estado parcial
- [ ] 3.2.5 Teste: cenários 2, 4, 5, 6, 7 e 8 do quickstart

---

## FASE 4 - Provisionamento de hooks (US4)

### 4.1 `provisionar_hooks` `[A]`

Ref: research.md Decision 10, spec.md FR-013/FR-014, plan.md §Constitution Check (IV)

- [ ] 4.1.1 Como último passo, checar `cstk --version` contra `CSTK_MIN` lido de `versoes.env` via `scripts/lib/versao.sh`
- [ ] 4.1.2 Com `cstk` presente e no piso, executar `cstk hooks install --project-path <raiz>`; nunca copiar hooks
- [ ] 4.1.3 Com `cstk` ausente ou abaixo do piso: manter config e templates, imprimir `Execute:` e o comando oficial, exit 3; nenhuma instalação, atualização ou bootstrap de terceiro
- [ ] 4.1.4 Teste: cenário 10 do quickstart, com `cstk` falso no `PATH`

### 4.2 Registrar a fonte oficial de `cstk hooks install` (CHK023) `[A]`

Ref: checklists/requirements.md CHK023, plan.md §Constitution Check (V), research.md Decision 10, constitution Princípio V

- [ ] 4.2.1 Ler a documentação oficial do `cstk hooks install` via `context-mode` e registrar o link e a data em `research.md` Decision 10
- [ ] 4.2.2 Conferir o comportamento observado em `--help` contra a documentação; se divergir, ajustar `provisionar_hooks` e o contrato
- [ ] 4.2.3 Marcar CHK023 como atendido em `checklists/requirements.md` com a referência à fonte

---

## FASE 5 - Testes, CI e qualidade estática

### 5.1 `scripts/testar-configurar.sh` `[A]`

Ref: research.md Decision 11, quickstart.md, spec.md SC-001..SC-007

- [ ] 5.1.1 Criar o script (bash, sem framework), cada cenário em repositório git temporário limpo ao final
- [ ] 5.1.2 Reunir os 11 cenários do quickstart e sair diferente de zero na primeira falha, dizendo qual cenário falhou
- [ ] 5.1.3 Teste: rodar limpo em máquina sem `cstk` real (o `cstk` é sempre o falso do teste)

### 5.2 Job de CI e gates estáticos `[A]`

Ref: plan.md §Source Code, spec.md SC-006/FR-019/FR-020

- [ ] 5.2.1 Acrescentar o job `configurar` em `.github/workflows/ci.yml`, sem `pull_request_target` e com actions fixadas por SHA conforme o padrão existente
- [ ] 5.2.2 Rodar shellcheck em `configurar.sh`, `scripts/lib/versao.sh`, `scripts/testar-configurar.sh` e `instalar.sh` com 0 findings
- [ ] 5.2.3 Rodar `scripts/verificar-agnostico.sh` sobre todos os artefatos novos com 0 ocorrências
- [ ] 5.2.4 Executar `bmad-code-review` sobre o diff antes da PR (Princípio II)

---

## FASE 6 - Fechamento e decisões do owner

### 6.1 Itens de decisão do owner na descrição da PR `[M]`

Ref: checklists/requirements.md CHK018/CHK024/CHK025, research.md Decision 5, spec.md FR-018/SC-001

- [ ] 6.1.1 Pedir ao owner a ratificação de FR-018 (`nome <email>` na pergunta versus nome e e-mail separados) na descrição da PR (CHK024, dec-020)
- [ ] 6.1.2 Pedir ao owner a confirmação do apetite de risco: aviso versus recusa para e-mail não `noreply` (CHK025)
- [ ] 6.1.3 Pedir ao owner o método de medição de SC-001 ("menos de 5 minutos") (CHK018)
- [ ] 6.1.4 Atualizar o histórico/briefing do projeto se a feature alterar algum item registrado

---

## Matriz de Dependências

```mermaid
flowchart TD
    F1[Fase 1 - Fundação]
    F2[Fase 2 - Núcleo do config]
    F3[Fase 3 - Motor e manifesto]
    F4[Fase 4 - Hooks]
    F5[Fase 5 - Testes e CI]
    F6[Fase 6 - Fechamento]

    F1 --> F2
    F2 --> F3
    F3 --> F4
    F3 --> F5
    F4 --> F5
    F5 --> F6
```

## Resumo Quantitativo

| Fase | Tarefas | Subtarefas | Criticidade |
|------|---------|------------|-------------|
| 1 - Fundação | 2 | 7 | A |
| 2 - Núcleo do config | 4 | 13 | C |
| 3 - Motor e manifesto | 2 | 9 | C |
| 4 - Hooks | 2 | 7 | A |
| 5 - Testes e CI | 2 | 7 | A |
| 6 - Fechamento | 1 | 4 | M |
| **Total** | **13** | **47** | - |

## Escopo Coberto

| Item | Descrição | Fase |
|------|-----------|------|
| FR-002/FR-003 | Formato do `cockpit.config` e 3 chaves novas | 1, 2 |
| FR-001/FR-004/FR-005/FR-016/FR-018 | Perguntas, validação e modo não interativo | 2 |
| FR-006/FR-007/FR-008/FR-017 | Idempotência, edição local, `--atualizar` e atomicidade | 2, 3 |
| FR-009..FR-012/FR-015 | Motor de templates, template de prova e contenção | 3 |
| FR-013/FR-014 | Provisionamento de hooks e piso do `cstk` | 4 |
| FR-019/FR-020/FR-021 | Portabilidade, agnosticismo e pt-BR | 5 |
| CHK018/CHK023/CHK024/CHK025 | Gaps do checklist | 4, 6 |

## Escopo Excluído

| Item | Descrição | Motivo |
|------|-----------|--------|
| Templates de governança e automação | Templates dos itens 4 e 5 do MVP | Frentes seguintes; esta feature entrega só o motor e um template de prova (FR-012) |
| Instalação de terceiros | Instalar ou atualizar `cstk` ou outra ferramenta | Princípio IV: só se imprime o comando oficial |
