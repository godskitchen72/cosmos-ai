# Cosmos Medical Technologies — HANDOVER (July 16, 2026, Session 45)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed and live.
Session 45 was a major feature sprint: Visit Packet Merge, FD Dashboard V2
improvements, 4 new referral types (SONO/FC/PSY/EMG), MRI selector redesign,
referral workflow logic fixes, Referral Pipeline report, and multiple
provider email enhancements.

---

## Completed This Session (Session 45)

### Visit Packet Merge — FD Documents Tab ✅ CLOSED

New `/generate-visit-packet` endpoint in `cosmos-api`. Merges all per-visit
PDFs (PCE + all referral types + ICD-10) into a single file using
`merge_pdfs()` helper added to `forms/base.py`.

- **Trigger:** FD explicit tap — "Build Visit Packet" button in Documents tab
- **Filename:** `{patient_id}_{doa}_{dos}_visit_packet.pdf`
- **form_type:** `VISIT_PACKET`
- **Individual files:** preserved intact — this is additive, not destructive
- **State:** `visitPacketMap` — per-visit packet tracking (each visit card
  independently tracks its own packet filename)
- **Blocked on:** Render Standard plan upgrade for production load safety
  (still on 512MB Starter — pre-go-live blocker, see Open Items)

**Files:** `cosmos-api/main.py`, `cosmos-api/forms/base.py`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Column Preferences (DB-Persisted) ✅ CLOSED

- `user_profiles.fd_column_prefs JSONB DEFAULT NULL` — migration applied
- Column picker dropdown: centered on screen (was off-screen left), custom
  checkbox UI (cyan fill, visible on mobile), "Columns" header + Reset button
