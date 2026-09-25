# Quickstart: Esqueleto do cockpit-dev e instalador de máquina

Cenários que validam a implementação end-to-end. Cada um mapeia para um cenário de
aceitação da [spec.md](./spec.md) e pode ser executado sem o resto do MVP.

> **Isolamento**: os cenários de `instalar.sh` escrevem em `~/.claude/` e
> `~/.local/`. Para não mexer na máquina real, execute-os com `HOME` apontando
> para um diretório temporário (`HOME=$(mktemp -d) ./instalar.sh`). Isso também
> **testa o confinamento** exigido por FR-011: se algo escrever fora desse `HOME`,
> o script violou o Princípio VII.

---

## Scenario 1: Máquina nova fica pronta com um comando (happy path)

Cobre User Story 1 cenários 2 e 7; SC-001.

1. Numa máquina com `git`, `gh`, `node`, `jq` e `curl` presentes e conformes, mas
   **sem** `cstk` instalado.
2. Executar `./instalar.sh`.
3. **Expected**:
   - o `cstk` é instalado pelo one-liner oficial, em `~/.local/bin/`;
   - `cstk --version` responde e a versão é conferida contra `CSTK_MIN`;
   - o relatório final lista **cada** item (pré-requisitos, cstk, catálogo,
     skills, plugins) com seu status individual;
   - código de saída `0`.

---

## Scenario 2: Pré-requisitos ausentes — lista todos, não só o primeiro

Cobre User Story 1 cenário 1; Edge Case "mais de um pré-requisito ausente"; SC-005.

1. Numa máquina onde **dois ou mais** dos pré-requisitos estão ausentes (simular
   executando com um `PATH` reduzido que esconda, por exemplo, `jq` e `gh`).
2. Executar `./instalar.sh`.
3. **Expected**:
   - falha **antes** de tentar qualquer instalação;
   - a mensagem lista **todos** os ausentes de uma vez — não para no primeiro;
   - o diagnóstico identifica a ferramenta e, quando há piso, a versão exigida,
     sem precisar consultar log;
   - código de saída `2`.

---

## Scenario 3: Atualiza antes de conferir o piso

Cobre User Story 1 cenário 3; Princípio IV (ordem `self-update` → piso).

1. Numa máquina com `cstk` instalado numa versão **anterior** à última release.
2. Executar `./instalar.sh`.
3. **Expected**:
   - `cstk self-update` roda **antes** de qualquer comparação com `CSTK_MIN`;
   - a versão conferida na etapa seguinte é a **já atualizada**;
   - se a versão atualizada satisfaz o piso, o comando segue normalmente e termina
     com `0` — uma máquina desatualizada se cura sozinha, não falha.

---

## Scenario 4: Versão abaixo do piso mesmo após atualizar (error case)

Cobre User Story 1 cenário 4.

1. Editar `versoes.env` elevando `CSTK_MIN` para uma versão acima da última
   release disponível (ex.: `CSTK_MIN=99.0.0`).
2. Executar `./instalar.sh`.
3. **Expected**:
   - a atualização roda normalmente;
   - a conferência do piso falha com mensagem clara informando **a versão
     instalada e o piso exigido**;
   - código de saída `1`.
4. Reverter `versoes.env`.

---

## Scenario 5: `cstk` não responde à checagem de versão (error case)

Cobre User Story 1 cenário 5; FR-005; Princípio IV (cláusula final).

1. Simular um `cstk` presente no `PATH` que falha ao ser chamado (ex.: um
   executável que sai com código não-zero).
2. Executar `./instalar.sh`.
3. **Expected**:
   - falha com mensagem clara de que o `cstk` não respondeu;
   - **nunca** prossegue silenciosamente sem essa peça — a etapa de implementação
     do ciclo não existe sem ela;
   - código de saída `1`.

---

## Scenario 6: Idempotência — segunda execução não duplica nem sobrescreve

Cobre User Story 1 cenário 6; FR-010; SC-002; Princípio VII.

1. Executar `./instalar.sh` numa máquina e guardar o relatório.
2. Executar `./instalar.sh` **de novo**, sem mudar nada entre as duas.
3. **Expected**:
   - o relatório da segunda execução reporta sucesso igual ao da primeira;
   - nada é duplicado (nenhum registro de marketplace ou plugin repetido);
   - código de saída `0` nas duas.
4. Agora editar localmente uma skill já instalada em `~/.claude/skills/` e executar
   uma terceira vez.
5. **Expected**: a divergência local é **avisada** explicitamente no relatório —
   nunca sobrescrita em silêncio (research Decision 14).

---

