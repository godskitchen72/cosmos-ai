# Cosmos Medical Technologies — HANDOVER (July 3, 2026, Session 10)

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
close. NF-3 full regression passed across all three provider scenarios.

---

## Completed This Session

### `forms/base.py` — removed all `except Exception: pass` (P1 closed)

All silent exception swallowing eliminated from `forms/base.py`. Seven
sessions flagged, fixed this session:
- `requests` import failure: now logs `WARNING: requests not available`
- `fitz` import failure: now logs `WARNING: fitz (PyMuPDF) not available`
- `render_visible_text_in_rect`: now logs error instead of passing silently
- `format_date` inner/outer except: both now log parse errors

### `w9_filler.py` removed (P2 closed)

Legacy 120-line duplicate of `forms/w9.py` deleted from `cosmos-api` root.
Nothing imported it. Six sessions flagged, fixed this session.

### PDF filename casing normalized

`ortho.pdf` → `ORTHO.pdf`, `pain_mgmt.pdf` → `PAIN_MGMT.pdf`. Updated
`forms/ortho.py` line 44 and `forms/pain_mgmt.py` line 42 to match.
All 15 PDF templates now use uppercase filenames consistently.

### Practice Info → NF-3 wiring (P4 closed — won't do)

`practice_settings` feeds Admin Overview only. NF-3 billing is
correctly sourced per-doctor via `doctors` table. No wiring needed.

### Admin — Edit Provider/Carrier header shows name in green

Provider edit form: `Edit Provider: Dr. {first} {last}` with name in green.
Carrier edit form: `Edit Carrier: {carrier_name}` with name in green.

### Admin — backend save errors surfaced inline (all sections)

Previously silent Supabase failures now show a red inline error message
below the Save button on every Admin save handler:
- Carriers, Lawyers, CPT Codes, ICD-10 — `saveError` state
- Practice Info — `practiceError` state
- Office Locations (Overview) — `locOvError` state
- Doctor Location Assignments — `locError` state
- Lawyers `alert()` replaced with inline error for consistency

**Side effect:** Exposed missing RLS policy on `insurance_carriers` —
`authenticated` role had no INSERT/UPDATE/DELETE. Fixed:
```sql
CREATE POLICY "authenticated all insurance_carriers"
ON public.insurance_carriers FOR ALL TO authenticated
USING (true) WITH CHECK (true);
```

### Admin — Insurance Carriers expanded

Three new columns: `claims_department text`, `street2 text`, `claims_email text`.
CSV batch import added (upload → preview → confirm, skips duplicates by name).
Carrier cards: name in cyan, `m-0` on all text, shows new fields when present.
Top 20 NY No-Fault carriers imported.

### MD Dashboard — logged-in doctor name in header

`MDClient.tsx` header: `👤 Dr. Yury Gottesman` (cyan) above `📍 Queens Location`.
Doctor name from `doctorNameMap[doctorId]`. `Dr.` prefix only for MD/DO.

### FD Dashboard — assigned provider on patient cards