- **Reset:** clears UI to all-visible + writes `null` to DB
- Load on mount: fetches `fd_column_prefs`, applies to `columnVisibility`
- Debounced save (800ms) on every column toggle

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`
**DB:** `ALTER TABLE user_profiles ADD COLUMN fd_column_prefs jsonb DEFAULT null`

### FD Dashboard V2 — Search Bar X Clear Button ✅ CLOSED

`✕` button appears inside the search bar when text is present. Clears
`globalFilter` and resets pagination to page 0. Uses lucide `X` icon.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — Activity Summary Tab Navigation ✅ CLOSED

Activity Summary cards (Visits / Appointments / Referrals) on the Overview
tab now navigate to their respective tabs on tap. Uses `setTab()` with
tab keys `'visits'`, `'appointments'`, `'referrals'`.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### SONO / FC / PSY Referral Types ✅ CLOSED

Three new referral types using `GENERIC_REFERRAL_FORM.pdf` (CMT-REF-MD-001 v2.0):

| Type | Code | Specialty printed on form |
|---|---|---|
| Sonogram | SONO | Sonography / Ultrasound |
| Functional Capacity | FC | Functional Capacity Evaluation |
| Psychology | PSY | Psychology / Behavioral Health |

- `referral_types` table: SONO updated from ULTRASOUND code; FC and PSY inserted
- Backend: `forms/sono.py`, `forms/fc.py`, `forms/psy.py`; routes `/generate-sono`,
  `/generate-fc`, `/generate-psy`; config entries in `REFERRAL_FORM_CONFIG`
- Frontend: `app/md/[patientId]/sono/`, `fc/`, `psy/` — `page.tsx` + client component each
- Pre-filled reason text per type; Facility/Provider field removed (FD decides routing)
- No. of Visits field removed (FD assigns)
- Requested Date field removed
- Full lifecycle tracking: `referrals`, `referral_status_history`,
  `referral_timeline`, `referral_notifications` — TRACKED badge on save

**Files:** `cosmos-api/forms/sono.py`, `fc.py`, `psy.py`, `main.py`,
`pdf_engine.py`, `forms/GENERIC_REFERRAL_FORM.pdf` (added to forms/),
`app/md/[patientId]/sono/`, `fc/`, `psy/`,
`app/md/[patientId]/components/ReferralGrid.tsx`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### EMG Referral Type ✅ CLOSED

New EMG referral type using `GENERIC_REFERRAL_FORM.pdf`:

- `referral_types` row already existed (code: EMG, neurology) — no DB insert needed
- Backend: `forms/emg.py`, route `/generate-emg`, config entry in `REFERRAL_FORM_CONFIG`
- Frontend: `app/md/[patientId]/emg/` — `page.tsx` + `EmgReferral.tsx`
- **Body parts:** Upper, Lower (multi-select); stored in `referrals.body_parts`
- Full lifecycle tracking including body_parts in `referral_timeline`

**Files:** `cosmos-api/forms/emg.py`, `main.py`, `pdf_engine.py`,
`app/md/[patientId]/emg/`, `ReferralGrid.tsx`, `FDPatientSheet.tsx`

### SONO — Body Part Multi-Select ✅ CLOSED

Sonogram referral screen now has body part multi-select:
- Options: L. Shoulder, R. Shoulder, Neck, Mid Back, Lower Back
- Stored in `referrals.body_parts` on lifecycle creation
- Validation: at least one part required before save
- Selection summary shown below chips

**Files:** `app/md/[patientId]/sono/SonoReferral.tsx`

### Psych Referral Button — Removed ✅ CLOSED

Old `Psych Referral` toggle button (which wrote `psych_referral` directly to
`patient_visits`) removed from `ReferralGrid.tsx` and `VisitTab.tsx`.
Replaced by the new PSY referral type with full lifecycle tracking.

**Files:** `app/md/[patientId]/components/ReferralGrid.tsx`,
`app/md/[patientId]/components/VisitTab.tsx`

### MRI Selector — Redesigned to MRI/MRA/CT Radio Buttons ✅ CLOSED

Replaced YES/NO metal implant binary selector with three mutually exclusive
radio buttons: **MRI | MRA | CT Scan** in one row.

- Selecting one modality disables and clears the other two sections
- Warning text shown when CT or MRA selected ("MRI and MRA sections disabled")
- `isImaging` flag scoped to MRI/MRA/CT only — SONO/EMG excluded from session splitter
- Submit guard: must select modality before generating
- `handleModalityChoice()` replaces `handleMetalToggle()`

**Files:** `app/md/[patientId]/mri/MriReferral.tsx`

### MRI Session Splitter — Gated to MRI/MRA/CT Only ✅ CLOSED

`isImaging` in `ReferralAppointmentTab.tsx` now checks `typeCode` against
`['MRI', 'MRA', 'CT']` — SONO/EMG `body_parts` no longer trigger the
session splitter UI. Fixing false MRI Sessions display on Ultrasound referrals.

`actions.ts` `scheduleAppointment()` also gated: `isMriType` check before
`requiredSessions` calculation — SONO/EMG appointments schedule as single
sessions with no body-part split logic.

**Files:** `app/referrals/components/ReferralAppointmentTab.tsx`,
`app/referrals/actions.ts`

### Session Card — Moved Above Schedule Form ✅ CLOSED

In `ReferralAppointmentTab.tsx`, the existing session card (showing prior
appointment result) now renders above the Schedule Appointment form.
Previous order was reversed — FD saw the form before seeing the existing session.

**Files:** `app/referrals/components/ReferralAppointmentTab.tsx`

### Auto-Close SONO/FC/PSY/EMG on Result Upload ✅ CLOSED

`uploadReferralResult()` in `actions.ts`: after uploading a result document,
auto-advances referral to `closed` when `referral_types.code` is in
`['SONO', 'FC', 'PSY', 'EMG']`. Writes `referral_status_history` and
`referral_timeline` entries. Non-fatal (wrapped in try/catch).

**Files:** `app/referrals/actions.ts`

### Provider Email — Clinical Reason + Body Parts ✅ CLOSED

Provider session notification email (`actions.ts`) now includes:
- **Body Parts** row — shown when `referral.body_parts` is non-empty
- **Clinical Reason** row — shown when `referral.clinical_reason` is non-empty

Both fields added to the provider email Supabase select query.

**Files:** `app/referrals/actions.ts`

### Referral Pipeline — New Report Tab ✅ CLOSED

New **Referral Pipeline** tab in `app/reports/ReportsClient.tsx`:

- **KPI strip:** Total | Pending (orange) | Upcoming (cyan) | Overdue (red) | Completed (green)
- **Pipeline table:** one row per referral type, columns colored by type
- **Drill-down:** tap any type row to see individual referral detail
- **Detail view:** Provider | Stage | Next Appt | Age — sorted by urgency
- **Export CSV:** both summary and detail views
- **Totals row:** all green bold
- Pending = no appointment, created < 2 days ago
- Upcoming = future appointment scheduled
- Overdue = no upcoming appointment, past appointment OR unscheduled 2+ days
- Completed = `closed` or `cancelled`

**Files:** `app/reports/ReportsClient.tsx`

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet
   Merge is blocked for production use until this upgrade lands. One click in
   Render dashboard — $25/mo, no code change.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientFormV2.tsx` email field
   must be made required. Patient confirmation emails dead until fixed.

