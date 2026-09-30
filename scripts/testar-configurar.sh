#!/usr/bin/env bash
# scripts/testar-configurar.sh — cenários de docs/specs/configurar/quickstart.md.
#
# Cada cenário roda num repositório git temporário; o `cstk` é sempre o falso
# deste script (nunca o real). Sai diferente de zero na primeira falha, dizendo
# qual cenário falhou. Sem framework, sem rede.
# shellcheck disable=SC2015,SC2016 # `A && B || falha` é o idioma dos cenários
# (falha() sai); textos em aspas simples são literais de propósito
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
  --version)
    [ -z "${CSTK_FALSO_STDERR:-}" ] || echo "$CSTK_FALSO_STDERR" >&2
    if [ -n "${CSTK_FALSO_SAIDA:-}" ]; then printf '%b' "$CSTK_FALSO_SAIDA"; else echo "cstk ${CSTK_FALSO_PREFIXO-v}${CSTK_FALSO_VERSAO:-0.0.0}"; fi ;;
  --versao-bruta) : ;;
  hooks)
    shift; echo "hooks $*" >>"$CSTK_LOG_FALSO"
    [ -z "${CSTK_FALSO_FALHA:-}" ] || { echo "falha simulada" >&2; exit 7; } ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$BIN/cstk"
export CSTK_LOG_FALSO="$TMP/cstk.log"
# Piso lido pela mesma função do configurar.sh (tolera export, aspas, CRLF).
REPO_ROOT="$RAIZ_COCKPIT"
# shellcheck source=scripts/lib/versao.sh
. "$RAIZ_COCKPIT/scripts/lib/versao.sh"
PISO="$(ler_cstk_min)"
[ -n "$PISO" ] || { echo "FALHOU: CSTK_MIN não encontrado em versoes.env" >&2; exit 1; }
export CSTK_FALSO_VERSAO="$PISO"

sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum <"$1"; else shasum -a 256 <"$1"; fi; }

