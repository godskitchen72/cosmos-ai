# Cosmos Medical Technologies — HANDOVER (July 6, 2026, Session 21 — continued)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed.
Live app confirmed healthy. Supabase experiencing active incident
(Americas region 500 errors, Jul 6 2026) — dashboard SQL editor
unreliable; REST API queries also affected. No Cosmos code issues.

---

## Completed This Session (Session 21)

### Billing packet ZIP download — complete

📦 zip icon on Recent Visits rows in `PatientProfile.tsx`. Visible only
when visit has a complete billing packet (same four-condition gate as
Submit to Billing). Zip contains all `patient_forms` rows for that
`visit_id` plus `patients.nf2_url` and `patients.aob_url`. Filename:
`{patient_id}_{doa}_{dos}.zip`. JSZip loaded from CDN — no npm dependency.
Future document types included automatically if they store as
`patient_forms` row with `visit_id` set (see `PRODUCT_SPEC.md §12`).

### SYSTEM_PROMPT.md §13 updated

Fresh doc upload rule added: before producing end-of-session doc updates,
always request fresh uploads of all six documents.

---

### PDF filename convention — complete

All generated PDFs now use the structured naming convention defined in
`PRODUCT_SPEC.md §12`. Implemented entirely in `cosmos-api/main.py`.

**Changes:**
- `_fmt_date(raw) -> str` helper added — converts ISO DB date to `YYYYMMDD`
- NF-2: `{patient_id}_{doi}_nf2.pdf`
- AOB: `{patient_id}_{doi}_aob.pdf`
- NF-3: `{patient_id}_{doi}_{visit_date}_nf3.pdf`
- PCE: `{patient_id}_{doi}_{visit_date}_init_rpt.pdf`
- All referrals: `{patient_id}_{doi}_{visit_date}_{fn_type}.pdf`
- `REFERRAL_FORM_CONFIG` updated with `fn_type` key per entry (lowercase
  filename token, separate from `tag` which is the `patient_forms.form_type`
  DB value — kept unchanged to avoid breaking `ReferralGrid.tsx`)
- Existing test data wiped via Dev Tools before convention applied

---

## Open Items, Priority Order

1. **`patient_forms` visit_id backfill** — some legacy rows have
   `visit_id = null`, silently excluding them from the zip. Needs a SQL
   UPDATE to backfill correct `visit_id` on affected rows. Deferred
   pending Supabase incident resolution. Query to run once Supabase
   recovers: `SELECT form_type, visit_id, filename FROM patient_forms WHERE patient_id = 'PT331111'` — then backfill any null `visit_id` rows with the correct visit UUID.

3. **Sidebar rollout to FD, MD, Biller** — Admin pattern proven. Mechanical
   repetition. Product decision: all three in one session or one at a time.

4. **DEV fill-all PCE button** — remove from `VisitTab.tsx` before go-live.

5. **Signed URL caching** — deferred by explicit product decision.

6. **Doctor mailing address data** — Gottesman and Kramer placeholders.
   Test environment only — not urgent until go-live.

7. **`patients.doctor_id` NOT NULL** — deferred to pre-production.

8. **Vercel Pro upgrade** — eliminates cold starts. Worth doing at go-live.

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

**`_fmt_date` fallback:** Returns `"00000000"` when `doi` or `visit_date`
is null/missing. This produces a valid but obviously-wrong filename rather
than crashing. A `"00000000"` in a filename is a signal that the patient
record is missing a date — treat as a data quality issue, not a code bug.

**Login `practice_settings` fetch:** Admin/billing path fetches both
`mfa_required` and `session_timeout_minutes` in one query via
`checkAndHandleMfa`. MD/PA/NP path fetches `session_timeout_minutes`
separately in `handlePostLogin` (no MFA check for those roles).

**`REFERRAL_FORM_CONFIG` dual keys:** `tag` = DB `form_type` value stored
in `patient_forms` (e.g. `"MRI"`, `"PAIN-MGMT"`) — never change these
without also updating `ReferralGrid.tsx` completion checks. `fn_type` =
lowercase filename token (e.g. `"mri"`, `"pm"`) — filename only, no DB
usage.

**Zip `patient_forms` visit_id gap:** legacy `patient_forms` rows generated
before reliable visit linkage may have `visit_id = null`. These are
silently excluded from the billing packet zip. Backfill needed — deferred
pending Supabase incident resolution (Jul 6, 2026). After Supabase
recovers, query `patient_forms` for any rows with `visit_id = null` and
update with correct visit UUID from `patient_visits`.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-api/main.py` | ★ Verified-final (Session 21 — PDF filename convention) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 21 — billing packet zip) |
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
- **PDF filename convention (Session 21)** — all filenames follow `patid_doa_dos_type.pdf` (per-visit) or `patid_doa_type.pdf` (patient-level). Dates are `YYYYMMDD`. Type tokens are lowercase. `REFERRAL_FORM_CONFIG.tag` is the DB value; `fn_type` is the filename token — never conflate them.
- **`_fmt_date` fallback is `"00000000"`** — a filename containing this string signals a missing date on the patient record, not a code bug. Treat as a data quality issue.
- **Zip requires `patient_forms.visit_id`** — zip collects all `patient_forms` rows matching `visit_id`. Any per-visit document type that stores its file outside `patient_forms` (or with `visit_id = null`) is silently excluded from the zip. Always set `visit_id` on insert.
- **JSZip CDN timing** — JSZip is loaded inline on first render via a script tag. On first tap the zip icon shows ⏳ briefly while the library loads. Subsequent taps are instant. This is expected behavior, not a bug.
- **Supabase service key not in Termux env** — `SUPABASE_SERVICE_KEY` is only set on Render. Direct DB queries from Termux require either a local `.env` file or hardcoding the URL/key. Neither is present by default — use the Supabase dashboard SQL editor for ad-hoc queries instead.
- **Fresh doc uploads required before end-of-session updates** — session-start copies may be stale. Always request fresh uploads before producing documentation. Rule now in `SYSTEM_PROMPT.md §13`.
