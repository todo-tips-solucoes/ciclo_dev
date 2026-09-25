#!/usr/bin/env bash
# scripts/verificar-agnostico.sh — varredura de agnosticismo do cockpit-dev.
#
# Garante o Princípio I (Agnosticismo Verificável, NON-NEGOTIABLE): nenhum
# arquivo versionado cita termo de projeto, cliente, organização, domínio ou
# credencial reais — nem no conteúdo, nem no caminho. Lê
# scripts/agnostico.lista (data-model.md §Lista de termos proibidos) e varre
# todo o repositório contra ela.
#
# Uso: ./scripts/verificar-agnostico.sh   (sem parâmetros — nenhum modo
# parcial: a garantia é sobre "todo arquivo do repositório")
#
# Efeito colateral: nenhum — só leitura. Idempotente por construção.
#
# Códigos de saída (contracts/cli.md):
#   0  zero ocorrências (inclui lista vazia ou só com comentários)
#   1  uma ou mais ocorrências, listadas como arquivo:linha:texto; ocorrência
#      no caminho do arquivo sai como arquivo:0:(caminho)
#   2  erro de uso — agnostico.lista ausente, execução fora de um repositório
#      git (a enumeração depende de git ls-files), ou arquivo ilegível
set -euo pipefail

LISTA_REL="scripts/agnostico.lista"

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

TERMOS_TMP="$(mktemp)"
ACHADOS_TMP="$(mktemp)"
trap 'rm -f "$TERMOS_TMP" "$ACHADOS_TMP"' EXIT

# Termos: tira CR (lista salva com CRLF) e espaço nas pontas ANTES de filtrar
# — sem isso "<termo>\r" ou "<termo> " nunca casariam (review rodada 1). Depois,
# '#' comenta e linha em branco é ignorada (research Decision 8). O que sobra
# são os termos, um por linha, casados como substring literal (grep -F,
# alimentado por -f para todos de uma vez).
sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$LISTA_REL" \
  | grep -vE '^(#|$)' > "$TERMOS_TMP" || true

if [ ! -s "$TERMOS_TMP" ]; then
  echo "Agnosticismo: OK — nenhuma ocorrência de termo proibido."
  exit 0
fi

# Enumerar arquivos versionados via git ls-files (research Decision 6),
# excluindo a própria lista da varredura (research Decision 7 — senão ela
# casaria contra si mesma e a verificação falharia sempre).
#
# Conteúdo: grep -a trata todo arquivo como texto, independente do locale —
# sem isso um .md em Latin-1 era classificado como binário em C.UTF-8 e a
# ocorrência sumia em silêncio. -H prefixa "arquivo:linha:" sem interpolar o
# nome num programa sed (nome com '|', '&', '\' ou newline quebrava o sed e
# o achado era descartado). rc 1 = sem ocorrência; qualquer outro rc é erro
# real e sai com 2 em vez de ser engolido (review rodada 1).
while IFS= read -r -d '' arquivo; do
  [ "$arquivo" = "$LISTA_REL" ] && continue
  [ -f "$arquivo" ] || continue
  if printf '%s\n' "$arquivo" | grep -qiF -f "$TERMOS_TMP"; then
    printf '%s:0:(caminho)\n' "$arquivo" >> "$ACHADOS_TMP"
  fi
  grep -inaHF -f "$TERMOS_TMP" -- "$arquivo" >> "$ACHADOS_TMP" || {
    rc=$?
    if [ "$rc" -ne 1 ]; then
      echo "Agnosticismo: erro ao ler '$arquivo' (grep rc=$rc)." >&2
      exit 2
    fi
  }
done < <(git ls-files -z)

if [ ! -s "$ACHADOS_TMP" ]; then
  echo "Agnosticismo: OK — nenhuma ocorrência de termo proibido."
  exit 0
fi

N="$(wc -l < "$ACHADOS_TMP" | tr -d '[:space:]')"
echo "Agnosticismo: FALHOU — ${N} ocorrência(s) de termo proibido:"
sed 's/^/  /' "$ACHADOS_TMP"
exit 1
