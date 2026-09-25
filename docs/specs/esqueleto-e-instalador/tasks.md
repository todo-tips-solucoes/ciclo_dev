# Tarefas Esqueleto do cockpit-dev - Instalador de máquina + verificação de agnosticismo + CI

Escopo: `instalar.sh` (preparo de máquina, 7 etapas), `scripts/verificar-agnostico.sh`
(varredura de termos proibidos) e `.github/workflows/ci.yml` (shellcheck + agnostico +
segredos) — itens 1 e 6 do MVP do briefing. Deriva de
[spec.md](./spec.md) + [plan.md](./plan.md) + [research.md](./research.md) +
[data-model.md](./data-model.md) + [contracts/cli.md](./contracts/cli.md), com os gaps
abertos de [checklists/security.md](./checklists/security.md) e
[checklists/ux-ops.md](./checklists/ux-ops.md) consumidos na FASE 1.

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

## FASE 1 - Fundação e Requisitos

### 1.1 Resolver gaps de comportamento revelados pelo checklist `[A]`

Ref: checklists/ux-ops.md CHK010, CHK011

- [x] 1.1.1 Adicionar Edge Case explícito e Acceptance Scenario em spec.md, mais
      cenário correspondente em quickstart.md, cobrindo falha por ausência de
      permissão de escrita na área de configuração — definindo o mecanismo que
      impede estado parcial (ex.: pré-checagem de escrita como parte da etapa 1,
      ou escrita atômica por etapa) (CHK010-ux-ops)
- [x] 1.1.2 Adicionar Acceptance Scenario/cenário de quickstart cobrindo
      instalação seletiva de plugin ausente sem reinstalar o que já está correto
      (CHK011-ux-ops)
- [x] 1.1.3 Validar que o mecanismo escolhido em 1.1.1 é implementável dentro do
      confinamento de escrita já definido (FR-011, `~/.claude/` e `~/.local/`
      apenas) antes de codificar a etapa correspondente na FASE 2

### 1.2 Resolver gaps de redação/documentação revelados pelo checklist `[M]`

Ref: checklists/security.md CHK005, CHK012

- [x] 1.2.1 Declarar em plan.md/research.md o comportamento do binário
      `gitleaks` diante de arquivo binário (fonte oficial lida, ou lacuna
      declarada explicitamente — nunca suposição) (CHK012-security)
- [x] 1.2.2 Revisar a redação de SC-006 em spec.md para refletir o limite
      "regex + entropia, não prova de ausência" já registrado em plan.md
      §Risco residual aceito item 3, evitando a leitura de garantia absoluta
      (CHK005-security)
- [!] 1.2.3 Registrar decisão sobre feedback de progresso do `instalar.sh`
      durante etapas potencialmente demoradas — silêncio-até-o-fim vs. saída
      incremental — e documentar a escolha em plan.md (CHK012-ux-ops)
      `{decisão do dono do produto}` — **bloqueado em block-002/dec-034**,
      aguardando resposta do operador (onda-007)

### 1.3 Scaffolding de diretórios e arquivos de dados versionados `[A]`

Ref: plan.md §Project Structure; data-model.md

- [x] 1.3.1 Criar diretório `scripts/` com `scripts/agnostico.lista` (cabeçalho
      de comentários explicando o formato, zero termos ativos — FR-015,
      data-model §Lista de termos proibidos)
- [x] 1.3.2 Criar `.gitleaks.toml` na raiz (cabeçalho de comentário, zero
      allowlists ativas — FR-021, data-model §Exceção de varredura de segredo)
- [x] 1.3.3 Criar `.gitleaksignore` na raiz (cabeçalho de comentário, zero
      exceções ativas — FR-021)
- [x] 1.3.4 Confirmar que `versoes.env` já existente atende ao formato exigido
      (`CSTK_MIN=10.8.0`, chave única versionada) — sem alteração necessária,
      só validação (data-model §Piso de versão do `cstk`). Validado
      empiricamente: `grep -cE '^[A-Z_]+=.+$' versoes.env` → 1 linha de chave,
      `CSTK_MIN=10.8.0`, formato `CHAVE=valor` conforme especificado.

---

## FASE 2 - `instalar.sh` (pipeline de preparo de máquina)

### 2.1 Etapa 1 — Pré-requisitos de máquina `[A]`

Ref: spec.md FR-001; plan.md §Arquitetura de `instalar.sh` (etapa 1);
data-model.md §Pré-requisito de máquina; quickstart.md Scenario 2

