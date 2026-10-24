#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';

// Codex coordinates real agents; this CLI validates their handoffs and runs CI gates.
const root = fs.realpathSync(process.cwd());
const runs = path.join(root, 'work', 'agent-runs');
const pointer = path.join(runs, 'latest.json');
const stages = ['audit', 'plan', 'data', 'ui', 'performance', 'security', 'qa', 'release'];
const implementationStages = new Set(['data', 'ui', 'performance', 'security', 'release']);
const commands = [
  ['node', ['tools.mjs', 'verify-source']], ['node', ['tools.mjs', 'verify-schema']],
  ['node', ['tests/p301-export-dto.mjs']], ['npm', ['test']], ['npm', ['run', 'qa']],
  ['npm', ['run', 'qa:audit']], ['npm', ['run', 'build']],
];
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
function check(condition, message) { if (!condition) throw new Error(message); }
function save(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file + '.tmp', JSON.stringify(value, null, 2) + '\n');
  fs.renameSync(file + '.tmp', file);
}
function evidence(file) {
  check(typeof file === 'string' && file.length > 0, 'evidence path required');
  const resolved = fs.realpathSync(path.resolve(root, file));
  check(resolved.startsWith(root + path.sep), 'evidence must be inside this worktree');
  check(fs.statSync(resolved).isFile(), 'evidence must be a file');
  const bytes = fs.readFileSync(resolved);
  check(bytes.length > 0, 'empty evidence is not accepted');
  return { path: path.relative(root, resolved), sha256: sha(bytes) };
}
function rules() { return evidence('AGENTS.md'); }
function worktreeDigest() {
  const files = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8' }).split('\0').filter(Boolean);
  return sha([...new Set(files)].sort().map(file => {
    const full = path.join(root, file);
    return file + ':' + (fs.existsSync(full) ? sha(fs.readFileSync(full)) : 'deleted');
  }).join('\n'));
}
function load({ requireFresh = true } = {}) {
  const state = JSON.parse(fs.readFileSync(pointer, 'utf8'));
  check(state.version === 2, 'legacy run has unverified stage claims; initialize a new run');
  check(state.root === root, 'run belongs to another worktree');
  if (requireFresh) {
    check(state.rules.sha256 === rules().sha256, 'rules changed; cancel and initialize a new run');
    verifyArtifacts([state.task, ...(state.policy ?? [])]);
  }
  return state;
}
function persist(state) {
  save(path.join(runs, state.runId, 'state.json'), state);
  save(pointer, state);
}
function verifyArtifacts(records) {
  for (const record of records) check(evidence(record.path).sha256 === record.sha256, `evidence changed: ${record.path}`);
}
function confirmed(state) {
  check(state.confirmation && state.stages.plan.status === 'passed', 'user confirmation of the plan is required');
  verifyArtifacts([state.confirmation.evidence, ...state.stages.plan.evidence]);
}
function init(taskFile) {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  check(pkg.name === 'pn-weekly' && Number(pkg.version.split('.')[0]) >= 26 && fs.existsSync('src/manifest.json'), 'run from PN Weekly v26+ worktree');
  if (fs.existsSync(pointer)) {
    const previous = JSON.parse(fs.readFileSync(pointer, 'utf8'));
    check(!['running', 'awaiting-confirmation', 'awaiting-review'].includes(previous.status), 'an active run exists; finish or cancel it first');
  }
  const task = evidence(taskFile);
  const state = {
    version: 2, runId: Date.now() + '-' + crypto.randomBytes(4).toString('hex'), root,
    commit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
    rules: rules(), policy: ['Rules.md', 'docs/DEVELOPMENT-WORKFLOW.md'].filter(file => fs.existsSync(file)).map(evidence), task, status: 'running', createdAt: new Date().toISOString(),
    stages: Object.fromEntries(stages.map(id => [id, { status: 'pending' }])), events: [],
  };
  persist(state); console.log(`Created ${state.runId}; next: audit → plan → user confirmation`);
}
function handoff(file) {
  const state = load();
  check(state.status !== 'cancelled' && state.status !== 'completed', 'run is closed');
  const handoffRecord = evidence(file);
  const input = JSON.parse(fs.readFileSync(path.join(root, handoffRecord.path), 'utf8'));
  check(input.runId === state.runId, 'handoff runId does not match');
  const index = stages.indexOf(input.stage);
  check(index >= 0 && input.stage !== 'qa', 'invalid stage; qa is recorded only by --qa');
  check(typeof input.agent === 'string' && input.agent.trim(), 'agent identity required');
  check(Array.isArray(input.skills) && input.skills.length && input.skills.every(x => typeof x === 'string' && x.trim()), 'list skills actually used');
  check(Array.isArray(input.plugins), 'list plugins actually used (empty if none relevant)');
  check(typeof input.summary === 'string' && input.summary.trim(), 'summary required');
  check(['passed', 'blocked', 'needs-rework'].includes(input.status), 'invalid handoff status');
  check(index === 0 || state.stages[stages[index - 1]].status === 'passed', 'previous stage has not passed');
  if (implementationStages.has(input.stage)) confirmed(state);
  if (input.stage === 'release') {
    check(state.stages.qa.results?.length === commands.length, 'complete QA results required');
    check(state.stages.qa.worktreeSha256 === worktreeDigest(), 'worktree changed after QA; rerun --qa');
    verifyArtifacts(state.stages.qa.results.map(item => item.log));
    for (const stage of stages.slice(0, 6)) verifyArtifacts(state.stages[stage].evidence);
  }
  check(Array.isArray(input.evidence) && input.evidence.length, 'stage evidence required');
  const records = input.evidence.map(evidence);
  state.stages[input.stage] = { ...input, evidence: [handoffRecord, ...records], recordedAt: new Date().toISOString() };
  // Rework always invalidates downstream decisions, including prior QA/release.
  for (const next of stages.slice(index + 1)) state.stages[next] = { status: 'pending' };
  if (index <= 1) delete state.confirmation;
  state.status = input.status !== 'passed' ? 'blocked' : input.stage === 'plan' ? 'awaiting-confirmation' : input.stage === 'release' ? 'completed' : 'running';
  state.events.push({ stage: input.stage, status: input.status, at: new Date().toISOString() });
  persist(state); console.log(`${input.stage}: ${input.status}`);
}
function confirm(file) {
  const state = load();
  check(state.status === 'awaiting-confirmation' && state.stages.plan.status === 'passed', 'no approved-ready plan');
  verifyArtifacts(state.stages.plan.evidence);
  const record = evidence(file);
  const input = JSON.parse(fs.readFileSync(path.join(root, record.path), 'utf8'));
  check(input.runId === state.runId && input.planSha256 === state.stages.plan.evidence[0].sha256, 'confirmation must identify this run and current plan handoff hash');
  check(input.decision === 'approved', 'coordinator must explicitly attest an approved decision');
  check(typeof input.userMessage === 'string' && input.userMessage.trim() && typeof input.source === 'string' && input.source.trim(), 'record exact user confirmation and conversation source');
  check(!/ยกเลิก|ยังไม่|ไม่ยืนยัน|do not|cancel|not approved/i.test(input.userMessage), 'message contains a negative decision; clarification required');
  state.confirmation = { evidence: record, recordedAt: new Date().toISOString(), source: input.source };
  state.status = 'running'; persist(state); console.log('User confirmation recorded; implementation stages unlocked');
}
function qa() {
  const state = load(); confirmed(state);
  check(state.status !== 'cancelled', 'run is cancelled');
  for (const stage of stages.slice(0, 6)) {
    check(state.stages[stage].status === 'passed', `${stage} has not passed`);
    verifyArtifacts(state.stages[stage].evidence);
  }
  const attempt = Date.now();
  state.qaAttempts ??= [];
  state.stages.qa = { status: 'running', attempt, worktreeSha256: worktreeDigest(), results: [] };
  state.qaAttempts.push(state.stages.qa);
  state.stages.release = { status: 'pending' }; persist(state);
  for (const [bin, args] of commands) {
    const started = Date.now();
    const log = path.join(runs, state.runId, `qa-${attempt}-${state.stages.qa.results.length}.log`);
    const fd = fs.openSync(log, 'w');
    fs.writeSync(fd, `Command: ${bin} ${args.join(' ')}\nStarted: ${new Date(started).toISOString()}\n`);
    let result;
    try { result = spawnSync(bin, args, { cwd: root, shell: false, stdio: ['ignore', fd, fd], timeout: 15 * 60 * 1000 }); }
    finally { fs.closeSync(fd); }
    const exitCode = result.status ?? 1;
    state.stages.qa.results.push({ command: [bin, ...args], exitCode, signal: result.signal, error: result.error?.message, durationMs: Date.now() - started, log: evidence(log) });
    console.log(`[${exitCode ? 'FAIL' : 'PASS'}] ${bin} ${args.join(' ')}`);
    if (exitCode) {
      state.stages.qa.status = 'blocked'; state.status = 'blocked'; persist(state); process.exitCode = 1; return;
    }
    persist(state);
  }
  check(state.stages.qa.worktreeSha256 === worktreeDigest(), 'worktree changed during QA; rerun --qa');
  state.stages.qa.status = 'passed'; state.status = 'awaiting-review'; persist(state);
  console.log('QA passed; release agent must review evidence. No deployment performed.');
}
let lock;
try {
  const action = process.argv[2], arg = process.argv[3];
  check(['--init', '--handoff', '--confirm', '--qa', '--status', '--cancel'].includes(action), 'Usage: agent:workflow -- --init task.md | --handoff file.json | --confirm file.json | --qa | --status | --cancel');
  if (action !== '--status') {
    fs.mkdirSync(runs, { recursive: true });
    lock = fs.openSync(path.join(runs, '.lock'), 'wx');
  }
  if (action === '--init') init(arg);
  else if (action === '--handoff') handoff(arg);
  else if (action === '--confirm') confirm(arg);
  else if (action === '--qa') qa();
  else if (action === '--cancel') { const state = load({ requireFresh: false }); state.status = 'cancelled'; persist(state); }
  else console.log(JSON.stringify(load(), null, 2));
} catch (error) { console.error('agent-workflow: ' + error.message); process.exitCode = 1; }
finally { if (lock !== undefined) { fs.closeSync(lock); fs.unlinkSync(path.join(runs, '.lock')); } }
