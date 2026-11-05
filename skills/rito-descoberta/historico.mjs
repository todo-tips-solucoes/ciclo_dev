#!/usr/bin/env node
// rito-descoberta/historico.mjs — auxiliar SÓ DE LEITURA da Fase 0 e do gate da Fase 11.
//
// Uso:
//   node historico.mjs foto [--raiz <dir>]   → impressão digital das raízes (tipo\tchave\tvalor)
//   node historico.mjs pendentes <log>       → installs/enables temporários sem desfazer posterior
//   node historico.mjs gate <frente>         → gate da Fase 11 (pendentes + estado real = base, no escopo)
//   node historico.mjs frente <nome>         → valida o nome da frente (^[a-z0-9][a-z0-9-]*$, até 64)
//
// Códigos de saída: foto 0 ok / 1 falha fechado; pendentes 0 nenhum / 1 há pendentes / 2 log
// ausente, ilegível, vazio, sem evento base ou com linha mal formada; gate 0 pode encerrar / 1
// pendente ou diferença / 2 log ou base com problema; frente 0 válido / 2 inválido.
// Uso errado: 64. Contrato: seção "Formato do histórico" da SKILL.md. Nunca imprime conteúdo de
// arquivo. O git roda com --no-optional-locks: a foto não toca o índice.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, isAbsolute, join, resolve, sep } from 'node:path';

const falha = (msg, code = 1) => { process.stderr.write(`historico: ${msg}\n`); process.exit(code); };
const limpa = (s) => String(s).replace(/[\t\r\n]+/g, ' ');
const sha = (buf) => createHash('sha256').update(buf).digest('hex');
const cmp = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));
const objeto = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function git(raiz, args) {
  try {
    return execFileSync('git', ['--no-optional-locks', '-C', raiz, ...args],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  } catch { return null; }
}

// Arquivos sob `dir`, pulando `pula`. Segue symlink (diretório só uma vez por caminho real);
// symlink quebrado e diretório ilegível viram linha própria, nunca somem.
function arquivos(dir, pula) {
  const out = [];
  const vistos = new Set();
  const anda = (d) => {
    try { const real = realpathSync(d); if (vistos.has(real)) return; vistos.add(real); } catch { /* abaixo */ }
    let ents;
    try { ents = readdirSync(d, { withFileTypes: true }); } catch { out.push([d, 'ilegivel']); return; }
    for (const e of ents) {
      const p = join(d, e.name);
      if (pula.includes(p)) continue;
      let s;
      try { s = statSync(p); } catch { out.push([p, 'link-quebrado']); continue; }
      if (s.isDirectory()) anda(p);
      else out.push([p, `${s.size} ${s.mtimeMs} ${s.ctimeMs} ${s.ino}`]);
    }
  };
  anda(dir);
  return out;
}

function lerJson(p, obrigatorio) {
  if (!existsSync(p)) return undefined;
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch {
    if (obrigatorio) falha(`${p} ilegível ou JSON inválido (falha fechado)`);
    return undefined;
  }
}

const canon = (v) => JSON.stringify(v, (_, x) => (objeto(x)
  ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => cmp(a, b))) : x));

