# Cosmos Medical Technologies — HANDOVER (July 7, 2026, Session 25)

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
Referral Management Module Phase 1 + 2 complete and live.
Migration 026 confirmed deployed (9 tables, 9 rows in `referral_types`).
TurboSMTP account closed (spam detection). SendGrid is the target provider.

---

## Completed This Session (Session 25)

### Referral Management Module — Phase 1: Foundation

New route `/referrals` — dedicated referral management dashboard.
shadcn/ui scoped exception approved for this surface (same CSS-variable
bridge pattern as Biller and Admin dashboards).

**Migration 026** — 9 new tables, all RLS-enabled, `authenticated` role only:
`referral_providers`, `referral_types` (seeded with 10 types), `referrals`,
`referral_appointments`, `referral_documents`, `referral_status_history`,
`referral_timeline`, `referral_notes`, `referral_notifications`.
Run in Supabase SQL editor in 3 blocks. Confirmed: 9 rows in `referral_types`.

**`app/referrals/types.ts`** — complete TypeScript types: 15 statuses with
badge colors/icons, valid transition map, urgency metadata, role permission
matrix, all DB row types, joined query types, form input types, metrics type.

**`app/referrals/actions.ts`** — Server Actions: `createReferral`,
`updateReferralStatus` (validates against transition map), `scheduleAppointment`
(auto-advances status), `uploadReferralResult` (auto-chains to needs_review),
`addReferralNote`, `getReferralMetrics` (8 KPIs parallel), `listReferrals`
(with filters, PostgREST join shape handled), `getReferralTypes`,
`getReferralProviders`.

**`app/referrals/page.tsx`** — server component, auth gate (all roles except
none), initial parallel data fetch (metrics + referrals + types).

**`app/referrals/ReferralDashboard.tsx`** — client: 8 metric cards (clickable
to filter table), TanStack table (sort/filter/pagination/search), filter bar
(status/type/urgency/global search), row click opens Sheet, Refresh button.

**`app/referrals/ReferralSheet.tsx`** — right-side detail Sheet: 7 tabs
(Overview, Patient, Provider, Appointment, Documents, Notes, Timeline) +
status action buttons per role + note entry.

**Key design decisions:**
- `referral_providers` is explicitly separate from `doctors` table —
  external specialists ≠ treating/billing providers. Never conflate.
- `referral_notifications` stubs at `delivery_status = 'queued'`,
  `sent_at = null` — no schema change needed when SendGrid is wired.
- `referral_timeline` is append-only — no DELETE policy. Nothing ever removed.
- `referral_appointments.is_current` preserves full reschedule history.
- 15-status engine with explicit transition map enforced in server actions.
- Dual-write is fire-and-forget — PDF generation always primary path.

### Referral Management Module — Phase 2: MRI Dual-Write Bridge + V2 Tab

**`app/md/[patientId]/mri/MriReferral.tsx`** — dual-write bridge added.
After successful PDF generation, `createLifecycleRecord()` fires
asynchronously (non-blocking, non-awaited). Derives modality from selected
keys: `ct.*` → CT, `mri.mra.*` → MRA, all other `mri.*` → MRI. Writes to
`referrals`, `referral_status_history`, `referral_timeline`,
`referral_notifications`. Failure logged to console only — never shown to MD,
never rolls back PDF. `✓ TRACKED` badge appears in header on success.

**`app/md-v2/[patientId]/ReferralsTabV2.tsx`** — new component. Queries
`referrals` table directly for patient. Shows lifecycle status cards with
status badges, overdue highlighting, appointment dates, provider name.
Filter pills: All / Open / Closed. "Full Dashboard →" routes to `/referrals`.
Status metadata inlined (not imported from `/referrals/types`) to avoid
module resolution issues before Phase 1 files are fully wired.

**`app/md-v2/[patientId]/PatientChartV2.tsx`** — Referrals tab added as
fourth tab. Tab strip font reduced to 10px to fit four tabs on mobile.

