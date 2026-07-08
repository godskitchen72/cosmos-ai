# Cosmos Medical Technologies — HANDOVER (July 7, 2026, Session 24)

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
Re-login hang fully resolved. Patch script cleanup complete.
TurboSMTP account closed (spam detection). SendGrid is the target provider.

---

## Completed This Session (Session 24)

### Re-login hang — fully resolved

**Root cause:** `setLoading(false)` was never called on the success path of
`handleLogin`. After all 8 login steps completed, `loading` remained `true`.
On the second login the component was still mounted with `loading=true`,
causing the button to show "Signing in…" indefinitely even though
authentication succeeded.

**Fixes applied to `app/page.tsx`:**

1. `setLoading(false)` added before `setStage`/`setReady` in all
   `handlePostLogin` branches (superadmin, md/pa/np, other roles).

2. `cosmos_login_marker` sessionStorage guard in `useEffect` — only restores
   a prior session if the marker is present. Prevents stale Supabase auth
   tokens from a prior user auto-navigating on page load.

3. Direct `localStorage.removeItem('sb-ttudxnzmybcwrtqlbtta-auth-token')`
   before `signIn` — clears stale session token synchronously without
   racing the Supabase singleton client's async state machine.

4. All Sign Out buttons (superadmin picker, location picker, MFA setup,
   MFA challenge): `sessionStorage.clear()` + `setLoading(false)` +
   `setError('')` — ensures full state reset on every sign-out.

5. `autoComplete="email"` on email field, `autoComplete="current-password"`
   on PIN field — restores browser saved credential support (was `new-password`
   during debugging, which suppressed autofill entirely).

6. Debug instrumentation (`debugLog` state, `dlog()`, on-screen cyan log panel)
   added during diagnosis and fully removed in final clean rewrite.

**Key lesson:** The hang was not in `signIn`, `getUserProfile`, `login_attempts`,
`writeAuditLog`, or `checkAndHandleMfa` — all completed. The missing
`setLoading(false)` on the success path left React with stale loading state
after stage transition.

### Patch script cleanup

`rm ~/fix_*.py ~/patch_*.py ~/rewrite_*.py` — confirmed clean.

---

## Completed Prior Sessions (carried forward)

### Session 23

**PC NPI full-stack:** Migration 025 (`pc_npi` on `doctors`), `_resolve_billing_npi`
in `database.py`, all 11 `forms/*.py` patched to `billing_npi`, `DoctorsSection.tsx`
UI, `shared.tsx` `BLANK_DOCTOR` updated.

**Dev generator:** `attorney_email` null gap fixed in `app/dev/page.tsx`.

**MD V2 dashboard:** `/md-v2/[patientId]` is now the primary MD patient chart.
`/md/[patientId]` remains the clinical visit entry point via Start Visit.
`MDClient.tsx` full shadcn rewrite routes to `/md-v2/`.

**TurboSMTP account closed:** `/send-billing-packet` broken. SendGrid required.

---

## Open Items, Priority Order

1. **SendGrid setup.** TurboSMTP closed. Set up SendGrid, domain auth
   SPF/DKIM, HIPAA BAA, swap Render env vars, update
   `send_billing_endpoint.py`.

2. **Supabase RLS alert on `patient_forms`.** Supabase security advisor
   flagged `patient_forms` as publicly accessible (RLS disabled). Known
   architecture gap. Must resolve before go-live with real patient data.
   Also flagged: sensitive columns exposed via API without access restrictions.

3. **`patient_forms` visit_id backfill.** Query:
   `SELECT form_type, visit_id, filename FROM patient_forms WHERE patient_id = 'PT331111'`
   — then backfill any null `visit_id` rows with the correct visit UUID.

4. **CPT codes `provider_type` product decision needed.** All 34 codes are
   MD only. Non-MD providers see empty CPT picker. Add `General` type or
   separate sets.

5. **DEV fill-all PCE button** — remove from `VisitTab.tsx` before go-live.

6. **`ARCHITECTURE.md` updates:** add MD V2 / MDClient / login to shadcn
   exceptions; add Migration 025 to migration list.

7. **Sidebar rollout to FD, MD, Biller.** Deferred.

8. **Doctor mailing address data.** Gottesman and Kramer placeholders.
   Test only.

9. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

10. **Vercel Pro upgrade.** Eliminates cold starts. Do at go-live.

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
- [x] Admin sidebar nav (Session 19)
- [x] MD V2 shadcn chart (Session 23)
- [x] MDClient shadcn list (Session 23)
- [x] Login shadcn (Session 23)
- [x] Re-login hang fixed (Session 24)
- [ ] Sidebar rollout — FD, MD, Biller dashboards
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, email provider
- [ ] Data retention and deletion policy
- [ ] Patient data export capability

