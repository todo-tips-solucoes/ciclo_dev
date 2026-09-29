#!/usr/bin/env bash
# scripts/testar-configurar.sh — cenários de docs/specs/configurar/quickstart.md.
#
# Cada cenário roda num repositório git temporário; o `cstk` é sempre o falso
# deste script (nunca o real). Sai diferente de zero na primeira falha, dizendo
# qual cenário falhou. Sem framework, sem rede.
# shellcheck disable=SC2015 # `A && B || falha` é o idioma dos cenários: falha() sai
set -euo pipefail

RAIZ_COCKPIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CENARIO="(nenhum)"

falha() {
  printf 'FALHOU: cenário %s — %s\n' "$CENARIO" "$*" >&2
  exit 1
}
cenario() { CENARIO="$1"; printf 'Cenário %s\n' "$1"; }
espera() { # espera "descrição" comando...
  local d="$1"; shift
  "$@" || falha "$d"
}

# cstk falso: informa a versão de CSTK_FALSO_VERSAO (padrão: o piso) e registra
# os argumentos de `hooks install` em $TMP/cstk.log.
BIN="$TMP/bin"
mkdir -p "$BIN"
cat >"$BIN/cstk" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo "cstk v${CSTK_FALSO_VERSAO:-0.0.0}" ;;
  hooks) shift; echo "hooks $*" >>"$CSTK_LOG_FALSO" ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$BIN/cstk"
export CSTK_LOG_FALSO="$TMP/cstk.log"
PISO="$(grep -E '^CSTK_MIN=' "$RAIZ_COCKPIT/versoes.env" | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
export CSTK_FALSO_VERSAO="$PISO"

# PATH sem qualquer cstk (o do usuário inclusive).
PATH_SEM_CSTK=""
IFS=: read -ra _dirs <<<"$PATH"
for d in "${_dirs[@]}"; do
  [ -x "$d/cstk" ] || PATH_SEM_CSTK="${PATH_SEM_CSTK:+$PATH_SEM_CSTK:}$d"
done
PATH_COM_FALSO="$BIN:$PATH_SEM_CSTK"

novo_repo() { local r; r="$(mktemp -d "$TMP/proj.XXXXXX")"; git init -q "$r"; printf '%s' "$r"; }
# configurar CAMINHO_DO_CONFIGURAR.SH args... — roda com o cstk falso.
rodar() { local c="$1"; shift; PATH="$PATH_COM_FALSO" "$c" "$@"; }
CONF="$RAIZ_COCKPIT/configurar.sh"
EXEMPLO="$RAIZ_COCKPIT/cockpit.config.example"
# cockpit de teste com templates próprios (cenários 5 e 7).
cockpit_copia() {
  local c; c="$(mktemp -d "$TMP/cockpit.XXXXXX")"
  mkdir -p "$c/scripts"
  cp "$CONF" "$c/configurar.sh"; cp -R "$RAIZ_COCKPIT/scripts/lib" "$c/scripts/lib"
  cp "$RAIZ_COCKPIT/versoes.env" "$c/versoes.env"; cp -R "$RAIZ_COCKPIT/templates" "$c/templates"
  printf '%s' "$c"
}
codigo() { local rc=0; "$@" >"$TMP/out" 2>"$TMP/err" || rc=$?; printf '%s' "$rc"; }

# ---------------------------------------------------------------- 1 ---
cenario "1: configuração do zero, não interativa"
T="$(novo_repo)"; : >"$CSTK_LOG_FALSO"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "exit diferente de 0"
for k in PROJETO_NOME REPO_REMOTO BRANCH_INTEGRACAO BRANCH_PRODUCAO GERENCIADOR_PACOTES CMD_TYPECHECK CMD_LINT CMD_BUILD CMD_DEPLOY_INTEGRACAO CMD_DEPLOY_PRODUCAO IDENTIDADES BOARD PRINCIPIO_III; do
  grep -q "^$k=" "$T/cockpit.config" || falha "chave $k ausente do cockpit.config"
done
espera "source com set -u falhou" bash -c 'set -u; source "$1/cockpit.config"' _ "$T"
! grep -q '{{' "$T/.cockpit/LEIAME.md" || falha "LEIAME.md com placeholder"
espera "manifesto ausente" test -f "$T/.cockpit/manifesto.sha256"
grep -q "^hooks install --project-path $T\$" "$CSTK_LOG_FALSO" || falha "cstk falso não recebeu hooks install --project-path"

