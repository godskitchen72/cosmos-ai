# Cosmos Medical Technologies — HANDOVER (June 28, 2026, session 2)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed via `tsc --noEmit` +
full deploy chain. Live app confirmed healthy at session close.

---

## Completed This Session

### P1 cleared: Save→View deploy confirmed

`git log --oneline` confirmed both Save→View commits (`c68d705`,
`8716f2d`) present and on `origin/main`. This item is permanently closed.

### VNG v5 verified (P2)

End-to-end human visual review of real VNG v5 generated PDF completed and
confirmed. Item closed.

### Admin dashboard — complete rebuild and expansion

The Admin page received the largest single-session expansion in project
history. Commits in order:

**Overview tab** (new — was missing):
- 6 KPI cards (2×3 grid): Total Providers (real), Documents (real, from
  `patient_forms` count), Total Patients (real), Total Visits (real),
  Office Locations (real, from new `office_locations` table), Active Users
  (placeholder — requires future users table)
- Quick Access shortcuts: Providers, Carriers, Lawyers, CPT Codes, Dev Tools
- Practice Info card: inline edit, saves to new `practice_settings` table
  (NF-3 ready: `practice_name`, `corp_name`, `tax_id`, `tax_classification`,
  `street`, `city`, `state`, `zip`, `phone`, `fax`)
- Office Locations manage UI: list with Add/Delete, inline add form — fully
  functional, saves to `office_locations` table
- Recent Providers list: last 5 doctors by `created_at DESC`, shows
  license_type badge (color-coded), specialty, supervisor name, date added
- Quick Access moved to top of Overview (action-first layout)

**CPT Codes tab** (new):
- Full CRUD: add/edit/delete CPT codes
- Filter strip by provider type (All, General, MD, DC, PT, etc.)
- Grouped by `provider_type` with code badge, description, fee display
- CSV import: uploads a specialty-specific CSV, parses client-side,
  previews before commit, upserts into `cpt_codes` on `cpt_code` conflict,
  simultaneously imports paired ICD-10 codes into `icd10_codes`
- Provider type selector on import modal

**ICD-10 tab** (new):
- Full CRUD: add/edit/delete ICD-10 codes
- Search bar (filters code, description, category)
- Grouped by `category`, green code badges
- CSV import (same pattern as CPT — independent ICD-10-only import)
- `clinical_note_template` field exposed in edit form

**Providers tab improvements**:
- Add Provider button moved to top
- Edit form auto-scrolls into view (`useRef` + `scrollIntoView`) on open
- Edit form renders above list (list scrolls into view after cancel/save)
- Schedule tab extended with **Location Assignments** sub-section:
  - Existing Available Days + Max Patients renamed to "Default Schedule"
    (fallback when no location assigned)
  - Assign Location button → picks from `office_locations`, sets per-location
    days/start_time/end_time/slot_minutes/capacity
  - Writes to `doctor_locations` junction table (upsert on doctor+location)
  - Remove button per assignment
  - Gracefully shows "Add locations in Overview tab first" when none exist

**Carriers/Lawyers tab improvements**:
- Add Carrier / Add Lawyer buttons moved to top
- Lists now render below the edit form

**Admin-wide**:
- Scrollable tab strip (`overflow-x-auto`, `shrink-0` per tab) — 6 tabs fit
- Header subtitle changed from "Manage Lookup Tables" to "Table Management"
- Cyan borders (`border-[#00cfff30]`) on all list item cards throughout
- Cyan borders on Edit buttons, red-tinted borders on Del buttons

### New Supabase tables (all deployed with full anon RLS policies)

| Table | Migration | Purpose |
|---|---|---|
| `practice_settings` | `010_add_practice_settings_and_office_locations.sql` | Single-row practice entity info (NF-3 ready) |
| `office_locations` | `010_add_practice_settings_and_office_locations.sql` | Physical office locations |
| `doctor_locations` | `011_add_doctor_locations_and_appointment_location.sql` | Doctor ↔ location junction with per-location schedule |

Also: `location_id uuid REFERENCES office_locations(id)` added to
`appointments` table. Unique constraints added: `cpt_codes(cpt_code)`,
`icd10_codes(code)` — required for CSV import upsert.

RLS confirmed on: `cpt_codes` (4 policies), `icd10_codes` (5 policies —
pre-existing "Allow all" + 4 new granular anon policies), `doctor_locations`
(4 policies), `practice_settings` (4 policies), `office_locations` (4 policies).

### Scheduling — Phase 1+2 complete

**What was discovered**: scheduling is already substantially built in
`app/calendar/page.tsx` — week/month views, doctor selector, quick-pick
chips, full appointment lifecycle (Scheduled → Confirmed → Checked In →
Completed / No-Show / Cancelled), capacity tracking per day, FD "Needs
Appointment" queue with Book→ deep link.

**Phase 1** (schema): `doctor_locations` table + `appointments.location_id`
column added. RLS complete.

**Phase 2** (Admin UI): Doctor Location Assignment in Schedule tab — done
(described above).

**Phase 3** (calendar location selector): NOT YET BUILT. Calendar still
reads `doctors.available_days` and `doctors.max_patients_per_day` —
location-aware capacity/availability fallback logic not yet wired.

**Phase 4** (MD login location picker): NOT YET BUILT. MD role select
should prompt "Which office today?" and store selection in sessionStorage
to pre-filter calendar and pre-populate visit service location.

