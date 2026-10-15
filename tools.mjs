// PN Weekly v6: หมวดทดสอบ / สร้างเว็บ / เปิดเซิร์ฟเวอร์ ในไฟล์เดียว
import fs from 'node:fs/promises';import path from 'node:path';import{fileURLToPath}from'node:url';
const root=path.dirname(fileURLToPath(import.meta.url)),mode=process.argv[2]||'serve';
if(mode==='test'){
 const{test}=await import('node:test');const{default:assert}=await import('node:assert/strict');const App=await import('./app.js');
 const {amendReport,clone,createReport,effectiveDays,elapsed,expired,normalizeState,parsePaymentDate,paymentNote,rangeFor,reportHTML,reportTitle,rowsFor,statusKey,validateDates,validateEntry,xlsxBlob}=App;
// ---- export.test.mjs ----

test('report escapes text, preserves locked settings, colors paid rows and marks drafts',async()=>{
 const p={id:'P1',year:2568,contract:'1/2568',title:'<script>alert(1)</script>',start:'2026-01-01',end:'2026-04-10',duration:100,extensions:[],contractor:'ผู้รับจ้าง',supervisor:'ผู้ควบคุม',extras:{f1:'ตอนควบคุม'}};
 const e={plan:100,weekly:0,actual:100,payment:'เบิกจ่ายแล้ว',note:'& หมายเหตุ'};const state={projects:[p],settings:{title:'ชื่อปัจจุบัน',organization:'หน่วยงาน',customFields:[{id:'f1',name:'ตอนควบคุม'}]}};const r={start:'2026-04-07',end:'2026-04-13',reference:'2026-04-13',locked:true,entries:{P1:e},snapshots:{P1:p},settingsSnapshot:{...state.settings,title:'ชื่อเดิม'}};
 const html=reportHTML(state,r,2568);assert(html.includes('ชื่อเดิม'));assert(!html.includes('<script>'));assert(html.includes('&lt;script&gt;'));assert(html.includes('class="paid"'));r.locked=false;assert(reportHTML(state,r,2568).includes('ฉบับร่าง'));
 const bytes=new Uint8Array(await xlsxBlob(state,r,2568).arrayBuffer());assert.equal(new DataView(bytes.buffer).getUint32(0,true),0x04034b50);const text=new TextDecoder().decode(bytes);assert(text.includes('FFFF3333'));assert(!text.includes('รหัสข้อมูล'));assert(!text.includes('ตอนควบคุม'));assert(text.includes('สรุปความก้าวหน้างาน'));assert(text.includes('_xlnm.Print_Titles'));assert(text.includes('B3:B4'));assert(text.includes('numFmtId="2"'));
});

// ---- model.test.mjs ----

test('Tuesday to Monday and inclusive elapsed days',()=>{assert.deepEqual(rangeFor('2026-10-05'),{start:'2026-09-29',end:'2026-10-05',reference:'2026-10-05'});assert.equal(elapsed({start:'2025-02-07'},{actual:96.1},'2026-04-06'),424);assert.equal(elapsed({start:'2025-02-07'},{actual:100},'2026-04-06'),'-');assert.equal(elapsed({start:'2026-11-01'},{actual:0},'2026-10-05'),0);});
test('expiry is strictly after end and only approved extensions count',()=>{assert.equal(expired({end:'2026-10-05'},'2026-10-05'),false);assert.equal(expired({end:'2026-10-05'},'2026-10-06'),true);assert.equal(effectiveDays({duration:90,extensions:[{days:7,approved:true},{days:100,approved:false}]}),97);});
test('weekly actual reconciliation, bounds, paid completion',()=>{validateEntry({plan:100,weekly:2,actual:87,payment:'รอส่งมอบงาน'},{actual:85});assert.throws(()=>validateEntry({plan:100,weekly:2,actual:88},{actual:85}));assert.throws(()=>validateEntry({plan:101,weekly:0,actual:100}));assert.throws(()=>validateEntry({plan:100,weekly:0,actual:80,payment:'เบิกจ่ายแล้ว'}));assert.throws(()=>validateEntry({plan:100,weekly:0,actual:80},{actual:85}));});
test('new report carries previous entry but resets weekly and confirmation',()=>{const s={projects:[{id:'P1',year:2568,archived:false}],reports:[{id:'old',end:'2026-09-28',entries:{P1:{plan:90,actual:85,weekly:5,confirmed:true}}}]};const r=createReport(s,{start:'2026-09-29',end:'2026-10-05',reference:'2026-10-05'},2568);assert.equal(r.entries.P1.actual,85);assert.equal(r.entries.P1.weekly,0);assert.equal(r.entries.P1.confirmed,false);r.entries.P1.actual=99;assert.equal(s.reports[0].entries.P1.actual,85);assert.throws(()=>createReport(s,{start:'2026-09-28',end:'2026-10-04',reference:'2026-09-28'},2568));});

// ---- no-login.test.mjs ----

test('Supabase RPC works without Auth endpoints, user JWT, password or UID',async()=>{
 const m=new Map();globalThis.localStorage={getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)};const calls=[];
 globalThis.fetch=async(url,opts)=>{calls.push({url,...opts});if(url.endsWith('pn2_load_active_workspace'))return new Response(JSON.stringify({version:1,revision:4}));const b=JSON.parse(opts.body);return new Response(JSON.stringify(b.expected_revision===4?{revision:5}:{message:'revision conflict'}),{status:b.expected_revision===4?200:409});};
 const c=App.cloud;c.setConfig('https://example.supabase.co','sb_publishable_test');assert.equal((await c.loadCloud()).revision,4);assert.equal((await c.saveCloud({version:1},4)).revision,5);assert.equal(calls.at(-1).headers.apikey,'sb_publishable_test');assert.equal(calls.at(-1).headers.Authorization,undefined);assert(calls.every(x=>!x.url.includes('/auth/')));assert(!('login'in c));await assert.rejects(()=>c.saveCloud({},1),/revision conflict/);c.disconnect();assert.equal(c.config(),null);
});

