import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {p301Record} from '../app.js';
const db=new PGlite();
try{
 await db.exec('create role anon;create role authenticated;');
 await db.exec(await fs.readFile(new URL('../supabase/schema.sql',import.meta.url),'utf8'));
 const doc={settings:{p301:{agency:'ทดสอบ'},dataReviews:{large:'unused'}},contractRegistry:[{id:'a',funding:'DOH',year:2569,workCodeId:'w',contractorId:'c',workCode:'31510',contract:'1',title:'งานราว',acceptanceDate:'2026-01-01',actualCost:100000,p301:{confirmed:true}},{id:'b',funding:'PROVINCE',contractorId:'other'},{id:'gone',funding:'DOH',deletedAt:'2026-01-01'}],workCodes:[{id:'w',name:'31510',usefulLifeYears:10,assetCategory:'โครงสร้าง'},{id:'unused',name:'1'}],contractors:[{id:'c',name:'บริษัท',address:'ที่อยู่',phone:'0123'},{id:'other',name:'อื่น'}],reports:[],importHistory:[{large:'unused'}]};
 await db.query("insert into public.pn2_workspaces(workspace_id,document,revision) values('00000000-0000-0000-0000-000000000001',$1,1) on conflict(workspace_id) do update set document=excluded.document,revision=1",[doc]);
 const result=(await db.query("select public.pn2_load_p301_export('DOH') dto")).rows[0].dto;
 assert.equal(result.contractRegistry.length,1);assert.equal(result.contractors.length,1);assert.equal(result.workCodes.length,1);assert(!('reports'in result));assert(!('importHistory'in result));assert(!('dataReviews'in result.settings));
 assert.deepEqual(p301Record(result,result.contractRegistry[0]),p301Record(doc,doc.contractRegistry[0]));
 assert.equal((await db.query("select public.pn2_load_p301_export('UNKNOWN') dto")).rows[0].dto.contractRegistry.length,0);
 console.log('P301 DTO: scoped data, no history/reports, identical report model, empty scope passed');
}finally{await db.close();}
