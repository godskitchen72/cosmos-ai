# Cosmos Medical Technologies — HANDOVER (July 9, 2026, Session 29)

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
`cosmos-dashboard-nu.vercel.app`. Referral Management Module Phase 3
substantially complete. Provider assignment, document upload, overdue
flagging, and timeline all functional end-to-end.

---

## Completed This Session (Session 29)

### AI_STYLE_GUIDE.md — shadcn Exception Scope Corrected

§2 updated: "two explicit, scoped exceptions, both on the Biller dashboard
only" corrected to "five explicit, scoped exceptions" — Biller (`/billing`),
Admin (`/admin`), MD V2 (`/md-v2`), MDClient (`/md`), Referral dashboard
(`/referrals`). Matches `SYSTEM_PROMPT.md` §9 and `ARCHITECTURE.md` §1.

### Provider Assignment — Appointment Tab

`ReferralSheet.tsx` — Assigned Provider card added to Appointment tab:
- Dark custom `ProviderDropdown` component (same pattern as `DarkDropdown`,
  with "— Unassigned —" as null option).
- Providers loaded from `referral_providers` on mount via Supabase client.
- Filtered by referral category → specialty mapping (`CATEGORY_SPECIALTIES`):
  imaging → MRI/Radiology, therapy → PT/Chiro/Acupuncture, etc.
- "Show all" toggle bypasses filter.
- Selection calls `assignProvider()` Server Action immediately (optimistic
  update with revert on error).
- Assigned provider's specialty, address, phone shown below dropdown.
- When Schedule form opens (new or Reschedule), Location pre-fills from
  assigned provider's address if Location is currently empty.

### assignProvider() Server Action

`actions.ts` — new `assignProvider(referralId, providerId | null)`:
- Writes `referral_provider_id` to `referrals` (confirmed column name —
  NOT `provider_id`).
- Fetches provider address (`street`, `city`, `state`, `zip`) and returns
  `providerAddress` string for Location pre-fill.
- Inserts `provider_assigned` timeline event.
- Returns `{ ok, providerAddress }` or `{ error }`.

### Column Audit — actions.ts

Additional column name mismatches resolved Session 29:
- `referral_providers`: no `address` composite column — real columns are
  `street`, `city`, `state`, `zip` (confirmed `information_schema.columns`).
- `referrals`: FK column is `referral_provider_id` not `provider_id`.
- `referral_timeline`: no `occurred_at` column — uses auto-set `created_at`.
- `referral_documents`: no `uploaded_at` column — uses auto-set `created_at`.
- `referral_documents`: has `file_size_bytes` and `mime_type` (not yet
  populated by upload action — future improvement).
- `getReferralProviders()` return type changed from `ReferralProviderRow[]`
  to `any[]` — `ReferralProviderRow` in `types.ts` is stale (workaround;
  full type update deferred).

### Document Upload — Documents Tab

`ReferralSheet.tsx` — Documents tab now has upload UI:
- Upload card: doc type `DarkDropdown` (Result / Authorization / Referral
  Form / Other), file picker button (hidden `<input type="file">`), file
  name + size preview, Upload button.
- Accepted: `application/pdf`, `image/jpeg`, `image/png`, `image/tiff`.
  Max 25MB enforced client-side before upload attempt.
- Storage path: `{patientId}/{referralId}/{timestamp}_{sanitizedFilename}`
  in `referral-documents` bucket.
- On success: calls `uploadReferralResult()` Server Action → inserts
  `referral_documents` row + `document_uploaded` timeline event.
- Document list refreshes immediately after upload.
- View button: generates 15-min signed URL from `referral-documents` bucket.
- Doc type shown human-readable in list ("Result" not "result").

### referral-documents Bucket

New Supabase Storage bucket created Session 29:
- Name: `referral-documents`
- Public: OFF
- File size limit: 25MB (26214400 bytes)
- MIME types: PDF, JPEG, PNG, TIFF
- Created via SQL: `INSERT INTO storage.buckets ...`
- Three RLS policies: INSERT / SELECT / UPDATE for `authenticated` role.

### Timeline — Fixed

`ReferralSheet.tsx` + `actions.ts`:
- Timeline query now orders by `created_at` (was `occurred_at` — column
  does not exist).
- Timeline timestamp display uses `e.created_at` (was `e.occurred_at`).
- All timeline inserts no longer pass `occurred_at` — Supabase auto-sets
  `created_at`.
- Timeline now records: referral created, status changed, provider assigned,
  appointment scheduled, document uploaded.

### Dark Dropdowns — ReferralSheet

All native `<select>` elements in `ReferralSheet.tsx` replaced with custom
dark dropdowns:
- `ProviderDropdown` — provider assignment (with Unassigned option)
- `DarkDropdown` — Record Outcome selector
- Both use `useRef` outside-click dismiss, dark `#0d1821` background,
  `#00cfff` active color, Oxanium font.

### Outcome Form — Record Outcome Dropdown

Record Outcome selector converted from native `<select>` to `DarkDropdown`
component. Eliminates Android OS light-theme picker.

### Overdue Row Flagging — ReferralDashboard

`ReferralDashboard.tsx`:
- `isOverdue(r)` helper: returns true when status is not terminal/completed
  AND `updated_at` older than 14 days. Single source of truth.
- Patient cell: `⚠ OVERDUE` dark red badge (`#7f1d1d` bg, `#fca5a5` text)
  inline with urgency badge.
