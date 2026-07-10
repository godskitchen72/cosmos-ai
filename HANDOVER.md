# Cosmos Medical Technologies — HANDOVER (July 10, 2026, Session 31)

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
Session 31 priority queue exhausted. MRI session splitting workflow fully
operational end-to-end. Sentry error monitoring live on both services.
Migration 030 deployed — `referral_documents.appointment_id` ready.
Per-session result upload feature (Session 32 priority #1) not yet built.

---

## Completed This Session (Session 31)

### Infrastructure — DB Indexes ✅ CLOSED (Migration 028)

6 indexes added to Supabase. Pre-existing indexes confirmed extensive —
only 6 gaps found: `patient_visits` (patient_id, submitted_to_billing_at
partial WHERE NOT NULL, location_id), `biller_md_flags` (visit_id,
patient_id), `referrals` (referral_provider_id). All used `IF NOT EXISTS`.

### Infrastructure — Sentry Error Monitoring ✅ CLOSED

`cosmos-dashboard`: `@sentry/nextjs` installed. `sentry.client.config.ts`,
`sentry.server.config.ts`, `instrumentation.ts` created. DSN confirmed
working — test event received in Sentry dashboard.

`cosmos-api`: `sentry-sdk 2.64.0` installed. `sentry_sdk.init()` added to
`main.py` after `import supabase as sb`. `sentry-sdk>=2.64.0` added to
`requirements.txt`. Both deployed and confirmed.

Sentry projects: `cosmos-dashboard` + `cosmos-api` under `cosmosmedtechnologies`
org. Alert threshold: 1 occurrence. Notify via email.

### MRI Referral UI Fixes ✅ CLOSED

- Spine buttons now in rows of 2 (Cervical W/O | Cervical W/WO per row)
- W/O and W/WO mutually exclusive **per pair** (selecting one deselects sibling)
- CT / CAT Scan section dimmed and disabled when MRI is selected (no metal implant)
- CT available only when YES — CT only selected (metal implant present)

### MRI Session Splitting — Full Workflow ✅ CLOSED

**Product decisions recorded:**
- Max 2 body parts per MRI session
- FD manually selects which body parts go in each session (no auto-pairing)
- System auto-advances referral to `scheduled` when all sessions booked
- MRA and CT session splitting deferred (low priority)
- Provider email fires on assignment (existing) + per session save (new)
- Patient email fires per session save (existing behavior, requires patient email on file)

**Migration 029:** `referrals.body_parts text[]`, `referral_appointments.body_parts text[]`

**`MriReferral.tsx`:** `createLifecycleRecord()` now writes `body_parts[]`
to `referrals` — MRI spine + extremity labels only (MRA/CT excluded).
Spine button mutual exclusivity implemented via `SPINE_PAIRS` toggle logic.

**`types.ts`:** `ScheduleAppointmentInput` + `body_parts?: string[]`.
`ReferralSummary` + `body_parts: string[] | null`. `ReferralAppointmentRow`
+ `body_parts?: string[] | null`. `_session_appointment` field added to
`ReferralSummary` for per-row expansion. `current_appointment.outcome`
added.

**`actions.ts`:**
- `scheduleAppointment()` writes `body_parts` to `referral_appointments`
- Auto-advance logic: for MRI referrals, only advances to `scheduled` when
  `appointment_count >= ceil(body_parts.length / 2)`; non-MRI advances on
  first appointment as before
- `listReferrals()`: adds `body_parts`, `body_parts` (appts), `outcome`
  to select; expands MRI referrals with pending appointments into one row
  per session (`_session_appointment` field)
- Provider session email added to `scheduleAppointment()` — fires on every
  session save with date, time, body parts for that session

**`ReferralSheet.tsx`:**
- Overview tab: CLINICAL REASON + PROVIDER labels now bright green (`#19a866`)
- Overview tab: body parts shown as cyan chips below clinical reason
- Appointment tab: MRI Sessions card shows session counter, scheduled
  sessions with date + body parts, unassigned parts pool (select up to 2),
  schedule form visible when sessions remain
- Header: `body_part` text removed (moved to Overview tab)
- `sessionParts` state added; wired into `handleSchedule()`; cleared on
  cancel and after successful save

**`ReferralDashboard.tsx`:**
- UPCOMING KPI: now counts individual `referral_appointments` rows where
  `scheduled_date >= today` (was: referral records in scheduled status)
- OVERDUE KPI: two conditions — (1) open referral not updated in 14 days
  (excluding scheduled/patient_confirmed), (2) appointment date passed
  with no outcome recorded. Counts are summed.
- `isOverdue()` updated to match: stale OR missed appointment
- Upcoming row filter updated to match appointment-level definition
- Per-session rows: MRI referrals with pending appointments expand into
  one list row per session; each row shows date + body parts in cyan chips
- Session outcome filter: completed/no-show/rescheduled appointments
  excluded from session list display

### Migration 030 — appointment_id on referral_documents ✅ DEPLOYED

`referral_documents.appointment_id uuid REFERENCES referral_appointments(id)`
nullable. Index `idx_ref_docs_appointment_id` added. Migration run in
Supabase dashboard. No code changes yet — next session picks up here.

---

## Completed Prior Sessions (carried forward)

### Session 30

patient_forms ghost row cleanup. CPT codes → General. ReferralProviderRow
type cleanup. Migration 027 (patients.email). PatientForm email field.
PatientProfile email display. actions.ts sendEmail() Resend helper. Patient
appointment confirmation email. Provider assignment notification email with
MRI/Rx/DME PDF attachment. RESEND_API_KEY added to Vercel.

### Session 29

Full FD scheduling workflow on ReferralSheet. assignProvider() Server Action.
Document upload to referral-documents bucket. Overdue row flagging. Timeline
end-to-end. Dark dropdowns throughout ReferralSheet. Column audit — actions.ts.
shadcn exception scope corrected in AI_STYLE_GUIDE.md.

### Session 28

Full FD scheduling workflow. `actions.ts` service key rewrite. Column name
audit. CosmosUI toast system fixed. Patient name in referral table. Dark
custom dropdowns in dashboard. Provider Directory Admin CRUD. 10 providers
seeded. Dev generator referral seeding.

### Session 27

TurboSMTP replaced with Resend. Domain `cosmosmt.com` verified.
`patient_forms` RLS enabled. RX and DME dual-write bridges added.

### Session 26

Referral Management Module Phase 1 route deployment. Five `/referrals`
route files deployed. MD dashboard Referrals nav button. Dual-write bridge
for PT, Ortho, Pain Mgmt, VNG, ANS.

### Session 25

Referral Management Module Phase 1 + 2 designed and partially deployed.
Migration 026 (9 tables) deployed. shadcn/ui approved for `/referrals`.

### Session 24

Re-login hang fully resolved. `setLoading(false)` on success path.

### Session 23

PC NPI full-stack (Migration 025). MD V2 dashboard as primary MD chart.

### Session 22

Billing packet ZIP server-side. Attorney email feature via Resend.
`attorney_email` column (Migration 024).

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

### Sessions 13–16

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

1. **Per-session result upload — IN PROGRESS.** Migration 030 deployed.
   Next session: `uploadReferralResult()` accepts `appointment_id?`; sets
   `referral_appointments.outcome = 'completed'` on upload; checks all
   sessions complete → advances referral to `completed` → `needs_review`.
   Session cards in `ReferralSheet.tsx` get 📎 upload button + result badge.
   `ReferralsTabV2.tsx` shows result docs for completed/needs_review referrals.

2. **MRA/CT session splitting.** Deferred. Product decision pending on
   whether CT requires same 2-body-parts-per-session rule as MRI.

3. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

4. **Sidebar rollout — FD, MD, Biller.** Deferred.

5. **Doctor mailing address data.** All current records are test data.
   Real provider data entered at go-live onboarding.

6. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

7. **Vercel Pro upgrade.** At go-live.

8. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — must be signed
   before go-live with real patient data.

9. **SPF/DKIM records** for `cosmosmt.com` on Porkbun/Cloudflare — fixes
   email spam classification. At go-live.

10. **Twilio SMS integration.** Deferred. `sendSMS()` slots alongside
    `sendEmail()` in `actions.ts` when Twilio account is ready.

11. **Provider portal — token-gated referral view.** Phase 2.

12. **`getReferralProviders()` return type.** Still `any[]`.

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
- [x] Database indexes on FK and common filter columns (Session 31 — Migration 028)
- [x] Error monitoring — Sentry on cosmos-dashboard + cosmos-api (Session 31)
- [ ] Staging environment
- [ ] GitHub Actions CI
- [ ] Supabase point-in-time recovery confirmed enabled

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
- [x] CosmosUI toast system fixed (Session 28)
- [x] Provider assignment — Appointment tab (Session 29)
- [x] Document upload — referral-documents bucket (Session 29)
- [x] Overdue row flagging + filter fix (Session 29)
- [x] Timeline — writes and display fully working (Session 29)
- [x] Dark dropdowns throughout ReferralSheet (Session 29)
- [x] CPT codes provider_type → General (Session 30)
- [x] patient_forms ghost row cleanup (Session 30)
- [x] ReferralProviderRow type cleanup — types.ts (Session 30)
- [x] patients.email field (Migration 027) (Session 30)
- [x] Referral notifications — patient + provider emails (Session 30)
- [x] MRI/Rx/DME PDF attachment in provider notification email (Session 30)
- [x] DB indexes — Migration 028 (Session 31)
- [x] Sentry error monitoring — both services (Session 31)
- [x] MRI spine UI fixes — rows of 2, per-pair exclusivity, CT dim (Session 31)
- [x] MRI session splitting — body parts pool, per-session assignment (Session 31)
- [x] Provider session email per appointment save (Session 31)
- [x] UPCOMING KPI → individual appointment count (Session 31)
- [x] OVERDUE KPI → stale + missed appointment conditions (Session 31)
- [x] Per-session rows in referral dashboard list (Session 31)
- [x] Migration 029 — referrals.body_parts, referral_appointments.body_parts (Session 31)
- [x] Migration 030 — referral_documents.appointment_id (Session 31)
- [ ] Per-session result upload + auto-close + MD review (Session 32)
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

**`/referrals/page.tsx` userRole prop.** `userRole="md"` still hardcoded as
the prop from the server component. `ReferralDashboard.tsx` overrides this
client-side from `sessionStorage.cosmos_license_type` in `useEffect`. The
prop default matters only if sessionStorage is empty (hard refresh without
re-login).

**`scheduling` and `auth_required` statuses.** Exist in DB and type system
but unreachable via Move To UI from `new` status (removed Session 28 —
business model has no pre-auth requirement).

**Admin dashboard is configuration-only.** No operational nav to `/referrals`
or other workflow dashboards. This is intentional — operational access belongs
to Superadmin role-switching.

**MD V2 as primary route:** `/md-v2/[patientId]` is the primary MD chart.
`/md/[patientId]` is the clinical visit entry point.

**shadcn exception extended Sessions 23 + 25:** MD V2, MDClient, login,
`/referrals`. `ARCHITECTURE.md` §1 and `AI_STYLE_GUIDE.md` §2 updated.

**`billing_npi` is the only NPI used in PDF forms.** All `forms/*.py` confirmed.

**`pc_npi` column:** Migration 025. No on-disk SQL file.

**Auth server-component gap:** `createServerClient` (not
`createServerComponentClient`) is the correct export from
`@supabase/auth-helpers-nextjs`. Cookie wrapper required. `getActorId()` in
`actions.ts` is the correct pattern.

**`patient_visits.doctor_id` missing:** relies on `patients.doctor_id`.

**PA/NP users:** `user_profiles.doctor_id` must point to own `doctors` row.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**Supabase insert returns `PromiseLike<void>`.** Use two-arg `.then(onFulfilled,
onRejected)` — `.catch()` is not available on `PromiseLike`.

**`referral_notifications` reads.** Table is written by `sendEmail()` but
nothing reads it in the UI yet. Audit-only for now.

**CPT codes all `General`.** No MD/DC/PT-specific codes exist. Admin CPT
filter tabs for MD, DC, PT etc. show 0 codes — expected. Tab strip could
be improved to hide empty types (deferred).

**MRI session splitting scoped to spine/extremity only.** MRA and CT studies
are excluded from `body_parts[]` and session splitting logic. MRA/CT session
splitting is a deferred product decision.

**`listReferrals()` expands MRI rows.** MRI referrals with pending appointments
return multiple rows (one per session) with `_session_appointment` field.
Non-MRI referrals and MRI referrals with no pending appointments return as
single rows. This affects total row count in the dashboard table.

**`outcome` on `referral_appointments`.** Added to `listReferrals()` select
and cast as `(current as any).outcome` / `(appt as any).outcome` due to
PostgREST inline join type not including it. Workaround — not a schema gap.

---

## Source File Registry (★ = do not patch without fresh pull)

| File | Status |
|---|---|
| `cosmos-dashboard/app/referrals/actions.ts` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/app/referrals/types.ts` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/app/referrals/ReferralSheet.tsx` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/app/referrals/ReferralDashboard.tsx` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 31) |
| `cosmos-api/main.py` | ★ Verified-final (Session 31 — Sentry added) |
| `cosmos-dashboard/sentry.client.config.ts` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/sentry.server.config.ts` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/instrumentation.ts` | ★ Verified-final (Session 31) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 30) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 30) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/admin/components/ReferralProvidersSection.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/referrals/page.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/md-v2/[patientId]/ReferralsTabV2.tsx` | ★ Verified-final (Session 27) |
| `cosmos-api/database.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/ortho.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/rx.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/ans.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/icd10.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-api/forms/pain_mgmt.py` | ★ Verified-final (Session 23 — billing_npi) |
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 23) |
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
| `cosmos-dashboard/app/hooks/useSessionTimeout.ts` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (Session 11) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |

