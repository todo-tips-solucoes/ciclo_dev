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
   - Nenhum segmento é `.`, `..` ou `.git`; nada sob `.claude/` com `**` (só arquivo literal).
   - Não há `/` inicial, `~`, espaço nem outro curinga.
   - Bloco ausente, vazio ou com uma linha inválida reprova.
4. **Irreversibilidade.** O texto não está vazio; quando não há irreversibilidade, começa por
   `Nenhuma`.
5. **Instalações previstas.**
   - A seção traz `Nenhuma.` ou uma tabela com o cabeçalho exato
     `| Instalar | Desfazer | Escopo | Versão ou SHA | Classe |`.
   - `Instalar`, `Desfazer` e `Versão ou SHA` são, cada uma, um único trecho de código
     (`` `…` ``); o valor é o texto entre as crases, sem elas.
   - O valor de `Instalar` e de `Desfazer` só tem letras, dígitos, espaço e `@ . _ / : = + -`.
   - `Classe` é `permanente` ou `temporária`; `marketplace add`/`remove` só `temporária`.
   - `Versão ou SHA` é uma versão exata ou um SHA de 40 caracteres hexadecimais.
   - Formas permitidas, sem outra flag:
     - `claude plugin install|enable <plugin>@<marketplace> -s project`, com Desfazer
       `claude plugin uninstall|disable` do mesmo id e `-s project`;
     - `claude plugin marketplace add <dono>/<repositório>`, com Desfazer
       `claude plugin marketplace remove <nome>`;
     - gerenciador de pacote com versão exata e as flags obrigatórias de D17.
   - Reprova: comando proibido por D17; as flags `-g`, `--global`, `--location`, `--prefix`,
     `--user`, `--registry`, `-i`, `--index-url`, `--extra-index-url`, `-f`, `--find-links` e
     `--trusted-host`; a palavra `global`; pacote por URL ou repositório (`://`, `git+`).
   - O agente executa o valor da célula do 1º commit byte a byte, nunca uma versão reescrita.
6. **Commit.** Logo depois do commit, o arquivo é o único do 1º commit da branch. Saída vazia ou
   outro arquivo reprova.

Para conferir o 6:

```text
git log --reverse --format=%H origin/<base>..HEAD | head -1
git show --name-only --format= "<sha>"
```

Fonte normativa da implementação: seção "Validação do registro" de `skills/rito-descoberta/SKILL.md`
(rodada de revisão de 2026-11-05).

## Garantia para a `modo-autonomo`

A lista de caminhos válida é a do 1º commit. Um caminho acrescentado depois, na ponta da branch,
não amplia o limite (D11). Esta frente só declara a garantia; a trava fica com a `modo-autonomo`
(D14).
