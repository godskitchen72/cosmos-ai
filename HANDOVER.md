# Cosmos Medical Technologies — HANDOVER (July 4, 2026, Session 11)

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
close.

---

## Completed This Session

### NF-3 — Patient signature gate (UI + backend)

NF-3 generate is now locked until the patient has a signature on file.

**UI gate** (`PatientProfile.tsx`):
- `canGenerateNF3 = has(patient, 'patient_signature_url')`
- NF-3 card `blocked` state: `!selectedVisit ? 'Select a visit' : !canGenerateNF3 ? 'No signature' : null`
- Tapping a locked card calls `setNf3Msg(blocked)` with 3-second auto-clear
- Message strip renders below the forms grid (outside the 4-column grid, not inside it)
- All NF-3 error handlers converted from `alert()` to inline state

**Backend guard** (`main.py` `/generate/nf3`):
- Returns HTTP 400 `"Patient signature required to generate NF-3"` if `patient_signature_url` missing

### Admin — dropdown contrast fixed globally

All `SelectContent` components in `admin/page.tsx` changed from `bg-card`
(dark-on-dark, unreadable) to `bg-[#1a2235]` with explicit `text-[#e2e8f0]`.
All `SelectItem` elements changed from `text-foreground focus:bg-muted` to
`text-[#e2e8f0] focus:bg-[#00cfff20] focus:text-white`. 12 SelectContent
and 14 SelectItem instances fixed.

### Admin — Save Provider gated on location assignment

`Save Provider` button disabled when `docLocations.length === 0` for
existing providers. Button label changes to `"Assign a location first"`.
Warning prompt appears in the Schedule tab when no locations assigned.

### Admin — New provider two-step flow

New provider flow (`editing === 'new'`) was incorrectly blocked by the
location gate (a `doctor_id` must exist before a `doctor_locations` row
can be created). Fix:
- Save is allowed on first save for new providers
- Button label: `"Save & Continue"` for new providers
- After successful insert, reopens the same provider in edit mode on the
  Schedule tab via `setEditing(id); setDocTab('schedule')`
- "LOCATION ASSIGNMENTS (SAVE PROVIDER FIRST)" hint shown on Schedule tab
  when `editing === 'new'`

### W9 scoped to billing entities only

**Business rule established** (confirmed by product owner):
- W9 applies only to providers who are the billing entity
- Rule: `!supervising_provider_id AND (!!pc_corp_name OR tax_classification === 'individual')`
- Supervised providers (any license type with a supervisor set) → no W9
- NP with own PC and no supervisor → W9 ✅
- NP under supervising MD → no W9 ✅
- MD supervised by another MD (e.g. Orthobot) → no W9 ✅

**`admin/page.tsx`:**
- Auto-W9 on creation gated: `needsW9 = !supervising_provider_id && (!!pc_corp_name || tax_classification === 'individual')`
- W9 View and Regenerate buttons on provider cards hidden when provider
  doesn't meet billing entity criteria

**`main.py` `/generate-w9`:**
- Returns HTTP 400 if provider has `supervising_provider_id` set, or
  lacks both PC corp and sole-proprietor classification

### NF-3 routes supervisor W9 for supervised providers

In `generate_pdf` for `form_type == "nf3"`, after doctor data merge:
- If treating doctor has `supervising_provider_id`, fetches supervisor record
- Injects supervisor's `w9_url` into `patient_data` as the billing entity W9
- Also sets `billing_entity_name` and `billing_tax_id` from supervisor

### W9 cleanup and regeneration

All 7 existing W9 PDFs deleted from `patient-forms` storage bucket via
Supabase Storage API. `w9_url` nulled on all doctor records via SQL.
W9 regenerated for the 3 eligible providers:
- Jim Carrey (MD, Divine Health Practices & Cattle, S-Corp) ✅
- Yury Gottesman (MD, Infinity Health Practices, LLC) ✅
- Don Kramer (MD, Sole Proprietor) ✅

Supervised providers confirmed with no W9: NPian, Orthobot, PAian, Pearlman.

### NF-3 Section 16 — license number (not NPI)

Section 16 "LICENSE OR CERTIFICATION NO." field previously populated with
NPI. Fixed in `forms/nf3.py`:
- `license_number` parameter added to `_p2_vals()` signature
- `treating_provider.1.license_or_certification_number` now uses `license_number`
- NPI fallback removed entirely (license is required; NPI is wrong field)
- Correct key: `patient_data.get("doctor_license_number")` (prefixed by `database.py`)

### License number required in provider validation

`validate()` in `admin/page.tsx` now requires `license_number`:
```
if (!form.license_number) e.license_number = 'Required'
else if (form.license_number.length < 6) e.license_number = 'Minimum 6 characters'
```
Existing providers with blank license numbers will surface this error on
next edit — must be populated before save.

### AOB — always uses billing entity

AOB was showing treating provider (e.g. Brad PAian) as the provider/assignee.
Fixed in `forms/aob.py`:

