# Cosmos Medical Technologies — HANDOVER (July 8, 2026, Session 27)

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
Referral Management Module Phase 1 + 2 + partial Phase 3 complete and live.
Migration 026 confirmed deployed (9 tables, 13 rows in `referral_types` —
RX and DME seeded this session). TurboSMTP replaced with Resend. Domain
`cosmosmt.com` verified. `patient_forms` RLS now enabled.

---

## Completed This Session (Session 27)

### Email Provider — TurboSMTP replaced with Resend

`cosmos-api/send_billing_endpoint.py` fully rewritten. SMTP block removed.
Now uses Resend REST API (`https://api.resend.com/emails`). Sends from
`admin@cosmosmt.com`. All ZIP logic, patient/visit fetching, and email body
unchanged. `RESEND_API_KEY` set in Render env. Commit `72fc7d7` — Render
auto-deployed.

DNS records added to `cosmosmt.com` in Porkbun (DNS powered by Cloudflare):
- TXT `resend._domainkey` — DKIM public key
- MX `send` → `feedback-smtp.us-east-1.amazonses.com` priority 10
- TXT `send` → `v=spf1 include:amazonses.com ~all`

Domain verified in Resend at Jul 08, 8:03 PM. `/send-billing-packet` is
fully operational. Old TurboSMTP env vars remain in Render (harmless).

**Note:** Resend API key created as full-access (`YOUR_RESEND_API_KEY` in
Render). An earlier restricted key was exposed in a Termux screenshot and
rotated immediately.

### `patient_forms` RLS Enabled

Confirmed via `pg_class` query: `rls_enabled = false`, one existing policy
`authenticated full access` (ALL commands, `authenticated` role) — policy
was already correct from Session 12 RLS hardening but RLS was never switched
on. One line resolved it:

```sql
ALTER TABLE patient_forms ENABLE ROW LEVEL SECURITY;
```

`cosmos-api` service key bypasses RLS — PDF generation and `patient_forms`
inserts unaffected. Frontend `authenticated` role covered by existing policy.
No code changes required.

### Referral Dual-Write Bridge — RX and DME

`referral_types` seeded with RX and DME rows:
```sql
INSERT INTO referral_types (code, label, category, is_active, sort_order, legacy_form_tag)
VALUES ('RX', 'Prescription', 'specialist', true, 10, 'RX'),
       ('DME', 'Durable Medical Equipment', 'specialist', true, 11, 'DME');
```

Two referral screens patched via `~/patch_rx_dme_bridge.py` (deleted
post-commit):
- `app/md/[patientId]/rx/RxReferral.tsx` — code `RX`
- `app/md/[patientId]/dme/DmeReferral.tsx` — code `DME`

Identical bridge pattern to PT/Ortho/Pain Mgmt/VNG/ANS (Session 26):
`createLifecycleRecord()` fires fire-and-forget after PDF success. Writes
`referrals` + `referral_status_history` + `referral_timeline` +
`referral_notifications`. `✓ TRACKED` badge in header on success. Failure
console-logged only. Commit `eadfcda` — Vercel ✓ Ready in 52s.

All 9 referral types now have dual-write bridges:
MRI, CT, MRA (via MriReferral modality detection), PT, ORTHO, PAIN-MGMT,
VNG, ANS, RX, DME.

### `ReferralsTabV2.tsx` Import Cleanup

Removed inlined `ReferralStatus` type, `REFERRAL_STATUS_META`,
`URGENCY_META`, local `categoryColor()` function, and local `TERMINAL` set.
Replaced with single import:
```ts
import { ReferralStatus, REFERRAL_STATUS_META, URGENCY_META,
  TERMINAL_STATUSES, categoryColor } from '@/app/referrals/types'
```
`TERMINAL` set now uses `TERMINAL_STATUSES` from shared module.
Patched via `~/patch_referralstabv2.py` (deleted post-commit).
Confirmed working — MD V2 Referrals tab renders correctly post-deploy.
Commit included in `eadfcda` deploy.

---

## Completed Prior Sessions (carried forward)

### Session 26

Referral Management Module Phase 1 route deployment. Five `/referrals` route
files written to repo and deployed. MD dashboard Referrals nav button added.
Dual-write bridge for PT, Ortho, Pain Mgmt, VNG, ANS. CHANGELOG Session 26
entry confirmed present in live `cosmos-ai` repo.

### Session 25

Referral Management Module Phase 1 + 2 designed and partially deployed.
Five `/referrals` route files designed (deployed Session 26 above).
MRI dual-write bridge deployed. `ReferralsTabV2.tsx` + Referrals tab in
`PatientChartV2.tsx` deployed. Migration 026 (9 tables) deployed.
shadcn/ui approved as fifth scoped exception for `/referrals` surface.

