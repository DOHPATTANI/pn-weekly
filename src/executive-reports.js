// ==================== 2. PDF / EXCEL REPORTS ====================
export const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const fmt=d=>d?new Date(d+'T00:00:00Z').toLocaleDateString('th-TH',{day:'numeric',month:'short',year:'numeric',timeZone:'UTC'}):'ไม่ระบุ';
export const displayContract=value=>String(value||'').replace(/^\s*ป\s*\.?\s*น\s*\.?\s*/u,'').trim();
export const reportValues=(p,e,r)=>[displayContract(p.contract),p.title,fmt(p.start),fmt(p.end),effectiveDays(p),r.reference?elapsed(p,e,r.reference):'-',p.contractor,p.supervisor,+e.plan,+e.weekly,+e.actual,String(e.note??'')];
export const summaryRows=rows=>[['ผลงานแล้วเสร็จ 100 %',rows.filter(x=>complete(x.e)).length,''],['เบิกจ่ายแล้ว',rows.filter(x=>x.e.payment==='เบิกจ่ายแล้ว').length,'paid'],['รอเบิกจ่าย',rows.filter(x=>complete(x.e)&&x.e.payment==='รอเบิกจ่าย').length,'pay'],['รอส่งมอบงาน',rows.filter(x=>complete(x.e)&&x.e.payment==='รอส่งมอบงาน').length,'deliver'],['ยังไม่แล้วเสร็จ',rows.filter(x=>!complete(x.e)).length,'']];
export const widthFactors=[1.1,1,1,1,.9,.95,1.1,1,1,1,1,.85];
const rawWidths=[4,21,6,6,5,5,12,7,5,5,5,19].map((w,i)=>w*widthFactors[i]*[1,.8,.9,.9,1,.9,1,1,.8,.8,.8,1.2][i]);
const normalizedWidths=rawWidths.map(w=>w/rawWidths.reduce((a,b)=>a+b,0)*100);
export const widths=normalizedWidths.map((w,i)=>i===0?w*1.07:i===11?w-normalizedWidths[0]*.07:w);

export const reportColumnLabels=['สัญญาที่ ปน.','งานจ้างเหมา','เริ่มต้นสัญญา','สิ้นสุดสัญญา','ระยะเวลาดำเนินการ','ดำเนินการไปแล้ว (วัน)','ผู้รับจ้าง','ผู้ควบคุมงาน','แผนงานสะสม (%)','ผลงานรายสัปดาห์ (%)','ผลงานสะสม (%)','หมายเหตุ'];
export const reportLayoutKey=funding=>'reportLayout'+(funding==='PROVINCE'?'PROVINCE':'DOH');
export function validateReportWidths(values){
 if(!Array.isArray(values)||values.length!==12||values.some(v=>typeof v!=='number'||!Number.isFinite(v)||v<40||v>3000))throw Error('ความกว้างแต่ละช่องต้องอยู่ระหว่าง 40–3,000 พิกเซล');
 if(values.reduce((a,b)=>a+b,0)>18000)throw Error('ความกว้างรวมต้องไม่เกิน 18,000 พิกเซล เพื่อสร้างไฟล์ภาพได้');
 return values;
}
export function fittedReportWidths(s,r,year){
 let ctx;if(typeof document!=='undefined'){ctx=document.createElement('canvas').getContext('2d');ctx.font='18px "TH SarabunPSK"';}
 const measure=text=>ctx?ctx.measureText(String(text)).width:[...new Intl.Segmenter('th',{granularity:'grapheme'}).segment(String(text))].length*9;
 const values=reportColumnLabels.map(text=>Math.max(40,Math.ceil(measure(text)+24)));
 for(const {p,e}of rowsFor(s,r,year))reportValues(p,e,r).forEach((v,i)=>{for(const line of String([8,9,10].includes(i)?Number(v).toFixed(2):v).split('\n'))values[i]=Math.max(values[i],Math.ceil(measure(line)+24));});
 return values;
}
export function reportLayout(s,r,year){
 const custom=s.settings?.[reportLayoutKey(r.funding||s.activeFunding)]?.pixels;
 if(custom){try{validateReportWidths(custom);const total=custom.reduce((a,b)=>a+b,0);return {auto:true,custom:true,widths:custom.map(w=>w*100/total),pixels:[...custom],total};}catch{/* Invalid imported presets fall back to the established layout. */}}
 const province=(r.funding||s.activeFunding||'DOH')==='PROVINCE',pixels=widths.map(w=>w*11);
 if(province){
 let ctx;if(typeof document!=='undefined'){ctx=document.createElement('canvas').getContext('2d');ctx.font='18px "TH SarabunPSK"';}
 const measure=text=>ctx?ctx.measureText(String(text)).width:[...new Intl.Segmenter('th',{granularity:'grapheme'}).segment(String(text))].length*9;
 const first=[measure(reportColumnLabels[0])+24,measure(reportColumnLabels[1])+24];
 for(const {p,e}of rowsFor(s,r,year))reportValues(p,e,r).slice(0,2).forEach((v,i)=>{for(const line of String(v).split('\n'))first[i]=Math.max(first[i],measure(line)+24);});
 const spare=Math.max(0,pixels[0]-first[0]);pixels[0]-=spare;pixels[11]+=spare;
 pixels[1]=Math.max(pixels[1],first[1]);
 }
 const total=pixels.reduce((a,b)=>a+b,0);
 return {auto:province,widths:province?pixels.map(w=>100*w/total):[...widths],pixels,total:province?total:1100};
}