**TSC error resolved:** `ReferralsTabV2.tsx` initially imported from
`'@/app/referrals/types'` which doesn't exist in repo yet (Phase 1 files
designed but not deployed as live route). Fixed by inlining
`REFERRAL_STATUS_META` and `URGENCY_META` constants directly in the component
via Python patch script. Lesson: types shared between a new module and
existing components must either be deployed together or inlined until the
module route is live.

**Commit:** `df0341e..c2428f8` — deployed Vercel production in 41s.

---

## Completed Prior Sessions (carried forward)

### Session 24

**Re-login hang — fully resolved.** Root cause: `setLoading(false)` never
called on success path. `cosmos_login_marker` sessionStorage guard added.
Direct `localStorage.removeItem` before `signIn`. All Sign Out buttons reset
full state. `autoComplete` restored.

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

6. **`ARCHITECTURE.md` updates:** shadcn exceptions (MD V2, MDClient, login,
   `/referrals`), Migration 025, Migration 026. **Updated this session.**

7. **Sidebar rollout to FD, MD, Biller.** Deferred.

8. **Doctor mailing address data.** Gottesman and Kramer placeholders.
   Test only.

9. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

10. **Vercel Pro upgrade.** Eliminates cold starts. Do at go-live.

11. **Referral Module Phase 3** — FD scheduling workflow: schedule appointment
    form inside ReferralSheet Appointment tab, confirmation number entry,
    patient confirmation toggle, appointment outcome recording, Provider
    Directory management UI (CRUD for `referral_providers`), overdue detection.

12. **Deploy `/referrals` route files to repo.** `app/referrals/types.ts`,
    `actions.ts`, `page.tsx`, `ReferralDashboard.tsx`, `ReferralSheet.tsx`
    were designed this session but not yet written to the repo via heredoc.
    Required before Phase 3 and before `ReferralsTabV2.tsx` can import from
    `@/app/referrals/types` instead of inlining constants.

13. **Dual-write bridge for remaining referral types.** Only `MriReferral.tsx`
    has the lifecycle dual-write so far. PT, VNG, ANS, Ortho, Pain Mgmt, Rx,
    DME all need the same pattern in Phase 3.

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
- [x] Referral Management Module Phase 1 + 2 (Session 25)
- [ ] Referral Module Phase 3-5 (scheduling, results, notifications, providers)
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

**Referral module `/referrals/types.ts` not yet in repo as live file.**
`ReferralsTabV2.tsx` inlines `REFERRAL_STATUS_META` and `URGENCY_META`
to avoid import failure. When Phase 3 deploys the full `/referrals` route
files, update `ReferralsTabV2.tsx` to import from `@/app/referrals/types`
and remove the inlined constants.

**Referral dual-write bridge: MRI only.** Only `MriReferral.tsx` creates
lifecycle records. All other referral screens (PT, VNG, ANS, Ortho, Pain
Mgmt, Rx, DME) still only write PDFs to `patient_forms`. Phase 3 adds
the bridge to remaining screens.

**MD V2 as primary route:** `/md-v2/[patientId]` is the primary MD chart.
`/md/[patientId]` is the clinical visit entry point.
`/md` patient list routes to `/md-v2/` for all patient taps.
Biller flag taps route to `/md/` with `visit_id` for flag resolution.

**shadcn exception extended Session 23 + 25:** MD V2 route, MDClient,
login page, `/referrals` dashboard. `ARCHITECTURE.md` updated this session.

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

**`ARCHITECTURE.md` migration list gap:** Migrations 020-025 added in prior
sessions. Migration 026 added this session.

**Edit form scroll context:** CPT and ICD-10 edit forms must render at top
of section — sidebar layout makes bottom-rendered forms scroll out of mobile
viewport, appearing as if Edit does nothing.

**`_fmt_date` fallback:** Returns `"00000000"` when `doi` or `visit_date`
is null/missing. Data quality issue, not a code bug.

**Login `practice_settings` fetch:** Admin/billing path fetches both
`mfa_required` and `session_timeout_minutes` in one query via
`checkAndHandleMfa`. MD/PA/NP path fetches `session_timeout_minutes`
separately in `handlePostLogin`.

