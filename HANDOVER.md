# Cosmos Medical Technologies — HANDOVER (July 6, 2026, Session 22)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed and
live. Supabase Americas incident (Jul 6 2026) resolved — SQL editor and
REST API restored. No Cosmos code issues.

---

## Completed This Session (Session 22)

### Backend billing packet ZIP — complete

Replaced client-side JSZip with a new `POST /generate-zip` endpoint on
`cosmos-api`. Server fetches all files directly from Supabase Storage
using the service key (no signed URL round-trips), zips in memory using
Python's `zipfile`, returns zip as a binary `Response`.

**Changes:**
- `cosmos-api/main.py`: `/generate-zip` endpoint appended; `ZipRequest`
  model (`patient_id`, `visit_id`)
- `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx`:
  `handleDownloadZip` replaced — now calls backend endpoint; JSZip CDN
  loader block removed; `fmtDateForFilename` helper removed (no longer
  needed client-side)

**Zip filename:** `{patient_id}_{doa}_{dos}_billing_packet.zip`

---

### Email billing packet to attorney — complete

New `POST /send-billing-packet` endpoint on `cosmos-api`. Generates one
ZIP per selected visit and sends a single email to the patient's attorney
via TurboSMTP (SMTP). Confirmed delivered end-to-end.

**New file:**
- `cosmos-api/send_billing_endpoint.py` — endpoint logic extracted to
  separate file (avoids heredoc string literal issues in Termux); wired
  into `main.py` via `register()` pattern

**Changes:**
- `cosmos-api/main.py`: imports and registers `send_billing_endpoint`;
  zip filename fixed to `patid_doa_dos_billing_packet.zip`
- `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx`:
  `selectedVisits` state (`Set<string>`), `sendingEmail` state,
  `toggleVisitSelect` handler, `handleEmailAttorney` handler; checkboxes
  on complete visit rows; "📧 Email X Billing Packet(s) to Attorney"
  button appears when visits selected
- `cosmos-dashboard/app/components/PatientForm.tsx`: `attorney_email`
  field added to Attorney section; `attorney_email` added to form state;
  `handleLawyerChange` now auto-fills `attorney_email` from
  `lawyers.email` when attorney selected; `Lawyer` interface updated
  with `email?` field

**Migration 024:** `ALTER TABLE patients ADD COLUMN IF NOT EXISTS attorney_email text` — run directly in Supabase SQL editor (no on-disk file).

**Render env vars added:**
- `TURBOSMTP_HOST` = `pro.turbo-smtp.com`
- `TURBOSMTP_PORT` = `587`
- `TURBOSMTP_USER` = Consumer Key (TurboSMTP API key pair)
- `TURBOSMTP_PASS` = Consumer Secret
- `TURBOSMTP_FROM` = verified sender email

**Email provider:** TurboSMTP via SMTP (`smtplib` — Python stdlib, no
new dependency). Consumer Key/Secret pair used as SMTP credentials.
Sender domain authentication not yet configured — emails may land in
spam until domain DNS records are added. SendGrid is the target provider
for go-live (HIPAA BAA available); TurboSMTP is development/testing only.

**Data model:** `lawyers.email` is the source of truth for attorney
email. `patients.attorney_email` is the runtime field populated when FD
selects an attorney. Backend reads `patients.attorney_email` at send
time.

**Confirmed working:** TurboSMTP Analytics shows `Delivered` status for
test send to `kompaniaadvokat@gmail.com` at 2026-07-06 21:59:56.

---

## Open Items, Priority Order

1. **`patient_forms` visit_id backfill** — legacy rows with
   `visit_id = null` are silently excluded from the billing packet zip.
   Supabase incident now resolved. Query to run:
   `SELECT form_type, visit_id, filename FROM patient_forms WHERE patient_id = 'PT331111'`
   — then backfill any null `visit_id` rows with the correct visit UUID.

2. **Email provider — switch to SendGrid before go-live** — TurboSMTP is
   dev/testing only. SendGrid required for HIPAA BAA. SendGrid account
   creation was blocked (account flagged); retry or use alternate email.
   Domain authentication (SPF/DKIM DNS records) required for reliable
   inbox delivery regardless of provider.

3. **Sidebar rollout to FD, MD, Biller** — Admin pattern proven.
   Mechanical repetition. Product decision: all three in one session or
   one at a time.

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
- [ ] BAA with Supabase, Render, Vercel, email provider
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

**`ARCHITECTURE.md` migration list gap:** Migrations 020–023 added Session 20.
Migration 024 (`attorney_email` on `patients`) added Session 22. Note:
001–019 exist as `.sql` files on disk; 020+ were run directly in Supabase
dashboard SQL editor — no on-disk files.

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
Items #1.

**`send_billing_endpoint.py` register pattern:** The endpoint is extracted
to a separate file and wired into `main.py` via a `register()` function
that receives `app`, `get_db`, `verify_jwt`, `Depends`, `SUPABASE_URL`,
`SUPABASE_KEY`, `BUCKET`, and `_fmt_date` as arguments. This avoids
heredoc string literal corruption in Termux for files with multi-line
f-strings.

**TurboSMTP dev-only:** Email provider for development. HIPAA BAA not
confirmed available. Must switch to SendGrid (or equivalent BAA-capable
provider) before go-live with real patient data.

**`attorney_email` auto-fill:** Populated from `lawyers.email` when FD
selects an attorney in PatientForm. If attorney record has no email, field
remains blank and FD must enter manually. Backend returns HTTP 400 if
`patients.attorney_email` is null at send time.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-api/main.py` | ★ Verified-final (Session 22 — /generate-zip + /send-billing-packet wired + zip filename fix) |
| `cosmos-api/send_billing_endpoint.py` | ★ Verified-final (Session 22 — new file) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 22 — attorney_email field + auto-fill from lawyers.email) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 22 — backend zip, email attorney, checkboxes) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 20 — refactored to shell) |
| `cosmos-dashboard/app/md/[patientId]/chart-shared.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/ReferralGrid.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitHistoryTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/md/[patientId]/components/PatientInfoTab.tsx` | ★ Verified-final (Session 20 — new file) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 20 — warning badges, Replace mode, parser fix, toasts) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 20 — warning badges, Replace mode, toasts) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 20 — alert() replaced, AlertModal/ConfirmModal mounted) |
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
- **Supabase service key not in Termux env** — `SUPABASE_SERVICE_KEY` is only set on Render. Direct DB queries from Termux require either a local `.env` file or hardcoded URL/key. Neither is present by default — use Supabase dashboard SQL editor for ad-hoc queries.
- **Fresh doc uploads required before end-of-session updates** — session-start copies may be stale. Always request fresh uploads before producing documentation. Rule now in `SYSTEM_PROMPT.md §13`.
- **`send_billing_endpoint.py` register pattern (Session 22)** — when a FastAPI endpoint contains multi-line f-strings or complex string concatenation, extract it to a separate `.py` file and wire via a `register(app, ...)` function. Avoids heredoc string literal truncation/corruption in Termux.
- **TurboSMTP SMTP credentials are API key pairs** — Consumer Key = SMTP username, Consumer Secret = SMTP password. Not email/password. `starttls()` required on port 587.
- **`lawyers.email` is the attorney email source** — not a field on `patients` directly. `patients.attorney_email` is populated at intake/edit time from the selected lawyer record. Backend reads `patients.attorney_email` — ensure it is saved before testing email send.
- **Zip filename convention (Session 22):** `patid_doa_dos_billing_packet.zip` — includes `_billing_packet` suffix for clarity. DOA and DOS both included for uniqueness and consistency with PDF naming.