4. **Referral workflow auto-advancement logic.** Full workflow design needed
   (Session 45 deferred). Only SONO/FC/PSY/EMG auto-close on result upload
   currently. MRI/VNG/ANS/etc. still require manual FD advancement.

5. **Duplicate visit records.** David Anderson has multiple `patient_visits`
   rows for the same date, all sharing the same generated PDF filenames.
   Root cause not yet identified — investigate why duplicate visits are
   being created.

6. **Cleanup leftover route folders.** Delete `app/md-v2/[patientId]/ref/`
   and `app/md-v2/[patientId]/referral/` — both abandoned, broken content.

7. **Dashboard V2 — Notes tab persistence.** Notes are session-only.
   Requires a new `patient_notes` table or column. Roadmap item.

8. **Dashboard V2 — Stub KPIs.** Patients Waiting, Insurance Verification,
   Tasks Due Today require new DB tables/columns. Future work.

9. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only.

10. **`/referrals/page.tsx` `userRole` hardcoded to `"md"`.** Relies on
    sessionStorage override. Hard refresh without re-login exposes wrong role.

11. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — all unsigned.
    Pre-go-live blocker.

12. **SPF/DKIM for cosmosmt.com.** Not yet configured. Pre-go-live blocker.

13. **DME and RX referral codes.** Excluded from Session 38 codes refactor.

14. **Realtime — referrals and appointments.** Current subscription covers
    `patients`, `patient_visits`, `patient_forms` only. Add before go-live.

15. **PCE guard — minimum pce_data threshold.** Product decision needed.

16. **Ghost mode for PA/NP users.** Location selection currently skipped.

17. **Impersonation session timeout.** Ghost sessions have `timeout=0`.

18. **`patients.intake_url` not in migration file.** Added manually via SQL
    only — schema drift risk if DB is rebuilt.

19. **NPI and License Number on SONO/FC/PSY/EMG PDFs.** Fixed in code
    (`billing_npi`, `doctor_license_number`) — visual review of actual
    generated PDFs still needed to confirm fields populate correctly.

---

## DB Schema Changes This Session

```sql
-- Migration applied via Supabase dashboard SQL editor
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS fd_column_prefs jsonb DEFAULT null;

-- referral_types: code updated and inserted
UPDATE referral_types SET code = 'SONO' WHERE code = 'ULTRASOUND';
INSERT INTO referral_types (label, category, code) VALUES
  ('Functional Capacity', 'specialist', 'FC'),
  ('Psychology', 'specialist', 'PSY');
-- EMG already existed (ae6ab125, neurology, code: EMG)
```

---

## File Confidence

All files below were modified or created this session and confirmed deployed:

