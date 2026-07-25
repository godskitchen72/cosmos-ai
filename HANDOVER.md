# Cosmos Medical Technologies — HANDOVER (July 23, 2026, Session 57 — Close)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed and live as of Session 57 close.

**Production status:** `cosmosmt.com` fully live. MD Dashboard V3 is the default MD dashboard. FD Dashboard V2 is the default FD dashboard. `cosmos_documents` is the sole source of truth for all generated PDFs. All legacy url columns and `patient_forms` retired.

**Dev environment status:** `cosmos-dev` Supabase project fully operational. Phase 4 schema drop should also be applied to cosmos-dev (not yet done — see open items).

**Root cause learned (Session 52):** Server component `page.tsx` files must NOT call `supabase.auth.getUser()` + `redirect()` — this causes the page to 404 in production. Auth is handled by middleware only. This applies to all future server page components.

---

## Completed This Session (Session 57)

### MD Dashboard V3 — Visit Page at /md-v3/visit/[patientId] ✅
New V3-styled visit page at `/md-v3/visit/[patientId]`. New Visit and Edit Visit buttons in `PatientClinicalSheet.tsx` now route to V3 visit page instead of `/md`. Back button uses `router.back()` per platform policy. On return from visit page, patient sheet reopens via `?patient=` URL param read by `MDDashboardV3`.

**Files:** `app/md-v3/visit/[patientId]/page.tsx` (new), `app/md-v3/visit/[patientId]/VisitPageV3.tsx` (new), `app/md-v3/components/PatientClinicalSheet.tsx`

### MD Dashboard V3 — Referral Workspace as Overlay ✅
Referrals button in patient sheet no longer navigates to `/md/[patientId]/referrals`. Instead opens `ReferralWorkspace` as a full-screen overlay on `/md-v3`. Visit picker appears first when patient has multiple visits (MD selects which visit to attach referrals to). Android back button closes overlay correctly — URL never changes.

**Files:** `app/md-v3/MDDashboardV3.tsx`, `app/md-v3/components/PatientClinicalSheet.tsx`, `app/md/[patientId]/referrals/ReferralWorkspace.tsx`

### MD Dashboard V3 — Workflow Badges + 6 KPI Cards ✅
Status column added to MD patient list with multiple computed badges per patient: `Appt Today` (cyan), `Note Missing` (red), `Referrals Pending` (purple), `Results Ready` (green), `Biller Flag` (orange), `Discharge Pending` (amber), `No Visit Yet` (grey). KPI card grid expanded from 3 to 6: Today, Waiting, Urgent, Referrals, Discharge, All. All 6 are tappable and filter the patient table.

**Files:** `app/md-v3/MDDashboardV3.tsx`

### FD Dashboard — Discharge Pending Stage ✅
New `Discharge Pending` workflow stage in `getWorkflowStage()` — triggers when latest visit has `work_status = 'Discharge Pending'`. Amber badge. Bridges MD→FD workflow automatically on next page load.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard — todayStr() Eastern Timezone Fix ✅
`todayStr()` now uses `America/New_York` timezone via `toLocaleString`. Previously used UTC causing date off-by-one after ~8pm Eastern. Appointment `>= today` comparison also fixed to include same-day appointments.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard — KPI Cards 3-Column Grid ✅
KPI cards changed from 1 per row to 3 per row. Card padding, icon size, font sizes tightened for mobile.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### MD Dashboard — MD/Doctor Selector Routes to V3 ✅
Dashboard selector at `cosmosmt.com` now routes "MD / Doctor" to `/md-v3` instead of `/md`.

**Files:** `app/page.tsx`

### PatientClinicalSheet — UI Improvements ✅
- Open Referrals section removed from Overview tab
- Latest Visit date now cyan, ICD-10/CPT codes display fixed (string→array parse)
- Visits tab: compact single-line cards, Initial Visit first (oldest→newest), cyan dates, BILLED badge
- Font sizes doubled across Overview tab (field labels, values, pain chips, section headers)

**Files:** `app/md-v3/components/PatientClinicalSheet.tsx`

