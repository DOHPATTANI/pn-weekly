/* PLANNET DOH v27.0.0 — JavaScript รวมไฟล์เดียว
หมวด 1 กติกาข้อมูล / 2 รายงาน PDF–Excel / 3 ภาพ JPG / 4 ข้อมูลพื้นฐาน
หมวด 5 จัดเก็บในเครื่อง / 6 Supabase / 7 หน้าจอและการทำงาน
ไม่มีข้อมูลสัญญาจริง • มีค่าเริ่มต้น URL/anon key สาธารณะที่ผู้ใช้ระบุ */


// Canonical list controls: local state only; no database writes on navigation.
const tableSizes=new Map(),tableSorts=new Map();
export const tableSize=key=>tableSizes.get(key)||((typeof matchMedia==='function'&&matchMedia('(max-width:640px)').matches)?10:['projects','registry'].includes(key)?50:10);
function setTableSize(key,value){tableSizes.set(key,[10,25,50,100].includes(+value)?+value:10);}
function fileOperationsMenu(scope){const button=(label,attrs)=>'<button type="button" class="btn" '+attrs+'>'+label+'</button>';if(scope==='catalog')return '<details class="file-menu"><summary class="btn">นำเข้า / ส่งออก</summary><div class="file-menu-items">'+button('นำเข้า','data-master-csv-import')+button('ส่งออก','data-master-csv-export')+'</div></details>';return '<details class="file-menu"><summary class="btn">นำเข้า / ส่งออก</summary><div class="file-menu-items"><details class="file-submenu"><summary>นำเข้าจากแหล่งภายนอก</summary><div>'+[['แบบ ก-3','convert-g3'],['แบบ ก-3 งบฉุกเฉิน','convert-emergency'],['แบบ ก-4','import-personnel']].map(([label,action])=>button(label,'data-action="'+action+'"')).join('')+'</div></details><details class="file-submenu"><summary>รูปแบบระบบ</summary><div>'+button('นำเข้า','data-action="import-registry-csv"')+button('ส่งออก','data-action="export-registry-xlsx"')+'</div></details></div></details>';}
function sortCatalogRows(rows,s,tab){const sort=tableSorts.get('catalog:'+tab);if(!sort)return rows;const values=r=>tab==='roadSections'?[r.routeNumber,r.controlSection,r.sectionName]:tab==='workNames'?[r.name,s.workCodes.find(x=>x.id===r.codeIds?.[0])?.name,s.workTypes.find(x=>x.id===r.typeId)?.name]:tab==='contractors'?[r.name,r.address,r.phone]:tab==='supervisors'?[r.name,r.position]:[r.name];return rows.slice().sort((a,b)=>compareTableValues(values(a)[sort.index],values(b)[sort.index])*sort.dir);}

function sortTableRecords(rows,owner,values){const sort=tableSorts.get(owner);return sort?rows.slice().sort((a,b)=>compareTableValues(values(a)[sort.index],values(b)[sort.index])*sort.dir):rows;}

function compareTableValues(a,b){if(a==null||a==='')return b==null||b===''?0:1;if(b==null||b==='')return -1;return String(a).localeCompare(String(b),'th',{numeric:true});}

