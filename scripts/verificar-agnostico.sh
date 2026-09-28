#!/usr/bin/env bash
# scripts/verificar-agnostico.sh — varredura de agnosticismo do cockpit-dev.
#
# Garante o Princípio I (Agnosticismo Verificável, NON-NEGOTIABLE): nenhum
# arquivo versionado cita termo de projeto, cliente, organização, domínio ou
# credencial reais — nem no conteúdo, nem no caminho, nem no alvo de um
# symlink. O conjunto de termos proibidos é a UNIÃO de duas fontes
# complementares (FR-022, emenda 1.1.0): scripts/agnostico.lista (versionada,
# data-model.md §Lista de termos proibidos, PODE ficar vazia) e a variável de
# ambiente AGNOSTICO_TERMOS (fora do repositório — variável de Actions no CI,
# ou exportada localmente pelo dev a partir de um arquivo ignorado pelo git).
# Mesmo formato nas duas: um termo por linha, `#` comenta, linha em branco é
# ignorada. Varre todo o repositório contra o conjunto unido.
#
# Guarda anti-vacuidade (research Decision 17): se as duas fontes ficarem
# vazias e AGNOSTICO_EXIGIR_TERMOS=1 estiver setada (o job `agnostico` do CI
# a exporta sempre), o script falha — a garantia nunca é "vazia por
# construção" no CI. Fora do CI (variável ausente), conjunto vazio segue
# sendo estado inicial legítimo (sucesso).
#
# Uso: ./scripts/verificar-agnostico.sh   (sem parâmetros — nenhum modo
# parcial: a garantia é sobre "todo arquivo do repositório")
#
# Efeito colateral: nenhum — só leitura. Idempotente por construção.
#
# Códigos de saída (contracts/cli.md):
#   0  zero ocorrências (inclui as duas fontes de termos vazias quando
#      AGNOSTICO_EXIGIR_TERMOS não é "1")
#   1  uma ou mais ocorrências, listadas como arquivo:linha:texto; ocorrência
#      no caminho sai como arquivo:0:(caminho) e no alvo de um symlink como
#      arquivo:0:(alvo do symlink)
#   2  erro de uso — agnostico.lista ausente ou ilegível, as duas fontes de
#      termos vazias com AGNOSTICO_EXIGIR_TERMOS=1, execução fora de um
#      repositório git, git ls-files falhando ou sem listar este script,
#      arquivo versionado ilegível, ou falha ao criar arquivo temporário
set -euo pipefail

LISTA_REL="scripts/agnostico.lista"
SELF_REL="scripts/verificar-agnostico.sh"

# Caixa fora do ASCII (Promoção vs PROMOÇÃO) só dobra em locale UTF-8; o runner
# do GitHub já é C.UTF-8, uma máquina local pode estar em C/POSIX e divergir em
# silêncio (review rodada 2). Só exporta se o locale existir.
# Sem pipe para `grep -q`: ele encerra no primeiro casamento, o escritor leva
# SIGPIPE e, sob pipefail, o `if` falha — numa máquina com muitos locales o
# export quase nunca acontecia (review rodada 3).
case "$(locale -a 2>/dev/null || true)" in
  *C.UTF-8*|*C.utf8*) export LC_ALL=C.UTF-8 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || {
  echo "Agnosticismo: erro de uso — não foi possível resolver a raiz do script." >&2
  exit 2
}
cd "$REPO_ROOT" || exit 2

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Agnosticismo: erro de uso — execução fora de um repositório git." >&2
  exit 2
fi

if [ ! -f "$LISTA_REL" ]; then
  echo "Agnosticismo: erro de uso — $LISTA_REL ausente." >&2
  exit 2
fi
if [ ! -r "$LISTA_REL" ]; then
  echo "Agnosticismo: erro de uso — $LISTA_REL ilegível." >&2
  exit 2
fi

# `|| exit 2`: TMPDIR cheio ou sem permissão sairia 1 por `set -e`, o mesmo
# código de "termo proibido encontrado", e o CI acusaria ocorrência sem lista
# (review rodada 3).
# Template explícito: o `mktemp` do BSD (macOS, alvo declarado no plan) exige
# template e falharia sem argumento, saindo 2 em toda máquina local
# (review rodada 4).
LISTA_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
ENV_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
ENV_INPUT_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
TERMOS_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
ACHADOS_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
ARQS_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
BLOB_TMP="$(mktemp "${TMPDIR:-/tmp}/agnostico.XXXXXX")" || exit 2
trap 'rm -f "$LISTA_TMP" "$LISTA_TMP.raw" "$LISTA_TMP.trim" "$ENV_TMP" "$ENV_TMP.raw" "$ENV_TMP.trim" "$ENV_INPUT_TMP" "$TERMOS_TMP" "$ACHADOS_TMP" "$ARQS_TMP" "$BLOB_TMP" "$BLOB_TMP.oc"' EXIT

