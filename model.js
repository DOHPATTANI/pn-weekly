export const clone=o=>JSON.parse(JSON.stringify(o));
export const iso=d=>new Date(d).toISOString().slice(0,10);
export const addDays=(d,n)=>iso(Date.parse(d+'T00:00:00Z')+n*86400000);
export const days=(a,b)=>Math.round((Date.parse(a+'T00:00:00Z')-Date.parse(b+'T00:00:00Z'))/86400000);
export const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Bangkok',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export function rangeFor(date,mode='tue'){let dow=new Date(date+'T00:00:00Z').getUTCDay();let monday=addDays(date,-((dow+6)%7));return mode==='tue'?{start:addDays(monday,-6),end:monday,reference:monday}:{start:monday,end:addDays(monday,6),reference:monday};}
export const complete=e=>Number(e.actual)===100;
export const elapsed=(p,e,reference)=>complete(e)?'-':Math.max(0,days(reference,p.start)+1);
export const effectiveDays=p=>p.duration+p.extensions.filter(e=>e.approved).reduce((n,e)=>n+e.days,0);
export const expired=(p,date=today())=>!!p.end&&date>p.end;
export const entryFor=(report,id)=>report.entries[id]||{plan:0,weekly:0,actual:0,note:'',payment:'รอส่งมอบงาน',confirmed:false};
export function validateEntry(e,previous){for(const k of ['plan','weekly','actual'])if(!Number.isFinite(Number(e[k]))||Number(e[k])<0||Number(e[k])>100)throw Error('เปอร์เซ็นต์ต้องเป็นตัวเลขระหว่าง 0–100');if(previous&&Number(e.actual)<Number(previous.actual))throw Error('ผลงานสะสมลดลงจากรอบก่อน กรุณาตรวจสอบ');if(previous&&Math.abs(Number(e.actual)-Number(previous.actual)-Number(e.weekly))>.011)throw Error('ผลงานสะสมต้องเท่ากับผลงานสะสมรอบก่อน + ผลงานรายสัปดาห์');if(e.payment==='เบิกจ่ายแล้ว'&&!complete(e))throw Error('เบิกจ่ายแล้วต้องมีผลงานสะสม 100%');}
export function projectAt(state,report,id){return report.snapshots?.[id]||state.projects.find(p=>p.id===id);}
export function rowsFor(state,report,year){return Object.keys(report.entries).map(id=>({p:projectAt(state,report,id),e:report.entries[id]})).filter(x=>x.p&&(!year||x.p.year===Number(year))&&(!state.activeFunding||(x.p.funding||'DOH')===state.activeFunding)).sort(sortRows);}
export function createReport(state,range,year,funding='DOH'){if(days(range.end,range.start)!==6)throw Error('รอบรายงานต้องมี 7 วัน');if(range.reference!==range.end||new Date(range.end+'T00:00:00Z').getUTCDay()!==1)throw Error('รอบอังคาร–จันทร์ต้องสิ้นสุดวันจันทร์และใช้วันท้ายรอบคำนวณ');if(state.reports.some(r=>r.start===range.start&&r.year===year&&(r.funding||'DOH')===funding&&!r.imported))throw Error('มีรอบรายงานนี้ในปีงบประมาณที่เลือกแล้ว');const candidates=state.reports.filter(r=>r.end&&r.end<range.start).sort((a,b)=>b.end.localeCompare(a.end));const entries={};for(const p of state.projects.filter(p=>!p.archived&&p.year===year&&(p.funding||'DOH')===funding)){const prev=candidates.find(r=>r.entries[p.id]);const e=prev?entryFor(prev,p.id):entryFor({entries:{}},p.id);entries[p.id]={...clone(e),paymentDate:e.paymentDate||parsePaymentDate(e.note),weekly:0,confirmed:false};}if(!Object.keys(entries).length)throw Error('ไม่มีสัญญาในปีงบประมาณที่เลือก');return {id:'RPT-'+range.end+'-'+year+'-'+funding,title:'สัปดาห์ที่ '+nextWeek(state,year,funding),funding,year,...range,locked:false,imported:false,entries,snapshots:{},createdAt:new Date().toISOString()};}
export function validateProject(p,state,ignoreId){if(!p.title.trim()||!p.contract.trim()||!p.start||!p.end||!p.contractor.trim())throw Error('กรอกข้อมูลงาน สัญญา หมวดหมู่ วันที่ และผู้รับจ้างให้ครบ');if(p.end<p.start)throw Error('วันสิ้นสุดสัญญาต้องไม่น้อยกว่าวันเริ่มต้น');if(!Number.isInteger(p.duration)||p.duration<=0)throw Error('ระยะเวลาดำเนินการต้องเป็นจำนวนเต็มมากกว่า 0');if(state.projects.some(x=>x.id!==ignoreId&&x.year===p.year&&x.contract===p.contract&&(x.funding||'DOH')===(p.funding||'DOH')))throw Error('เลขสัญญานี้มีอยู่แล้วในปีงบประมาณเดียวกัน');}