# ---------------------------------------------------------------- 2 ---
cenario "2: idempotência byte a byte"
cp -R "$T" "$TMP/copia"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "segunda execução falhou"
diff -r --exclude=.git "$T" "$TMP/copia" >/dev/null || falha "diferença entre execuções"

# ---------------------------------------------------------------- 3 ---
cenario "3: --atualizar"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "--atualizar saiu com $rc"
diff -r --exclude=.git "$T" "$TMP/copia" >/dev/null || falha "--atualizar alterou arquivos"
T2="$(novo_repo)"
rc="$(codigo rodar "$CONF" --projeto "$T2" --atualizar </dev/null)"
[ "$rc" = 1 ] || falha "--atualizar sem config saiu com $rc (esperado 1)"
grep -q 'sem --atualizar' "$TMP/err" || falha "mensagem não cita rodar sem --atualizar"
rc="$(codigo rodar "$CONF" --projeto "$T2" </dev/null)"
[ "$rc" = 1 ] || falha "sem terminal e sem --respostas saiu com $rc (esperado 1)"

# ---------------------------------------------------------------- 4 ---
cenario "4: edição à mão preservada"
echo "editado à mão" >>"$T/.cockpit/LEIAME.md"
cp "$T/.cockpit/LEIAME.md" "$TMP/editado"
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='outro-nome'/" "$EXEMPLO" >"$TMP/resp4"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp4")"
[ "$rc" = 2 ] || falha "conflito saiu com $rc (esperado 2)"
cmp -s "$T/.cockpit/LEIAME.md" "$TMP/editado" || falha "arquivo editado foi alterado"
grep -q -- '--forcar' "$TMP/err" || falha "aviso não cita --forcar"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp4" --forcar)"
[ "$rc" = 0 ] || falha "--forcar saiu com $rc"
grep -q 'outro-nome' "$T/.cockpit/LEIAME.md" || falha "--forcar não re-renderizou"
grep -q "  .cockpit/LEIAME.md\$" "$T/.cockpit/manifesto.sha256" || falha "manifesto sem o arquivo"
h="$(sha256sum <"$T/.cockpit/LEIAME.md")"; h="${h%% *}"
grep -q "^$h  " "$T/.cockpit/manifesto.sha256" || falha "manifesto não foi atualizado"

# ---------------------------------------------------------------- 5 ---
cenario "5: placeholder residual"
C="$(cockpit_copia)"; printf 'valor: {{CHAVE_INEXISTENTE}}\n' >"$C/templates/x.md.tmpl"
T="$(novo_repo)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 2 ] || falha "residual saiu com $rc (esperado 2)"
grep -q 'x.md.tmpl' "$TMP/err" && grep -q '{{CHAVE_INEXISTENTE}}' "$TMP/err" || falha "stderr não cita template e placeholder"
[ ! -e "$T/x.md" ] || falha "x.md foi criado"
[ ! -e "$T/.cockpit/LEIAME.md" ] || falha "algum template foi movido"
[ -z "$(find "$T" -path "$T/.git" -prune -o -name '.cockpit-tmp.*' -print)" ] || falha "temporário restante"

