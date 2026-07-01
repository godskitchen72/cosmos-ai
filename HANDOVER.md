# Cosmos Medical Technologies — HANDOVER (June 30, 2026, session 8)

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

### PC/Personal Address → Mailing Address (migration 014)

Dropped unused `street`, `city`, `state`, `zip`, `pc_street`, `pc_city`,
`pc_state`, `pc_zip` from `doctors` table. Added `mailing_street`,
`mailing_city`, `mailing_state` (DEFAULT `'NY'`), `mailing_zip` — the
single address used for all insurance correspondence (payments, denials,
and remittance). Mailing address is required for all providers regardless
of tax classification. Backend `forms/w9.py` updated to read `mailing_*`
columns directly (dropped the old `pc_street → street` fallback chain).

### Provider Form — General + Credentials tab merge

`General` tab removed. Its fields (First/Last Name, License Type,
Specialty, Supervising Provider, Email, Phone, Fax) merged into
`Credentials` tab. Provider form now has three tabs: **Credentials**,
**Billing**, **Schedule**. Mailing Address added to Billing tab, replacing
the Registered PC Address block. PC Corp Name still conditionally shown
when `tax_classification !== 'individual'`.

### PA and NP license types added

`LICENSE_TYPE_OPTIONS` extended with `NP — Nurse Practitioner` and
`PA — Physician Assistant`. Validation rule: `license_type === 'NP'`
requires a `supervising_provider_id` (NPs must have a supervising MD).
PAs can have their own PC, no supervisor required.

### Provider cards — grouped hierarchy + visual tiers

Doctor cards now grouped: independent/supervising MDs first (full cyan
border `border-[#00cfff]`), supervised providers indented under their
supervisor (dim border `border-[#ffffff18]`, `ml-4`). Cards show:
- Name + license type abbreviation inline (PSY, ACU, POD short labels)
- Specialty, NPI, Corp name (purple), Supervisor (green), Signature status
- No empty line gaps (`gap-[3px]`, `m-0` on all `<p>` elements)

### Dev test-data generator — real doctors/carriers/attorneys

`app/dev/page.tsx` `generate()` now fetches real `doctors`, `insurance_carriers`,
and `lawyers` from Supabase before generating patients. Fallback to
hardcoded fictional data only if a table returns empty rows (with a
visible warning in the results log). Column mapping: carriers use
`carrier_name` + composed address from `street`/`city`/`state`/`zip`;
lawyers use `first_name`/`last_name` + `firm_name` + `phone`.

### Wipe-patients endpoint — now clears appointments

`app/api/wipe-patients/route.ts`: `appointments` table delete added to
the cascade chain before `patients` is deleted. Previous gap caused
stale orphaned appointment rows after a patient data wipe.

### Doctor location assignment Edit button (from session 7, live)

Admin → Providers → Schedule → Location Assignments cards have an **Edit**
button. Edit reuses the existing Add Location form and upsert — no new
backend path. Location dropdown is locked while editing.

Also fixed in same pass: location card hours display changed from 24-hour
to 12-hour with AM/PM (`toLocaleTimeString`).

### Provider card layout fixes (from session 7, live)

- License type `MD` shown inline after name (not as a separate badge)
- PSY / ACU / POD short label abbreviations in card
- Empty-line gaps removed with `gap-[3px]` + `m-0` on all `<p>` elements

---

## Open Items, Priority Order

