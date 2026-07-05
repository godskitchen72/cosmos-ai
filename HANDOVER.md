# Cosmos Medical Technologies — HANDOVER (July 5, 2026, Session 18)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed via `tsc --noEmit` + full
deploy chain. Live app confirmed healthy at session close. No outstanding
TypeScript errors.

---

## Completed This Session (Session 18)

### Admin page refactor — complete

`app/admin/page.tsx` split from 2,761 lines into 9 files. Pure structural
refactor — zero behavioral changes, all functionality confirmed working.

**New file structure:**

```
app/admin/
  page.tsx                    ← shell only, 114 lines (tab router + header)
  shared.tsx                  ← all shared helpers, components, constants
  components/
    OverviewSection.tsx        ← practice info, security, KPIs, locations
    CarriersSection.tsx        ← insurance carriers CRUD + CSV import
    DoctorsSection.tsx         ← providers CRUD, credentials/billing/schedule tabs
    LawyersSection.tsx         ← lawyers CRUD, grouped by firm
    CptCodesSection.tsx        ← CPT codes CRUD + CSV import + ICD-10 map
    Icd10Section.tsx           ← ICD-10 codes CRUD + CSV import
    UsersSection.tsx           ← user management, PIN reset, activate/deactivate
    AuditLogSection.tsx        ← TanStack Table, category filters, pagination
```

**`shared.tsx` exports:** `getAuthToken`, `PDF_API_URL`, `formatPhone`,
`Field`, `SectionHeading`, `STATES`, `StateSelectField`, `SignaturePad`,
`TAX_CLASS_OPTIONS`, `LLC_CLASS_OPTIONS`, `SPECIALTY_OPTIONS`,
`LICENSE_TYPE_OPTIONS`, `BLANK_DOCTOR`, `PROVIDER_TYPES`.

**Key preservation notes:**
- `useMemo` on `filtered` in `AuditLogSection` preserved intact (prevents
  TanStack Table infinite re-render freeze)
- `handlePracticeSave` scoped to `OverviewSection` only (owns both Practice
  Info and Security & Access save)
- `TAX_LABELS` (display-only, Overview) kept local to `OverviewSection`
- `KpiCard` kept as local function inside `OverviewSection`
- `DoctorCard` kept as local function inside `DoctorsSection` IIFE
- `UsersSection.getToken` left as-is (identical to `getAuthToken` but pure
  refactor = no behavioral changes)
- `admin-tab` custom event listener preserved in shell `page.tsx`

---

## Open Items, Priority Order

1. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

2. **Signed URL caching** — deferred by explicit product decision.

3. **Doctor mailing address data** — Gottesman and Kramer placeholders.
   Required for NF-3/W9 accuracy in production.

4. **`patients.doctor_id` NOT NULL** — deferred to pre-production.

5. **Render "always on"** — upgrade for PDF speed.

---

## Enterprise Hardening Checklist (running)

### Stage 1 — Data Integrity ✅ Complete
- [x] FK constraints (Session 10)
- [x] Full RLS audit (Session 12)
- [x] NOT NULL constraints (Session 12)

### Stage 2 — Security ✅ Complete
- [x] API JWT authentication (Session 13)
- [x] Session timeout (Session 13)
- [x] Failed PIN attempt lockout (Session 17)
- [x] MFA for admin/billing/superadmin — TOTP, 30-day device trust (Session 17)
- [x] Audit log table — DB triggers + frontend logging (Session 17)
- [ ] HIPAA BAA with Supabase — administrative, sign in Supabase dashboard

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
must point to the user's own `doctors` row, not their supervisor.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null
`doctor_id`. Constraint deferred to pre-production go-live pass.

**`cosmos_license_type` in sessionStorage:** CPT filter depends on this
value being set at login. NP and PA map to MD codes via `effectiveLicenseType`.

**Session timeout SSR:** `useSessionTimeout` reads sessionStorage inside
`useEffect` to avoid SSR crash.

