// Pure dashboard projections. Existing persisted schemas and lifecycle remain canonical.
export const DASHBOARD_STAGES=Object.freeze([
 {key:'ongoing',label:'กำลังดำเนินการ',color:'#d97a0b'},
 {key:'deliver',label:'รอส่งมอบงาน',color:'#e5a50f'},
 {key:'pay',label:'รอเบิกจ่าย',color:'#50565a'},
 {key:'paid',label:'เบิกจ่ายแล้ว',color:'#16946a'},
 {key:'expired',label:'หมดอายุสัญญา',color:'#e11d48'}
]);
/** @param {Array} rows Report rows. @param {object} filters Committed filters.
 * @param {Array} registry Scope registry. @param {string} date Reference date.
 * @returns {Array} Matching projections; never mutates data or accesses DOM.
 */
export function filterDashboardRows(rows=[],filters={},registry=[],date=today()){
 const byId=new Map();for(const r of registry){byId.set(r.id,r);if(r.projectId)byId.set(r.projectId,r);}
 const needle=String(filters.query||'').trim().toLocaleLowerCase('th');
 return rows.filter(row=>{const p=row.p||{},e=row.e||{},r=byId.get(p.registryId)||byId.get(p.id)||{},segments=r.segments||[],type=p.workTypeId||r.workTypeId||'';
 return (!filters.route||segments.some(s=>s.routeNumber===filters.route))&&(!filters.supervisor||p.supervisor===filters.supervisor)&&(!filters.category||(filters.category==='__none__'?!type:type===filters.category))&&(!filters.budget||r.budgetAccount===filters.budget)&&(!filters.status||filters.status==='all'||deriveContractStage(row,date)===filters.status)&&(!needle||[p.contract,p.title,p.contractor,p.supervisor,...segments.flatMap(s=>[s.routeNumber,s.controlSection,s.sectionName])].join(' ').toLocaleLowerCase('th').includes(needle));});
}
/** Derive one display stage from a report projection without changing its entry.
 * @param {{p:object,e:object}} row Report snapshot and entry.
 * @param {string} asOfDate ISO CE reference day. @returns {string} Display stage. No side effects.
 */
export function deriveContractStage({p={},e={}}={},asOfDate=today()){
 const stage=statusKey(e);
 if(stage==='paid')return 'paid';
 if(stage==='pay')return 'pay';
 if(Number(e.actual)>=100||stage==='deliver')return 'deliver';
 const end=effectiveEnd(p);
 return end&&end<asOfDate?'expired':'ongoing';
}
/** @param {Array} rows Report rows. @param {string} asOfDate Reference date.
 * @returns {Array} New priority-sorted pending projections; never mutates inputs.
 */
export function selectPendingActionRows(rows=[],asOfDate=today()){
 const priority={expired:0,pay:1,deliver:2,ongoing:3};
 return rows.map(row=>({...row,stage:deriveContractStage(row,asOfDate),diffPct:Number(row.e?.actual||0)-Number(row.e?.plan||0),remainingDays:effectiveEnd(row.p||{})?days(effectiveEnd(row.p),asOfDate):null})).filter(row=>row.stage!=='paid').sort((a,b)=>priority[a.stage]-priority[b.stage]||a.diffPct-b.diffPct||String(a.p?.contract).localeCompare(String(b.p?.contract),'th'));
}
/** @param {Array} rows Report projections. @param {string} asOfDate Reference date.
 * @returns {Array} Exclusive distribution summing to the row count. No side effects.
 */
export function computeStatusDistribution(rows=[],asOfDate=today()){
 const counts=new Map(DASHBOARD_STAGES.map(stage=>[stage.key,0]));
 for(const row of rows){const key=deriveContractStage(row,asOfDate);counts.set(key,counts.get(key)+1);}
 return DASHBOARD_STAGES.map(stage=>({...stage,count:counts.get(stage.key),percent:rows.length?counts.get(stage.key)/rows.length*100:0}));
}
/** @param {Array} rows Report projections. @param {Array} registry Scoped registry records.
 * @returns {Array} Account averages and counts. No mutation or DOM access.
 */
export function aggregateProgressByBudgetAccount(rows=[],registry=[]){
 const byId=new Map(),groups=new Map();for(const record of registry){byId.set(record.id,record);if(record.projectId)byId.set(record.projectId,record);}
 for(const {p={},e={}}of rows){const record=byId.get(p.registryId)||byId.get(p.id),name=record?.budgetAccount||'ยังไม่ระบุ',g=groups.get(name)||{name,count:0,sumActual:0,sumPlan:0};g.count++;g.sumActual+=Number(e.actual||0);g.sumPlan+=Number(e.plan||0);groups.set(name,g);}
 return [...groups.values()].map(g=>({name:g.name,count:g.count,actual:g.sumActual/g.count,plan:g.sumPlan/g.count})).sort((a,b)=>b.actual-a.actual||b.count-a.count);
}
/** @param {Array} rows Filtered report rows. @param {Array} registry Scoped contracts.
 * @returns {object} Known finance and plan-comparison counts. No side effects.
 */
export function computeKpiMetrics(rows=[],registry=[]){const ids=new Set(rows.map(x=>x.p?.id)),records=registry.filter(r=>ids.has(r.id)||ids.has(r.projectId)),comparison={ahead:0,onPlan:0,behind:0};for(const row of rows){const difference=Number(row.e?.actual||0)-Number(row.e?.plan||0);comparison[difference>.005?'ahead':difference<-.005?'behind':'onPlan']++;}return {total:rows.length,finance:financialSummary(records),...comparison};}
