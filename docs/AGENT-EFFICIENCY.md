# การบริหารโควตา Agent — กติกากลาง

## ข้อเท็จจริงและข้อจำกัด

ตรวจจากการส่งงานในบทสนทนารอบ v27, tools/agent-workflow.mjs, tests/agent-workflow.mjs, GitHub workflow และ work/v27-release-notes.md. ไม่มี token usage, cached-input tokens หรือยอดโควตาจริงแยกเอเจนต์ จึงจัดอันดับต้นทุนจริงหรือระบุเปอร์เซ็นต์ประหยัดไม่ได้ เวลารัน shell/CI ไม่ใช่ ChatGPT quota โดยตรง; สิ่งที่มีแนวโน้มเพิ่มงานโมเดลคือบริบทยาว ผลเครื่องมือที่ส่งกลับ การเรียกซ้ำ และการแก้ปัญหาซ้ำ

| กลุ่มเดิม | หลักฐานปัญหา | ผลต่อทรัพยากร | แนวทางใหม่ |
|---|---|---|---|
| Coordinator | ส่งประวัติทั้งชุดให้หลายตัวและรอสถานะสั้นถี่มาก | บริบทซ้ำและรอบเครื่องมือมาก; ยังวัดโควตาจริงไม่ได้ | brief สั้นพร้อม paths/ข้อห้าม/เกณฑ์รับงาน; ใช้ callback และรอเป็นช่วง |
| Dashboard / Theme / Operational UX / P301 | แก้ operations.js และ cascade ร่วมกัน; syntax และ handler integration หลุด | ต้องอ่าน diff/แก้รวมและทดสอบใหม่ | หนึ่งเจ้าของต่อไฟล์; แยกงานพร้อมกันเฉพาะไฟล์ไม่ชน |
| Sidebar | ถอด notification/search แต่ handler เดิมค้าง ทำ startup พัง | full QA เริ่มก่อน smoke ผ่าน | syntax → boot/navigation smoke → focused interaction ก่อน full QA |
| Requirements QA | ทำ inventory แยกก่อน review/integration อีกชุด | เสี่ยงอ่านกฎ/ข้อกำหนดซ้ำ | รวม inventory กับ coordinator; reviewer ตรวจ diff/acceptance หลังรวม |
| Integration / Release | พบ 375px บีบ, topbar ผูกปุ่มเก่า และ live smoke race หลังเริ่ม gates | หลายรอบ QA และ CI; หลายรอบจำเป็นเพราะพบ defect จริง | freeze code ก่อน final gates, screenshot ก่อน PR, test readiness แบบ observable |

ไม่ควรตัด regression ที่เคยจับบั๊กจริงออกเพื่อประหยัด และไม่ควรแปลจำนวนเครื่องมือเป็นยอดเงิน/โควตาโดยไม่มี telemetry

## ชุดบทบาทเดียว

1. **Coordinator:** รับโจทย์ อ่านกฎ วิเคราะห์/วางแผน รวม acceptance/ownership ใน brief เดียว และบันทึกการอนุญาตจริง
2. **Implementer:** ทำโค้ดและ focused tests; งานเล็ก coordinator ทำเอง ไม่ต้องสร้างเอเจนต์เพิ่ม งานอิสระจริงจึงใช้ specialist ไม่เกินความจำเป็น โดยไม่ส่ง full-history ถ้า brief เพียงพอ
3. **Reviewer/Release:** ตรวจ diff, UX/security ตามผลกระทบ, final gates, CI/deploy และ live smoke เมื่อได้รับอนุญาต หากเป็นการเปลี่ยน workflow/docs อย่างเดียวไม่ต้อง deploy เว็บ

Stage audit/plan/data/ui/performance/security/qa/release เป็น checklist ไม่ใช่จำนวนเอเจนต์บังคับ เอเจนต์เดียวส่งหลักฐานหลาย stage ได้; งานไม่เกี่ยวข้องระบุเหตุผล ไม่สร้างงานตรวจปลอมเพื่อให้ครบช่อง

## ลำดับประหยัดที่ยังตรวจสอบได้

- อ่านกฎครบครั้งแรกใน task; ถ้าไม่เปลี่ยนอย่าดึงเนื้อหาเดิมซ้ำใน context เดิม ใช้ skill ที่ตรงงานและอ่าน reference เฉพาะจำเป็น
- ก่อนแบ่งงานกำหนด files owned, dependencies, acceptance และคำสั่งตรวจ ห้ามหลายตัวเขียนไฟล์เดียวพร้อมกัน; reviewer อ่านอย่างเดียว
- ระหว่างพัฒนาใช้ syntax/source consistency และ test ที่เกี่ยวข้อง เก็บ full logs ใน work/ ส่งกลับ exit/result/error excerpt สั้น
- ห้าม full QA ขณะยังมีผู้แก้ source; รวมและตรวจ screenshot/boot/critical interactions ก่อน จึง freeze และรัน final gates
- ถ้าล้มเหลวแก้ต้นเหตุแล้วรัน targeted reproduction ก่อน final gates ที่ถูกกระทบ การแก้ source ทำให้ผล final เดิมไม่ยืนยัน source ใหม่
- ไม่ข้าม CI ที่กำหนด ไม่ reuse pass จากคนละ content digest; ตัดการรันซ้ำเฉพาะกรณีไม่มี code/config/dependency เปลี่ยนและไม่มี unresolved concern
- ไม่ต้องรัน mobile/browser/schema ทั้งชุดสำหรับเอกสารหรือ workflow runner อย่างเดียว; ใช้ runner tests + syntax/diff check ใน local ส่วน CI ยังคงเกณฑ์เดิม
- รอ CI ผ่านเครื่องมือ wait/watch แบบ bounded หรือ callback ไม่ poll ทุก 10 วินาที; ทบทวนเมื่อ state เปลี่ยน อย่าส่งข้อความ unchanged status
- deploy เฉพาะ final verified revision และ smoke read-only บนเว็บจริง; แก้ปัญหา live แล้วตรวจใหม่ก่อนอ้างพร้อมใช้งาน

## หลักฐานและไฟล์

เอกสารนี้เป็นเจ้าของ efficiency policy; `AI-AGENT-WORKFLOW.md` เป็นคู่มือ CLI, `DEVELOPMENT-WORKFLOW.md` เป็น lifecycle/approval, YAML เป็น manifest ไม่ทำสำเนาคำอธิบายยาว เก็บ run evidence ทั้งหมดใน `work/agent-runs/<runId>/`; ไม่ลบ release เก่า ข้อมูลจริง หรือหลักฐานย้อนหลังเพื่อลดความรก

ใช้ `npm run agent:workflow -- --summary` เพื่อดู stage, จำนวน QA attempts/gates, failed gates, elapsed และ log bytes โดยไม่ดึง state/evidence ยาว เครื่องมือนี้ไม่อ่านโควตาบัญชีและไม่เรียกโมเดล ควรเทียบ metrics ก่อน/หลังงานชนิดเดียวกันจึงประเมินผล ไม่ตั้งเป้าประหยัดเป็นเปอร์เซ็นต์จนมีข้อมูลจริง

## ผลรอบนี้

Scope: เอกสาร/CLI summary/tests เท่านั้น; ไม่มี schema/data/auth/runtime/dependency เปลี่ยน ไม่เปลี่ยน gate approval, evidence hashes หรือ release guard. Rollback: revert commit นี้. ไม่ deploy เว็บเพราะไม่มี runtime change. ตัวเลขโควตาจริงของเอเจนต์แต่ละตัว: ยังยืนยันไม่ได้