// ---- v3.test.mjs ----

const project=(id,contract,funding='DOH')=>({id,contract,funding,year:2571,title:'งานทาง',contractor:'บริษัท ก',supervisor:'นาย ข',duration:300,extensions:[],start:'2028-01-01',end:'2028-10-26'});
test('master normalization deduplicates names and leaves locked history unchanged',()=>{const p=project('p1','2/2571');const s={projects:[p,project('p2','10/2571')],settings:{},reports:[{locked:true,snapshots:{p1:clone(p)},entries:{p1:{actual:100}}}]};const before=JSON.stringify(s.reports);normalizeState(s);normalizeState(s);assert.equal(s.contractors.length,1);assert.equal(s.supervisors.length,1);assert.equal(s.workNames.length,1);assert.equal(s.workTypes.length,0);assert.equal(JSON.stringify(s.reports),before);});
test('ongoing first, natural contract ordering, separate funding filter',()=>{const s={projects:[project('p10','10/2571'),project('p2','2/2571'),project('done','1/2571'),project('prov','1/2571','PROVINCE')],activeFunding:'DOH'};const r={entries:{p10:{actual:5},p2:{actual:0},done:{actual:100},prov:{actual:0}}};assert.deepEqual(rowsFor(s,r,2571).map(x=>x.p.id),['p2','p10','done']);s.activeFunding='PROVINCE';assert.deepEqual(rowsFor(s,r,2571).map(x=>x.p.id),['prov']);});
test('new week can share fiscal year and dates across funding groups',()=>{const s={projects:[project('d','1/2571'),project('p','1/2571','PROVINCE')],reports:[]};const range={start:'2028-10-03',end:'2028-10-09',reference:'2028-10-09'};const d=createReport(s,range,2571);s.reports.push(d);const p=createReport(s,range,2571,'PROVINCE');assert.deepEqual(Object.keys(d.entries),['d']);assert.deepEqual(Object.keys(p.entries),['p']);assert.notEqual(p.id,d.id);assert.throws(()=>createReport(s,range,2571));});
test('payment date formats Thai note and parses existing original note',()=>{assert.equal(parsePaymentDate('เบิกจ่ายแล้ว วันที่ 9 กรกฎาคม 2568'),'2025-07-09');assert.equal(paymentNote({actual:100,payment:'เบิกจ่ายแล้ว',paymentDate:'2026-10-05'}),'เบิกจ่ายแล้ว วันที่ 5 ตุลาคม 2569');});
test('report fiscal year comes from selected contracts, ignoring fixed setting',()=>{const s={settings:{title:'รายงานความก้าวหน้างาน พรบ.69',reportYear:2569,organization:'หน่วยงาน'}};assert(reportTitle(s,{locked:true},2571).includes('2571'));assert(!reportTitle(s,{locked:true},2571).includes('พรบ.69'));});

// ---- v4.test.mjs ----

test('website buckets separate ongoing, awaiting delivery, awaiting payment and paid',()=>{assert.equal(statusKey({actual:80,payment:'รอส่งมอบงาน'}),'ongoing');assert.equal(statusKey({actual:100,payment:'รอส่งมอบงาน'}),'deliver');assert.equal(statusKey({actual:100,payment:'รอเบิกจ่าย'}),'pay');assert.equal(statusKey({actual:100,payment:'เบิกจ่ายแล้ว'}),'paid');});
test('dates preserve lifecycle order',()=>{validateDates({deliveryDate:'2026-10-01',acceptanceDate:'2026-10-02',paymentDate:'2026-10-03',payment:'เบิกจ่ายแล้ว'});assert.throws(()=>validateDates({deliveryDate:'2026-10-03',acceptanceDate:'2026-10-02'}));});
test('report names follow funding source and snapshots',()=>{const s={projects:[],settings:{title:'งานกรม',organization:'ปัตตานี'},fundingSources:[{id:'DOH',name:'กรมทางหลวง'},{id:'PROVINCE',name:'งบจังหวัด'}]};normalizeState(s);s.settings.reportTitles={DOH:'ชื่อกรม',PROVINCE:'ชื่อจังหวัด'};assert(reportTitle({...s,activeFunding:'PROVINCE'},{locked:true},2571).startsWith('ชื่อจังหวัด 2571'));const r={locked:true,settingsSnapshot:clone(s.settings)};s.settings.reportTitles.PROVINCE='ใหม่';assert(reportTitle({...s,activeFunding:'PROVINCE'},r,2571).startsWith('ชื่อจังหวัด 2571'));});
test('amendment leaves snapshots and later cumulative intact, recalculates weekly',()=>{const e=n=>({plan:100,actual:n,weekly:n,payment:'รอส่งมอบงาน',note:''});const s={audit:[],projects:[],reports:[{id:'old',title:'สัปดาห์ที่ 1',start:'2026-09-29',end:'2026-10-05',locked:true,entries:{p:e(80)},snapshots:{p:{title:'เดิม'}}},{id:'next',title:'สัปดาห์ที่ 2',start:'2026-10-06',end:'2026-10-12',locked:true,entries:{p:{...e(90),weekly:10}}}]};const n=amendReport(s,'old',{p:{actual:85}},'2026-10-14T00:00:00Z');assert.equal(s.reports[0].entries.p.actual,80);assert.equal(n.reports[1].entries.p.actual,90);assert.equal(n.reports[1].entries.p.weekly,5);assert.equal(n.reports[0].snapshots.p.title,'เดิม');assert.equal(n.amendments.length,1);assert.throws(()=>amendReport(n,'old',{p:{actual:95}}));});


