// Optional in-memory PostgreSQL check. Never connects to your real Supabase.
// Install optional dev tool: npm install --no-save @electric-sql/pglite@0.5.8
import {PGlite} from '@electric-sql/pglite';import fs from 'node:fs/promises';import assert from 'node:assert/strict';import path from'node:path';import{fileURLToPath}from'node:url';import{createReport,clone}from'../model.js';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url))),db=new PGlite();
await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;insert into auth.users values('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222');`);
await db.exec(await fs.readFile(path.join(root,'supabase/migration.sql'),'utf8'));console.log('PASS migration');
await db.exec(`set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111';set role authenticated;`);
let state;try{state=JSON.parse(await fs.readFile(path.join(root,'seed.json'),'utf8'));}catch{state=JSON.parse(await fs.readFile(path.join(root,'seed.empty.json'),'utf8'));}
assert.equal((await db.query('select public.save_workspace($1::jsonb,0) result',[JSON.stringify(state)])).rows[0].result.revision,1);console.log('PASS seed transaction');
assert.equal((await db.query('select count(*)::int n from public.pn_contracts')).rows[0].n,state.projects.length);
await assert.rejects(()=>db.query('select public.save_workspace($1::jsonb,0)',[JSON.stringify(state)]));console.log('PASS revision conflict');
if(state.projects.length){
 const broken=clone(state);broken.reports[0].entries[Object.keys(broken.reports[0].entries)[0]].actual=99;await assert.rejects(()=>db.query('select public.save_workspace($1::jsonb,1)',[JSON.stringify(broken)]));console.log('PASS locked report immutability');
 const r=createReport(state,{start:'2026-09-29',end:'2026-10-05',reference:'2026-10-05'},2568);state.reports.unshift(r);assert.equal((await db.query('select public.save_workspace($1::jsonb,1) result',[JSON.stringify(state)])).rows[0].result.revision,2);console.log('PASS new draft save');
 for(const[id,e]of Object.entries(r.entries)){e.confirmed=true;r.snapshots[id]=clone(state.projects.find(p=>p.id===id));}r.settingsSnapshot=clone(state.settings);r.locked=true;assert.equal((await db.query('select public.save_workspace($1::jsonb,2) result',[JSON.stringify(state)])).rows[0].result.revision,3);console.log('PASS report close with contract snapshots');
 const bad=clone(state);bad.projects[0].contractor='changed';await db.query('select public.save_workspace($1::jsonb,3)',[JSON.stringify(bad)]);console.log('PASS contract updates preserve locked history');
}
await db.exec(`set request.jwt.claim.sub='22222222-2222-2222-2222-222222222222';`);assert.equal((await db.query('select count(*)::int n from public.pn_contracts')).rows[0].n,0);console.log('PASS RLS isolation');
await assert.rejects(()=>db.exec("insert into public.pn_categories values('22222222-2222-2222-2222-222222222222','BAD','bad')"));console.log('PASS direct table writes denied');await db.close();