**Superadmin timeout exemption:** Superadmin gets `cosmos_session_timeout_minutes = '0'`
at login. Hook treats `0` as disabled.

**Biller W9 resolution:** `billing/page.tsx` must include
`supervising_provider_id` in doctors select for W9 chain to work.

**`nf3_preflight_passed` gate:** FD submission requires preflight check.
`PatientProfile.tsx` reads from `patient_visits` via `select('*')`.

**`biller_md_flags` fetch condition:** `billing/page.tsx` fetches both
pending and rejected-undismissed flags via PostgREST `.or()`.

**Audit log user attribution:** DB trigger entries show "System" for user —
no session context available in PostgreSQL trigger functions. Only
frontend-written entries have real user attribution.

**`audit_logs` anon RLS:** Table has authenticated INSERT only — frontend
`writeAuditLog()` works because users are authenticated when actions fire.
Login failure logging works because the attempt insert happens after
Supabase auth is called (which creates an anon session context).

**MFA `localStorage` device trust:** Key format:
`cosmos_mfa_trusted_{email_normalized}`. 30-day expiry as Unix timestamp.
Clearing localStorage or new browser forces re-challenge.

**`login_attempts` RLS:** Must include `anon` role — lockout check runs
before user is authenticated.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 18 — shell only, 114 lines) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/OverviewSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/CarriersSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/LawyersSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/UsersSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/admin/components/AuditLogSection.tsx` | ★ Verified-final (Session 18 — new) |
| `cosmos-dashboard/app/lib/auditLogger.ts` | ★ Verified-final (Session 17 — new file) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 17 — PIN lockout + TOTP MFA + audit logging) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 17 — audit logging added) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 17 — biller flag strip, audit logging) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 17 — NF-3 preflight, audit logging) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 17 — biller flag alert card) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17 — Authorization header) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17 — biller flags with resolution columns) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 17 — queue subtitle updates) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 15) |
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/hooks/useSessionTimeout.ts` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/dme/DmeReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/ortho/OrthoReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/vng/VngReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/rx/RxReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/pt/PtReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/ans/AnsReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 13) |
| `cosmos-api/main.py` | ★ Verified-final (Session 13) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 13) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 13) |
| `cosmos-api/database.py` | ★ Verified-final (Session 12) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (Session 11) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (Session 11) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 17 — reset_mfa handler) |
| `cosmos-api/forms/ans.py`, `icd10.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

---

## Lessons Learned (carried forward)

- **`cat > file << 'ENDOFFILE'` heredoc is the reliable full-file write method**
- **Chrome silently saves re-downloads as `filename-1.ext`** — always `ls -lt` before `cp`
- **Tailwind purge eliminates classes not present at build time** — use inline `style={{}}` as fallback
- **`grep` multi-line fetch pattern gives false positives** — view actual lines before concluding header is missing
- **MFA `localStorage` device trust uses email-derived key** — clearing localStorage forces re-challenge
- **Supabase `mfa.listFactors()` returns `factors.totp` array** — filter by `status === 'verified'`
- **`login_attempts` RLS must include `anon` role** — lockout check runs before authentication
- **Audit log DB triggers show "System" for user** — no PostgreSQL session context; use frontend `writeAuditLog()` for user-attributed events
- **TanStack Table data prop must be memoized** — passing a non-memoized filtered array causes infinite re-renders and freezes; always wrap in `useMemo`
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
- **CosmosUI `toastSuccess`/`toastError` both route through `AlertModal`**
- **New screens must mount `<AlertModal />` and `<ConfirmModal />`**
- **`sessionStorage` reads must be in `useEffect`**
- **Bash history expansion breaks inline `python3 -c` with `!`**
- **Render env var changes trigger automatic redeploy**
- **`~/storage/downloads/` writes can silently fail** — verify with `wc -l` or `ls`
- **Large file refactors: read full source before splitting** — never reconstruct from changelog summaries
- **`shared.tsx` pattern: all cross-section helpers in one file** — eliminates duplicate imports across component splits
