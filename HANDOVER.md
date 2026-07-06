# Cosmos Medical Technologies — HANDOVER (July 5, 2026, Session 19 — final)

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

## Completed This Session (Session 19)

### Admin sidebar nav — complete

`app/admin/page.tsx` updated to replace the horizontal tab strip with a
collapsible left sidebar. All 8 section components and `shared.tsx`
are unchanged — layout change only.

**Design decisions confirmed:**
- Pattern: collapsible toggle (☰ / ✕ button in header)
- Collapsed state: sidebar fully hidden — full content width
- Expanded state: 200px left rail, labels only (no icons, emoji stripped)
- Default: expanded on first load
- Persistence: `localStorage` key `cosmos_admin_sidebar_open`
- Scope this session: Admin only — FD, MD, Biller deferred to a future session

**Implementation notes:**
- `stripEmoji()` helper strips Unicode emoji prefix from `NAV_TABS` labels
  for sidebar display — `NAV_TABS` data itself is unchanged
- Active tab: cyan left border (`2px solid #00cfff`) + cyan text
- Hover state: inline `onMouseEnter`/`onMouseLeave` (Tailwind purge avoidance)
- Sidebar is `sticky top-[52px]` with `height: calc(100vh - 52px)` —
  scrolls independently of content
- Body layout: `flex` row — sidebar + `flex-1 min-w-0` content area
- `admin-tab` custom event listener preserved intact
- Header button order corrected: ← Back before ⇄ Sign Out (was reversed)

### CPT and ICD-10 section fixes — complete

**Edit form visibility** (`CptCodesSection.tsx`, `Icd10Section.tsx`):
Edit form moved from bottom to top of section. `useRef` +
`scrollIntoView({ behavior: 'smooth', block: 'start' })` fires on
`editing` state change. Root cause: sidebar layout introduced an
independent scroll context — bottom-rendered form appeared below
the mobile viewport, making Edit appear to do nothing.

**CPT price layout** (`CptCodesSection.tsx`):
Price moved inline after CPT code badge — `[98940] $68.15` on one row,
description below. Eliminates one row per card.

**Active/Inactive toggle** (both sections):
`<input type="checkbox">` replaced with a styled pill button.
`● Active` (green `#19a866`) / `○ Inactive` (red `#e74c3c`).
Checkbox was visually ambiguous on dark theme.

**ICD-10 download template** (`Icd10Section.tsx`):
`⬇ Download Import Template` link added matching the CPT section pattern.
Template columns: `code, description, category`. Two format example rows
(one Cervical, one Lumbar).

**CPT download template updated** (`CptCodesSection.tsx`):
Hardcoded blob updated from placeholder data to real NY No-Fault codes
with accurate fee schedule amounts and linked ICD-10s.

### FD submit button fix — complete

`PatientProfile.tsx`: After successful billing submission,
`setLocalVisits` now stamps submitted visits with `submitted_to_billing_at`
in local state immediately. `readyVisits` filters them out — button
disappears instantly without waiting for `router.refresh()`. Success
toast added confirming visit count submitted.

### Login performance optimization — complete

`app/page.tsx` — two changes:

**Merged duplicate `practice_settings` fetch:** `checkAndHandleMfa` previously
fetched `mfa_required`, then called `handlePostLogin` which fetched
`session_timeout_minutes` separately — two round-trips to the same table.
Now a single query fetches both columns. `handlePostLogin` accepts an optional
`sessionTimeoutMinutes` parameter; when pre-fetched it skips the DB call.
MD/PA/NP path unchanged — they are not in `MFA_ROLES` and still fetch
`session_timeout_minutes` independently in `handlePostLogin`.

**Parallelized lockout pre-check:** Two sequential `login_attempts` queries
(last success + recent fails) replaced with a single `Promise.all`. Saves
one sequential round-trip on every login attempt.

**Infrastructure analysis completed:** Supabase on `us-east-2` (Ohio),
Vercel Hobby on `us-east-1` (Virginia) — ~50ms cross-region gap, not
a meaningful bottleneck. Render on $7 Starter plan — always-on confirmed.
Remaining latency is Vercel Hobby cold starts on first load after idle
(unavoidable without Vercel Pro upgrade).

---

## Open Items, Priority Order

1. **Sidebar rollout to FD, MD, Biller** — template proven in Admin. Mechanical
   repetition of the same pattern. Product decision: do all three in one session
   or one at a time.

2. **Signed URL caching** — deferred by explicit product decision.

3. **Doctor mailing address data** — Gottesman and Kramer placeholders.
   Required for NF-3/W9 accuracy in production.

4. **`patients.doctor_id` NOT NULL** — deferred to pre-production.

5. **Render "always on"** — confirmed on $7 plan, already resolved.

6. **Vercel Pro upgrade** — eliminates cold starts, adds region control.
   Worth doing at go-live. Not urgent now.

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

**`ARCHITECTURE.md` migration list gap:** Migrations 020–023 are missing
from `ARCHITECTURE.md §3`. Should be added next time that document is updated.

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
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 19 — merged practice_settings fetch, parallelized lockout queries) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (Session 19 — submit button local state fix) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (Session 19 — sidebar nav) |
| `cosmos-dashboard/app/admin/components/CptCodesSection.tsx` | ★ Verified-final (Session 19 — edit top-mount, price inline, toggle pill, template updated) |
| `cosmos-dashboard/app/admin/components/Icd10Section.tsx` | ★ Verified-final (Session 19 — edit top-mount, toggle pill, download template added) |
| `cosmos-dashboard/app/admin/shared.tsx` | ★ Verified-final (Session 18 — unchanged Session 19) |
| `cosmos-dashboard/app/admin/components/OverviewSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/CarriersSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/DoctorsSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/LawyersSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/UsersSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/admin/components/AuditLogSection.tsx` | ★ Verified-final (Session 18) |
| `cosmos-dashboard/app/lib/auditLogger.ts` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/md/[patientId]/icd10/IcdReferral.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/billing/page.tsx` | ★ Verified-final (Session 17) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 17) |
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
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 17) |
| `cosmos-api/forms/ans.py`, `icd10.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

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
- **Supabase region: `us-east-2` (Ohio) / Vercel: `us-east-1` (Virginia)** — ~50ms gap, not a meaningful bottleneck at current scale