export const sortRows=(a,b)=>Number(complete(a.e))-Number(complete(b.e))||Number(a.p.year)-Number(b.p.year)||parseInt(a.p.contract)-parseInt(b.p.contract)||a.p.contract.localeCompare(b.p.contract,'th',{numeric:true});
const stableId=(prefix,name)=>{let h=2166136261;for(const c of name)h=Math.imul(h^c.charCodeAt(0),16777619);return prefix+'-'+(h>>>0).toString(16);};
export function normalizeState(s){
 s.contractors||=[];s.supervisors||=[];s.workTypes||=[];s.workNames||=[];
 s.fundingSources||=[{id:'DOH',name:'กรมทางหลวง'},{id:'PROVINCE',name:'งบจังหวัด'}];
 const add=(key,name,prefix)=>{if(!name)return '';let v=s[key].find(x=>x.name===name);if(!v){v={id:stableId(prefix,name),name};if(key==='workNames')v.typeId='';s[key].push(v);}return v.id;};
 for(const p of s.projects){p.funding||='DOH';p.contractorId||=add('contractors',p.contractor,'CTR');p.supervisorId||=add('supervisors',p.supervisor,'SUP');p.workNameId||=add('workNames',p.title,'JOB');p.workTypeId||='';}
 s.settings.systemName||='PN Weekly';s.settings.logo||='';if(!/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(s.settings.logo))s.settings.logo='';
 return s;
}
export function paymentNote(e){return e.payment==='เบิกจ่ายแล้ว'&&e.paymentDate?'เบิกจ่ายแล้ว วันที่ '+new Date(e.paymentDate+'T00:00:00Z').toLocaleDateString('th-TH',{day:'numeric',month:'long',year:'numeric',timeZone:'UTC'}):e.note||(complete(e)?e.payment:'');}
export const fundingName=(s,id)=>s.fundingSources?.find(x=>x.id===id)?.name||(id==='PROVINCE'?'งบจังหวัด':'กรมทางหลวง');
export function reportTitle(s,r,year){const cfg=r.settingsSnapshot||s.settings;return cfg.title.replace(/(?:พ\.?ศ\.?\s*)?25\d{2}|(?<=พรบ\.)\d{2}/g,'').trim()+' '+year+' · '+fundingName(s,s.activeFunding||r.funding||'DOH')+' '+cfg.organization+(r.locked?'':' (ฉบับร่าง)');}

export function parsePaymentDate(note){const m=String(note||'').match(/วันที่\s*(\d{1,2})\s+([^\s]+)\s+(\d{4})/);if(!m)return '';const months=['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'];const month=months.indexOf(m[2])+1;if(!month)return '';return String(+m[3]-543)+'-'+String(month).padStart(2,'0')+'-'+m[1].padStart(2,'0');}

function nextWeek(state,year,funding){const eligible=state.reports.filter(r=>(r.funding||'DOH')===funding&&(r.year===year||(!r.year&&Object.keys(r.entries).some(id=>state.projects.some(p=>p.id===id&&p.year===year)))));return Math.max(0,...eligible.map(r=>Number(String(r.title||'').match(/(?:รอบที่|สัปดาห์ที่)\s*(\d+)/)?.[1]||0)))+1;}