# PATH sem qualquer cstk (o do usuário inclusive). Um diretório com cstk real é
# trocado por uma cópia de links para tudo, menos o cstk — git, awk e demais
# ferramentas que moram junto continuam no PATH.
PATH_SEM_CSTK=""
IFS=: read -ra _dirs <<<"$PATH"
_n=0
for d in "${_dirs[@]}"; do
  [ -n "$d" ] && [ -d "$d" ] || continue
  if [ -e "$d/cstk" ]; then
    _n=$((_n + 1)); _sombra="$TMP/sem-cstk.$_n"; mkdir -p "$_sombra"
    for f in "$d"/*; do
      [ "$(basename "$f")" = cstk ] || ln -s "$f" "$_sombra/" 2>/dev/null || true
    done
    d="$_sombra"
  fi
  PATH_SEM_CSTK="${PATH_SEM_CSTK:+$PATH_SEM_CSTK:}$d"
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
h="$(sha "$T/.cockpit/LEIAME.md")"; h="${h%% *}"
grep -q "^$h  " "$T/.cockpit/manifesto.sha256" || falha "manifesto não foi atualizado"
# Arquivo gerado e não editado é regravado sem --forcar quando o config muda.
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='terceiro-nome'/" "$EXEMPLO" >"$TMP/resp4b"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp4b")"
[ "$rc" = 0 ] || falha "arquivo não editado deveria ser regravado sem --forcar (saiu $rc)"
grep -q 'terceiro-nome' "$T/.cockpit/LEIAME.md" || falha "arquivo não editado não foi re-renderizado"

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
# URL opcional vazia = ausente: mesmo resultado na 1ª execução e no --atualizar.
C="$(cockpit_copia)"; printf 'url: {{URL_AMBIENTE_INTEGRACAO}}\n' >"$C/templates/u.md.tmpl"
T="$(novo_repo)"
{ grep -v '^URL_AMBIENTE_' "$EXEMPLO"; echo "URL_AMBIENTE_INTEGRACAO=''"; } >"$TMP/resp-url"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$TMP/resp-url")"
[ "$rc" = 2 ] || falha "URL vazia na 1ª execução saiu com $rc (esperado 2, residual)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --atualizar)"
[ "$rc" = 2 ] || falha "URL vazia no --atualizar saiu com $rc (esperado 2, residual)"

# ---------------------------------------------------------------- 6 ---
cenario "6: caracteres especiais"
T="$(novo_repo)"
ESPECIAL='a/b & "c" $HOME \n'"'"'x'
{ grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='a/b & \"c\" \$HOME \\\\n'\\\\''x'\n"; } >"$TMP/resp6"
rodar "$CONF" --projeto "$T" --respostas "$TMP/resp6" >/dev/null 2>&1 || falha "exit diferente de 0"
grep -qF "Build:                  $ESPECIAL" "$T/.cockpit/LEIAME.md" || falha "valor não está literal no LEIAME.md"
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
# Controle real (TAB, ESC), C1 e marca bidi: cada um recusado citando a chave.
for bruto in $'a\tb' $'a\e[31mb' $'a\xc2\x9bb' $'a\xe2\x80\xaeb' $'a\xe2\x80\x8eb' $'a\xe2\x80\xa8b' $'a\xd8\x9cb' $'a\xffb' $'a\xc3'; do
  { grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='%s'\n" "$bruto"; } >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q 'CMD_BUILD' "$TMP/err" && grep -q 'controle' "$TMP/err" \
    || falha "valor com controle $(printf %q "$bruto") não recusado citando CMD_BUILD"
done
# Acentos, € e emoji são legítimos.
{ grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='echo ação € 😀 中文'\n"; } >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] || falha "valor com acentos e emoji recusado"
for repo in "../x" "org/.." "-x/y" "org/-y"; do
  sed "s#^REPO_REMOTO=.*#REPO_REMOTO='$repo'#" "$EXEMPLO" >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q REPO_REMOTO "$TMP/err" || falha "REPO_REMOTO '$repo' não recusado"
done
sed "s#^BOARD=.*#BOARD='   '#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q BOARD "$TMP/err" || falha "BOARD só com espaços não recusado"
for b in 'x y' 'org/0' 'org/007' 'org'; do
  sed "s#^BOARD=.*#BOARD='$b'#" "$EXEMPLO" >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q BOARD "$TMP/err" || falha "BOARD '$b' não recusado"
done
sed "s#^BOARD=.*#BOARD='org-exemplo/7'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] || falha "BOARD org-exemplo/7 recusado"
for d in '' '@org-exemplo/time' 'maria' '@maria_x'; do
  sed "s#^DONOS_CODEOWNERS=.*#DONOS_CODEOWNERS='$d'#" "$EXEMPLO" >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q DONOS_CODEOWNERS "$TMP/err" || falha "DONOS_CODEOWNERS '$d' não recusado"
done
sed "s#^DONOS_CODEOWNERS=.*#DONOS_CODEOWNERS='@org-exemplo/time'#" "$EXEMPLO" >"$TMP/r"
codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r" >/dev/null
grep -q 'times' "$TMP/err" || falha "recusa de @org/time não cita times"
grep -v '^DONOS_CODEOWNERS=' "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q 'DONOS_CODEOWNERS' "$TMP/err" || falha "DONOS_CODEOWNERS ausente deveria falhar"
T9="$(novo_repo)"
rodar "$CONF" --projeto "$T9" --respostas "$EXEMPLO" >/dev/null 2>&1
grep -v '^DONOS_CODEOWNERS=' "$T9/cockpit.config" >"$TMP/c9"; cp "$TMP/c9" "$T9/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T9" --atualizar)"
[ "$rc" = 1 ] && grep -q 'DONOS_CODEOWNERS' "$TMP/err" || falha "--atualizar com config sem DONOS_CODEOWNERS deveria falhar"
grep -v '^PRINCIPIO_III=' "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q 'PRINCIPIO_III' "$TMP/err" || falha "PRINCIPIO_III ausente deveria falhar (FR-016)"
sed "s#^IDENTIDADES=.*#IDENTIDADES=' A:1+a@users.noreply.github.com ; B:2+b@users.noreply.github.com '#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] && grep -q "^IDENTIDADES='A:1+a@users.noreply.github.com;B:2+b@users.noreply.github.com'\$" "$T/cockpit.config" \
  || falha "IDENTIDADES com espaços em volta do ; não foi aceita e normalizada"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" --atualizar)"
[ "$rc" = 1 ] || falha "--atualizar com --respostas saiu com $rc (esperado 1)"

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
# Aviso com número de versão em stderr não burla o piso.
T="$(novo_repo)"
rc="$(CSTK_FALSO_VERSAO=0.0.1 CSTK_FALSO_STDERR="aviso: node 999.9.9 obsoleto" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "versão em stderr burlou o piso (saiu $rc)"
# Pré-release do próprio piso fica abaixo dele.
rc="$(CSTK_FALSO_VERSAO="$PISO-rc1" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "pré-release do piso aceito (saiu $rc)"
# Versão só com major, acima do piso, é reconhecida.
rc="$(CSTK_FALSO_VERSAO="$(( ${PISO%%.*} + 1 ))" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] || falha "versão só com major não reconhecida (saiu $rc)"
# Formatos de saída reais: CRLF, +build, parênteses, ponto final, número espúrio.
T="$(novo_repo)"
for saida in "cstk $PISO\\r\\n" "cstk $PISO+build5\\n" "cstk (v$PISO)\\n" "cstk v$PISO.\\n" "cstk: 3 plugins carregados\\ncstk v$PISO\\n" "aviso: nova versão 99.0.0 disponível\\ncstk v$PISO\\n"; do
  rc="$(CSTK_FALSO_SAIDA="$saida" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
  [ "$rc" = 0 ] || falha "saída de versão '$saida' não reconhecida (saiu $rc)"
done
rc="$(CSTK_FALSO_SAIDA="aviso: nova versão 99.0.0 disponível\\ncstk v0.0.1\\n" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "versão de outra linha burlou o piso (saiu $rc)"
# hooks install falhando: exit 4, config e templates mantidos.
T="$(novo_repo)"
rc="$(CSTK_FALSO_FALHA=1 codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 4 ] && [ -f "$T/cockpit.config" ] && [ -f "$T/.cockpit/LEIAME.md" ] || falha "hooks install falhando saiu com $rc (esperado 4)"

# --------------------------------------------------------------- 12 ---
cenario "12: leitura do cockpit.config"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "configuração inicial falhou"
cp "$T/.cockpit/LEIAME.md" "$TMP/leiame12"
# Espaço/comentário depois das aspas, export e BOM: lidos como `source` leria.
{ printf '\xef\xbb\xbf# config\n'; sed -e "s/^CMD_LINT=\(.*\)\$/export CMD_LINT=\1   # lint/" -e "s/^CMD_BUILD=\(.*\)\$/CMD_BUILD=\1 /" "$T/cockpit.config"; } >"$TMP/c12"
cp "$TMP/c12" "$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar)"
[ "$rc" = 0 ] || falha "config com BOM/export/comentário saiu com $rc"
cmp -s "$T/.cockpit/LEIAME.md" "$TMP/leiame12" || falha "valores lidos com aspas ou comentário no valor"
printf "CMD_BUILD='a' b\n" >>"$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar)"
[ "$rc" = 1 ] && grep -q 'CMD_BUILD' "$TMP/err" || falha "aspas malformadas não recusadas"
# Formas lidas por `source` de outro jeito: recusadas citando a chave.
for linha in "CMD_BUILD='a'#c" 'CMD_BUILD="b"#d' 'CMD_BUILD=$HOME/x' "CMD_BUILD=a'b" 'CMD_BUILD="x$y"'; do
  { grep -v '^CMD_BUILD=' "$EXEMPLO"; printf '%s\n' "$linha"; } >"$TMP/r12"
  rc="$(codigo rodar "$CONF" --projeto "$(novo_repo)" --respostas "$TMP/r12")"
  [ "$rc" = 1 ] && grep -q CMD_BUILD "$TMP/err" || falha "forma '$linha' não recusada"
done
# Aceitas: aspa dentro do comentário e forma legada sem aspas (exemplo antigo).
for linha in "CMD_BUILD='a' # it's" 'CMD_BUILD=npm run build'; do
  { grep -v '^CMD_BUILD=' "$EXEMPLO"; printf '%s\n' "$linha"; } >"$TMP/r12"
  rc="$(codigo rodar "$CONF" --projeto "$(novo_repo)" --respostas "$TMP/r12")"
  [ "$rc" = 0 ] || falha "forma '$linha' deveria ser aceita (saiu $rc)"
done
# Chave desconhecida é mantida na regravação.
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "configuração inicial falhou"
printf "CMD_TESTE='npm test'\n" >>"$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q "^CMD_TESTE='npm test'\$" "$T/cockpit.config" && grep -q 'mantida' "$TMP/err" \
  || falha "chave desconhecida não foi mantida no cockpit.config"
# --respostas com config antigo malformado: linha avisada e ignorada, sem abortar;
# chave desconhecida com valor fora do formato não é copiada; export mantido.
printf 'lixo sem igual\nFOO=\x27sem fim\nexport QUX=1\n' >>"$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q 'não será mantida' "$TMP/err" || falha "config antigo malformado abortou o --respostas (saiu $rc)"
! grep -q '^FOO=' "$T/cockpit.config" && grep -q '^export QUX=1$' "$T/cockpit.config" || falha "extras malformados copiados ou export perdido"
espera "cockpit.config com extras não carrega com source" bash -c 'set -u; source "$1/cockpit.config"' _ "$T"
cp "$T/cockpit.config" "$TMP/c12b"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "segunda regravação falhou"
cmp -s "$T/cockpit.config" "$TMP/c12b" || falha "regravação com chave mantida não é idempotente"

# --------------------------------------------------------------- 13 ---
cenario "13: templates e falhas de escrita"
C="$(cockpit_copia)"
printf '#!/bin/sh\necho {{PROJETO_NOME}}\n' >"$C/templates/exec.sh.tmpl"; chmod +x "$C/templates/exec.sh.tmpl"
printf 'sem newline {{PROJETO_NOME}}' >"$C/templates/semnl.txt.tmpl"
T="$(novo_repo)"
rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render falhou"
[ -x "$T/exec.sh" ] || falha "template executável perdeu o bit de execução"
[ "$(tail -c 1 "$T/semnl.txt")" = o ] || falha "newline final acrescentado ao template sem newline"
# Conteúdo igual, modo diferente: o bit de execução volta a seguir o template.
chmod a-x "$T/exec.sh"
rodar "$C/configurar.sh" --projeto "$T" --atualizar >/dev/null 2>&1 || falha "--atualizar falhou"
[ -x "$T/exec.sh" ] || falha "bit de execução não sincronizado com o template"
# Com o cockpit num repositório git, o modo registrado no git manda (clone sob
# /mnt no WSL mostra todo arquivo como executável).
(cd "$C" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm t) \
  || falha "não consegui versionar a cópia do cockpit"
chmod +x "$C/templates/semnl.txt.tmpl"
(cd "$C" && git update-index --chmod=-x templates/semnl.txt.tmpl)
rodar "$C/configurar.sh" --projeto "$T" --atualizar >/dev/null 2>&1 || falha "--atualizar falhou"
[ ! -x "$T/semnl.txt" ] || falha "bit de execução do disco venceu o modo 100644 do git"
chmod a-x "$C/templates/exec.sh.tmpl"
(cd "$C" && git update-index --chmod=+x templates/exec.sh.tmpl)
rodar "$C/configurar.sh" --projeto "$T" --atualizar >/dev/null 2>&1 || falha "--atualizar falhou"
[ -x "$T/exec.sh" ] || falha "modo 100755 do git não aplicado"
# Permissão restritiva do destino é mantida na regravação.
chmod 600 "$T/semnl.txt" "$T/cockpit.config"
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='outro'/" "$EXEMPLO" >"$TMP/r13m"
rodar "$C/configurar.sh" --projeto "$T" --respostas "$TMP/r13m" >/dev/null 2>&1 || falha "regravação falhou"
[ "$(stat -c %a "$T/semnl.txt" 2>/dev/null || stat -f %Lp "$T/semnl.txt")" = 600 ] || falha "permissão 600 do template perdida"
[ "$(stat -c %a "$T/cockpit.config" 2>/dev/null || stat -f %Lp "$T/cockpit.config")" = 600 ] || falha "permissão 600 do cockpit.config perdida"
# Template removido do cockpit: aviso, arquivo e linha do manifesto mantidos.
rm "$C/templates/semnl.txt.tmpl"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --atualizar)"
[ "$rc" = 0 ] && grep -q 'semnl.txt não é mais gerado' "$TMP/err" && [ -f "$T/semnl.txt" ] \
  && grep -q '  semnl.txt$' "$T/.cockpit/manifesto.sha256" || falha "órfão não foi avisado e mantido"
# Destinos duplicados ou dentro de .git: recusados.
C="$(cockpit_copia)"; printf 'a\n' >"$C/templates/d.md"; printf 'b\n' >"$C/templates/d.md.tmpl"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$(novo_repo)" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && grep -q 'mesmo destino' "$TMP/err" || falha "destino duplicado não recusado"
for g in .git/hooks/pre-commit .GIT/hooks/pre-commit sub/.git/config Cockpit.config.tmpl; do
  C="$(cockpit_copia)"; mkdir -p "$(dirname "$C/templates/$g")"; printf 'x\n' >"$C/templates/$g"
  rc="$(codigo rodar "$C/configurar.sh" --projeto "$(novo_repo)" --respostas "$EXEMPLO")"
  [ "$rc" = 1 ] && grep -q 'reservado' "$TMP/err" || falha "destino reservado $g não recusado"
done
C="$(cockpit_copia)"; printf 'a\n' >"$C/templates/D.md"; printf 'b\n' >"$C/templates/d.md"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$(novo_repo)" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && grep -q 'mesmo destino' "$TMP/err" || falha "destinos que só diferem em maiúsculas não recusados"
# Destino que existe e não é arquivo regular (FIFO): recusado sem travar.
if command -v mkfifo >/dev/null 2>&1; then
  T="$(novo_repo)"; mkdir -p "$T/.cockpit"; mkfifo "$T/.cockpit/LEIAME.md"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" </dev/null)"
  [ "$rc" = 1 ] && grep -q 'não é arquivo regular' "$TMP/err" || falha "destino FIFO não recusado (saiu $rc)"
fi
# Falha de escrita não passa em silêncio: sai != 0 e não anuncia gravação.
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "configuração inicial falhou"
if [ "$(id -u)" != 0 ]; then
  sed "s/^PROJETO_NOME=.*/PROJETO_NOME='mudou'/" "$EXEMPLO" >"$TMP/r13"
  chmod 555 "$T/.cockpit"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r13")"
  chmod 755 "$T/.cockpit"
  [ "$rc" != 0 ] && ! grep -q 'Guard hooks provisionados' "$TMP/out" && ! grep -q 'gravado: ' "$TMP/out" \
    && grep -q 'Falha' "$TMP/err" || falha "falha de escrita saiu com $rc ou anunciou gravação"
