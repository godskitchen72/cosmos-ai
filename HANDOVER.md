# Cosmos Medical Technologies — HANDOVER (July 9, 2026, Session 28)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed and live on
`cosmos-dashboard-nu.vercel.app`. Referral Management Module Phase 1 + 2
+ Phase 3 (partial) complete and live. Provider Directory seeded with 10
providers. FD scheduling workflow fully functional end-to-end.

---

## Completed This Session (Session 28)

### Referral Dashboard — Full FD Scheduling Workflow

**ReferralSheet.tsx** — Appointment tab rebuilt from read-only to fully
functional three-state workflow:
- **Schedule form** — shown when no current appointment exists or FD taps
  Reschedule. Fields: Date (required), Time, Location, Confirmation #.
  Calls `scheduleAppointment()` Server Action.
- **Current appointment card** — shows date/time/location/conf# with three
  action buttons: ✓ Patient Confirmed, Record Outcome, 🔄 Reschedule.
- **Patient confirmation** — writes `patient_confirmed = true` +
  `patient_confirmed_at` directly via Supabase client. Auto-advances status
  to `patient_confirmed` if currently `scheduled`.
- **Record Outcome** — inline dropdown (Completed / No Show / Rescheduled)
  + optional notes. Updates `referral_appointments.outcome` + advances
  referral status to match.
- **Prior appointments** — read-only history cards below current card.

### Referral Actions — Full Service Key Rewrite

`actions.ts` fully rewritten Session 28. All DB operations now use
`supabaseServer` (service key) — previously used `createServerClient` with
anon key + session cookie, causing silent RLS failures for read operations
and unhandled Server Action errors for writes.

Key changes:
- All write actions (`createReferral`, `updateReferralStatus`,
  `scheduleAppointment`, `addReferralNote`, `uploadReferralResult`) use
  `supabaseServer` for all DB writes.
- `getActorId()` replaces `getClient()` — resolves session user ID for
  attribution only; failure falls back to `null` rather than throwing.
- All write actions return `{ error: string }` instead of throwing — callers
  check `result.error` and call `toastError()` directly. No unhandled Server
  Action exceptions.
- Read-only actions (`listReferrals`, `getReferralMetrics`, `getReferralTypes`,
  `getReferralProviders`) also use `supabaseServer`.
- `listReferrals` now joins `patients` for `first_name`/`last_name` —
  returns `patient_name` field on each summary row.
- **Column name corrections:** all actions now use correct schema column names:
  `created_by_user_id` (referrals), `changed_by_user_id` (status_history),
  `actor_user_id` (timeline), `author_user_id` (notes),
  `uploaded_by_user_id` (documents), `location_name` (appointments).

### Schema — Attribution Columns Made Nullable

Five attribution columns dropped NOT NULL constraint (previously blocking
all inserts from seed route and server actions without a user session):
```sql
ALTER TABLE referrals ALTER COLUMN created_by_user_id DROP NOT NULL;
ALTER TABLE referral_status_history ALTER COLUMN changed_by_user_id DROP NOT NULL;
ALTER TABLE referral_appointments ALTER COLUMN created_by_user_id DROP NOT NULL;
ALTER TABLE referral_notes ALTER COLUMN author_user_id DROP NOT NULL;
ALTER TABLE referral_documents ALTER COLUMN uploaded_by_user_id DROP NOT NULL;
```

### Referral Dashboard — Patient Name Column + Dark Dropdowns

**ReferralDashboard.tsx** rebuilt Session 28:
- Table recolumned: 4 mobile-first columns — **Patient** (name + type +
  urgency badge), **Status**, **Appt**, **Date**. Patient name visible
  without horizontal scroll.
- All three `<select>` filter dropdowns replaced with `DarkSelect` — custom
  dark pill dropdown with `useRef` outside-click dismiss. Eliminates OS
  light-theme native picker on Android.
- `DarkSelect` is a local component inside `ReferralDashboard.tsx` —
  not extracted to shared UI.
- Refresh button now calls `getReferralMetrics()` + `listReferrals()` in
  parallel — metric cards update on refresh, not just the table.
- `resolvedRole` derived from `sessionStorage.getItem('cosmos_license_type')`
  in `useEffect` — overrides the `userRole="md"` prop from `page.tsx`.

### Auth — `cosmos_license_type` Written for All Roles