### FD Dashboard — Re-sign Button Fixed ✅
Re-sign button now opens signature pad (`setShowSigPad(true)`) instead of viewing the existing signature URL.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard — router.refresh() After Document Regen ✅
AOB/NF-2 warnings now clear automatically after regen without manual page reload. `router.refresh()` added to both `handleGenerate` and `handleRegenerate` success paths.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### Patient Intake — Doctor Required + Default ✅
Doctor field now required at intake. `doctors.is_default` column added (Migration 035). Yury Gottesman set as default doctor. New patient form pre-populates doctor from `is_default` flag. Doctor validation added to personal tab.

**Files:** `app/components/PatientFormV2.tsx`
**DB:** Migration 035 — `ALTER TABLE doctors ADD COLUMN is_default boolean DEFAULT false`

### API — W9 Billing Entity Check Fixed ✅
`is_billing_entity` check in `/generate-w9` endpoint changed from `not supervising_id and (bool(pc_corp_name) or ...)` to `bool(pc_corp_name) or (not supervising_id and tax_class == "individual")`. PC corp presence is now sufficient to qualify as billing entity regardless of supervision status.

**File:** `cosmos-api/main.py`

### W9 Backfill + Wipe Route Cleanup ✅
- W9 rows backfilled from `doctors.w9_url` into `cosmos_documents` via SQL
- `app/api/wipe-patients/route.ts` — `patient_forms` truncate replaced with `cosmos_documents` truncate
- `app/dev/page.tsx` — `patient_forms` insert removed (table dropped)

**Files:** `app/api/wipe-patients/route.ts`, `app/dev/page.tsx`

### DEV Artifacts — PCE Fill Button Removed ✅
DEV fill-all PCE button removed from `VisitTab.tsx`. No other DEV artifacts removed this session (Dev Tools card in Admin stays — superadmin tool, intentional).

**Files:** `app/md/[patientId]/components/VisitTab.tsx`

### Back Button Policy Enforced ✅
Platform-wide policy: all back/← buttons on sub-pages and modals use `router.back()` or callback pattern. `ReferralWorkspace` back buttons fixed. Android hardware back works correctly throughout MD flow.

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet Merge blocked for production use. Cold start causes "Failed to fetch" on referral saves. One click, $25/mo. **Pre-go-live blocker.**

2. **Twilio SMS activation.** All code live. Three steps:
   - Buy `+17185695200`
   - Update `TWILIO_FROM_NUMBER` in Render
   - Complete A2P 10DLC business registration

3. **Appointment confirmation SMS trigger.** Wire `/notify/sms` into calendar booking save path.

4. **Patient phone required at intake.** `PatientFormV2.tsx` phone field must be required.

5. **Patient email required at intake.** `PatientFormV2.tsx` email field must be required.

6. **Calendar timezone bug.** MD Calendar highlights wrong day (shows Friday Jul 24 when today is Thursday Jul 23). Client-side `new Date()` week calculation off by one day. Investigate `app/calendar/page.tsx` week offset logic.

7. **Jessica Rodriguez (PT660445) — no doctor assigned.** FD must open patient → edit → assign doctor. W9 "Not on file" will resolve automatically after assignment and AOB regen.

8. **AOB regeneration — all affected patients.** Patients whose AOB was generated pre-Migration 034 show "AOB not uploaded" warning. Regen via FD → patient sheet → Documents tab → AOB → Regen. `router.refresh()` now clears warning automatically after regen.

9. **Phase 4 schema drop — cosmos-dev.** `patient_forms` table and url columns not yet dropped from `cosmos-dev`. Apply Migration 034 SQL to `tpwbgqfdznqtjqimxric` when convenient.

10. **`/md` and `/md-v2` route retirement.** Routes still in codebase. Safe to delete once MD V3 confirmed stable. Keep `app/md/[patientId]/` visit editor and referral workspace files — still used by V3.

11. **`/md-v3` error boundary cleanup.** `app/md-v3/error.tsx` is a debug artifact. Remove when `/md-v3` is stable.

12. **`page.tsx` userRole hardcoded.** `/referrals/page.tsx` passes `userRole="md"` — should be resolved from session.

13. **Duplicate visit records investigation.** Some patients have multiple `patient_visits` rows for the same date (test data, confirm before go-live).

14. **`000_initial_schema.sql` superseded.** Stale on disk — use pg_dump approach.

15. **`/patients/[patientId]` old route still accessible.** URL `cosmosmt.com/patients/PT447963` loads old patient page. Nothing in V3 links to it — accessible via direct URL only. Retire or redirect when old dashboard is retired.

