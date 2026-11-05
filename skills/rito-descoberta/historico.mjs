#!/usr/bin/env node
// rito-descoberta/historico.mjs — auxiliar SÓ DE LEITURA da Fase 0 e do gate da Fase 11.
//
// Uso:
//   node historico.mjs foto [--raiz <dir>]   → impressão digital das raízes (tipo\tchave\tvalor)
//   node historico.mjs pendentes <log>       → installs temporários sem uninstall posterior
//   node historico.mjs frente <nome>         → valida o nome da frente (^[a-z0-9][a-z0-9-]*$)
//
// Códigos de saída: foto 0 ok / 1 falha fechado; pendentes 0 nenhum / 1 há pendentes / 2 log
// ausente ou ilegível; frente 0 válido / 2 inválido. Uso errado: 64.
// Contrato: docs/specs/rito-descoberta/contracts/historico.md. Nunca imprime conteúdo de arquivo.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

const HOME = homedir();
const falha = (msg, code = 1) => { process.stderr.write(`historico: ${msg}\n`); process.exit(code); };
const limpa = (s) => String(s).replace(/[\t\r\n]+/g, ' ');
const sha = (buf) => createHash('sha256').update(buf).digest('hex');
const cmp = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));

function git(raiz, args) {
  try {
    return execFileSync('git', ['-C', raiz, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  } catch { return null; }
}

// Arquivos (não diretórios, sem seguir symlink) sob `dir`, pulando os caminhos de `pula`.
function arquivos(dir, pula = []) {
  const out = [];
  const anda = (d) => {
    let ents;
    try { ents = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of ents) {
      const p = join(d, e.name);
      if (pula.some((x) => p === x)) continue;
      if (e.isDirectory()) anda(p);
      else out.push(p);
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

const canon = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x)
  ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => cmp(a, b))) : x));

function foto(raiz) {
  if (process.env.CLAUDE_CODE_PLUGIN_CACHE_DIR) {
    falha('CLAUDE_CODE_PLUGIN_CACHE_DIR definido: o cache fica fora das raízes da foto');
  }
  const linhas = [];
  const add = (tipo, chave, valor) => linhas.push([tipo, limpa(chave), limpa(valor)].join('\t'));
  const claude = join(HOME, '.claude');

  // meta: só arquivos, só metadados.
  const hooks = git(raiz, ['rev-parse', '--git-path', 'hooks']);
  const raizesMeta = [
    [join(claude, 'skills'), [join(claude, 'skills', 'synced')]],
    [join(claude, 'agents'), []],
    [join(claude, 'plugins', 'cache'), []],
    [join(raiz, '.claude'), [join(raiz, '.claude', 'feature-00c-state'), join(raiz, '.claude', 'enforcement-log.jsonl')]],
    ...(hooks ? [[resolve(raiz, hooks.trim()), []]] : []),
    [join(HOME, '.ssh'), []], [join(HOME, '.config', 'gh'), []], [join(HOME, '.local', 'bin'), []],
    [join(HOME, '.gitconfig'), []], [join(HOME, '.bashrc'), []], [join(HOME, '.profile'), []],
  ];
  for (const [r, pula] of raizesMeta) {
    if (!existsSync(r)) { add('meta', r, 'ausente'); continue; }
    const fs = lstatSync(r).isDirectory() ? arquivos(r, pula) : [r];
    for (const f of fs) {
      if (/-(shm|wal)$/.test(f)) continue; // ruído conhecido (SQLite)
      try {
        const s = statSync(f);
        add('meta', f, `${s.size} ${s.mtimeMs} ${s.ctimeMs} ${s.ino}`);
      } catch { /* sumiu entre a listagem e o stat */ }
    }
  }

  // hash: conteúdo, só o sha256 vai à saída.
  const cfg = git(raiz, ['rev-parse', '--git-path', 'config']);
  const hashes = [join(claude, 'settings.json'), join(raiz, '.claude', 'settings.json'),
    join(raiz, '.claude', 'settings.local.json'), ...(cfg ? [resolve(raiz, cfg.trim())] : [])];
  for (const f of hashes) add('hash', f, existsSync(f) ? sha(readFileSync(f)) : 'ausente');
  let cron = 'ausente';
  try { cron = sha(execFileSync('crontab', ['-l'], { stdio: ['ignore', 'pipe', 'ignore'] })); } catch { /* sem crontab */ }
  add('hash', 'crontab -l', cron);
  const cj = lerJson(join(HOME, '.claude.json'), false);
  add('hash', '~/.claude.json#mcpServers', cj && cj.mcpServers !== undefined ? sha(canon(cj.mcpServers)) : 'ausente');

  // plugin e enabled.
  const ip = lerJson(join(claude, 'plugins', 'installed_plugins.json'), true);
  if (ip === undefined) add('plugin', '-', 'ausente');
  else {
    const plugins = ip.plugins && typeof ip.plugins === 'object' ? ip.plugins : {};
    for (const [id, ents] of Object.entries(plugins)) {
      for (const e of [].concat(ents)) {
        add('plugin', `${id}|${e.scope ?? '-'}|${e.projectPath ?? '-'}`, `${e.version ?? '-'} ${e.gitCommitSha ?? '-'}`);
      }
    }
    if (ip.enabledPlugins !== undefined) add('enabled', 'installed_plugins.json', canon(ip.enabledPlugins));
  }
  for (const f of [join(claude, 'settings.json'), join(raiz, '.claude', 'settings.json')]) {
    const s = lerJson(f, false);
    if (s && s.enabledPlugins !== undefined) add('enabled', f, canon(s.enabledPlugins));
  }

  // marketplace e catalogo.
  const km = lerJson(join(claude, 'plugins', 'known_marketplaces.json'), false) || {};
  for (const [nome, m] of Object.entries(km)) {
    const src = (m && m.source) || {};
    add('marketplace', nome, src.repo ?? src.url ?? src.path ?? '-');
    if (m && m.installLocation) add('catalogo', nome, (git(m.installLocation, ['rev-parse', 'HEAD']) || 'ausente').trim());
  }

  // git.
  for (const l of (git(raiz, ['status', '--porcelain', '--ignored']) || '').split('\n')) {
    if (l && !/-(shm|wal)$/.test(l)) add('git', 'status', l);
  }
  for (const l of (git(raiz, ['worktree', 'list']) || '').split('\n')) if (l) add('git', 'worktree', l);

  return linhas.sort(cmp).join('\n') + '\n';
}

