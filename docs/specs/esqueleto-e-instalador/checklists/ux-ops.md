# UX-OPS Checklist: Esqueleto do cockpit-dev e instalador de máquina

**Purpose**: Validar a qualidade dos requisitos da experiência de linha de comando
do `instalar.sh` — clareza de mensagens, relatório final, idempotência percebida
pelo dev e cobertura dos caminhos de erro operacionais. Domínio customizado
(UX + Ops do instalador), combinando `ux` com foco em CLI não-interativa.
**Created**: 2026-09-25
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md) · [contracts/cli.md](../contracts/cli.md)

## Completude de Requisitos

- [x] CHK001 - O relatório final especifica o status individual de CADA etapa do
      pipeline (FR-009), incluindo o caso `pulada` com o motivo inline, e não só
      um resumo binário ok/falhou? [Completude, Plan §Arquitetura de `instalar.sh`
      — tabela de 7 etapas; Contracts/cli.md §Saída — relatório final] {auto}
- [x] CHK002 - Os três códigos de saída (`0`/`1`/`2`) têm cada um seu significado
      documentado, permitindo ao dev diferenciar "minha máquina não tem as
      ferramentas de base" de "o preparo tentou e falhou"? [Completude,
      Contracts/cli.md §Códigos de saída; Spec §SC-005] {auto}

## Clareza de Requisitos

- [x] CHK003 - O limite entre "mensagem autoral em PT-BR" (FR-012) e "saída
      nativa de ferramenta externa, em qualquer idioma" está definido de forma
      operacional, sem margem para julgamento caso a caso durante a
      implementação? [Clareza, Spec Clarifications Q3] {auto}
- [x] CHK004 - "Avisar" divergência local na idempotência (US1 cenário 6) está
      associado a um texto de status concreto no relatório
      (`atualizada (havia edicao local)`), e não deixado como promessa genérica
      de "avisar"? [Clareza, Research Decision 14 — tabela de ações] {auto}

## Consistência de Requisitos

- [x] CHK005 - A ordem das etapas no relatório final (contracts/cli.md) é
      consistente com a ordem de execução da arquitetura do pipeline (plan.md),
      inclusive a ordem não-negociável `self-update` → checagem de piso
      (Decision 2)? [Consistência, Plan §Arquitetura de `instalar.sh`;
      Contracts/cli.md §Saída] {auto}

## Qualidade de Critérios de Aceite

- [x] CHK006 - SC-005 ("diagnóstico que identifica exatamente qual ferramenta e
      qual versão falta — sem precisar investigar log nenhum") é mensurável por
      um formato de saída fixo (lista completa antes de qualquer instalação,
      código `2`), e não por interpretação subjetiva de "exatamente"?
      [Mensurabilidade, Spec §SC-005; Quickstart Scenario 2] {auto}
- [x] CHK007 - SC-002 ("mesmo relatório de sucesso... sem nenhuma duplicação
      perceptível") tem "duplicação perceptível" concretizado por um critério
      verificável (nenhum registro de marketplace/plugin repetido), em vez de
      ficar subjetivo? [Mensurabilidade, Spec §SC-002; Quickstart Scenario 6,
      passo 3] {auto}

## Cobertura de Cenários

- [x] CHK008 - Existe cenário cobrindo a segunda execução sem nenhuma mudança
      entre as duas (idempotência do caminho feliz)? [Cobertura, Quickstart
      Scenario 6, passos 1-3] {auto}
- [x] CHK009 - Existe cenário cobrindo divergência local detectada (edição manual
      de uma skill já instalada) e o aviso correspondente no relatório?
      [Cobertura, Quickstart Scenario 6, passos 4-5] {auto}

## Cobertura de Edge Cases

- [ ] CHK010 - O Edge Case "máquina sem permissão de escrita na área de
      configuração" (spec.md) não tem Acceptance Scenario, cenário de quickstart,
      código de saída dedicado nem mecanismo de arquitetura (ex.: escrita
      atômica, pré-checagem de permissão como etapa própria do pipeline) que
      sustente "falhar... em vez de falhar a meio caminho deixando estado
      parcial". A promessa existe como texto de Edge Case; o COMO fica
      inteiramente implícito na implementação. [Gap, Spec Edge Cases — "não tem
      permissão de escrita"; Plan §Arquitetura de `instalar.sh` (sem menção);
      Contracts/cli.md §Códigos de saída (sem código dedicado); Quickstart (sem
      cenário correspondente)] {auto}
- [ ] CHK011 - O Edge Case "plugin necessário ausente mas ferramenta de
      implementação já correta → instala apenas o que falta, sem reinstalar o
      que já está correto" não tem Acceptance Scenario nem cenário de quickstart
      dedicado — a garantia existe só como texto de Edge Case, sem verificação
      executável descrita (Scenario 7 do quickstart cobre falha do plugin
      recomendado, não instalação parcial seletiva). [Gap, Spec Edge Cases;
      Quickstart (sem cenário correspondente)] {auto}

## Requisitos Não-Funcionais

- [ ] CHK012 - Nem spec.md nem plan.md especificam se o dev recebe algum sinal de
      progresso durante etapas potencialmente demoradas (download/instalação do
      `cstk`, registro de marketplace, instalação de plugin) ou se fica sem
      feedback algum até o relatório final de sete etapas. Ausência não
      confirmada como decisão deliberada (silêncio-até-o-fim é uma escolha de UX
      válida, mas não está registrada como tal). [Gap, Spec (ausente); Plan
      (ausente)] {humano}

## Dependências e Premissas

- [x] CHK013 - A leitura do piso `CSTK_MIN` a partir de `versoes.env` está
      especificada com o mecanismo exato (parse explícito via grep/cut, nunca
      `source`), evitando que uma implementação ingênua transforme um arquivo de
      dados em script executável? [Premissa, Plan §Superfície de Segurança —
      linha "`versoes.env` interpretado como código"] {auto}

## Notes

- Items `{auto}` já vêm resolvidos pelo agente (`[x]` com citação, ou marcador
  `[Gap]`).
- Items `{humano}` ficam `[ ]` aguardando decisão do dono do produto.
- Gate `requirement-coverage.sh` já rodado sobre `spec.md` em
  [checklists/security.md](./security.md) (21/21 FRs cobertos, exit 0) — mesmo
  `spec.md`, não repetido aqui.
