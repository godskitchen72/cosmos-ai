# Cosmos Medical Technologies — HANDOVER (July 4, 2026, Session 14)

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

### CosmosUI standard — PatientProfile.tsx complete

All `alert()` and `confirm()` calls converted to CosmosUI. `ConfirmModal`
mounted (was missing despite `AlertModal` being present). `cosmosConfirm`
now gates all four regenerate/undo actions (NF-2, AOB, NF-3, PCE). Dead
`nf3Msg` state and `setTimeout` no-op removed. Amber NF-3 warning strip
removed — NF-3 card locked tap now fires `toastError` directly.
Native browser dialogs now fully eliminated app-wide.

### Session 13 regression fixes

Two regressions introduced by Session 13's JWT hardening, discovered and
fixed this session:

**NF-2 / AOB generation broken** — `generateForm()` module-level helper
was missing the `Authorization: Bearer` header. Added `token` parameter,
passed `await getAuthToken()` from both call sites in `handleGenerate` and
`handleRegenerate`.

**MD/PA/NP location picker bypass** — `app/page.tsx` was auto-navigating
when a doctor had exactly one location (`locs.length > 1` condition).
Product rule is picker always required for MD/PA/NP regardless of location
count. Condition removed; picker always shown.

### Blank signature guard — all SignaturePad components

`isCanvasBlank()` check added to `save()` in both `PatientProfile.tsx`
(patient signatures) and `admin/page.tsx` (doctor/staff signatures).
Saving a blank canvas now fires `toastError` instead of silently writing
an empty PNG.

### NP/PA CPT code mapping

`PatientChart.tsx` now maps `NP` and `PA` license types to `MD` CPT codes
at the filter level (`effectiveLicenseType`). No data duplication — both
provider types see MD-tagged codes. Debug `console.log` removed.

### CPT import — Option A architecture + error handling

`handleCptImportConfirm` in `admin/page.tsx` rebuilt:
- CPT rows deduplicated by `cpt_code` before upsert (root cause of silent
  failure when CSV has multiple ICD-10 rows per CPT code)
- ICD-10 codes upserted to `icd10_codes` (deduplicated by `code`)
- CPT↔ICD-10 mappings upserted to `cpt_icd10_map` on composite key
  `(cpt_code, icd10_code)` — idempotent, re-import safe
- Full error handling on all three upserts via `toastError`
- Success toast confirms counts of CPT codes, ICD-10 codes, and mappings

**RLS fix:** `icd10_codes` table was missing an `authenticated` INSERT/UPDATE
policy — discovered when import surfaced the error. Fixed via SQL.

### CPT import — Download Template link

A "⬇ Download Import Template" link added below the Import CSV button in
`CptCodesSection`. Generates CSV client-side as a blob URL. Always
current, no server dependency.

### CPT import template format documented

Correct format confirmed and documented in `PRODUCT_SPEC.md` §12.

---

## Open Items, Priority Order

1. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

2. **Signed URL caching** — `supabase.storage.createSignedUrl()` called
   fresh on every "View" tap. Deferred by explicit product decision.

3. **Doctor mailing address data** — Gottesman and Kramer are independent
   MDs with placeholder mailing addresses. Required for NF-3/W9 accuracy
   in production.

4. **`patients.doctor_id` NOT NULL** — deferred to pre-production. 3 test
   patients have null `doctor_id`.

5. **Render "always on"** — `cosmos-api` spins down on inactivity
   (free/starter tier). First PDF generation after idle takes 5-10s.
   Upgrading to a paid always-on tier is the single biggest real-world
   speed improvement available.

---

## Enterprise Hardening Checklist (running)

### Stage 1 — Data Integrity ✅ Complete
- [x] FK constraints — all tables audited and complete (Session 10)
- [x] Full RLS audit — every table, every command, both roles (Session 12)
- [x] `NOT NULL` constraints on required columns (Session 12);
      `patients.doctor_id` deferred to pre-production

### Stage 2 — Security
- [x] API JWT authentication on all `cosmos-api` endpoints (Session 13)
- [x] Session timeout / auto sign-out after inactivity (Session 13)
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

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null
`doctor_id`. Constraint deferred to pre-production go-live pass.

**`cosmos_license_type` in sessionStorage:** CPT filter depends on this
value being set at login. NP and PA now map to MD codes via
`effectiveLicenseType` in `PatientChart.tsx`. If a provider logs in
without a `license_type` in the `doctors` table, all codes show (safe
fallback).

**Session timeout SSR:** `useSessionTimeout` reads sessionStorage inside
`useEffect` to avoid SSR crash. If hook is mounted on a server-rendered
page without `'use client'`, it will silently no-op (safe).

