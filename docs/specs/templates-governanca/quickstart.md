# Quickstart: templates-governanca

## Cenário 1: render com a config de exemplo (happy path)

1. `T=$(mktemp -d); git init -q "$T"`
2. `./configurar.sh --projeto "$T" --respostas cockpit.config.example`
3. Conferir os 9 destinos e `grep -rl '{{' "$T/CLAUDE.md" "$T/docs"`

**Expected**: 9 arquivos presentes; `grep` sem saída; constituição com os 9 princípios; rito com Fases 1–11.

## Cenário 2: segunda execução

1. Após o Cenário 1, anotar `sha256sum` dos 9 arquivos.
2. `./configurar.sh --projeto "$T" --atualizar`

**Expected**: hashes idênticos (FR-014, SC-004).

## Cenário 3: Princípio III desligado e integração = produção

1. Cópia da config de exemplo com `PRINCIPIO_III='desligado'` e `BRANCH_PRODUCAO='staging'`.
2. Renderizar num repositório novo.

**Expected**: render sem residual; Princípio III diz `desligado`; Fase 9 do rito declara no-op para branches iguais.

## Cenário 4 (erro): template com chave opcional

1. Adicionar `{{URL_AMBIENTE_INTEGRACAO}}` a um template e remover a URL da config.

**Expected**: o configurador recusa por placeholder residual (comportamento existente) — por isso nenhum template usa chave opcional (FR-003).

## Cenário 5: agnosticismo

1. `./scripts/verificar-agnostico.sh`

**Expected**: 0 ocorrências (SC-003).
