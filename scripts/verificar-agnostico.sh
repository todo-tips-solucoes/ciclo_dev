#!/usr/bin/env bash
# scripts/verificar-agnostico.sh — varredura de agnosticismo do cockpit-dev.
#
# Garante o Princípio I (Agnosticismo Verificável, NON-NEGOTIABLE): nenhum
# arquivo versionado cita termo de projeto, cliente, organização, domínio ou
# credencial reais. Lê scripts/agnostico.lista (data-model.md §Lista de
# termos proibidos) e varre todo o repositório contra ela.
#
# Uso: ./scripts/verificar-agnostico.sh   (sem parâmetros — nenhum modo
# parcial: a garantia é sobre "todo arquivo do repositório")
#
# Efeito colateral: nenhum — só leitura. Idempotente por construção.
#
# Códigos de saída (contracts/cli.md):
#   0  zero ocorrências (inclui lista vazia ou só com comentários)
#   1  uma ou mais ocorrências, listadas com arquivo e linha
#   2  erro de uso — agnostico.lista ausente, ou execução fora de um
#      repositório git (a enumeração depende de git ls-files)
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

# Filtrar termos reais: '#' comenta, linhas em branco ignoradas
# (research Decision 8). O que sobra são os termos, um por linha, casados
# como substring literal (grep -F, alimentado por -f para todos de uma vez).
grep -vE '^[[:space:]]*(#|$)' "$LISTA_REL" > "$TERMOS_TMP" || true

if [ ! -s "$TERMOS_TMP" ]; then
  echo "Agnosticismo: OK — nenhuma ocorrência de termo proibido."
  exit 0
fi

# Enumerar arquivos versionados via git ls-files (research Decision 6),
# excluindo a própria lista da varredura (research Decision 7 — senão ela
# casaria contra si mesma e a verificação falharia sempre).
while IFS= read -r -d '' arquivo; do
  [ "$arquivo" = "$LISTA_REL" ] && continue
  [ -f "$arquivo" ] || continue
  grep -inF -f "$TERMOS_TMP" -- "$arquivo" 2>/dev/null \
    | sed "s|^|${arquivo}:|" >> "$ACHADOS_TMP" || true
done < <(git ls-files -z)

if [ ! -s "$ACHADOS_TMP" ]; then
  echo "Agnosticismo: OK — nenhuma ocorrência de termo proibido."
  exit 0
fi

N="$(wc -l < "$ACHADOS_TMP" | tr -d '[:space:]')"
echo "Agnosticismo: FALHOU — ${N} ocorrência(s) de termo proibido:"
sed 's/^/  /' "$ACHADOS_TMP"
exit 1