`app/page.tsx` line 118 (the `else` branch covering FD/billing/admin/
superadmin): `sessionStorage.setItem('cosmos_license_type', prof.role)` now
added before `cosmos_login_marker`. Previously only MD/PA/NP roles wrote this
value (from `doctors.license_type`). FD users now correctly resolve as
`'frontdesk'`, enabling the Schedule form to appear in `ReferralSheet`.

### FD Dashboard — Referrals Nav Button

`app/dashboard/DashboardClient.tsx` — 🔗 Referrals button added to the
Patients tab action row (line 679), `window.location.href='/referrals'`.
FD can now navigate to the full referral dashboard without a URL.

### Lifecycle Simplification — No Auth Required in Your Business Model

`VALID_TRANSITIONS` in `types.ts` simplified for actual business model
(no insurance pre-authorization required):
- `new: ['cancelled']` — FD schedules directly via Appointment tab (which
  auto-advances to `scheduled`); no manual Move To needed.
- `scheduling` and `auth_required` statuses preserved in DB/types for data
  integrity but removed from Move To UI on `new` status.
- `scheduleAppointment()` bypasses `VALID_TRANSITIONS` for direct status
  update: writes `status = 'scheduled'` + inserts status history row
  directly via `supabaseServer` without going through `updateReferralStatus`.

### CosmosUI — Toast System Fixed

`app/components/ui/CosmosUI.tsx` rewritten Session 28:
- `toastSuccess()` now wires to `_addToast` (auto-dismiss green toast,
  3.5s, ✓ icon, `#0a1a12` background, `#2ee08a` text) — previously
  incorrectly routed to `AlertModal` (blocking red modal).
- `toastError()` correctly routes to `AlertModal` (blocking red modal,
  requires OK tap).
- `ToastContainer` renders bottom-anchored stack of auto-dismiss toasts.
- Toast types: `success` (green), `info` (cyan), `error` (red).
- `AlertModal` border/text color changed to red (`#e74c3c`) — was cyan.

### Dev Generator — Referral Seeding + FK Fix

**Wipe route FK fix:** `app/api/wipe-patients/route.ts` — referral subtree
now deleted before `patient_visits` to satisfy `referrals_visit_id_fkey`:
```
referral_notifications → referral_timeline → referral_status_history →
referral_notes → referral_documents → referral_appointments →
referrals → visit_line_items → patient_visits → patient_forms →
appointments → patients
```

**`/api/seed-referrals/route.ts`** — new POST endpoint. Accepts
`{ patient_id, visit_id, referral_type_code, clinical_reason }`. Uses
`supabaseServer` to insert `referrals` + `referral_status_history` +
`referral_timeline` rows. Called by dev generator after each successful PDF.
Bypasses RLS without session cookie requirement.

**Dev generator** (`app/dev/page.tsx`) — referral seeding integrated:
- After each `generate-{type}` PDF succeeds, calls `/api/seed-referrals`
  with the correct `referral_type_code` from `REFERRAL_TYPE_CODE` map.
- ICD-10 excluded (not a referral type).
- Results log compacted: all referral results per visit shown on one line:
  `MRI ✓ · PT ✓ · Ortho ✓`. ✓ = PDF + lifecycle record seeded. ✗ = failed.
- `waking API...` and per-referral intermediate lines removed.

### Provider Directory — Admin CRUD

**`app/admin/components/ReferralProvidersSection.tsx`** — new component:
- Full CRUD: add, edit, deactivate/activate providers.
- Fields: Name (required), Facility Name, Specialty (required, dropdown),
  Phone, Fax, Email, Street, City, State, ZIP, NPI, Avg Turnaround Days,
  Preferred Contact, Notes, Active toggle.
- Search bar + Active Only / Show All toggle.
- Deactivate/Activate with confirm modal. No hard delete.
- Inactive providers shown at reduced opacity with INACTIVE badge.

**`app/admin/page.tsx`** — 🔗 Ref. Providers tab added to sidebar and
render block.

**10 providers seeded** via Supabase SQL with realistic NY-area data,
one per specialty: Physical Therapy, MRI/Radiology, Orthopedic, Pain
Management, Neurology, VNG/Vestibular, Chiropractic, ANS Autonomic,
DME/Equipment, Pharmacy. All set `email = 'referralsout@outlook.com'`.

---

## Completed Prior Sessions (carried forward)

### Session 27

