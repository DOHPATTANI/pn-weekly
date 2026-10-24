# PN Weekly agent workflow

อ่าน Rules.md → AGENTS.md → docs/DEVELOPMENT-WORKFLOW.md ก่อนเริ่ม เอเจนต์จริงรับงานจาก Codex coordinator ผ่านเครื่องมือ delegation ที่มีใน session ส่วน CLI นี้ตรวจหลักฐาน handoff และเรียก QA commands เท่านั้น ไม่เรียกโมเดลหรือทำงานเบื้องหลังเมื่อปิด session

## บทบาทและลำดับ

| Stage | หน้าที่ | สกิล/ปลั๊กอินที่พิจารณาเมื่อเกี่ยวข้อง |
|---|---|---|
| audit | ตรวจ rules, repo และ root cause | full-stack-integrity / code analysis ที่มี |
| plan | Facts/Assumptions/Unknowns, scope, แผนและเกณฑ์ตรวจรับ | สกิลโดเมนของงาน |
| confirmation | บันทึกคำยืนยันผู้ใช้ที่ผูกกับแผน | coordinator บันทึกข้อความจริง |
| data | DB/API/data contract หรือระบุไม่เกี่ยวข้องพร้อมเหตุผล | supabase / postgres best practices |
| ui | Implementation และ UX ตาม scope หรือเหตุผลที่ไม่เกี่ยวข้อง | frontend-design-premium / impeccable |
| performance | ตรวจผลกระทบและข้อจำกัดการวัด | เครื่องมือ profiling ที่เหมาะกับ stack |
| security | ตรวจความเสี่ยงจาก diff | สกิล security ตามพื้นที่ที่แก้ |
| qa | รัน CI gates เดิมและเก็บ logs | web-qa-release |
| release | ตรวจผลจริง ข้อจำกัด และ decision log | verification/release skills ที่มี |

ห้ามใช้สกิลผิด stack หรือระบุว่าใช้เพียงเพราะอยู่ในตาราง หากบทบาทไม่เกี่ยวข้องให้แนบ rationale เป็น evidence และบอกว่าไม่ได้ตรวจด้านนั้น อย่าอ้างว่าระบบทั้งด้านผ่านแล้ว

## ใช้งาน

```bash
npm run agent:workflow -- --init work/task.md
npm run agent:workflow -- --status
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