fi
# Barra invertida no caminho do projeto não desliga a detecção de residual.
C="$(cockpit_copia)"; printf 'v: {{CHAVE_INEXISTENTE}}\n' >"$C/templates/x.md.tmpl"
T="$TMP/proj\\tbarra"; mkdir -p "$T"; git init -q "$T"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 2 ] && [ ! -e "$T/x.md" ] || falha "residual com barra invertida no caminho saiu com $rc (esperado 2)"
# Sem templates: nada a renderizar, sem manifesto vazio.
C="$(cockpit_copia)"; rm -rf "$C/templates"; mkdir "$C/templates"
T="$(novo_repo)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q 'nada havia a renderizar' "$TMP/out" && [ ! -e "$T/.cockpit/manifesto.sha256" ] \
  || falha "sem templates: mensagem ou manifesto errados"
# Na raiz do próprio cockpit, sem --projeto: recusado.
C="$(cockpit_copia)"; git init -q "$C"
rc="$(cd "$C" && PATH="$PATH_COM_FALSO" codigo ./configurar.sh --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && grep -q -- '--projeto' "$TMP/err" && [ ! -e "$C/cockpit.config" ] || falha "raiz do cockpit sem --projeto não recusada"

# --------------------------------------------------------------- 14 ---
cenario "14: modo interativo (pty)"
if command -v script >/dev/null 2>&1 && script -qec true /dev/null >/dev/null 2>&1; then
  # interativo ENTRADA ARGS... — roda o configurar num pty com a entrada dada.
  interativo() {
    local entrada="$1"; shift
    printf '%b' "$entrada" | PATH="$PATH_COM_FALSO" script -qec "$(printf '%q ' "$CONF" "$@")" /dev/null >"$TMP/tty" 2>&1
  }
  T="$(novo_repo)"
  # 12 chaves, depois nome/e-mail de duas identidades, nome vazio encerra,
  # board e Enter no Princípio III (sugere ligado).
  interativo 'proj\norg/repo\ndev\nmain\nnpm\nnpm run tc\nnpm run lint\nnpm run build\nnpm run d:i\nnpm run d:p\n-\n-\nAna Silva\n1+ana@users.noreply.github.com\nBeto\n2+beto@users.noreply.github.com\n\n@ana-exemplo\norg-exemplo/9\n\n' --projeto "$T" \
    || falha "configuração interativa falhou: $(tail -3 "$TMP/tty")"
  grep -q "^IDENTIDADES='Ana Silva:1+ana@users.noreply.github.com;Beto:2+beto@users.noreply.github.com'\$" "$T/cockpit.config" \
    || falha "nome e e-mail separados não gravados como nome:email"
  grep -q "^PRINCIPIO_III='ligado'\$" "$T/cockpit.config" || falha "Enter no Princípio III não aceitou o sugerido"
  # SC-001: configuração mínima (uma identidade) com exatamente 18 respostas (17 + DONOS_CODEOWNERS).
  MINIMO='proj\norg/repo\ndev\nmain\nnpm\nnpm run tc\nnpm run lint\nnpm run build\nnpm run d:i\nnpm run d:p\n-\n-\nAna\n1+ana@users.noreply.github.com\n\n@ana-exemplo\n-\n\n'
  [ "$(printf '%b' "$MINIMO" | wc -l | tr -d ' ')" = 18 ] || falha "entrada mínima não tem 18 respostas"
  T3="$(novo_repo)"
  interativo "$MINIMO" --projeto "$T3" || falha "configuração mínima com 18 respostas falhou: $(tail -3 "$TMP/tty")"
  [ -f "$T3/cockpit.config" ] && [ -f "$T3/.cockpit/LEIAME.md" ] || falha "configuração mínima não gravou config e templates"
  T3="$(novo_repo)"
  ! interativo "$(printf '%b' "$MINIMO" | head -17 | sed 's/$/\\n/' | tr -d '\n')" --projeto "$T3" \
    || falha "configuração concluiu com 17 respostas; SC-001 fixa 18"
  # Config incompleto: só a chave ausente é perguntada.
  grep -v '^BOARD=' "$T/cockpit.config" >"$TMP/c14"; cp "$TMP/c14" "$T/cockpit.config"
  interativo 'org-exemplo/3\n-\n-\n' --projeto "$T" || falha "interativo com config incompleto falhou: $(tail -3 "$TMP/tty")"
  grep -q 'ausente(s) no cockpit.config: BOARD' "$TMP/tty" || falha "chave ausente não foi reportada"
  ! grep -q 'Nome do projeto' "$TMP/tty" || falha "config incompleto perguntou chave já definida"
  grep -q "^BOARD='org-exemplo/3'\$" "$T/cockpit.config" || falha "chave ausente não foi gravada"
  # Nome com ':' é recusado e perguntado de novo; vazio depois mantém as atuais.
  interativo '\n\n\n\n\n\n\n\n\n\n\n\nA:B\n\n\n\n\n' --projeto "$T" || falha "reentrada de identidade falhou: $(tail -3 "$TMP/tty")"
  grep -q "não pode conter ':'" "$TMP/tty" || falha "nome com ':' não recusado"
  grep -q "^IDENTIDADES='Ana Silva:" "$T/cockpit.config" || falha "identidades atuais não mantidas"
