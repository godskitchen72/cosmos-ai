# Cosmos Medical Technologies — HANDOVER (July 7, 2026, Session 23)

Session-specific status only. Permanent rules live in SYSTEM_PROMPT.md,
technical facts in ARCHITECTURE.md, product/business rules in
PRODUCT_SPEC.md, permanent dev conventions in AI_STYLE_GUIDE.md.
Read all six documents at session start (SYSTEM_PROMPT.md 12).

This handover supersedes all prior HANDOVER.md versions.

---

## Current Status

All cosmos-dashboard and cosmos-api commits confirmed deployed and live.
TurboSMTP account closed (spam detection). SendGrid is the target provider.

---

## Completed This Session (Session 23)

### PC NPI full-stack implementation

Product decision: All billing documents use billing_npi. Individual NPI
never appears on documents except sole proprietors. Supervised providers
use supervisor pc_npi.

Migration 025: ALTER TABLE doctors ADD COLUMN IF NOT EXISTS pc_npi text
Run in Supabase SQL editor. No on-disk file.

cosmos-api/database.py complete rewrite:
- _resolve_billing_npi(d, sup): supervised uses supervisor pc_npi;
  PC corp uses own pc_npi; sole proprietor uses own npi
- billing_npi exported in all doctor field dicts
- doctor_npi retained for internal reference only

cosmos-api/forms patched (11 files):
nf2.py nf3.py pt.py vng.py pce.py mri.py ortho.py rx.py dme.py ans.py
icd10.py pain_mgmt.py
All patient_data.get("doctor_npi") replaced with billing_npi.
nf3.py internal resolver block removed (moved to database.py).

DoctorsSection.tsx:
- pc_npi field in Billing tab after PC Corp Name
- Hidden for sole proprietors (tax_classification === individual)
- 10-digit numeric input with counter
- Card display: PC corp MD shows PC NPI, sole prop shows NPI, supervised shows Lic

shared.tsx: pc_npi added to BLANK_DOCTOR

### Dev generator attorney_email fix

app/dev/page.tsx: lawyers select includes email; patient insert includes
attorney_email from atty.email.

### MD V2 dashboard

New route /md-v2/[patientId] — parallel shadcn MD patient chart.
V2 is now the primary MD patient chart.
/md/[patientId] remains the clinical visit entry point via Start Visit.

New files:
- app/md-v2/[patientId]/page.tsx
- app/md-v2/[patientId]/PatientChartV2.tsx (tabs: Pat Profile / History / New Visit)
- app/md-v2/[patientId]/InfoTabV2.tsx
- app/md-v2/[patientId]/HistoryTabV2.tsx
- app/md-v2/page.tsx (redirect to /md)

Pat Profile tab: one-line cyan header (PTID DOB DOA Carrier) plus
claim/pol line; collapsible Attorney card; pain scores grid; visit summary.
Claim Information card removed. Insurance Carrier and Policy Holder removed.

History tab: shadcn Card per visit, cyan left border on most recent,
CPT/ICD-10 badges, bottom drawer with PCE generation.
ICD-10 filter validates codes against icd10Codes table.

New Visit tab: Start Visit button navigates to /md/{patientId}.

MDClient.tsx full shadcn rewrite: patient cards route to /md-v2/;
V2 badge removed; colored left accent border per treatment status.

### Login page improvements

app/page.tsx:
- Dashboard role selector: shadcn Card per role with description line
- Location picker: cyan doctor name and locations, Oxanium font
- autoComplete off on email and PIN fields
- sessionStorage.clear() on all Sign Out buttons all roles
- Pre-login signOut removed from handleLogin (caused hang)

DashboardClient.tsx MDClient.tsx BillerDashboard.tsx:
sessionStorage.clear() added to Sign Out handlers.

OPEN BUG: Re-login hang when switching users not fully resolved.
autoComplete off deployed. If hang persists: add step-debug logging
to handleLogin to identify which await is blocking.

### TurboSMTP account closure

Account closed by TurboSMTP (spam detection on test sends).
/send-billing-packet broken until SendGrid configured.
/generate-zip and PDF generation unaffected.

---

## Open Items Priority Order

1. Re-login hang when switching users. Test after autoComplete off deploy.
   If still hanging add step-debug logging inside handleLogin.

2. SendGrid setup. TurboSMTP closed. Set up SendGrid, domain auth SPF/DKIM,
   HIPAA BAA, swap Render env vars, update send_billing_endpoint.py.

3. patient_forms visit_id backfill. Query:
   SELECT form_type, visit_id, filename FROM patient_forms
   WHERE patient_id = 'PT331111'

4. CPT codes provider_type product decision needed. All 34 codes are MD only.
   Non-MD providers see empty CPT picker. Add General type or separate sets.

5. DEV fill-all PCE button. Remove from VisitTab.tsx before go-live.

6. Patch script cleanup:
   rm ~/fix_*.py ~/patch_*.py ~/rewrite_*.py 2>/dev/null

7. ARCHITECTURE.md updates: add MD V2/MDClient/login to shadcn exceptions;
   add Migration 025 to migration list.

