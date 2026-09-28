# Quickstart: Esqueleto do cockpit-dev e instalador de máquina

Cenários que validam a implementação end-to-end. Cada um mapeia para um cenário de
aceitação da [spec.md](./spec.md) e pode ser executado sem o resto do MVP.

> **Isolamento**: desde a emenda 1.1.0 o `instalar.sh` só **escreve** em
> `~/.claude/skills/` (skills do próprio cockpit) — o resto é verificação somente
> leitura, e toda lacuna vira comando impresso (`Execute: ...`). Para não mexer na máquina real, execute-os com `HOME` apontando
> para um diretório temporário (`HOME=$(mktemp -d) ./instalar.sh`). Isso também
> **testa o confinamento** exigido por FR-011: se algo escrever fora desse `HOME`,
> o script violou o Princípio VII.

---

## Scenario 1: Máquina sem `cstk` — para e imprime o comando oficial

Cobre User Story 1 cenários 2 e 7; FR-002; FR-009; Princípio IV (emenda 1.1.0).

1. Numa máquina com `git`, `gh`, `node`, `jq` e `curl` presentes e conformes, mas
   **sem** `cstk` no `PATH` (ex.: `HOME` temporário e `PATH` sem `~/.local/bin`).
2. Executar `./instalar.sh`.
3. **Expected**:
   - o script **não** baixa nem executa nada: nenhum arquivo novo em `~/.local/`,
     nenhum processo `curl` de download disparado pelo script;
   - o item `cstk presente` sai `[falhou]` com as linhas `Execute:` da URL oficial
     em dois passos (baixar para arquivo, inspecionar, executar — contracts/cli.md);
   - o relatório lista só `Pré-requisitos de máquina` e `cstk presente` — as
     etapas seguintes **não aparecem** (sequencial por gates, clarify r02);
   - código de saída `1`.
4. Executar os comandos impressos, rodar `./instalar.sh` de novo.
5. **Expected**: a etapa 2 passa e o pipeline avança para as seguintes.

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

## Scenario 3: Release mais nova acima do piso — avisa, não atualiza

Cobre User Story 1 cenário 3; FR-003; Princípio IV (emenda 1.1.0).

1. Numa máquina com `cstk` instalado numa versão que atende `CSTK_MIN`, mas
   **anterior** à última release (`cstk self-update --check` sai `10`).
2. Registrar `cstk --version`.
3. Executar `./instalar.sh`.
4. **Expected**:
   - o item de versão sai `[aviso]` com a release disponível e
     `Execute: cstk self-update`;
   - `cstk --version` depois da execução é **igual** ao do passo 2 — nada foi
     atualizado pelo script;
   - as etapas seguintes rodam normalmente; código de saída `0` se nada
     bloqueante falhar.
5. Repetir sem rede (o `--check` sai `1`).
6. **Expected**: `[aviso]` "não foi possível verificar release" — nunca `[ok]`,
   nunca bloqueio.

---

## Scenario 4: Versão abaixo do piso (error case)

Cobre User Story 1 cenário 4; FR-004.

1. Editar `versoes.env` elevando `CSTK_MIN` para uma versão acima da instalada
   (ex.: `CSTK_MIN=99.0.0`).
2. Executar `./instalar.sh`.
3. **Expected**:
   - nenhum `self-update` é executado;
   - a conferência do piso falha com mensagem clara informando **a versão
     instalada, o piso exigido** e `Execute: cstk self-update`;
   - o relatório para nessa etapa (catálogo, skills e plugins não aparecem);
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
2. Executar `./instalar.sh` **de novo**, sem mudar nada entre as duas (e sem
   executar nenhum comando impresso).
3. **Expected**:
   - o relatório e os comandos impressos da segunda execução são iguais aos da
     primeira;
   - nada é duplicado (nenhum registro de marketplace ou plugin — o script não
     registra nenhum);
   - mesmo código de saída nas duas.
4. Agora editar localmente uma skill **do cockpit** já copiada em
   `~/.claude/skills/` e executar uma terceira vez.
5. **Expected**: a divergência local é **avisada** explicitamente no relatório —
   nunca sobrescrita em silêncio (research Decision 14).

---

## Scenario 7: Plugin recomendado ausente, comando ainda tem sucesso

Cobre FR-008; Edge Case "falha do plugin recomendado"; decisão do `/clarify`.

1. Numa máquina com `context-mode` instalado e habilitado no escopo `user`, e
   `ponytail` **ausente** (ou desabilitado).