// ---- Registry CSV / G-3 tests ----
test('CSV preserves Thai, commas, quotes, multiline and missing vs zero',()=>{const rows=[{contract:'313/-/106/69',title:'งาน, "ทดสอบ"\nไทย',start:'2026-01-01',end:'2026-03-31',duration:90,contractValue:'',actualCost:0}];const parsed=App.parseRegistryCSV(App.registryCSV(rows));assert.equal(parsed[0].title,rows[0].title);assert.equal(parsed[0].contractValue,'');assert.equal(parsed[0].actualCost,0);});
test('Thai dates and contract keys have deterministic representations',()=>{assert.equal(App.parseG3Date('30 ธ.ค. 2568'),'2025-12-30');assert.equal(App.contractKey('ปน.37/2569'),App.contractKey('37/2569'));assert.equal(App.contractKey('313/-/106/69'),'313/-/106/69');});
test('registry duplicate skip and overwrite do not mutate weekly projects/reports or contractor masters',()=>{const r={id:'R1',contract:'ปน.1/2569',title:'เดิม',start:'2026-01-01',end:'2026-03-31',duration:90,year:2569,funding:'DOH'};const state={contractRegistry:[r],projects:[],reports:[{id:'old',entries:{p:{actual:10}}}],contractors:[{id:'C1',name:'เดิม'}],workTypes:[]};const before=JSON.stringify(state);const preview=App.previewRegistryImport(state,[{...r,title:'ใหม่',contractorRaw:'ชื่อจากต้นฉบับ'}],2569,'DOH');assert(preview[0].duplicateId);assert.equal(App.applyRegistryImport(state,preview).skipped,1);const result=App.applyRegistryImport(state,preview,{0:'overwrite'});assert.equal(result.updated,1);assert.equal(result.state.contractRegistry[0].title,'ใหม่');assert.equal(result.state.contractors.length,1);assert.deepEqual(result.state.reports,state.reports);assert.equal(JSON.stringify(state),before);});
test('invalid rows are identified, can be skipped, and types resolve from existing register',()=>{const s={contractRegistry:[],projects:[],reports:[],workTypes:[{id:'T1',name:'ประเภท'}]};const p=App.previewRegistryImport(s,[{contract:'',title:'งาน',start:'',end:'',duration:0},{contract:'2/2569',title:'งาน',start:'2026-01-01',end:'2026-03-31',duration:90,workTypeId:'ประเภท'}],2569,'DOH');assert(p[0].errors.length);assert.equal(p[1].record.workTypeId,'T1');assert.equal(App.applyRegistryImport(s,p,{0:'skip'}).added,1);});

// ---- v6 linked-registry tests ----
const registryFixture=()=>({version:1,projects:[],reports:[],contractRegistry:[{id:'G1',contract:'ปน.2/2570',title:'งานทดสอบ',year:2570,funding:'PROVINCE',start:'2026-10-01',end:'2026-12-29',duration:90,workCode:'31411',budgetAccount:'สป.',contractorRaw:'ชื่อรอจับคู่',contractorId:'',contractorNeedsReview:true,extensions:[]}],contractors:[],supervisors:[],workTypes:[],workNames:[],categories:[],years:[2570],settings:{},audit:[]});
test('registry master migration is idempotent and never creates pending contractor names',()=>{const s=registryFixture();normalizeState(s);const before=JSON.stringify(s);normalizeState(s);assert.equal(JSON.stringify(s),before);assert.equal(s.contractors.length,0);assert.equal(s.budgetAccounts.length,1);assert.equal(s.workCodes.length,1);assert(s.workNames[0].codeIds.includes(s.workCodes[0].id));});
test('first group/year report links registry and starts week1 at zero; subsequent week carries actual',()=>{const s=registryFixture();normalizeState(s);const r=createReport(s,rangeFor('2026-10-12'),2570,'PROVINCE');assert.equal(r.title,'สัปดาห์ที่ 1');const pid=Object.keys(r.entries)[0];assert.equal(r.entries[pid].plan,0);assert.equal(r.entries[pid].weekly,0);assert.equal(r.entries[pid].actual,0);assert.equal(s.projects[0].registryId,'G1');normalizeState(s);assert.equal(s.contractors.length,0);r.entries[pid].plan=50;r.entries[pid].weekly=25;r.entries[pid].actual=25;s.reports.push(r);const next=createReport(s,rangeFor('2026-10-19'),2570,'PROVINCE');assert.equal(next.title,'สัปดาห์ที่ 2');assert.equal(next.entries[pid].actual,25);assert.equal(next.entries[pid].weekly,0);assert.equal(next.entries[pid].plan,50);});
test('delete referenced registry preserves report and excludes contract from future weeks',()=>{const s=registryFixture();normalizeState(s);const r=createReport(s,rangeFor('2026-10-12'),2570,'PROVINCE');s.reports.push(r);const before=JSON.stringify(s.reports);assert.equal(App.deleteRegistryRecord(s,'G1'),'retained-history');assert.equal(JSON.stringify(s.reports),before);assert.equal(App.registryRecords(s,2570,'PROVINCE').length,0);assert.equal(s.projects[0].archived,true);});
test('delete unreported registry removes row and lifecycle sync changes only selected keys',()=>{const s=registryFixture();normalizeState(s);s.contractRegistry[0].projectId='P';s.contractRegistry[0].deliveryDate='2026-10-01';App.syncContractDates(s,'P',{paymentDate:'2026-10-12',deliveryDate:'2026-10-03'},['paymentDate']);assert.equal(s.contractRegistry[0].deliveryDate,'2026-10-01');assert.equal(s.contractRegistry[0].finalPaymentDate,'2026-10-12');assert.equal(App.deleteRegistryRecord(s,'G1'),'deleted');assert.equal(s.contractRegistry.length,0);});
test('sort compares numeric percentages, Thai contract numbers and blank monetary fields',()=>{assert(App.compareData({contract:'ปน.2/2569'},{contract:'ปน.10/2569'},'contract')<0);assert(App.compareData({e:{actual:9}},{e:{actual:80}},'e.actual')<0);assert(App.compareData({contractValue:''},{contractValue:0},'contractValue')>0);assert(App.compareData({contractValue:2},{contractValue:10},'contractValue',-1)>0);});

