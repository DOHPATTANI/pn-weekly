---
version: alpha
name: "PN Weekly"
description: "Thai highway weekly contract reporting, quiet operational archive"
colors:
  primary: "#145d47"
  text: "#142e29"
  muted: "#50665e"
  background: "#f6f8f6"
  surface: "#ffffff"
  border: "#cddbd4"
  delivery: "#177245"
  payment: "#1455aa"
  paid: "#e22222"
typography:
  sans:
    fontFamily: "Noto Sans Thai, Tahoma, sans-serif"
  utility:
    fontFamily: "Tahoma, sans-serif"
rounded:
  DEFAULT: "8px"
  panel: "12px"
spacing:
  page: "38px"
  phone: "14px"
components:
  archive:
    pageSize: 10
  button:
    borderRadius: "8px"
---

# PN Weekly design and behavior contract

## Overview

Product/admin surface for one Thai highway officer preparing weekly management reports. Preserve the existing green/white identity. The report itself follows the supplied institutional table. The archive is a chronological register rather than a dashboard of cards. Avoid repeated actions, decorative tiles and unnecessary status columns.

Authoritative business decisions are the user's requests in this chat and the installation/user manual. The user explicitly chose one shared workspace without login and direct historical editing without reason or extra confirmation. Older v3 immutable-history behavior is superseded through the audited amendment workflow; silent wholesale overwriting is still rejected.

## Colors

Runtime CSS in styles.css is canonical. This document records the existing variables: primary --green, text --ink, muted --muted, background --bg, border --line; website lifecycle colors --delivery-ink and --payment-ink. Paid red is retained in webpage and exported rows. Green awaiting-delivery and blue awaiting-payment are scoped to #app. Exported detail rows otherwise stay black. Summary colors follow the source report. Status text accompanies colors.

## Typography

Thai locale, Bangkok business timezone, Buddhist years in display, Gregorian YYYY-MM-DD for storage. Native date/select/datalist popups are intentionally platform-owned. Tahoma is the deterministic offline fallback. No Japan-market behavior applies. Archive cells are 14px with 1.6 line-height; labels use 12px. Report fonts remain smaller to fit A4 landscape.

## Layout

Desktop sidebar + document-scrolling content. Archive: group/year filters, local search, five-column native table, latest end date first, ten rows per page. Mobile below 700px transforms each row into a vertical record with the same single Open action. Table owns horizontal overflow; the page must not overflow horizontally. Loading/error feedback must not move primary controls.

## Elevation & Depth

Keep white bordered panels, small radius and restrained existing dialog elevation. No new shadows or hero graphics. Uploaded PNG logo uses a white, borderless container; transparent pixels stay transparent.

## Shapes

Reuse existing .btn, .card, .field, .pill and native dialog. Preserve keyboard focus rings and operable scrollbars. Respect reduced-motion preferences.

## Components

### Canonical UI Map and UX contract

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Select/Listbox | selectField + native select / native datalist | DESIGN.md + runtime owner | platform-owned; search/create is datalist plus semantic button | Chrome create/select flow, DOM relation test |
| Date | field(type=date), validateDates | DESIGN.md + runtime owner | native browser calendar, date-only storage | DOM/DB lifecycle ordering and Chrome fill/save |
| Form | field/selectField, modal, showFormError | DESIGN.md + runtime owner | create/edit/history amendment | required/range checks, inline errors, duplicate-submit disable |
| Scrollbar | styles.css global baseline | DESIGN.md + runtime owner | responsive archive geometry | Chrome desktop/mobile inspection |
| Toast | toast + #toast role=status | DESIGN.md + runtime owner | success/error | DOM and browser live status |
| CRUD | mutate, catalogUI, saveAmendment | DESIGN.md + runtime owner | standard save vs audited historical save | actual PostgreSQL + DOM + Chrome |

Table Selection is not part of the archive: there are no bulk-selection checkboxes. Weekly confirmation checkboxes are a business review state, not a grid selection model.

### Shared interactions

Create/edit uses the same app dialog and save/cancel controls. Form errors preserve values. Historical editing is staged until Save, with no reason and no secondary confirmation. Contract choice is disabled after editing begins so a switch cannot silently discard input. Cancel intentionally discards that dialog's edits. Standard weekly input continues to autosave. Revision conflicts preserve entered values and require loading the latest version.

Search filters the already loaded workspace locally. Archive search is transient and non-shareable; group/year are remembered in localStorage because this is a single-person application rather than a shareable list URL. Reset/clamp pagination when filtering. Empty state explains how to recover. Add buttons appear only for a non-empty exact name not already in the master list; successful create keeps the contract form open and selects the new name.

### Historical data

pn2_amend_report accepts only entry-field patches, preserves contract snapshots and report identity, records before/after automatically, and updates the amended indicator. Changing historical cumulative actual preserves later cumulative figures and recomputes their weekly increment; reject negative increments rather than guessing. Delivery and acceptance dates are independent optional fields retained when payment status changes. Awaiting delivery/payment tabs only count completed work; ongoing is separate.