2. Executar `./instalar.sh`.
3. **Expected**:
   - o item `ponytail` aparece como `[falhou]` não bloqueante, com
     `Execute: claude plugin install ...` (ausente) ou
     `Execute: claude plugin enable ...` (desabilitado);
   - nenhum `claude plugin install/update/enable` é executado pelo script;
   - **o comando termina com sucesso**, código de saída `0`;
   - o mesmo teste com o `context-mode` ausente/desabilitado deve, ao contrário,
     falhar o comando inteiro com código `1`.

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
   `termo-de-teste-agnostico` — termo que não identifica ninguém, o único tipo
   que a lista versionada aceita desde a emenda 1.1.0).
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

## Scenario 12: Sem permissão de escrita — falha na etapa 1, sem estado parcial

Cobre User Story 1 cenário 8; Edge Case "sem permissão de escrita"; FR-011.

1. Simular `~/.claude/skills/` sem permissão de escrita para o usuário
   (ex.: `chmod 555` no diretório dentro do `HOME` temporário do cenário 11).
2. Executar `./instalar.sh`.
3. **Expected**:
   - falha **na etapa 1**, antes de qualquer outra etapa;
   - a mensagem identifica a área que não aceitou a escrita;
   - código de saída `3` (contracts/cli.md);
   - nenhum arquivo novo fica para trás.
4. Restaurar a permissão do diretório.

---

## Scenario 13: Só o plugin ausente é mencionado

Cobre User Story 1 cenário 9; Edge Case "plugin ausente"; FR-008.

1. Numa máquina com `cstk` na versão exigida, `context-mode` instalado e
   habilitado no escopo `user`, e `ponytail` ausente.
2. Registrar o estado do `context-mode` (`claude plugin list --json`).
3. Executar `./instalar.sh`.
4. **Expected**:
   - só o `ponytail` recebe linha `Execute:`;
   - o `context-mode` sai `[ok]` **sem** comando impresso, e o estado do passo 2
     fica inalterado — o script não o toca;
   - código de saída `0` (o `ponytail` é recomendado).

---

## Scenario 14: Catálogo de skills ausente bloqueia; defasado só avisa

Cobre FR-006; Edge Cases "catálogo nunca provisionado" e "catálogo desatualizado".

1. Num `HOME` temporário com `cstk` acessível no `PATH` e **sem**
   `~/.claude/skills/.cstk-manifest`.
2. Executar `./instalar.sh`.
3. **Expected**: o item do catálogo sai `[falhou]` com `Execute: cstk install`;
   o relatório para nele; código `1`; nenhum `cstk install` executado.
4. Executar `cstk install`, simular defasagem (release nova do catálogo, ou uma
   skill do perfil apagada do disco) e rodar de novo.
5. **Expected**: `[aviso]` com `Execute: cstk update` (defasado) e/ou
   `Execute: cstk install <nome>` (faltando); as etapas seguintes rodam; o
   catálogo em disco fica **idêntico** ao de antes da execução.

---

## Scenario 15: Agnosticismo no CI não passa por vacuidade

Cobre FR-022; Princípio I (emenda 1.1.0); research Decision 17.

1. Com `scripts/agnostico.lista` sem termos e `AGNOSTICO_TERMOS` não definida,
   executar `./scripts/verificar-agnostico.sh`.
2. **Expected**: código `0` — fora do CI, conjunto vazio é estado legítimo.
3. Executar `AGNOSTICO_EXIGIR_TERMOS=1 ./scripts/verificar-agnostico.sh`.
4. **Expected**: código `2`, mensagem dizendo que nenhuma das duas fontes tem
   termo; nenhum termo impresso.
5. Executar com `AGNOSTICO_TERMOS='termo-de-teste-agnostico'` e
   `AGNOSTICO_EXIGIR_TERMOS=1`, com o termo plantado num arquivo versionado.
6. **Expected**: código `1` apontando arquivo e linha — a fonte externa é casada
   exatamente como a lista versionada; a saída não lista os termos além do
   trecho da linha onde o termo vazou.
7. No CI, com o secret `AGNOSTICO_TERMOS` vazio ou ausente (inclusive PR de fork): o job `agnostico` fica vermelho, mesmo com `scripts/agnostico.lista` preenchida.

---

> **Nota sobre o cenário de roundtrip backend↔frontend** do template: não se
> aplica. A feature é single-layer (scripts de shell e workflow de CI), sem
> serviço, payload ou borda de serialização — conforme §Convenções de Borda do
> [plan.md](./plan.md).