TurboSMTP replaced with Resend. Domain `cosmosmt.com` verified.
`patient_forms` RLS enabled. RX and DME dual-write bridges added.
`ReferralsTabV2.tsx` import cleanup.

### Session 26

Referral Management Module Phase 1 route deployment. Five `/referrals`
route files written to repo and deployed. MD dashboard Referrals nav button.
Dual-write bridge for PT, Ortho, Pain Mgmt, VNG, ANS.

### Session 25

Referral Management Module Phase 1 + 2 designed and partially deployed.
Migration 026 (9 tables) deployed. shadcn/ui approved for `/referrals`.

### Session 24

Re-login hang fully resolved. `setLoading(false)` on success path.
`cosmos_login_marker` sessionStorage guard. Direct localStorage token removal.

### Session 23

PC NPI full-stack (Migration 025). MD V2 dashboard as primary MD chart.
TurboSMTP closed.

### Session 22

Billing packet ZIP server-side. Attorney email feature via TurboSMTP
(now Resend). `attorney_email` column (Migration 024).

### Session 21

`patid_doa_dos_type.pdf` file naming convention. ZIP download feature.

### Session 20

`PatientChart.tsx` refactored. Custom styled pickers. `ReferralGrid`.

### Session 19

Admin horizontal tab strip → collapsible sidebar.

### Session 18

Monolithic `app/admin/page.tsx` split into 9 files.

### Session 17

PIN lockout. TOTP MFA. Audit log system.

### Session 13–16

CosmosUI notification standard. JWT auth on 15 API endpoints. Session timeout.

### Sessions 8–12

Enterprise hardening Stage 1. Biller Dashboard. Provider card hierarchy.

### Sessions 4–7

Auth via Supabase. Scheduling Phase 3. Superadmin dashboard. RLS audit.

### Sessions 1–3 + Genesis

Cosmos origin. Streamlit → Next.js/FastAPI migration. NF-2/NF-3/AOB
PDF pipelines. CPT/ICD-10 system. Front Desk Command Dashboard.

---

## Open Items, Priority Order

1. **`patient_forms` visit_id backfill.** Query:
   `SELECT form_type, visit_id, filename FROM patient_forms WHERE patient_id = 'PT331111'`
   — then backfill any null `visit_id` rows with the correct visit UUID.

2. **CPT codes `provider_type` product decision needed.** All 34 codes are
   MD only. Non-MD providers see empty CPT picker. Add `General` type or
   separate sets.

3. **DEV fill-all PCE button** — remove from `VisitTab.tsx` before go-live.

4. **Provider assignment on referral sheet.** FD cannot yet assign a provider
   to a referral from the Sheet. `referral_providers` table is populated (10
   records) but no UI exists to assign one. Planned: dropdown in Overview tab
   or Schedule form; assigned provider's address auto-fills Location field.

5. **Overdue detection.** Metric card exists and counts correctly; no
   automated flagging or FD alert beyond the ⚠ indicator in the table.

6. **`/referrals` nav from Admin dashboard.** FD and MD have nav buttons;
   Admin sidebar has no path to `/referrals` yet.

7. **Sidebar rollout to FD, MD, Biller.** Deferred.

8. **Doctor mailing address data.** Gottesman and Kramer placeholders.
   Test only.

9. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

10. **Vercel Pro upgrade.** Eliminates cold starts. Do at go-live.

11. **Resend HIPAA BAA.** Must be signed before go-live with real patient
    data alongside Supabase, Render, Vercel.

---

## Enterprise Hardening Checklist

### Stage 1 — Data Integrity ✅ Complete
- [x] FK constraints (Session 10)
- [x] Full RLS audit (Session 12)
- [x] NOT NULL constraints (Session 12)

### Stage 2 — Security ✅ Complete (except BAA)
- [x] API JWT authentication (Session 13)
- [x] Session timeout (Session 13)
- [x] Failed PIN attempt lockout (Session 17)
- [x] MFA for admin/billing/superadmin — TOTP, 30-day device trust (Session 17)
- [x] Audit log table — DB triggers + frontend logging (Session 17)
- [x] `patient_forms` RLS enabled (Session 27)
- [ ] HIPAA BAA with Supabase, Render, Vercel, Resend — administrative

### Stage 3 — Infrastructure
- [ ] Staging environment
- [ ] GitHub Actions CI
- [ ] Database indexes on FK and common filter columns
- [ ] Supabase point-in-time recovery confirmed enabled
- [ ] Error monitoring (Sentry or equivalent)

