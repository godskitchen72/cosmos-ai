# Cosmos Medical Technologies — HANDOVER (July 4, 2026, Session 13)

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

### `forms/mri.py` — full backend audit

Obtained and audited for the first time. All Session 12 frontend keys
correctly wired:
- Extremity left/right keys (`mri.left_*`, `mri.right_*`) — loop confirmed
- Contrast type (`contrast.type`) — correct
- CT studies (`ct.*`) — correct
- Insurance fields (`policy_number`, `group_number`, `precert_number`) — correct
- Signature injection (`provider.signature`, `mri.attestation.signature`) — correct

No backend changes required. Confidence level upgraded to ★ Verified-final.

### MRI Spine order fix

`MRI_SPINE` array reordered to clinical standard:
Cervical → Thoracic → Lumbar (was Cervical → Lumbar → Thoracic).

### CosmosUI standard — fully adopted app-wide

All remaining screens migrated to CosmosUI notification standard:
- `DmeReferral.tsx` — `cosmosConfirm`, `AlertModal`/`ConfirmModal` mounted
- `OrthoReferral.tsx`, `PainMgmtReferral.tsx`, `VngReferral.tsx`,
  `RxReferral.tsx`, `PtReferral.tsx`, `AnsReferral.tsx` — `cosmosConfirm`,
  `AlertModal`/`ConfirmModal` mounted, `toastError` replacing inline error divs
- `app/calendar/page.tsx` — `cosmosConfirm`, `AlertModal`/`ConfirmModal` mounted
- Native `alert()`/`confirm()` now eliminated app-wide. Only remaining
  `confirm(` in codebase is the fallback inside `CosmosUI.tsx` itself.

`SessionTimeoutModal` added to `CosmosUI.tsx`.

### Enterprise Hardening Stage 2 — API JWT authentication

All 15 `cosmos-api` POST endpoints protected with `verify_jwt` FastAPI
dependency. Verification calls Supabase `/auth/v1/user` with the Bearer
token. Unauthenticated requests return HTTP 401 `"Not authenticated"`.

**Backend changes (`cosmos-api/main.py`):**
- Added `httpx`, `HTTPBearer`, `Depends` imports
- `SUPABASE_ANON_KEY` env var added to Render (required for token verification)
- `verify_jwt` async function — verifies token against Supabase auth endpoint
- All 15 POST routes: `dependencies=[Depends(verify_jwt)]` added
- `httpx` added to `requirements.txt`

**Frontend changes — all `cosmos-api` fetch calls updated:**
- `getAuthToken()` helper injected into every file that calls `cosmos-api`
- `Authorization: Bearer ${await getAuthToken()}` header added to all fetches
- Files updated: `PatientProfile.tsx`, `PatientChart.tsx`, `admin/page.tsx`,
  `OrthoReferral.tsx`, `PainMgmtReferral.tsx`, `VngReferral.tsx`,
  `RxReferral.tsx`, `PtReferral.tsx`, `AnsReferral.tsx`, `MriReferral.tsx`,
  `DmeReferral.tsx`

**Confirmed:** `curl` test returns `HTTP 401 {"detail":"Not authenticated"}`
for unauthenticated POST. Authenticated users experience no change.

### Enterprise Hardening Stage 2 — Session timeout

Inactivity-based auto sign-out implemented across all four dashboards.

**Architecture:**
- `app/hooks/useSessionTimeout.ts` — new shared hook. Reads timeout duration
  from `sessionStorage` inside `useEffect` (SSR-safe). Starts inactivity
  timer on mount, resets on any user interaction (tap, scroll, keypress,
  click). Shows `SessionTimeoutModal` 60 seconds before expiry. Signs out
  and redirects to `/` on expiry or "Sign Out" tap.
- `SessionTimeoutModal` — added to `CosmosUI.tsx`. Orange border/text,
  countdown display, "Stay Logged In" + "Sign Out" buttons.
- Migration 019: `ALTER TABLE practice_settings ADD COLUMN session_timeout_minutes int NOT NULL DEFAULT 15`

**Configuration:**
- Default: 15 minutes
- Configurable from Admin → Practice Settings → Session Timeout dropdown
  (15 / 30 / 60 / 90 minutes)
- Value read from `practice_settings` at login, stored as
  `cosmos_session_timeout_minutes` in sessionStorage
- Superadmin exempt: `'0'` written to sessionStorage at superadmin login;
  hook treats `0` as disabled, no timers start

**Mounted on:** `DashboardClient.tsx`, `MDClient.tsx`, `admin/page.tsx`,
`BillerDashboard.tsx`

**Admin panel:** Session Timeout selector added to Practice Settings edit
form (`pForm.session_timeout_minutes`, saves to `practice_settings` via
existing `handlePracticeSave`).

### `DmeReferral.tsx` — correctness confirmed + CosmosUI

`forms/dme.py` audited — all backend keys correctly match the frontend.
The HANDOVER concern about blank fields was the docstring's own warning
from file creation; the frontend was subsequently built correctly.
`cosmosConfirm` added, `AlertModal`/`ConfirmModal` mounted.

### Patch script cleanup

All accumulated patch scripts from previous sessions deleted from `~/`.

---

## Open Items, Priority Order

1. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