export function reportHTML(s,r,year){const rows=rowsFor(s,r,year),cfg=r.settingsSnapshot||s.settings,layout=reportLayout(s,r,year);return `<table class="main-report ${layout.auto?'auto-report':''} ${layout.custom?'custom-report':''}" ${layout.auto?'style="width:'+Math.ceil(layout.total)+'px;--province-print-font:'+Math.min(12,18000/layout.total)+'px"':''}><colgroup>${layout.widths.map(w=>`<col style="width:${w}%">`).join('')}</colgroup><thead><tr class="report-title"><th colspan="12">${esc(reportTitle(s,r,year))} (รายสัปดาห์)<br>ระหว่างวันที่ ${fmt(r.start)} – ${fmt(r.end)}</th></tr><tr><th rowspan="2">สัญญาที่<br>ปน.</th><th rowspan="2">งานจ้างเหมา</th><th colspan="3">ระยะเวลาดำเนินการ (วัน)</th><th rowspan="2">ดำเนินการ<br>ไปแล้ว<br>(วัน)</th><th rowspan="2">ผู้รับจ้าง</th><th rowspan="2">ผู้ควบคุมงาน</th><th colspan="3">ผลงานรายสัปดาห์</th><th rowspan="2">หมายเหตุ</th></tr><tr><th>เริ่มต้นสัญญา</th><th>สิ้นสุดสัญญา</th><th>ระยะเวลา<br>ดำเนินการ</th><th>แผนงาน<br>สะสม (%)</th><th>ผลงานราย<br>สัปดาห์ (%)</th><th>ผลงาน<br>สะสม (%)</th></tr></thead><tbody>${rows.map(({p,e})=>`<tr class="${e.payment==='เบิกจ่ายแล้ว'?'paid':e.payment==='รอเบิกจ่าย'?'waiting-payment':complete(e)&&e.payment==='รอส่งมอบงาน'?'waiting-delivery':''}">${reportValues(p,e,r).map((v,i)=>`<td>${esc([8,9,10].includes(i)?Number(v).toFixed(2):v)}</td>`).join('')}</tr>`).join('')}<tr class="summary-container"><td colspan="12"><table class="report-summary"><tr><th colspan="2">สรุปความก้าวหน้างาน ${esc(cfg.organization)}</th></tr>${summaryRows(rows).map(([label,n,c])=>`<tr class="summary-${c}"><td>${label}</td><td>${n}</td></tr>`).join('')}</table></td></tr></tbody></table>`;}
export function exportFilename(name){const clean=String(name||'export').replace(/[\\/:*?"<>|]/g,'-').replace(/\s+/g,' ').trim();const dot=clean.lastIndexOf('.'),base=dot>0?clean.slice(0,dot):clean,ext=dot>0?clean.slice(dot):'';const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Bangkok',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date()).reduce((out,x)=>({...out,[x.type]:x.value}),{});return `${base}_${parts.year}${parts.month}${parts.day}-${parts.hour}${parts.minute}${parts.second}${ext}`;}
export function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=exportFilename(name);a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);}
// OOXML workbook, stored ZIP entries; no network or runtime dependency required.
const colName=i=>{let out='';for(i++;i>0;i=Math.floor((i-1)/26))out=String.fromCharCode(65+(i-1)%26)+out;return out;};
const enc=new TextEncoder();const crcTable=Array.from({length:256},(_,n)=>{for(let i=0;i<8;i++)n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
const crc=b=>{let n=0xffffffff;for(const v of b)n=crcTable[(n^v)&255]^(n>>>8);return(n^0xffffffff)>>>0;};
function zip(files){let offset=0;const local=[],central=[];const hdr=(size,fn)=>{const b=new Uint8Array(size);fn(new DataView(b.buffer));return b;};for(const [name,text] of Object.entries(files)){const n=enc.encode(name),b=typeof text==='string'?enc.encode(text):text instanceof Uint8Array?text:new Uint8Array(text),c=crc(b);const h=hdr(30,v=>{v.setUint32(0,0x04034b50,true);v.setUint16(4,20,true);v.setUint32(14,c,true);v.setUint32(18,b.length,true);v.setUint32(22,b.length,true);v.setUint16(26,n.length,true);});local.push(h,n,b);central.push(hdr(46,v=>{v.setUint32(0,0x02014b50,true);v.setUint16(4,20,true);v.setUint16(6,20,true);v.setUint32(16,c,true);v.setUint32(20,b.length,true);v.setUint32(24,b.length,true);v.setUint16(28,n.length,true);v.setUint32(42,offset,true);}),n);offset+=h.length+n.length+b.length;}const end=hdr(22,v=>{v.setUint32(0,0x06054b50,true);v.setUint16(8,Object.keys(files).length,true);v.setUint16(10,Object.keys(files).length,true);v.setUint32(12,central.reduce((n,b)=>n+b.length,0),true);v.setUint32(16,offset,true);});return new Blob([...local,...central,end]);}
export function xlsxBlob(s,r,year){
 const rows=rowsFor(s,r,year),cfg=r.settingsSnapshot||s.settings,layout=reportLayout(s,r,year),merges=['A1:L1','A2:L2','A3:A4','B3:B4','C3:E3','F3:F4','G3:G4','H3:H4','I3:K3','L3:L4'];
 const cell=(v,i,n,style)=>`<c r="${colName(i)}${n}" s="${style}" ${typeof v==='number'?'':'t="inlineStr"'}>${typeof v==='number'?`<v>${v}</v>`:`<is><t xml:space="preserve">${esc(v)}</t></is>`}</c>`;
 const row=(values,n,styles,height=25)=>`<row r="${n}" ht="${height}" customHeight="1">${values.map((v,i)=>cell(v,i,n,typeof styles==='function'?styles(i,v):styles)).join('')}</row>`;
 let n=5;const data=[row([reportTitle(s,r,year)+' (รายสัปดาห์)'],1,1,30),row(['ระหว่างวันที่ '+fileDate(r.start)+' – '+fileDate(r.end)],2,1,26),row(['สัญญาที่\nปน.','งานจ้างเหมา','ระยะเวลาดำเนินการ (วัน)','','','ดำเนินการ\nไปแล้ว (วัน)','ผู้รับจ้าง','ผู้ควบคุมงาน','ผลงานรายสัปดาห์','','','หมายเหตุ'],3,2,28),row(['','','เริ่มต้นสัญญา','สิ้นสุดสัญญา','ระยะเวลา\nดำเนินการ','','','','แผนงาน\nสะสม (%)','ผลงานราย\nสัปดาห์ (%)','ผลงาน\nสะสม (%)',''],4,2,36)];
 for(const {p,e} of rows){const tone=e.payment==='เบิกจ่ายแล้ว'?2:e.payment==='รอเบิกจ่าย'?3:complete(e)&&e.payment==='รอส่งมอบงาน'?4:0;data.push(row(reportValues(p,e,r).map((v,i)=>i===2?fileDate(p.start):i===3?fileDate(p.end):v),n++,i=>tone===3?(i===1?13:[8,9,10].includes(i)?14:15):tone===4?(i===1?16:[8,9,10].includes(i)?17:18):i===1?(tone?6:5):[8,9,10].includes(i)?(tone?4:3):(tone?7:0),32));}
 n++;merges.push(`B${n}:D${n}`);data.push(row(['','สรุปความก้าวหน้างาน '+cfg.organization,'',''],n++,i=>i?8:9,28));
 for(const [label,count,c]of summaryRows(rows)){merges.push(`B${n}:C${n}`);data.push(row(['',label,'',count],n++,i=>i===0?9:c==='paid'?10:c==='pay'?11:c==='deliver'?12:0,24));}
 const xml='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
 const styles=[
 [0,0,1,'center',0],[1,0,0,'center',0],[1,0,1,'center',0],[0,0,1,'center',2],[2,0,1,'center',2],[0,0,1,'left',0],[2,0,1,'left',0],[2,0,1,'center',0],[1,2,1,'center',0],[0,0,0,'center',0],[2,0,1,'center',0],[3,0,1,'center',0],[4,0,1,'center',0],[3,0,1,'left',0],[3,0,1,'center',2],[3,0,1,'center',0],[4,0,1,'left',0],[4,0,1,'center',2],[4,0,1,'center',0]
 ].map(([f,fill,b,align,num])=>`<xf numFmtId="${num}" fontId="${f}" fillId="${fill}" borderId="${b}" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1" applyNumberFormat="1"><alignment horizontal="${align}" vertical="center" wrapText="1"/></xf>`).join('');
 return zip({
 '[Content_Types].xml':xml+'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
 '_rels/.rels':xml+'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
 'xl/workbook.xml':xml+`<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="รายงานรายสัปดาห์" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm.Print_Titles" localSheetId="0">'รายงานรายสัปดาห์'!$1:$4</definedName><definedName name="_xlnm.Print_Area" localSheetId="0">'รายงานรายสัปดาห์'!$A$1:$L$${n-1}</definedName></definedNames></workbook>`,
 'xl/_rels/workbook.xml.rels':xml+'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
 'xl/styles.xml':xml+`<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="5">${['','<b/>','<color rgb="FFFF3333"/>','<color rgb="FF1684BD"/>','<color rgb="FF279A69"/>'].map(x=>`<font>${x}<sz val="16"/><name val="TH SarabunPSK"/></font>`).join('')}</fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="2"><border/><border>${['left','right','top','bottom'].map(x=>`<${x} style="thin"><color rgb="FF808080"/></${x}>`).join('')}</border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="19">${styles}</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>`,
 'xl/worksheets/sheet1.xml':xml+`<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><sheetViews><sheetView workbookViewId="0" showGridLines="0"><pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>${layout.pixels.map(w=>w*270/1100).map((w,i)=>`<col min="${i+1}" max="${i+1}" width="${w}" customWidth="1"/>`).join('')}</cols><sheetData>${data.join('')}</sheetData><mergeCells count="${merges.length}">${merges.map(m=>`<mergeCell ref="${m}"/>`).join('')}</mergeCells><printOptions horizontalCentered="1"/><pageMargins left="0.25" right="0.25" top="0.35" bottom="0.35" header="0.1" footer="0.1"/><pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/><headerFooter><oddFooter>&amp;Rหน้า &amp;P / &amp;N</oddFooter></headerFooter></worksheet>`
 });
}


