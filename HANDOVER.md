# Cosmos Medical Technologies — HANDOVER (July 9, 2026, Session 30)

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
`cosmos-dashboard-nu.vercel.app`. Session 29 priority queue exhausted.
Referral Management Module fully operational end-to-end including
notifications. Patient and provider email notifications live and confirmed
working in production.

---

## Completed This Session (Session 29 → continued as Session 30)

### Priority #1 — patient_forms visit_id backfill ✅ CLOSED

Investigation revealed all 30 null-visit_id rows were dev-seeded ghost
records — both `visit_id` and `filename` were null, meaning no real PDF
existed behind them. No real patient data was affected. Billing packet ZIP
was correctly excluding them. Deleted via:
`DELETE FROM patient_forms WHERE visit_id IS NULL AND filename IS NULL;`

### Priority #2 — CPT codes provider_type ✅ CLOSED

All 34 CPT codes bulk-updated from `MD` → `General` in database.
`VisitTab.tsx` filter updated to show codes where
`provider_type === effectiveLicenseType || provider_type === 'General'`.
PA and NP users now see full code set (previously empty picker).
Product decision: single `General` code set correct for this practice —
DC/PT/etc. are referral recipients, not visit coders in Cosmos.

### Priority #3 — DEV artifacts removal DEFERRED to go-live

DEV fill-all PCE button in `VisitTab.tsx` and Dev Tools card in Admin panel
both intentionally retained during testing phase. Remove together at go-live.

### Priority #4 — ReferralProviderRow type cleanup ✅ CLOSED

`app/referrals/types.ts` fully corrected — all interface field names now
match live schema:
- `ReferralProviderRow`: `address` → `street`, `city`, `state`, `zip`
- `ReferralRow`: `provider_id` → `referral_provider_id`; `created_by` → `created_by_user_id`
- `ReferralAppointmentRow`: `location` → `location_name`
- `ReferralDocumentRow`: `uploaded_by` → `uploaded_by_user_id`; `uploaded_at` → `created_at`
- `ReferralStatusHistoryRow`: `changed_by` → `changed_by_user_id`; `changed_at` → `created_at`
- `ReferralTimelineRow`: `actor_id` → `actor_user_id`; `occurred_at` → `created_at`
- `ReferralNoteRow`: `created_by` → `author_user_id`
`getReferralProviders()` can now be restored to `ReferralProviderRow[]`
from `any[]` in a future `actions.ts` touch.

### Priority #5 — Referral notifications ✅ CLOSED

**Migration 027:** `patients.email text` (nullable) added.

**PatientForm.tsx:** Email field added to Personal Information section
(after Phone). Optional. State initialized from `patient?.email` in edit mode.

**PatientProfile.tsx:** Email shown in patient info grid when present
(conditional spread into the grid array).

**actions.ts — sendEmail() helper:** Fire-and-forget Resend integration.
Uses `RESEND_API_KEY` env var (added to Vercel Production). Logs every
send attempt to `referral_notifications` (delivery_status: sent/failed).
Uses two-arg `.then(onFulfilled, onRejected)` pattern — Supabase insert
returns `PromiseLike<void>`, not standard `Promise`; `.catch()` not available.

**scheduleAppointment() — patient email:** After successful appointment
insert, fetches patient email from `patients`. If present, sends
appointment confirmation email via Resend:
- Subject: `Appointment Confirmation — {referral type}`
- Body: patient name, referral type, date (long format), time, location,
  confirmation number (all optional fields shown only if present)
- Fire-and-forget — appointment save never blocked by email failure

**assignProvider() — provider email:** After successful provider assignment,
fetches provider email from `referral_providers`. If present, sends
referral notification:
- Subject: `New {type} Referral — {patient name}`
- Body: patient name, referral type, urgency, clinical reason
- For MRI/Rx/DME types: fetches most recent `patient_forms` row for that
  type, downloads PDF from `patient-forms` storage bucket, attaches as
  base64 to Resend email
- Fire-and-forget — provider assignment never blocked by email failure

