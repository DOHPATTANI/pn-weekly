# Requirement-to-validation workflow

ใช้ [AGENT-EFFICIENCY.md](AGENT-EFFICIENCY.md) สำหรับการรวมบทบาท ลด context/log/polling ซ้ำ และเลือก validation ตามผลกระทบ โดยไม่ลด approval/data/release safeguards

เจ้าของระบบยืนยัน workflow นี้ในบทสนทนา 24 October 2026 ใช้กับ requirement, workflow, business logic และ idea ทุกงาน Rules.md คือ entry point และ AGENTS.md เป็นกติกาโครงการหลัก ทั้งบนเครื่องและ GitHub

## Step 1: Rules Review

อ่าน Rules.md → AGENTS.md ก่อนวิเคราะห์หรือแก้ไขทุกครั้ง ตรวจ architecture, security, validation, testing, UX/UI, database, reporting และ delivery หากไม่มี Rules.md ให้ใช้ AGENTS.md ตาม alias ที่ผู้ใช้ระบุ หากไม่พบทั้งคู่ให้หยุดและแจ้งตำแหน่งที่ต้องการ ห้ามอ้างว่าอ่านฉบับ GitHub ถ้าตรวจเพียงฉบับ local

ผลลัพธ์ต้องมี Rules file, Relevant project files, Applicable rules และ Constraints identified

## Step 2: Analysis

สรุป requirement โดยไม่เปลี่ยนความหมาย แยก Facts พร้อม Source, Assumptions พร้อม Impact if incorrect, Unknowns พร้อม Decision impact และ Opinions/Recommendations ระบุ Root Problem, Goal, Users, Success criteria, Scope และ Out of scope

จัด Impact Assessment: Business, UX/UI/accessibility, Data/lifecycle, Security/auth/privacy, API/integration, Performance/reliability/scalability, Maintenance, migration/rollback/compatibility โดยระบุ impact, risk และเหตุผล ตรวจเอกสารทางการและเวอร์ชันก่อนอ้างความสามารถเทคนิค ถ้าข้อมูลขาดเปลี่ยนข้อสรุปให้ถามเฉพาะที่จำเป็น ถ้าความเสี่ยงต่ำให้ระบุสมมติฐานแบบถ้า–แล้ว ห้ามแต่งตัวเลข ผลทดสอบ หรือแหล่งอ้างอิง หากหลักฐานไม่พอให้ใช้ “ยังยืนยันไม่ได้” ทุกข้อเสนอสำคัญต้องมีเหตุผลและทางแก้/ทางสำรองพร้อม trade-off เลือกแนวทางง่ายที่สุดที่ตอบโจทย์

## Requirement-to-Acceptance Matrix

ทุกแผนและผลตรวจต้องมีตาราง traceability ตามนี้ โดยระบุเฉพาะ requirement ใน scope และคำสั่ง/วิธีตรวจที่รันจริง

| Requirement | Source | Implementation area | Acceptance criteria | Validation |
|---|---|---|---|---|
| เปลี่ยนสี sidebar | User instruction | design tokens / styles | สีเปลี่ยนทุก operational screen ตาม token | visual check |
| เพิ่ม KPI | User instruction | dashboard selector + renderer | KPI ใช้ live scoped data เท่านั้น | selector test + UI test |
| ปรับตารางมือถือ | DESIGN.md | responsive renderer | ≤640px แสดง labeled cards ไม่มี horizontal overflow | browser/mobile test |
| คง export เดิม | AGENTS.md | export model | PDF/XLSX columns และ data semantics ไม่เปลี่ยน | export regression test |

สถานะ validation ต้องเป็น Pass, Fail หรือ Not run พร้อมเหตุผล ห้ามสรุปว่าผ่านโดยไม่มีผลตรวจจริง

## Step 3: Implementation Plan

ต้องมี Recommended Approach พร้อมเหตุผล, Alternatives พร้อม benefits/trade-offs/recommendation, Must have, Should have, Out of scope และ Planned Changes ที่ระบุ order/action/files/risk/dependencies

ระบุ database migration, data migration/backfill, authorization, environment variables, dependency, deployment และ sensitive data impact กำหนด Test Plan (unit/integration/E2E ตามความเกี่ยวข้อง), acceptance criteria, rollback, monitoring และ Decision Log Entry (decision/reason/alternatives/source files)

## Step 4: Decision Gate — หยุดเฉพาะการตัดสินใจสำคัญ

เมื่อผู้ใช้สั่งให้ลงมือทำ ให้ดำเนินการตามแผนในขอบเขตนั้นต่อทันที ไม่ต้องหยุดขอยืนยันแผนหรือแต่ละรอบซ้ำ การอ่านโค้ด แก้ไข ทดสอบ แก้ข้อผิดพลาด build และเผยแพร่ที่ได้รับอนุญาตแล้วเป็นขั้นตอนปกติของงาน