else
  printf '  (script(1) ausente — cenário interativo pulado)\n'
fi

# --------------------------------------------------------------- 15 ---
cenario "15: templates de governança reais"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render com cockpit.config.example falhou"
for f in docs/constitution.md CLAUDE.md docs/rito-dev.md docs/CICLO-GIT.md docs/project-context.md \
  docs/agentes/guardiao.md docs/agentes/implementador.md docs/agentes/revisor.md docs/agentes/triador.md; do
  [ -f "$T/$f" ] || falha "arquivo gerado ausente: $f"
  ! grep -q '{{' "$T/$f" || falha "placeholder residual em $f"
  ! grep -q 'URL_AMBIENTE' "$T/$f" || falha "chave opcional URL_AMBIENTE_* em $f"
done
# Nenhum template real usa chave opcional (a ausência delas não pode deixar resíduo).
[ -d "$RAIZ_COCKPIT/templates" ] || falha "diretório templates/ ausente"
! grep -rq 'URL_AMBIENTE' "$RAIZ_COCKPIT/templates" || falha "template usa chave opcional URL_AMBIENTE_*"
# Princípios na ordem, seção de princípios próprios e o que o pre-flight do /feature-00c exige.
ordem="$(grep -oE '^### [IVX]+(-bis)?\. ' "$T/docs/constitution.md" | tr -d '#. ' | tr '\n' ' ')"
[ "$ordem" = "II II-bis III IV IV-bis V VI VII VIII " ] || falha "princípios fora de ordem: $ordem"
grep -q '^## Core Principles$' "$T/docs/constitution.md" || falha "constituição sem ## Core Principles"
grep -q '^## Princípios próprios do projeto$' "$T/docs/constitution.md" || falha "seção de princípios próprios ausente"
grep -qE '^\*\*Version\*\*: [0-9]+\.[0-9]+\.[0-9]+' "$T/docs/constitution.md" || falha "constituição sem rodapé **Version**"
for n in 1 2 3 4 5 6 7 8 9 10 11; do
  grep -q "^## Fase $n — " "$T/docs/rito-dev.md" || falha "Fase $n ausente do rito"
