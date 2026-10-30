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
function renderReferenceHighway(model,asset){return `<section class="card reference-highway"><h2>แผนภาพสายทาง · ทล. ${esc(asset?.routeNumber||'–')} <small>ตอน ${esc(asset?.controlSection||'–')} ${esc(asset?.sectionName||'')}</small></h2><p class="sub">ช่วงดำเนินงานแยกตามปีงบประมาณ · กดแถบสัญญาเพื่อดูรายละเอียด</p>${model.years.length?`<div class="reference-highway-scroll"><div class="reference-highway-chart">${model.years.map(group=>`<div class="reference-road-row tone-${group.index%3}"><div class="reference-road-year"><b>ปีงบ ${esc(group.year)}</b><small>${group.count} สัญญา</small></div><div class="reference-road-track" style="height:${group.laneCount*42+8}px">${group.items.map(item=>`<button type="button" class="reference-road-segment" data-history-contract="${esc(item.id)}" style="left:${item.left}%;width:${item.width}%;top:${item.lane*42+4}px" title="${esc(item.contract+' · '+item.title+' · กม. '+item.startLabel+'–'+item.endLabel+' '+item.direction)}" aria-label="${esc(item.contract+' กม. '+item.startLabel+' ถึง '+item.endLabel)}"><span>${item.startLabel}</span><b>${esc(item.contract)}</b><span>${item.endLabel}</span></button>`).join('')}</div></div>`).join('')}<div class="reference-road-axis"><span></span><div>${model.ticks.map(t=>`<span style="left:${t.position}%">กม. ${t.label}</span>`).join('')}</div></div></div></div>`:'<p class="empty">ยังไม่มีช่วงกิโลเมตรที่ระบุครบสำหรับแผนภาพ</p>'}${model.missingCount?`<p class="hint">${model.missingCount} สัญญายังไม่มีช่วงกิโลเมตรครบ ตรวจรายละเอียดได้ในตารางด้านล่าง</p>`:''}</section>`;}

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
 if(view==='assetHistory'&&!historyLoading&&!historyError){const panel=app.querySelector('.history-panel');if(panel){const template=document.createElement('template');template.innerHTML=renderReferenceHighway(selectHighwayReferenceTimeline(historyRows()),historyPayload?.asset);panel.before(template.content);for(const button of app.querySelectorAll('.reference-highway [data-history-contract]'))button.onclick=()=>{const record=historyPayload?.contractRegistry?.find(r=>r.id===button.dataset.historyContract);if(record)registryDetailDialog(record.id);};}}
}
