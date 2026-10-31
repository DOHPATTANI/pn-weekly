/** Render inert KPI cards from a resolved view model.
 * @param {Array<object>} metrics Resolved labels and values. @param {string} owner Stable section key.
 * @returns {string} Escaped HTML; never binds new business handlers.
 */
function renderReferenceMetrics(metrics,owner){return `<section class="reference-metrics" data-reference-metrics="${esc(owner)}" aria-label="ตัวเลขสรุป">${metrics.map(m=>`<article class="reference-metric ${esc(m.tone)}"><span>${esc(m.label)}</span><strong>${esc(m.value)}</strong><small>${esc(m.detail)}</small></article>`).join('')}</section>`;}

/** Refresh reference metrics after canonical inline autosave without replacing active inputs.
 * @returns {void} Replaces the metric section only.
 */
function refreshReferenceMetrics({$,state,report,year,rowsFor}){const current=$('[data-reference-metrics=weekly]');if(current){const template=document.createElement('template');template.innerHTML=renderReferenceMetrics(selectWeeklyReferenceMetrics(rowsFor(state,report(),year)),'weekly');current.replaceWith(template.content.firstElementChild);}}

/** Render the source-shaped highway diagram with canonical detail buttons.
 * @param {object} model Resolved timeline. @param {object} asset Selected live route.
 * @returns {string} Semantic chart and textual kilometre ranges.
 */
function renderReferenceHighway(model,asset){return `<section class="card reference-highway"><h2>แผนภาพสายทาง · ทล. ${esc(asset?.routeNumber||'–')} <small>ตอน ${esc(asset?.controlSection||'–')} ${esc(asset?.sectionName||'')}</small></h2><p class="sub">ช่วงดำเนินงานแยกตามปีงบประมาณ · กดแถบสัญญาเพื่อดูรายละเอียด</p>${model.years.length?`<div class="reference-highway-scroll"><div class="reference-highway-chart">${model.years.map(group=>`<div class="reference-road-row tone-${group.index%3}"><div class="reference-road-year"><b>ปีงบ ${esc(group.year)}</b><small>${group.count} สัญญา</small></div><div class="reference-road-track" style="height:${group.laneCount*56+8}px">${group.items.map(item=>`<button type="button" class="reference-road-segment" data-history-contract="${esc(item.id)}" style="left:${item.left}%;width:${item.width}%;top:${item.lane*56+4}px" title="${esc(item.contract+' · '+item.title+' · กม. '+item.startLabel+'–'+item.endLabel+' '+item.direction)}" aria-label="${esc(item.contract+' กม. '+item.startLabel+' ถึง '+item.endLabel)}"><span>${item.startLabel}</span><b>${esc(item.contract)}</b><span>${item.endLabel}</span></button>`).join('')}</div></div>`).join('')}<div class="reference-road-axis"><span></span><div>${model.ticks.map(t=>`<span style="left:${t.position}%">กม. ${t.label}</span>`).join('')}</div></div></div></div>`:'<p class="empty">ยังไม่มีช่วงกิโลเมตรที่ระบุครบสำหรับแผนภาพ</p>'}${model.missingCount?`<p class="hint">${model.missingCount} สัญญายังไม่มีช่วงกิโลเมตรครบ ตรวจรายละเอียดได้ในตารางด้านล่าง</p>`:''}</section>`;}

/** Place existing bound fragments into the reference hierarchy.
 * @returns {void} Moves original nodes; leaves CRUD, filter and export handlers intact.
 */
function mountReferenceLayout({$,view,state,year,report,rowsFor,registryVisibleRecords,historyLoading,historyError,historyRows,historyPayload,registryDetailDialog}){
 const app=$('#app'),context=$('.topbar .page-context');
 if(view==='dashboard'){
  const tools=app.querySelector('.dash-reference-tools'),bar=app.querySelector('.dash-v25-filter');if(tools&&bar)bar.append(tools);
  const yearSelect=$('#year');if(yearSelect)for(const option of yearSelect.options)option.textContent=option.value;
 }
 if(view==='weekly'||view==='projects'){
  if(view==='weekly'){const extra=app.querySelector('.weekly-control-tools'),host=app.querySelector('.weekly-table-panel .table-density');if(extra&&host){host.append(extra);extra.classList.remove('filters');}const empty=app.querySelector('.weekly-controls');if(empty&&!empty.querySelector('input,select,button,details'))empty.remove();}
  const template=document.createElement('template');template.innerHTML=renderReferenceMetrics(view==='weekly'?selectWeeklyReferenceMetrics(rowsFor(state,report(),year)):selectRegistryReferenceMetrics(state,registryVisibleRecords()),view);app.prepend(template.content);
  const status=app.querySelector('.weekly-archive-status,.notice.success');if(view==='weekly'&&status){status.classList.add('reference-week-status');context.prepend(status);context.hidden=false;}
 }
 if(view==='p301'){
  const all=app.querySelector('[data-p301-filter=all]'),tools=app.querySelector('.p301-table-tools');if(all&&tools){all.classList.add('reference-all-assets');tools.prepend(all);}
  const scope=app.querySelector('.p301-scope');if(scope){const hint=scope.querySelector('.hint');if(hint)$('#page-description').textContent=hint.textContent;scope.remove();}
 }
 if(view==='catalog'){
  const tabs=app.querySelector('.catalog-tabs');if(tabs){context.append(tabs);context.hidden=false;}
 }
 // Keep commands beside the records they affect, without cloning their handlers.
 if(view!=='dashboard'){
  const dock=app.querySelector('.operational-dock'),toolbar=app.querySelector('.table-density');
  if(dock&&toolbar&&['projects','p301','catalog'].includes(view)){dock.classList.add('record-actions-dock');toolbar.before(dock);}
  for(const empty of app.querySelectorAll('.table-top,.command-search-row,.registry-control-tools,.weekly-control-tools'))if(!empty.textContent.trim()&&!empty.querySelector('input,select,button,details'))empty.remove();
  if(view==='settings')app.querySelector('.operational-dock')?.remove();
  if(view==='settings'){
   const heading=app.querySelector('#theme-settings-title');if(heading)heading.textContent='การแสดงผลบนอุปกรณ์นี้';
   const save=app.querySelector('#settings-form [type=submit]');if(save)save.textContent='บันทึกข้อมูลระบบส่วนกลาง';
  }
  if(view==='weekly'){
   app.dataset.reportLocked=String(!!report().locked);
   const batch=context.querySelector('.weekly-batch-tools');if(batch&&report().locked)batch.hidden=true;
  }
 }
 if(view==='assetHistory'&&!historyLoading&&!historyError){const panel=app.querySelector('.history-panel');if(panel){const template=document.createElement('template');template.innerHTML=renderReferenceHighway(selectHighwayReferenceTimeline(historyRows()),historyPayload?.asset);panel.before(template.content);for(const button of app.querySelectorAll('.reference-highway [data-history-contract]'))button.onclick=()=>{const record=historyPayload?.contractRegistry?.find(r=>r.id===button.dataset.historyContract);if(record)registryDetailDialog(record.id);};}}
 if(view==='assetHistory'){
  const chart=app.querySelector('.reference-highway');if(chart){const list=document.createElement('details');list.className='highway-readable-list';const summary=document.createElement('summary');summary.textContent='อ่านเลขสัญญาและช่วงกิโลเมตรทั้งหมด';list.append(summary);const rows=document.createElement('ul');for(const segment of chart.querySelectorAll('.reference-road-segment')){const row=document.createElement('li');row.textContent=segment.title;rows.append(row);}list.append(rows);chart.append(list);}
 }
}
