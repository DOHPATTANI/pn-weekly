import test from 'node:test';
import assert from 'node:assert/strict';
import * as A from '../app.js';
const row=(id,actual,payment='รอส่งมอบงาน',end='2026-10-20')=>({p:{id,contract:id,title:'งาน '+id,end,start:'2026-01-01',extensions:[]},e:{plan:90,actual,weekly:0,payment}});
test('five dashboard stages are exclusive, calendar-reference aware and immutable',()=>{
 const rows=[row('late',50),row('active',20,'รอส่งมอบงาน','2026-12-31'),row('delivery',100),row('payment',100,'รอเบิกจ่าย'),row('paid',100,'เบิกจ่ายแล้ว')],before=structuredClone(rows);
 const dist=A.computeStatusDistribution(rows,'2026-10-26');assert.deepEqual(dist.map(x=>x.count),[1,1,1,1,1]);assert.equal(dist.reduce((n,x)=>n+x.percent,0),100);assert.equal(A.deriveContractStage(rows[0],'2026-10-19'),'ongoing');assert.equal(A.selectPendingActionRows(rows,'2026-10-26')[0].p.id,'late');assert.equal(A.selectPendingActionRows(rows,'2026-10-26').length,4);assert.deepEqual(rows,before);
});
test('budget averages and filters use registry identities, preserve route zeros and escape-independent values',()=>{
 const rows=[row('p',20),row('q',80)],registry=[{id:'r',projectId:'p',budgetAccount:'สป.',workTypeId:'T',segments:[{routeNumber:'0042',controlSection:'0100'}]},{id:'s',projectId:'q',budgetAccount:'สป.'}];
 assert.equal(A.aggregateProgressByBudgetAccount(rows,registry)[0].actual,50);assert.equal(A.filterDashboardRows(rows,{route:'0042'},registry).length,1);assert.equal(A.filterDashboardRows(rows,{query:'0100'},registry).length,1);assert.equal(A.filterDashboardRows(rows,{route:'42'},registry).length,0);
});
test('date and workspace guards reject malformed data before replacement',()=>{
 for(const date of ['2026-02-29','2026-02-31','2026-13-01','not-date']){assert.equal(A.isValidISODate(date),false);assert.throws(()=>A.validateDates({paymentDate:date}));}
 assert(A.isValidISODate('2028-02-29'));assert.throws(()=>A.validateLoadedWorkspace({loadedScope:{}}),/โครงสร้าง/);assert.throws(()=>A.validateBackup(null),/รูปแบบ/);
 assert.throws(()=>A.validateFinancialAmounts({contractValue:100,actualCost:101}),/ไม่เกิน/);assert.throws(()=>A.validateFinancialAmounts({actualCost:-1}),/ไม่ติดลบ/);assert.doesNotThrow(()=>A.validateFinancialAmounts({contractValue:100,actualCost:100}));assert.doesNotThrow(()=>A.validateFinancialAmounts({contractValue:'',actualCost:''}));
});