**Superadmin timeout exemption:** Superadmin gets `cosmos_session_timeout_minutes = '0'`
written at login. Hook treats `0` as disabled. If superadmin navigates to
a role dashboard (FD, MD, etc.) the exemption persists for that session.

**`SignaturePad` uses `alert()` — intentional exception:** Both
`SignaturePad` components use a plain `alert()` for the blank-canvas
guard. These are module-level components; converting to `toastError`
was done this session (confirmed working). This note can be removed.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 14 — full CosmosUI, blank sig guard, nf3Msg removed) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 14 — blank sig guard, CPT import fix + Option A + template link) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 14 — location picker always shown for MD/PA/NP) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 14 — NP/PA→MD CPT mapping, debug log removed) |
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 13 — SessionTimeoutModal added) |
| `cosmos-dashboard/app/hooks/useSessionTimeout.ts` | ★ Verified-final (Session 13 — new file) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/dme/DmeReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/ortho/OrthoReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/vng/VngReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/rx/RxReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/pt/PtReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/ans/AnsReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 13) |
| `cosmos-api/main.py` | ★ Verified-final (Session 13) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 13) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 12) |
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
| `cosmos-api/forms/ans.py`, `icd10.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **`generateForm()` was not in the Session 13 JWT sweep** — module-level
  helper functions that call `cosmos-api` are easy to miss when adding auth
  headers. Any future JWT audit must grep for all `fetch(` calls against
  `PDF_API_URL`, not just named handlers.
- **MD location picker had a single-location bypass** — `locs.length > 1`
  was the condition for showing the picker. Product rule is picker always
  required; never gate the location picker on location count.
- **`~/storage/downloads/` writes can silently fail** — `git show HEAD:path
  > ~/storage/downloads/file && echo "OK"` prints OK even when the write
  fails due to storage permissions. Always verify with `wc -l` or `ls`.
  Writing to `~/` directly is the reliable fallback.
- **CPT importer failed silently due to duplicate conflict keys** — sending
  multiple rows with the same `cpt_code` in one upsert batch causes the
  entire batch to fail with no error surfaced. Always deduplicate by the
  conflict key before batch upsert.
- **`icd10_codes` was missing an authenticated INSERT/UPDATE RLS policy** —
  the Session 12 RLS audit locked all tables to `authenticated` for SELECT,
  but `icd10_codes` was missing the INSERT/UPDATE commands. Discovered via
  the new import error handling. Fixed with a full `ALL` policy.
- **Always request full files — never use grep/sed inspection mid-task** —
  when an anchor fails or a question arises about file contents, request
  the full file. Falling back to grep/sed inspection commands is a
  protocol violation confirmed this session.
- **`SignaturePad` blank-canvas guard uses `toastError`** — both
  `PatientProfile.tsx` and `admin/page.tsx` components confirmed working
  with `toastError` (not `alert()`); CosmosUI singleton pattern reaches
  module-level components when `AlertModal` is mounted in the parent tree.

---

## Lessons Learned (carried forward)

- **`/tmp` does not persist in Termux** — patch scripts must always write
  to `~/`, never `/tmp/`.
- **`pathlib.Path.home()` returns `/root` in this environment** — use
  `os.path.expanduser('~')` instead.
- **React fragments (`<>`) inside a CSS grid don't create grid items** —
  render message strips outside the grid container.
- **`database.py` prefixes all doctor fields** — `license_number` becomes
  `doctor_license_number` in `patient_data`.
- **W9 is a billing entity document, not a provider document.**
- **AOB assigns benefits to the billing entity, never the treating provider.**
- **NF-3 Section 16 LICENSE field is not NPI.**
- **`patients` primary key is `patient_id` (text)** — not `id`. Format: `PT457696`.
- **Supervised providers legitimately have null mailing addresses** —
  `database.py` resolves to supervisor at PDF time.
- **CosmosUI `toastSuccess`/`toastError` both route through `AlertModal`**
  — the `ToastContainer` is mounted but all exported helpers use `_openAlert`.
- **New screens must mount `<AlertModal />` and `<ConfirmModal />`** —
  singleton global overlays; if not mounted, notifications silently fall
  back to native `window.confirm`.
- **`sessionStorage` reads must be in `useEffect`** — server-side renders
  always return `''`.
- **Bash history expansion breaks inline `python3 -c` with `!`** — always
  use a patch script file for anchors containing `!`.
- **Render env var changes trigger an automatic redeploy** — coordinate
  backend and frontend deploys; backend must have `verify_jwt` before
  frontend sends JWT headers.