done
for a in guardiao implementador revisor triador; do
  for s in Responsabilidade Entradas Saídas Limites; do
    grep -q "^## $s\$" "$T/docs/agentes/$a.md" || falha "seção $s ausente em agentes/$a.md"
  done
done
# Idempotência (FR-014): segunda execução não altera nenhum arquivo gerado.
cp -R "$T" "$TMP/copia15"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "segunda execução falhou"
diff -r --exclude=.git "$T" "$TMP/copia15" >/dev/null || falha "segunda execução alterou arquivos gerados"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "--atualizar saiu com $rc"
diff -r --exclude=.git "$T" "$TMP/copia15" >/dev/null || falha "--atualizar alterou arquivos gerados"
# Variação: Princípio III desligado e integração igual a produção (branch única).
T="$(novo_repo)"
sed -e "s/^PRINCIPIO_III=.*/PRINCIPIO_III='desligado'/" \
  -e "s/^BRANCH_PRODUCAO=.*/$(grep '^BRANCH_INTEGRACAO=' "$EXEMPLO" | sed 's/INTEGRACAO/PRODUCAO/')/" \
  "$EXEMPLO" >"$TMP/variacao15.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/variacao15.config")"
[ "$rc" = 0 ] || falha "render da variação saiu com $rc: $(cat "$TMP/err")"
grep -q 'Valor configurado neste projeto: \*\*desligado\*\*' "$T/docs/constitution.md" || falha "Princípio III não mostra desligado"
grep -q 'esta fase é \*\*no-op\*\*' "$T/docs/rito-dev.md" || falha "rito sem o no-op da promoção"
! grep -rq '{{' "$T/docs" "$T/CLAUDE.md" || falha "placeholder residual na variação"

