# Implementation Plan: configurar

**Feature**: `configurar` | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

## Summary

`configurar.sh` (raiz do cockpit) pergunta os parâmetros do ciclo — ou os lê
de um arquivo de respostas `CHAVE=valor` —, grava `cockpit.config` no
projeto-alvo com aspas simples (legível por `source`), renderiza todo arquivo
sob `templates/` por substituição literal de `{{CHAVE}}` (awk, sem engine),
recusa placeholder residual, preserva edição local via manifesto sha256, e
por último provisiona os guard hooks com `cstk hooks install --project-path`,
sem nunca instalar terceiro. Toda escrita é atômica (temporário + `mv`) e
contida na raiz do projeto.

## Technical Context

**Language/Version**: bash (3.2 do macOS até 5.x), `set -euo pipefail`
**Primary Dependencies**: `git` (validação de branch/raiz), `awk`/`grep`/`tr`/`mktemp`/`mv` do sistema base; `sha256sum` ou `shasum -a 256`; `cstk` só no último passo
**Storage**: arquivos texto no projeto-alvo (`cockpit.config`, `.cockpit/manifesto.sha256`, saídas dos templates)
**Testing**: `scripts/testar-configurar.sh` (bash, sem framework) + shellcheck + `verificar-agnostico.sh`, todos no CI
**Target Platform**: Linux, WSL, macOS (constitution Princípio VII)
**Project Type**: cli (script local)
**Performance Goals**: N/A — interação humana domina (SC-001: 17 respostas na configuração mínima + medição cronometrada < 5 min)
**Constraints**: escreve só dentro do projeto-alvo; nenhuma dependência nova; nenhum valor de projeto no script
**Scale/Scope**: ~13 chaves, poucos templates (1 de prova agora; itens 4 e 5 do MVP depois)

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo verificável | PASS | valores só no `cockpit.config`; template de prova e exemplo com nomes fictícios; `verificar-agnostico.sh` no CI (FR-020). Integração = produção aceito sem aviso (FR-005) |
| II. Próprio ciclo | PASS | trilha completa (toca raiz, `scripts/`, `templates/`, `.github/`, `cockpit.config.example`); worktree + `/feature-00c` em curso; `bmad-code-review` antes da PR |
| III. Identidade de commit | PASS | o configurador não altera identidade git; `IDENTIDADES` é dado para templates, não `git config` |
| IV. Terceiros não instalados | PASS | só `cstk --version` e `cstk hooks install` (permitido explicitamente); ausência → comando oficial impresso + exit 3; piso lido de `versoes.env` via `scripts/lib/versao.sh` |
| V. Fonte oficial | PASS com pendência | comportamento de `cstk hooks install` citado da saída de `--help` observada; o link da doc oficial MUST ser lido via `context-mode` e registrado na implementação (research Decision 10) |
| VI. Português do Brasil | PASS | mensagens, perguntas e artefatos em pt-BR (FR-021); chaves de config como identificadores |
| VII. Portável, idempotente, contido | PASS | bash com `set -euo pipefail` + shellcheck; saída byte a byte estável (ordem fixa, sem data); contenção por `pwd -P`; dependências dentro da lista |

## Decisões e pendências

- Motor, leitura/escrita do config, manifesto, atomicidade, contenção,
  sufixo `.tmpl`, reuso de `instalar.sh` e teste: [research.md](./research.md)
  Decisions 1–4 e 6–11.
- **FR-018 — ratificado pelo owner em 2026-09-29** (research Decision 5):
  nome e e-mail perguntados separadamente, gravação `nome:email;…` em
  `IDENTIDADES`. Histórico: a proposta original era `nome <email>`. A conciliação foi feita pelo orquestrador na onda-003 sem
  resposta explícita. Implementar como proposta; a PR MUST pedir ao owner a
  confirmação (ou a alternativa: perguntar nome e e-mail separadamente).
  A mudança, se vier, fica isolada na função de pergunta de identidades.

## Project Structure

### Documentation (this feature)

```
docs/specs/configurar/
├── spec.md
├── plan.md          # este arquivo
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── cli.md
```