---

## Known Architecture Gaps

**MD V2 as primary route:** `/md-v2/[patientId]` is the primary MD chart.
`/md/[patientId]` is the clinical visit entry point.
`/md` patient list routes to `/md-v2/` for all patient taps.
Biller flag taps route to `/md/` with `visit_id` for flag resolution.

**shadcn exception extended Session 23:** MD V2 route, MDClient, login page.
`ARCHITECTURE.md` needs update.

**`billing_npi` is the only NPI used in PDF forms.** `doctor_npi` retained in
`database.py` output dict for internal reference only. All `forms/*.py` confirmed.

**`pc_npi` column:** Migration 025. No on-disk SQL file.

**TurboSMTP closed:** `/send-billing-packet` returns SMTP error. `/generate-zip` fine.

**`patient_forms` RLS disabled:** Supabase security advisor flagged this table
as publicly accessible. Known gap — must be resolved before go-live.

**Auth server-component gap:** `createServerComponentClient` not exported.
`doctor_id` URL param is the reliable doctor-scoping path.

**`patient_visits.doctor_id` missing:** relies on `patients.doctor_id`.

**PA/NP users:** `user_profiles.doctor_id` must point to own `doctors` row.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null `doctor_id`.

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

**Audit log user attribution:** DB trigger entries show "System" — no
PostgreSQL session context. Only frontend-written entries have real user
attribution.

**`audit_logs` anon RLS:** Table has authenticated INSERT only — frontend
`writeAuditLog()` works because users are authenticated when actions fire.

**MFA `localStorage` device trust:** Key format:
`cosmos_mfa_trusted_{email_normalized}`. 30-day expiry as Unix timestamp.
Clearing localStorage or new browser forces re-challenge.

**`login_attempts` RLS:** Must include `anon` role — lockout check runs
before user is authenticated.

**Admin sidebar `localStorage`:** Key `cosmos_admin_sidebar_open`. Defaults
to expanded (`true`) on first load if key is absent.

**`ARCHITECTURE.md` migration list gap:** Migrations 020–024 from prior sessions.
Migration 025 (`pc_npi` on `doctors`) added Session 23. Note: 001–019 exist
as `.sql` files on disk; 020+ were run directly in Supabase dashboard SQL
editor — no on-disk files.

**Edit form scroll context:** CPT and ICD-10 edit forms must render at top
of section — sidebar layout makes bottom-rendered forms scroll out of mobile
viewport, appearing as if Edit does nothing.

**`_fmt_date` fallback:** Returns `"00000000"` when `doi` or `visit_date`
is null/missing. A `"00000000"` in a filename signals a missing date on the
patient record — data quality issue, not a code bug.

**Login `practice_settings` fetch:** Admin/billing path fetches both
`mfa_required` and `session_timeout_minutes` in one query via
`checkAndHandleMfa`. MD/PA/NP path fetches `session_timeout_minutes`
separately in `handlePostLogin` (no MFA check for those roles).

**`REFERRAL_FORM_CONFIG` dual keys:** `tag` = DB `form_type` value stored
in `patient_forms` (e.g. `"MRI"`, `"PAIN-MGMT"`) — never change these
without also updating `ReferralGrid.tsx` completion checks. `fn_type` =
lowercase filename token (e.g. `"mri"`, `"pm"`) — filename only, no DB usage.

**Zip `patient_forms` visit_id gap:** legacy `patient_forms` rows generated
before reliable visit linkage may have `visit_id = null`. These are
silently excluded from the billing packet zip. Backfill needed — see Open
Items #3.

**`send_billing_endpoint.py` register pattern:** The endpoint is extracted
to a separate file and wired into `main.py` via a `register()` function
that receives `app`, `get_db`, `verify_jwt`, `Depends`, `SUPABASE_URL`,
`SUPABASE_KEY`, `BUCKET`, and `_fmt_date` as arguments. This avoids
heredoc string literal corruption in Termux for files with multi-line
f-strings.

**TurboSMTP dev-only:** Account closed Session 23. Must switch to SendGrid
(or equivalent BAA-capable provider) before go-live with real patient data.

**`attorney_email` auto-fill:** Populated from `lawyers.email` when FD
selects an attorney in PatientForm. If attorney record has no email, field
remains blank and FD must enter manually. Backend returns HTTP 400 if
`patients.attorney_email` is null at send time.

