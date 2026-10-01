# Research: modo semente no configurar.sh

**Feature**: `modo-semente` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

Nenhum eixo estrutural em aberto: linguagem (bash), persistência (arquivos + manifesto
`.cockpit/manifesto.sha256`) e plataforma (Linux/WSL/macOS) já estão fixadas pela constituição
(Princípio VII) e pelo `configurar.sh` existente. As decisões abaixo são de implementação.

## Decision 1: onde marcar "semente"

**Decision**: pelo sufixo do nome do template, `.semente.tmpl`, detectado em
`preparar_templates()` com `case "$rel" in *.semente.tmpl)`; o destino é `${rel%.semente.tmpl}`.
Um array paralelo `SEMENTE[i]` (0/1) acompanha `TPL_ORIG`/`DEST_REL`.

**Rationale**: a spec fixa a marcação por nome (FR-001, US3) e exclui lista/front-matter. O
array paralelo segue o padrão que o script já usa (`TPL_ORIG`, `DEST_REL`, `dests_min`).

**Alternatives considered**: arquivo de lista ou front-matter — fora de escopo pela spec.

## Decision 2: quando decidir que a semente é pulada

**Decision**: uma única decisão por execução, logo após `preparar_templates()` e antes do laço
`exigir_contido` de `main()`: `PULAR[i]=1` quando `SEMENTE[i]=1` e
`[ -e "$dest" ] || [ -L "$dest" ]`. Todo o resto (laço de contenção em `main`, render,
residuais, conflitos, gravação, manifesto, relatório) só consulta `PULAR[i]`.

**Rationale**: FR-002 pede "não existe" no sentido `-e` **e** sem link quebrado; `help test` do
bash: `-e FILE True if file exists`, `-L FILE True if file is a symbolic link` — `-e` segue o
link, então link quebrado só aparece no `-L`. Decidir uma vez evita que as fases discordem
(ex.: render pulado mas conflito avaliado). O laço de contenção de `main` hoje recusa destino
que é diretório ou link (`destino_contido`); o edge case da spec manda pular a semente existente
nesses casos, então o laço passa a ignorar `PULAR[i]=1` — a contenção continua valendo para
tudo que será gravado.

**Alternatives considered**: checar `-e` em cada fase — mais linhas e risco de divergência.

## Decision 3: colisão `X.tmpl` x `X.semente.tmpl` e nomes degenerados

**Decision**: nenhuma mudança na checagem de duplicados: como o destino da semente já é
calculado sem o sufixo, a comparação case-insensitive existente (`dests_min`) acusa a colisão
com a mensagem atual `Templates com o mesmo destino (...)` (exit 1). Um template chamado só
`.semente.tmpl` (destino vazio ou terminado em `/`) é recusado com `falhar`.

**Rationale**: FR-005 pede as mesmas guardas; reaproveitar a guarda existente é o menor diff.
Destino vazio cairia em `$RAIZ/` (diretório) e falharia de forma obscura.

## Decision 4: manifesto da semente pulada

**Decision**: em `gravar_manifesto()`, para `PULAR[i]=1`, reemitir a linha anterior do
manifesto (`manifesto_hash "${DEST_REL[i]}"`) se houver; se não houver, não emitir nada.
Semente gravada recebe hash como qualquer destino.

**Rationale**: FR-006 ("não entra nem sai; entrada anterior é mantida"). Sem isso o laço atual
recalcularia o hash do arquivo editado (passaria a tratar a edição como "gerada") ou falharia
em `hash_arquivo` quando o destino é diretório/link quebrado. Como `DEST_REL` ainda contém o
caminho, a entrada não é tratada como órfã.

## Decision 5: relatório e código de saída

**Decision**: para cada semente pulada, `log "  mantido (semente): <rel>"` (stdout). A linha de
contagem ganha o sufixo `, K mantido(s) (semente)` **só quando K > 0**, preservando byte a byte
a saída de projetos sem semente pulada (FR-009). Exit 0 quando só há sementes mantidas
(clarify). No caminho de recusa do lote (exit 2), sementes não entram em `conflitos`.

**Rationale**: FR-007 + clarify Q1/Q4.

## Decision 6: documentação

**Decision**: renomear (`git mv`) `templates/CLAUDE.md.tmpl`,
`templates/docs/constitution.md.tmpl` e `templates/docs/project-context.md.tmpl` para
`*.semente.tmpl` e trocar nelas o parágrafo que manda usar `--forcar` por "gerado uma vez; o
configurador nunca mais o altera". Atualizar `uso()` (linha do `--forcar`: "não vale para
sementes"), o cabeçalho de `configurar.sh` e `docs/specs/configurar/contracts/cli.md` (saída e
regra de semente). README e `.cockpit/LEIAME.md.tmpl` hoje não citam `--forcar` para esses três
arquivos (grep); conferir na implementação e só tocar se houver menção.