function foto(raiz, HOME) {
  for (const v of ['CLAUDE_CODE_PLUGIN_CACHE_DIR', 'CLAUDE_CONFIG_DIR']) {
    if (process.env[v]) falha(`${v} definido: a configuração fica fora das raízes da foto`);
  }
  const linhas = [];
  const add = (tipo, chave, valor) => linhas.push([tipo, limpa(chave), limpa(valor)].join('\t'));
  const claude = join(HOME, '.claude');
  const projClaude = join(raiz, '.claude');
  const sqlite = (p) => p.startsWith(projClaude + sep) && /-(shm|wal|journal)$/.test(p); // ruído

  const hooks = git(raiz, ['rev-parse', '--git-path', 'hooks']);
  const cfg = git(raiz, ['rev-parse', '--git-path', 'config']);
  const status = git(raiz, ['status', '--porcelain', '--ignored']);
  const worktrees = git(raiz, ['worktree', 'list', '--porcelain']);
  if (hooks === null || cfg === null || status === null || worktrees === null) {
    falha(`git falhou em ${raiz} (falha fechado)`);
  }

  // meta: só metadados.
  const raizesMeta = [
    [join(claude, 'skills'), [join(claude, 'skills', 'synced')]],
    [join(claude, 'agents'), []], [join(claude, 'commands'), []], [join(claude, 'hooks'), []],
    [join(claude, 'CLAUDE.md'), []], [join(claude, 'plugins', 'cache'), []],
    [projClaude, [join(projClaude, 'feature-00c-state'), join(projClaude, 'enforcement-log.jsonl')]],
    [resolve(raiz, hooks.trim()), []],
    [join(HOME, '.ssh'), []], [join(HOME, '.config', 'gh'), []], [join(HOME, '.local', 'bin'), []],
    [join(HOME, '.gitconfig'), []], [join(HOME, '.bashrc'), []], [join(HOME, '.profile'), []],
  ];
  for (const [r, pula] of raizesMeta) {
    let s;
    try { s = statSync(r); } catch { add('meta', r, existsSync(r) ? 'link-quebrado' : 'ausente'); continue; }
    const itens = s.isDirectory() ? arquivos(r, pula) : [[r, `${s.size} ${s.mtimeMs} ${s.ctimeMs} ${s.ino}`]];
    for (const [f, v] of itens) if (!sqlite(f)) add('meta', f, v);
  }

  // hash: conteúdo, só o sha256 vai à saída.
  for (const f of [join(claude, 'settings.json'), join(projClaude, 'settings.json'),
    join(projClaude, 'settings.local.json'), resolve(raiz, cfg.trim())]) {
    add('hash', f, existsSync(f) ? sha(readFileSync(f)) : 'ausente');
  }
  let cron = 'ausente';
  try { cron = sha(execFileSync('crontab', ['-l'], { stdio: ['ignore', 'pipe', 'ignore'] })); } catch { /* sem crontab */ }
  add('hash', 'crontab -l', cron);
  const cj = lerJson(join(HOME, '.claude.json'), false);
  add('hash', '~/.claude.json#mcpServers', objeto(cj) && cj.mcpServers !== undefined ? sha(canon(cj.mcpServers)) : 'ausente');
  const locais = objeto(cj) && objeto(cj.projects)
    ? Object.fromEntries(Object.entries(cj.projects).filter(([, p]) => objeto(p) && p.mcpServers !== undefined)
      .map(([k, p]) => [k, p.mcpServers])) : {};
  add('hash', '~/.claude.json#projects.mcpServers', sha(canon(locais)));

  // plugin e enabled.
  const ip = lerJson(join(claude, 'plugins', 'installed_plugins.json'), true);
  if (ip === undefined) add('plugin', '-', 'ausente');
  else {
    if (!objeto(ip)) falha('installed_plugins.json não é um objeto (falha fechado)');
    const plugins = ip.plugins === undefined ? {} : ip.plugins;
    if (!objeto(plugins)) falha('installed_plugins.json: "plugins" não é um objeto (falha fechado)');
    for (const [id, ents] of Object.entries(plugins)) {
      for (const e of [].concat(ents)) {
        if (!objeto(e)) falha(`installed_plugins.json: entrada inválida em ${limpa(id)} (falha fechado)`);
        add('plugin', `${id}|${e.scope ?? '-'}|${e.projectPath ?? '-'}`, `${e.version ?? '-'} ${e.gitCommitSha ?? '-'}`);
      }
    }
    if (ip.enabledPlugins !== undefined) add('enabled', 'installed_plugins.json', canon(ip.enabledPlugins));
  }
  for (const f of [join(claude, 'settings.json'), join(projClaude, 'settings.json'), join(projClaude, 'settings.local.json')]) {
    const s = lerJson(f, false);
    if (objeto(s) && s.enabledPlugins !== undefined) add('enabled', f, canon(s.enabledPlugins));
  }

  // marketplace e catalogo. URL ou caminho só como hash (pode trazer credencial).
  const km = lerJson(join(claude, 'plugins', 'known_marketplaces.json'), false);
  for (const [nome, m] of Object.entries(objeto(km) ? km : {})) {
    const src = objeto(m) && objeto(m.source) ? m.source : {};
    const outra = src.url ?? src.path;
    add('marketplace', nome, src.repo ?? (outra ? `sha256:${sha(String(outra))}` : '-'));
    if (objeto(m) && m.installLocation) add('catalogo', nome, (git(m.installLocation, ['rev-parse', 'HEAD']) || 'ausente').trim());
  }

  // git.
  for (const l of status.split('\n')) if (l && !sqlite(join(raiz, l.slice(3)))) add('git', 'status', l);
  for (const bloco of worktrees.split('\n\n')) {
    // Sem HEAD: commit em worktree paralela não é desvio; criar ou remover worktree é.
    const campos = bloco.split('\n').filter((c) => c && !c.startsWith('HEAD '));
    if (campos.length) add('git', 'worktree', campos.join(' '));
  }

  return linhas.sort(cmp).join('\n') + '\n';
}