# ---------------------------------------------------------------- 6 ---
cenario "6: caracteres especiais"
T="$(novo_repo)"
ESPECIAL='a/b & "c" $HOME \n'"'"'x'
{ grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='a/b & \"c\" \$HOME \\\\n'\\\\''x'\n"; } >"$TMP/resp6"
rodar "$CONF" --projeto "$T" --respostas "$TMP/resp6" >/dev/null 2>&1 || falha "exit diferente de 0"
grep -qF "| Build | \`$ESPECIAL\` |" "$T/.cockpit/LEIAME.md" || falha "valor não está literal no LEIAME.md"
[ "$(bash -c 'source "$1/cockpit.config"; printf %s "$CMD_BUILD"' _ "$T")" = "$ESPECIAL" ] || falha "source devolve outro valor"

# ---------------------------------------------------------------- 7 ---
cenario "7: template novo sem mudar o script"
C="$(cockpit_copia)"; mkdir -p "$C/templates/novo"; printf '{{PROJETO_NOME}}\n' >"$C/templates/novo/y.txt.tmpl"
T="$(novo_repo)"
rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "exit diferente de 0"
[ "$(cat "$T/novo/y.txt")" = "meu-projeto" ] || falha "novo/y.txt não renderizado"
cmp -s "$C/configurar.sh" "$CONF" || falha "configurar.sh mudou"

# ---------------------------------------------------------------- 8 ---
cenario "8: contenção de caminho"
T="$(novo_repo)"; FORA="$(mktemp -d "$TMP/fora.XXXXXX")"; ln -s "$FORA" "$T/.cockpit"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "link simbólico saiu com $rc (esperado 1)"
[ -z "$(ls -A "$FORA")" ] || falha "algo foi escrito fora do projeto"
[ ! -e "$T/cockpit.config" ] || falha "config gravado apesar do erro de contenção"
NAO_GIT="$(mktemp -d "$TMP/nogit.XXXXXX")"
rc="$(codigo rodar "$CONF" --projeto "$NAO_GIT" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "diretório sem git saiu com $rc (esperado 1)"
T="$(novo_repo)"; mkdir "$T/sub"
rc="$(codigo rodar "$CONF" --projeto "$T/sub" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "subdiretório de repo saiu com $rc (esperado 1)"
T="$(novo_repo)"; ln -s "$FORA/alvo" "$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && [ ! -e "$FORA/alvo" ] || falha "cockpit.config link simbólico não foi recusado"

# ---------------------------------------------------------------- 9 ---
cenario "9: validação de respostas"
T="$(novo_repo)"
sed "s#^REPO_REMOTO=.*#REPO_REMOTO='semBarra'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q REPO_REMOTO "$TMP/err" && [ ! -e "$T/cockpit.config" ] || falha "REPO_REMOTO inválido não recusado"
grep -v '^CMD_LINT=' "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q CMD_LINT "$TMP/err" || falha "CMD_LINT ausente não recusado"
sed "s#^BRANCH_PRODUCAO=.*#BRANCH_PRODUCAO='staging'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] && [ ! -s "$TMP/err" ] || falha "produção igual à integração deveria passar sem aviso"
sed "s#^IDENTIDADES=.*#IDENTIDADES=''#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q IDENTIDADES "$TMP/err" || falha "IDENTIDADES vazia não recusada"
sed "s#^IDENTIDADES=.*#IDENTIDADES='Fulana:fulana@exemplo.example'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] && grep -q 'noreply' "$TMP/err" || falha "e-mail não noreply deveria passar com aviso"
sed "s#^CMD_BUILD=.*#CMD_BUILD='a'\$'\\\\t''b'#;s#^BOARD=.*#BOARD='x'#" "$EXEMPLO" >"$TMP/r"
printf "CMD_LINT='com\tcontrole'\n" | sed "s/\\\\t/$(printf '\t')/" >>"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q 'controle' "$TMP/err" || falha "caractere de controle não recusado"

# --------------------------------------------------------------- 10 ---
cenario "10: cstk ausente ou abaixo do piso"
T="$(novo_repo)"
rc="$(PATH="$PATH_SEM_CSTK" codigo "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "cstk ausente saiu com $rc (esperado 3)"
[ -f "$T/cockpit.config" ] && [ -f "$T/.cockpit/LEIAME.md" ] || falha "config/templates não mantidos"
grep -q '^Execute:' "$TMP/out" || falha "stdout sem Execute:"
T="$(novo_repo)"
rc="$(CSTK_FALSO_VERSAO=0.0.1 codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "cstk abaixo do piso saiu com $rc (esperado 3)"
grep -q '^Execute:' "$TMP/out" || falha "stdout sem Execute: (abaixo do piso)"

# --------------------------------------------------------------- 11 ---
cenario "11: qualidade estática"
if command -v shellcheck >/dev/null 2>&1; then
  (cd "$RAIZ_COCKPIT" && shellcheck -x configurar.sh scripts/lib/versao.sh scripts/testar-configurar.sh instalar.sh) \
    || falha "shellcheck com findings"
else
  printf '  (shellcheck ausente nesta máquina — checado no CI)\n'
fi
(cd "$RAIZ_COCKPIT" && ./scripts/verificar-agnostico.sh >/dev/null) || falha "verificar-agnostico.sh com ocorrências"

printf 'OK: todos os cenários passaram.\n'