test('registry extension before first report retains base end and inclusive effective days',()=>{const s=registryFixture();normalizeState(s);const r=s.contractRegistry[0];r.extensions=[{id:'X',days:7,approved:true,reference:'หนังสือ',end:'2027-01-05'}];r.end='2027-01-05';const p=App.projectFromRegistry(s,r);assert.equal(p.originalEnd,'2026-12-29');assert.equal(effectiveDays(p),97);assert.equal(addDaysForTest(p.originalEnd,7),p.end);});
function addDaysForTest(d,n){return App.addDays(d,n);}

test('export contract labels remove Thai prefix while preserving non-PN formats and raw data',()=>{assert.equal(App.displayContract('ป.น. 1/2569'),'1/2569');assert.equal(App.displayContract('ปน.1/2569'),'1/2569');assert.equal(App.displayContract('313/-/106/69'),'313/-/106/69');});
test('master codes have type prefix and six digits, are stable, and never recycle deleted suffix',()=>{const s={contractors:[{id:'old',name:'ก'}],years:[2569]};App.assignMasterCodes(s);assert.equal(s.contractors[0].code,'C000001');assert.equal(s.yearCodes[2569],'Y000001');App.assignMasterCodes(s);assert.equal(s.contractors[0].id,'old');s.contractors=[];s.contractors.push({id:'next',name:'ข'});App.assignMasterCodes(s);assert.equal(s.contractors[0].code,'C000002');});
test('master CSV duplicate preview skips by default and overwrite keeps reference IDs',()=>{const s={contractors:[{id:'keep',name:'บริษัท ก',archived:true}],years:[2569],projects:[],reports:[],contractRegistry:[]};App.assignMasterCodes(s);let p=App.previewMasterCSV(s,'contractors','ชื่อกิจการ\nบริษัท ก\nบริษัท ข\nบริษัท ข');assert(p[0].matchId);assert(p[2].fileDuplicate);const result=App.applyMasterCSV(s,'contractors',p);assert.equal(result.added,1);assert.equal(result.skipped,2);p=App.previewMasterCSV(s,'contractors','รหัส,ชื่อ\n'+s.contractors[0].code+',ชื่อใหม่');App.applyMasterCSV(s,'contractors',p,{0:'overwrite'});assert.equal(s.contractors[0].id,'keep');assert.equal(s.contractors[0].archived,true);});
test('master CSV round trip preserves multiline quotes and code/name links',()=>{const s={workNames:[{id:'J',name:'ชื่อ, "ไทย"\nสองบรรทัด',typeId:'T',codeIds:['W']}],workTypes:[{id:'T',name:'ประเภท'}],workCodes:[{id:'W',name:'31411'}],years:[2569],projects:[],contractRegistry:[]};const csv=App.masterCSV(s,'workNames'),p=App.previewMasterCSV(s,'workNames',csv);assert.equal(p[0].name,s.workNames[0].name);assert.deepEqual(p[0].codes,['31411']);assert.equal(p[0].typeName,'ประเภท');});
test('latest draft week edit retains cumulative actual and protects closed reports',()=>{const s={projects:[{id:'P',year:2569}],reports:[{id:'R',year:2569,funding:'DOH',start:'2026-10-06',end:'2026-10-12',locked:false,entries:{P:{plan:20,weekly:10,actual:10,payment:'รอส่งมอบงาน'}}}]};App.changeDraftWeek(s,'R',{start:'2026-10-13',end:'2026-10-19'});assert.equal(s.reports[0].entries.P.actual,10);assert.equal(s.reports[0].reference,'2026-10-19');s.reports[0].locked=true;assert.throws(()=>App.changeDraftWeek(s,'R',{start:'2026-10-20',end:'2026-10-26'}));});

