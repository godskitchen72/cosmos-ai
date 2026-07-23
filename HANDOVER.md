# Cosmos Medical Technologies — HANDOVER (July 23, 2026, Session 56 — Close)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed and live as of Session 56 close.

**Production status:** `cosmosmt.com` fully live. MD Dashboard V3 is the default MD dashboard. FD Dashboard V2 is the default FD dashboard. `cosmos_documents` is the sole source of truth for all generated PDFs — Phase 4 complete. `patient_forms` table and all legacy url columns dropped from production DB.

**Dev environment status:** `cosmos-dev` Supabase project fully operational. Phase 4 schema drop should also be applied to cosmos-dev (not yet done — see open items).

**Root cause learned (Session 52):** Server component `page.tsx` files must NOT call `supabase.auth.getUser()` + `redirect()` — this causes the page to 404 in production. Auth is handled by middleware only. `page.tsx` files must use `supabaseServer` for data fetches directly, same pattern as `dashboard-v2/page.tsx`. This applies to all future server page components.

---

## Completed This Session (Session 56)

### MIGRATIONS.md — `patients.intake_url` debt entry expanded ✅
The one-liner in Known Technical Debt was expanded to include column type, failure mode, verification query, and remediation `ALTER TABLE` statement.

**File:** `MIGRATIONS.md`

### cosmos_documents Phase 4 — Legacy retirement complete ✅

**cosmos-dashboard** (`a202451` — 6 files, 643 deletions):
- `FDDashboardV2.tsx` — `hasAOB` prop added to `<FDPatientSheet>` render; `nf2_url`, `aob_url`, `intake_url` removed from `Patient` interface
- `FDPatientSheet.tsx` — full Phase 4 rewrite: `hasAOB: boolean` prop added; all `patient.aob_url` / `patient?.aob_url` presence checks replaced with `hasAOB`; `handleGenerate` / `handleRegenerate` key type changed from `'nf2_url' | 'aob_url' | 'intake_url'` to `'nf2' | 'aob' | 'intake'`; `FDVisitsTab.load()` PCE query replaced with `cosmos_documents`; `FDVisitsTab.isReady()` AOB check uses `hasAOB`; `docIssues`, Document Status, Timeline tab all use `hasAOB`; `nf2_url`, `aob_url`, `intake_url` removed from `FullPatient` interface
- `dv2_page.tsx` — `nf2_url`, `aob_url`, `intake_url` removed from patients select
- `mdv3_page.tsx` — `nf2_url`, `aob_url`, `intake_url` removed from patients select; `patient_forms` PCE query replaced with `cosmos_documents`
- `PatientClinicalSheet.tsx` — `nf2_url`, `aob_url`, `intake_url` removed from `Patient` interface
- `MDDashboardV3.tsx` — `nf2_url`, `aob_url`, `intake_url` removed from `Patient` interface

**cosmos-api** (`main.py`):
- `update_patient_url()` and `update_doctor_url()` helper functions deleted
- `url_field` assignments (`nf2_url`, `aob_url`, `intake_url`) removed from `/generate` route
- `update_patient_url()` call removed from `/generate` route
- NF-3 `patient_forms` fallback write block removed
- PCE `patient_visits.pce_url` update and `patient_forms` fallback write block removed
- Referral dispatch `patient_forms` fallback write block removed
- W9 `update_doctor_url()` call removed
- `generate-zip` `patient_forms` fallback read block removed; `nf2_url`, `aob_url` removed from patients select
- `generate-visit-packet` `patient_forms` fallback read and write blocks removed
- Module docstring updated to reflect Phase 4 completion

**Production DB (Migration 034):**
- `patients.nf2_url` dropped
- `patients.aob_url` dropped
- `patients.intake_url` dropped
- `patient_visits.pce_url` dropped
- `patient_forms` table dropped
- `NOTIFY pgrst, 'reload schema'` sent

**Verified:** Documents tab, AOB gate on Visits tab, Visit Packet rebuild, and new document generation all confirmed working exclusively from `cosmos_documents`.

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet Merge blocked for production use. Cold start causes "Failed to fetch" on referral saves. One click, $25/mo. **Pre-go-live blocker.**

2. **Twilio SMS activation.** All code live. Three steps:
   - Buy `+17185695200`
   - Update `TWILIO_FROM_NUMBER` in Render
   - Complete A2P 10DLC business registration

3. **Production patient phone data.** All `patients.phone` = `+19297683179`. Clear before go-live:
   ```sql
   UPDATE patients SET phone = NULL;
   ```

4. **W9 signature stretch — regenerate all 3 billing-entity doctor W9s.** W9 PDFs for Jim Carrey, Yury Gottesman, Don Kramer were generated before Session 54's signature stretch fix. Regenerate via Admin → Doctors → ↺ button for each. No code change needed.

5. **DEV artifacts removal.** PCE fill-all button in `VisitTab.tsx` + Dev Tools card in Admin panel.

6. **Patient phone required at intake.** `PatientFormV2.tsx` phone field must be required.

7. **Patient email required at intake.** `PatientFormV2.tsx` email field must be required.

8. **Appointment confirmation SMS trigger.** Wire `/notify/sms` into calendar booking save path.

9. **Phase 4 schema drop — cosmos-dev.** `patient_forms` table and url columns not yet dropped from `cosmos-dev`. Apply Migration 034 SQL to `tpwbgqfdznqtjqimxric` when convenient.

10. **`/md` and `/md-v2` route retirement.** Routes still in codebase. Safe to delete once MD V3 confirmed stable. Files to remove: `app/md-v2/` (entire directory). Keep `app/md/[patientId]/PatientChart.tsx` and all referral/visit editor files — still used by V3 Edit Visit and Start Visit buttons.