---

## Open Items, Priority Order

1. **NF-3 PC-payee mapping** — verify in a real generated PDF. Never
   confirmed across all sessions.
2. **Scheduling Phase 3** — calendar location selector. FD selects doctor
   → location selector appears (filtered to `doctor_locations` for that
   doctor) → capacity/available days read from `doctor_locations` instead
   of `doctors` fallback → booking form adds Location field → appointment
   record stores `location_id`. Calendar `app/calendar/page.tsx` is the
   target file.
3. **Scheduling Phase 4** — MD login location picker. After role select,
   MD sees "Which office today?" → selected location stored in
   sessionStorage → passed as URL param to calendar → calendar pre-filters
   to that location.
4. **Appointment → Visit conversion** — when FD marks appointment
   "Checked In", a visit record should be creatable from that appointment
   (pre-populated with patient, doctor, location, date). Currently manual.
5. **NF-3 Pay-To: supervisor PC logic** — `forms/nf3.py` reads treating
   doctor's own PC; should fall through to supervisor's PC when set.
   Deliberately deferred multiple sessions.
6. **Practice Info → NF-3 wiring** — `practice_settings` table now exists
   and is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.
7. **Regenerate W-9s for existing doctors** — no bulk path exists
   (`PRODUCT_SPEC.md` §5). Low urgency.
8. **`forms/base.py` `except Exception: pass`** in
   `render_visible_text_in_rect` — prohibited by `SYSTEM_PROMPT.md` §1/§8.
   Flagged 3+ sessions, never fixed.
9. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 2 sessions, never removed.
10. **RLS hardening** — `patient_forms` RLS disabled entirely;
    `storage.objects` has one fully-open policy on `patient-forms` bucket.
    Not causing bugs, still un-hardened.
11. **MRI Extremity Studies + insurance fields** — backend ready, pure
    frontend work, never started.
12. **`patient_visits` doctor linkage gap** — `doctor_id` not reliably
    written at save time. Prerequisite for `cpt_codes.provider_type`
    validation use case.
13. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
    `ANS.pdf`, `DME.pdf` etc. uppercase. Cosmetic; resolve before next
    new template.
14. **Desktop sidebar nav** — mockup confirmed target. Mobile-first
    remains immediate priority; sidebar is future work.
15. **`cpt_codes.provider_type` backend wiring** — column exists, unused
    on both frontend and backend. CPT tab now has full CRUD with
    provider_type, but the backend billing path never reads it.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (multiple commits this session — full Overview, CPT, ICD-10, Providers, Carriers, Lawyers expansion; live screenshots confirmed) |
| `cosmos-dashboard/app/calendar/page.tsx` | Obtained-current (read in full this session; not modified — Phase 3 is the next touch) |
| `cosmos-dashboard/app/dev/page.tsx` | Obtained-current (read in full this session; already on Oxanium — no changes needed) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (prior session — Admin role tile promoted) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session — buried Admin button removed) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session — supervised query) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (prior session — supervised toggle + badge) |
| `cosmos-dashboard/lib/fonts.ts` | Obtained-current (read this session — all weights 300–800 loaded; oxanium.className controls weight, not the export) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/main.py`, `pdf_engine.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed — rest of each file never seen in full |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained, any session |

---

## Architecture Corrections (this session, `ARCHITECTURE.md` updated)

- **New tables**: `practice_settings`, `office_locations`, `doctor_locations`
  added to live database. See §3 migration history.
- **`appointments` table**: `location_id uuid REFERENCES office_locations(id)`
  column added.
- **`cpt_codes`**: unique constraint added on `cpt_code`. RLS now complete
  (was missing all 4 anon policies — silent read failure was the root cause
  of the CPT tab showing empty on first deploy).
- **`icd10_codes`**: unique constraint added on `code`. Had pre-existing
  "Allow all" policy; 4 granular anon policies added alongside it.
- **Scheduling architecture**: `doctor_locations` junction table is the
  per-location schedule source of truth. `doctors.available_days` and
  `doctors.max_patients_per_day` remain as fallback defaults (used by
  calendar when no `doctor_locations` rows exist for a doctor).

---

## Lessons Learned This Session

- **Missing RLS policies cause silent empty results** — `cpt_codes` had
  RLS enabled but zero anon policies; the CPT tab returned `[]` with no
  error. Always run the RLS audit query after creating a new table and
  before testing its frontend. The pattern is now consistent: `CREATE TABLE`
  → immediately `CREATE POLICY` × 4 → verify row count in SQL Editor.
- **Always unique-constraint before upsert** — the CSV import's
  `.upsert(..., { onConflict: 'cpt_code' })` would silently insert
  duplicates without the unique constraint. Added the constraint in the
  same migration that enabled the upsert path.
- **`React.useRef` vs `useRef`** — this project imports hooks directly
  (`import { useState, useEffect } from 'react'`), not via `React.*`.
  Always use the destructured form in patches.
- **Patch script anchor failures due to section comment separators** —
  `// ─── SECTION ───` comment blocks between functions affect close-block
  anchors. When a function's closing `}` is followed by one of these
  comments, the anchor must include the full comment string verbatim.
  Use `grep -n "function.*Section"` to find the exact separator text
  before writing close-block anchors.