1. **NF-3 Pay-To: use mailing address** — `forms/nf3.py` currently reads
   `patient_data.get("doctor_address")` / `patient_data.get("doctor_pc_address")`
   — both denormalized free-text fields on `patients`, not the real
   `doctors.mailing_*` columns. NF-3 Pay-To address needs to be wired to
   the new `mailing_*` columns. Also: supervisor PC fallback logic
   (`supervising_provider_id` → supervisor's mailing address) still not
   implemented. Deferred multiple sessions.

2. **NF-3 PC-payee mapping — live PDF verification** — code logic checked
   out in session 8 (`payee_name = doctor_pc_corp_name or provider`), but
   a real generated PDF visual check was never completed. Blocked until
   #1 is implemented (address fields are wrong until then).

3. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.

4. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 6+ sessions, never fixed.

5. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 5 sessions, never removed.

6. **`patient_visits.doctor_id` column** — does not exist. `handleStartVisit`
   was patched to omit it. If doctor linkage on visits is needed, add
   migration first.

7. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
   uppercase convention for the other 7.

8. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend work, never started.

9. **`cpt_codes.provider_type` backend wiring** — column exists, unused.

10. **Regenerate W-9s for existing doctors** — no bulk path. Low urgency.

11. **Desktop sidebar nav** — mockup confirmed target. System is intended
    for desktop use (confirmed session 8). Mobile-first was the original
    priority but desktop layout is the real end goal.

12. **Existing doctor records missing mailing address** — Dr. Gottesman,
    Dr. Orthobot, Dr. Pearlman, Dr. Kramer all predate migration 014 and
    have blank `mailing_*` fields. W-9 generation for these doctors will
    produce PDFs with a blank address until they're edited in Admin →
    Providers → Billing → Mailing Address.

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` installed
version does not export `createServerComponentClient` (TS2724). Server-side
session reads in server components are deferred. The `?doctor_id=` URL param
from the login screen is the reliable doctor-scoping path.

**`patient_visits.doctor_id` missing:** Column does not exist in schema.
`handleStartVisit` omits it. Visit-to-doctor linkage currently relies on
`patients.doctor_id` (one-doctor-per-patient assumption).

**NF-3 address denormalization:** `forms/nf3.py` reads `doctor_address` and
`doctor_pc_address` from `patient_data` (free-text fields on `patients`),
not from the real `doctors.mailing_*` columns. This is a compliance-relevant
gap — the NF-3 Pay-To address may be blank or stale for any patient whose
record predates migration 014. See Open Item #1.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — tab merge, mailing address, PA/NP, grouped cards, card layout fixes) |
| `cosmos-dashboard/app/api/wipe-patients/route.ts` | ★ Verified-final (this session — appointments cascade added) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (this session — real doctors/carriers/attorneys) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (this session — reads mailing_* columns) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (session 7 — shadcn rewrite, superadmin picker) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (session 7 — full CRUD + superadmin guard) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (session 7 — role buttons, free-form time, double-booking guard) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (session 7 — dual-mode save, visitDirty, CPT picker fix) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (session 7 — padPin helper) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/nf3.py` | Obtained-current (this session — read in full, address logic confirmed but NOT using mailing_* yet) |
| `cosmos-api/main.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **When patching a file that has already been partially patched in the
  same session, always re-fetch the live file before writing new anchors.**
  Multiple anchor failures this session were caused by writing patch
  anchors against the original uploaded file rather than the current
  on-disk state after earlier patches had run. Standing rule: whenever
  two or more patch scripts touch the same file in one session, the
  second script must anchor against a fresh `git show HEAD:...` or `cat`
  of the file as it exists after the first script ran.
- **Prefer full-file rebuild over stacking patches on heavily-modified
  files.** `admin/page.tsx` was patched 5+ times this session, causing
  several anchor failures. For files that require 3+ patches in a
  session, the correct approach is to fetch the current file, apply all
  changes at once in Claude's sandbox, and deliver the complete corrected
  file for a single `cp` — which is what eventually worked.
- **`<p>` elements have browser-default margins** — `gap-0` on a flex
  container does not collapse `<p>` spacing. Must use `m-0`/`my-0` on
  the `<p>` elements themselves, or use `leading-tight` + explicit gap
  (e.g. `gap-[3px]`) to achieve visually tight card layouts.
- **License type display vs. stored value** — the displayed label in
  `LICENSE_TYPE_OPTIONS` only affects the dropdown, not what's stored in
  the database or rendered in card views. Cards render `item.license_type`
  directly; short labels (PSY, ACU etc.) must be mapped in the card
  render itself via an inline lookup object.
- **Desktop is the real target** — confirmed in session 8. The system is
  intended for desktop use by front desk staff. Mobile-first was the
  development-environment constraint, not the product direction. Desktop
  layout work (sidebar nav, wider containers, multi-column layouts) should
  be treated as a high-priority product goal, not a future nice-to-have.
- **Termux home path is not `/root`** — re-confirmed this session.
  All patch scripts must use `$HOME`/`~`, never `/root`.