# Termos, duas fontes (FR-022). Normalização ANTES de filtrar, senão
# "<termo>\r", "<termo> " ou um BOM grudado no primeiro termo nunca casariam
# (review rodadas 1-2):
#   - tr -d '\r'  : CRLF (tr, não sed 's/\r$//' — no BSD sed o \r é 'r' literal)
#   - BOM UTF-8   : só na 1ª linha (editor Windows "UTF-8 com BOM")
#   - trim        : espaço nas pontas
# Depois, '#' comenta e linha em branco é ignorada (research Decision 8). O que
# sobra são os termos, um por linha, casados como substring literal (grep -F,
# alimentado por -f para todos de uma vez). Mesma normalização para as duas
# fontes — função única para não divergirem com o tempo.
BOM="$(printf '\357\273\277')"

# normalizar_termos <arquivo-de-entrada> <arquivo-de-saida> <rotulo-p/-erro>
# A leitura fica fora do `|| true` para que um erro de I/O seja exit 2, não
# "OK"; sem pipeline com `|| true` no filtro final, senão engolia também uma
# falha do sed ou da escrita (TMPDIR cheio) e o script anunciava "OK" sem ter
# aplicado um único termo — falso negativo da guarda (review rodada 4). Só o
# rc 1 do `grep -v` (fonte só com comentários) é aceitável.
normalizar_termos() {
  local origem="$1" destino="$2" rotulo="$3" rc
  tr -d '\r' < "$origem" > "$destino.raw" || {
    echo "Agnosticismo: erro de uso — falha ao ler $rotulo." >&2
    exit 2
  }
  sed -e "1s/^$BOM//" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$destino.raw" \
    > "$destino.trim" || {
    echo "Agnosticismo: erro de uso — falha ao normalizar $rotulo." >&2
    exit 2
  }
  grep -vE '^(#|$)' "$destino.trim" > "$destino" || {
    rc=$?
    if [ "$rc" -ne 1 ]; then
      echo "Agnosticismo: erro de uso — falha ao filtrar $rotulo (grep rc=$rc)." >&2
      exit 2
    fi
  }
  rm -f "$destino.raw" "$destino.trim"
}

normalizar_termos "$LISTA_REL" "$LISTA_TMP" "$LISTA_REL"

# AGNOSTICO_TERMOS: variável de ambiente, não arquivo — grava o valor num
# temporário antes de reusar a mesma normalização. `printf '%s'` (nunca
# `echo`) preserva o conteúdo literal, inclusive sem quebra de linha final.
printf '%s' "${AGNOSTICO_TERMOS:-}" > "$ENV_INPUT_TMP" || {
  echo "Agnosticismo: erro de uso — falha ao materializar AGNOSTICO_TERMOS." >&2
  exit 2
}
normalizar_termos "$ENV_INPUT_TMP" "$ENV_TMP" "AGNOSTICO_TERMOS"
rm -f "$ENV_INPUT_TMP"

# União (FR-022): concatenação simples — grep -f não distingue a origem de
# cada padrão, e não precisa.
cat "$LISTA_TMP" "$ENV_TMP" > "$TERMOS_TMP" || {
  echo "Agnosticismo: erro de uso — falha ao unir as fontes de termos." >&2
  exit 2
}

if [ ! -s "$TERMOS_TMP" ]; then
  # Guarda anti-vacuidade (research Decision 17): só falha quando a execução
  # se declara CI via AGNOSTICO_EXIGIR_TERMOS=1 (o job `agnostico` sempre
  # exporta) — nunca por inferência de variável do runner (Princípio V). Fora
  # do CI, conjunto vazio permanece estado inicial legítimo. Nunca imprime os
  # termos em si, só que as duas fontes estão vazias.
  if [ "${AGNOSTICO_EXIGIR_TERMOS:-}" = "1" ]; then
    echo "Agnosticismo: erro de uso — as duas fontes de termos (scripts/agnostico.lista e AGNOSTICO_TERMOS) estão vazias; AGNOSTICO_EXIGIR_TERMOS=1 exige ao menos um termo em alguma delas." >&2
    exit 2
  fi
  echo "Agnosticismo: OK — nenhuma ocorrência de termo proibido."
  exit 0
fi

# Enumerar arquivos versionados via git ls-files (research Decision 6),
# materializado para que uma falha (índice corrompido, rc 128) não vire "OK"
# — o rc de um processo substituído é invisível (review rodada 2). Exigir que
# este script conste da lista pega a cópia sem .git dentro de outro
# repositório, em que ls-files responde vazio.
git ls-files -z > "$ARQS_TMP" || {
  echo "Agnosticismo: erro de uso — git ls-files falhou." >&2
  exit 2
}
# `grep -z` direto no arquivo, sem `tr |`: com a lista passando do buffer do
# pipe (~64 KiB), o `grep -q` encerrava cedo, o `tr` levava SIGPIPE e o
# pipefail transformava isso em "erro de uso" falso (review rodada 3).
if ! grep -zqxF -- "$SELF_REL" "$ARQS_TMP"; then
  echo "Agnosticismo: erro de uso — $SELF_REL não consta de git ls-files (cópia sem .git dentro de outro repositório?)." >&2
  exit 2