2. **`PatientProfile.tsx` — remaining `confirm()`** — one native
   `confirm()` call remains in `PatientProfile.tsx`. Not yet converted
   to `cosmosConfirm`. Needs `AlertModal`/`ConfirmModal` mount audit.

3. **Signed URL caching** — `supabase.storage.createSignedUrl()` called
   fresh on every "View" tap. Caching the URL client-side after first
   call would eliminate the Supabase round trip on subsequent taps.
   Deferred by explicit product decision.

4. **Doctor mailing address data** — Gottesman and Kramer are independent
   MDs with placeholder mailing addresses. Required for NF-3/W9 accuracy
   in production.

5. **`patients.doctor_id` NOT NULL** — deferred to pre-production. 3 test
   patients have null `doctor_id`.

6. **Render "always on"** — `cosmos-api` spins down on inactivity
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

**NF-3 message state is module-level (`nf3Msg`):** `nf3Msg` useState is
declared at module level not inside the component. Low risk but
architecturally incorrect. Fix on next full `PatientProfile.tsx` rebuild.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null
`doctor_id`. Constraint deferred to pre-production go-live pass.

**`cosmos_license_type` in sessionStorage:** CPT filter depends on this
value being set at login. If a provider logs in without a `license_type`
in the `doctors` table, all CPT codes will show (safe fallback, not a bug).

**Session timeout SSR:** `useSessionTimeout` reads sessionStorage inside
`useEffect` to avoid SSR crash. If hook is mounted on a server-rendered
page without `'use client'`, it will silently no-op (safe).

**Superadmin timeout exemption:** Superadmin gets `cosmos_session_timeout_minutes = '0'`
written at login. Hook treats `0` as disabled. If superadmin navigates to
a role dashboard (FD, MD, etc.) the exemption persists for that session.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 13 — SessionTimeoutModal added) |
| `cosmos-dashboard/app/hooks/useSessionTimeout.ts` | ★ Verified-final (Session 13 — new file) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 13 — spine order fix, AlertModal mount) |
| `cosmos-dashboard/app/md/[patientId]/dme/DmeReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals mounted) |
| `cosmos-dashboard/app/md/[patientId]/ortho/OrthoReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals, toastError) |
| `cosmos-dashboard/app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals, toastError) |
| `cosmos-dashboard/app/md/[patientId]/vng/VngReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals, toastError) |
| `cosmos-dashboard/app/md/[patientId]/rx/RxReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals, toastError) |
| `cosmos-dashboard/app/md/[patientId]/pt/PtReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals, toastError) |
| `cosmos-dashboard/app/md/[patientId]/ans/AnsReferral.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals, toastError) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 13 — cosmosConfirm, modals mounted) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 13 — JWT headers, session timeout selector, useSessionTimeout hook) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 13 — JWT headers, useSessionTimeout hook) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 13 — JWT headers, useSessionTimeout hook) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 13 — useSessionTimeout hook) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 13 — JWT headers; one confirm() remains) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 13 — JWT headers) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 13 — session_timeout_minutes stored at login, superadmin exempt) |
| `cosmos-api/main.py` | ★ Verified-final (Session 13 — verify_jwt on all 15 POST routes) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 13 — full audit, all keys confirmed) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 13 — full audit, all keys confirmed) |
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

- **Bash history expansion breaks inline `python3 -c` with `!`** — any
  string containing `!confirm`, `!await` etc. triggers bash history
  substitution even inside Python `-c` strings. Always use a patch script
  file (`~/patch_name.py`) for anchors containing `!`.
- **`sessionStorage` must be read inside `useEffect`** — reading at hook
  function top level fires server-side (SSR) where sessionStorage doesn't
  exist. This caused the session timeout modal to fire immediately for
  superadmin. Fixed by moving all sessionStorage reads inside `useEffect`.
- **Supabase anon key needed for JWT verification** — `SUPABASE_SERVICE_KEY`
  alone is not sufficient. Verifying user tokens requires the anon key as
  the `apikey` header on `/auth/v1/user` requests.
- **Render env var changes trigger an automatic redeploy** — adding
  `SUPABASE_ANON_KEY` in the Render dashboard immediately triggered a
  deploy. Backend and frontend deploys must be coordinated: backend first,
  then frontend. Deploying frontend with JWT headers before backend has
  `verify_jwt` would break all PDF generation.
- **`httpx` must be in `requirements.txt`** — FastAPI's async HTTP client
  is not bundled. Omitting it from requirements causes a Render build failure.
- **Calendar page uses `background:'#0a0e1a'`** — different from the
  `#080d14` used by referral screens. Root div anchors must be verified
  per-file, not assumed consistent.
- **Superadmin lands on a dashboard picker, not a dashboard** — timeout
  hook is mounted on the four actual dashboards (FD, MD, Admin, Biller).
  The picker stage in `app/page.tsx` has no hook. Writing `'0'` to
  sessionStorage at superadmin login propagates the exemption to whichever
  dashboard they subsequently enter.
- **Chrome download suffix collision** — when downloading a file that
  already exists in Downloads, Chrome appends `-1`, `-2` etc. Always
  verify the correct file using File Manager sorted by date, not the
  Claude app file picker which shows stale cache.

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
