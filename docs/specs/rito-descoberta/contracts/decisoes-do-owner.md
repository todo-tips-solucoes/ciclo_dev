# Contrato: formato do `decisoes-do-owner.md` (D11)

**Produtor**: skill `rito-descoberta`, depois do OK do Gate 0.
**Consumidores**:
- gate da Fase 1 do `rito-dev`;
- `/feature-00c` (contexto da frente);
- frente `modo-autonomo`, que lê `Caminhos previstos` no 1º commit da branch.

**Referência viva**: `docs/specs/rito-descoberta/decisoes-do-owner.md` (1º commit desta branch).

## Estrutura

- H1: `# Decisões do owner — <frente>`, em que `<frente>` é o short-name.
- Os 14 títulos `## ` de `data-model.md`, cada um exatamente uma vez e com a grafia igual.
  A ordem recomendada é a da referência viva.

## Validação (falha fechado)

A skill roda as checagens antes do commit. Qualquer falha impede a Fase 0 de concluir.

1. **Títulos.** Cada um dos 14 títulos aparece em exatamente uma linha inteira (`grep -cFx`
   igual a 1).
2. **Seção não vazia.** Entre um título e o próximo há pelo menos uma linha que não está em
   branco.
3. **Caminhos previstos.**
   - A seção tem um bloco ```` ```text ```` com uma ou mais linhas.
   - Cada linha casa com `^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*(/\*\*)?$`.
   - Nenhum segmento é `.` ou `..`.
   - Não há `/` inicial, `~`, espaço nem outro curinga.
   - Bloco ausente, vazio ou com uma linha inválida reprova.
4. **Irreversibilidade.** O texto não está vazio; quando não há irreversibilidade, começa por
   `Nenhuma`.
5. **Instalações previstas.**
   - A seção traz `Nenhuma.` ou uma tabela com o cabeçalho exato
     `| Instalar | Desfazer | Escopo | Versão ou SHA | Classe |`.
   - Em cada linha, `Classe` é `permanente` ou `temporária`.
   - `Versão ou SHA` é uma versão exata ou um SHA de 40 caracteres hexadecimais.
   - Comando de plugin com `-s project`.
   - Nenhum comando proibido por D17 (lista em `data-model.md`, entidade "Item de instalação").
   - `Instalar` e `Desfazer` sem metacaractere de shell (`;`, `|`, `&`, `>`, `<`, `` ` ``, `$(`,
     quebra de linha). Cada comando casa com uma das formas permitidas:
     - `claude plugin install|uninstall|enable <plugin>@<marketplace> -s project`, sem outra flag;
     - `claude plugin marketplace add|remove <fonte ou nome>`;
     - gerenciador de pacote com versão exata e as flags de D17.
     Qualquer outra forma reprova.
   - O agente executa o comando byte a byte igual à célula do 1º commit, nunca uma versão
     reescrita.
6. **Commit.** O arquivo é o único do 1º commit da branch.

Para conferir o 6:

```text
git log --reverse --format=%H origin/<base>..HEAD | head -1
git show --name-only <sha>
```

## Garantia para a `modo-autonomo`

A lista de caminhos válida é a do 1º commit. Um caminho acrescentado depois, na ponta da branch,
não amplia o limite (D11). Esta frente só declara a garantia; a trava fica com a `modo-autonomo`
(D14).