fi

# Para cada entrada versionada (a própria lista excluída — research Decision
# 7, senão casaria contra si mesma e falharia sempre):
#   1. o CAMINHO é casado antes de qualquer filtro: gitlink, symlink e arquivo
#      apagado do worktree mas ainda no índice também vão ao remoto;
#   2. symlink: o git versiona o TEXTO do alvo, não o conteúdo apontado —
#      casa o readlink e não segue o link (senão varreria arquivo fora do
#      repositório);
#   3. conteúdo: grep -a trata todo arquivo como texto, independente do
#      locale (sem -a, um .md em Latin-1 era "binário" e a ocorrência sumia);
#      -H prefixa "arquivo:linha:" sem interpolar o nome num programa sed.
#      rc 1 = sem ocorrência; qualquer outro rc é erro real e sai com 2.
while IFS= read -r -d '' arquivo; do
  [ "$arquivo" = "$LISTA_REL" ] && continue
  if printf '%s\n' "$arquivo" | grep -qiF -f "$TERMOS_TMP"; then
    printf '%s:0:(caminho)\n' "$arquivo" >> "$ACHADOS_TMP"
  fi
  if [ -L "$arquivo" ]; then
    # `--`: nome começando com hífen viraria opção do readlink e o alvo
    # escaparia da varredura (review rodada 3).
    if readlink -- "$arquivo" | grep -qiF -f "$TERMOS_TMP"; then
      printf '%s:0:(alvo do symlink)\n' "$arquivo" >> "$ACHADOS_TMP"
    fi
    continue
  fi
  # Gitlink (submódulo): o repositório-pai versiona só o ponteiro. O caminho já
  # foi casado acima; não há conteúdo deste repositório para varrer. Conferir o
  # modo 160000 e não só "é diretório": um arquivo versionado que virou
  # diretório no worktree (merge abortado, troca manual) tem blob no índice, e
  # pular por `-d` era falso negativo da guarda (review rodada 5).
  if [ -d "$arquivo" ] && git ls-files -s -- "$arquivo" | grep -q '^160000'; then
    continue
  fi
  if [ -f "$arquivo" ]; then
    grep -inaHF -f "$TERMOS_TMP" -- "$arquivo" >> "$ACHADOS_TMP" || {
      rc=$?
      if [ "$rc" -ne 1 ]; then
        echo "Agnosticismo: erro ao ler '$arquivo' (grep rc=$rc)." >&2
        exit 2
      fi
    }
    continue
  fi
  # Versionado mas ausente do disco (sparse checkout, skip-worktree): o que vai
  # ao remoto é o blob do índice, não o worktree — varrer o blob, senão o
  # conteúdo passaria em silêncio (review rodada 3). O nome é prefixado por
  # printf, nunca interpolado num programa sed.
  if ! git cat-file -p ":$arquivo" > "$BLOB_TMP" 2>/dev/null; then
    # Não engolir: o ramo do worktree acima trata erro de leitura como exit 2
    # e o cabeçalho promete o mesmo. Gitlink não checado já saiu no `-d`; o
    # que sobra aqui é índice corrompido ou objeto ausente (review rodada 4).
    if git ls-files -s -- "$arquivo" | grep -q '^160000'; then
      continue
    fi
    echo "Agnosticismo: erro ao ler o blob de '$arquivo' no índice." >&2
    exit 2
  fi
  grep -inaF -f "$TERMOS_TMP" "$BLOB_TMP" > "$BLOB_TMP.oc" || {
    rc=$?
    if [ "$rc" -ne 1 ]; then
      echo "Agnosticismo: erro ao varrer o blob de '$arquivo' (grep rc=$rc)." >&2
      exit 2
    fi
  }
  # Prefixo por printf, nunca interpolado num programa sed.
  while IFS= read -r ocorrencia; do
    printf '%s:%s\n' "$arquivo" "$ocorrencia" >> "$ACHADOS_TMP"
  done < "$BLOB_TMP.oc"
  rm -f "$BLOB_TMP.oc"
done < "$ARQS_TMP"

if [ ! -s "$ACHADOS_TMP" ]; then
  echo "Agnosticismo: OK — nenhuma ocorrência de termo proibido."
  exit 0
fi

N="$(wc -l < "$ACHADOS_TMP" | tr -d '[:space:]')"
echo "Agnosticismo: FALHOU — ${N} ocorrência(s) de termo proibido:"
# Coluna de texto truncada: um binário com o termo despejaria o blob inteiro
# no log da PR (review rodada 2). O contrato pede a colisão, não o conteúdo.
# `-b`, não `-c`: o GNU cut conta bytes de qualquer forma, e dizer "bytes"
# evita prometer um corte por caractere que não acontece (review rodada 3).
cut -b1-200 "$ACHADOS_TMP" | sed 's/^/  /'
exit 1