// ---- Audited file import / export regression ----
test('registry CSV round trip preserves Thai, quoted multiline, decimals, blank and zero',()=>{const rows=[{contract:'1/2569',title:'งาน, "ไทย"\nสองบรรทัด',start:'2026-01-01',end:'2026-03-31',duration:90,contractValue:'',actualCost:0,quantity:1.25}];const parsed=App.parseRegistryCSV(App.registryCSV(rows));assert.equal(parsed[0].title,rows[0].title);assert.equal(parsed[0].contractValue,'');assert.equal(parsed[0].actualCost,0);assert.equal(parsed[0].quantity,1.25);});
test('both CSV import paths reject broken quotes, column widths and duplicate headers',()=>{assert.throws(()=>App.parseCSVTable('ชื่อ\n"เปิดไม่ปิด'),/คำพูด/);assert.throws(()=>App.parseCSVTable('ชื่อ\nผิด"ตำแหน่ง'),/ผิดตำแหน่ง/);assert.throws(()=>App.parseCSVTable('ชื่อ,รหัส\nหนึ่ง'),/คอลัมน์/);assert.throws(()=>App.previewMasterCSV({contractors:[]},'contractors','ชื่อ,ชื่อ\nก,ข'),/ซ้ำ/);assert.throws(()=>App.parseRegistryCSV('contract,contract\n1,2'),/ซ้ำ/);});
test('master CSV imports preserve supplied gapped codes and reject duplicate codes',()=>{const s={projects:[],reports:[],years:[],contractRegistry:[],contractors:[]};const preview=App.previewMasterCSV(s,'contractors','รหัส,ชื่อ\nC000005,ก\nC000010,ข');App.applyMasterCSV(s,'contractors',preview);assert.deepEqual(s.contractors.map(x=>x.code),['C000005','C000010']);assert(App.previewMasterCSV(s,'contractors','รหัส,ชื่อ\nC000005,ก\nC000005,ข')[1].errors.length);assert(App.previewMasterCSV(s,'contractors','รหัส,ชื่อ\nBAD,ใหม่')[0].errors.length);});
const importFixture=()=>{const p={id:'LEGACY-P',contract:'1/2569',year:2569,funding:'DOH',title:'งาน',category:'CAT',start:'2026-01-01',end:'2026-03-31',duration:90,contractor:'ก',supervisor:'ข',extensions:[],archived:false};const s={version:1,projects:[p],reports:[{id:'LEGACY-R',year:2569,funding:'DOH',title:'รอบที่ 1',start:'2026-10-06',end:'2026-10-12',reference:'2026-10-12',locked:true,imported:true,entries:{'LEGACY-P':{plan:90,weekly:5,actual:75,note:'',payment:'รอส่งมอบงาน',confirmed:true}},snapshots:{'LEGACY-P':clone(p)}}],years:[2569],categories:[{id:'CAT',name:'งานทาง'}],audit:[],settings:{title:'รายงาน',organization:'ทดสอบ'}};normalizeState(s);return s;};
test('JSON backup round trip validates closed reports; invalid references and dates fail before import',()=>{const s=importFixture();App.validateBackup(JSON.parse(JSON.stringify(s)));const bad=clone(s);bad.projects[0].start='2026-02-30';assert.throws(()=>App.validateBackup(bad),/วันที่/);const missing=clone(s);missing.reports[0].entries.UNKNOWN=missing.reports[0].entries['LEGACY-P'];assert.throws(()=>App.validateBackup(missing),/อ้างอิง/);assert.throws(()=>App.validateBackup(JSON.parse('{"__proto__":{}}')),/ไม่อนุญาต/);});
test('JSON business matching preserves PK/FK and records confirmed history changes',()=>{const s=importFixture(),incoming=clone(s);incoming.projects[0].id='SOURCE-P';incoming.reports[0].id='SOURCE-R';incoming.reports[0].entries={'SOURCE-P':{...incoming.reports[0].entries['LEGACY-P'],actual:82}};incoming.reports[0].snapshots={'SOURCE-P':{...incoming.projects[0]}};const result=App.prepareWorkspaceImport(s,incoming);assert.equal(result.projects[0].id,'LEGACY-P');assert.equal(result.reports[0].id,'LEGACY-R');assert.equal(result.reports[0].entries['LEGACY-P'].actual,82);const run=App.recordImport(s,result,{fileName:'ใหม่.json',format:'JSON'});assert(run.changes.some(x=>x.before===75&&x.after===82));});
test('import history shows escaped old/new values, removals and bounded pagination',()=>{const changes=App.importChanges({projects:[{id:'P',title:'เก่า'}]},{projects:[]});assert(changes.some(x=>x.before==='เก่า'&&x.kind==='removed'));const html=App.importHistoryHTML([{fileName:'<script>',at:'2026-10-15',changes:Array.from({length:30},()=>({path:'note',before:'เดิม',after:'<img onerror=bad>',kind:'updated'}))}]);assert(!html.includes('<img onerror'));assert(html.includes('&lt;img'));assert(html.includes('หน้า 1/2'));});
test('replacing master CSV archives referenced omissions and removes unreferenced ones',()=>{const s=importFixture();s.contractors.push({id:'FREE',name:'ไม่ใช้งาน',code:'C000005'});const preview=App.previewMasterCSV(s,'contractors','ชื่อ\nใหม่');const result=App.replaceMasterCSV(s,'contractors',preview);assert.equal(result.archived,1);assert.equal(result.removed,1);assert(s.contractors.some(x=>x.name==='ก'&&x.archived));assert(s.contractors.some(x=>x.name==='ใหม่'));assert(!s.contractors.some(x=>x.id==='FREE'));});
test('replacing registry CSV stays within funding/year and preserves closed snapshots',()=>{const s=importFixture();s.projects.push({...clone(s.projects[0]),id:'OTHER',contract:'2/2569',funding:'PROVINCE'});normalizeState(s);const before=JSON.stringify(s.reports);const rows=[{contract:'3/2569',title:'ใหม่',start:'2026-01-01',end:'2026-03-31',duration:90}];const preview=App.previewRegistryImport(s,rows,2569,'DOH');const result=App.replaceRegistryCSV(s,preview);assert.equal(result.removed,1);assert.equal(JSON.stringify(result.state.reports),before);assert(result.state.contractRegistry.some(x=>x.funding==='PROVINCE'&&!x.archived));assert(result.state.projects.find(x=>x.id==='LEGACY-P').archived);});

