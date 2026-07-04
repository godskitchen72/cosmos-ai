# Cosmos Medical Technologies — HANDOVER (July 4, 2026, Session 12)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed via
`tsc --noEmit` + full deploy chain. Live app confirmed healthy at session
close. No outstanding TypeScript errors.

---

## Completed This Session

### Enterprise Hardening Stage 1 — RLS full audit and hardening

Full RLS audit conducted. Every `anon` and `public` policy removed from
all tables. Every table now locked to `authenticated` only.

Key findings: `patient_forms` had zero policies (silently blocked all
authenticated operations). `patients` had `{public}` INSERT/SELECT/UPDATE
(unauthenticated PHI access). Both fixed.

Login flow (`app/page.tsx`) confirmed via source review to make zero
pre-auth database queries — safe to drop all `anon` policies with no
code changes required.

Verified clean:
```sql
SELECT policyname, tablename, roles FROM pg_policies
WHERE schemaname = 'public'
AND ('anon' = ANY(roles) OR 'public' = ANY(roles));
-- 0 rows ✅
```

### Enterprise Hardening Stage 1 — NOT NULL constraints (migration 018)

Full null audit before constraining. Constrained:
- `doctors.license_number NOT NULL`
- `doctors.npi NOT NULL`
- `doctors.mailing_state NOT NULL`
- `patient_forms.form_type NOT NULL`

Deliberately left nullable:
- `doctors.mailing_street/city/zip` — supervised providers legitimately
  have no own address; `database.py` resolves to supervisor at PDF time
- `patients.patient_signature_url` — collected post-intake; app gate sufficient
- `patient_forms.visit_id` — NF-2 is patient-level, not visit-scoped
- `patients.doctor_id` — deferred to pre-production go-live pass

### NF-3 regression fix — place of service + description of treatment

**Root cause:** Migration 014 dropped `street/city/state/zip` from `doctors`
table. `database.py` was still reading those columns silently returning
empty strings. `main.py` only looked up place of service via
`visit.location_id` with no fallback.

**Fix (`main.py`):** Added fallback to MD's assigned `doctor_locations`
when `visit.location_id` is null. Priority order:
1. `patient_visits.location_id` → `office_locations` (exact visit location)
2. MD's `doctor_locations` → prefer `is_main_office = true`, else first

**Fix (`database.py`):** Removed dead code referencing dropped doctor
address columns. Keys kept as empty strings with explanatory comment.

### MRI Referral — full feature completion

`app/md/[patientId]/mri/MriReferral.tsx` rebuilt with:
- **Metal implant contraindication toggle** — YES collapses and disables
  MRI Spine, MRI Extremities, Contrast, MRA sections entirely. CT remains
  active with "← Required (metal implant)" label.
- **MRI/CT mutual exclusion** — enforced by UI disable, not just visual
- **Extremity Studies** — Left/Right toggle per body part (Shoulder, Elbow,
  Wrist, Hip, Knee, Ankle). Maps to `mri.left_*` / `mri.right_*` backend keys
- **Contrast selection** — Without / With & Without. Maps to `contrast.type`
- **Insurance auto-pass** — `carrier` and `policy_num` read silently from
  patient record, passed to PDF backend, not shown in UI

### CPT codes filtered by provider license type

**`app/page.tsx`:** Added `fetchLicenseType(doctorId)` — fetches
`license_type` from `doctors` table at login, stores as
`cosmos_license_type` in sessionStorage alongside `cosmos_location_id`.

**`app/md/[patientId]/PatientChart.tsx`:** Added `useEffect` to read
`cosmos_license_type` from sessionStorage after hydration. `filteredCptCodes`
filters `cptCodes` by `provider_type === licenseType`. Falls back to all
codes if `licenseType` is empty (superadmin, non-clinical roles).

**Note:** `sessionStorage` read must be in `useEffect` — reading during
render fires server-side where `sessionStorage` doesn't exist, always
returning `''`.

### CosmosUI — universal notification standard

New shared component: `app/components/ui/CosmosUI.tsx`

