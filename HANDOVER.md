# Cosmos Medical Technologies — HANDOVER (July 17, 2026, Session 46)

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
Session 46 was a major FD workflow sprint: complete Workflow Stage redesign,
booking modal improvements, FD Documents tab overhaul (MD Clinical removed,
visit packet checkboxes, manual referral result upload, named ZIP downloads),
Needs Scheduling KPI card, Dev Tools enhancements, and Admin scroll-to-edit
across all sections.

---

## Completed This Session (Session 46)

### SONO/FC/PSY/EMG PDF Visual Verification ✅ CLOSED

NPI and license number field population on SONO/FC/PSY/EMG PDFs visually
verified against real generated PDFs. Fields confirmed populating correctly.
Open Item #19 from Session 45 closed.

### Workflow Stage — Complete Redesign ✅ CLOSED

FD work queue Workflow Stage column fully redesigned with clinical lifecycle
stages. Computed in `getWorkflowStage()` in `FDDashboardV2.tsx`.

**Stage map (priority order):**
| Stage | Color | Condition |
|---|---|---|
| `Discharged` | Green | `patients.status === 'Discharged'` |
| `NF-2 Missing` | Red | No `nf2_url` |
| `Book Init Visit` | Orange | Has `nf2_url`, zero visits |
| `Cancelled / Rebook` | Red | Most recent appointment is `cancelled` |
| `Book Follow Up N` | Orange | Has visits, no future appointment; N = visit count |
| `Upcoming · MMM D` | Cyan | Has future non-cancelled appointment |

- `patients.status` column confirmed as the discharge field (values: `Active`, `Active Treatment`, `Discharged`)
- `Active` and `Active Treatment` both treated as non-discharged
- Booking-action stages (Book Init Visit, Book Follow Up N, Cancelled/Rebook) tap directly to `/calendar?patient=ID` — booking modal auto-opens with patient + doctor pre-filled
- `Upcoming` and `Discharged` open patient sheet

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`, `app/dashboard-v2/page.tsx`

### Needs Scheduling KPI Card ✅ CLOSED

New KPI card counting all patients in booking-action stages (Book Init Visit +
Book Follow Up N + Cancelled/Rebook). Tapping filters work queue to those
patients only.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### Booking Modal — Patient Pre-fill Fix ✅ CLOSED

Calendar patient query was `.eq('status','Active Treatment')` — excluded
`Active` patients, causing empty patient dropdown when arriving from FD
dashboard. Fixed to `.neq('status','Discharged')` — all non-discharged
patients now appear.

**Files:** `app/calendar/page.tsx`

### Booking Modal — Duplicate Button Removed ✅ CLOSED

Removed redundant "Schedule First Appointment" empty-state button from
Appointments tab. Single "Book Appointment" header button remains.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### Booking Modal — Location Date Chips ✅ CLOSED

When a location is selected in the booking modal, a row of available date
chips appears showing the next 6 dates for that location's `days_of_week`.
Tapping a chip sets the appointment date. Left/right arrows page through
additional dates (6 per page, up to 60 total). `LocationDateChips` is a
standalone React component with its own page state.

**Files:** `app/calendar/page.tsx`

### FD Documents Tab — Complete Overhaul ✅ CLOSED

Multiple changes to `FDPatientSheet.tsx` Documents tab:

- **Section header** renamed to "No-Fault Forms & Requirements", moved above
  signature card
- **Signature card** restyled to match DocCard pattern (green dot indicator,
  View button right-aligned, Re-sign as underline link — no emoji, no
  full-width button)
- **NF-2 Confirm Mailed** moved inline with the NF-2 title row (subtitle
  row shows mailed status or the button)
- **MD Clinical table** (PCE/ICD-10 per visit collapsible card) removed —
  replaced by Visit Packet as the primary per-visit document collection
- **Visit Packet checkboxes** — each visit packet card now has an individual
  checkbox for manual selection; `download_name` computed at selection time
- **Select All** moved above Visit Packet section; now selects visit packets
  + referral results (replaces old MD forms selection)
- **Manual upload** — each Referral Results card has an Upload Result button
  for uploading documents received outside the system. Inserts
  `referral_documents` row (no `patient_id` column on that table).
  Storage path: `referral-results/{patientId}/{safeLabel}-manual-{ts}.{ext}`
- **Referral Results** now show below Visit Packet with Select All on same row

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### Named ZIP Downloads ✅ CLOSED

Files inside the downloaded ZIP now use meaningful names instead of
`record_01.pdf` etc.

**Naming convention:**
- Visit Packet: `VisitPacket_N_MMDDYYYY.pdf` (N = oldest visit = 1)
- Referral result: `ReferralType_N_MMDDYYYY.pdf` (N = result number within type)
- Date format: `MMDDYYYY` (human-readable for medical staff / attorneys)

`download_name` is computed client-side at selection time and sent to the
API alongside `path` and `bucket`. API uses it as the ZIP entry name,
falling back to `record_NN.ext` if absent.

**Files:** `cosmos-api/main.py`, `app/dashboard-v2/components/FDPatientSheet.tsx`

### Dev Tools — Fixed Email/Phone + New Referral Types ✅ CLOSED

- All generated test patients now use fixed email `arcchemies@gmail.com` and
  phone `9297683179` so notifications reach the developer during testing
- SONO, FC, PSY, EMG added to `ALL_REFERRAL_TYPES` with labels, type codes,
  and clinical reasons
- "All" chip updated from "All 9" to "All 13"

**Files:** `app/dev/page.tsx`

### Admin — Scroll to Edit Form ✅ CLOSED

Tapping Edit on any admin card now scrolls the edit form into view
automatically (`scrollIntoView({ behavior: 'smooth', block: 'start' })` with
50ms delay). Applied to all four sections with edit forms:
- CarriersSection
- LawyersSection
- UsersSection
- ReferralProvidersSection

**Files:** `app/admin/components/CarriersSection.tsx`,
`app/admin/components/LawyersSection.tsx`,
`app/admin/components/UsersSection.tsx`,
`app/admin/components/ReferralProvidersSection.tsx`

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet
   Merge is blocked for production use until this upgrade lands. One click in
   Render dashboard — $25/mo, no code change.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientFormV2.tsx` email field
   must be made required. Patient confirmation emails dead until fixed.