---

## Lessons Learned (carried forward)

- **`cat > file << 'ENDOFFILE'` heredoc is the reliable full-file write method**
- **Chrome silently saves re-downloads as `filename-1.ext`** — always `ls -lt` before `cp`
- **Tailwind purge eliminates classes not present at build time** — use inline `style={{}}` as fallback
- **TanStack Table data prop must be memoized**
- **`/tmp` does not persist in Termux** — use `~/`
- **`pathlib.Path.home()` returns `/root`** — use `os.path.expanduser('~')`
- **`patients` primary key is `patient_id` (text)** — format: `PT457696`
- **CosmosUI `toastSuccess` auto-dismiss green toast; `toastError` blocking red modal**
- **`sessionStorage` reads must be in `useEffect`**
- **Bash `!` triggers history expansion in double-quoted sed strings** — use single quotes or escape
- **Termux heredoc buffer limit ~250 lines** — split files >~250 lines
- **After 3+ patches to same file, restore with `git checkout HEAD -- <file>`**
- **Vercel preview URL domain isolation** — always test on `cosmos-dashboard-nu.vercel.app`
- **Supabase schema cache errors** — column name mismatches fail silently at runtime; always verify against `information_schema.columns`
- **`referral_timeline` has no `occurred_at`** — uses auto-set `created_at`
- **`referral_documents` has no `uploaded_at`** — uses auto-set `created_at`
- **`referrals` FK to `referral_providers` is `referral_provider_id`** — not `provider_id`
- **`referral_providers` address is separate columns** — `street`, `city`, `state`, `zip`; no composite `address` field
- **`storage.buckets` can be created via SQL** — `INSERT INTO storage.buckets`
- **Supabase Storage bucket must exist before RLS policies**
- **Bash `!` in sed replacement strings** — wrap entire sed expression in single quotes
- **Admin dashboard is configuration-only** — no operational nav; Superadmin role-switching is the correct owner access pattern
- **`getReferralProviders()` returns `any[]`** — workaround for stale type; now resolved in types.ts but function not yet updated
- **Referral Server Actions must use `supabaseServer`** — anon key + session cookie does not reliably reach `authenticated` RLS on Vercel
- **PostgREST join shape** — FK-joined tables return arrays even for many-to-one
- **`VALID_TRANSITIONS` blocks `scheduleAppointment`** — `new → scheduled` not in map; `scheduleAppointment` writes status directly
- **`cosmos_license_type` written for all roles on login** — fixed Session 28
- **Patch anchor drift** — always `grep -n` to confirm before any sed; use line-number based Python replacement when anchor has drifted across multiple patches
- **Supabase insert returns `PromiseLike<void>`** — use `.then(onFulfilled, onRejected)` not `.catch()`; `.catch()` only exists on standard `Promise`
- **Complex sed patterns in Termux** — use Python one-liner `python3 -c "..."` for reliable string replacement
- **`user_profiles` join key is `id`** — not `user_id`; table columns: id, role, doctor_id, full_name, pin_hint, created_at, active
- **CPT codes now all `General`** — Admin filter tabs for MD/DC/PT show 0 codes; expected behavior
- **Patient appointment email fires on `scheduleAppointment()`** — provider session email also fires on `scheduleAppointment()`; provider assignment email fires on `assignProvider()`
- **MRI/Rx/DME PDF attachment** — fetched from `patient-forms` bucket via `storage.download()`, converted to base64, attached to Resend email
- **`RESEND_API_KEY` must be set on Vercel** — not just Render; both services use Resend independently
- **`sentry-sdk[fastapi]` fails on Termux/ARM** — `pydantic-core` requires Rust; use `sentry-sdk` (base) instead; full FastAPI integration not needed for exception capture
- **`@sentry/wizard` not usable in Termux** — use manual config (sentry.client.config.ts, sentry.server.config.ts, instrumentation.ts) instead
- **Supabase `GET /api/` prefix removed in `cosmos-api`** — always use `git show HEAD:main.py | head -40` to check actual path before any route change (confirmed Session 31)
- **Python patch scripts use `/root/` path** — always use `os.path.expanduser('~')` not hardcoded `/root/`; Termux home is `/data/data/com.termux/files/home/`
- **Multiple patches to same file cause anchor drift** — after 2+ patches, use line-number based Python replacement (`sed -n 'N,Mp'` to confirm then replace by line range) rather than string anchors
- **PostgREST inline join type omits custom columns** — `outcome`, `body_parts` on `referral_appointments` not in TypeScript inferred type; cast as `(row as any).outcome`
- **`listReferrals()` now returns expanded rows for MRI** — row count no longer equals referral count; `_session_appointment` field signals an expanded row
