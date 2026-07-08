# Cosmos Medical Technologies — HANDOVER (July 8, 2026, Session 26)

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
Migration 026 confirmed deployed (9 tables, 11 rows in `referral_types` after
RX and DME deferred — 9 seeded rows confirmed; PT and ORTHO codes confirmed).
TurboSMTP account closed (spam detection). SendGrid is the target provider.

---

## Completed This Session (Session 26)

### Referral Management Module — Phase 1 Route Deployment

Five `/referrals` route files written to repo and deployed (designed Session 25,
deployed this session via split heredoc method):

**`app/referrals/types.ts`** (293 lines) — exports `ReferralStatus`, `ALL_STATUSES`,
`TERMINAL_STATUSES`, `REFERRAL_STATUS_META` (15 statuses, badge colors/icons),
`VALID_TRANSITIONS` map, `ReferralUrgency`, `URGENCY_META`, `UserRole`,
`ROLE_PERMISSIONS`, `CATEGORY_COLOR`, `categoryColor()`, all DB row interfaces,
`ReferralSummary`, `ReferralDetail`, `ReferralMetrics`, form input types,
`ReferralFilters`.

**`app/referrals/actions.ts`** (314 lines) — Server Actions using `createServerClient`
with cookie wrapper pattern (Next.js 15 async cookies fix applied):
`createReferral`, `updateReferralStatus` (validates VALID_TRANSITIONS),
`scheduleAppointment` (auto-advances to scheduled), `uploadReferralResult`
(auto-chains to needs_review), `addReferralNote`, `getReferralMetrics` (8 KPIs
parallel), `listReferrals` (filters + PostgREST join shape), `getReferralTypes`,
`getReferralProviders`.

**`app/referrals/page.tsx`** — server-side auth removed (middleware handles it);
parallel fetch of metrics + referrals + types + providers; passes to
`ReferralDashboard`. `userRole` hardcoded `'md'` pending role-aware server
component pattern.

**`app/referrals/ReferralDashboard.tsx`** (356 lines) — client component:
8 metric cards (clickable to filter table), TanStack Table (sort/pagination),
filter bar (status/urgency/type/search), row click opens Sheet, Refresh button.
Uses shadcn Card/Table/Badge/Button/Input. Oxanium font. Palette-matched inline
styles per project standard.

**`app/referrals/ReferralSheet.tsx`** (303 lines) — right-side detail Sheet:
5 tabs (Overview, Appointment, Documents, Notes, Timeline), status action
buttons per VALID_TRANSITIONS, note entry with live Supabase fetch.

**TSC errors resolved this session:**
- `createServerComponentClient` → `createServerClient` (not exported by this
  package version)
- Cookie wrapper pattern: `await cookies()` + `get/set/remove` object (Next.js
  15 async cookies)
- `async function getClient()` + `await getClient()` at all call sites

**Deployment:** commit `b97e812..ed56af5` — Vercel ✓ Ready in 38s.

### MD Dashboard — Referrals Nav Button

`app/md/MDClient.tsx` — `🔗 Referrals` button added to header button row
(alongside Schedule and Sign Out). `router.push('/referrals')` — always visible,
not gated on `doctorId`. Commit `ed56af5..` — Vercel ✓ Ready in 38s.

### Referral Dual-Write Bridge — PT, Ortho, Pain Mgmt, VNG, ANS

Five referral screens patched via `~/patch_dualwrite.py` (deleted post-commit):

- `app/md/[patientId]/pt/PtReferral.tsx` — code `PT`
- `app/md/[patientId]/ortho/OrthoReferral.tsx` — code `ORTHO`
- `app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` — code `PAIN-MGMT`
- `app/md/[patientId]/vng/VngReferral.tsx` — code `VNG`
- `app/md/[patientId]/ans/AnsReferral.tsx` — code `ANS`

