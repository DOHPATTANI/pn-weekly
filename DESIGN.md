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
