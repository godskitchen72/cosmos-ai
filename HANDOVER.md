# Cosmos Medical Technologies — HANDOVER (July 5, 2026, Session 16)

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

**One open deploy carried from Session 15:** The billing W9 supervisor-chain
fix (`BillerDashboard.tsx` + `billing/page.tsx`) was patched and confirmed
via node script (all checks OK) but `tsc --noEmit` + deploy chain was not
run before Session 15 ended. This must be the first task of Session 17 —
verify TSC passes and deploy before any other work.

---

## Completed This Session

### Documentation update only

Session 16 was a documentation-only session. No code was written or deployed.

Updated documents:
- `CHANGELOG.md` — Session 15 entries added (dev tools rebuild + W9 supervisor-chain fix)
- `ARCHITECTURE.md` — Migrations 017–019 added to §3 migration list; §10 login flow updated to reflect Session 14 fix (location picker now always shown for MD/PA/NP regardless of location count)
- `HANDOVER.md` — This document (Session 15 → Session 16)

---

## Open Items, Priority Order

1. **Complete billing W9 deploy** — `tsc --noEmit` + deploy chain for
   `BillerDashboard.tsx` + `billing/page.tsx` changes. First task Session 17.

2. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

3. **Signed URL caching** — `supabase.storage.createSignedUrl()` called
   fresh on every "View" tap. Deferred by explicit product decision.

4. **Doctor mailing address data** — Gottesman and Kramer are independent
   MDs with placeholder mailing addresses. Required for NF-3/W9 accuracy
   in production.

5. **`patients.doctor_id` NOT NULL** — deferred to pre-production. 3 test
   patients have null `doctor_id`.

6. **Render "always on"** — `cosmos-api` spins down on inactivity
   (free/starter tier). First PDF generation after idle takes 5–10s.
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

**Biller W9 resolution:** W9 on the biller dashboard now walks the supervisor
chain (`doctor.w9_url → supervisor.w9_url`). The `doctors` prop fetched in
`billing/page.tsx` must include `supervising_provider_id` for this to work —
confirmed added Session 15, deploy pending Session 17.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 15 — full rebuild: live CPT, visit count, DOI guard, individual referral selector, Render warm-up) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | Patched Session 15 (W9 supervisor-chain resolution) — TSC + deploy pending Session 17 |
| `cosmos-dashboard/app/billing/page.tsx` | Patched Session 15 (`supervising_provider_id` added to doctors select) — TSC + deploy pending Session 17 |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 14) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 14) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 14) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 14) |
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
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 13) |
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
| `cosmos-api/forms/ans.py`, `icd10.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

---

## Lessons Learned (carried forward)

- **`cat > file << 'ENDOFFILE'` heredoc is the reliable full-file write
  method** — single-quoted delimiter prevents all bash expansion. `node -e`
  inline and `sed` both break on `!` characters (bash history expansion).
  Use `.js` patch script files written via heredoc and run via `node ~/patch.js`
  for all structural replacements.
- **Chrome silently saves re-downloads as `filename-1.ext`** — always run
  `ls -lt ~/storage/downloads/filename*` before `cp` to confirm which copy
  is newest. Or clear old copies with `rm -f` first.
- **Biller W9 badge requires supervisor-chain resolution** — a simple
  `doctor.w9_url` join is insufficient for supervised providers. The billing
  entity W9 must walk `doctor → supervising_provider_id → supervisor.w9_url`.
  Implemented in `BillerDashboard.tsx`.
- **Dev generator Render cold-start pattern** — warm-up ping must fire before
  each patient's referral batch, not just once at session start.
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
- **`~/storage/downloads/` writes can silently fail** — `git show HEAD:path
  > ~/storage/downloads/file && echo "OK"` prints OK even when the write
  fails. Always verify with `wc -l` or `ls`. Writing to `~/` directly is
  the reliable fallback.