Each receives identical bridge: `createLifecycleRecord(filename)` fires
fire-and-forget after PDF success. Writes `referrals` + `referral_status_history`
+ `referral_timeline` + `referral_notifications`. `✓ TRACKED` badge in header
on success. Failure console-logged only — never shown to MD, never rolls back PDF.
Same pattern as `MriReferral.tsx` (Session 25).

**Confirmed working:** Pain Management, VNG, Orthopedic, ANS all appear in MD V2
Referrals tab with "New" status and correct category colors after generation.

**RX and DME deferred** — `referral_types` has no `RX` or `DME` code rows.
Seeding deferred by product decision this session.

**Commit:** `ed56af5..` — Vercel ✓ Ready.

### Known Architecture Gap Resolved

`referral_types.code` column confirmed present (Migration 026). Existing
`fetchReferralTypeId(code)` pattern in `MriReferral.tsx` is correct.
All new bridges use the same `.eq('code', ...)` lookup.

---

## Completed Prior Sessions (carried forward)

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

6. **Sidebar rollout to FD, MD, Biller.** Deferred.

7. **Doctor mailing address data.** Gottesman and Kramer placeholders.
   Test only.

8. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

9. **Vercel Pro upgrade.** Eliminates cold starts. Do at go-live.

10. **Referral Module Phase 3 (remaining):**
    - FD scheduling workflow: schedule appointment form inside ReferralSheet
      Appointment tab, confirmation number entry, patient confirmation toggle,
      appointment outcome recording
    - Provider Directory management UI (CRUD for `referral_providers`)
    - Overdue detection (metric card exists; no automated flagging yet)

11. **Dual-write bridge for RX and DME.** Deferred — `referral_types` needs
    `RX` and `DME` rows seeded first. Seed SQL:
    ```sql
    INSERT INTO referral_types (code, label, category, is_active, sort_order, legacy_form_tag)
    VALUES ('RX', 'Prescription', 'specialist', true, 10, 'RX'),
           ('DME', 'Durable Medical Equipment', 'specialist', true, 11, 'DME');
    ```
    Then patch `RxReferral.tsx` and `DmeReferral.tsx` with the same bridge
    pattern used for PT/Ortho/Pain Mgmt/VNG/ANS this session.

12. **`ReferralsTabV2.tsx` import cleanup.** Still inlines `REFERRAL_STATUS_META`
    and `URGENCY_META`. Now that `/referrals/types.ts` is deployed, update to
    import from `@/app/referrals/types` and remove inlined constants.

13. **`/referrals` nav from Admin/FD dashboards.** Only MD dashboard has the
    🔗 Referrals button. Admin and FD have no path to `/referrals` yet.

14. **`userRole` in `page.tsx`.** Currently hardcoded `'md'`. Should resolve
    from session for role-aware Sheet action buttons.

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
- [x] Referral Module Phase 1 route deployed (Session 26)
- [x] Referral dual-write: PT, Ortho, Pain Mgmt, VNG, ANS (Session 26)
- [x] MD dashboard Referrals nav button (Session 26)
- [ ] Referral Module Phase 3 (scheduling, results, notifications, providers)
- [ ] RX + DME dual-write bridge (seed referral_types first)
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

**`ReferralsTabV2.tsx` inlines status constants.** Still inlines
`REFERRAL_STATUS_META` and `URGENCY_META` from Session 25 workaround.
Update to `import from '@/app/referrals/types'` now that Phase 1 is live.

**`/referrals/page.tsx` userRole hardcoded.** `userRole="md"` passed to
`ReferralDashboard`. Role-aware server component pattern not yet implemented
for this surface. Sheet action buttons will show MD-role transitions regardless
of actual logged-in role.

**`/referrals` nav missing from Admin and FD.** Only MD dashboard has the
🔗 Referrals button. Phase 3 item.

**Referral dual-write bridge: MRI + PT + Ortho + Pain Mgmt + VNG + ANS only.**
RX and DME still only write PDFs. Seed `referral_types` then patch.