**Provider name** resolution order:
1. `doctor_pc_corp_name` (supervisor's PC corp when supervised — already
   resolved by `database.py`'s `pc_corp_name` logic)
2. `supervisor_name`
3. `doctor_name` (treating provider — only used for independent providers
   with no PC corp)

**Provider address**: `doctor_mailing_address` — already resolves to
supervisor's mailing address when supervised (set by `database.py`
`sup_mailing` block).

**Provider signature**: `supervisor_signature_url` when present, falls back
to `doctor_signature_url`. For independent providers, these are the same
doctor.

---

## Open Items, Priority Order

1. **RLS full audit** — enterprise hardening Stage 1. Every table, every
   command (SELECT/INSERT/UPDATE/DELETE), both `anon` and `authenticated`.
   FK audit complete; RLS audit is next.

2. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend work, never started.

3. **`cpt_codes.provider_type` backend wiring** — column exists, unused.

4. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

5. **DME provider certification fields blank** — `forms/dme.py` has never
   been obtained or audited.

6. **Doctor mailing address data** — Gottesman, Orthobot, Pearlman, Kramer
   have test/placeholder mailing addresses. Must be updated with real data
   before production use.

7. **Existing providers missing license numbers** — now a required field.
   Existing records (NPian, Orthobot, PAian, Pearlman, Carrey, Gottesman,
   Kramer) should be audited and populated if missing.

8. **NF-3 Section 15 Place of Service** — confirmed working for visits with
   `location_id` set. Visits created before migration 016 (location tracking)
   will have blank place of service — data gap, not a code bug.

---

## Enterprise Hardening Checklist (running)

### Stage 1 — Data Integrity
- [x] FK constraints — all tables audited and complete (Session 10)
- [ ] Full RLS audit — every table, every command, both roles
- [ ] `NOT NULL` constraints on required columns

### Stage 2 — Security
- [ ] API JWT authentication on all `cosmos-api` endpoints
- [ ] Session timeout / auto sign-out after inactivity
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

**NF-3 message state is module-level (`nf3Msg`):** `nf3Msg` useState is
declared at module level (line 69 area) not inside the component — it works
at runtime because React hooks are called consistently, but it's
architecturally incorrect. Low risk for now but should be moved inside
the component on next full PatientProfile.tsx rebuild.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-api/forms/nf3.py` | ★ Verified-final (this session — license_number fix, doctor_license_number key) |
| `cosmos-api/forms/aob.py` | ★ Verified-final (this session — billing entity provider name/address/sig) |
| `cosmos-api/main.py` | ★ Verified-final (this session — NF-3 signature gate, supervisor W9 routing, generate-w9 guard) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — dropdown contrast, location gate, two-step new provider, W9 billing entity logic) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (this session — NF-3 signature gate, inline message strip) |
| `cosmos-api/database.py` | ★ Verified-final (Session 10 — independent provider supervisor fallback fix) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/base.py` | ★ Verified-final (Session 10) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (Session 10) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (Session 9) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (Session 9) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (Session 9) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (Session 8) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (Session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **`/tmp` does not persist in Termux** — patch scripts must always write
  to `~/` (e.g. `~/fix_something.py`), never `/tmp/`. Using `/tmp/` as an
  intermediate path silently loses the file when the session context changes.
- **Bash history expansion breaks `sed -i` with `!`** — any `sed` pattern
  containing `!selectedVisit`, `!res.ok`, etc. will hit bash history
  expansion (`!sel` → last command starting with `sel`) in interactive
  shells. Use Python patch scripts for any anchor containing `!` characters.
- **`pathlib.Path.home()` returns `/root` in this environment** — not the
  actual Termux home at `/data/data/com.termux/files/home`. Use
  `os.path.expanduser('~')` instead, which correctly resolves to the
  Termux home.
- **React fragments (`<>`) inside a CSS grid don't create grid items** —
  the fragment's children become direct grid children, not the fragment
  itself. A message strip inside a `<>` wrapper inside a 4-column grid
  will occupy one of the 4 column slots, pushing subsequent cards to the
  next row. Solution: render the message outside the grid container.
- **`database.py` prefixes all doctor fields** — `license_number` from
  the `doctors` table becomes `doctor_license_number` in `patient_data`
  after the doctor merge. Always check `database.py` `_build_doctor_fields()`
  for the exact key name before referencing a doctor field in any `forms/*.py`.
- **W9 is a billing entity document, not a provider document** — only
  providers who are the pay-to entity (no supervisor, own PC corp or
  sole proprietor) need a W9. Supervised providers bill under their
  supervisor's PC corp; the supervisor's W9 is what gets sent with billing.
- **AOB assigns benefits to the billing entity** — the "Print name of
  Provider" and provider signature on the AOB must be the billing entity
  (PC corp / supervising MD), never the individual treating provider.
  `database.py`'s `doctor_pc_corp_name` and `doctor_mailing_address`
  already resolve to the supervisor's values when supervised — AOB and
  NF-3 should always use these resolved fields, not raw `doctor_name`.
- **NF-3 Section 16 LICENSE field is not NPI** — Section 16 asks for the
  treating provider's state license or certification number. NPI is a
  federal identifier used in the NF-3 billing header (Page 1), not
  Section 16. These are legally distinct.