8. Sidebar rollout to FD MD Biller. Deferred.

9. Doctor mailing address data. Gottesman and Kramer placeholders. Test only.

10. patients.doctor_id NOT NULL. Deferred to pre-production.

11. Vercel Pro upgrade. Eliminates cold starts. Do at go-live.

---

## Enterprise Hardening Checklist

Stage 1 Data Integrity COMPLETE
Stage 2 Security COMPLETE except HIPAA BAA with Supabase

Stage 3 Infrastructure:
- Staging environment
- GitHub Actions CI
- Database indexes on FK columns
- Supabase PITR confirmed enabled
- Error monitoring

Stage 4 Code Quality:
- Admin page refactor DONE Session 18
- Replace print() in cosmos-api with structured logging
- Eliminate any types TypeScript strict mode
- React error boundaries
- Loading states on all data fetches

Stage 5 Product UX:
- Admin sidebar DONE Session 19
- MD V2 shadcn chart DONE Session 23
- MDClient shadcn list DONE Session 23
- Login shadcn DONE Session 23
- Sidebar rollout FD MD Biller pending
- Holistic UX audit
- Accessibility
- Multi-tenancy

Stage 6 Compliance:
- HIPAA compliance review
- BAA with Supabase Render Vercel email provider
- Data retention and deletion policy
- Patient data export

---

## Known Architecture Gaps

MD V2 as primary route: /md-v2/[patientId] is the primary MD chart.
/md/[patientId] is the clinical visit entry point.
/md patient list routes to /md-v2/ for all patient taps.
Biller flag taps route to /md/ with visit_id for flag resolution.

shadcn exception extended Session 23: MD V2 route, MDClient, login page.
ARCHITECTURE.md needs update.