**Standard:**
- All notifications → `AlertModal` (dark, cyan border `#00cfff60`, cyan
  message text, requires tap to dismiss)
- Success → `AlertModal` via `toastSuccess()`
- Errors → `AlertModal` via `toastError()`
- Destructive confirmations → `ConfirmModal` (cyan border, red confirm button)
- `ToastContainer` still exported but `toastSuccess`/`toastError`/`toastInfo`
  all route through `AlertModal`

**Adopted across:**
- `admin/page.tsx` — all 15 `alert()`/`confirm()` calls replaced
- `app/billing/BillerDashboard.tsx` — all 8 calls replaced
- `app/patients/[patientId]/PatientProfile.tsx` — 2 calls replaced
- `app/md/[patientId]/mri/MriReferral.tsx` — 1 call replaced
- `app/dev/page.tsx` — 1 call replaced
- Native `alert()`/`confirm()` eliminated app-wide

**Mount pattern:** Each page that uses notifications must mount both
`<AlertModal />` and `<ConfirmModal />` in its root return. Currently
mounted in: `admin/page.tsx`, `BillerDashboard.tsx`, `PatientProfile.tsx`,
`MriReferral.tsx`, `dev/page.tsx`.

---

## Open Items, Priority Order

1. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

2. **DME provider certification fields blank** — `forms/dme.py` has never
   been obtained or audited.

3. **Doctor mailing address data** — Gottesman, Orthobot, Pearlman, Kramer
   have test/placeholder mailing addresses. Gottesman and Kramer are
   independent — their addresses are required for NF-3/W9. Supervised
   providers (Orthobot, NPian, PAian, Pearlman) resolve through supervisor.

4. **`patients.doctor_id` NOT NULL** — deferred to pre-production. 3 test
   patients (Maria Anderson PT457696, Dorothy Lewis PT322913, John Ramirez
   PT326475) have null `doctor_id`.

5. **NF-3 Section 15 Place of Service** — confirmed working post-fix.
   Visits predating migration 016 have null `location_id`; fallback to
   MD's assigned location now handles these correctly.

6. **CosmosUI — mount AlertModal/ConfirmModal on remaining screens** —
   any new screen added must mount both components to use notifications.

---

## Enterprise Hardening Checklist (running)

### Stage 1 — Data Integrity
- [x] FK constraints — all tables audited and complete (Session 10)
- [x] Full RLS audit — every table, every command, both roles (Session 12)
- [x] `NOT NULL` constraints on required columns — partial (Session 12);
      `patients.doctor_id` deferred to pre-production

### Stage 2 — Security
- [ ] API JWT authentication on all `cosmos-api` endpoints
- [ ] Session timeout / auto sign-out after inactivity
- [ ] Failed PIN attempt lockout
- [ ] MFA for admin and billing roles
- [ ] HIPAA BAA with Supabase
- [ ] Audit log table (who changed what, when)

### Stage 3 — Infrastructure
- [ ] Staging environment (Vercel preview + Render staging)
- [ ] GitHub Actions CI (auto `tsc --noEmit` + `py_compile` on push)
- [ ] Database indexes on all FK and common filter columns
- [ ] Supabase point-in-time recovery confirmed enabled
- [ ] Error monitoring (Sentry or equivalent)

### Stage 4 — Code Quality
- [ ] Replace all `print()` in `cosmos-api` with structured Python `logging`
- [ ] Eliminate remaining `any` types — TypeScript strict mode
- [ ] React error boundaries on all dashboard surfaces
- [ ] Loading states on all data fetches

