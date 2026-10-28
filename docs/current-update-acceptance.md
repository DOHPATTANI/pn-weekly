# รอบปรับปรุงที่ได้รับอนุญาต 2026-10-28

โหมด productize; ผู้ใช้อนุญาตให้ทำครบและเผยแพร่โดยไม่ถามซ้ำ ใช้ข้อมูลจริง ไม่เปลี่ยน authentication และไม่ล้างข้อมูล

## แผนและความเสี่ยง

ตรวจ owner จาก src/manifest.json: data-rules → executive-reports/image-export → operations/registry-dialogs; dashboard-selectors เป็นเจ้าของ dashboard view model ส่วน cascade เป็น presentation เท่านั้น

แก้ business correctness ก่อน UI: สีรายงาน, สถานะทรัพย์สิน, chain ขยายสัญญา, pagination และ filename จากนั้นปรับ controls/help/studio และ OCR แบบเสนอค่าก่อนบันทึก ตรวจ focused tests ก่อน integrated gates และเผยแพร่เฉพาะ revision ที่ผ่าน ตรวจเว็บจริงหลัง deploy

ความเสี่ยงหลักคือ legacy extension dates, การแบ่งหน้าลายเซ็น และข้อมูลแนบ OCR ต้องไม่ยืนยันค่าหรือเขียนฐานข้อมูลอัตโนมัติ Rollback ใช้ revert release commit ไม่แตะข้อมูลจริง

| Requirement | Source | Implementation area | Acceptance criteria | Validation |
|---|---|---|---|---|
| สีดำ/เขียว/น้ำเงิน/แดง | คำสั่งล่าสุด | report HTML/XLSX/image | ongoing ไม่ติดสีเขียว; paid แดง | Pending |
| สถานะทรัพย์สิน 4 แบบ | บทสนทนาที่อนุมัติ | P301 selector/UI | confirmed saved แสดงจัดทำแล้วและกรองได้ | Pending |
| ลายเซ็นและ metadata | บทสนทนาที่อนุมัติ | P301 vector/XLSX | ช่องตรงกันและลายเซ็นไม่ล้นหน้า | Pending |
| ขยาย/ลดสัญญา | บทสนทนาที่อนุมัติ | registry/data-rules | แก้/ลบคำนวณ chain ใหม่ ไม่ซ้ำ legacy | Pending |
| อ่านภาพ/PDF | บทสนทนาที่อนุมัติ | extension attachment | เสนอค่าให้ยืนยันก่อนบันทึก | Pending |
| filename ทุก export | บทสนทนาที่อนุมัติ | export owners | ชื่อรายการและเวลาไทย รวม ZIP | Pending |
| UX ทุกหน้า/help/scope | คำสั่งและ mockup | shell/controls/CSS | grouping ชัด ใช้ scope เดียว มือถือไม่ล้น | Pending |
| Dashboard | HTML อ้างอิง | selectors/renderers | live data และตรวจภาพกับ reference | Pending |
| เผยแพร่พร้อมใช้งาน | คำสั่งล่าสุด | CI/Pages | gates ผ่านและ production smoke ผ่าน | Pending |

ยังไม่ถือว่า Pending ผ่าน ไม่มีการยืนยัน pixel match จากภาพสร้างด้วย AI หรือจาก build อย่างเดียว