หยุดรอคำตอบเฉพาะเมื่อมีทางเลือกสำคัญที่หลักฐานและคำสั่งเดิมยังตัดสินไม่ได้ เช่น ขยายขอบเขตงานอย่างมีนัยสำคัญ ลบข้อมูลที่กู้คืนไม่ได้ เปลี่ยนสิทธิ์หรือเปิดเผยข้อมูล เพิ่มค่าใช้จ่าย/บริการภายนอก หรือเปลี่ยนกฎธุรกิจที่ยังไม่ได้รับอนุญาต ระบุข้อเท็จจริง ผลกระทบ และคำถามที่ต้องให้ผู้ใช้ตัดสินใจอย่างกระชับ ทำส่วนที่ไม่ขึ้นกับคำตอบต่อได้

การแก้บั๊กและปรับรายละเอียดภายในขอบเขตเดิมไม่ถือเป็นเหตุให้ขอยืนยันใหม่ งานทำจนเสร็จทั้งหมดให้ดำเนินต่อจนผ่านการตรวจ เผยแพร่สำเร็จ และตรวจหน้าเว็บจริงพร้อมใช้งานตามคำสั่งผู้ใช้

## Step 5: Implement

แก้เฉพาะ scope ที่ยืนยัน แก้น้อยที่สุด ใช้ component/utility/service/pattern เดิมก่อนสร้างใหม่ ใช้กฎ TypeScript/Zod/auth/RLS เฉพาะที่ตรงกับเทคโนโลยีและข้อตกลงจริง ห้ามเพิ่มเทคโนโลยีหรือระบบ login เพียงเพราะ template ระบุไว้ **ต้องดึงข้อมูลจากฐานข้อมูลจริง (Live Data) เท่านั้น ห้ามใช้ข้อมูลจำลอง (Mock Data) และต้องแยกชั้นการคำนวณ (View Model) ออกจากชั้นแสดงผล (UI) เสมอ**

เอเจนต์แต่ละตัวต้องอ่านกฎและใช้สกิล/ปลั๊กอินที่เหมาะสมจริง บันทึกเครื่องมือที่ใช้และผลส่งต่อ ห้ามอ้างงานผ่านเพียงจากสถานะที่ runner สร้างเอง เก็บ decision ใน docs/decision-log.md หรือมาตรฐานโครงการเดิม

รายงาน Status, Completed, Files changed, Deviations from Approved Plan และ Blockers หาก scope/architecture/data model/security approach ต้องเปลี่ยนให้หยุดส่วนที่เกี่ยวข้องและแจ้งผู้ใช้ ลบไฟล์ชั่วคราวที่สร้างเพื่อ debug หลังเสร็จ แต่เก็บหลักฐาน validation ที่จำเป็นใน work/ ซึ่งไม่เผยแพร่

## Step 6: Validation Result

งานที่เปลี่ยน UI ต้องผ่าน [UI Release Gate](UI-RELEASE-GATE.md) ก่อน push ที่นำไป deploy และตรวจ live revision หลังเผยแพร่ โดยมีภาพ/ผลตรวจของทุกหน้าที่ได้รับผล การแก้ shared shell ต้องตรวจครบหน้าหลัก ไม่ใช้ build หรือ functional QA เป็นหลักฐานแทน visual review และไม่ต้องขอผู้ใช้ยืนยันซ้ำสำหรับการตรวจตามปกติ

คำสั่งให้ทำจนเสร็จทั้งหมดสำหรับเว็บรวมถึง deploy สำเร็จและ production smoke ที่ยืนยันว่าพร้อมใช้งานตามขอบเขตที่อนุญาต ไม่ถามยืนยันซ้ำในแต่ละขั้น และไม่ปิดงานเมื่อทำได้เพียงบางรายการ หากมี blocker จริงต้องระบุหลักฐานตามจริงโดยไม่อ้างพร้อมใช้งาน

เทียบ requirement/implementation/result/source files แบบ traceability รายงานคำสั่งที่รันจริงและ Pass/Fail/Not run พร้อมเหตุผล ครอบคลุม typecheck, lint, unit/integration/E2E, build, security/auth, migration, UX/accessibility ตาม scope

ตรวจ input → validation → transform → storage → display → edit → export/re-import ถ้าเกี่ยวข้อง **และต้องตรวจสอบให้แน่ใจว่าไม่มีสคริปต์ล้างฐานข้อมูล ข้อมูลจำลอง หรือ Hardcoded String หลงเหลืออยู่ใน UI** ตรวจ secrets/credentials/debug/mock/temporary artifacts ห้ามลบ configuration ที่โครงการกำหนดโดยไม่วิเคราะห์ผลกระทบ Performance ต้องมี environment, data size, metric และข้อจำกัดจากการวัดจริง

สรุป Files Changed, Decision Log, Remaining Risks/Uncertainties, Recommended reviewer focus และ Final Summary (Completed, Not completed/reason, Rollback available, Next required action) งานเสร็จเมื่อ scope ที่อนุมัติครบ ตรวจตามเกณฑ์ มีหลักฐาน ข้อจำกัดและ decision log ไม่อ้าง deployment จาก local build