| File | Changes |
|---|---|
| `cosmos-api/forms/base.py` | `merge_pdfs()` helper added |
| `cosmos-api/forms/sono.py` | New — SONO referral PDF filler |
| `cosmos-api/forms/fc.py` | New — FC referral PDF filler |
| `cosmos-api/forms/psy.py` | New — PSY referral PDF filler |
| `cosmos-api/forms/emg.py` | New — EMG referral PDF filler |
| `cosmos-api/forms/GENERIC_REFERRAL_FORM.pdf` | Added — CMT-REF-MD-001 v2.0 template |
| `cosmos-api/main.py` | `/generate-visit-packet`, `/generate-sono`, `/generate-fc`, `/generate-psy`, `/generate-emg` routes; REFERRAL_FORM_CONFIG entries |
| `cosmos-api/pdf_engine.py` | SONO/FC/PSY/EMG imports added |
| `app/dashboard-v2/FDDashboardV2.tsx` | Column prefs (DB-persisted), search X, useRef, load/save effects |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | Visit Packet section (Build/View/Rebuild per visit); visitPacketMap state; Activity Summary tab nav; SONO/FC/PSY/EMG/VISIT_PACKET DOC_LABELS |
| `app/md/[patientId]/components/ReferralGrid.tsx` | SONO/FC/PSY/EMG/EMG buttons added; Psych Referral button removed; psych props removed |
| `app/md/[patientId]/components/VisitTab.tsx` | Psych props removed from ReferralGrid call |
| `app/md/[patientId]/mri/MriReferral.tsx` | MRI/MRA/CT radio selector replaces YES/NO metal implant toggle |
| `app/md/[patientId]/sono/SonoReferral.tsx` | Full rewrite — body part multi-select, no visit count, no requested date |
| `app/md/[patientId]/sono/page.tsx` | Server component for SONO |
| `app/md/[patientId]/fc/FcReferral.tsx` | New — FC referral client component |
| `app/md/[patientId]/fc/page.tsx` | New — FC server component |
| `app/md/[patientId]/psy/PsyReferral.tsx` | New — PSY referral client component |
| `app/md/[patientId]/psy/page.tsx` | New — PSY server component |
| `app/md/[patientId]/emg/EmgReferral.tsx` | New — EMG referral client component with Upper/Lower body parts |
| `app/md/[patientId]/emg/page.tsx` | New — EMG server component |
| `app/referrals/actions.ts` | Auto-close SONO/FC/PSY/EMG on result upload; body_parts + clinical_reason in provider email; MRI split gated to MRI/MRA/CT |
| `app/referrals/components/ReferralAppointmentTab.tsx` | isImaging scoped to MRI/MRA/CT; session card above schedule form |
| `app/reports/ReportsClient.tsx` | Referral Pipeline tab added |

---

## Known Architecture Gaps

- `getReferralProviders()` return type is still `any[]`.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — sessionStorage override only.
- ReferralSheet header badge reads raw `referrals.status` — cosmetic gap.
- Body parts missing on sessions rescheduled before Session 36 — data issue.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- `(referral as any).cpt_codes` cast in `ReferralOverviewTab`.
- Render Starter (512MB) insufficient for PDF generation under load.
- DME and RX referral pages still hardcode `cpt_codes: []`/`icd10_codes: []`.
- `app/md-v2/[patientId]/ref/` and `app/md-v2/[patientId]/referral/` abandoned folders to delete.
- Android/Termux filesystem is case-insensitive — git cannot track folder renames with bracket characters.
- `dashboard-v2` notes are session-only — not persisted to DB.
- `referral_appointments.needs_review` and `reviewed_at` (migrations 031–032) vestigial.
- Realtime subscription covers `patients`, `patient_visits`, `patient_forms` only.
- PCE auto-generation guard fires on any non-empty `pce_data` — minimum field threshold not enforced.
- `hasPceLocal` variable remains in `PreflightModal` — dead variable, harmless.
- `PatientForm.tsx` (legacy) still exists and is used nowhere — candidate for removal.
- `patients.intake_url` added via manual SQL only — not in any migration file.
- Ghost mode for PA/NP users skips location selection.
- Ghost mode has no session timeout (timeout=0).
- `AI_STYLE_GUIDE.md` §2 still says "five" Tailwind/shadcn exceptions — should be "six" (FD Dashboard V2 added Session 41).
- SONO/FC/PSY/EMG PDF field population (NPI, license) — fixed in code but not yet visually verified against real generated PDFs.
- Duplicate visit records for some patients — root cause unknown, needs investigation.

---

## Technical Lessons This Session

- `visitPacketMap` (Record<string, string>) is the correct pattern for
  tracking per-visit state across multiple visit cards — a single string
  state variable causes all cards to share the same value.
- `isImaging` in `ReferralAppointmentTab.tsx` was gated on `category === 'imaging'`
  which incorrectly included SONO/Ultrasound. Always gate MRI-specific logic
  on `typeCode` (MRI/MRA/CT) not on category string.