const EVENTOS = new Set(['base', 'rodada', 'install', 'uninstall', 'enable', 'disable', 'desvio', 'gate0']);
const ABRE = { install: 'install', enable: 'enable' };
const FECHA = { uninstall: 'install', disable: 'enable' };

// Lê e valida o log inteiro; qualquer linha mal formada falha fechado (saída 2).
function lerLog(log) {
  let txt;
  try { txt = readFileSync(log, 'utf8'); } catch { falha(`log ausente ou ilegível: ${log}`, 2); }
  const linhas = [];
  let base = null;
  let gate0 = false;
  for (const bruta of txt.split('\n')) {
    const l = bruta.replace(/\r$/, '').normalize('NFC');
    if (!l || l.startsWith('\t')) continue; // continuação de rodada
    const c = l.split('\t');
    if (c.length < 6 || !EVENTOS.has(c[4])) falha(`linha mal formada (falha fechado): ${limpa(l)}`, 2);
    if ((ABRE[c[4]] || FECHA[c[4]]) && (c.length !== 11 || !['permanente', 'temporária'].includes(c[9]))) {
      falha(`linha de ${c[4]} mal formada (11 colunas TAB, classe permanente|temporária): ${limpa(l)}`, 2);
    }
    if (c[4] === 'base' && !base) base = c;
    if (c[4] === 'gate0') gate0 = true;
    linhas.push(c);
  }
  if (!base) falha(`log sem evento base (falha fechado): ${log}`, 2);
  return { linhas, base, gate0 };
}

// install/enable temporários ainda sem uninstall/disable com a mesma tripla id, escopo, projeto.
function abertosDe(linhas) {
  const abertos = [];
  for (const c of linhas) {
    const tipo = ABRE[c[4]] ?? FECHA[c[4]];
    if (!tipo) continue;
    const chave = `${tipo}|${c[5]}|${c[6]}|${c[7]}`;
    if (ABRE[c[4]]) { if (c[9] === 'temporária') abertos.push({ chave, l: c.join('\t') }); }
    else {
      const i = abertos.map((a) => a.chave).lastIndexOf(chave);
      if (i >= 0) abertos.splice(i, 1); // sem abertura anterior: ignorado
    }
  }
  return abertos;
}

function pendentes(log) {
  const abertos = abertosDe(lerLog(log).linhas);
  for (const a of abertos) process.stdout.write(a.l + '\n');
  process.exit(abertos.length ? 1 : 0);
}