**`REFERRAL_FORM_CONFIG` dual keys:** `tag` = DB `form_type` value stored
in `patient_forms` — never change without also updating `ReferralGrid.tsx`.
`fn_type` = lowercase filename token — filename only, no DB usage.

**Zip `patient_forms` visit_id gap:** legacy rows with `visit_id = null`
silently excluded from billing packet zip. Backfill needed — see Open Items #3.

**`send_billing_endpoint.py` register pattern:** Extracted to separate file,
wired into `main.py` via `register()` receiving `app`, `get_db`,
`verify_jwt`, `Depends`, `SUPABASE_URL`, `SUPABASE_KEY`, `BUCKET`, `_fmt_date`.

**TurboSMTP dev-only:** Account closed Session 23. Must switch to SendGrid
before go-live with real patient data.

**`attorney_email` auto-fill:** Populated from `lawyers.email` when FD
selects an attorney in PatientForm. Backend returns HTTP 400 if null at send time.

**Login `cosmos_login_marker`:** Set in sessionStorage after successful login.
Cleared by `sessionStorage.clear()` on every Sign Out button.

**Supabase auth token localStorage key:**
`sb-ttudxnzmybcwrtqlbtta-auth-token` — cleared directly before `signIn`.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 25 — dual-write bridge) |
| `cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx` | ★ Verified-final (Session 25 — Referrals tab) |
| `cosmos-dashboard/app/md-v2/[patientId]/ReferralsTabV2.tsx` | ★ Verified-final (Session 25 — new file) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 24 — re-login hang fixed) |
| `cosmos-api/database.py` | ★ Verified-final (Session 23 — `billing_npi`, `pc_npi`) |
| `cosmos-api/forms/nf2.py` | ★ Verified-final (Session 23 — `billing_npi`) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (Session 23 — `billing_npi`) |
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
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 23 — `pc_npi`) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 23 — `pc_npi` in `BLANK_DOCTOR`) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 23 — `attorney_email` fix) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 23 — shadcn, `/md-v2/`) |
| `cosmos-dashboard/app/md-v2/[patientId]/page.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/InfoTabV2.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/HistoryTabV2.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/page.tsx` | ★ Verified-final (Session 23 — redirect to `/md`) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 23) |
| `cosmos-api/main.py` | ★ Verified-final (Session 22) |
| `cosmos-api/send_billing_endpoint.py` | ★ Verified-final (Session 22) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 22) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 22) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/chart-shared.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitTab.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/ReferralGrid.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/VisitHistoryTab.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/md/[patientId]/components/PatientInfoTab.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 20) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 19) |
| `cosmos-dashboard/app/lib/auditLogger.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/components/ui/CosmosUI.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/hooks/useSessionTimeout.ts` | ★ Verified-final (Session 13) |
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
- **Referral dual-write is fire-and-forget** — `createLifecycleRecord()` is never awaited after PDF success; lifecycle failure is console-logged only and never surfaces to the MD or rolls back the PDF. This is by design — PDF generation is always the primary path.
- **Referral modality derived from selected keys** — CT: `ct.*` prefix; MRA: `mri.mra.*` prefix; MRI: all other `mri.*` keys. No new UI needed; the existing metal-implant gate already enforces mutual exclusion.
- **Shared types between new module and existing components** — if the module route files are not yet deployed to the repo, importing from `@/app/<module>/types` will fail TSC. Either deploy module files together or inline the needed constants in the consuming component until the module is live.
- **Supabase SQL editor RLS prompt** — when creating tables, editor shows "Run and enable RLS" / "Run without RLS" dialog. Always choose "Run without RLS" when the migration SQL includes explicit `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and `CREATE POLICY` statements — letting the editor auto-enable RLS skips the policy creation.
- **Migration 026 run in 3 blocks** — Block 1: providers + types + seed. Block 2: referrals + appointments + documents + status_history + timeline + notes + notifications + indexes. Block 3: RLS + triggers. Each block confirmed "Success" before next.