## Do's and Don'ts

- Keep one Open action on archive rows; edit/export is inside the report.
- Keep report titles separate by funding source and fiscal year derived from contract selection.
- Do not put internal IDs into executive exports.
- Do not introduce login, new approval gates or mandatory amendment reasons.
- Do not merge data-import JSON into GitHub package.json: they have separate destinations.
- Use installed skills/plugins when applicable; do not invoke unrelated plugins just because available.

## Verification and legacy migration

The maintained verification evidence is in the consolidated manual. Static premium audit supplements runtime tests; it does not replace them. The published code is one app.js assembled by section; tools.mjs owns test/build/serve. No runtime npm dependency or real contract data is bundled. Previous separate JS modules and separate workflows are retired when replacing the repository contents with this release.

## Registry import contract — v5

The user's approved mapping is PO -> contract value, payment-group Total Project -> actual construction cost. Missing is not zero. Contractor source names stay pending in registry records and never create contractor masters automatically. CSV schema is defined once by registryColumns in app.js and used for both import/export. XLSX conversion reads cached values and Thai dates, never evaluates workbook instructions.

Registry records are separate from projects/reports so imports and overwrites cannot change weekly report detail, entries or snapshots. Duplicate identity is funding/year/normalized contract; displayed text remains original. Preview makes missing fields and duplicates explicit and defaults to skipping duplicates. Invalid rows can be skipped, not fabricated. Type is manually assigned to code/title relationships. Dates fall back to matching weekly data only when absent. The CSV import, source converter and pending-contractor match use the existing modal, validation, select, file input and toast owners.

## Linked contract registry — v6, supersedes the v5 isolation at report creation

Preserve the established green/white Operate identity and shared modal/field/toast/CRUD owners. Registry is the current contract source; pn2_contracts is the report projection with registry_id and registry.project_id. Imports still do not rewrite existing weekly entries/snapshots. A new report materializes registry rows for its exact funding/year and carries prior progress; opening a previously unreported group/year automatically creates week1 with all three progress values0. Blank source contractor IDs remain pending even when projected and never create masters automatically.

Budget/code/job names are master records, with work_name_codes supporting the same job name under multiple codes. Work type -> code -> job selection is searchable; code with one linked job prefills title, which remains editable. Create/edit use one registry form. All deletions require shared confirmAction. Referenced contracts are removed from active registry/future weeks via archived flag; historical snapshots/FKs remain. Unreferenced contracts can be physically deleted. Replacing group/year on a previously reported contract is rejected.

Registry table has consistent SVG view/edit/delete icons, row Enter/Space opens full detail, action clicks do not bubble to row. Shared native dialog owns top Close, Escape, and backdrop hit test. Sort headers report aria-sort and use Thai natural text/numeric values, blanks last. Registry group/year controls contain no week selector. Summary strips sit outside table panels and filter budget/status lists; no duplicate status tabs. Mobile keeps summary2-column and table overflow inside its scroll owner. HeaderClose is sticky in long dialogs. Dates are edited in a contract dialog and never occupy weekly table date columns. Lifecycle amendments sync only the date keys actually patched, leaving frozen snapshots untouched.

Verification: tools.mjs test25 cases, work/v6-tests.mjs PGlite upgrade/FKs/amend/delete, work/v6-browser.cjs Chrome desktop1440x1000/phone390x844. Browser plugin absent: installed Playwright+systemChrome fallback. Detector advisories mainly flag existing palette literals and legacy dashboard Arial; preserve incumbent identity for this scoped feature. Print export palette/layout remain unchanged.

## v7 production decisions

Preserve Operate identity. Summary uses blue/all, amber/ongoing, green/delivery, blue/payment and red/paid tinted surfaces with explicit text and a selected outline; registry accounts use matching distinct tints. Responsive totals full row + remaining2-column on phone. New report font TH SarabunPSK is the user's exact bundled THSarabun.ttf: HTML/PDF/canvas use @font-face and wait for it; XLSX names the font and requires local installation. Contract display strips only leading Thai PN prefix; header is ปน. Canonical report values own all three export formats. Print thead explicitly avoids breaks for repeatable headers.

Master codes have a type prefix+6digits, hidden from UI, stored as code without replacing legacy PK/FK. Counters persist in workspace and are not recycled. CSV owner is masterCSV/previewMasterCSV/applyMasterCSV; preserve omitted metadata, skip duplicates by default, keep reference IDs on overwrite. Catalog uses existing shared CRUD/dialog/confirm/field owners, semantic SVG icon actions and25-row pagination.

Only latest draft week can edit period or cancel:7-dayTue–Mon, start after other report periods for same funding/year, cumulative preserved and weekly recalculated, confirmations reset. Closed history keeps snapshots and uses existing audited progress amendment. Settings has no URL/key fields; DEFAULT_CONFIG in app.js contains supplied anon config, connects automatically, no login. Cloud review does not imply live deployment. QA:30 unit tests, embedded PostgreSQL, realChrome desktop/phone,2-page printed PDF with embeddedfont, actualXLSX/JPG generated by UI.