billing_npi is the only NPI used in PDF forms. doctor_npi retained in
database.py output dict for internal reference only. All forms/*.py confirmed.

pc_npi column: Migration 025. No on-disk sql file.

TurboSMTP closed: /send-billing-packet returns SMTP error. /generate-zip fine.

Re-login session race: useEffect calls getSession on mount. If stale session
from previous user present it fires before new login completes. Partial
mitigations in place. Full fix pending.

Auth server-component gap: createServerComponentClient not exported.
doctor_id URL param is the reliable doctor-scoping path.

patient_visits.doctor_id missing: relies on patients.doctor_id.

PA/NP users: user_profiles.doctor_id must point to own doctors row.

PostgREST join shape: FK-joined tables return arrays. Handle both shapes.

patients.doctor_id NOT NULL deferred: 3 test patients have null doctor_id.

cosmos_license_type in sessionStorage: CPT filter depends on this.

Session timeout SSR: useSessionTimeout reads sessionStorage in useEffect.

Superadmin timeout exemption: cosmos_session_timeout_minutes = 0 at login.

ARCHITECTURE.md migration list gap: Migrations 020-024 prior sessions.
Migration 025 pc_npi on doctors added Session 23. All 020+ run in Supabase
dashboard SQL editor no on-disk files.

REFERRAL_FORM_CONFIG dual keys: tag is DB value, fn_type is filename token.

Zip patient_forms visit_id gap: legacy rows with visit_id null silently
excluded. Backfill needed see Open Items 3.

send_billing_endpoint.py register pattern: extracted to separate file,
wired via register() to avoid heredoc corruption.

attorney_email auto-fill: from lawyers.email when FD selects attorney.
Backend returns HTTP 400 if patients.attorney_email is null at send time.

---

## File Confidence Levels

cosmos-api/database.py: Verified-final Session 23 complete rewrite billing_npi pc_npi
cosmos-api/forms/nf2.py: Verified-final Session 23 billing_npi
cosmos-api/forms/nf3.py: Verified-final Session 23 billing_npi internal resolver removed
cosmos-api/forms/pt.py: Verified-final Session 23 billing_npi
cosmos-api/forms/vng.py: Verified-final Session 23 billing_npi
cosmos-api/forms/pce.py: Verified-final Session 23 billing_npi
cosmos-api/forms/mri.py: Verified-final Session 23 billing_npi
cosmos-api/forms/ortho.py: Verified-final Session 23 billing_npi
cosmos-api/forms/rx.py: Verified-final Session 23 billing_npi
cosmos-api/forms/dme.py: Verified-final Session 23 billing_npi
cosmos-api/forms/ans.py: Verified-final Session 23 billing_npi
cosmos-api/forms/icd10.py: Verified-final Session 23 billing_npi
cosmos-api/forms/pain_mgmt.py: Verified-final Session 23 billing_npi
cosmos-dashboard/app/admin/components/DoctorsSection.tsx: Verified-final Session 23 pc_npi
cosmos-dashboard/app/admin/shared.tsx: Verified-final Session 23 pc_npi BLANK_DOCTOR
cosmos-dashboard/app/dev/page.tsx: Verified-final Session 23 attorney_email
cosmos-dashboard/app/md/MDClient.tsx: Verified-final Session 23 shadcn routes to md-v2
cosmos-dashboard/app/md-v2/[patientId]/page.tsx: Verified-final Session 23 new file
cosmos-dashboard/app/md-v2/[patientId]/PatientChartV2.tsx: Verified-final Session 23 new file
cosmos-dashboard/app/md-v2/[patientId]/InfoTabV2.tsx: Verified-final Session 23 new file
cosmos-dashboard/app/md-v2/[patientId]/HistoryTabV2.tsx: Verified-final Session 23 new file
cosmos-dashboard/app/md-v2/page.tsx: Verified-final Session 23 new file
cosmos-dashboard/app/page.tsx: Verified-final Session 23 shadcn cards autocomplete sessionStorage
cosmos-dashboard/app/dashboard/DashboardClient.tsx: Verified-final Session 23 sessionStorage.clear
cosmos-dashboard/app/billing/BillerDashboard.tsx: Verified-final Session 23 sessionStorage.clear
cosmos-api/main.py: Verified-final Session 22
cosmos-api/send_billing_endpoint.py: Verified-final Session 22
cosmos-dashboard/app/components/PatientForm.tsx: Verified-final Session 22
cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx: Verified-final Session 22
cosmos-dashboard/app/md/[patientId]/PatientChart.tsx: Verified-final Session 20
cosmos-dashboard/app/md/[patientId]/chart-shared.tsx: Verified-final Session 20
cosmos-dashboard/app/md/[patientId]/components/VisitTab.tsx: Verified-final Session 20
cosmos-dashboard/app/md/[patientId]/components/ReferralGrid.tsx: Verified-final Session 20
cosmos-dashboard/app/md/[patientId]/components/VisitHistoryTab.tsx: Verified-final Session 20
cosmos-dashboard/app/md/[patientId]/components/PatientInfoTab.tsx: Verified-final Session 20
cosmos-dashboard/app/admin/components/CptCodesSection.tsx: Verified-final Session 20
cosmos-dashboard/app/admin/components/Icd10Section.tsx: Verified-final Session 20
cosmos-dashboard/app/admin/page.tsx: Verified-final Session 19
cosmos-dashboard/app/lib/auditLogger.ts: Verified-final Session 17
cosmos-dashboard/app/billing/page.tsx: Verified-final Session 17
cosmos-dashboard/app/components/ui/CosmosUI.tsx: Verified-final Session 13
cosmos-dashboard/app/hooks/useSessionTimeout.ts: Verified-final Session 13
cosmos-dashboard/lib/supabase.ts: Verified-final Session 7
cosmos-dashboard/middleware.ts: Verified-final prior session
cosmos-ai/ARCHITECTURE.md: Needs update shadcn exceptions and migration 025

---

## Lessons Learned

- heredoc cat > file is the reliable full-file write method
- Chrome silently saves re-downloads as filename-1.ext always ls -lt before cp
- Tailwind purge eliminates dynamic classes use inline style as fallback
- login_attempts RLS must include anon role
- Audit log DB triggers show System use frontend writeAuditLog for user events
- TanStack Table data must be memoized
- /tmp does not persist in Termux use ~/
- pathlib.Path.home() returns /root use os.path.expanduser
- database.py prefixes all doctor fields eg license_number to doctor_license_number
- W9 is a billing entity document not a provider document
- AOB assigns benefits to billing entity never treating provider
- NF-3 Section 16 LICENSE field is not NPI
- patients primary key is patient_id text format PT457696
- sessionStorage reads must be in useEffect
- Bash history expansion breaks inline python3 -c with exclamation mark
- Render env var changes trigger automatic redeploy
- storage/downloads writes can silently fail verify with wc -l or ls
- Large file refactors read full source before splitting
- Patch script old anchor must match on-disk state exactly
- Termux heredoc buffer limit about 250 lines split large files
- CosmosUI notification standard: single-record CRUD uses toastSuccess/toastError
  bulk destructive uses AlertModal
- PDF filename convention patid_doa_dos_type.pdf tag is DB value fn_type is filename token
- _fmt_date fallback is 00000000 signals missing date not a code bug
- Zip requires patient_forms.visit_id always set on insert
- Supabase service key not in Termux env use Supabase dashboard SQL editor
- Fresh doc uploads required before end-of-session updates
- send_billing_endpoint.py register pattern extract to separate file wire via register()
- TurboSMTP SMTP credentials are API key pairs Consumer Key is SMTP user
- lawyers.email is the attorney email source patients.attorney_email populated at intake
- Next.js 15 async params server components must use Promise params and await params
- Dynamic route folder naming in Termux use Python os.makedirs not mkdir for bracket folders
- Git tracks quoted folder names use Python os.makedirs to create correctly
- supabase.auth.signOut inside handleLogin causes hang remove it
- Browser autofill persists across sign-out autoComplete off on login fields required
- sessionStorage.clear on sign-out must be on every Sign Out button all roles
- billing_npi is the only NPI key used in PDF forms
- PC NPI field only shown for providers with PC corp sole proprietors excluded
