#!/usr/bin/env bash
# scripts/verificar-agnostico.sh — varredura de agnosticismo do cockpit-dev.
#
# Garante o Princípio I (Agnosticismo Verificável, NON-NEGOTIABLE): nenhum
# arquivo versionado cita termo de projeto, cliente, organização, domínio ou
# credencial reais — nem no conteúdo, nem no caminho, nem no alvo de um
# symlink. Lê scripts/agnostico.lista (data-model.md §Lista de termos
# proibidos) e varre todo o repositório contra ela.
#
# Uso: ./scripts/verificar-agnostico.sh   (sem parâmetros — nenhum modo
# parcial: a garantia é sobre "todo arquivo do repositório")
#
# Efeito colateral: nenhum — só leitura. Idempotente por construção.
#
# Códigos de saída (contracts/cli.md):
#   0  zero ocorrências (inclui lista vazia ou só com comentários)
#   1  uma ou mais ocorrências, listadas como arquivo:linha:texto; ocorrência
#      no caminho sai como arquivo:0:(caminho) e no alvo de um symlink como
#      arquivo:0:(alvo do symlink)
#   2  erro de uso — agnostico.lista ausente ou ilegível, execução fora de um
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
TERMOS_TMP="$(mktemp)" || exit 2
ACHADOS_TMP="$(mktemp)" || exit 2
ARQS_TMP="$(mktemp)" || exit 2
trap 'rm -f "$TERMOS_TMP" "$TERMOS_TMP.raw" "$ACHADOS_TMP" "$ARQS_TMP"' EXIT

# Termos. Normalização ANTES de filtrar, senão "<termo>\r", "<termo> " ou um
# BOM grudado no primeiro termo nunca casariam (review rodadas 1-2):
#   - tr -d '\r'  : CRLF (tr, não sed 's/\r$//' — no BSD sed o \r é 'r' literal)
#   - BOM UTF-8   : só na 1ª linha (editor Windows "UTF-8 com BOM")
#   - trim        : espaço nas pontas
# Depois, '#' comenta e linha em branco é ignorada (research Decision 8). O que
# sobra são os termos, um por linha, casados como substring literal (grep -F,
# alimentado por -f para todos de uma vez). A leitura da lista fica fora do
# `|| true` para que um erro de I/O seja exit 2, não "OK".
BOM="$(printf '\357\273\277')"
tr -d '\r' < "$LISTA_REL" > "$TERMOS_TMP.raw" || {
  echo "Agnosticismo: erro de uso — falha ao ler $LISTA_REL." >&2
  exit 2
}
sed -e "1s/^$BOM//" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$TERMOS_TMP.raw" \
  | grep -vE '^(#|$)' > "$TERMOS_TMP" || true
rm -f "$TERMOS_TMP.raw"

if [ ! -s "$TERMOS_TMP" ]; then
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
  git cat-file -p ":$arquivo" 2>/dev/null \
    | grep -inaF -f "$TERMOS_TMP" \
    | while IFS= read -r ocorrencia; do
        printf '%s:%s\n' "$arquivo" "$ocorrencia" >> "$ACHADOS_TMP"
      done || true
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