### Session 24

Re-login hang fully resolved. `setLoading(false)` on success path.
`cosmos_login_marker` sessionStorage guard. Direct localStorage token removal.

### Session 23

PC NPI full-stack (Migration 025, `_resolve_billing_npi`, all 11 `forms/*.py`).
MD V2 dashboard as primary MD chart. TurboSMTP closed.

---

## Open Items, Priority Order

1. **`patient_forms` visit_id backfill.** Query:
   `SELECT form_type, visit_id, filename FROM patient_forms WHERE patient_id = 'PT331111'`
   — then backfill any null `visit_id` rows with the correct visit UUID.

2. **CPT codes `provider_type` product decision needed.** All 34 codes are
   MD only. Non-MD providers see empty CPT picker. Add `General` type or
   separate sets.

3. **DEV fill-all PCE button** — remove from `VisitTab.tsx` before go-live.

4. **Sidebar rollout to FD, MD, Biller.** Deferred.

5. **Doctor mailing address data.** Gottesman and Kramer placeholders.
   Test only.

6. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

7. **Vercel Pro upgrade.** Eliminates cold starts. Do at go-live.

8. **Referral Module Phase 3 (remaining):**
   - FD scheduling workflow: schedule appointment form inside ReferralSheet
     Appointment tab, confirmation number entry, patient confirmation toggle,
     appointment outcome recording
   - Provider Directory management UI (CRUD for `referral_providers`)
   - Overdue detection (metric card exists; no automated flagging yet)

9. **`/referrals` nav from Admin/FD dashboards.** Only MD dashboard has the
   🔗 Referrals button. Admin and FD have no path to `/referrals` yet.

10. **`userRole` in `page.tsx`.** Currently hardcoded `'md'`. Should resolve
    from session for role-aware Sheet action buttons.

11. **Resend HIPAA BAA.** Resend offers BAA on paid plans. Must be signed
    before go-live with real patient data alongside Supabase, Render, Vercel.

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
- [x] `patient_forms` RLS enabled (Session 27)
- [ ] HIPAA BAA with Supabase, Render, Vercel, Resend — administrative

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
- [x] Referral Module Phase 1 route deployed (Session 26)
- [x] Referral dual-write: PT, Ortho, Pain Mgmt, VNG, ANS (Session 26)
- [x] MD dashboard Referrals nav button (Session 26)
- [x] Referral dual-write: RX, DME (Session 27)
- [x] ReferralsTabV2 import cleanup (Session 27)
- [ ] Referral Module Phase 3 (scheduling, results, notifications, providers)
- [ ] Sidebar rollout — FD, MD, Biller dashboards
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] Data retention and deletion policy
- [ ] Patient data export capability

---

## Known Architecture Gaps

**`/referrals/page.tsx` userRole hardcoded.** `userRole="md"` passed to
`ReferralDashboard`. Role-aware server component pattern not yet implemented
for this surface. Sheet action buttons will show MD-role transitions regardless
of actual logged-in role.

**`/referrals` nav missing from Admin and FD.** Only MD dashboard has the
🔗 Referrals button. Phase 3 item.

**MD V2 as primary route:** `/md-v2/[patientId]` is the primary MD chart.
`/md/[patientId]` is the clinical visit entry point.

**shadcn exception extended Sessions 23 + 25:** MD V2, MDClient, login,
`/referrals`. `ARCHITECTURE.md` updated Session 25.

**`billing_npi` is the only NPI used in PDF forms.** All `forms/*.py` confirmed.

**`pc_npi` column:** Migration 025. No on-disk SQL file.

**Auth server-component gap:** `createServerClient` (not `createServerComponentClient`)
is the correct export from `@supabase/auth-helpers-nextjs` in this project's
package version. Cookie wrapper required: `await cookies()` + `get/set/remove`
object pattern. Confirmed needed in `/referrals/actions.ts` and `page.tsx`
Session 26.

**`patient_visits.doctor_id` missing:** relies on `patients.doctor_id`.

**PA/NP users:** `user_profiles.doctor_id` must point to own `doctors` row.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**`patients.doctor_id` NOT NULL deferred:** 3 test patients have null `doctor_id`.

**`cosmos_license_type` in sessionStorage:** CPT filter depends on this
value being set at login.

**Session timeout SSR:** `useSessionTimeout` reads sessionStorage inside
`useEffect` to avoid SSR crash.

**Superadmin timeout exemption:** Superadmin gets `cosmos_session_timeout_minutes = '0'`
at login. Hook treats `0` as disabled.

**`nf3_preflight_passed` gate:** FD submission requires preflight check.