test('CSV parser handles trailing blank lines, whitespace before quotes, and whitespace-only numeric cells as missing',()=>{
 const table=App.parseCSVTable('\ufeff"รหัส", "ชื่อ"\r\n"C000001", "บริษัท ก"\r\n   ');
 assert.equal(table.length,2);assert.equal(table[1][1],'บริษัท ก');
 const regCsv='"เลขสัญญา","ชื่องาน","เริ่มต้นสัญญา","วันสิ้นสุดปัจจุบัน","ระยะเวลาเดิม (วัน)","วงเงินค่างานตามสัญญา (บาท)","ค่าก่อสร้างจริง (บาท)"\r\n"1/2569","งานทาง","2026-01-01","2026-03-31"," 90 ","   ","0"\r\n';
 const parsed=App.parseRegistryCSV(regCsv);
 assert.equal(parsed[0].duration,90);assert.equal(parsed[0].contractValue,'');assert.equal(parsed[0].actualCost,0);
});

test('registry CSV preview validates optional Thai dates and date order, and re-import unarchives omitted contracts',()=>{
 const s=importFixture();
 const badDates=App.previewRegistryImport(s,[{contract:'9/2569',title:'งาน',start:'2026-01-01',end:'2026-03-31',duration:90,deliveryDate:'2026-04-10',acceptanceDate:'2026-04-05'}],2569,'DOH');
 assert(badDates[0].errors.some(e=>e.includes('ตรวจรับ')));
 const thaiDates=App.previewRegistryImport(s,[{contract:'9/2569',title:'งาน',start:'1 ม.ค. 2569',end:'31 มี.ค. 2569',duration:90,signedAt:'25 ธ.ค. 2568',deliveryDate:'30 มี.ค. 2569',acceptanceDate:'31 มี.ค. 2569'}],2569,'DOH');
 assert.equal(thaiDates[0].errors.length,0);assert.equal(thaiDates[0].record.signedAt,'2025-12-25');
 const step1=App.replaceRegistryCSV(s,thaiDates);
 assert(step1.state.contractRegistry.find(x=>x.contract==='1/2569').archived);
 const reimport=App.previewRegistryImport(step1.state,[{contract:'1/2569',title:'งานคืนชีพ',start:'2026-01-01',end:'2026-03-31',duration:90}],2569,'DOH');
 const step2=App.replaceRegistryCSV(step1.state,reimport,{0:'overwrite'});
 assert.equal(step2.state.contractRegistry.find(x=>x.contract==='1/2569').archived,false);
 assert.equal(step2.state.projects.find(x=>x.id==='LEGACY-P').archived,false);
});

test('master CSV years overwrite, lowercase codes, and compact import history labels',()=>{
 const s=importFixture();normalizeState(s);
 const pYears=App.previewMasterCSV(s,'years','รหัส,ชื่อ\ny000001,2569\ny000009,2571');
 assert.equal(pYears[0].errors.length,0);assert.equal(pYears[0].code,'Y000001');
 const rYears=App.replaceMasterCSV(s,'years',pYears,{0:'overwrite',1:'add'});
 assert.equal(rYears.updated,1);assert.equal(rYears.added,1);assert(s.years.includes(2571));
 const next=clone(s);next.contractors[0].name='เปลี่ยนชื่อผู้รับจ้าง 0';
 const run=App.recordImport(s,next,{fileName:'contractors.csv',format:'CSV'});
 assert.equal(Object.keys(run.labels).length,1);
 const csvOut=App.importHistoryCSV(next.importHistory);
 assert(csvOut.includes('ผู้รับจ้าง / เปลี่ยนชื่อผู้รับจ้าง 0 / ชื่อ'));
});


