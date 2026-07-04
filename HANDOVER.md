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
close. No code changes this session — all work was database-layer hardening
executed directly in the Supabase SQL Editor.

---

## Completed This Session

### Enterprise Hardening Stage 1 — RLS full audit and hardening

Full RLS audit conducted via `sql/003_rls_audit_query.sql`. Every table
inspected for `anon` and `public` policy exposure.

**Findings:**
- `patient_forms` — RLS enabled, zero policies (every authenticated
  operation silently blocked). Fixed.
- `patients` — `{public}` INSERT/SELECT/UPDATE (unauthenticated PHI
  access). Fixed.
- `patient_visits`, `visit_line_items` — `{anon,authenticated}` combined
  policies. Fixed.
- `doctors`, `insurance_carriers`, `lawyers`, `appointments`,
  `cpt_codes`, `icd10_codes`, `office_locations`, `doctor_locations`,
  `practice_settings`, `user_profiles` — all had residual `anon` or
  `public` policies. All fixed.
- `cpt_icd10_map` — `{public}` ALL policy. Fixed.
- `_deprecated_cpt_templates`, `_deprecated_icd10_templates` — open
  `{public}` policies. Fixed.

**Result:** Zero `anon` or `public` policies remain on any table.
Every table is now locked to `authenticated` only. Verified via:
```sql
SELECT policyname, tablename, roles FROM pg_policies
WHERE schemaname = 'public'
AND ('anon' = ANY(roles) OR 'public' = ANY(roles));
-- Returns 0 rows ✅
```

**Key finding during audit:** Login flow (`app/page.tsx`) confirmed to
make zero pre-auth database queries — `signIn()` authenticates via
Supabase Auth before any DB read occurs. Dropping `anon` policies had
no impact on the login screen. Verified from source.

**Policy name lesson learned:** Supabase SQL Editor CSV export omits
`policyname` when using the standard audit query columns. Always use:
```sql
SELECT tablename, policyname, cmd, roles FROM pg_policies
WHERE schemaname = 'public';
```
to get actual policy names for DROP POLICY statements.

**Mobile paste truncation lesson learned:** The Supabase SQL Editor on
mobile Chrome truncates large pastes silently. Keep each SQL block under
~20 lines when pasting on mobile. Split into numbered chunks.

### Enterprise Hardening Stage 1 — NOT NULL constraints (migration 018)

Full audit of null counts across all critical columns conducted before
constraining anything.

**Constrained (migration 018):**
- `doctors.license_number NOT NULL` — zero nulls confirmed pre-migration
- `doctors.npi NOT NULL` — zero nulls confirmed pre-migration
- `doctors.mailing_state NOT NULL` — zero nulls confirmed pre-migration
- `patient_forms.form_type NOT NULL` — zero nulls confirmed pre-migration

**Left nullable — supervised providers:**
- `doctors.mailing_street/city/zip` — 4 supervised providers (NPian,
  Orthobot, PAian, Pearlman) legitimately have no own mailing address;
  `database.py` resolves to supervisor's address at document generation.
  NOT NULL would be architecturally incorrect for this column.

**Left nullable — application-layer gate sufficient:**
- `patients.patient_signature_url` — 13 patients without signature;
  collected post-intake. App-layer gate on NF-3 generation is the
  correct enforcement point. DB constraint would break new patient intake.

**Left nullable — NF-2 is patient-level:**
- `patient_forms.visit_id` — 50 null records confirmed as NF-2 (25) and
  NF-3 (25) test records from Session 10 dev generator. NF-2 is
  patient-level, not visit-scoped — `visit_id` is legitimately nullable.

**Deferred to pre-production:**
- `patients.doctor_id` — 3 test patients (Maria Anderson PT457696,
  Dorothy Lewis PT322913, John Ramirez PT326475) have no doctor assigned.
  System is in test mode; constraining now adds friction during testing.
  Enforce at go-live after test data cleared.

---

## Open Items, Priority Order

1. **NOT NULL — `patients.doctor_id`** — deferred to pre-production.
   3 test patients identified with null `doctor_id`. Enforce at go-live.

2. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend work, never started.

3. **`cpt_codes.provider_type` backend wiring** — column exists, unused.

4. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

5. **DME provider certification fields blank** — `forms/dme.py` has never
   been obtained or audited.