### Stage 4 — Code Quality
- [x] Admin page refactor (Session 18)
- [ ] Replace all `print()` in `cosmos-api` with structured logging
- [ ] Eliminate remaining `any` types — TypeScript strict mode
- [ ] React error boundaries on all dashboard surfaces
- [ ] Loading states on all data fetches

### Stage 5 — Product & UX
- [x] Admin sidebar nav (Session 19)
- [x] MD V2 shadcn chart (Session 23)
- [x] MDClient shadcn list (Session 23)
- [x] Login shadcn (Session 23)
- [x] Re-login hang fixed (Session 24)
- [x] Referral Management Module Phase 1 + 2 (Session 25)
- [x] Referral Module Phase 1 route deployed (Session 26)
- [x] Referral dual-write: PT, Ortho, Pain Mgmt, VNG, ANS (Session 26)
- [x] MD dashboard Referrals nav button (Session 26)
- [x] Referral dual-write: RX, DME (Session 27)
- [x] ReferralsTabV2 import cleanup (Session 27)
- [x] FD scheduling workflow — full end-to-end (Session 28)
- [x] FD dashboard Referrals nav button (Session 28)
- [x] Provider Directory CRUD in Admin (Session 28)
- [x] `cosmos_license_type` written for all roles on login (Session 28)
- [x] CosmosUI toast system fixed — success auto-dismiss, error modal (Session 28)
- [x] Patient name in referral table (Session 28)
- [x] Dark custom dropdowns in referral dashboard (Session 28)
- [x] Metrics refresh on Refresh button (Session 28)
- [x] Dev generator referral lifecycle seeding (Session 28)
- [x] Wipe route FK constraint fixed (Session 28)
- [ ] Provider assignment on referral sheet
- [ ] Referral Module Phase 3 remaining (overdue detection, notifications)
- [ ] Sidebar rollout — FD, MD, Biller dashboards
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] Data retention and deletion policy
- [ ] Patient data export capability

---

## Known Architecture Gaps

**Provider assignment not yet wired.** `referral_providers` table has 10
active records but no UI exists in `ReferralSheet` to assign a provider to
a referral. The `provider_id` FK on `referrals` is nullable — no data
integrity risk, just a missing FD workflow step.

**`/referrals/page.tsx` userRole prop.** `userRole="md"` still hardcoded as
the prop from the server component. `ReferralDashboard.tsx` now overrides
this client-side from `sessionStorage.cosmos_license_type` in `useEffect`,
so the effective role is correct for all logged-in users. The prop default
matters only if sessionStorage is empty (e.g. hard refresh without re-login).

**`scheduling` and `auth_required` statuses.** These exist in the DB and
type system but are no longer reachable via the Move To UI from `new` status
(removed Session 28 — business model has no pre-auth requirement). Existing
rows with these statuses can still transition to `scheduled` or `cancelled`.

**`/referrals` nav missing from Admin dashboard.** FD has the button in
Patients tab; MD has it in MDClient. Admin sidebar has no path yet.

**MD V2 as primary route:** `/md-v2/[patientId]` is the primary MD chart.
`/md/[patientId]` is the clinical visit entry point.

**shadcn exception extended Sessions 23 + 25:** MD V2, MDClient, login,
`/referrals`. `ARCHITECTURE.md` updated Session 25.

**`billing_npi` is the only NPI used in PDF forms.** All `forms/*.py` confirmed.

**`pc_npi` column:** Migration 025. No on-disk SQL file.

**Auth server-component gap:** `createServerClient` (not
`createServerComponentClient`) is the correct export from
`@supabase/auth-helpers-nextjs`. Cookie wrapper required. `getActorId()` in
`actions.ts` is the correct pattern — resolves session user ID for attribution
only; DB writes use `supabaseServer` (service key) regardless.

**`patient_visits.doctor_id` missing:** relies on `patients.doctor_id`.

**PA/NP users:** `user_profiles.doctor_id` must point to own `doctors` row.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null `doctor_id`.

**`cosmos_license_type` in sessionStorage:** Now written for all roles on
login (Session 28). FD writes `'frontdesk'`; MD/PA/NP write from
`doctors.license_type`; admin/billing write `prof.role`.

**Session timeout SSR:** `useSessionTimeout` reads sessionStorage inside
`useEffect` to avoid SSR crash.

