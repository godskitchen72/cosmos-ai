# Cosmos Medical Technologies — HANDOVER (July 6, 2026, Session 20 — final)

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

## Completed This Session (Session 20)

### PatientChart.tsx refactor — complete

`app/md/[patientId]/PatientChart.tsx` split from 1328 lines into 6 files:

- `PatientChart.tsx` — shell only (~120 lines): tab router, header, visits state
- `chart-shared.tsx` — shared types, interfaces, `getAuthToken`, `getTx`, `CustomCombo`, `CodeMultiPicker`, `QuickNotePicker`, style constants
- `components/VisitTab.tsx` — all visit/PCE/CPT/ICD-10/flag/billing logic
- `components/ReferralGrid.tsx` — 9 referral type cards + psych referral
- `components/VisitHistoryTab.tsx` — history list + visit sheet drawer
- `components/PatientInfoTab.tsx` — DOA/insurance/pain scores display

**Implementation notes:**
- `components/` directory created under `app/md/[patientId]/`
- `pceData` now hydrates from `v.pce_data` when `visit_id` is in URL — existing visit data loads correctly on return
- `visitDate` also hydrates from existing visit record
- DEV fill-all PCE test button added to `VisitTab.tsx` — always visible, remove before go-live
- All native `<select>` dropdowns replaced with `QuickNotePicker` (custom styled dropdown in `chart-shared.tsx`)
- Update Status replaced with styled button group (color-coded per status)
- Patient status normalized on init — `'Active Treatment'` maps to `'Active'`

### ReferralGrid cyan completion indicators — complete

`ReferralGrid.tsx` queries `patient_forms` on mount filtered by `visit_id`.
Cards with matching `form_type` highlight cyan with `✓` checkmark. Psych
referral and ICD-10 use separate DB queries (`patient_visits.psych_referral`
and `icd10_codes` presence). Psych state updates optimistically on toggle.

**form_type mapping:** `MRI`, `RX`, `DME`, `PT`, `VNG`, `ANS`, `ORTHO`,
`PAIN-MGMT`. ICD-10 uses `icd10_codes` presence check (no `patient_forms`
record). Psych uses `patient_visits.psych_referral` boolean.

### Admin CPT/ICD-10 data quality warnings — complete

`CptCodesSection.tsx`, `Icd10Section.tsx`: Warning badges added:
- ICD-10: `⚠️ No description` if `description` blank or equals code
- CPT: `⚠️ No fee` if fee is 0/null and `fee_varies = false`
- CPT: `⚠️ No description` if description blank
- Section-level banner shows count of affected codes

### CSV import Replace mode — complete

Both sections now show `＋ Append` / `⟳ Replace All` toggle in import
preview. Replace mode deletes all existing codes before upserting.
Red warning banner shown when Replace selected. Confirm button turns red.

**CPT import parser fix:** `icdKey` and `diagKey` no longer fall back to
positional columns when no `icd10_code` header exists — Supabase backup
exports were misread (fee values treated as ICD-10 codes). Fix: only
auto-import ICD-10 if explicit `icd10_code` column present in CSV headers.

**`null` fee_varies fix:** Supabase exports use literal string `"null"` for
null fees — parser now treats `"null"` as `fee_varies = true`.

### Admin action confirmations — complete

`CptCodesSection.tsx`, `Icd10Section.tsx`: `toastSuccess`/`toastError` added
to all save, delete, and import actions. Import success message includes count
and mode (Imported/Replaced). All error paths covered.

### DashboardClient.tsx CosmosUI migration — complete

`app/dashboard/DashboardClient.tsx`: Two bare `alert()` calls replaced with
`toastError()`. `<AlertModal />` and `<ConfirmModal />` mounted. Previously
FD dashboard had no CosmosUI modals mounted — `cosmosConfirm()` would have
silently fallen back to native `window.confirm()`.

### NF-2 signature injection fix — complete

`cosmos-api/forms/nf2.py`: Signature key fixed from `signature_url` to
`patient_signature_url` — the correct DB column name. Patient signature was
always present in `patient_data` but never injected because the wrong key
was read.

`app/patients/[patientId]/PatientProfile.tsx`: `canGenerateNF2` now requires
`patient_signature_url`. NF-2 generation blocked with `"Missing: Signature"`
message when no patient signature on file.

### ARCHITECTURE.md migration gap — resolved

Migrations 020–023 added to `ARCHITECTURE.md §3`. Note added clarifying
that 001–019 exist as `.sql` files on disk; 020+ were run directly in the
Supabase dashboard SQL editor — no on-disk files exist for these.

### CosmosUI notification standard — documented

`AI_STYLE_GUIDE.md §2` updated with the notification standard:
- Single-record CRUD → `toastSuccess`/`toastError`
- Bulk operations, destructive completions, errors requiring acknowledgment → `AlertModal`
- Note: `toastSuccess` internally routes through `AlertModal` (confirmed in `CosmosUI.tsx` line 21)

---

## Open Items, Priority Order

1. **Sidebar rollout to FD, MD, Biller** — Admin pattern proven. Mechanical
   repetition. Product decision: all three in one session or one at a time.

2. **DEV fill-all PCE button** — remove from `VisitTab.tsx` before go-live.