**`biller_md_flags` fetch condition:** `billing/page.tsx` fetches both
pending and rejected-undismissed flags via PostgREST `.or()`.

**Audit log user attribution:** DB trigger entries show "System".

**MFA `localStorage` device trust:** Key format:
`cosmos_mfa_trusted_{email_normalized}`. 30-day expiry as Unix timestamp.

**`login_attempts` RLS:** Must include `anon` role.

**Admin sidebar `localStorage`:** Key `cosmos_admin_sidebar_open`.

**`ARCHITECTURE.md` migration list gap:** Migrations 020-026 added in prior
sessions. No migrations this session.

**`_fmt_date` fallback:** Returns `"00000000"` when null/missing.

**`REFERRAL_FORM_CONFIG` dual keys:** `tag` = DB value, `fn_type` = filename.

**Zip `patient_forms` visit_id gap:** legacy null rows silently excluded.

**`send_billing_endpoint.py` register pattern:** Extracted to separate file.

**`attorney_email` auto-fill:** Populated from `lawyers.email` at FD intake.

**Login `cosmos_login_marker`:** Set in sessionStorage after successful login.

**Supabase auth token localStorage key:**
`sb-ttudxnzmybcwrtqlbtta-auth-token`.

**Referral dual-write is fire-and-forget** — `createLifecycleRecord()` never
awaited; failure console-logged only; never surfaces to MD or rolls back PDF.

**Referral modality derived from selected keys (MRI only)** — CT: `ct.*`;
MRA: `mri.mra.*`; MRI: all other `mri.*`. PT/Ortho/Pain Mgmt/VNG/ANS/RX/DME
use static type code lookup only.

**`referral_types` codes confirmed** — `.eq('code', ...)` is the correct
lookup. Codes: MRI, CT, MRA, ULTRASOUND, PT, ORTHO, PAIN-MGMT, EMG, VNG,
ANS, RX, DME. All 12 now seeded.

**Vercel preview URL domain isolation** — session cookies are scoped to the
aliased domain (`cosmos-dashboard-nu.vercel.app`). Preview deployment URLs
(`*-godskitchen72s-projects.vercel.app`) have separate cookie scope. Always
test on the aliased domain.

**Resend domain verified** — `cosmosmt.com` sending via `admin@cosmosmt.com`.
Full-access API key stored as `RESEND_API_KEY` in Render env.