**Superadmin timeout exemption:** Superadmin gets `cosmos_session_timeout_minutes = '0'`
at login. Hook treats `0` as disabled.

**`nf3_preflight_passed` gate:** FD submission requires preflight check.

**`biller_md_flags` fetch condition:** `billing/page.tsx` fetches both
pending and rejected-undismissed flags via PostgREST `.or()`.

**Audit log user attribution:** DB trigger entries show "System".

**MFA `localStorage` device trust:** Key format:
`cosmos_mfa_trusted_{email_normalized}`. 30-day expiry as Unix timestamp.

**`login_attempts` RLS:** Must include `anon` role.

**Admin sidebar `localStorage`:** Key `cosmos_admin_sidebar_open`.

**`ARCHITECTURE.md` migration list gap:** Migrations 020-026 added in prior
sessions. No migrations this session.

**`_fmt_date` fallback:** Returns `"00000000"` when null/missing.

**`REFERRAL_FORM_CONFIG` dual keys:** `tag` = DB value, `fn_type` = filename.

**Zip `patient_forms` visit_id gap:** legacy null rows silently excluded.

**`send_billing_endpoint.py` register pattern:** Extracted to separate file.

**`attorney_email` auto-fill:** Populated from `lawyers.email` at FD intake.

**Login `cosmos_login_marker`:** Set in sessionStorage after successful login.

**Supabase auth token localStorage key:**
`sb-ttudxnzmybcwrtqlbtta-auth-token`.

**Referral dual-write is fire-and-forget** — `createLifecycleRecord()` never
awaited; failure console-logged only; never surfaces to MD or rolls back PDF.

**Referral modality derived from selected keys (MRI only)** — CT: `ct.*`;
MRA: `mri.mra.*`; MRI: all other `mri.*`. PT/Ortho/Pain Mgmt/VNG/ANS/RX/DME
use static type code lookup only.

**`referral_types` codes confirmed** — `.eq('code', ...)` is the correct
lookup. Codes: MRI, CT, MRA, ULTRASOUND, PT, ORTHO, PAIN-MGMT, EMG, VNG,
ANS, RX, DME. All 12 seeded.

**`referral_appointments.location_name`** — column is `location_name` not
`location`. Confirmed Session 28. All code corrected.

**`referral_appointments.created_by_user_id`** — nullable as of Session 28
ALTER TABLE. Same for `referral_status_history.changed_by_user_id`,
`referral_timeline.actor_user_id`, `referral_notes.author_user_id`,
`referral_documents.uploaded_by_user_id`.

**Vercel preview URL domain isolation** — session cookies are scoped to the
aliased domain (`cosmos-dashboard-nu.vercel.app`). Preview deployment URLs
(`*-godskitchen72s-projects.vercel.app`) have separate cookie scope. Always
test on the aliased domain.

**Resend domain verified** — `cosmosmt.com` sending via `admin@cosmosmt.com`.
Full-access API key stored as `RESEND_API_KEY` in Render env.