# --------------------------------------------------------------- 16 ---
cenario "16: templates de automação (fluxos, CODEOWNERS, releaserc, task.sh)"
AUTOMACAO=".github/workflows/ci.yml .github/workflows/commitlint.yml .github/workflows/require-codeowner-approval.yml .github/workflows/promotion-pr.yml .github/workflows/audit-merge-vermelho.yml .github/workflows/release.yml .github/CODEOWNERS .releaserc.json .claude/scripts/task.sh"
# CMD_LINT com caracteres especiais (quickstart Cenário 4) e BOARD preenchido (Cenário 6).
LINT_ESPECIAL='npm run lint -- --fix | tee "$X" && echo `ok`'
grep -v -e '^CMD_LINT=' -e '^BOARD=' "$EXEMPLO" >"$TMP/auto.config"
printf "CMD_LINT='%s'\nBOARD='org-exemplo/7'\n" "$LINT_ESPECIAL" >>"$TMP/auto.config"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$TMP/auto.config" >/dev/null 2>&1 || falha "render da automação falhou"
n=0
for f in $AUTOMACAO; do
  [ -f "$T/$f" ] || falha "arquivo de automação ausente: $f"
  n=$((n + 1))
  ! grep -qE '\{\{[A-Z][A-Z0-9_]*\}\}' "$T/$f" || falha "placeholder residual em $f"
  # FR-017: cada expressão ${{ ... }} do template atravessa a renderização intacta.
  [ -f "$RAIZ_COCKPIT/templates/$f.tmpl" ] || falha "template ausente: $f.tmpl"
  [ "$(grep -o '\${{[^}]*}}' "$RAIZ_COCKPIT/templates/$f.tmpl" | sort)" = "$(grep -o '\${{[^}]*}}' "$T/$f" | sort)" ] \
    || falha "expressão \${{ }} alterada em $f"