3. **Signed URL caching** — deferred by explicit product decision.

4. **Doctor mailing address data** — Gottesman and Kramer placeholders.
   Test environment only — not urgent until go-live.

5. **`patients.doctor_id` NOT NULL** — deferred to pre-production.

6. **Vercel Pro upgrade** — eliminates cold starts. Worth doing at go-live.

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
- [x] Admin sidebar nav (Session 19)
- [ ] Sidebar rollout — FD, MD, Biller dashboards
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

**MFA `localStorage` device trust:** Key format:
`cosmos_mfa_trusted_{email_normalized}`. 30-day expiry as Unix timestamp.
Clearing localStorage or new browser forces re-challenge.

**`login_attempts` RLS:** Must include `anon` role — lockout check runs
before user is authenticated.

**Admin sidebar `localStorage`:** Key `cosmos_admin_sidebar_open`. Defaults
to expanded (`true`) on first load if key is absent.

**`ARCHITECTURE.md` migration list gap:** Resolved Session 20 — migrations
020–023 added. Note: 001–019 exist as `.sql` files on disk; 020+ were run
directly in Supabase dashboard SQL editor — no on-disk files.

**Edit form scroll context:** CPT and ICD-10 edit forms must render at top
of section — sidebar layout makes bottom-rendered forms scroll out of mobile
viewport, appearing as if Edit does nothing.

**Login `practice_settings` fetch:** Admin/billing path fetches both
`mfa_required` and `session_timeout_minutes` in one query via
`checkAndHandleMfa`. MD/PA/NP path fetches `session_timeout_minutes`
separately in `handlePostLogin` (no MFA check for those roles).

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 20 — refactored to shell) |
| `cosmos-dashboard/app/md/[patientId]/chart-shared.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/ReferralGrid.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitHistoryTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/PatientInfoTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 20 — warning badges, Replace mode, parser fix, toasts) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 20 — warning badges, Replace mode, toasts) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 20 — alert() replaced, AlertModal/ConfirmModal mounted) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 20 — NF-2 requires signature) |
| `cosmos-api/forms/nf2.py` | ★ Verified-final (Session 20 — patient_signature_url key fix) |
| `cosmos-ai/ARCHITECTURE.md` | ★ Verified-final (Session 20 — migrations 020–023 added) |
| `cosmos-ai/AI_STYLE_GUIDE.md` | ★ Verified-final (Session 20 — CosmosUI notification standard added §2) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 19 — merged practice_settings fetch, parallelized lockout queries) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 19 — sidebar nav) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 18 — unchanged Session 20) |
| `cosmos-dashboard/app/admin/components/OverviewSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/CarriersSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/LawyersSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/UsersSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/AuditLogSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/lib/auditLogger.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 17) |
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
| `cosmos-api/forms/ans.py`, `icd10.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |

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
- **Sidebar `localStorage` persistence: initialize in `useEffect` to avoid SSR hydration mismatch**
- **Sidebar hover states on plain `<button>` elements require inline handlers** — Tailwind `hover:` purged at build time for dynamically constructed class strings
- **Edit forms in sidebar layout must render at top of section** — bottom-rendered forms scroll out of mobile viewport, appearing as no-ops
- **Patch script `old` anchor must match on-disk state exactly** — always `grep -n` to confirm current string before writing patch
- **Termux heredoc buffer limit** — very large heredocs truncate silently; split files >~250 lines into separate heredoc commands
- **Line-number Python insert** (`lines.insert(N, text)`) is reliable when anchor-based patch fails — use `grep -n` to find target line first
- **Submit button persistence after action** — after any Supabase update that changes list membership, always update local state immediately; never rely on `router.refresh()` alone
- **Login perf: merge parallel `practice_settings` reads** — when two functions call the same table sequentially, combine into one query and pass the result as a parameter
- **CosmosUI notification standard (Session 20)**: single-record CRUD → `toastSuccess`/`toastError`; bulk operations, destructive completions, errors requiring acknowledgment → `AlertModal`. Rule documented in `AI_STYLE_GUIDE.md §2`.
- **`toastSuccess` routes through `AlertModal`** — `CosmosUI.tsx` line 21: both `toastSuccess` and `toastError` call `_openAlert`. No separate toast UI for success — all notifications require acknowledgment.
- **NF-2 signature key mismatch** — `nf2.py` read `signature_url`; DB column is `patient_signature_url`. Always verify field keys against DB column names, not assumed naming patterns.
- **CPT CSV import parser fallback** — positional column fallback (`?? headers[N]`) causes silent misreads when column count differs from expected. Always require explicit header match; never fall back to position.
- **Supabase CSV export uses `"null"` string** — not Python `None` or empty. Parser must treat literal `"null"` as null/missing value.
- **`pceData` must hydrate from existing visit on load** — initialize `useState` from `initialVisits.find(v => v.id === visitIdParam)?.pce_data` when `visitIdParam` present; default `{}` only for new visits.
- **`patient_signature_url` required for NF-2** — both frontend block and backend key corrected this session.
- **Supabase region: `us-east-2` (Ohio) / Vercel: `us-east-1` (Virginia)** — ~50ms gap, not a meaningful bottleneck at current scale