11. **`/md-v3` error boundary cleanup.** `app/md-v3/error.tsx` is a debug artifact. Remove when `/md-v3` is stable.

12. **`page.tsx` userRole hardcoded.** `/referrals/page.tsx` passes `userRole="md"` — role is resolved client-side from sessionStorage. Not a bug but should be cleaned up.

13. **Duplicate visit records investigation.** Some patients have multiple `patient_visits` rows for the same date.

14. **`000_initial_schema.sql` superseded.** Stale on disk — use pg_dump approach.

---

## Known Architecture Gaps (carried forward)

- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- Ghost session timeout is 0 — impersonation sessions never expire.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"`.
- `app/md-v3/error.tsx` debug artifact in production.
- `doctors.w9_url` for supervised providers is a copied value (not a FK) — if supervisor regenerates W9, supervised providers' `cosmos_documents` rows auto-update via `registry_upsert`, but `doctors.w9_url` still requires manual re-save or SQL backfill.
- Phase 4 schema drop not yet applied to cosmos-dev (open item #9).

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

NF-2 and NF-3 have their own inline injection loops (due to multi-field/keyword matching complexity) but now use the same expansion and `keep_proportion=True`.

**Key signature URL keys in `patient_data`:**
- Patient signature: `patient_signature_url`
- Doctor/treating provider signature: `doctor_signature_url`
- Supervisor signature: `supervisor_signature_url`
- Billing entity signature (supervisor or treating): `assignee_sig_url` (NF-3 only, computed inline)

**Note:** W9 signatures for all 3 billing-entity doctors (Jim Carrey, Yury Gottesman, Don Kramer) were generated before the stretch fix and remain stretched. Regenerate via Admin ↺ button (open item #4).

---

## W9 Inheritance Rule (Session 54, updated Session 55)

Supervised providers (PA, NP, DC, PT, PSY) never have their own W9 — they bill under their supervising MD's PC. Their `doctors.w9_url` is set to the supervisor's `w9_url` at save time in Admin (`DoctorsSection.tsx` `handleSave()`). Their `cosmos_documents` W9 row is inserted/updated pointing to the supervisor's W9 filename.

The FD dashboard resolves W9 via `cosmos_documents` `doctor_id` lookup in `FDDocumentsTab.load()` — which checks `supervising_provider_id` at load time and includes the supervisor's `doctor_id` in the query if present. No string-copying required at runtime.

All 7 providers confirmed in `cosmos_documents` registry as of Session 55.

---

## DocCard Checkbox Pattern (Session 54)

`DocCard` component in `FDPatientSheet.tsx` accepts optional `onSelect`/`isSelected` props. When provided and a file exists, a cyan checkbox renders inside the card border alongside the title. `staticDocs` array (computed at render time from `patientDocMap`) drives `allSelected` / `toggleSelectAll` logic.

Button order (Session 55): secondary action (Regen / Re-sign / Rebuild) on left, primary action (View / View Packet) on right — consistent across all cards.

---

## server page.tsx Pattern (Session 52 lesson, permanent)

```ts
export default async function PageName() {
  const supabase = supabaseServer
  // fetch data directly — NO auth.getUser(), NO redirect()
}
```

Calling `supabase.auth.getUser()` + `redirect('/login')` in a server page causes the route to fail silently in production (builds as static `f` type, serves 404). Middleware handles all auth — page components do data fetching only.

---

## Vercel Alias Convention (Session 52 lesson)

After each `vercel --prod --yes` deploy, the `cosmos-dashboard-nu.vercel.app` alias does NOT always update automatically. If the preview URL still shows an old build, run:

```bash
vercel alias <new-deployment-url> cosmos-dashboard-nu.vercel.app
```

Get the new deployment URL from `vercel ls | head -5`.

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

## MD Referral Workspace Architecture (Session 51)

### Route
`/md/[patientId]/referrals?visit_id=` — server page.tsx → `ReferralWorkspace.tsx` (client)

### Referral Registry
13 entries in `REFERRAL_REGISTRY` array in `ReferralWorkspace.tsx`. To add a new referral type: add one entry to the registry + add a case to `ReferralFormRouter` switch. Nothing else changes.

### Form Contract
All 11 referral form components share identical optional props:
```ts
onBack?: () => void
onSaved?: (filename: string) => void
```
When `onBack` is absent (standalone page route), `router.back()` fires as before — backward compatible.

### Shared Utilities
`app/md/[patientId]/lib/referralUtils.ts`:
- `getAuthToken()` — session JWT for API Authorization headers
- `viewReferralFile(filename)` — opens signed URL in new tab

### MRI / MRA / CT
Three separate focused forms in `app/md/[patientId]/mri/`:
- `MriForm.tsx` — spine + extremities + contrast (formType: `MRI`)
- `MraForm.tsx` — MRA studies (formType: `MRA`)
- `CtForm.tsx` — CT studies (formType: `CT`)
- `MriReferral.tsx` — retained for `/mri/page.tsx` standalone route only

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
- [ ] MD Dashboard V3 — SOAP structured pain/exam fields (new schema required)
- [ ] MD Dashboard V3 — clinical timeline
- [ ] `/md` and `/md-v2` route retirement (code cleanup)

### Stage 5 — Admin
- [x] Admin Users — login email edit for superadmin (Session 51)
- [x] Admin Overview — KPI cards 3 per row (Session 51)
- [x] Doctor signature immediate DB persist on upload (Session 54)
- [x] Supervised provider W9 inheritance on save (Session 54)

### Stage 6 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] Twilio SMS activation
- [ ] 000_initial_schema.sql removal/replacement
- [x] Phase 4 — retire patient_forms + url columns (Session 56) ✅

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend, Twilio
- [ ] SPF/DKIM for cosmosmt.com