**`patient_forms` RLS** — enabled Session 27. Existing `authenticated full
access` ALL policy was already present from Session 12.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/referrals/actions.ts` | ★ Verified-final (Session 28 — service key rewrite, correct column names) |
| `cosmos-dashboard/app/referrals/ReferralSheet.tsx` | ★ Verified-final (Session 28 — scheduling workflow) |
| `cosmos-dashboard/app/referrals/ReferralDashboard.tsx` | ★ Verified-final (Session 28 — patient name, dark dropdowns, metrics refresh) |
| `cosmos-dashboard/app/referrals/types.ts` | ★ Verified-final (Session 28 — simplified transitions) |
| `cosmos-dashboard/app/referrals/page.tsx` | ★ Verified-final (Session 28 — debug wrapper reverted) |
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 28 — toast system rewrite) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 28 — cosmos_license_type for all roles) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 28 — Referrals nav button) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 28 — Ref. Providers tab) |
| `cosmos-dashboard/app/admin/components/ReferralProvidersSection.tsx` | ★ Verified-final (Session 28 — new file) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 28 — referral seeding, compact log) |
| `cosmos-dashboard/app/api/wipe-patients/route.ts` | ★ Verified-final (Session 28 — FK order fix) |
| `cosmos-dashboard/app/api/seed-referrals/route.ts` | ★ Verified-final (Session 28 — new file) |
| `cosmos-dashboard/app/md-v2/[patientId]/ReferralsTabV2.tsx` | ★ Verified-final (Session 27 — import cleanup) |
| `cosmos-dashboard/app/md/[patientId]/rx/RxReferral.tsx` | ★ Verified-final (Session 27 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/dme/DmeReferral.tsx` | ★ Verified-final (Session 27 — dual-write bridge) |
| `cosmos-api/send_billing_endpoint.py` | ★ Verified-final (Session 27 — Resend rewrite) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 26 — Referrals button) |
| `cosmos-dashboard/app/md/[patientId]/pt/PtReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/ortho/OrthoReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/vng/VngReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/ans/AnsReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 25 — dual-write bridge) |
| `cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx` | ★ Verified-final (Session 25 — Referrals tab) |
| `cosmos-dashboard/app/md-v2/[patientId]/page.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/InfoTabV2.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/HistoryTabV2.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/page.tsx` | ★ Verified-final (Session 23 — redirect to `/md`) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 23) |
| `cosmos-api/database.py` | ★ Verified-final (Session 23 — `billing_npi`, `pc_npi`) |
| `cosmos-api/forms/nf2.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/pt.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/vng.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/pce.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/ortho.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/rx.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/ans.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/icd10.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/pain_mgmt.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 23 — `pc_npi`) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 23 — `pc_npi` in `BLANK_DOCTOR`) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/chart-shared.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitTab.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/ReferralGrid.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitHistoryTab.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/PatientInfoTab.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/lib/auditLogger.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/hooks/useSessionTimeout.ts` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (Session 11) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 22) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 22) |
| `cosmos-api/main.py` | ★ Verified-final (Session 22) |

---

## Lessons Learned (carried forward)

- **`cat > file << 'ENDOFFILE'` heredoc is the reliable full-file write method**
- **Chrome silently saves re-downloads as `filename-1.ext`** — always `ls -lt` before `cp`
- **Tailwind purge eliminates classes not present at build time** — use inline `style={{}}` as fallback
- **`grep` multi-line fetch pattern gives false positives** — view actual lines before concluding header is missing
- **MFA `localStorage` device trust uses email-derived key** — clearing localStorage forces re-challenge
- **Supabase `mfa.listFactors()` returns `factors.totp` array** — filter by `status === 'verified'`
- **`login_attempts` RLS must include `anon` role** — lockout check runs before authentication
- **Audit log DB triggers show "System" for user** — no PostgreSQL session context
- **TanStack Table data prop must be memoized** — passing a non-memoized filtered array causes infinite re-renders
- **Biller W9 badge requires supervisor-chain resolution**
- **Dev generator Render cold-start pattern** — warm-up ping before each patient's referral batch
- **`/tmp` does not persist in Termux** — use `~/`
- **`pathlib.Path.home()` returns `/root`** — use `os.path.expanduser('~')`
- **React fragments inside CSS grid don't create grid items**
- **`database.py` prefixes all doctor fields** — `license_number` → `doctor_license_number`
- **W9 is a billing entity document, not a provider document**
- **AOB assigns benefits to the billing entity, never the treating provider**
- **NF-3 Section 16 LICENSE field is not NPI**
- **`patients` primary key is `patient_id` (text)** — format: `PT457696`
- **Supervised providers legitimately have null mailing addresses**
- **CosmosUI `toastSuccess` was incorrectly routed to `AlertModal`** — fixed Session 28; `toastSuccess` now auto-dismiss green toast
- **New screens must mount `<AlertModal />` and `<ConfirmModal />`**
- **`sessionStorage` reads must be in `useEffect`**
- **Bash history expansion breaks inline `python3 -c` with `!`**
- **Render env var changes trigger automatic redeploy**
- **`~/storage/downloads/` writes can silently fail** — verify with `wc -l` or `ls`
- **Large file refactors: read full source before splitting**
- **`shared.tsx` pattern: all cross-section helpers in one file**
- **Sidebar `localStorage` persistence: initialize in `useEffect` to avoid SSR hydration mismatch**
- **Sidebar hover states on plain `<button>` elements require inline handlers**
- **Edit forms in sidebar layout must render at top of section**
- **Patch script `old` anchor must match on-disk state exactly** — always `grep -n` to confirm
- **Termux heredoc buffer limit ~250 lines** — large heredocs truncate silently; split files >~250 lines
- **Line-number Python insert** (`lines.insert(N, text)`) is reliable when anchor-based patch fails
- **Submit button persistence after action** — after any Supabase update that changes list membership, update local state immediately
- **Login perf: merge parallel `practice_settings` reads**
- **CosmosUI notification standard (Session 20):** single-record CRUD → toast; bulk/destructive → AlertModal
- **NF-2 signature key mismatch** — always verify field keys against DB column names
- **CPT CSV import parser fallback** — always require explicit header match; never fall back to position
- **Supabase CSV export uses `"null"` string** — not Python `None` or empty
- **`pceData` must hydrate from existing visit on load**
- **PDF filename convention (Session 21)** — `patid_doa_dos_type.pdf`
- **`_fmt_date` fallback is `"00000000"`** — signals missing date, not a code bug
- **Zip requires `patient_forms.visit_id`** — rows with `visit_id = null` silently excluded
- **Supabase service key not in Termux env** — use Supabase dashboard SQL editor for ad-hoc queries
- **Fresh doc uploads required before end-of-session updates**
- **`send_billing_endpoint.py` register pattern (Session 22)**
- **`lawyers.email` is the attorney email source**
- **Zip filename convention (Session 22):** `patid_doa_dos_billing_packet.zip`
- **Next.js 15 async params** — server components must use Promise params and `await params`
- **Dynamic route folder naming in Termux** — use Python `os.makedirs` not `mkdir` for bracket folders
- **`billing_npi` is the only NPI key used in PDF forms**
- **PC NPI field only shown for providers with PC corp**
- **Re-login hang root cause (Session 24)** — missing `setLoading(false)` on success path
- **`supabase.auth.signOut()` inside `handleLogin` causes hang**
- **Supabase localStorage token key** — `sb-ttudxnzmybcwrtqlbtta-auth-token`
- **`cosmos_login_marker` sessionStorage pattern**
- **Patch anchor drift** — after multiple iterative patches to the same file, prefer full clean rewrite
- **On-screen debug log pattern** — `debugLog` state + `dlog()` helper + monospace cyan panel
- **`autoComplete="new-password"` suppresses browser saved credentials entirely**
- **Referral dual-write is fire-and-forget**
- **Referral modality derived from selected keys (MRI only)**
- **Shared types between new module and existing components** — deploy module files together or inline until live
- **Supabase SQL editor RLS prompt** — always choose "Run without RLS" when migration SQL includes explicit ENABLE ROW LEVEL SECURITY
- **Migration 026 run in 3 blocks**
- **`createServerComponentClient` not exported** — use `createServerClient` from `@supabase/auth-helpers-nextjs` with explicit cookie wrapper
- **Vercel preview URL domain isolation** — always test on aliased domain `cosmos-dashboard-nu.vercel.app`
- **File repeated patch corruption** — after 3+ patches to the same file, restore from `git checkout HEAD -- <file>` before applying further changes
- **Python `os.path` in Termux** — use `/data/data/com.termux/files/home/` not `/root/`
- **`referral_types` codes confirmed** — all 12 seeded
- **`patient_forms` RLS gap pattern** — always verify both policy existence AND `relrowsecurity` together
- **Resend restricted API key** — use full-access key for domain management API calls
- **Porkbun DNS add record** — use Manual tab; Host field takes subdomain only
- **Resend domain ID** — get from `GET /domains` API
- **Referral Server Actions must use `supabaseServer`** — anon key + session cookie does not reliably reach `authenticated` RLS policies on Vercel server components; service key bypasses RLS safely for all referral writes (Session 28)
- **Referral schema column names** — `location_name` (not `location`), `created_by_user_id`, `changed_by_user_id`, `actor_user_id`, `author_user_id`, `uploaded_by_user_id` — confirmed against `information_schema.columns` Session 28
- **Attribution columns made nullable** — referral subtree attribution columns all dropped NOT NULL Session 28; dev seeding passes `null`, production writes pass `actorId`
- **`VALID_TRANSITIONS` blocks `scheduleAppointment` status advance** — `new → scheduled` not in transition map; `scheduleAppointment` must write status directly via `supabaseServer` bypassing `updateReferralStatus`
- **`cosmos_license_type` not written for FD on login** — only MD/PA/NP wrote this value; fixed Session 28 to include all roles from `prof.role`
- **`referral_providers` table populated** — 10 providers seeded Session 28 via SQL; `email = 'referralsout@outlook.com'` for all