- `billing_npi` and `doctor_license_number` are the correct keys from
  `_build_doctor_fields()` — not `npi` and `license_number`.
- `awaiting_results` is not a valid `ReferralStatus` TypeScript type — use
  the actual enum members only.
- `'use client'` components exporting named exports (not default) must use
  `export function X()` syntax — `page.tsx` server components that import
  them must use `{ X }` named import, not default import.
- Python `.format(**r)` fails when the template string contains `{}` dict
  literals — use string concatenation instead for Python code generation.
- Line-number based file patching (reading `lines[]` by index) is more
  reliable than string anchoring when file has non-UTF-8 bytes or
  inconsistent whitespace.

---

## Roadmap Checklist

### Stage 1 — Core Platform ✅ COMPLETE
- [x] All items from Sessions 1–37

### Stage 2 — Referral Management
- [x] MRI referral lifecycle (Sessions 22–32)
- [x] MRI session splitting (Session 31)
- [x] Per-session result upload (Session 32)
- [x] ANS referral module end-to-end (Session 37)
- [x] VNG/Ortho/Pain-Mgmt/PT codes from patient_visits (Session 38)
- [x] VNG/Ortho/Pain-Mgmt/PT selections stored + displayed (Session 38)
- [x] Auto-close on result upload — MRI types (Session 38)
- [x] Auto-close on result upload — SONO/FC/PSY/EMG (Session 45)
- [x] NEW RESULTS badge — MD patient chart (Session 38)
- [x] results_viewed_at dismissal (Session 38)
- [x] referral_submitted_at — set on provider assign (Session 38)
- [x] MD all-referrals summary table (Session 38)
- [x] MRI/MRA/CT incomplete parts warning (Session 38)
- [x] Done/Awaiting/Review workflow removed (Session 39)
- [x] MRA body_parts fix (Session 39)
- [x] Auto-close body_parts select bug fixed (Session 39)
- [x] MRI/MRA/CT all-parts-assigned gate for auto-close (Session 39)
- [x] Referral dashboard MRI/MRA/CT per-appointment expansion (Session 39)
- [x] MD referrals table — per-session expansion, sort, body parts column (Session 39)
- [x] Referral dashboard patient pre-filter via ?patient= (Session 40)
- [x] Awaiting KPI — past appointment, no result (Session 42)
- [x] Overdue KPI — redefined as unscheduled 2+ days (Session 42)
- [x] Results Received column in referral dashboard (Session 42)
- [x] Ref. Created column renamed and reordered (Session 42)
- [x] Provider Performance turnaround N/A fixed (Session 43)
- [x] SONO referral type — body parts, generic form (Session 45)
- [x] FC referral type — generic form (Session 45)
- [x] PSY referral type — generic form (Session 45)
- [x] EMG referral type — body parts (Upper/Lower), generic form (Session 45)
- [x] MRI selector → MRI/MRA/CT radio buttons (Session 45)
- [x] Psych referral button removed (Session 45)
- [x] Body parts in provider session email (Session 45)
- [x] Clinical reason in provider session email (Session 45)
- [x] Referral Pipeline report tab (Session 45)
- [ ] DME and RX codes from patient_visits
- [ ] ReferralSheet header badge — raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientFormV2.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id
- [ ] Cleanup abandoned route folders (ref/, referral/)
- [ ] Full referral workflow auto-advancement logic design