done
[ "$n" = 9 ] || falha "esperados 9 arquivos de automação, contei $n"
[ -x "$T/.claude/scripts/task.sh" ] || falha "task.sh sem bit de execução"
grep -qF "          $LINT_ESPECIAL" "$T/.github/workflows/ci.yml" || falha "CMD_LINT não chegou byte a byte ao ci.yml"
grep -q '^\* @maria-exemplo @jose-exemplo$' "$T/.github/CODEOWNERS" || falha "CODEOWNERS sem os donos do exemplo"
python3 -m json.tool "$T/.releaserc.json" >/dev/null || falha ".releaserc.json inválido"
grep -q '"branches": \["main"\]' "$T/.releaserc.json" || falha ".releaserc.json sem a branch de produção"
bash -n "$T/.claude/scripts/task.sh" || falha "task.sh com erro de sintaxe"
# task.sh: BOARD vazio sai 3; BOARD preenchido sem gh sai 4 (FR-013).
sed "s#^BOARD=.*#BOARD=''#" "$EXEMPLO" >"$TMP/semboard.config"
T2="$(novo_repo)"
rodar "$CONF" --projeto "$T2" --respostas "$TMP/semboard.config" >/dev/null 2>&1 || falha "render sem board falhou"
rc="$(codigo "$T2/.claude/scripts/task.sh" list)"
[ "$rc" = 3 ] && grep -q 'não tem board' "$TMP/err" || falha "task.sh com BOARD vazio deveria sair 3 (saiu $rc)"
mkdir -p "$TMP/semgh"; for b in bash env cat; do ln -sf "$(command -v "$b")" "$TMP/semgh/$b"; done
rc="$(codigo env PATH="$TMP/semgh" "$T/.claude/scripts/task.sh" discover)"
[ "$rc" = 4 ] || falha "task.sh sem gh deveria sair 4 (saiu $rc)"
rc="$(codigo "$T/.claude/scripts/task.sh" --help)"
[ "$rc" = 0 ] || falha "task.sh --help deveria sair 0"
# promotion-pr: com integração = produção o passo sai 0 sem chamar o gh (SC-005).
T3="$(novo_repo)"
sed -e "s/^BRANCH_PRODUCAO=.*/$(grep '^BRANCH_INTEGRACAO=' "$EXEMPLO" | sed 's/INTEGRACAO/PRODUCAO/')/" "$EXEMPLO" >"$TMP/igual.config"
rodar "$CONF" --projeto "$T3" --respostas "$TMP/igual.config" >/dev/null 2>&1 || falha "render com branches iguais falhou"
awk '/^          TOKEN_PADRAO/ {d=1} d && /run: \|/ {r=1; next} r {sub(/^          /, ""); print}' \
  "$T3/.github/workflows/promotion-pr.yml" >"$TMP/promocao.sh"