test('multi-funding 2569 JSON import separates DOH and PROVINCE, handles W017/W018 duplicate dates, and preserves other years',()=>{
 const existing2568={version:1,revision:3,projects:[{id:'P-2568',contract:'1/2568',year:2568,funding:'DOH',title:'งานปี 2568',category:'CAT-001',start:'2025-01-01',end:'2025-03-31',duration:90,contractor:'หจก.เดิม',supervisor:'นาย ก',extensions:[],archived:false}],reports:[{id:'R-2568',year:2568,funding:'DOH',title:'รอบที่ 1',start:'2025-02-04',end:'2025-02-10',reference:'2025-02-10',locked:true,imported:true,entries:{'P-2568':{plan:50,weekly:10,actual:50,note:'',payment:'รอส่งมอบงาน',confirmed:true}},snapshots:{'P-2568':{id:'P-2568',contract:'1/2568',year:2568,funding:'DOH',title:'งานปี 2568',category:'CAT-001',start:'2025-01-01',end:'2025-03-31',duration:90,contractor:'หจก.เดิม',supervisor:'นาย ก',extensions:[],archived:false}}}],years:[2568],categories:[{id:'CAT-001',name:'งานก่อสร้างทาง'}],audit:[],settings:{organization:'แขวงทางหลวงปัตตานี',title:'รายงานความก้าวหน้างาน พรบ.'}};
 normalizeState(existing2568);
 const pProv={id:'XLSX-PROVINCE-2569-C41-2569',contract:'41/2569',year:2569,funding:'PROVINCE',title:'งานติดตั้งราวกันอันตราย',category:'CAT-001',start:'2026-03-25',end:'2026-06-22',duration:90,contractor:'บ.เอ ที ซี ทราฟฟิค จำกัด',supervisor:'นายกรรมสิทธิ์',contractorId:'CTR-46b1425',supervisorId:'SUP-7a3e2fe9',workNameId:'JOB-bd04c8e0',extensions:[],archived:false};
 const pDoh={id:'XLSX-DOH-2569-C17-2569',contract:'17/2569',year:2569,funding:'DOH',title:'กิจกรรมบูรณะโครงข่ายทางหลวง',category:'CAT-001',start:'2025-12-18',end:'2026-04-16',duration:120,contractor:'หจก.ปะนาเระก่อสร้าง',supervisor:'ชม.ขท.ปะนาเระ',contractorId:'CTR-4f7e6b01',supervisorId:'SUP-a9b6133c',workNameId:'JOB-8a80dc71',extensions:[],archived:false};
 const incoming2569={version:1,revision:0,projects:[pProv,pDoh],reports:[
  {id:'XLSX-PROVINCE-2569-W029',title:'รอบที่ 29 (งบจังหวัด)',year:2569,funding:'PROVINCE',start:'2026-10-06',end:'2026-10-12',reference:'2026-10-12',locked:true,imported:true,entries:{[pProv.id]:{plan:100,weekly:0,actual:100,note:'เบิกจ่ายแล้ว',payment:'เบิกจ่ายแล้ว',paymentDate:'2026-07-09',confirmed:true}},snapshots:{[pProv.id]:clone(pProv)}},
  {id:'XLSX-DOH-2569-W018',title:'รอบที่ 18',year:2569,funding:'DOH',start:'2026-04-07',end:'2026-04-13',reference:'2026-04-13',locked:true,imported:true,entries:{[pDoh.id]:{plan:100,weekly:56.07,actual:98.86,note:'',payment:'รอส่งมอบงาน',confirmed:true}},snapshots:{[pDoh.id]:clone(pDoh)}},
  {id:'XLSX-DOH-2569-W017',title:'รอบที่ 17',year:2569,funding:'DOH',start:'2026-04-07',end:'2026-04-13',reference:'2026-04-13',locked:true,imported:true,entries:{[pDoh.id]:{plan:98.86,weekly:31.56,actual:42.79,note:'',payment:'รอส่งมอบงาน',confirmed:true}},snapshots:{[pDoh.id]:clone(pDoh)}}
 ],categories:[{id:'CAT-001',name:'งานก่อสร้างทาง'}],years:[2569],audit:[],issues:[{'กลุ่มงบ':'PROVINCE','แผ่นงาน':'รอบที่ 8 (งบจังหวัด)','แถว':1,'ประเด็น':'ช่วงรายงานเดิมไม่ใช่อังคาร–จันทร์ 7 วัน','รายละเอียด':'คงวันที่ต้นฉบับ'}]};
 App.validateBackup(incoming2569);
 const summary=App.summarizeWorkspaceImport(incoming2569);
 assert.equal(summary.length,2);
 const dohSum=summary.find(x=>x.funding==='DOH'),provSum=summary.find(x=>x.funding==='PROVINCE');
 assert.equal(dohSum.contractsCount,1);assert.equal(dohSum.reportsCount,2);assert.equal(dohSum.uniqueWeeksCount,1);assert.equal(dohSum.duplicateWeeksCount,1);
 assert.equal(provSum.contractsCount,1);assert.equal(provSum.reportsCount,1);
 // Mode 1: keep all sheets (including W017 & W018 sharing 2026-04-07..2026-04-13) while preserving 2568
 const kept=App.prepareWorkspaceImport(existing2568,incoming2569,{targetFunding:'all',mergeByDateRange:false});
 assert(kept.years.includes(2568)&&kept.years.includes(2569));
 assert.equal(kept.projects.filter(p=>p.year===2568).length,1);
 assert.equal(kept.projects.filter(p=>p.year===2569&&p.funding==='PROVINCE').length,1);
 assert.equal(kept.projects.filter(p=>p.year===2569&&p.funding==='DOH').length,1);
 assert.equal(kept.reports.filter(r=>r.year===2569&&r.funding==='DOH').length,2);
 assert(kept.contractors.some(c=>c.name==='บ.เอ ที ซี ทราฟฟิค จำกัด'));
 assert(kept.supervisors.some(s=>s.name==='นายกรรมสิทธิ์'));
 // Mode 2: merge by reporting week range (1 report per unique start-end, W018 wins over W017)
 const merged=App.prepareWorkspaceImport(existing2568,incoming2569,{targetFunding:'all',mergeByDateRange:true});
 const dohReports=merged.reports.filter(r=>r.year===2569&&r.funding==='DOH');
 assert.equal(dohReports.length,1);
 assert.equal(dohReports[0].entries[pDoh.id].actual,98.86);
 // Mode 3: import only PROVINCE
 const onlyProv=App.prepareWorkspaceImport(existing2568,incoming2569,{targetFunding:'PROVINCE'});
 assert.equal(onlyProv.projects.filter(p=>p.year===2569&&p.funding==='PROVINCE').length,1);
 assert.equal(onlyProv.projects.filter(p=>p.year===2569&&p.funding==='DOH').length,0);
 assert.deepEqual(App.parseThaiWeekRange('ระหว่างวันที่ 30 ธ.ค พ.ศ. 2568 - 5 ม.ค. พ.ศ. 2569',2569),{start:'2025-12-30',end:'2026-01-05',reference:'2026-01-05'});
});


