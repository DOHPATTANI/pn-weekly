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
 registry[0].workCodeId='wc-1';assert.equal(A.filterDashboardRows(rows,{query:'สป.'},registry).length,2);assert.equal(A.filterDashboardRows(rows,{query:'WC001'},registry,'2026-10-26',[{id:'wc-1',code:'WC001'}]).length,1);
});
test('dashboard view model derives actual scope values and keeps source rows immutable',()=>{
 const rows=[row('p',25,'รอส่งมอบงาน','2026-12-31'),row('q',100,'เบิกจ่ายแล้ว','2026-12-31')],before=structuredClone(rows);
 const state={contractRegistry:[{id:'r',projectId:'p',year:2569,funding:'DOH',budgetAccount:'สป.',workTypeId:'road',contractValue:100,actualCost:25},{id:'s',projectId:'q',year:2569,funding:'DOH',budgetAccount:'สป.',workTypeId:'road',contractValue:200,actualCost:100}],projects:[],workTypes:[{id:'road',name:'งานทาง'}],reports:[]};
 const model=A.selectDashboardViewModel({state,rows,year:2569,funding:'DOH',asOfDate:'2026-10-26'});
 assert.equal(model.actual,62.5);assert.equal(model.plan,90);assert.equal(model.metrics.total,2);assert.equal(model.statusDistribution.reduce((sum,item)=>sum+item.count,0),2);
 assert.equal(model.workTypes[0].count,2);assert.equal(model.workTypes[0].percent,100);assert.equal(model.projectRows[0].record.id,'r');assert.equal(model.pendingRows.length,1);
 assert.equal(A.DASHBOARD_VIEW_CONFIG.pageSize,8);assert.deepEqual(rows,before);
});
test('date and workspace guards reject malformed data before replacement',()=>{
 for(const date of ['2026-02-29','2026-02-31','2026-13-01','not-date']){assert.equal(A.isValidISODate(date),false);assert.throws(()=>A.validateDates({paymentDate:date}));}
 assert(A.isValidISODate('2028-02-29'));assert.throws(()=>A.validateLoadedWorkspace({loadedScope:{}}),/โครงสร้าง/);assert.throws(()=>A.validateBackup(null),/รูปแบบ/);
 assert.throws(()=>A.validateFinancialAmounts({contractValue:100,actualCost:101}),/ไม่เกิน/);assert.throws(()=>A.validateFinancialAmounts({actualCost:-1}),/ไม่ติดลบ/);assert.doesNotThrow(()=>A.validateFinancialAmounts({contractValue:100,actualCost:100}));assert.doesNotThrow(()=>A.validateFinancialAmounts({contractValue:'',actualCost:''}));
});