### Stage 3 — Front Desk Dashboard V2
- [x] Shell, header, sidebar, KPI cards (Session 40)
- [x] TanStack work queue — sorting, pagination, search, CSV export, column visibility (Session 40)
- [x] Patient detail sheet — 8 tabs, real data (Session 40)
- [x] Referrals tab — real FK join data, links to Referral Dashboard (Session 40)
- [x] Oxanium font, mobile search (Session 40)
- [x] Superadmin picker integration (Session 40)
- [x] Referrals tab — full ReferralsTabV2-style table, per-session rows, Results PDF (Session 41)
- [x] Documents tab — NF-2 and AOB only, signature capture (Session 41)
- [x] Visits tab — billing workflow, preflight modal, checkbox selection, submit to billing (Session 41)
- [x] Realtime subscriptions — patients, patient_visits, patient_forms (Session 41)
- [x] Search bar moved below KPI cards (Session 41)
- [x] KPI cards Oxanium font (Session 41)
- [x] Documents tab — MD Records + Referral Results collapsible cards (Session 42)
- [x] Documents tab — Select All, Download ZIP, Email Attorney (Session 42)
- [x] Visits tab — CPT chips cyan, simplified (Session 42)
- [x] Reports link in sidebar (Session 42)
- [x] Overview tab — Demographics/Accident/Insurance restructure (Session 43)
- [x] Insurance tab — matches overview structure, policy_num (Session 43)
- [x] Edit Patient quick action button (Session 43)
- [x] Intake Form card in Documents tab (Session 43)
- [x] DashboardNav shared hamburger (Session 43)
- [x] Back button — router.back() replaced with explicit push (Session 44)
- [x] System back closes patient sheet via hash nav (Session 44)
- [x] Badge-to-tab navigation — clicking badge opens correct tab (Session 44)
- [x] Signature on file — cyan card + View button on all surfaces (Session 44)
- [x] Shared SignatureCaptureModal — optimistic UI (Session 44)
- [x] Book Appointment CTA in Appointments tab (Session 44)
- [x] Docs OK requires sig + AOB + NF-2 generated (Session 44)
- [x] Workflow Stage: NF-2 Missing Stage, Book Appointment badge (Session 44)
- [x] NF-2 KPI split — Missing vs Pending Mail (Session 44)
- [x] Work queue table — green headers, cyan cells, 10-row default (Session 44)
- [x] Visit Packet Merge — Build/View/Rebuild per visit in Documents tab (Session 45)
- [x] Column preferences — DB-persisted per user (Session 45)
- [x] Column picker — custom checkbox UI, centered dropdown, Reset button (Session 45)
- [x] Search bar X clear button (Session 45)
- [x] Activity Summary buttons → tab navigation (Session 45)
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables
- [ ] Remove legacy PatientForm.tsx

### Stage 3b — FD Reports
- [x] Monthly Summary (Sessions 42–43)
- [x] Awaiting Results tab (Sessions 42–43)
- [x] Provider Performance tab (Sessions 42–43)
- [x] Open Aging tab (Sessions 42–43)
- [x] Referral Pipeline tab (Session 45)

### Stage 3c — Patient Intake
- [x] PatientFormV2 — 5-tab wizard, FD dark theme (Session 43)
- [x] INTAKE PDF auto-generation on save (Session 43)
- [x] INTAKE Regen button in Documents tab (Session 43)
- [x] Edit patient wired to PatientFormV2 (Session 43)
- [ ] Patient email required in PatientFormV2
- [ ] intake_url added to migration file (currently manual SQL only)

### Stage 3d — Superadmin & Ghost Mode
- [x] DashboardNav on all dashboards (Session 43)
- [x] Valar Morghulis — full JWT impersonation (Session 43)
- [x] Audit log on impersonation (Session 43)
- [x] Ghost banner on all pages (Session 43)
- [x] Iron coin + anonymous mask branding (Session 43)
- [ ] Ghost mode for PA/NP users — location selection currently skipped
- [ ] Impersonation session timeout (ghost sessions have timeout=0)

### Stage 3e — Scheduling
- [x] Calendar redesign — FD V2 palette, bottom-sheet booking (Session 44)
- [x] Smart booking — auto-resolve patient's MD, next available date (Session 44)
- [x] Adaptive doctor filter — chips ≤5, dropdown >5 (Session 44)
- [x] System back closes referral sheet via hash nav (Session 44)
- [ ] Calendar realtime — appointment status changes don't push live
- [ ] Conflict-aware time slot display (future enhancement)

### Stage 4 — Billing
- [ ] Billing packet generation improvements
- [ ] Attorney email workflow

### Stage 5 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker (Visit Packet production-blocked until done)
- [ ] PDF migration to client-side @react-pdf/renderer (Phase 2, long-term)

### Stage 6 — Scale
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] Data retention and deletion policy
- [ ] Patient data export capability