4. **Referral workflow auto-advancement logic.** Full workflow design needed.
   Only SONO/FC/PSY/EMG auto-close on result upload currently. MRI/VNG/ANS/etc.
   still require manual FD advancement.

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

19. **ZIP download naming — needs live test.** API change landed (`download_name`
    support in `/generate-records-zip`). Fresh Select All + Download ZIP test
    needed to confirm `VisitPacket_N_MMDDYYYY.pdf` names appear correctly.

---

## DB Schema Changes This Session

No new migrations. `referral_documents` table confirmed has no `patient_id`
column — upload insert corrected accordingly.

---

## File Confidence

All files below were modified or created this session and confirmed deployed:

| File | Changes |
|---|---|
| `cosmos-api/main.py` | `download_name` support in `/generate-records-zip` ZIP entry naming |
| `app/dashboard-v2/FDDashboardV2.tsx` | Workflow stages redesign; Needs Scheduling KPI; `patient_status` fetched; `getWorkflowStage()` rewritten; booking-action badges route to calendar |
| `app/dashboard-v2/page.tsx` | `status` added to patients select query |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | Full Documents tab overhaul — signature card, NF-2 inline mailed, MD Clinical removed, visit packet checkboxes, manual upload, select all, named download, section header |
| `app/calendar/page.tsx` | Patient query fixed to `.neq('status','Discharged')`; `LocationDateChips` component added; duplicate booking button removed; `React` default import added |
| `app/dev/page.tsx` | Fixed email/phone on generated patients; SONO/FC/PSY/EMG referral types added |
| `app/admin/components/CarriersSection.tsx` | Scroll-to-edit on tap |
| `app/admin/components/LawyersSection.tsx` | Scroll-to-edit on tap |
| `app/admin/components/UsersSection.tsx` | Scroll-to-edit on tap |
| `app/admin/components/ReferralProvidersSection.tsx` | Scroll-to-edit on tap |

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
- Duplicate visit records for some patients — root cause unknown, needs investigation.
- ZIP download naming (named files) — landed in API but not yet live-tested end-to-end.

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
- `referral_documents` table has no `patient_id` column — confirmed via
  `information_schema.columns`. Upload inserts must not include it.
- `patients.status` (not `patient_status`) is the correct column name for
  discharge state. Values: `Active`, `Active Treatment`, `Discharged`.
  Both `Active` and `Active Treatment` are treated as non-discharged for
  workflow stage logic.
- `useRef`/`useEffect` for scroll-to-edit must be declared after the state
  variable they reference — declaring before causes TS2448 "used before
  declaration" error.
- sed commands with complex substitutions involving brackets and quotes are
  unreliable in Termux — always prefer Python heredoc or patch scripts for
  anything beyond simple single-word replacements.
- Chrome does not overwrite same-named downloads — always `rm -f` before
  re-downloading a patch script with the same filename.

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
- [x] Manual result upload on referral result cards (Session 46)
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
- [x] Workflow Stage — full lifecycle redesign (Discharged/Book Init Visit/Book Follow Up N/Cancelled Rebook/Upcoming date) (Session 46)
- [x] Needs Scheduling KPI card (Session 46)
- [x] Booking-action badges route directly to calendar with patient pre-filled (Session 46)
- [x] Documents tab — MD Clinical removed; visit packet checkboxes; manual result upload; named ZIP downloads; NF-2 mailed inline; signature card restyled; section header renamed/moved (Session 46)
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
- [x] Location date chips in booking modal — available dates by location (Session 46)
- [x] Patient pre-fill fix — all non-discharged patients shown (Session 46)
- [ ] Calendar realtime — appointment status changes don't push live
- [ ] Conflict-aware time slot display (future enhancement)

### Stage 3f — Admin
- [x] Scroll-to-edit across all admin sections (Session 46)

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