**Login `cosmos_login_marker`:** Set in sessionStorage after successful login
for all roles. `useEffect` on mount skips session restore if marker is absent —
prevents stale Supabase auth tokens from prior user auto-navigating on page load.
Cleared by `sessionStorage.clear()` on every Sign Out button.

**Supabase auth token localStorage key:**
`sb-ttudxnzmybcwrtqlbtta-auth-token` — cleared directly before `signIn` in
`handleLogin` to avoid async `signOut()` racing the singleton Supabase client.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 24 — re-login hang fixed, clean rewrite, debug removed) |
| `cosmos-api/database.py` | ★ Verified-final (Session 23 — complete rewrite, `billing_npi`, `pc_npi`) |
| `cosmos-api/forms/nf2.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (Session 23 — `billing_npi`, internal resolver removed) |
| `cosmos-api/forms/pt.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/vng.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/pce.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/mri.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/ortho.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/rx.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/dme.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/ans.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/icd10.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/pain_mgmt.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 23 — `pc_npi` field) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 23 — `pc_npi` in `BLANK_DOCTOR`) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 23 — `attorney_email` fix) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 23 — shadcn, routes to `/md-v2/`) |
| `cosmos-dashboard/app/md-v2/[patientId]/page.tsx` | ★ Verified-final (Session 23 — new file) |
| `cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx` | ★ Verified-final (Session 23 — new file) |
| `cosmos-dashboard/app/md-v2/[patientId]/InfoTabV2.tsx` | ★ Verified-final (Session 23 — new file) |
| `cosmos-dashboard/app/md-v2/[patientId]/HistoryTabV2.tsx` | ★ Verified-final (Session 23 — new file) |
| `cosmos-dashboard/app/md-v2/page.tsx` | ★ Verified-final (Session 23 — new file, redirect to `/md`) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 23 — `sessionStorage.clear` on Sign Out) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 23 — `sessionStorage.clear` on Sign Out) |
| `cosmos-api/main.py` | ★ Verified-final (Session 22 — `/generate-zip` + `/send-billing-packet` wired) |
| `cosmos-api/send_billing_endpoint.py` | ★ Verified-final (Session 22 — new file) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 22 — `attorney_email` field + auto-fill) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 22 — backend zip, email attorney, checkboxes) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 20 — refactored to shell) |
| `cosmos-dashboard/app/md/[patientId]/chart-shared.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/ReferralGrid.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitHistoryTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/PatientInfoTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 20 — warning badges, Replace mode, parser fix, toasts) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 20 — warning badges, Replace mode, toasts) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 19 — sidebar nav) |
| `cosmos-dashboard/app/lib/auditLogger.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 17) |
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
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (Session 11) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-ai/ARCHITECTURE.md` | Needs update — shadcn exceptions and Migration 025 |

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
- **CosmosUI `toastSuccess`/`toastError` both route through `AlertModal`** — no separate toast UI; all notifications require acknowledgment
- **New screens must mount `<AlertModal />` and `<ConfirmModal />`**
- **`sessionStorage` reads must be in `useEffect`**
- **Bash history expansion breaks inline `python3 -c` with `!`**
- **Render env var changes trigger automatic redeploy**
- **`~/storage/downloads/` writes can silently fail** — verify with `wc -l` or `ls`
- **Large file refactors: read full source before splitting** — never reconstruct from changelog summaries
- **`shared.tsx` pattern: all cross-section helpers in one file** — eliminates duplicate imports across component splits
- **Sidebar `localStorage` persistence: initialize in `useEffect` to avoid SSR hydration mismatch**
- **Sidebar hover states on plain `<button>` elements require inline handlers** — Tailwind `hover:` purged at build time for dynamically constructed class strings
- **Edit forms in sidebar layout must render at top of section** — bottom-rendered forms scroll out of mobile viewport, appearing as no-ops
- **Patch script `old` anchor must match on-disk state exactly** — always `grep -n` to confirm current string before writing patch
- **Termux heredoc buffer limit ~250 lines** — large heredocs truncate silently; split files >~250 lines into separate heredoc commands
- **Line-number Python insert** (`lines.insert(N, text)`) is reliable when anchor-based patch fails — use `grep -n` to find target line first
- **Submit button persistence after action** — after any Supabase update that changes list membership, always update local state immediately; never rely on `router.refresh()` alone
- **Login perf: merge parallel `practice_settings` reads** — when two functions call the same table sequentially, combine into one query and pass the result as a parameter
- **CosmosUI notification standard (Session 20):** single-record CRUD → `toastSuccess`/`toastError`; bulk operations, destructive completions, errors requiring acknowledgment → `AlertModal`. Rule documented in `AI_STYLE_GUIDE.md §2`
- **NF-2 signature key mismatch** — `nf2.py` read `signature_url`; DB column is `patient_signature_url`. Always verify field keys against DB column names, not assumed naming patterns
- **CPT CSV import parser fallback** — positional column fallback causes silent misreads when column count differs from expected. Always require explicit header match; never fall back to position
- **Supabase CSV export uses `"null"` string** — not Python `None` or empty. Parser must treat literal `"null"` as null/missing value
- **`pceData` must hydrate from existing visit on load** — initialize `useState` from `initialVisits.find(v => v.id === visitIdParam)?.pce_data` when `visitIdParam` present; default `{}` only for new visits
- **PDF filename convention (Session 21)** — all filenames follow `patid_doa_dos_type.pdf` (per-visit) or `patid_doa_type.pdf` (patient-level). Dates are `YYYYMMDD`. Type tokens are lowercase. `REFERRAL_FORM_CONFIG.tag` is the DB value; `fn_type` is the filename token — never conflate them
- **`_fmt_date` fallback is `"00000000"`** — signals a missing date on the patient record, not a code bug. Treat as a data quality issue
- **Zip requires `patient_forms.visit_id`** — always set `visit_id` on insert; rows with `visit_id = null` are silently excluded from billing packet zip
- **Supabase service key not in Termux env** — `SUPABASE_SERVICE_KEY` is only set on Render. Use Supabase dashboard SQL editor for ad-hoc queries
- **Fresh doc uploads required before end-of-session updates** — session-start copies may be stale. Rule now in `SYSTEM_PROMPT.md §13`
- **`send_billing_endpoint.py` register pattern (Session 22)** — when a FastAPI endpoint contains multi-line f-strings or complex string concatenation, extract it to a separate `.py` file and wire via a `register(app, ...)` function. Avoids heredoc string literal truncation/corruption in Termux
- **TurboSMTP SMTP credentials are API key pairs** — Consumer Key = SMTP username, Consumer Secret = SMTP password. Not email/password. `starttls()` required on port 587
- **`lawyers.email` is the attorney email source** — not a field on `patients` directly. `patients.attorney_email` is populated at intake/edit time from the selected lawyer record. Backend reads `patients.attorney_email` — ensure it is saved before testing email send
- **Zip filename convention (Session 22):** `patid_doa_dos_billing_packet.zip` — includes `_billing_packet` suffix for clarity
- **Next.js 15 async params** — server components must use Promise params and `await params`
- **Dynamic route folder naming in Termux** — use Python `os.makedirs` not `mkdir` for bracket folders; git tracks quoted folder names
- **`billing_npi` is the only NPI key used in PDF forms** — `doctor_npi` retained in `database.py` output dict for internal reference only
- **PC NPI field only shown for providers with PC corp** — sole proprietors excluded (`tax_classification === 'individual'`)
- **Re-login hang root cause (Session 24)** — missing `setLoading(false)` on success path in `handleLogin`. All login steps completed but `loading` state never cleared, causing frozen "Signing in…" UI. `setLoading(false)` must be called in every `handlePostLogin` branch before stage transition.
- **`supabase.auth.signOut()` inside `handleLogin` causes hang** — do not await `signOut()` before `signIn()` on the same singleton Supabase client; clear the session token directly via `localStorage.removeItem('sb-<project-ref>-auth-token')` instead
- **Supabase localStorage token key** — `sb-ttudxnzmybcwrtqlbtta-auth-token`. Remove directly before `signIn` to avoid singleton client state race.
- **`cosmos_login_marker` sessionStorage pattern** — set `'1'` after successful login in all `handlePostLogin` branches; `useEffect` on page mount skips session restore if marker is absent; `sessionStorage.clear()` on Sign Out removes it
- **Patch anchor drift** — after multiple iterative patches to the same file, anchors become unreliable. Prefer full clean rewrite from known-good source when more than ~4 patches have accumulated on one file
- **On-screen debug log pattern** — when DevTools are unavailable, add a `debugLog` state array, a `dlog(msg)` helper, and render a monospace cyan panel above the Submit button. Remove completely before final deploy via clean rewrite
- **`autoComplete="new-password"` suppresses browser saved credentials entirely** — use only as a temporary diagnostic measure; restore `"email"` / `"current-password"` for production