- Table row: subtle dark red background tint (`#7f1d1d18`) on overdue rows.
- Overdue metric card filter now uses `isOverdue()` — previously used past
  appointment date (different definition). Now matches KPI count exactly.
- Appointment column `⚠` indicator kept (past appointment date, not 14-day
  rule) — renamed `pastAppt` to distinguish from overdue concept.

### Admin Sidebar — Referrals Link Removed

`app/admin/page.tsx` — Referrals → nav link added then removed this session.
Decision: Admin dashboard is configuration-only (table management). Operational
workflow dashboards (FD, MD, referrals) belong to Superadmin role-switching,
not Admin. Admin has no operational reason to view the referral workflow.

### Superadmin Dashboard — Future Feature (Noted)

Superadmin dashboard scoped for future development. Owner-level oversight
layer. Key capabilities identified:
- Identity & Access: active sessions, force sign-out, PIN reset, enable/disable users
- Role switching / impersonation: "View as FD/MD/Billing/Admin" read-only
- Practice Operations Overview: cross-role KPI executive summary
- Audit & Compliance: full audit log with user filter, failed login attempts
- System Health: storage usage, last deploy, environment indicator
Not building this session — documented for roadmap.

---

## Completed Prior Sessions (carried forward)

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

1. **`patient_forms` visit_id backfill.** Query:
   `SELECT form_type, visit_id, filename FROM patient_forms WHERE patient_id = 'PT331111'`
   — then backfill any null `visit_id` rows with the correct visit UUID.
   Billing packet ZIP silently excludes rows with `visit_id = null`.

2. **CPT codes `provider_type` product decision needed.** All 34 codes are
   MD only. Non-MD providers see empty CPT picker. Add `General` type or
   separate sets.

3. **DEV fill-all PCE button** — remove from `VisitTab.tsx` before go-live.

4. **`ReferralProviderRow` type cleanup.** `types.ts` still has stale
   `address: string | null` field. Real columns are `street`, `city`,
   `state`, `zip`. `getReferralProviders()` returns `any[]` as workaround.
   Low risk — no runtime impact.

5. **Referral notifications.** `referral_notifications` table exists in
   schema (Migration 026) but nothing writes to or reads from it. Requires
   product decision: in-app only, or email via Resend?

6. **Superadmin dashboard.** Scoped Session 29. See above for full spec.
   Not yet built.

7. **Sidebar rollout — FD, MD, Biller.** Deferred.

8. **Doctor mailing address data.** Gottesman and Kramer placeholders.

9. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

10. **Vercel Pro upgrade.** At go-live.

11. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — must be signed
    before go-live with real patient data.

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
- [x] Patient name in referral table (Session 28)
- [x] Dark custom dropdowns in referral dashboard (Session 28)
- [x] Provider assignment on referral sheet (Session 29)
- [x] Document upload — referral-documents bucket (Session 29)
- [x] Overdue row flagging + filter fix (Session 29)
- [x] Timeline — writes and display fully working (Session 29)
- [x] Dark dropdowns throughout ReferralSheet (Session 29)
- [ ] Referral notifications (product decision needed)
- [ ] Superadmin dashboard (scoped Session 29)
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

**`ReferralProviderRow` type stale.** `types.ts` declares `address: string |
null` but real table has `street`, `city`, `state`, `zip`. `getReferralProviders()`
returns `any[]` as workaround. Full type update deferred.

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
to Superadmin role-switching (not yet built).

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

---

## Source File Registry (★ = do not patch without fresh pull)

| File | Status |
|---|---|
| `cosmos-dashboard/app/referrals/ReferralSheet.tsx` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/referrals/actions.ts` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/referrals/ReferralDashboard.tsx` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/admin/components/ReferralProvidersSection.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/referrals/types.ts` | Obtained Session 29 — `ReferralProviderRow` stale |
| `cosmos-dashboard/app/referrals/page.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/referrals/ReferralDashboard.tsx` | ★ Verified-final (Session 29) |
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx` | ★ Verified-final (Session 28) |
| `cosmos-dashboard/app/md-v2/[patientId]/ReferralsTabV2.tsx` | ★ Verified-final (Session 27) |
| `cosmos-api/database.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/ortho.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/rx.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/ans.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/icd10.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/pain_mgmt.py` | ★ Verified-final (Session 23 — `billing_npi`) |
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
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 22) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 22) |
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
- **Supabase Storage bucket must exist before RLS policies** — policies ran before bucket existed Session 29; bucket created after via SQL
- **Bash `!` in sed replacement strings** — wrap entire sed expression in single quotes; never double-quote sed with `!` in replacement
- **Admin dashboard is configuration-only** — no operational nav; Superadmin role-switching is the correct owner access pattern
- **`ReferralProviderRow` in types.ts is stale** — use `any[]` cast until full type update
- **`getReferralProviders()` returns `any[]`** — workaround for stale type; not a bug
- **Referral Server Actions must use `supabaseServer`** — anon key + session cookie does not reliably reach `authenticated` RLS on Vercel
- **PostgREST join shape** — FK-joined tables return arrays even for many-to-one
- **`VALID_TRANSITIONS` blocks `scheduleAppointment`** — `new → scheduled` not in map; `scheduleAppointment` writes status directly
- **`cosmos_license_type` written for all roles on login** — fixed Session 28
- **Patch anchor drift** — always `grep -n` to confirm before any sed
