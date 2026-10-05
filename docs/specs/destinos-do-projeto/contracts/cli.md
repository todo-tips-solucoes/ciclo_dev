# Contrato (delta): configurar.sh com destinos do projeto

**Base**: [`docs/specs/configurar/contracts/cli.md`](../../configurar/contracts/cli.md), já com o
delta da [modo-semente](../../modo-semente/contracts/cli.md). Só o que muda está aqui; o resto
vale igual.

[PROPOSTA — a validar na implementação]: textos de mensagem novos, desenhados nesta feature. Os
textos existentes citados vêm de `configurar.sh` (commit `3599598`).

## Chave nova

`DESTINOS_DO_PROJETO` (opcional): caminhos relativos à raiz, separados por espaço, iguais ao
destino de algum template depois de normalizados: `./` inicial, `/./` e `//` internos e `/` final
não contam (code review, decisão do owner). Exemplo: `DESTINOS_DO_PROJETO='.github/workflows/ci.yml docs/rito-dev.md'`.

- Modo interativo: última pergunta, `Destinos mantidos pelo projeto (caminhos separados por
  espaço) (- para vazio)`; Enter mantém o valor atual, `-` limpa.
- Valor inválido: exit 1 citando a chave, nada gravado (modos `--respostas` e `--atualizar`);
  no interativo, pergunta de novo. Regras em [data-model.md](../data-model.md).
- Item que não é destino de nenhum template, em stderr, sem mudar o exit:
  `Aviso: DESTINOS_DO_PROJETO: '<item>' não é destino de nenhum template; ignorado.`

## Regra

| Destino | Efeito | Manifesto |
|---------|--------|-----------|
| listado (existente ou não, semente ou não) | intacto, sem leitura, sem render, sem prompt, ignora `--forcar`; nunca é gerado | linha anterior mantida (ou nenhuma) |
| semente ou listado, ausente, numa worktree vinculada, ignorado pelo git, existente como arquivo regular na árvore principal | copiado de lá como arquivo regular | linha anterior mantida (ou nenhuma); a cópia não entra |
| idem, sem arquivo regular na árvore principal (ausente, link, repositório bare) | nada gerado | linha anterior mantida (ou nenhuma) |

Fora de worktree vinculada, ou com destino não ignorado, vale a regra atual.

## Saída (stdout)

- Por destino listado: `  mantido (projeto): <rel>`
- Por cópia: `  copiado da árvore principal: <rel>`
- Por ignorado sem origem: `  mantido (ignorado pelo git): <rel> (esperado em <caminho na árvore principal>)`;
  com a árvore principal indisponível: `… (árvore principal indisponível)`
- Contagem: `Templates: N gravado(s), M inalterado(s)` seguida, nesta ordem e só com contagem
  maior que zero, de `, K mantido(s) (semente)`, `, P mantido(s) (projeto)`,
  `, C copiado(s) da árvore principal`, `, G mantido(s) (ignorado pelo git)`, e `.` no fim.

Sem nenhum destino listado, copiado ou ignorado, a saída é a de hoje, byte a byte, salvo a
mensagem de conflito e o `--ajuda`, que passam a citar a chave.

## Saída (stderr)

- Conflito (texto atual + sugestão, D2):
  `Arquivo editado localmente, mantido: <rel>. Use --forcar para sobrescrever ou declare o destino em DESTINOS_DO_PROJETO no cockpit.config.`
- Origem recusada: `Aviso: origem recusada (link simbólico): <caminho na árvore principal>`
- Árvore principal indisponível, uma vez por execução:
  `Aviso: árvore principal indisponível (<repositório bare | não confirmada>); destinos ignorados pelo git não serão copiados.`

## Códigos de saída

Sem código novo. A recusa do lote por edição local continua (exit 2, nenhum template movido e
nenhuma cópia feita). Falha ao copiar: exit 1, linha "falha de escrita" do contrato base.

## `--ajuda`

Linha do `--forcar`: sobrescreve arquivos editados à mão sem confirmação, exceto sementes e
destinos em DESTINOS_DO_PROJETO, que nunca são sobrescritos.