test('legacy paid rows keep unknown dates in drafts and recover only documented dates',()=>{
 const s=importFixture();const p=s.projects[0],r=s.reports[0];
 r.start='2026-10-06';r.end='2026-10-12';r.reference=r.end;r.funding='DOH';r.year=2569;
 r.entries[p.id]={plan:100,actual:100,weekly:0,payment:'เบิกจ่ายแล้ว',paymentDate:'',note:'เบิกจ่ายแล้ว',confirmed:true};
 const range={start:'2026-10-13',end:'2026-10-19',reference:'2026-10-19'};
 let next=App.createReport(clone(s),range,2569,'DOH');assert.equal(next.entries[p.id].paymentDate,'');assert.equal(App.missingPaymentDates(next).length,1);
 const documented=clone(s);documented.reports[0].entries[p.id].note='เบิกจ่ายแล้ว วันที่ 12 พฤภาคม 2569';
 next=App.createReport(documented,range,2569,'DOH');assert.equal(next.entries[p.id].paymentDate,'2026-05-12');
 const registered=clone(s);normalizeState(registered);registered.contractRegistry.find(x=>x.projectId===p.id).finalPaymentDate='2026-07-01';
 next=App.createReport(registered,range,2569,'DOH');assert.equal(next.entries[p.id].paymentDate,'2026-07-01');
 assert.equal(App.parsePaymentDate('วันที่ 31 กุมภาพันธ์ 2569'),'');assert.equal(App.parsePaymentDate('เบิกจ่ายแล้ว'),'');
 assert.equal(s.reports[0].entries[p.id].paymentDate,'');
});
test('ordinary mutation isolates editable state without cloning immutable import history',()=>{
 const s=importFixture();s.importHistory=[{id:'audit',changes:[{before:'old',after:'new'}]}];const next=App.cloneForMutation(s);
 assert.equal(next.importHistory,s.importHistory);assert.notEqual(next.projects,s.projects);next.projects[0].title='edited';assert.notEqual(s.projects[0].title,next.projects[0].title);
});
test('ordinary RPC saves omit heavy history while full backup and audit remain available',async()=>{
 const oldFetch=globalThis.fetch,c=App.cloud;const calls=[];globalThis.fetch=async(url,opts)=>{calls.push({url,body:JSON.parse(opts.body)});return new Response(JSON.stringify({revision:9}));};
 try{c.setConfig('https://example.supabase.co','sb_publishable_test');await c.saveCloud({version:1,importHistory:[{id:'large'}],importHistoryDeferred:true},8);assert(!('importHistory'in calls[0].body.payload));assert(!('importHistoryDeferred'in calls[0].body.payload));await c.loadCloud();assert(calls.at(-1).url.endsWith('pn2_load_active_workspace'));await c.loadFullCloud();assert(calls.at(-1).url.endsWith('pn2_load_workspace'));await c.loadHistoryCloud();assert(calls.at(-1).url.endsWith('pn2_load_import_history'));}finally{globalThis.fetch=oldFetch;c.disconnect();}
});

}else if(mode==='build'){
 const dist=path.join(root,'dist');await fs.mkdir(dist,{recursive:true});for(const file of ['index.html','styles.css','app.js','THSarabun.ttf']){try{await fs.copyFile(path.join(root,file),path.join(dist,file));}catch(e){throw Error('ไฟล์ GitHub ไม่ครบ: '+file,{cause:e});}}console.log('Built dist: one JavaScript bundle, no real contract data; public anon configuration included');
}else if(mode==='serve'){
 const{default:http}=await import('node:http');const port=Number(process.env.PORT||4173);const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.ttf':'font/ttf'};
 http.createServer(async(req,res)=>{try{let rel=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(rel==='/')rel='/index.html';if(!['/index.html','/app.js','/styles.css','/THSarabun.ttf'].includes(rel)){res.writeHead(404);return res.end('Not found');}const data=await fs.readFile(path.join(root,rel));res.writeHead(200,{'Content-Type':mime[path.extname(rel)],'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(data);}catch{res.writeHead(404);res.end('Not found');}}).listen(port,'127.0.0.1',()=>console.log('PN Weekly: http://127.0.0.1:'+port));
}else throw Error('Use: node tools.mjs test | build | serve');