### Stage 5 — Product & UX
- [ ] Desktop sidebar nav
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel
- [ ] Data retention and deletion policy
- [ ] Patient data export capability

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` does not
export `createServerComponentClient` (TS2724). Server-side session reads
deferred. `?doctor_id=` URL param is the reliable doctor-scoping path.

**`patient_visits.doctor_id` missing:** Visit-to-doctor linkage relies on
`patients.doctor_id` (one-doctor-per-patient assumption).

**PA/NP users — `doctor_id` must be own record:** `user_profiles.doctor_id`
must point to the user's own `doctors` row, not their supervisor. The
supervisor relationship lives in `doctors.supervising_provider_id`.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**NF-3 message state is module-level (`nf3Msg`):** `nf3Msg` useState is
declared at module level not inside the component. Low risk but
architecturally incorrect. Fix on next full `PatientProfile.tsx` rebuild.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null
`doctor_id`. Constraint deferred to pre-production go-live pass.

**`cosmos_license_type` in sessionStorage:** CPT filter depends on this
value being set at login. If a provider logs in without a `license_type`
in the `doctors` table, all CPT codes will show (safe fallback, not a bug).

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 12 — new file, universal notification standard) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 12 — CosmosUI alerts, AlertModal mount) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 12 — CosmosUI alerts, AlertModal mount) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 12 — CosmosUI alerts, AlertModal mount) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 12 — full rebuild: extremities, contrast, metal implant, CosmosUI) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 12 — CPT filter by license_type via useEffect) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 12 — fetchLicenseType added, cosmos_license_type stored at login) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 12 — CosmosUI confirm) |
| `cosmos-api/main.py` | ★ Verified-final (Session 12 — place of service fallback to doctor_locations) |
| `cosmos-api/database.py` | ★ Verified-final (Session 12 — dead doctor address columns cleaned up) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (Session 11) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (Session 11) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 9) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (Session 8) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **Supabase SQL Editor CSV export omits `policyname`** — must explicitly
  select `policyname` column. Use:
  `SELECT tablename, policyname, cmd, roles FROM pg_policies`
- **`DROP POLICY IF EXISTS` with guessed names silently no-ops** — always
  confirm actual policy names via `pg_policies` before writing DROP statements
- **Supabase SQL Editor on mobile Chrome truncates large pastes** — keep
  each SQL block under ~20 lines. Split into numbered chunks.
- **`ALTER TABLE ... DISABLE ROW LEVEL SECURITY` requires superuser** —
  the SQL Editor role (`postgres`) does not have this privilege on managed
  tables. Use explicit DROP POLICY with exact names instead.
- **`patients` primary key is `patient_id` (text)** — not `id`. Format:
  `PT457696`. Queries must use `patient_id`, not `id`.
- **Supervised providers legitimately have null mailing addresses** —
  `database.py` resolves to supervisor at PDF time. NOT NULL on
  `doctors.mailing_street/city/zip` would be architecturally incorrect.
- **`patient_forms.visit_id` is legitimately nullable** — NF-2 is
  patient-level. 50 null records confirmed correct.
- **Login flow makes zero pre-auth DB queries** — confirmed from source.
  Dropping all `anon` policies safe with no code changes.
- **`sessionStorage` reads must be in `useEffect`** — reading during
  render fires server-side where `sessionStorage` doesn't exist, always
  returns `''`. The CPT license_type filter learned this the hard way.
- **CosmosUI `toastSuccess`/`toastError` both route through `AlertModal`**
  — the `ToastContainer` is mounted but all exported helpers use
  `_openAlert`. Don't confuse the exported function names with the
  underlying mechanism.
- **New screens must mount `<AlertModal />` and `<ConfirmModal />`** —
  these are singleton global overlays; if not mounted, notifications
  silently do nothing (fallback to native `window.confirm`).

---

## Lessons Learned (carried forward from Session 11)

- **`/tmp` does not persist in Termux** — patch scripts must always write
  to `~/`, never `/tmp/`.
- **Bash history expansion breaks `sed -i` with `!`** — use Python patch
  scripts for any anchor containing `!` characters.
- **`pathlib.Path.home()` returns `/root` in this environment** — use
  `os.path.expanduser('~')` instead.
- **React fragments (`<>`) inside a CSS grid don't create grid items** —
  render message strips outside the grid container.
- **`database.py` prefixes all doctor fields** — `license_number` becomes
  `doctor_license_number` in `patient_data`.
- **W9 is a billing entity document, not a provider document.**
- **AOB assigns benefits to the billing entity, never the treating provider.**
- **NF-3 Section 16 LICENSE field is not NPI.**