**MD V2 as primary route:** `/md-v2/[patientId]` is the primary MD chart.
`/md/[patientId]` is the clinical visit entry point.

**shadcn exception extended Sessions 23 + 25:** MD V2, MDClient, login,
`/referrals`. `ARCHITECTURE.md` updated Session 25.

**`billing_npi` is the only NPI used in PDF forms.** All `forms/*.py` confirmed.

**`pc_npi` column:** Migration 025. No on-disk SQL file.

**TurboSMTP closed:** `/send-billing-packet` returns SMTP error. `/generate-zip` fine.

**`patient_forms` RLS disabled:** Supabase security advisor flagged this table
as publicly accessible. Known gap — must be resolved before go-live.

**Auth server-component gap:** `createServerClient` (not `createServerComponentClient`)
is the correct export from `@supabase/auth-helpers-nextjs` in this project's
package version. Cookie wrapper required: `await cookies()` + `get/set/remove`
object pattern. Confirmed needed in `/referrals/actions.ts` and `page.tsx`
this session.

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

**TurboSMTP dev-only:** Account closed Session 23.

**`attorney_email` auto-fill:** Populated from `lawyers.email` at FD intake.

**Login `cosmos_login_marker`:** Set in sessionStorage after successful login.

**Supabase auth token localStorage key:**
`sb-ttudxnzmybcwrtqlbtta-auth-token`.

**Referral dual-write is fire-and-forget** — `createLifecycleRecord()` never
awaited; failure console-logged only; never surfaces to MD or rolls back PDF.

**Referral modality derived from selected keys (MRI only)** — CT: `ct.*`;
MRA: `mri.mra.*`; MRI: all other `mri.*`. PT/Ortho/Pain Mgmt/VNG/ANS use
static type code lookup only.

**`referral_types` code column confirmed** — `.eq('code', ...)` is the correct
lookup. Codes: MRI, CT, MRA, ULTRASOUND, PT, ORTHO, PAIN-MGMT, EMG, VNG, ANS.
RX and DME not yet seeded.

**Vercel preview URL domain isolation** — session cookies are scoped to the
aliased domain (`cosmos-dashboard-nu.vercel.app`). Preview deployment URLs
(`*-godskitchen72s-projects.vercel.app`) have separate cookie scope. Always
test on the aliased domain. The 🔗 Referrals button and "Full Dashboard →" link
both use `router.push` (same-domain navigation) so they work correctly once
the user is logged in on the aliased domain.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live confirmation.

| File | Confidence |
|---|---|
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
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 26 — Referrals button) |
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
| `cosmos-dashboard/app/md/[patientId]/ortho/OrthoReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/vng/VngReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/rx/RxReferral.tsx` | ★ Verified-final (Session 13) |
| `cosmos-dashboard/app/md/[patientId]/pt/PtReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
| `cosmos-dashboard/app/md/[patientId]/ans/AnsReferral.tsx` | ★ Verified-final (Session 26 — dual-write bridge) |
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
- **TurboSMTP SMTP credentials are API key pairs**
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
- **Vercel preview URL domain isolation** — session cookies are scoped per domain. Always test on aliased domain (`cosmos-dashboard-nu.vercel.app`), not preview URLs. `router.push()` navigates within the same domain correctly.
- **File repeated patch corruption** — after 3+ patches to the same file, restore from `git checkout HEAD -- <file>` before applying further changes. Never patch a corrupted working-tree file.
- **Python `os.path` in Termux** — use `/data/data/com.termux/files/home/` not `/root/` as the home path in Python scripts.
- **`referral_types.code` column** — confirmed present in Migration 026 schema. Codes: MRI, CT, MRA, ULTRASOUND, PT, ORTHO, PAIN-MGMT, EMG, VNG, ANS. RX and DME not seeded.
