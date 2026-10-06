# Implementation Plan: commitlint sem limite de linha no corpo

**Feature**: `commitlint-corpo-longo` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1, normativa)

## Summary

O fluxo `commitlint.yml` gerado pelo cockpit escreve na hora o `commitlint.config.cjs` com uma
única linha `printf`. Essa linha passa a declarar, além do `extends` da configuração
convencional, o objeto `rules` com `body-max-line-length` no nível 0 (desligada), na forma
`[0, 'always', Infinity]` conferida na documentação oficial ([research](research.md), Decision 1).
As demais regras da configuração convencional seguem valendo, porque a documentação diz que as
regras declaradas na configuração sobrepõem só as de mesmo nome da configuração estendida. Um
cenário novo, o 25, em `scripts/testar-configurar.sh`, renderiza o fluxo, executa a linha `printf`
renderizada num diretório temporário e confere a configuração gerada. Nenhuma dependência nova,
nenhuma versão ou gatilho alterado: o diff do template é uma linha.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` no `run:` do fluxo (já é assim) e no script de
teste (Princípio VII); a configuração gerada é CommonJS, formato aceito pela documentação oficial
(research, Decision 1)
**Primary Dependencies**: nenhuma nova; `@commitlint/cli` e `@commitlint/config-conventional`
seguem nas versões fixadas hoje no template
**Storage**: N/A
**Testing**: `scripts/testar-configurar.sh` (cenário 25 novo); o cenário 16 já passa o fluxo
renderizado no actionlint e confere que as expressões `${{ }}` atravessam o render; o cenário 11
roda shellcheck no script de teste e `verificar-agnostico.sh`
**Target Platform**: o fluxo roda no runner `ubuntu-latest` (fonte: `runs-on` do próprio
template); o teste roda em Linux, WSL e macOS (fonte: constitution, Princípio VII)
**Project Type**: template de fluxo do GitHub Actions + script de teste local
**Performance Goals**: N/A
**Constraints**: sem rede e sem `node` no teste (Princípio IV: rodar o commitlint de verdade
exigiria instalação); prosa em pt-BR acentuado; nada que nomeie projeto real; actionlint e
shellcheck sem findings
**Scale/Scope**: 1 linha em `templates/.github/workflows/commitlint.yml.tmpl`; 1 cenário novo em
`scripts/testar-configurar.sh`

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | Nenhum nome real entra; o cenário 11 roda `verificar-agnostico.sh` sobre os arquivos rastreados |
| II. Cockpit sob o próprio ciclo | PASS | Trilha completa (toca `templates/` e `scripts/`): worktree, `/feature-00c`, `bmad-code-review` antes da PR, registro SDD neste diretório |
| III. Identidade de commit | PASS | Sem efeito no desenho; conferida no commit, fora deste plano |
| IV. Dependências, não cópias | PASS | Nenhuma dependência nova; o teste não instala nem roda o commitlint, confere a configuração gerada |
| V. Fonte Oficial Antes de Afirmar | PASS | Sintaxe conferida nas páginas oficiais do commitlint, com links e trechos na research (Decision 1); o que a fonte não afirma está marcado como tal |
| VI. Português do Brasil | PASS | Prosa nova em pt-BR acentuado; identificadores do commitlint ficam como são |
| VII. Scripts portáveis e contidos | PASS | Cenário em bash com o idioma `espera`/`falha` existente, escreve só em `$TMP`; shellcheck no cenário 11 |

## Phase 0 - Research

Sem NEEDS CLARIFICATION: a única dúvida técnica (como desligar a regra) foi resolvida na
[research](research.md), Decision 1, contra a fonte oficial. Nenhum eixo estrutural (linguagem,
stack, arquitetura, persistência, ambiente, tier) é decidido por esta feature.

## Phase 1 - Design

- **Modelo de dados**: N/A (não há entidade).
- **Contratos**: N/A (nenhuma API, evento ou CLI nova; a configuração do commitlint é arquivo
  interno do job, gerado e consumido no mesmo passo).
- **Cenários de validação**: [quickstart.md](quickstart.md).

### Mudança 1 - linha que gera a configuração (FR-001 a FR-004)

Em `templates/.github/workflows/commitlint.yml.tmpl`, passo "Validar título e commits", só a linha
`printf ... >"$pasta/commitlint.config.cjs"` muda. O conteúdo gerado passa a ser, em uma linha:

```js
module.exports = { extends: ['@commitlint/config-conventional'], rules: { 'body-max-line-length': [0, 'always', Infinity] } };
```

- O `extends` fica idêntico ao de hoje (FR-002).
- O objeto `rules` traz só `body-max-line-length`; as demais regras vêm da configuração
  convencional (FR-002, US2).
- A mesma configuração vale para o título do PR e para os commits; o título não tem corpo, então
  nada muda para ele (edge case da spec).
- Nada mais no arquivo muda: `npm install` com as mesmas versões, mesmos gatilhos, mesmas
  mensagens de erro, nenhuma expressão `${{ }}` nova (FR-004). A string de formato do `printf` não
  ganha `%` nem `$`, então não há expansão nova de shell.

### Mudança 2 - cenário 25 (FR-005)

Em `scripts/testar-configurar.sh`, bloco novo `cenario "25: commitlint sem limite de linha no
corpo"`, com o separador de comentário no padrão dos demais, inserido logo antes do bloco do
cenário 11 (que fica por último). Passos:

1. `T="$(novo_repo)"` e `rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO"`, como os outros
   cenários de render.
2. Extrair do `commitlint.yml` renderizado a única linha que contém `commitlint.config.cjs` e
   começa com `printf` (falha se não houver exatamente uma).
3. Executar essa linha com `bash -c`, com `pasta` apontando para um diretório novo sob `$TMP`, e
   conferir que `commitlint.config.cjs` foi criado.
4. Conferir na configuração gerada, com `grep -F`:
   - `extends: ['@commitlint/config-conventional']` (US2, FR-002);
   - `'body-max-line-length': [0, 'always', Infinity]` (US1, FR-001).

Sem rede, sem `node`, sem instalar nada. O cenário 16 já cobre actionlint sobre o fluxo
renderizado; o cenário 11 cobre shellcheck do script de teste (SC-003).

**Conflito esperado no rebase** (restrição do owner): outras frentes também inserem cenários antes
do 11; o conflito de inserção se resolve mantendo os dois blocos.

## Project Structure

### Documentation (this feature)

```
docs/specs/commitlint-corpo-longo/
├── decisoes-do-owner.md  # normativo (D1)
├── spec.md
├── research.md           # Decision 1: fonte oficial conferida
├── plan.md               # este arquivo
└── quickstart.md         # cenários de validação
```

### Source Code (repository root)

```
templates/.github/workflows/commitlint.yml.tmpl   # 1 linha alterada (printf da configuração)
scripts/testar-configurar.sh                      # cenário 25 novo, antes do 11
```

**Structure Decision**: nenhum arquivo novo de código; a mudança fica no template existente e no
script de teste existente.

## Convenções de Borda

N/A — single-layer (template de fluxo e script de teste; não há borda entre camadas).

## Complexity Tracking

Nenhuma violação a justificar.

## Re-check da constitution (pós-design)

O desenho mantém os sete princípios como na tabela acima: uma linha de template, um cenário de
teste no idioma existente, nenhuma dependência, arquivo ou mecanismo novo.