- [ ] 2.1.1 Implementar checagem de presença de `git`, `gh`, `node`, `jq`,
      `curl` no `PATH`
- [ ] 2.1.2 Implementar comparação de versão mínima para `git` (>=2.36) e
      `node` (>=20) por campo numérico, sem `sort -V` (research Decision 4)
- [ ] 2.1.3 Acumular TODOS os ausentes/abaixo-do-mínimo antes de reportar —
      nunca parar no primeiro (Edge Case da spec)
- [ ] 2.1.4 Encerrar com `exit 2` e mensagem listando todos os faltantes,
      antes de tentar qualquer instalação subsequente
- [ ] 2.1.5 Teste: reproduzir quickstart Scenario 2 (dois ou mais
      pré-requisitos ausentes simultaneamente)

### 2.2 Etapas 2-4 — Instalação/atualização e conferência de piso do `cstk` `[A]`

Ref: spec.md FR-002, FR-003, FR-004, FR-005; contracts/cli.md §Comandos
externos invocados; research Decision 1, Decision 2

- [ ] 2.2.1 Implementar detecção de `cstk` ausente → baixar o instalador
      oficial para arquivo temporário e só então executar (nunca
      `curl | sh` direto — controle de segurança, plan §Superfície de
      Segurança)
- [ ] 2.2.2 Implementar `cstk` presente → `cstk self-update`, sempre antes de
      qualquer comparação de piso (ordem não-negociável — research Decision 2)
- [ ] 2.2.3 Implementar checagem `cstk --version` responde (FR-005) — falhar
      com mensagem clara se não responder, `exit 1`
- [ ] 2.2.4 Implementar leitura de `CSTK_MIN` a partir de `versoes.env` por
      parse explícito (`grep`/`cut`), nunca `source` (controle de segurança —
      plan §Superfície de Segurança)
- [ ] 2.2.5 Implementar comparação da versão instalada contra `CSTK_MIN`,
      falhando com mensagem citando versão instalada e piso exigido
      (`exit 1`)
- [ ] 2.2.6 Teste: reproduzir quickstart Scenario 3 (atualiza antes de
      conferir), Scenario 4 (abaixo do piso) e Scenario 5 (`cstk` não
      responde)

### 2.3 Etapas 5-7 — Catálogo, skills do cockpit e plugins `[A]`

Ref: spec.md FR-006, FR-007, FR-008, FR-009; research Decision 12, 13, 14;
contracts/cli.md §Comandos externos invocados

- [ ] 2.3.1 Implementar `cstk install` (1ª vez) / `cstk update` (demais) para
      o catálogo de skills
- [ ] 2.3.2 Implementar cópia idempotente de `skills/` → `~/.claude/skills/`
      com comparação de conteúdo (research Decision 14: ausente → copia;
      idêntico → no-op reportando `ja atualizada`; diverge → avisa e reporta
      `atualizada (havia edicao local)`), tratando `skills/` inexistente como
      etapa `pulada` (research Decision 13)
- [ ] 2.3.3 Implementar registro do marketplace + instalação do plugin
      obrigatório `context-mode` pelos canais oficiais (`claude plugin
      marketplace add` / `claude plugin install`), sem `--accept-command`
      automático (controle de segurança)
- [ ] 2.3.4 Implementar instalação/atualização do plugin recomendado
      `ponytail` — falha reportada apenas no status individual desse item,
      nunca falha o comando inteiro (FR-008)
- [ ] 2.3.5 Capturar explicitamente o status de cada etapa não-fatal (`set -e`
      é a principal armadilha — research Decision 12): usar
      `comando || status=falhou` em vez de deixar o script abortar antes do
      relatório
- [ ] 2.3.6 Recusar execução como root/`sudo` antes de qualquer etapa
      (controle de segurança — plan §Superfície de Segurança)
- [ ] 2.3.7 Teste: reproduzir quickstart Scenario 1 (happy path), Scenario 6
      (idempotência), Scenario 7 (plugin recomendado falha) e Scenario 11
      (confinamento de escrita, `HOME` temporário)

### 2.4 Relatório final e códigos de saída `[A]`

Ref: spec.md FR-009, FR-012; contracts/cli.md §Saída — relatório final,
§Códigos de saída; data-model.md §Item de relatório

