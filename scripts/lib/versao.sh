#!/usr/bin/env bash
# scripts/lib/versao.sh — funções de versão compartilhadas por instalar.sh e
# configurar.sh. Só define funções (sem efeito ao ser carregado por `source`).
# Requer REPO_ROOT definido pelo chamador (raiz do clone do cockpit).

# URL oficial do instalador do cstk — único lugar no código que a escreve.
CSTK_INSTALL_URL="https://github.com/JotJunior/cstk/releases/latest/download/install.sh"

# versao_ge <instalada> <minima> — compara MAJOR.MINOR.PATCH numericamente,
# em bash puro (sem sort -V — research Decision 4). Campo ausente = 0.
versao_ge() {
  local inst="${1#v}" min="${2#v}"
  local -a a b
  IFS=. read -ra a <<<"$inst"
  IFS=. read -ra b <<<"$min"
  local i ai bi
  for i in 0 1 2; do
    # Só a parte numérica de cada campo: "0-rc1", "1\r" ou "3 # x" viravam
    # erro aritmético ou 'unbound variable' sob set -u (review rodada 1).
    ai="${a[i]:-0}"; ai="${ai%%[^0-9]*}"; ai="${ai:-0}"
    bi="${b[i]:-0}"; bi="${bi%%[^0-9]*}"; bi="${bi:-0}"
    if ((10#$ai > 10#$bi)); then return 0; fi
    if ((10#$ai < 10#$bi)); then return 1; fi
  done
  return 0
}

# ler_cstk_min — extrai CSTK_MIN de versoes.env sem `source` e sem morrer:
# tolera CRLF, `export`, espaços em volta do `=`, aspas e comentário inline;
# devolve vazio se o arquivo ou a chave faltarem (a etapa 4 decide o que
# fazer com vazio). Nunca aborta o script (review rodada 1: grep sob
# pipefail matava o instalador sem relatório e com exit code colidindo com 2).
ler_cstk_min() {
  local arq="$REPO_ROOT/versoes.env" v=""
  [ -f "$arq" ] || return 0
  # tr, não sed 's/\r$//': no BSD sed (macOS) o \r é um 'r' literal. tail -1:
  # mesma semântica de `source`, a última atribuição vale (review rodada 2).
  # O literal do piso vive só em versoes.env (Princípio IV) — nem aqui, nem
  # em comentário, nem em mensagem.
  v="$(tr -d '\r' < "$arq" \
    | grep -E '^[[:space:]]*(export[[:space:]]+)?CSTK_MIN[[:space:]]*=' \
    | tail -1 | cut -d= -f2- || true)"
  v="${v%%#*}"
  v="${v//\"/}"
  v="${v//\'/}"
  printf '%s' "$v" | tr -d '[:space:]'
}
