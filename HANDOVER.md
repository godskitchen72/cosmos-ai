# Cosmos Medical Technologies — HANDOVER (July 5, 2026, Session 17)

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

## Completed This Session

### W9 supervisor-chain deploy (carried from Session 15)

`BillerDashboard.tsx` + `billing/page.tsx` W9 patch confirmed already
committed before Session 17 started. `tsc --noEmit` passed clean.
Working tree clean — no deploy action needed.

### NF-3 workflow redesign — full implementation

**Product decision:** NF-3 generation moves from FD to Biller. FD role
becomes validation-only (preflight check). Biller generates NF-3 per visit
directly from the billing queue.

**Migration 020:** `patient_visits.nf3_preflight_passed boolean DEFAULT false`
+ `biller_md_flags` table with RLS.

**FD (`PatientProfile.tsx`):**
- NF-3 card replaced with "NF-3 Preflight" card
- Opens `PreflightModal` — checks 8 required fields (signature, carrier,
  claim #, policy #, DOI, attorney, CPT codes, ICD-10 codes for selected visit)
- Green = present, red = missing. "Confirm Ready" writes
  `nf3_preflight_passed = true` on the visit
- Submission gate updated: `hasNf3` replaced with `nf3_preflight_passed`
- `handleGenerateNF3` / `handleRegenerateNF3` removed

**Biller (`BillerDashboard.tsx`):**
- `+ NF-3` badge in Docs column generates NF-3 when missing; flips to
  tappable `NF-3` badge when generated
- `⚑ Flag MD` button per row — opens `FlagMdModal`

**Biller → MD flag system (`biller_md_flags` table):**
- Flag reasons: Missing/Incorrect CPT Codes, Missing/Incorrect ICD-10 Codes
- Full CPT and ICD-10 code library pickers in flag modal
- Suggested codes stored as `suggested_cpt_codes text[]` and
  `suggested_icd10_codes text[]`
- Biller dashboard shows suggested codes in amber (⏳) alongside confirmed
  cyan codes in CPT and ICD-10 columns
- Flagged rows show ⚠️ Flagged button; rejected rows show ↩ MD Rejected
  with Dismiss × button

**MD (`MDClient.tsx`):**
- Persistent amber alert card at top of dashboard for unresolved flags
- Shows patient name, visit date, reason, note, suggested CPT and ICD-10 codes
- Tapping flag navigates to `/md/[patientId]?visit_id=[flaggedVisitId]`

**MD (`PatientChart.tsx`):**
- Flag strip rendered when `visit_id` URL param matches an open flag
- Shows suggested codes with Accept & Apply / Reject options
- Accept: pre-fills code pickers with suggested codes (additive)
- Reject: writes `resolved_at + resolution: rejected + rejection_note`
- On visit save after accept: auto-resolves flag as `accepted`

**Migrations run:**
- `020`: `nf3_preflight_passed` + `biller_md_flags` table + RLS
- `021`: `biller_md_flags.suggested_cpt_codes text[]`,
  `suggested_icd10_codes text[]`
- `022`: `biller_md_flags.resolution text`, `rejection_note text`,
  `biller_dismissed_at timestamptz`

### IcdReferral.tsx — Authorization header fix

`app/md/[patientId]/icd10/IcdReferral.tsx` was missing `getAuthToken()`
and the `Authorization: Bearer` header on its fetch call. Added both.
All other referral screens confirmed already had the header — grep
false-positive from multi-line fetch pattern.

### Biller dashboard docs column

Docs column (NF-3, AOB, PCE, W9, Flag MD) confirmed rendering in a single
horizontal `nowrap` row. Multiple layout iterations required due to Tailwind
purge — final fix uses inline `style={{ display:'flex', flexDirection:'row',
flexWrap:'nowrap' }}` rather than Tailwind classes.

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
   (free/starter tier). First PDF generation after idle takes 5–10s.
   Upgrading to a paid always-on tier is the single biggest real-world
   speed improvement available.

6. **Failed PIN attempt lockout** — Enterprise Hardening Stage 2 remainder.

7. **MFA for admin and billing roles** — Enterprise Hardening Stage 2.

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

**Biller W9 resolution:** W9 on the biller dashboard walks the supervisor
chain (`doctor.w9_url → supervisor.w9_url`). The `doctors` prop fetched in
`billing/page.tsx` must include `supervising_provider_id` for this to work.

**`nf3_preflight_passed` gate:** FD submission now requires preflight check
instead of NF-3 generation. `PatientProfile.tsx` reads this from
`patient_visits` via `select('*')` — no explicit column selection needed.

**`biller_md_flags` fetch condition:** `billing/page.tsx` fetches both
`resolved_at IS NULL` (pending) and `resolution = rejected AND
biller_dismissed_at IS NULL` (rejected, not yet dismissed by biller).
Uses PostgREST `.or()` filter — confirm RLS covers authenticated role
for all commands if flag queries ever return unexpectedly empty.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 17 — NF-3 generation, Flag MD with code pickers, suggested codes amber display, reject/dismiss flow) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17 — CPT/ICD-10 fetches, biller_md_flags with resolution columns) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 17 — biller flag strip, Accept & Apply, Reject with note, auto-resolve on save) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 17 — persistent biller flag alert card with suggested codes, visit_id in nav URL) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 17 — NF-3 preflight modal, updated submission gate) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17 — Authorization header added) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 15) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 14) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 14) |
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
- **Tailwind purge eliminates classes not present at build time** — when a
  new Tailwind class is added to a component that previously didn't use it,
  it may not appear in the generated CSS bundle. Use inline `style={{}}` as
  the reliable fallback for one-off layout fixes on the Biller dashboard.
- **`grep` multi-line fetch pattern gives false positives** — `grep "fetch("
  | grep -v "Authorization"` misses auth headers on the next line. Always
  verify by viewing the actual lines around the match before concluding a
  header is missing.
- **Biller W9 badge requires supervisor-chain resolution** — a simple
  `doctor.w9_url` join is insufficient for supervised providers. Walk
  `doctor → supervising_provider_id → supervisor.w9_url`.
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