## Scenario 7: Plugin recomendado falha, comando ainda tem sucesso

Cobre FR-008; Edge Case "falha do plugin recomendado"; decisão do `/clarify`.

1. Tornar o marketplace do `ponytail` inalcançável (ex.: executar sem rede, ou
   apontar a origem para um repositório inexistente).
2. Executar `./instalar.sh` com o `context-mode` alcançável normalmente.
3. **Expected**:
   - o item `ponytail` aparece como `[falhou]` no relatório;
   - **o comando termina com sucesso**, código de saída `0`;
   - o mesmo teste com o `context-mode` inalcançável deve, ao contrário, falhar o
     comando inteiro com código `1`.

---

## Scenario 8: Agnosticismo — repositório limpo (happy path)

Cobre User Story 2 cenário 1; FR-013; a armadilha da auto-exclusão.

1. Com o repositório sem nenhum termo proibido, executar
   `./scripts/verificar-agnostico.sh`.
2. **Expected**:
   - zero ocorrências reportadas, código de saída `0`;
   - **em particular**, a varredura **não** casa contra `scripts/agnostico.lista`,
     que contém os próprios termos. Se este cenário falhar com ocorrências
     apontando para o arquivo de lista, a exclusão da research Decision 7 não foi
     implementada — é o modo de falha mais provável deste script.

---

## Scenario 9: Agnosticismo — termo plantado é apontado com arquivo e linha

Cobre User Story 2 cenários 2 e 3; FR-014; FR-015; SC-003.

1. Acrescentar um termo de teste a `scripts/agnostico.lista` (ex.:
   `termo-de-teste-agnostico`).
2. Inserir esse mesmo termo numa linha conhecida de um arquivo qualquer
   versionado.
3. Executar `./scripts/verificar-agnostico.sh`.
4. **Expected**:
   - falha com código de saída `1`;
   - a saída aponta **o arquivo e o número da linha exatos** da ocorrência
     plantada — e apenas ela, não a entrada correspondente no arquivo de lista.
5. Repetir com o termo em **outra capitalização** (`Termo-De-Teste-Agnostico`).
6. **Expected**: também é detectado (casamento sem distinção de maiúsculas).
7. Reverter as duas edições e confirmar que o Scenario 8 volta a passar — prova de
   que a lista é editável sem tocar no script (FR-015).

---

## Scenario 10: CI barra as três classes de problema

Cobre User Story 3 cenários 1 a 4; FR-017; FR-018; FR-019; SC-004; SC-006.

1. Abrir uma alteração de teste que introduza um script shell com problema de
   portabilidade conhecido que o `shellcheck` detecte.
2. **Expected**: o job `shellcheck` falha, apontando o script e o problema; o job
   `agnostico` passa — a identificação de **qual** garantia barrou fica evidente
   pelo job que ficou vermelho.
3. Abrir outra alteração de teste que introduza um termo da lista proibida.
4. **Expected**: o job `agnostico` falha pelo mesmo motivo que o Scenario 9
   reportaria localmente; o job `shellcheck` passa.
5. Abrir outra alteração de teste que introduza um segredo de teste (uma chave
   fictícia num formato que o detector reconheça — nunca uma credencial real).
6. **Expected**: o job `segredos` falha apontando **arquivo e linha**, e o valor
   detectado **não** aparece no log do job (efeito do `--redact` — FR-019); os
   jobs `shellcheck` e `agnostico` passam.
7. Registrar o *fingerprint* do achado do passo 5 em `.gitleaksignore` e reabrir.
8. **Expected**: o job `segredos` passa, e a exceção está visível no diff da PR —
   nenhuma supressão acontece fora do repositório (FR-021).
9. Abrir uma alteração sem nenhum dos três problemas.
10. **Expected**: os três jobs passam e a mudança segue para revisão humana.

---

## Scenario 11: Confinamento de escrita (FR-011, Princípio VII)

1. Criar um diretório de projeto-alvo qualquer e registrar o estado dele
   (ex.: `find <projeto> -newer <marco temporal>`).
2. Executar `HOME=$(mktemp -d) ./instalar.sh`.
3. **Expected**:
   - nenhum arquivo criado ou modificado fora do `HOME` temporário;
   - em particular, **nada** escrito dentro do diretório de projeto-alvo — o
     `instalar.sh` não tem nem parâmetro para recebê-lo.

---

> **Nota sobre o cenário de roundtrip backend↔frontend** do template: não se
> aplica. A feature é single-layer (scripts de shell e workflow de CI), sem
> serviço, payload ou borda de serialização — conforme §Convenções de Borda do
> [plan.md](./plan.md).