### Source Code (repository root)

```
configurar.sh                     # NOVO — o configurador
scripts/
├── lib/
│   └── versao.sh                 # NOVO — versao_ge + ler_cstk_min extraídos de instalar.sh
├── testar-configurar.sh          # NOVO — cenários do quickstart
├── verificar-agnostico.sh        # inalterado
└── agnostico.lista               # inalterado
templates/
└── .cockpit/
    └── LEIAME.md.tmpl            # NOVO — template de prova (FR-012)
instalar.sh                       # ALTERADO — passa a carregar scripts/lib/versao.sh
cockpit.config.example            # ALTERADO — 3 chaves novas; valores entre aspas simples
.github/workflows/ci.yml          # ALTERADO — job `configurar` roda testar-configurar.sh
docs/specs/skills-do-cockpit/data-model.md   # ALTERADO — registra as 3 chaves (FR-003)
skills/rito-dev/SKILL.md          # ALTERADO (mínimo) — nota de que valores podem vir entre aspas; linha 44 deixa de dizer que não há tabela de identidades
```

No projeto-alvo, o configurador escreve apenas: `cockpit.config`,
`.cockpit/manifesto.sha256`, as saídas dos templates, e (via `cstk`)
`.claude/hooks/` + `.claude/settings.json`.

**Structure Decision**: script único na raiz, ao lado de `instalar.sh`
(simetria "instalar = máquina, configurar = projeto" do briefing). Uma única
extração (`scripts/lib/versao.sh`) para não duplicar a comparação de versão
e a leitura do piso. `templates/` espelha o layout do projeto-alvo.

### Organização interna de `configurar.sh` (funções, não arquivos)

`uso` · `ler_config` (research D2) · `gravar_config` (D3) · `validar_chave`
(data-model §Validação) · `perguntar` / `perguntar_identidades` (D5) ·
`resolver_raiz` / `destino_contido` (D8) · `renderizar` (D1, D9) ·
`aplicar_render` (D6, D7) · `provisionar_hooks` (D10) · `main`.

## Convenções de Borda

N/A — single-layer (script local). A única convenção de formato é a de
`cockpit.config`/arquivo de respostas, fixada em [data-model.md](./data-model.md).

## Superfície de segurança

| Risco | Mitigação |
|---|---|
| Execução de código via `cockpit.config` hostil | leitura sem `source`/`eval` (D2) |
| Escrita fora do projeto (`..`, symlink) | `pwd -P` + prefixo, recusa de symlink de destino, `find -type f` (D8) |
| Injeção de valor no template (`&`, `\`, `$`) | substituição por `substr()`, valor via `ENVIRON` (D1) |
| Cadeia de suprimentos | nenhum download/instalação; só `cstk` já instalado pela pessoa (Princípio IV) |
| Arquivo parcial após Ctrl-C | temporário no mesmo diretório + `mv`; `trap` limpa (D7) |
| Valor com quebra de linha ou caractere de controle (formato quebrado, sequência ANSI no terminal ao exibir config lida) | recusado na validação (data-model §Regras) |
| Troca de diretório por link simbólico entre checagem e `mv` (TOCTOU) | checagem de contenção refeita imediatamente antes de cada `mv`; `cockpit.config` de destino que seja link simbólico é recusado. Teto aceito: script local de um usuário, sem atacante concorrente no mesmo projeto |
| Valor substituído em template executável futuro (`.sh`, `.yml` dos itens 4/5) | fora desta feature: cada template que usar valor em contexto de shell/YAML MUST citá-lo de forma segura; registrado para as frentes seguintes |
| E-mail pessoal em template | aviso quando não é `noreply` (FR-018) |

## Complexity Tracking

Sem violações de constitution.

## Re-check pós-design

Nenhum componente novo além do script, uma lib de duas funções, um template
de prova e um script de teste. Dependências continuam dentro do Princípio VII
(`awk`/`sha256sum|shasum` são utilitários base, mesma classe dos já usados
por `instalar.sh`). Princípio V permanece com a pendência registrada acima.
Resultado: **PASS**.
