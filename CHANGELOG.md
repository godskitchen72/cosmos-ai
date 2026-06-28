# Changelog

## 2026-06-28 — Admin dashboard expansion: Overview, CPT/ICD-10 tables, Locations, Scheduling Phase 1+2

### Admin — Overview tab (new)
- 6 KPI cards (2×3): Total Providers, Documents, Total Patients, Total Visits,
  Office Locations (all real/live), Active Users (placeholder)
- Quick Access shortcuts (Providers, Carriers, Lawyers, CPT Codes, Dev Tools)
  moved to top of Overview — action-first layout
- Practice Info card: inline edit, saves to new `practice_settings` table
  (NF-3-ready fields: practice name, corp name, TIN, tax classification,
  address, phone, fax)
- Office Locations manage UI: add/delete locations inline, saved to
  `office_locations` table, displayed as list with full address
- Recent Providers list: last 5 by date added, license_type badge
  (color-coded per discipline), specialty, supervisor name

### Admin — CPT Codes tab (new)
- Full CRUD for `cpt_codes` table
- Filter by provider type (All / General / MD / DC / PT / Acupuncturist /
  Psychologist / Podiatrist)
- Grouped display by `provider_type`
- CSV import: client-side parse, preview modal with provider type selector,
  upserts into `cpt_codes` + simultaneously imports paired ICD-10 codes

### Admin — ICD-10 tab (new)
- Full CRUD for `icd10_codes` table
- Search across code, description, category
- Grouped by `category`, CSV import (ICD-10-only variant)

### Admin — Providers tab improvements
- Add Provider moved to top
- Edit form auto-scrolls into view; renders above provider list
- Schedule tab: "Default Schedule" label added; new Location Assignments
  sub-section — assign doctor to office locations with per-location
  days/hours/capacity (writes to `doctor_locations` table)

### Admin — Carriers/Lawyers tab improvements
- Add Carrier / Add Lawyer buttons moved to top of each section

### Admin — visual polish
- Scrollable tab strip (6 tabs: Overview, Carriers, Providers, Lawyers,
  CPT Codes, ICD-10)
- Header subtitle: "Manage Lookup Tables" → "Table Management"
- Cyan borders (`border-[#00cfff30]`) on all list item cards
- Cyan-tinted Edit buttons, red-tinted Del buttons throughout

### Database migrations
- `010`: `practice_settings` (single-row, id=1 constraint) + `office_locations`
  tables, both with full anon RLS (4 policies each)
- `011`: `doctor_locations` junction table (doctor_id + location_id +
  per-location schedule fields); `appointments.location_id` FK column added;
  unique constraints on `cpt_codes(cpt_code)` and `icd10_codes(code)`
- RLS added to `cpt_codes` (was missing all 4 anon policies — root cause of
  CPT tab showing empty) and `icd10_codes` (4 granular policies added
  alongside pre-existing "Allow all" policy)

### Scheduling — Phase 1+2
- Schema: `doctor_locations`, `appointments.location_id` (Phase 1 complete)
- Admin UI: Doctor Schedule tab now has Location Assignments section (Phase 2 complete)
- Phase 3 (calendar location selector) and Phase 4 (MD login location picker): next session

---

## 2026-06-27 (evening) — Orthopedic Surgeon & Pain Management referrals; Save/View pattern; PDF filename cleanup

- New referral types **Orthopedic Surgeon** and **Pain Management**, full stack
- **Save→View button pattern** adopted as standing pattern for all MD-discretionary
  referral types except ICD-10 — applied to DME, Ortho, Pain Mgmt, ANS, MRI, PT,
  Rx, VNG. Deploy confirmed this session (was unconfirmed across 2 prior sessions)
- Renamed 7 referral PDF templates to short filenames (`ANS.pdf`, `DME.pdf`, etc.)

## 2026-06-27 — Biller Dashboard: typography fixes, charting, Denial Docs delete

- Fixed production 500 crash on `/billing`
- Renamed "Payment Status" → "Denial Status"; "Submitted" → "Bill Received"
- Added stacked bar chart "Paid vs Outstanding by Carrier" (raw Recharts)
- Hard delete for Denial Docs
- Shared `app/lib/fonts.ts` Oxanium module created
