import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';

const runner = path.resolve('tools/agent-workflow.mjs');
function fixture() {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'pn-agent-test-'));
  function write(file, data) { fs.mkdirSync(path.dirname(path.join(cwd, file)), {recursive:true}); fs.writeFileSync(path.join(cwd,file),typeof data==='string'?data:JSON.stringify(data)); }
  write('package.json', {name:'pn-weekly',version:'26.0.0',scripts:Object.fromEntries(['test','qa','qa:audit','build'].map(x=>[x,'node tools.mjs']))});
  write('.gitignore','work/\n'); write('src/manifest.json','{}'); write('AGENTS.md','Test rules'); write('work/task.md','Test requirement');
  write('tools.mjs','process.exit(0)'); write('tests/p301-export-dto.mjs','process.exit(0)');
  execFileSync('git',['init','-q'],{cwd}); execFileSync('git',['-c','user.name=Test','-c','user.email=test@example.invalid','commit','--allow-empty','-qm','fixture'],{cwd});
  const run = (...args) => spawnSync(process.execPath,[runner,...args],{cwd,encoding:'utf8'});
  const state = () => JSON.parse(fs.readFileSync(path.join(cwd,'work/agent-runs/latest.json')));
  function handoff(stage, overrides={}) {
    write('work/'+stage+'.md','evidence for '+stage);
    write('work/'+stage+'.json',{runId:state().runId,stage,agent:'test-'+stage,status:'passed',skills:['test-skill'],plugins:[],summary:'fixture evidence only',evidence:['work/'+stage+'.md'],...overrides});
    return run('--handoff','work/'+stage+'.json');
  }
  function approval() { write('work/confirmation.json',{runId:state().runId,planSha256:state().stages.plan.evidence[0].sha256,decision:'approved',userMessage:'ยืนยัน',source:'test fixture (not real authorization)'}); return run('--confirm','work/confirmation.json'); }
  function prepare() { assert.equal(handoff('audit').status,0); assert.equal(handoff('plan').status,0); assert.equal(approval().status,0); for (const s of ['data','ui','performance','security']) assert.equal(handoff(s).status,0); }
  assert.equal(run('--init','work/task.md').status,0);
  return {cwd,write,run,state,handoff,approval,prepare,cleanup:()=>fs.rmSync(cwd,{recursive:true,force:true})};
}

test('cannot bypass plan confirmation, evidence identity or stage ordering', () => {
  const f=fixture(); try {
    assert.notEqual(f.run('--qa').status,0);
    assert.equal(f.state().stages.audit.status,'pending');
    assert.notEqual(f.handoff('plan').status,0);
    assert.notEqual(f.handoff('audit',{runId:'wrong'}).status,0);
    assert.notEqual(f.handoff('audit',{evidence:[]}).status,0);
    assert.equal(f.handoff('audit').status,0);
    assert.equal(f.handoff('plan').status,0);
    assert.notEqual(f.handoff('data').status,0);
    assert.equal(f.approval().status,0);
    assert.equal(f.handoff('data').status,0);
  } finally {f.cleanup();}
});
test('changed plan evidence invalidates approval',()=>{
  const f=fixture();try{f.prepare();f.write('work/plan.md','changed scope');assert.notEqual(f.run('--qa').status,0);}finally{f.cleanup();}
});
test('failed QA exits nonzero, keeps logs and retry succeeds without auto-release',()=>{
  const f=fixture();try{
    f.prepare();f.write('tools.mjs','process.exit(19)');assert.notEqual(f.run('--qa').status,0);
    assert.equal(f.state().status,'blocked');assert.equal(f.state().stages.qa.results[0].exitCode,19);
    f.write('tools.mjs','console.log("fixture pass")');assert.equal(f.run('--qa').status,0);
    assert.equal(f.state().qaAttempts.length,2);assert.equal(f.state().status,'awaiting-review');
    assert.equal(f.state().stages.release.status,'pending');assert.equal(f.handoff('release').status,0);
    assert.equal(f.state().status,'completed');
  }finally{f.cleanup();}
});
test('rework invalidates downstream and requires renewed confirmation',()=>{
  const f=fixture();try{f.prepare();assert.equal(f.handoff('plan',{status:'needs-rework'}).status,0);assert.equal(f.state().confirmation,undefined);assert.equal(f.state().stages.security.status,'pending');assert.notEqual(f.run('--qa').status,0);}finally{f.cleanup();}
});
test('changed rules and legacy auto-passed states cannot be trusted',()=>{
  const f=fixture();try{f.write('AGENTS.md','new rules');assert.notEqual(f.run('--status').status,0);f.write('work/agent-runs/latest.json',{status:'passed'});assert.notEqual(f.run('--status').status,0);}finally{f.cleanup();}
});

test('release rejects ignored upstream evidence modified after QA',()=>{
  const f=fixture();try{f.prepare();assert.equal(f.run('--qa').status,0);f.write('work/security.md','changed findings');assert.notEqual(f.handoff('release').status,0);assert.equal(f.state().stages.release.status,'pending');}finally{f.cleanup();}
});

test('negative decision cannot unlock implementation',()=>{
  const f=fixture();try{assert.equal(f.handoff('audit').status,0);assert.equal(f.handoff('plan').status,0);f.write('work/no.json',{runId:f.state().runId,planSha256:f.state().stages.plan.evidence[0].sha256,decision:'approved',userMessage:'ยังไม่ยืนยัน',source:'fixture'});assert.notEqual(f.run('--confirm','work/no.json').status,0);assert.equal(f.state().status,'awaiting-confirmation');}finally{f.cleanup();}
});

test('changed rules can cancel stale run and initialize a fresh run',()=>{
  const f=fixture();try{const before=f.state().runId;f.write('AGENTS.md','revised rules');assert.notEqual(f.run('--status').status,0);assert.equal(f.run('--cancel').status,0);assert.equal(f.state().status,'cancelled');assert.equal(f.run('--init','work/task.md').status,0);assert.notEqual(f.state().runId,before);}finally{f.cleanup();}
});

test('compact summary reports real gate metrics without exposing evidence or claiming quota',()=>{
  const f=fixture();try{
    f.prepare();assert.equal(f.run('--qa').status,0);
    const result=f.run('--summary');assert.equal(result.status,0);
    const value=JSON.parse(result.stdout);
    assert.equal(value.qaAttempts,1);assert.equal(value.executedGates,7);assert.equal(value.failedGates,0);
    assert(value.logBytes>0);assert(value.gateDurationMs>=0);
    assert.match(value.quotaUsage,/unavailable/);assert.equal(value.stages.qa,'passed');
    assert.equal(value.evidence,undefined);assert.equal(f.state().status,'awaiting-review');
  }finally{f.cleanup();}
});
