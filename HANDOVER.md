# Cosmos Medical Technologies — HANDOVER (July 21, 2026, Session 52 — Close)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed and live as of Session 52 close.

**Production status:** `cosmosmt.com` is live. MD Dashboard V3 deployed and operational. `cosmos-dashboard-nu.vercel.app` alias updated to latest build. Preview alias management now requires `vercel alias` CLI command after each deploy — Vercel auto-alias only fires on `main` branch pushes, not via `--prod --yes` flag.

**Dev environment status:** `cosmos-dev` Supabase project fully operational.

**Root cause learned (Session 52):** Server component `page.tsx` files must NOT call `supabase.auth.getUser()` + `redirect()` — this causes the page to 404 in production. Auth is handled by middleware only. `page.tsx` files must use `supabaseServer` for data fetches directly, same pattern as `dashboard-v2/page.tsx`. This applies to all future server page components.

---

## Completed This Session (Session 52 — Full)

### MD Dashboard V3 — New enterprise physician workspace at `/md-v3` ✅

Full enterprise MD dashboard replacing the legacy `/md` patient list. Deployed and live.

**Route:** `/md-v3` — server component `page.tsx` → `MDDashboardV3.tsx` (client)

**Features:**
- Header: Cosmos Medical branding, DashboardNav hamburger, physician name, date, today's appointment count
- KPI cards: Today (appointments), Waiting (no note yet), Billing (flags + missing), Urgent (treatment window expiring/expired) — each card filters the work queue
- TanStack Table work queue: Patient, Priority, Appt time, Last Visit, Carrier, Pain score, Note status, Results status, Billing status, Actions (Visit / Chart)
- Global search, column visibility toggle, sort by all columns, 20-row pagination
- Treatment window bar per patient (180-day DOA timer, color-coded: green/orange/red)
- Left border color per row: treatment window urgency or biller flag
- Supervised doctor support — shows supervised provider label on patient rows

**Patient Clinical Sheet** (right-side desktop, full-screen mobile):
- Opens on row tap
- Overview tab: demographics, accident/insurance, pain summary chips, document buttons (Intake/NF-2/AOB/Sig), latest visit ICD-10/CPT, open referrals
- Visits tab: full visit history with ICD-10/CPT per visit, billing status, Open Visit button
- Referrals tab: all referrals with status, appointments, Manage Referrals button
- SOAP tab: Subjective (complaints, accident type, role, care, work status, aggravating factors, radiation, meds/allergies), Objective (vitals, pain scores by region, cervical ROM), Assessment (prognosis, functional limitations, active ICD-10), Plan (orders, referrals link), Diagnoses (ICD-10 live), Procedures (CPT live). Fields without backend columns show COMING SOON badge.

**Files added:**
- `app/md-v3/page.tsx` — server component, data fetcher (matches dashboard-v2 pattern exactly)
- `app/md-v3/MDDashboardV3.tsx` — main client component
- `app/md-v3/components/PatientClinicalSheet.tsx` — right-side/full-screen patient sheet
- `app/md-v3/components/SOAPWorkspace.tsx` — SOAP documentation tabs
- `app/md-v3/error.tsx` — error boundary (debug artifact, can be removed)

**Dashboard picker:** MD V3 tile added to `SUPERADMIN_DASHBOARDS` in `app/page.tsx` (line 25, between MD/Doctor and Billing).

**Architectural decision (Session 52, locked):** Cross-role visual consistency adopted as platform standard — MD, FD, and future Billing dashboards share the same layout, nav, cards, table, and side-sheet interaction pattern. Data and actions differ by role; UX pattern is identical.

**Deferred to Session 53:**
- Sidebar nav (evaluated and deferred — separate session)
- SOAP structured pain/exam fields (requires new schema — migration needed)
- ICD-10 / CPT favorite/recent codes
- Signature center
- Task center
- Clinical timeline

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet Merge blocked for production use. One click, $25/mo.

2. **Twilio SMS activation.** All code live. Three steps:
   - Buy `+17185695200`
   - Update `TWILIO_FROM_NUMBER` in Render
   - Complete A2P 10DLC business registration

3. **Production patient phone data.** All `patients.phone` = `+19297683179`. Clear before go-live:
   ```sql
   UPDATE patients SET phone = NULL;
   ```

4. **DEV artifacts removal.** PCE fill-all button in `VisitTab.tsx` + Dev Tools card in Admin panel.

5. **Patient phone required at intake.** `PatientFormV2.tsx` phone field must be required.

6. **Patient email required at intake.** `PatientFormV2.tsx` email field must be required.

7. **Appointment confirmation SMS trigger.** Wire `/notify/sms` into calendar booking save path.

8. **`/md` route retirement.** Four files reference `/md`: `app/page.tsx` (lines 14, 18, 19, 24, 334), `app/md/[patientId]/PatientChart.tsx` (back button), `app/components/DashboardNav.tsx` (nav link), `app/md-v2/page.tsx` (redirect). When ready to promote `/md-v3`, update these four files. Do not retire `/md` until then.

9. **`/md-v3` error boundary cleanup.** `app/md-v3/error.tsx` is a debug artifact. Remove when `/md-v3` is stable.

10. **`page.tsx` userRole hardcoded.** `/referrals/page.tsx` passes `userRole="md"` — role is resolved client-side from sessionStorage. Not a bug but should be cleaned up.

11. **Duplicate visit records investigation.** Some patients have multiple `patient_visits` rows for the same date.

12. **`000_initial_schema.sql` superseded.** Stale on disk — use pg_dump approach.

---

## Known Architecture Gaps (carried forward)

- `patients.intake_url` exists only via manual SQL — not in any migration file.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- Ghost session timeout is 0 — impersonation sessions never expire.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"`.
- `app/md-v3/error.tsx` debug artifact in production.

---

## Critical Convention — Server Page Components

**Confirmed Session 52:** All `page.tsx` server components must follow the `dashboard-v2` pattern:

```ts
import { supabaseServer } from '@/lib/supabaseServer'
export const revalidate = 0
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
- [ ] Appointment confirmation SMS — auto-trigger on booking
- [ ] Patient phone required at intake
- [ ] Notes tab persistence
- [ ] Realtime — referrals and appointments tables

### Stage 4 — MD Dashboard
- [x] MDClient patient list (`/md`) — legacy, to be retired
- [x] MD V2 patient chart (`/md-v2/[patientId]`) — full chart, retained
- [x] MD Dashboard V3 (`/md-v3`) — enterprise workspace (Session 52)
- [ ] MD Dashboard V3 — SOAP structured pain/exam fields (new schema required)
- [ ] MD Dashboard V3 — signature center
- [ ] MD Dashboard V3 — task center
- [ ] MD Dashboard V3 — clinical timeline
- [ ] MD Dashboard V3 — sidebar nav
- [ ] `/md` route retirement (promote `/md-v3`)

### Stage 5 — Admin
- [x] Admin Users — login email edit for superadmin (Session 51)
- [x] Admin Overview — KPI cards 3 per row (Session 51)

### Stage 6 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] Twilio SMS activation
- [ ] 000_initial_schema.sql removal/replacement

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend, Twilio
- [ ] SPF/DKIM for cosmosmt.com