---

## Known Architecture Gaps (carried forward)

- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- Ghost session timeout is 0 — impersonation sessions never expire.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"`.
- `app/md-v3/error.tsx` debug artifact in production.
- `doctors.w9_url` for supervised providers is a copied value (not a FK) — if supervisor regenerates W9, supervised providers' `cosmos_documents` rows auto-update via `registry_upsert`, but `doctors.w9_url` still requires manual re-save or SQL backfill.
- Phase 4 schema drop not yet applied to cosmos-dev (open item #9).
- Calendar week calculation off by one day (open item #6).

---

## Back Button Policy (Session 57, locked)

All back/← buttons on sub-pages and modals must use `router.back()` or a callback prop (`onDone`, `onBack`). Never hardcode a destination route for backward navigation. Forward navigation (New Visit, Edit Visit, Referral) uses `router.push()` with explicit paths.

**Exception:** When returning from a full-page route to a dashboard that manages overlay state (e.g. patient sheet), use `router.push('/md-v3?patient=[patientId]')` so the sheet reopens. This is not a backward navigation — it's a forward push that restores state.

---

## MD V3 Navigation Architecture (Session 57, locked)

```
cosmosmt.com/md-v3                          ← MD Dashboard
  │
  ├── tap patient → PatientClinicalSheet (overlay, URL stays /md-v3)
  │     │
  │     ├── [New Visit] → /md-v3/visit/[patientId]
  │     │     └── [← Dashboard] → router.back()
  │     │
  │     ├── [Edit Visit →] → /md-v3/visit/[patientId]?visit_id=[id]
  │     │     └── [← Dashboard] → router.back()
  │     │           (back pushes /md-v3?patient=[patientId] → sheet reopens)
  │     │
  │     └── [Referrals] → ReferralWorkspace overlay (URL stays /md-v3)
  │           ├── Visit picker (if multiple visits)
  │           └── [← Back / Done] → closes overlay (onDone callback)
  │
  └── KPI cards filter patient table (Today, Waiting, Urgent, Referrals, Discharge, All)
```

---

## cosmos_documents Architecture (Session 55–56, locked)

Unified document registry for all generated PDFs. Three scopes:

| Scope | Anchor | Examples |
|---|---|---|
| `patient` | `patient_id` | NF-2, AOB, INTAKE |
| `visit` | `visit_id` | NF-3, PCE, ICD10, referrals, VISIT_PACKET |
| `doctor` | `doctor_id` | W9 |

**Key properties:**
- `UNIQUE (patient_id, form_type)`, `UNIQUE (visit_id, form_type)`, `UNIQUE (doctor_id, form_type)` — one active doc per type per scope
- `registry_upsert()` in `main.py` handles delete-old-file + upsert atomically
- Supervisor W9 resolution: `FDDocumentsTab.load()` checks `doctors.supervising_provider_id` and includes supervisor's `doctor_id` in cosmos_documents query
- **Phase 4 complete:** No fallback reads or writes anywhere. `patient_forms` and all url columns retired from DB, code, and TypeScript interfaces.

---

## PDF Signature Architecture (Session 54, locked)

All signature injection goes through `forms/base.py` `inject_signature_image()`. Single shared function called by all 14 form generators. Key properties:
- `keep_proportion=True` — no stretching
- `cy ± 30` rect expansion — 60pt tall, centered on field midpoint
- Exception: NF-2 uses asymmetric expansion (`r.y0 - 20, r.y1 + 35`) to avoid bleeding into adjacent stacked fields

---

## W9 Inheritance Rule (Session 54, updated Session 55)

Supervised providers (PA, NP, DC, PT, PSY) never have their own W9 — they bill under their supervising MD's PC. Their `doctors.w9_url` is set to the supervisor's `w9_url` at save time in Admin (`DoctorsSection.tsx` `handleSave()`). Their `cosmos_documents` W9 row is inserted/updated pointing to the supervisor's W9 filename.

---

## Doctor Default Rule (Session 57, locked)

`doctors.is_default` boolean column (Migration 035). One doctor marked `is_default = true` (currently Yury Gottesman). `PatientFormV2.tsx` fetches `is_default` on load and pre-populates doctor field for new patients. Doctor is required at intake — validation blocks save if empty.

---

## Workflow Stage Lifecycle (Session 57, locked)

FD `getWorkflowStage()` computes stage from DB fields — never stored. Stages in priority order:

1. `Discharged` — `patient.status === 'Discharged'` (terminal)
2. `Discharge Pending` — latest visit `work_status === 'Discharge Pending'`
3. `NF-2 Missing` — no NF-2 in `cosmos_documents`
4. `Book Init Visit` — no visits yet
5. `Cancelled / Rebook` — latest appointment cancelled
6. `Upcoming · [date]` — future appointment exists (`>= today`)
7. `Book Follow Up N` — has visits, no upcoming appointment

MD sets `Discharge Pending` via work_status field in VisitTab. FD sees it automatically on next page load.

---

## Twilio Configuration Reference

| Env Var | Value | Location |
|---|---|---|
| `TWILIO_ACCOUNT_SID` | `AC...` (stored in Render env vars) | Render cosmos-api |
| `TWILIO_AUTH_TOKEN` | (set) | Render cosmos-api |
| `TWILIO_FROM_NUMBER` | `+18777804236` (placeholder) | Render cosmos-api |

**Target FROM number:** `+17185695200` (718 NYC, $1.15/mo, purchase pending)

---

## SMS Templates (live)

1. **Appointment Confirmed** — Hi [Name], your appointment at Cosmos Medical has been confirmed.
2. **Appointment Reminder** — Hi [Name], this is a reminder about your upcoming appointment at Cosmos Medical.
3. **Please Call Our Office** — Hi [Name], please call our office at your earliest convenience.
4. **Documents Needed** — Hi [Name], we have outstanding documents that require your attention.
5. **Results Ready** — Hi [Name], your test results are ready for review.

---

## Roadmap Checklist

### Stage 1 — Core Clinical
- [x] Patient intake — PatientFormV2 5-tab wizard
- [x] Visit documentation — SOAP, CPT, ICD-10
- [x] NF-2 generation and mailing
- [x] AOB generation
- [x] Doctor required + default at intake (Session 57)

### Stage 2 — Referral Management
- [x] Full referral lifecycle
- [x] MRI/MRA/CT body parts + session splitting
- [x] SONO/FC/PSY/EMG/ANS referral types
- [x] Auto-close on result upload
- [x] Referral workflow redesign — 7 statuses, all auto-transitions
- [x] MD review workflow removed
- [x] Appointment-driven dashboard (Session 50)
- [x] Multi-Referral tracking row (Session 50)
- [x] MRI stays `new` throughout lifecycle (Session 50)
- [x] Single appointment view at /referrals/[id]?appt= (Session 50)
- [x] Rebook flow from RESCHEDULE row (Session 50)
- [x] Referral detail page restyling — calendar design tokens (Session 51)
- [x] MD Referral Workspace — all 11 forms, onBack/onSaved, shared utils (Session 51)
- [x] MRI/MRA/CT split into 3 focused workspace forms (Session 51)
- [x] Referral workspace as overlay on MD V3 (Session 57)
- [x] Visit picker before referral workspace (Session 57)
- [ ] DME and RX codes from patient_visits
- [ ] Patient email required at intake
- [ ] DEV artifacts removal

### Stage 3 — Front Desk Dashboard V2
- [x] Full FD Dashboard V2
- [x] SMS notification system
- [x] Referral dashboard appointment-driven (Session 50)
- [x] Documents Missing — intake form added (Session 51)
- [x] Bills Submitted KPI — visit count (Session 51)
- [x] Submit Bills KPI — full 4-gate (Session 51)
- [x] Phone number formatting in patient sheet (Session 54)
- [x] W9 link in Documents tab (Session 54)
- [x] Select All + checkboxes on all selectable docs (Session 54)
- [x] cosmos_documents registry — all doc lookups, KPIs, W9 resolution (Session 55)
- [x] Action bar fixed to viewport bottom (Session 55)
- [x] View/Regen button order — View primary right (Session 55)
- [x] Phase 4 — legacy url columns and patient_forms retired (Session 56)
- [x] Re-sign button fixed — opens signature pad (Session 57)
- [x] router.refresh() after regen — warnings clear instantly (Session 57)
- [x] KPI cards 3-column grid (Session 57)
- [x] todayStr() Eastern timezone fix (Session 57)
- [x] Discharge Pending workflow stage (Session 57)
- [ ] Appointment confirmation SMS — auto-trigger on booking
- [ ] Patient phone required at intake
- [ ] Notes tab persistence
- [ ] Realtime — referrals and appointments tables

### Stage 4 — MD Dashboard
- [x] MDClient patient list (`/md`) — legacy, retained for visit editor
- [x] MD V2 patient chart (`/md-v2/[patientId]`) — legacy, retained
- [x] MD Dashboard V3 (`/md-v3`) — enterprise workspace (Session 52)
- [x] MD Dashboard V3 — promoted as default MD dashboard (Session 53)
- [x] MD Dashboard V3 — RESULTS chip + md_viewed_at (Session 53)
- [x] MD Dashboard V3 — Documents tab (Session 53)
- [x] MD Dashboard V3 — cosmosmt.com DNS live (Session 53)
- [x] MD Dashboard V3 — phone formatting in patient sheet (Session 54)
- [x] MD Dashboard V3 — cosmos_documents W9 + doc resolution (Session 55)
- [x] MD Dashboard V3 — Phase 4 legacy columns retired (Session 56)
- [x] MD Dashboard V3 — V3 visit page at /md-v3/visit/[patientId] (Session 57)
- [x] MD Dashboard V3 — referral workspace overlay + visit picker (Session 57)
- [x] MD Dashboard V3 — workflow badges + 6 KPI cards (Session 57)
- [x] MD Dashboard V3 — selector routes to /md-v3 (Session 57)
- [x] PatientClinicalSheet — visit cards compact, correct order, cyan dates (Session 57)
- [ ] MD Dashboard V3 — SOAP structured pain/exam fields (new schema required)
- [ ] MD Dashboard V3 — clinical timeline
- [ ] Calendar timezone bug fix
- [ ] `/md` and `/md-v2` route retirement (code cleanup)

### Stage 5 — Admin
- [x] Admin Users — login email edit for superadmin (Session 51)
- [x] Admin Overview — KPI cards 3 per row (Session 51)
- [x] Doctor signature immediate DB persist on upload (Session 54)
- [x] Supervised provider W9 inheritance on save (Session 54)
- [x] doctors.is_default column + default doctor at intake (Session 57)

### Stage 6 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] Twilio SMS activation
- [ ] 000_initial_schema.sql removal/replacement
- [x] Phase 4 — retire patient_forms + url columns (Session 56) ✅

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend, Twilio
- [ ] SPF/DKIM for cosmosmt.com

---

## Referral Architecture — Session 50 Model (unchanged)

### Appointment-Driven Dashboard
- One row per `referral_appointments` record
- Multi-Referral reminder row (NEW bucket only) for MRI with unscheduled parts
- Individual appointment row navigates to `/referrals/[id]?appt=[uuid]`
- Multi-Referral row navigates to `/referrals/[id]` (all sessions)

### MRI Session Splitting Rules
- Max 2 body parts per session (FD chooses 1 or 2)
- Patient can spread across as many sessions as needed
- MRI referral status stays `new` throughout
- Closes only when ALL ordered body parts have sessions + ALL sessions have results

### Cancelled Appointment Lifecycle
- Cancel → `outcome = 'cancelled'` → RESCHEDULE row appears
- Rebook → cancelled appointment row **deleted** → RESCHEDULE row destroyed → new SCHEDULED row created
- History preserved in `referral_timeline`

### `outcome` Values (referral_appointments)
`null` (scheduled/pending) | `completed` | `cancelled` | `no_show`

---

## MD Referral Workspace Architecture (Session 51, updated Session 57)

### Routes
- **Overlay mode (V3):** Rendered inline on `/md-v3` via `MDDashboardV3` state — no navigation
- **Standalone route (legacy):** `/md/[patientId]/referrals?visit_id=` — server page.tsx → `ReferralWorkspace.tsx` (client)

### Referral Registry
13 entries in `REFERRAL_REGISTRY` array in `ReferralWorkspace.tsx`. To add a new referral type: add one entry to the registry + add a case to `ReferralFormRouter` switch. Nothing else changes.

### Form Contract
All 11 referral form components share identical optional props:
```ts
onBack?: () => void
onSaved?: (filename: string) => void
onDone?: () => void
```
`onDone` closes overlay in V3 mode. `onBack`/`router.back()` fires in standalone route mode. Backward compatible.