function pendentes(log) {
  let txt;
  try { txt = readFileSync(log, 'utf8'); } catch { falha(`log ausente ou ilegível: ${log}`, 2); }
  const abertos = []; // installs temporários ainda sem uninstall
  for (const l of txt.split('\n')) {
    if (!l || l.startsWith('\t')) continue; // continuação de rodada
    const c = l.split('\t');
    const chave = `${c[5]}|${c[6]}|${c[7]}`;
    if (c[4] === 'install' && /^tempor[aá]ria$/.test(c[9] || '')) abertos.push({ chave, l });
    else if (c[4] === 'uninstall') {
      const i = abertos.map((a) => a.chave).lastIndexOf(chave);
      if (i >= 0) abertos.splice(i, 1); // sem install anterior: ignorado
    }
  }
  for (const a of abertos) process.stdout.write(a.l + '\n');
  process.exit(abertos.length ? 1 : 0);
}

const [cmd, ...args] = process.argv.slice(2);
if (cmd === 'foto') {
  let raiz = null;
  if (args.length) {
    if (args[0] !== '--raiz' || args.length !== 2) falha('uso: foto [--raiz <dir>]', 64);
    raiz = resolve(args[1]);
    if (!existsSync(raiz) || !statSync(raiz).isDirectory()) falha(`--raiz inexistente: ${raiz}`, 64);
  } else {
    raiz = (git(process.cwd(), ['rev-parse', '--show-toplevel']) || process.cwd()).trim();
  }
  process.stdout.write(foto(raiz));
} else if (cmd === 'pendentes' && args.length === 1) pendentes(args[0]);
else if (cmd === 'frente' && args.length === 1) {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(args[0])) falha(`frente inválida: ${limpa(args[0])}`, 2);
} else falha('uso: foto [--raiz <dir>] | pendentes <log> | frente <nome>', 64);