// Gate da Fase 11: sem pendentes e, no escopo da frente, o estado real igual à linha de base.
// Escopo: ids temporários do log (plugin, enabled, cache, marketplace), e presença dos plugins com
// projectPath numa raiz da frente. Ids permanentes são diferença esperada (vão no diff da PR).
function gate(frente, HOME) {
  const dir = join(HOME, '.claude', 'cockpit');
  const { linhas, base, gate0 } = lerLog(join(dir, `historico-${frente}.log`));
  if (!gate0) falha('log sem evento gate0 (falha fechado)', 2);
  const abertos = abertosDe(linhas);
  if (abertos.length) {
    for (const a of abertos) process.stdout.write(`pendente\t${a.l}\n`);
    process.exit(1);
  }
  let baseTxt;
  try { baseTxt = readFileSync(join(dir, `historico-${frente}.base`), 'utf8'); } catch { falha('.base ausente ou ilegível (falha fechado)', 2); }
  if (!baseTxt.trim()) falha('.base vazio (falha fechado)', 2);

  const raiz = base[2];
  const perm = new Set();
  const temp = new Set();
  const raizes = new Set([raiz]);
  for (const c of linhas) {
    raizes.add(c[2]);
    if (!ABRE[c[4]] && !FECHA[c[4]]) continue;
    (c[9] === 'permanente' ? perm : temp).add(c[5]);
    if (c[7] !== '-') raizes.add(c[7]);
  }
  for (const id of perm) temp.delete(id);

  const usuario = join(HOME, '.claude', 'settings.json');
  const cache = join(HOME, '.claude', 'plugins', 'cache') + sep;
  const tipoArq = (k) => (k === 'installed_plugins.json' ? k : k === usuario ? 'usuario' : `projeto:${basename(k)}`);
  const escopo = (txt) => {
    const out = new Set();
    for (const l of txt.split('\n')) {
      const [tipo, chave = '', valor = ''] = l.split('\t');
      if (tipo === 'plugin') {
        const [id, , pp] = chave.split('|');
        if (perm.has(id)) continue;
        if (temp.has(id)) out.add(l);
        else if (raizes.has(pp)) out.add(`plugin\t${chave}`); // só presença: auto-update não conta
      } else if (tipo === 'enabled') {
        let obj;
        try { obj = JSON.parse(valor); } catch { continue; }
        if (!objeto(obj)) continue;
        for (const id of temp) if (id in obj) out.add(`enabled\t${tipoArq(chave)}\t${id}=${JSON.stringify(obj[id])}`);
      } else if (tipo === 'meta' && chave.startsWith(cache)) {
        const [mkt, plugin] = chave.slice(cache.length).split(sep);
        if (temp.has(`${plugin}@${mkt}`)) out.add(l);
      } else if (tipo === 'marketplace' && temp.has(`marketplace:${chave}`)) out.add(l);
    }
    return out;
  };

  let atual = foto(raiz, HOME);
  for (const r of raizes) { // settings das worktrees da frente, comparadas às da raiz na base
    if (r === raiz || r === '-') continue;
    for (const f of ['settings.json', 'settings.local.json']) {
      const s = lerJson(join(r, '.claude', f), false);
      if (objeto(s) && s.enabledPlugins !== undefined) atual += `enabled\t${join(r, '.claude', f)}\t${canon(s.enabledPlugins)}\n`;
    }
  }
  const esperado = escopo(baseTxt);
  const real = escopo(atual);
  const dif = [...[...esperado].filter((l) => !real.has(l)).map((l) => `- ${l}`),
    ...[...real].filter((l) => !esperado.has(l)).map((l) => `+ ${l}`)].sort(cmp);
  for (const l of dif) process.stdout.write(l + '\n');
  process.exit(dif.length ? 1 : 0);
}

const validaFrente = (f) => { if (!/^[a-z0-9][a-z0-9-]{0,63}$/.test(f)) falha(`frente inválida: ${limpa(f)}`, 2); };
const casa = () => {
  const h = homedir();
  if (!h || !isAbsolute(h)) falha('HOME vazio ou relativo (falha fechado)');
  return h;
};

const [cmd, ...args] = process.argv.slice(2);
if (cmd === 'foto') {
  const HOME = casa();
  let raiz = process.cwd();
  if (args.length) {
    if (args[0] !== '--raiz' || args.length !== 2) falha('uso: foto [--raiz <dir>]', 64);
    raiz = resolve(args[1]);
  }
  const topo = git(raiz, ['rev-parse', '--show-toplevel']);
  if (topo === null) falha(`--raiz não é repositório git (ou o git a recusou): ${raiz}`);
  process.stdout.write(foto(topo.trim(), HOME));
} else if (cmd === 'pendentes' && args.length === 1) pendentes(args[0]);
else if (cmd === 'gate' && args.length === 1) { validaFrente(args[0]); gate(args[0], casa()); }
else if (cmd === 'frente' && args.length === 1) validaFrente(args[0]);
else falha('uso: foto [--raiz <dir>] | pendentes <log> | gate <frente> | frente <nome>', 64);
