// Pure dashboard projections. Existing persisted schemas and lifecycle remain canonical.
export const DASHBOARD_STAGES=Object.freeze([
 {key:'ongoing',label:'กำลังดำเนินการ',color:'#d97a0b'},
 {key:'deliver',label:'รอส่งมอบงาน',color:'#e5a50f'},
 {key:'pay',label:'รอเบิกจ่าย',color:'#50565a'},
 {key:'paid',label:'เบิกจ่ายแล้ว',color:'#16946a'},
 {key:'expired',label:'หมดอายุสัญญา',color:'#e11d48'}
]);
/** Presentation defaults for the two dashboard summary tables and work-type chart. */
export const DASHBOARD_VIEW_CONFIG=Object.freeze({pageSize:8,workTypeColors:Object.freeze(['#0f766e','#22a06b','#4fbf9f','#c99a2e','#5b6f8f','#d45b72','#8b6bb1','#6b7c72'])});
/** @param {Array} rows Report rows. @param {object} filters Committed filters.
 * @param {Array} registry Scope registry. @param {string} date Reference date.
 * @param {Array} workCodes Loaded work-code masters.
 * @returns {Array} Matching projections; never mutates data or accesses DOM.
 */
export function filterDashboardRows(rows=[],filters={},registry=[],date=today(),workCodes=[]){
 const byId=new Map();for(const r of registry){byId.set(r.id,r);if(r.projectId)byId.set(r.projectId,r);}
 const codeById=new Map(workCodes.map(code=>[code.id,code]));
 const needle=String(filters.query||'').trim().toLocaleLowerCase('th');
 return rows.filter(row=>{const p=row.p||{},e=row.e||{},r=byId.get(p.registryId)||byId.get(p.id)||{},segments=r.segments||[],type=p.workTypeId||r.workTypeId||'';
 return (!filters.route||segments.some(s=>s.routeNumber===filters.route))&&(!filters.supervisor||p.supervisor===filters.supervisor)&&(!filters.category||(filters.category==='__none__'?!type:type===filters.category))&&(!filters.budget||r.budgetAccount===filters.budget)&&(!filters.status||filters.status==='all'||deriveContractStage(row,date)===filters.status)&&(!needle||[p.contract,p.title,p.contractor,p.supervisor,r.budgetAccount,r.workCodeId,codeById.get(r.workCodeId)?.code,codeById.get(r.workCodeId)?.name,...segments.flatMap(s=>[s.routeNumber,s.controlSection,s.sectionName])].join(' ').toLocaleLowerCase('th').includes(needle));});
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

/** Build the dashboard's read-only view model from the loaded scope. No DOM or writes.
 * @param {{state:object,rows:Array,filters:object,year:number,funding:string,asOfDate:string}} input Loaded workspace and selected scope.
 * @returns {object} Resolved metrics, trend, charts and table rows for presentation.
 */
export function selectDashboardViewModel({state,rows=[],filters={},pendingQuery='',pendingMode='all',year,funding,asOfDate=today()}){
 const registry=state.contractRegistry||[];
 rows=filterDashboardRows(rows,filters,registry,asOfDate,state.workCodes||[]);
 const scopedRegistry=registry.filter(r=>!r.deletedAt&&(r.funding||'DOH')===funding&&r.year===year);
 const average=(items,key)=>items.length?items.reduce((sum,row)=>sum+Number(row.e?.[key]||0),0)/items.length:0;
 const actual=average(rows,'actual'),plan=average(rows,'plan');
 const history=(state.reports||[]).filter(r=>reportMatchesScope(state,r,year,funding)&&Object.keys(r.entries||{}).length).sort((a,b)=>(b.end||b.reference||'').localeCompare(a.end||a.reference||'')).slice(0,6).reverse().map(report=>{
  const reportRows=rowsFor({...state,activeFunding:funding},report,year);
  return {report,rows:reportRows,actual:average(reportRows,'actual'),plan:average(reportRows,'plan'),pendingCount:selectPendingActionRows(reportRows,report.end||asOfDate).length,entryCount:Object.keys(report.entries||{}).length};
 });
 const previous=history.length>1?history[history.length-2]:null;
 const diffActual=actual-(previous?previous.actual:actual);
 const metrics=computeKpiMetrics(rows,scopedRegistry),finance=metrics.finance;
 const delayedDiff=metrics.behind-(previous?computeKpiMetrics(previous.rows,scopedRegistry).behind:metrics.behind);
 const byId=new Map();for(const record of registry){byId.set(record.id,record);if(record.projectId)byId.set(record.projectId,record);}
 const projectTypes=new Map((state.projects||[]).map(p=>[p.id,p.workTypeId]));
 const typeNames=new Map((state.workTypes||[]).map(type=>[type.id,type.name]));
 const workTypeMap=new Map();
 for(const {p={}} of rows){const id=p.workTypeId||projectTypes.get(p.id)||(byId.get(p.registryId)||byId.get(p.id))?.workTypeId||'__none__',name=typeNames.get(id)||'ยังไม่ระบุประเภทงาน',item=workTypeMap.get(id)||{id,name,count:0};item.count++;workTypeMap.set(id,item);}
 let offset=0;
 const workTypes=[...workTypeMap.values()].sort((a,b)=>b.count-a.count||a.name.localeCompare(b.name,'th')).map(item=>{const percent=rows.length?item.count/rows.length*100:0,result={...item,percent,offset};offset+=percent;return result;});
 const projectRows=rows.map(({p={},e={}})=>{const record=byId.get(p.registryId)||byId.get(p.id)||{},stage=deriveContractStage({p,e},asOfDate);const behind=Number(e.actual)<Number(e.plan)&&!complete(e);return {p,e,record,stage:DASHBOARD_STAGES.find(item=>item.key===stage),actualPct:Math.min(100,Math.max(0,Number(e.actual)||0)),planPct:Math.min(100,Math.max(0,Number(e.plan)||0)),statusLabel:stage==='ongoing'&&behind?'ล่าช้า':DASHBOARD_STAGES.find(item=>item.key===stage)?.label||'ยังไม่ระบุ',statusTone:stage==='expired'||behind?'red':stage==='paid'?'green':stage==='deliver'||stage==='pay'?'blue':'amber'};});
 const attention=rows.filter(({p={},e={}})=>!complete(e)&&(expired(p,asOfDate)||Number(e.actual)<Number(e.plan))).sort((a,b)=>(Number(b.e?.plan)-Number(b.e?.actual))-(Number(a.e?.plan)-Number(a.e?.actual)));
 const pendingAll=selectPendingActionRows(rows,asOfDate),projectById=new Map(projectRows.map(item=>[item.p.id,item]));
 const pendingCounts={all:pendingAll.length,incomplete:pendingAll.filter(item=>!complete(item.e)).length,expired:pendingAll.filter(item=>item.stage==='expired').length,followup:pendingAll.filter(item=>['deliver','pay'].includes(item.stage)).length};
 const needle=String(pendingQuery||'').trim().toLocaleLowerCase('th');
 const pendingProjectRows=pendingAll.filter(item=>(pendingMode==='all'||pendingMode==='incomplete'&&!complete(item.e)||pendingMode==='expired'&&item.stage==='expired'||pendingMode==='followup'&&['deliver','pay'].includes(item.stage))&&(!needle||[item.p.contract,item.p.title,item.p.contractor].join(' ').toLocaleLowerCase('th').includes(needle))).map(item=>projectById.get(item.p.id)).filter(Boolean);
 return {routeOptions:[...new Set(scopedRegistry.flatMap(record=>(record.segments||[]).map(segment=>segment.routeNumber)).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'th',{numeric:true})),supervisorOptions:[...new Set(rows.map(item=>item.p.supervisor).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'th')),rows,pendingCounts,pendingProjectRows,incompleteCount:rows.filter(item=>!complete(item.e)).length,actual,plan,overallDiff:actual-plan,done:rows.filter(({e})=>complete(e)).length,metrics,finance,disbursedMB:finance.actualCost/1000000,disbursedPct:finance.percent===null?null:+finance.percent.toFixed(1),diffActual,delayedDiff,history,attention,statusDistribution:computeStatusDistribution(rows,asOfDate),pendingRows:selectPendingActionRows(rows,asOfDate),budgetGroups:aggregateProgressByBudgetAccount(rows,registry),workTypes,projectRows};
}