[ -s "$TMP/promocao.sh" ] || falha "não extraí o passo do promotion-pr"
mkdir -p "$TMP/ghfalso"; printf '#!/bin/sh\necho chamado >"%s/gh-chamado"\nexit 99\n' "$TMP" >"$TMP/ghfalso/gh"; chmod +x "$TMP/ghfalso/gh"
rm -f "$TMP/gh-chamado"
branch_unica="$(sed -n "s/^BRANCH_INTEGRACAO='\(.*\)'\$/\1/p" "$EXEMPLO")"
rc="$(codigo env PATH="$TMP/ghfalso:$PATH" INTEGRACAO="$branch_unica" PRODUCAO="$branch_unica" bash "$TMP/promocao.sh")"
[ "$rc" = 0 ] && [ ! -f "$TMP/gh-chamado" ] || falha "promotion-pr com branches iguais deveria sair 0 sem chamar gh (saiu $rc)"
grep -q 'nada a promover' "$TMP/out" || falha "promotion-pr sem a mensagem de no-op"
# Idempotência (SC-004): segunda execução e --atualizar não alteram conteúdo nem modo.
modos() { (cd "$1" && for f in $AUTOMACAO; do printf '%s %s\n' "$(stat -c '%a' "$f")" "$(sha256sum <"$f")"; done); }
antes="$(modos "$T")"
rodar "$CONF" --projeto "$T" --respostas "$TMP/auto.config" >/dev/null 2>&1 || falha "segunda execução da automação falhou"
[ "$(modos "$T")" = "$antes" ] || falha "segunda execução alterou a automação"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] && [ "$(modos "$T")" = "$antes" ] || falha "--atualizar alterou a automação"
# Ferramentas estáticas: no CI (COCKPIT_EXIGIR_FERRAMENTAS=1) a ausência é falha.
for ferr in actionlint shellcheck; do
  command -v "$ferr" >/dev/null 2>&1 && continue
  [ "${COCKPIT_EXIGIR_FERRAMENTAS:-}" != 1 ] || falha "$ferr ausente no CI"
  printf '  (%s ausente nesta máquina — checado no CI)\n' "$ferr"
done
if command -v actionlint >/dev/null 2>&1; then
  (cd "$T" && actionlint .github/workflows/*.yml) || falha "actionlint com findings"
  (cd "$T3" && actionlint .github/workflows/*.yml) || falha "actionlint com findings (branches iguais)"
fi
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$T/.claude/scripts/task.sh" || falha "shellcheck com findings no task.sh renderizado"
fi

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