**Email confirmed working in production** (appointment confirmation
received by patient, provider notification received with correct details;
MRI PDF attachment confirmed). Emails currently land in spam during testing
— expected; SPF/DKIM records on Porkbun/Cloudflare resolve at go-live.

**SMS via Twilio:** Deferred. Decision: stay with email until Twilio
account is set up. `sendSMS()` will slot alongside `sendEmail()` when ready.

**Provider portal (token-gated referral view page):** Deferred to Phase 2.
MRI/Rx/DME providers receive PDF via email attachment for now.

### Priority #6 — Superadmin dashboard ✅ CLOSED (already built)

Superadmin login lands on a role-selector screen: "Welcome, Roman" +
👑 SUPER ADMIN badge + four dashboard tiles (Front Desk / MD / Billing /
Admin). Superadmin can access any dashboard. Audit log records all logins
as `super@cosmos...`. No separate `/superadmin` route needed for this
practice size.

### Priority #7 — Sidebar rollout DEFERRED

### Priority #8 — Doctor mailing addresses DEFERRED to pre-production

All current doctor records (Carrey, Gottesman, Kramer, Pearlman, NPian,
PAian, Orthobot) are test/dev data with placeholder addresses. Real
provider data to be entered at go-live onboarding.

### Priority #9 — patients.doctor_id NOT NULL DEFERRED to pre-production

### Priority #10 — Vercel Pro + HIPAA BAAs AT GO-LIVE

---

## Completed Prior Sessions (carried forward)

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

1. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

2. **Sidebar rollout — FD, MD, Biller.** Deferred.

3. **Doctor mailing address data.** All current records are test data.
   Real provider data entered at go-live onboarding.

4. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

5. **Vercel Pro upgrade.** At go-live.

6. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — must be signed
   before go-live with real patient data.

7. **SPF/DKIM records** for `cosmosmt.com` on Porkbun/Cloudflare — fixes
   email spam classification. At go-live.

8. **Twilio SMS integration.** Deferred. `sendSMS()` slots alongside
   `sendEmail()` in `actions.ts` when Twilio account is ready.

9. **Provider portal — token-gated referral view.** Phase 2. Providers
   currently receive PDF via email attachment.

10. **`getReferralProviders()` return type.** Still `any[]` — can be
    restored to `ReferralProviderRow[]` in next `actions.ts` touch.

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
- [x] Referral notifications — patient appt email + provider assignment email (Session 30)
- [x] MRI/Rx/DME PDF attachment in provider notification email (Session 30)
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

---

## Source File Registry (★ = do not patch without fresh pull)

| File | Status |
|---|---|
| `cosmos-dashboard/app/referrals/actions.ts` | ★ Verified-final (Session 30) |
| `cosmos-dashboard/app/referrals/types.ts` | ★ Verified-final (Session 30) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 30) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 30) |
| `cosmos-dashboard/app/referrals/ReferralSheet.tsx` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/referrals/ReferralDashboard.tsx` | ★ Verified-final (Session 29) |
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
| `cosmos-api/main.py` | ★ Verified-final (Session 22) |

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
- **Patch anchor drift** — always `grep -n` to confirm before any sed
- **Supabase insert returns `PromiseLike<void>`** — use `.then(onFulfilled, onRejected)` not `.catch()`; `.catch()` only exists on standard `Promise`
- **Complex sed patterns in Termux** — use Python one-liner `python3 -c "..."` for reliable string replacement
- **`user_profiles` join key is `id`** — not `user_id`; table columns: id, role, doctor_id, full_name, pin_hint, created_at, active
- **CPT codes now all `General`** — Admin filter tabs for MD/DC/PT show 0 codes; expected behavior
- **Patient appointment email fires on `scheduleAppointment()`** — provider email fires on `assignProvider()`; provider assigned before appointment scheduled in FD workflow
- **MRI/Rx/DME PDF attachment** — fetched from `patient-forms` bucket via `storage.download()`, converted to base64, attached to Resend email
- **`RESEND_API_KEY` must be set on Vercel** — not just Render; both services use Resend independently
