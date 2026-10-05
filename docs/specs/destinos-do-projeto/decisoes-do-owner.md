# Decisões do owner — destinos-do-projeto

Frente única para as issues #14 e #15 (`configurar.sh`). As decisões abaixo foram tomadas pelo
owner em 2026-10-05, antes do `/feature-00c`, e são normativas: o `specify` parte delas e o
`clarify` não as reabre.

Contexto: `docs/specs/modo-semente/` (FR-001 a FR-009) e `docs/specs/configurar/contracts/cli.md`.
Hoje `PULAR` só vale para semente (`.semente.tmpl`) cujo destino existe. Qualquer outro destino
editado à mão é conflito e recusa o lote inteiro (exit 2), salvo `--forcar`, que apaga a versão
do projeto.

## D1 (#14) — destinos mantidos pelo projeto

- Nova chave **opcional** `DESTINOS_DO_PROJETO` no `cockpit.config` (Princípio I: valor que varia
  por projeto é chave do config).
- Formato: caminhos relativos à raiz do projeto, separados por espaço, iguais ao destino de algum
  template (ex.: `.github/workflows/ci.yml docs/rito-dev.md`).
- Destino listado é tratado como semente existente: não é renderizado nem comparado, e não conta
  como conflito, nem com `--forcar` nem no modo interativo. A entrada anterior no manifesto é
  mantida (mesma regra da FR-006 do modo semente).
- Relatório: `mantido (projeto): <rel>`, com contagem própria, separada da de sementes.
- Vale também para destino de semente: listado, nunca é gerado, nem quando ausente.
- Validação na fronteira de confiança: item absoluto, com `..`, vazio ou com caractere de controle
  → erro (exit 1, citando a chave). Item que não bate com destino de nenhum template → aviso, não
  erro.
- Entra em `CHAVES_OPCIONAIS`: é perguntada no modo interativo com `- para vazio` e gravada pelo
  `gravar_config` como as demais.
- Atualizar `cockpit.config.example` e a documentação de uso.

## D2 (#14) — recusa do lote mantida

- A recusa do lote por edição local continua: FR-009 do modo semente intacta, contrato do exit 2
  inalterado.
- Só a mensagem de conflito muda: além de `--forcar`, sugere declarar o destino em
  `DESTINOS_DO_PROJETO`.

## D3 (#15) — destino ignorado pelo git numa worktree

Vale para destino **ausente** de semente ou de destino do projeto (D1), quando as duas condições
valem:

1. o projeto é uma worktree vinculada (`git rev-parse --git-dir` ≠ `--git-common-dir`);
2. o destino é ignorado pelo git (`git check-ignore -q`).

Então:

- se o arquivo existe na árvore principal (primeira entrada de `git worktree list --porcelain`,
  recusando repositório bare), copiar de lá: arquivo regular, não link; mesmas guardas de
  contenção para o destino; não entra no manifesto, porque não foi gerado por template.
  Relatório: `copiado da árvore principal: <rel>`;
- se não existe lá, não gerar nada e avisar `mantido (ignorado pelo git)`, com o caminho esperado
  na árvore principal.

Fora de worktree, ou com destino não ignorado, o comportamento atual não muda. O script escreve
só dentro do projeto-alvo (Princípio VII); a árvore principal só é lida.

## Fora de escopo

- Prefixos de branch fixos (`feature/<slug>` …): issue #16.
- Conflito tratado por arquivo em vez de por lote: recusado em D2.

## Restrições

- bash com `set -euo pipefail`, shellcheck sem findings, `LC_ALL=C`, nenhuma dependência nova
  (Princípio VII).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I).
- Testes em `scripts/testar-configurar.sh`, no estilo dos cenários existentes (o cenário 17 é o
  modo semente): um cenário novo para D1/D2 e um para D3, este com worktree real e `.gitignore`
  cobrindo `CLAUDE.md`.
- Registro SDD em `docs/specs/destinos-do-projeto/`.
