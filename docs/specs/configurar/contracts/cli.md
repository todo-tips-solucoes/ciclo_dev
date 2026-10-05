# Contracts: configurar — interface de linha de comando

[PROPOSTA — a validar na implementação]: interface nova, desenhada nesta
feature; nenhum contrato existente é afirmado aqui, exceto a chamada ao
`cstk`, cuja fonte está em [research Decision 10](../research.md).

## `configurar.sh`

```
./configurar.sh [--projeto DIR] [--respostas ARQ] [--atualizar] [--forcar] [--ajuda]
```

Roda a partir do clone do cockpit (lê `templates/`, `versoes.env` e
`scripts/lib/versao.sh` relativos ao próprio script).

### Opções

| Opção | Default | Efeito |
|---|---|---|
| `--projeto DIR` | diretório corrente | raiz do projeto-alvo; MUST ser o topo de um repositório git |
| `--respostas ARQ` | — | modo não interativo: todos os valores vêm de `ARQ` (formato `CHAVE=valor`); nenhuma pergunta |
| `--atualizar` | — | não pergunta nada; re-renderiza a partir do `cockpit.config` existente |
| `--forcar` | — | sobrescreve arquivos editados à mão sem confirmação, exceto sementes e destinos em `DESTINOS_DO_PROJETO`, que nunca são sobrescritos |
| `--ajuda` | — | imprime o uso e sai com 0 |

`--atualizar` e `--respostas` juntos: erro de uso. Sem `--respostas`, sem
`--atualizar` e com stdin que não é terminal: erro de uso (nunca espera
entrada que não virá).

### Fluxo

1. Valida opções, resolve e valida a raiz do projeto.
2. Obtém valores: `--respostas` | `cockpit.config` (`--atualizar`) |
   perguntas com o valor atual como padrão (mostrando os valores lidos antes
   de aceitá-los — Edge Case "outro projeto").
3. Valida todos os valores (data-model §Validação); inválido → pergunta de
   novo (interativo) ou erro nomeando a chave (não interativo).
4. Grava `cockpit.config` (atômico).
5. Renderiza todos os templates para temporários; residual → erro; conflito
   de edição → confirmação/`--forcar`; então move tudo e grava o manifesto.
6. Checa o `cstk` e roda `cstk hooks install --project-path <raiz>`.

### Sementes (`*.semente.tmpl`)

- `templates/<caminho>.semente.tmpl` gera `<caminho>`. Colisão com `<caminho>.tmpl`:
  `Templates com o mesmo destino (<caminho>): ...`, exit 1.
- Destino inexistente (`! -e` e `! -L`): renderiza e grava como os demais; hash novo no manifesto.
- Destino existente (qualquer tipo): intacto, sem leitura, sem prompt, ignora `--forcar`;
  linha anterior do manifesto mantida (ou nenhuma). Nunca causa exit 2.
- Semente a gravar com placeholder sem valor: exit 2, mesma mensagem do não semente.
- Saída: `  mantido (semente): <rel>` por semente pulada; a contagem final ganha
  `, K mantido(s) (semente)` só com K > 0. Só sementes mantidas: exit 0.

### Destinos do projeto (`DESTINOS_DO_PROJETO`)

Delta da feature `destinos-do-projeto` (contrato completo em
`docs/specs/destinos-do-projeto/contracts/cli.md`).

- Chave opcional do `cockpit.config`: caminhos relativos separados por espaço, iguais ao destino
  de algum template depois de normalizados (sem `./` inicial, `/./` ou `//` internos e `/` final); é a última pergunta do modo interativo (`- para vazio`). Item só de aspas,
  absoluto, com componente `..` ou valor com caractere de controle: exit 1 citando a chave.
  Item sem template correspondente: aviso em stderr, exit inalterado.
- Destino listado: intacto, sem leitura, render, prompt nem `--forcar`; nunca é gerado; linha
  anterior do manifesto mantida. Saída `  mantido (projeto): <rel>` e, na contagem final,
  `, P mantido(s) (projeto)`.
- Numa worktree vinculada, semente ou destino listado ausente e ignorado pelo git é copiado do
  arquivo regular correspondente da árvore principal (primeiro registro de `git worktree list`),
  fora do manifesto: `  copiado da árvore principal: <rel>`. Sem origem válida (ausente, link,
  repositório bare): nada é gerado, `  mantido (ignorado pelo git): <rel> (esperado em <caminho>)`.
- Sem a chave e fora de worktree vinculada, a saída é a de antes, salvo a mensagem de conflito e o
  `--ajuda`, que passam a citar a chave.

### Saída

- stdout: progresso por passo e resumo final (arquivos escritos, inalterados,
  mantidos por edição local); sem templates, informa que nada havia a
  renderizar.
- stderr: erros, cada um nomeando campo, arquivo ou placeholder.
- Todas as mensagens em português do Brasil (FR-021).

### Códigos de saída

| Exit | Situação | Estado deixado no projeto |
|---|---|---|
| 0 | tudo concluído, inclusive hooks | config + templates + manifesto + hooks |
| 1 | erro de uso, projeto inválido, raiz do próprio cockpit sem `--projeto`, valor inválido no modo não interativo, `--atualizar` sem config, caminho que escapa do projeto | nada novo gravado |
| 1 | falha de escrita (permissão, disco) ao renderizar ou mover | `cockpit.config` pode ter sido gravado; templates já movidos antes da falha ficam; a mensagem nomeia o arquivo |
| 2 | placeholder residual, ou arquivo editado à mão mantido sem confirmação | `cockpit.config` gravado; **nenhum** template movido |
| 3 | `cstk` ausente, sem versão reconhecível ou abaixo de `CSTK_MIN` | config + templates + manifesto; comando oficial impresso; nada de terceiro executado |
| 4 | `cstk hooks install` retornou erro | config + templates + manifesto; saída do `cstk` repassada |

### Mensagens de referência (conteúdo, não literal final)

- Residual: `Placeholder sem valor: {{CHAVE}} em <rel do template>`
- Conflito: `Arquivo editado localmente, mantido: <rel>. Use --forcar para sobrescrever ou declare o destino em DESTINOS_DO_PROJETO no cockpit.config.`
- `--atualizar` sem config: `Nenhum cockpit.config em <raiz>. Rode ./configurar.sh sem --atualizar para criá-lo.`
- `cstk` ausente: o mesmo par de linhas `Execute: ...` que `instalar.sh` imprime (URL lida de um único lugar no código).

## Chamada externa: `cstk hooks install`

```
cstk hooks install --project-path <raiz do projeto>
```

Única invocação de terceiro. Fonte: `cstk hooks --help` (cstk v10.8.0) —
ver research Decision 10. Nenhuma outra flag é passada. Nunca
`cstk install`, `cstk update`, `cstk self-update` (Princípio IV).