- [ ] 2.4.1 Implementar acumulação de item de relatório por etapa (`nome`,
      `status` ok/falhou/pulada, `detalhe`, `bloqueante`)
- [ ] 2.4.2 Implementar impressão do relatório final no formato pt-BR
      especificado em contracts/cli.md §Saída
- [ ] 2.4.3 Implementar os três códigos de saída distintos (`0` nenhum
      bloqueante falhou; `1` algum bloqueante falhou; `2` pré-requisitos
      ausentes ou abaixo do mínimo)
- [ ] 2.4.4 Teste: confirmar que toda mensagem autoral está em pt-BR sem
      tocar na saída nativa de ferramentas externas (FR-012, Clarifications
      Q3)

---

## FASE 3 - `scripts/verificar-agnostico.sh`

### 3.1 Implementação da varredura de agnosticismo `[A]`

Ref: spec.md FR-013, FR-014, FR-015, FR-016; plan.md §Arquitetura de
`scripts/verificar-agnostico.sh`; contracts/cli.md; data-model.md §Lista de
termos proibidos; research Decision 6, 7, 8

- [ ] 3.1.1 Ler `scripts/agnostico.lista` (`#` comenta, linhas em branco
      ignoradas — research Decision 8)
- [ ] 3.1.2 Enumerar arquivos versionados via `git ls-files`, excluindo
      `scripts/agnostico.lista` da própria varredura (research Decision 7)
- [ ] 3.1.3 Casar por substring literal case-insensitive (`grep -i -F`),
      reportando `arquivo:linha` por ocorrência
- [ ] 3.1.4 Implementar os três códigos de saída: `0` zero ocorrências
      (inclui lista vazia/só comentários); `1` uma ou mais ocorrências
      listadas; `2` erro de uso (`scripts/agnostico.lista` ausente ou fora de
      um repositório git)
- [ ] 3.1.5 Teste: reproduzir quickstart Scenario 8 (repositório limpo) e
      Scenario 9 (termo plantado é apontado com arquivo e linha)

---

## FASE 4 - CI do cockpit (`.github/workflows/ci.yml`)

### 4.1 Workflow base e job `shellcheck` `[A]`

Ref: spec.md FR-017; plan.md §CI do cockpit, §Superfície de Segurança;
contracts/cli.md §Workflow de CI; research Decision 9

- [ ] 4.1.1 Criar `.github/workflows/ci.yml` com gatilho `pull_request` e
      `push` para `main` — **nunca** `pull_request_target`
- [ ] 4.1.2 Declarar `permissions: contents: read` no nível do workflow
      (CICD-SEC-2)
- [ ] 4.1.3 Fixar Actions de terceiro por SHA de commit, nunca tag móvel
      (A03, CICD-SEC-8)
- [ ] 4.1.4 Job `shellcheck`: instalar `shellcheck` explicitamente no job
      (não assumir pré-instalado no runner) e rodar sobre todo `.sh` do
      repositório (FR-017)
- [ ] 4.1.5 Teste: reproduzir quickstart Scenario 10, passos 1-2 (script com
      problema de portabilidade conhecido barra o job `shellcheck`
      especificamente)

### 4.2 Job `agnostico` `[A]`

Ref: spec.md FR-018; contracts/cli.md §Workflow de CI

- [ ] 4.2.1 Job `agnostico`: executar `./scripts/verificar-agnostico.sh`
      (FR-018)
- [ ] 4.2.2 Confirmar que o job falha quando o script retorna `exit 1`,
      barrando a mudança
- [ ] 4.2.3 Teste: reproduzir quickstart Scenario 10, passos 3-4 (termo
      proibido introduzido barra o job `agnostico` especificamente)

### 4.3 Job `segredos` `[A]`

Ref: spec.md FR-019, FR-020, FR-021; plan.md §CI do cockpit — job `segredos`
em detalhe; contracts/cli.md §Job `segredos`; research Decision 15

- [ ] 4.3.1 Baixar o binário do `gitleaks` (release fixada por versão,
      `linux_x64`) e conferir contra o `checksums.txt` publicado ao lado —
      nunca a Action de terceiro
- [ ] 4.3.2 Invocar `gitleaks dir . --redact` (`--redact` **obrigatória**,
      nunca omitida — FR-019 exige não reproduzir o valor detectado)
- [ ] 4.3.3 Confirmar leitura por default de `.gitleaks.toml` e
      `.gitleaksignore` da raiz, sem flags `-c`/`-i` explícitas no workflow
