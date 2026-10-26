# PLANNET DOH — Global UI Layout Standards v27.3

สถานะ: มาตรฐานกลางสำหรับหน้าปฏิบัติการและ Dashboard

## ขอบเขตและเจ้าของ

มาตรฐานนี้ใช้กับหน้า Dashboard, อัปเดตรายสัปดาห์, ทะเบียนสัญญา, ทะเบียนคุมทรัพย์สิน, ข้อมูลพื้นฐาน, คลังรายงาน, ตรวจสอบ, ประวัติ และตั้งค่าระบบ โดยใช้ Vanilla JS และ CSS tokens เดิมของระบบ

ห้ามใช้มาตรฐานนี้เปลี่ยน `.main-report` หรือ `.p301-accessible` และห้ามให้ UI renderer คำนวณข้อมูลธุรกิจเอง ตัวเลขและรายการต้องมาจาก View Model ที่สร้างใน `src/dashboard-selectors.js` หรือ selector/service canonical ของหน้านั้น

## Layout blueprint

```html
<main class="page-shell" data-page="..."><header class="page-header">
  <div class="page-heading"><nav class="breadcrumb">...</nav><h1 class="ptitle">ชื่อหน้า</h1></div>
  <div class="page-actions"><div class="toolbar-secondary">...</div>
    <button class="btn primary" data-action="primary-action">ปุ่มหลัก</button>
  </div>
</header><section class="page-filter-bar">...
</section><section class="page-summary">...</section><section class="page-content">...</section></main>
```

หน้าที่มี shell เดิมสามารถใช้ `operational-dock`, `page-primary-actions`, `period-bar`, `advanced-filter-menu` และ `table-density` เป็น canonical owners ได้ ไม่สร้าง toolbar หน้าจอใหม่ซ้ำ

## Action toolbar

- Primary action อยู่ด้านขวาบนและมีชื่อกริยาที่ชัดเจน
- Secondary actions อยู่ในแถบเดียวกันหรือเมนู “เครื่องมือเพิ่มเติม”
- ระหว่าง async action ให้คงขนาดปุ่มเดิมและตั้ง `data-loading="true"` กับ `aria-busy="true"`
- ปุ่ม icon-only ต้องมี `aria-label`, focus state และ target อย่างน้อย 44px
- การจัดการแถวและการลบจะแสดงเมื่อเข้าโหมดจัดการ ไม่แสดงตลอดเวลา

## Filter and search

- Filter หลักเรียงตามขอบเขตข้อมูล: กลุ่มงบ → ปี → สัปดาห์/ประเภท → สถานะ
- Search อยู่ใน toolbar เดียวกันหรือเหนือหัวตาราง พร้อมปุ่มล้างค่า
- Filter รองอยู่ใน `details.advanced-filter-menu` และแสดงค่าที่ใช้งานเป็น chips
- Search เป็น local View Model filtering; ไม่เขียนฐานข้อมูล และ reset/clamp pagination เมื่อเงื่อนไขเปลี่ยน
- บนมือถือให้เรียงเป็นสองแถวหรือ disclosure โดยไม่สร้างแผงแนวตั้งยาวด้านข้าง

## Overlay and z-index

ใช้ CSS custom properties เดียวกันทั้งระบบ ห้ามใช้ตัวเลขสุ่ม:

| Layer | Token | Value |
|---|---|---:|
| Base | `--z-base` | 0 |
| Sticky toolbar | `--z-sticky` | 80 |
| Dropdown | `--z-dropdown` | 100 |
| Submenu | `--z-dropdown-submenu` | 120 |
| Popover/tooltip | `--z-popover` | 130 |
| Navigation | `--z-navigation` | 300 |
| Modal backdrop | `--z-modal-backdrop` | 1490 |
| Modal | `--z-modal` | 1500 |
| Toast | `--z-toast` | 1600 |
| Guided tour | `--z-tour` | 1700 |

Dropdown/popover ต้องปิดด้วย click-outside และ Escape ไม่ถูก clip โดย `overflow:hidden` และต้องรักษา focus ที่คาดเดาได้

## Responsive rules

- ≤640px: ตารางปฏิบัติการทั่วไปใช้ labeled cards
- Dashboard `.dash-v25-clean-table` และตารางรายงานราชการคง multi-column table พร้อม scroll เฉพาะ table
- ห้ามใช้ `transform: scale()` กับทั้งหน้า
- ต้องตรวจ 320, 375, 390, 430, 640, 768, 1024, 1280 และ 1440px

## View Model mapping

| UI | Source |
|---|---|
| Dashboard KPI/hero | `selectDashboardViewModel` และ `latestScopeReport()` |
| Status pipeline | dashboard selector จาก live report entries |
| Budget progress | selector จัดกลุ่ม `budgetAccount` |
| Work-type donut | selector จัดกลุ่ม `workTypeId` |
| ตาราง/จำนวน filter | selector ของหน้านั้น หลัง local filter |

ห้ามใส่ fallback ตัวเลขธุรกิจ, multiplier, mock rows หรือคำนวณยอดเงินใน template

## Migration checklist

- [ ] ทุกหน้ามี page title และ primary action ในตำแหน่งเดียวกัน
- [ ] ปุ่มรองรวมใน toolbar/disclosure เดียว
- [ ] ตัวกรองหลักแนวนอนและ filter รองพับได้
- [ ] Search มี label, clear button และรองรับ IME/keyboard
- [ ] Dropdown ใช้ z-index token และปิดด้วย Escape/click-outside
- [ ] Loading ใช้ `aria-busy`/`data-loading` โดยไม่ทำให้ layout กระโดด
- [ ] ตารางมี loading, empty, no-results, error และ pagination state
- [ ] ตรวจ reduced motion, focus, contrast และ touch target
- [ ] ตรวจว่า `.main-report` และ `.p301-accessible` ไม่เปลี่ยน
- [ ] รัน source consistency, unit, QA, audit, schema และ build