**`patient_forms` RLS** — now enabled (Session 27). Existing
`authenticated full access` ALL policy was already present from Session 12
but RLS was never switched on. One `ALTER TABLE` fixed it. No code changes.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/md-v2/[patientId]/ReferralsTabV2.tsx` | ★ Verified-final (Session 27 — import cleanup) |
| `cosmos-dashboard/app/md/[patientId]/rx/RxReferral.tsx` | ★ Verified-final (Session 27 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/dme/DmeReferral.tsx` | ★ Verified-final (Session 27 — dual-write bridge) |
| `cosmos-api/send_billing_endpoint.py` | ★ Verified-final (Session 27 — Resend rewrite) |
| `cosmos-dashboard/app/referrals/types.ts` | ★ Verified-final (Session 26 — new file) |
| `cosmos-dashboard/app/referrals/actions.ts` | ★ Verified-final (Session 26 — new file) |
| `cosmos-dashboard/app/referrals/page.tsx` | ★ Verified-final (Session 26 — new file) |
| `cosmos-dashboard/app/referrals/ReferralDashboard.tsx` | ★ Verified-final (Session 26 — new file) |
| `cosmos-dashboard/app/referrals/ReferralSheet.tsx` | ★ Verified-final (Session 26 — new file) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 26 — Referrals button) |
| `cosmos-dashboard/app/md/[patientId]/pt/PtReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/ortho/OrthoReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/vng/VngReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/ans/AnsReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/mri/MriReferral.tsx` | ★ Verified-final (Session 25 — dual-write bridge) |
| `cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx` | ★ Verified-final (Session 25 — Referrals tab) |
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
| `cosmos-dashboard/app/md-v2/[patientId]/page.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/InfoTabV2.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/[patientId]/HistoryTabV2.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/md-v2/page.tsx` | ★ Verified-final (Session 23 — redirect to `/md`) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 23) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 23) |
| `cosmos-api/main.py` | ★ Verified-final (Session 22) |
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
- **Audit log DB triggers show "System" for user** — no PostgreSQL session context
- **TanStack Table data prop must be memoized** — passing a non-memoized filtered array causes infinite re-renders
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
- **Large file refactors: read full source before splitting**
- **`shared.tsx` pattern: all cross-section helpers in one file**
- **Sidebar `localStorage` persistence: initialize in `useEffect` to avoid SSR hydration mismatch**
- **Sidebar hover states on plain `<button>` elements require inline handlers**
- **Edit forms in sidebar layout must render at top of section**
- **Patch script `old` anchor must match on-disk state exactly** — always `grep -n` to confirm
- **Termux heredoc buffer limit ~250 lines** — large heredocs truncate silently; split files >~250 lines
- **Line-number Python insert** (`lines.insert(N, text)`) is reliable when anchor-based patch fails
- **Submit button persistence after action** — after any Supabase update that changes list membership, update local state immediately
- **Login perf: merge parallel `practice_settings` reads**
- **CosmosUI notification standard (Session 20):** single-record CRUD → toast; bulk/destructive → AlertModal
- **NF-2 signature key mismatch** — always verify field keys against DB column names
- **CPT CSV import parser fallback** — always require explicit header match; never fall back to position
- **Supabase CSV export uses `"null"` string** — not Python `None` or empty
- **`pceData` must hydrate from existing visit on load**
- **PDF filename convention (Session 21)** — `patid_doa_dos_type.pdf`
- **`_fmt_date` fallback is `"00000000"`** — signals missing date, not a code bug
- **Zip requires `patient_forms.visit_id`** — rows with `visit_id = null` silently excluded
- **Supabase service key not in Termux env** — use Supabase dashboard SQL editor for ad-hoc queries
- **Fresh doc uploads required before end-of-session updates**
- **`send_billing_endpoint.py` register pattern (Session 22)**
- **`lawyers.email` is the attorney email source**
- **Zip filename convention (Session 22):** `patid_doa_dos_billing_packet.zip`
- **Next.js 15 async params** — server components must use Promise params and `await params`
- **Dynamic route folder naming in Termux** — use Python `os.makedirs` not `mkdir` for bracket folders
- **`billing_npi` is the only NPI key used in PDF forms**
- **PC NPI field only shown for providers with PC corp**
- **Re-login hang root cause (Session 24)** — missing `setLoading(false)` on success path
- **`supabase.auth.signOut()` inside `handleLogin` causes hang**
- **Supabase localStorage token key** — `sb-ttudxnzmybcwrtqlbtta-auth-token`
- **`cosmos_login_marker` sessionStorage pattern**
- **Patch anchor drift** — after multiple iterative patches to the same file, prefer full clean rewrite
- **On-screen debug log pattern** — `debugLog` state + `dlog()` helper + monospace cyan panel
- **`autoComplete="new-password"` suppresses browser saved credentials entirely**
- **Referral dual-write is fire-and-forget**
- **Referral modality derived from selected keys (MRI only)**
- **Shared types between new module and existing components** — deploy module files together or inline until live
- **Supabase SQL editor RLS prompt** — always choose "Run without RLS" when migration SQL includes explicit ENABLE ROW LEVEL SECURITY
- **Migration 026 run in 3 blocks**
- **`createServerComponentClient` not exported** — use `createServerClient` from `@supabase/auth-helpers-nextjs` with explicit cookie wrapper: `await cookies()` + `{ get, set, remove }` object. `cookies()` returns a Promise in Next.js 15 and must be awaited. `getClient()` must be `async` and called with `await`.
- **Vercel preview URL domain isolation** — session cookies are scoped to the aliased domain (`cosmos-dashboard-nu.vercel.app`). Preview deployment URLs (`*-godskitchen72s-projects.vercel.app`) have separate cookie scope. Always test on the aliased domain.
- **File repeated patch corruption** — after 3+ patches to the same file, restore from `git checkout HEAD -- <file>` before applying further changes. Never patch a corrupted working-tree file.
- **Python `os.path` in Termux** — use `/data/data/com.termux/files/home/` not `/root/` as the home path in Python scripts.
- **`referral_types` codes confirmed** — all 12 now seeded: MRI, CT, MRA, ULTRASOUND, PT, ORTHO, PAIN-MGMT, EMG, VNG, ANS, RX, DME.
- **`patient_forms` RLS gap pattern** — a table can have a correct policy written but RLS never enabled; `pg_class.relrowsecurity = false` is the diagnostic. `ALTER TABLE x ENABLE ROW LEVEL SECURITY` is the one-line fix. Always verify both policy existence AND `relrowsecurity` together.
- **Resend restricted API key** — default Resend key creation is restricted to sending only; use full-access key for domain management API calls. Never paste API keys in screenshots.
- **Porkbun DNS add record** — use Manual tab, not Quick Setup. Host field takes subdomain only (e.g. `resend._domainkey`, not `resend._domainkey.cosmosmt.com`). Porkbun appends `.cosmosmt.com` automatically.
- **Resend domain ID** — get from `GET /domains` API, not from the SDK code snippet shown in dashboard (snippet shows a sample ID).