- [ ] 4.3.4 Implementar os códigos de saída do job: `0` nenhum achado; `1`
      um ou mais achados ou erro de execução (barra a mudança); `126` flag
      desconhecida (erro de uso do workflow)
- [ ] 4.3.5 Teste: reproduzir quickstart Scenario 10 completo, passos 5-10
      (segredo de teste barra o job apontando arquivo/linha sem reproduzir o
      valor; registro do fingerprint em `.gitleaksignore` libera a PR)

---

## FASE 5 - Testes e Validação Final

### 5.1 Execução completa dos cenários de quickstart `[A]`

Ref: quickstart.md Scenario 1-11

- [ ] 5.1.1 Rodar Scenario 1 (happy path) numa máquina limpa/simulada e
      confirmar relatório final com todos os itens `[ok]`
- [ ] 5.1.2 Rodar Scenario 11 (confinamento de escrita, `HOME` temporário) e
      confirmar zero escrita fora de `~/.claude/` e `~/.local/`, em
      particular zero escrita em qualquer diretório de projeto-alvo
- [ ] 5.1.3 Rodar `shellcheck` localmente sobre os três scripts antes de abrir
      PR — mesma ferramenta e critério do job `shellcheck` do CI
- [ ] 5.1.4 Confirmar via `requirement-coverage.sh` que `spec.md` continua com
      100% dos FRs cobertos por cenário após qualquer ajuste feito durante
      esta fase (mesmo gate já rodado em checklists/security.md)

---

## Matriz de Dependências

```mermaid
flowchart TD
    F1[Fase 1 - Fundação e Requisitos]
    F2[Fase 2 - instalar.sh]
    F3[Fase 3 - verificar-agnostico.sh]
    F4[Fase 4 - CI do cockpit]
    F5[Fase 5 - Testes e Validação Final]

    F1 --> F2
    F1 --> F3
    F2 --> F4
    F3 --> F4
    F4 --> F5
```

## Resumo Quantitativo

| Fase | Tarefas | Subtarefas | Criticidade |
|------|---------|------------|-------------|
| 1 - Fundação e Requisitos | 3 | 10 | A, M |
| 2 - `instalar.sh` | 4 | 22 | A |
| 3 - `verificar-agnostico.sh` | 1 | 5 | A |
| 4 - CI do cockpit | 3 | 13 | A |
| 5 - Testes e Validação Final | 1 | 4 | A |
| **Total** | **12** | **54** | - |

## Escopo Coberto

| Item | Descrição | Fase |
|------|-----------|------|
| FR-001..FR-012 | `instalar.sh` completo: pré-requisitos, instalação/atualização do `cstk`, piso de versão, catálogo, skills do cockpit, plugins, relatório final, idempotência, confinamento de escrita, mensagens em pt-BR | 2 |
| FR-013..FR-016 | `scripts/verificar-agnostico.sh`: varredura de termos proibidos, lista versionada separada, idempotência | 3 |
| FR-017..FR-021 | `.github/workflows/ci.yml`: jobs `shellcheck`, `agnostico` e `segredos` (varredura de segredo com `gitleaks --redact` e exceções versionadas) | 4 |
| Gaps do checklist (CHK005, CHK010, CHK011, CHK012) | Resolução de requisito revelada pelo gate `checklist` (security + ux-ops) | 1 |

## Escopo Excluído

| Item | Descrição | Motivo |
|------|-----------|--------|
| `configurar.sh` | Comando de preparo por projeto | Outra frente — esta feature cobre só o preparo de máquina (spec.md, item 1 do briefing) |
| Render de templates com configuração de exemplo | Checagem de render com config real | Spec Edge Cases difere explicitamente para frente futura — templates ainda não existem neste repositório |
| Conteúdo real do catálogo `skills/` além do esqueleto | Skills concretas do cockpit | `skills/` ainda não existe nesta frente (research Decision 13); etapa 6 do `instalar.sh` reporta `pulada` até existir |
| Verificação de assinatura/pinning do binário `cstk` | Confiança no canal upstream | Risco residual aceito 1 do plan.md — exigiria fonte de assinatura upstream inexistente e emenda constitucional (Princípio VII fechado) |
| Janela de maturação (*soak*) nas atualizações do `cstk` | Atraso deliberado antes de adotar release nova | Risco residual aceito 2 do plan.md — Princípio IV exige manter a máquina na última release, com redação MUST |
