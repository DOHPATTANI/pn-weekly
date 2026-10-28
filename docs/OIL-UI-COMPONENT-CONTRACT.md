# Weekly operations — preserved interaction contract

ตรวจ source ก่อนปรับ presentation: src/operations.js, src/data-rules.js, src/sidebar.js และ src/manifest.json การสำรวจสามแบบอยู่ใน design-preview/ เท่านั้น ไม่เปลี่ยนเจ้าของ state, business rules หรือ production handlers

## State ที่เกี่ยวข้อง

- Workspace/navigation: state, view, funding, year, selected, cloudMode, busy, connectionError, storageWarning
- Query/filter/pagination: filter, query, category, page, filterUnconfirmed, budgetFilter, weeklySort, tableSorts, filterDisclosures, operationalAdvancedFilters, operationalMenuState; page size ผ่าน tableSize/setTableSize
- Draft/write lifecycle: editDrafts, mutationTail, pendingWrites, lastSavedAt, outbox, syncing, syncError, outboxConflict, scopeLoading, scopeRequest, scopePending, activeRowsCache
- Interaction/layout: weeklyReturn, searchTimer, listSearchTimer, searchGeneration, operationalDock, headerMirror, layoutFrame, operationalResizeObserver; batch mode ใช้ localStorage key เดิม

## Data inputs / props

Vanilla functions ไม่ใช่ React props: projectTable(rows,weekly=false,dash=false), periodBar(showWeek=true), weeklySummary(rows), report(), activeRows(), state.settings, state.fundingSources, state.years, state.workTypes, state.contractRegistry, state.projects, state.reports

แต่ละ row ใช้ {p,e}; p คือข้อมูลสัญญา e คือ entry ของรายงาน (plan,weekly,actual,note,payment,confirmed และวันที่ที่เกี่ยวข้อง) ใช้ snapshot/projectAt/previousEntry เดิม ห้ามนำข้อมูลตัวอย่างมาทับ

## Events และ canonical handlers

| Trigger | Owner / behavior ที่ต้องคง |
|---|---|
| funding/year change | bind → ensureScope → ensureFirstWeekly → render; reset filters เดิม |
| report-select change | selected → ensureScope(selected) → render |
| search input/compositionend/clear | bindListSearches, bindClearSearches; local matching, focus, pagination reset |
| status/budget/category/unconfirmed | bind; filter, budgetFilter, category, filterUnconfirmed และ render |
| filter disclosure / advanced filters | disclosureFilters, mountAdvancedFilters; aria-expanded, remembered disclosure |
| sort/page/page-size | sortHead/tableSorts, data-page, setTableSize; clamp/reset เดิม |
| row details/navigation | data-linked-contract, registryDetailDialog, projectDialog, weeklyReturn |
| inline click/doubleclick/F2/Enter/Escape/blur | bindInlineEntries; unlock/cancel/restore โดยไม่เปลี่ยนค่าค้าง |
| entry input/change | bindWeeklyEntryInputs → editDrafts/persistEdits → submitWeeklyEdit หรือ batch draft; applyWeeklyAutoRules เดิม |
| batch toggle/save | weekly-batch-toggle, saveAllWeeklyDrafts(selected), withButtonLock |
| retry/discard drafts | retry-edits, discard-edits, confirmAction; preserve safe recovery |
| bulk selection/confirm | mountSelections, confirmWeeklySelection; selection scope เดิม |
| primary/secondary action click | data-action → actions mapping ผ่าน withButtonLock; preview/new-report/lock/export เดิม |
| form submit | modal callback, validation, mutate/saveAmendment เดิม; ไม่เพิ่ม onSubmit ใหม่แทน owner |
| archive review | weeklyArchiveDialog; confirmed แยกจาก locked เสมอ |
| shortcuts | / ค้นหา, Ctrl/Cmd+S บันทึก batch, Escape ปิด/cancel ตาม owner |

## Core functions ที่ห้ามเปลี่ยนในงานออกแบบนี้

report, rowsFor/activeRows, previousEntry, applyWeeklyAutoRules, validateEntry, validateDates, submitWeeklyEdit, saveAllWeeklyDrafts, saveAmendment, mutate, synchronizeReport, ensureScope, weeklyArchiveDialog, confirmWeeklySelection และ export/report model เดิมทั้งหมด

## Layout exploration

1. ห้องปฏิบัติงานทาง: Sidebar เต็ม → scope/commands → สรุป → ตาราง เหมาะผู้เริ่มต้น
2. โต๊ะทะเบียนดิจิทัล: เมนูแนวนอน → scope → แถบสรุป → ตารางเต็มความกว้าง เหมาะอ่านข้อมูลหลายคอลัมน์
3. ศูนย์ตรวจรายงาน: rail → scope → ตารางคู่แผงสถานะ เหมาะตรวจงานพร้อมภาพรวม ต้องระวังความกว้างตาราง

Gestalt: proximity รวมคำสั่งที่ทำกับวัตถุเดียวกัน; common region หนึ่งกรอบต่อกลุ่มงาน; similarity ใช้ controls เดียวกัน; hierarchy ให้ตารางเป็น主เนื้อหาและคำสั่งตรวจรายงานเป็น primary โดยไม่ลบคำสั่งรอง

พรีวิวโหลดแอปเดิมใน iframe และเพิ่ม CSS เฉพาะ frame; network write guard เป็นขอบเขตความปลอดภัยของพรีวิว ไม่ใช่ production handler ใหม่ การสำรวจนี้ยังไม่ใช่การยืนยัน full functional parity และไม่ควรทดสอบบันทึกธุรกิจในหน้าเปรียบเทียบ
