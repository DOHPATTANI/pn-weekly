# PN Weekly agent workflow

นโยบายลดงานซ้ำและยุบรวมบทบาทอยู่ที่ `docs/AGENT-EFFICIENCY.md` เป็นแหล่งอ้างอิงเดียว **Stage ในตารางด้านล่างนี้เป็นเพียง Checklist ไม่บังคับสร้างเอเจนต์แยก** ให้ใช้คำสั่ง `npm run agent:workflow -- --summary` แทน `--status` เมื่อต้องการเพียงภาพรวมและค่า gate metrics (เนื่องจากระบบไม่มีข้อมูล Token/โควตาจริงแสดงใน CLI)

อ่าน `Rules.md` → `AGENTS.md` → `docs/DEVELOPMENT-WORKFLOW.md` ก่อนเริ่มงานเสมอ เอเจนต์จริงรับงานจาก Codex Coordinator ผ่านเครื่องมือ Delegation ที่มีใน Session ส่วน CLI ตัวนี้มีหน้าที่ตรวจหลักฐาน Handoff และเรียกคำสั่ง QA เท่านั้น จะไม่มีการเรียกโมเดลหรือทำงานเบื้องหลังเมื่อปิด Session

## บทบาทและลำดับ (Stage Checklist)

| Stage | หน้าที่ | สกิล/ปลั๊กอินที่พิจารณาเมื่อเกี่ยวข้อง |
|---|---|---|
| audit | ตรวจ rules, repo และ root cause | full-stack-integrity / code analysis ที่มี |
| plan | ระบุ Facts/Assumptions/Unknowns, scope, แผน และเกณฑ์ตรวจรับ | สกิลโดเมนของงาน |
| confirmation | บันทึกคำยืนยันผู้ใช้ที่ผูกกับแผนการทำงาน | coordinator บันทึกข้อความจริงจากผู้ใช้ |
| data | จัดการ DB/API/data contract (หากไม่เกี่ยวให้ระบุเหตุผล) | supabase / postgres best practices |
| ui | Implementation และ UX ตาม scope (หากไม่เกี่ยวให้ระบุเหตุผล) | frontend-design-premium / impeccable |
| performance | ตรวจผลกระทบด้านประสิทธิภาพและข้อจำกัดการวัด | เครื่องมือ profiling ที่เหมาะกับ stack |
| security | ตรวจความเสี่ยงจาก Code Diff | สกิล security ตามพื้นที่ที่แก้ไข |
| qa | รัน CI gates บังคับและเก็บ logs | web-qa-release |
| release | ตรวจผลจริง ข้อจำกัด และอัปเดต decision log | verification/release skills ที่มี |

**ข้อห้าม:** ห้ามใช้สกิลผิด Stack หรืออ้างว่าใช้สกิลเพียงเพื่อให้ครบตามตาราง หากบทบาทหรือ Stage ใดไม่เกี่ยวข้องกับงาน ให้แนบ Rationale เป็น Evidence และระบุชัดเจนว่าไม่ได้ตรวจด้านนั้น (ห้ามอ้างว่าระบบด้านนั้นผ่านแล้วหากไม่ได้รันจริง)

## การใช้งาน CLI

```bash
npm run agent:workflow -- --init work/task.md
npm run agent:workflow -- --status
npm run agent:workflow -- --summary
npm run agent:workflow -- --handoff work/audit.json
npm run agent:workflow -- --handoff work/plan.json
npm run agent:workflow -- --confirm work/confirmation.json
# ส่ง data, ui, performance, security ตามลำดับ
npm run agent:workflow -- --qa
npm run agent:workflow -- --handoff work/release.json
```

`--init` ต้องมี requirement file ที่ไม่ว่าง และไม่ทับ active run `--cancel` ยกเลิกงานปัจจุบัน ทุก run เก็บแยกใน work/agent-runs/<runId>/state.json และมี latest.json เป็น pointer ความเปลี่ยนแปลงกฎต้องเริ่ม run ใหม่ State v1 ที่เคย auto-pass ไม่ได้รับการยอมรับ

ตัวอย่าง handoff (ทุก stage ยกเว้น QA):

```json
{
  "runId": "<from --status>",
  "stage": "audit",
  "agent": "<actual agent identity>",
  "status": "passed",
  "skills": ["<skill actually read and used>"],
  "plugins": [],
  "summary": "<ผลที่ทำจริงและข้อจำกัด>",
  "evidence": ["work/audit-evidence.md"]
}
```

สถานะ handoff รองรับ passed/blocked/needs-rework ไฟล์หลักฐานต้องมีอยู่จริง อยู่ภายใน worktree และไม่ว่าง ระบบเก็บ hash และตรวจซ้ำก่อน QA แต่ไม่ได้พิสูจน์ความจริงของข้อความในหลักฐาน coordinator/reviewer ต้องตรวจเนื้อหาด้วย ทุก handoff ใหม่ล้างผล downstream และการแก้ audit/plan ล้าง confirmation

ตัวอย่าง confirmation ซึ่ง coordinator บันทึกจากคำยืนยันจริง ไม่ให้เอเจนต์แต่งคำยืนยัน:

```json
{
  "runId": "<runId>",
  "planSha256": "<stages.plan.evidence[0].sha256>",
  "source": "<conversation message reference>",
  "decision": "approved",
  "userMessage": "ยืนยัน"
}
```

CLI ตรวจการผูกกับ plan และหลักฐาน ไม่ใช่ระบบยืนยันตัวตนของผู้ใช้ คำอนุญาตให้ลงมือทันทีที่ครอบคลุม scope ใช้เป็น confirmation evidence ได้โดยอ้างข้อความจริง

## QA และการกู้คืน

--qa เรียกเฉพาะ verify-source, verify-schema, P301 DTO, npm test, qa, qa:audit, build ด้วย shell:false เก็บ full logs, exit code, signal และเวลา โดยจำกัดแต่ละ gate 15 นาที คำสั่งล้มเหลวส่ง nonzero exit และ blocked สั่ง --qa ซ้ำได้หลังแก้ปัญหา เก็บประวัติ attempt เดิม

QA ผ่านแล้วเป็น awaiting-review ไม่ใช่ completed ต้องมี release handoff จึง completed ซึ่งหมายถึง review จบ ไม่ใช่ deploy สำเร็จ การเผยแพร่ใช้ขั้นตอน GitHub/Supabase เดิมและรายงานแยกกัน

มี lock ป้องกันการแก้ state พร้อมกัน ถ้า process ถูก kill และทิ้ง .lock ให้ตรวจว่าไม่มี runner ทำงานอยู่ก่อนลบ lock ด้วยตนเอง Logs อาจมีข้อมูลจาก test ให้เก็บใน work/ ที่ถูก gitignore และตรวจข้อมูลอ่อนไหวก่อนแชร์