6. **Doctor mailing address data** — Gottesman, Orthobot, Pearlman, Kramer
   have test/placeholder mailing addresses. Must be updated with real data
   before production use. (Orthobot, NPian, PAian, Pearlman are supervised
   — their mailing address resolves through supervisor. Gottesman and
   Kramer are independent — their addresses are required for NF-3/W9.)

7. **NF-3 Section 15 Place of Service** — confirmed working for visits with
   `location_id` set. Visits created before migration 016 (location tracking)
   will have blank place of service — data gap, not a code bug.

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
declared at module level (line 69 area) not inside the component — it works
at runtime because React hooks are called consistently, but it's
architecturally incorrect. Low risk for now but should be moved inside
the component on next full PatientProfile.tsx rebuild.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null
`doctor_id`. Constraint deferred to pre-production go-live pass.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-api/forms/nf3.py` | ★ Verified-final (Session 11 — license_number fix, doctor_license_number key) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (Session 11 — billing entity provider name/address/sig) |
| `cosmos-api/main.py` | ★ Verified-final (Session 11 — NF-3 signature gate, supervisor W9 routing, generate-w9 guard) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 11 — dropdown contrast, location gate, two-step new provider, W9 billing entity logic) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 11 — NF-3 signature gate, inline message strip) |
| `cosmos-api/database.py` | ★ Verified-final (Session 10 — independent provider supervisor fallback fix) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 12 — source read and confirmed; login makes zero pre-auth DB queries) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 9) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 9) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (Session 8) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **Supabase SQL Editor CSV export omits `policyname`** when using
  `SELECT tablename, cmd, roles` — must explicitly select `policyname`
  as a column to get it in output. Always use
  `SELECT tablename, policyname, cmd, roles FROM pg_policies` for any
  policy name lookup.
- **`DROP POLICY IF EXISTS` with guessed names silently no-ops** — if
  the policy name doesn't match exactly, the DROP succeeds with no error
  but does nothing. Always confirm actual policy names via `pg_policies`
  before writing DROP statements.
- **Supabase SQL Editor on mobile Chrome truncates large pastes** — any
  block over ~20 lines risks being cut off mid-statement, producing a
  `42601: syntax error at end of input`. Split into chunks of ~15-20
  lines when pasting on mobile.
- **`ALTER TABLE ... DISABLE ROW LEVEL SECURITY` requires superuser** —
  the Supabase SQL Editor role (`postgres`) does not have superuser
  privileges on managed tables. This approach does not work; use
  explicit DROP POLICY with exact names instead.
- **`patients` primary key is `patient_id` (text), not `id`** — unlike
  most other tables which use `uuid` PKs, `patients` uses a text-format
  `patient_id` column (e.g. `PT457696`). Queries against this table
  must use `patient_id`, not `id`.
- **Supervised providers legitimately have null mailing addresses** —
  `database.py` resolves mailing address to the supervisor's at document
  generation time. NOT NULL on `doctors.mailing_street/city/zip` would
  be architecturally incorrect — do not add it.
- **`patient_forms.visit_id` is legitimately nullable** — NF-2 is
  patient-level, not visit-scoped. The 50 null `visit_id` records in
  `patient_forms` are expected and correct, not a data gap.
- **Login flow makes zero pre-auth DB queries** — `app/page.tsx`
  confirmed by source review. `signIn()` authenticates via Supabase Auth
  first; all subsequent DB reads run under `authenticated`. Dropping all
  `anon` policies is safe with no code changes required.

---

## Lessons Learned (carried forward from Session 11)

- **`/tmp` does not persist in Termux** — patch scripts must always write
  to `~/` (e.g. `~/fix_something.py`), never `/tmp/`.
- **Bash history expansion breaks `sed -i` with `!`** — use Python patch
  scripts for any anchor containing `!` characters.
- **`pathlib.Path.home()` returns `/root` in this environment** — use
  `os.path.expanduser('~')` instead.
- **React fragments (`<>`) inside a CSS grid don't create grid items** —
  render message strips outside the grid container.
- **`database.py` prefixes all doctor fields** — `license_number` becomes
  `doctor_license_number` in `patient_data`. Always check
  `_build_doctor_fields()` for exact key names.
- **W9 is a billing entity document, not a provider document.**
- **AOB assigns benefits to the billing entity, never the treating provider.**
- **NF-3 Section 16 LICENSE field is not NPI.**