Patient cards: `PT336816 · Progressive · Dr. Yury Gottesman (MD)`.
Provider in cyan; `⚠ No provider` in red when null.
PostgREST join `doctors(first_name, last_name, license_type)` in `loadAll`.
Array join handled: `Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.
`Dr.` prefix only for `['MD', 'DO']` license types.

### FK constraint audit — Stage 1 complete

All FK relationships audited. Added:
- `appointments.patient_id → patients` ON DELETE CASCADE
- `patient_visits.patient_id → patients` ON DELETE CASCADE
- `visit_line_items.visit_id → patient_visits` ON DELETE CASCADE
- `visit_line_items.patient_id → patients` ON DELETE CASCADE

All other FKs were already in place.

### NF-3 — Section 16 title fix

`_p2_vals()` was hardcoding `"treating_provider.1.title": "MD"`. Fixed to
use `license_type` parameter passed from `patient_data.get('doctor_license_type')`.
Also fixed duplicate `doctor_license_type` key in `_build_doctor_fields()` return dict.

### `database.py` — independent provider fix

Supervisor fields (`supervisor_npi`, `supervisor_tax_id`, `supervisor_specialty`,
`supervisor_signature_url`, `supervisor_name`) previously defaulted to empty
strings when no `supervising_provider_id` was set — causing blank NF-3 Page 3
bottom row for independent MDs (Gottesman, Jim Carrey, etc.).

Fix: defaults now populated from the doctor's own fields:
```python
supervisor_npi           = str(d.get("npi") or "").strip()
supervisor_tax_id        = str(d.get("tax_id") or "").strip()
supervisor_specialty     = str(d.get("specialty") or "").strip()
supervisor_signature_url = str(d.get("signature_url") or "").strip()
supervisor_name          = full  # own name when no supervisor
```
Supervisor block still overrides these when `supervising_provider_id` is set.

### `patients.signature_url` column removed — migrated to `patient_signature_url`

Legacy `signature_url` column on `patients` table dropped. Data migrated:
```sql
UPDATE patients SET patient_signature_url = signature_url
WHERE signature_url IS NOT NULL
AND (patient_signature_url IS NULL OR patient_signature_url = '');
ALTER TABLE patients DROP COLUMN signature_url;
```
Two patients (PT293006, PT789389) had data only in `signature_url` — migrated.

All consumers updated:
- `forms/nf3.py` — reads `patient_signature_url` (was `signature_url`)
- `PatientProfile.tsx` — UPDATE writes `patient_signature_url`
- `PatientForm.tsx` — insert/update payload uses `patient_signature_url`
- `PatientProfile.tsx` canGenerateAOB and display checks updated

### Dev generator — `doctor_id` assigned to generated patients

`app/dev/page.tsx` previously fetched doctor names but never assigned `doctor_id`
to generated patients — resulting in `doctor_id = null` in the DB.

Fix: generator now fetches `doctor_id` alongside name, picks a random doctor
object, and writes both `doctor_name` and `doctor_id` on patient INSERT.

Existing null-`doctor_id` patients fixed via SQL:
```sql
UPDATE patients SET doctor_id = (
  SELECT doctor_id FROM doctors ORDER BY random() LIMIT 1
) WHERE doctor_id IS NULL;
```

### NP/PA user account — linked doctor fix

Reza NPian's user account had role=PA and `doctor_id` pointing to Gottesman
instead of Reza's own doctor record. Fixed in Admin → Users:
- Role: PA → NP
- Linked Doctor: Gottesman → Reza NPian

The `doctor_id` in `user_profiles` must always point to the user's **own**
provider record, not their supervisor. The supervisor relationship lives in
`doctors.supervising_provider_id`.

### NF-3 full regression — all scenarios passed ✅ (P3 closed)

Three scenarios verified against live generated PDFs:

**Scenario 1 — Independent MD (Gottesman):**
- Page 1 Pay-To: "Infinity Health Practices" + mailing address ✅
- Page 2 Section 16: "Yury Gottesman" · "MD" · NPI 1313131313 ✅
- Page 3 bottom: Gottesman's sig + name + NPI + specialty ✅
- Patient signature: image (not typed name) ✅

**Scenario 2 — Supervised PA (Brad PAian under Gottesman):**
- Page 1 Pay-To: Gottesman's PC corp + mailing address ✅
- Page 2 Section 16: "Brad PAian" · "PA" · PAian's own NPI ✅
- Page 3 bottom: Gottesman's sig + name + NPI (supervisor billing) ✅
- Patient signature: image ✅

**Scenario 3 — Independent MD (Jim Carrey, own PC corp):**
- Page 1 Pay-To: "Divine Therapy & Cattle Inc" + Carrey's mailing address ✅
- Page 2 Section 16: "Jim Carrey" · "MD" · NPI 5566255666 ✅
- Page 3 bottom: Carrey's own sig + name + NPI ✅
- Patient signature: image ✅

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

---

## Enterprise Hardening Checklist (running)

### Stage 1 — Data Integrity
- [x] FK constraints — all tables audited and complete (this session)
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
Confirmed this session when Reza NPian's account had Gottesman's `doctor_id`.

**PostgREST join shape:** FK-joined tables return as arrays even for
many-to-one. Always handle both:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain + live screenshot.

| File | Confidence |
|---|---|
| `cosmos-api/forms/nf3.py` | ★ Verified-final (this session — Section 16 title fix, patient_signature_url) |
| `cosmos-api/database.py` | ★ Verified-final (this session — independent provider supervisor fallback fix, duplicate key removed) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — carrier CSV import, inline errors, green name headers) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (this session — provider on cards, array join fix, license type) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (this session — reverted to select(*)) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (this session — doctor name in header) |
| `cosmos-dashboard/app/patients/[patientId]/PatientProfile.tsx` | ★ Verified-final (this session — patient_signature_url) |
| `cosmos-dashboard/app/components/PatientForm.tsx` | ★ Verified-final (this session — patient_signature_url) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (this session — doctor_id assigned to generated patients) |
| `cosmos-api/forms/base.py` | ★ Verified-final (this session — all except Exception: pass removed) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (this session — ORTHO.pdf/PAIN_MGMT.pdf) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (session 9) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (session 9) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (session 9) |
| `cosmos-api/main.py` | ★ Verified-final (session 9) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (session 8) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (session 7) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **PostgREST FK join returns array, not object** — even for many-to-one.
  Always: `const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.
- **Server-side `select('*')` and client-side join must stay separate** —
  adding a join to the server component's select changes the data shape
  passed as props, breaking client-side filters. Keep server as `select('*')`.
- **`insurance_carriers` was missing `authenticated` RLS policies** — caught
  immediately by the new inline error feedback. Inline errors are now a
  first-class RLS debugging tool.
- **`user_profiles.doctor_id` must be the user's own record** — not their
  supervisor. Calendar, location picker, and schedule all use this FK to
  scope to the logged-in provider's own appointments and locations.
- **`patients.signature_url` was a legacy column** — real data lived in
  `patient_signature_url`. Always audit column names against the DB before
  assuming the field name matches the code. The migration → drop pattern
  (verify → migrate data → drop column → remove fallback) worked cleanly.
- **Independent provider NF-3 bottom row needs own fields** — `database.py`
  supervisor defaults were empty strings, not the doctor's own values.
  For an independent MD who IS the billing entity, the "supervisor" fields
  on the NF-3 should be the doctor's own NPI, signature, and specialty.
