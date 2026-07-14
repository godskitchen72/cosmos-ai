# Cosmos Medical Technologies — PRODUCT SPEC

Product requirements, medical/billing workflows, and standing business
decisions. Stable until a product decision changes it. Does not contain
process rules (`SYSTEM_PROMPT.md`), technical architecture
(`ARCHITECTURE.md`), or current session status (`HANDOVER.md`).

---

## 1. Product Identity

NY State No-Fault and Personal Injury medical practice management SaaS,
built for commercial sale to NY No-Fault medical offices. Core domains:
Patient Intake, Clinical Documentation, CPT/ICD-10 Coding, Referrals, PDF
Automation, Front Desk Operations, Billing Preparation, Compliance
Tracking, AI-Assisted Documentation.

---

## 2. Document Confirmation Model (three tiers)

Every generated document falls into exactly one tier. Don't collapse
tiers for convenience (`SYSTEM_PROMPT.md` §7).

| Tier | Documents | Trigger |
|---|---|---|
| FD-gated, fully manual | NF-2, AOB | Front desk explicitly generates |
| FD role: preflight only | NF-3 | FD runs preflight check; Biller generates PDF from Biller dashboard |
| Automatic | ICD-10 Diagnosis PDF, PCE | Fire on visit save; PCE only when pce_data non-empty |
| MD-discretionary, fully manual | MRI, Rx, DME, ANS, VNG, PT, Ortho, Pain Mgmt (referrals) | MD chooses to generate, per visit |
| Automatic | ICD-10 Diagnosis PDF | Fires on visit save, no tap required |
| Automatic (finalization, not a document) | Billing (`visit_line_items`) | Auto-finalizes on visit save when codes/pairings are valid; manual "Finalize Billing" button remains as a retry/safety net, not removed |

**NF-3 gate (Session 11):** NF-3 cannot be generated until the patient
has a `patient_signature_url` on file. This is enforced at both the UI
level (card shows 🔒 "No signature" with a tappable inline message) and
the backend level (HTTP 400 from `/generate/nf3`).

---

## 3. Referral Workflow

**Visit-scoped**: every referral requires a `visit_id`; regenerating a
referral for a visit deletes and replaces only that visit's prior record
for that document type (not patient-wide).

**Header/administrative fields are never user-entered** on a referral
screen — patient name, DOB, insurance, claim number, ICD-10 codes, and
provider name/license/NPI/signature are always pulled server-side from
the patient/visit/doctor records. Only genuinely clinical content (goals,
modalities, symptoms, findings, test selections) is collected on-screen.

**PT (Physical Therapy)** — its own dedicated referral type. History:
the *old* "DME" template used to secretly contain PT content (goals,
modalities, frequency) under a `ptrf.*` field namespace, conflated with
real DME equipment. That conflation has been fully resolved — DME is now
real durable-medical-equipment content, PT has its own dedicated PDF and
referral screen. Never re-conflate these two.

**VNG (Videonystagmography)** — standing decisions:
- Referral card stays labeled **"VNG"**, not reverted to the form's own
  printed title ("TCD / VNG Referral"), even though the form itself
  supports TCD as a distinct test type.
- **"Both" (TCD + VNG) is not a separate selectable UI option.** The
  underlying field exists and can be set directly if a future caller
  sends it, but the referral screen just lets TCD and VNG be checked
  independently — checking both achieves the same end state without a
  dedicated "Both" control.
- Symptoms checklist: Dizziness, Vertigo, Headaches, Imbalance, Tinnitus,
  Memory Issues, Visual Disturbances, Post-Concussion Symptoms, plus an
  "Other" toggle with free-text description.

**Reserved/placeholder slots — resolved.** FD-facing
`PatientProfile.tsx`'s "Referrals & Orders" grid previously carried two
non-interactive "Reserved"/"Future referral" placeholder slots, a
standing explicit product-owner decision (made after hearing and
overruling the default recommendation against building dead-end UI for
undefined features). Both slots were filled with real Ortho and Pain Mgmt
cards — **no reserved slots remain**. The precedent stands for any future
similar request: a placeholder UI element for a genuinely-planned future
feature is an acceptable, explicit exception to the "never a dead-end
control" rule (`SYSTEM_PROMPT.md` §1, §9), not a default to repeat
without the product owner raising it again.

**Save→View — standing pattern, explicit product decision**, replacing
the prior Generate→View pattern for every MD-discretionary referral type
**except ICD-10** (excluded deliberately — it auto-fires on visit save,
a different mechanism, tier table above). On save, the PDF generates and
is stored but is **not** auto-opened; the MD taps the resulting "View"
state on their own terms. Revisiting an already-saved referral shows
"View" immediately rather than resetting to "Save" (explicit decision,
to prevent an accidental overwrite of a real referral with a blank one —
`ARCHITECTURE.md` §8). A "Regenerate" link remains available as a
deliberate, confirm-gated escape hatch.

---

## 4. Treating Provider vs. Billing/Pay-To Entity

Legally distinct roles on NY No-Fault forms — **never collapse into the
same value**:
- **Treating provider**: the individual MD/PA/NP who actually saw the
  patient. Appears in NF-3 Section 16. Title reflects actual license type
  (MD, PA, NP). License number is their own state-issued license/
  certification number (not NPI). NPI is their own individual NPI (used
  on the billing header, not Section 16).
- **Billing/pay-to entity**: who gets paid — the doctor's Professional
  Corporation (PC) when one is on file, otherwise the individual doctor.
  Uses the PC corp name + mailing address. For supervised providers (PA,
  NP, DC, PT, PSY), the supervising MD's PC corp and mailing address are
  used as the Pay-To entity.

On the NF-3:
- **Page 1 Pay-To box** (`provider.name_address`): PC corp name +
  mailing address. For supervised providers, uses supervisor's PC +
  mailing address.
- **Page 3 assignee** (`assignment.provider_assignee_print_name`): PC
  corp name. Both signature fields use the supervisor/billing MD's
  signature.
- **Page 3 bottom row**: supervisor's name, NPI, specialty, and signature.
- **Page 2 Section 16**: treating provider's name, title (license type),
  and their own **state license/certification number** — never NPI.

On the AOB:
- **Assignee/provider name**: PC corp name → supervisor name → treating
  MD name (priority order). Never the supervised treating provider's name.
- **Provider address**: billing entity's mailing address (resolves to
  supervisor's mailing address for supervised providers).
- **Provider signature**: supervisor's signature for supervised providers;
  treating doctor's own signature for independent providers.

---

## 5. Doctor / PC / Tax Classification Rules

NY No-Fault MDs commonly bill through a Professional Corporation (PC),
distinct from their personal identity. Doctor records support:
- **PC Corp Name** — the corporation name used on all billing documents.
- **License Number** — the doctor's state-issued license or certification
  number. Required field (minimum 6 characters). Used in NF-3 Section 16
  "LICENSE OR CERTIFICATION NO." — not NPI.
- **Mailing Address** (street/city/state/zip) — where insurance companies
  send payments, denials, and correspondence. This is the address used in
  the NF-3 Pay-To block and on the W-9. Required for all independent
  providers; optional for supervised providers (who inherit from their
  supervisor). Added in migration 014 — replaces the prior "Registered PC
  Address" block which has been removed from the schema and UI.
- **Tax Classification**: Individual/Sole Proprietor, C-Corp, S-Corp,
  Partnership, LLC, Trust/Estate, Other — matches the real IRS W-9 Line
  3a checkbox set exactly. Selecting **LLC** requires a second
  classification (C/S/P — an LLC is not itself a federal tax category).
  Selecting **Other** requires a free-text description.
- Default for every doctor: `individual` — nothing changes for an
  existing doctor until explicitly set otherwise.

**Supervised providers (PA, NP, DC, PT, PSY):** When a provider has a
`supervising_provider_id`, the system uses the supervisor's PC corp
name, mailing address, NPI, tax ID, specialty, and signature for all
billing/Pay-To purposes. The supervised provider's own mailing address
and tax classification fields are optional in the Admin form — the
system will use the supervisor's data for NF-3 generation regardless.

**W-9 generation policy — entity-based rule (Session 11):**
W-9 applies only to billing entities: providers with no
`supervising_provider_id` AND either a `pc_corp_name` set or
`tax_classification === 'individual'` (sole proprietor).

- Independent MD with PC corp → W9 ✅
- Independent MD sole proprietor → W9 ✅
- NP with own PC and no supervisor → W9 ✅
- NP under supervising MD → no W9 ❌
- PA/PT/DC/Psych under supervising MD → no W9 ❌
- MD supervised by another MD → no W9 ❌

W-9 routing: when an NF-3 is generated for a supervised provider, the
supervisor's W-9 is used as the billing entity W-9 (injected into the
billing packet). The supervised provider has no W-9 of their own.

W-9 generation is once per eligible doctor, at doctor creation (or on
explicit regeneration). Editing a doctor's PC/tax info later does **not**
retroactively regenerate their W-9 — this is by design, not a bug.
Regenerating requires an explicit manual action per doctor; no bulk-
regenerate path exists.

---

## 6. Billing Workflow

- **Auto-finalize on save**: `finalizeBilling()` runs automatically right
  after a visit saves with valid codes (same trigger pattern as the
  ICD-10 auto-generate). The manual "Finalize Billing for These Codes"
  button remains as a retry/safety net for any visit where auto-finalize
  didn't fire or needs to be redone.
- **Fee estimate** (for a visit with codes but no finalized billing yet —
  e.g. mid-entry, or any historical visit predating auto-finalize):
  display `Est. $XXX`, with a `+` suffix if any selected code has a
  variable/non-summable fee, in a visually distinct muted color so an
  estimate can never be mistaken for a real finalized total. Sourced
  from `cpt_codes.fee`/`fee_varies` — the only fee-schedule source of
  truth in the system.
- **Submit-to-billing**: producer-side signal. A visit is "ready" only
  when **all four** are true: billing finalized, NF-3 generated, PCE
  generated (both per-visit), and AOB on file (patient-level). UI: a
  per-visit "Submit" pill for the currently selected visit when ready,
  plus a separate batch button below the grid that submits all of a
  patient's ready visits in one tap — both forms are intentional, not
  redundant. Recorded as `submitted_to_billing_at`. On the Biller
  dashboard, this column is labeled **"Bill Received"**, not
  "Submitted" — same field, relabeled to avoid ambiguity against the
  separate `$` Received column described below.
- **Billing dashboard (Biller role, `/billing`)** — first built as v1,
  substantially rebuilt since. Reads the `submitted_to_billing_at`
  signal above and displays the queue, oldest first, with CPT codes,
  billed total, by-carrier totals for the current queue, and tappable
  NF-3/AOB/PCE/W9/Denial Docs document badges. Standing product
  decisions:
  - **"Received" is a real, per-visit dollar amount**
    (`patient_visits.received_amount`), directly editable on the
    dashboard.
  - **Outstanding, per carrier, is floored at $0** in the Paid-vs-
    Outstanding chart specifically — an overpaid carrier (negative
    outstanding) renders as fully Paid with no negative segment, rather
    than displaying a negative bar. This is a chart-display-only
    decision; it does not change the real underlying balance shown
    elsewhere.
  - **Denial Status** is the current label for what generation/screens
    may still internally refer to as Payment Status — same field
    (`payment_status`), same values (none/Denied/Paid/IME Cut
    Off/Missing Docs/Fraudulent/Policy Exhausted), label-only rename for
    clarity on the dashboard itself.
  - **Denial Docs support biller-initiated hard delete** (confirm-before-
    delete; removes both the uploaded file and its `patient_forms`
    record) — lets a biller correct a wrongly-uploaded document without
    needing a separate workflow or support ticket.
  - **W9 is matched via `patients.doctor_id`**, not a per-visit doctor
    field — `patient_visits` doesn't reliably record which doctor
    treated a given visit (`ARCHITECTURE.md` §3). Using the patient's
    assigned doctor is correct today (one doctor per patient in
    practice) but is a standing assumption, not a guarantee — revisit if
    the practice ever has multiple treating doctors per patient.
  - **W9 on the Biller dashboard** reflects the billing entity's W9 —
    for patients treated by supervised providers, this should be the
    supervising MD's W9 (per the W9 routing in §5).

---

## 7. NF-2 Compliance Workflow

The legally meaningful event for the 30-day no-fault filing deadline is
**mailing** the NF-2, not generating it. The FD queue/dashboard reflects
this:
- Queue clears on `nf2_mailed_at`, not on the PDF merely existing.
- Mailing confirmation UI: a small pill on the patient profile opens a
  bottom-sheet modal to upload a photo/scan of the certified mail receipt
  and/or enter a manual confirmation/tracking number. An "Undo" exists
  for this action — a misclick on a compliance record must not be
  silently unrecoverable.
- Tapping a patient's name from the NF-2 queue card navigates to their
  profile.

---

## 8. Clinical Documentation Standards

- **ROM (Range of Motion)** is documented via severity-only chips
  (Normal / Mild / Moderate / Severe) — not numeric degree values.
- **CPT/ICD-10 codes**: editable while a visit is open; lock to
  read-only chips immediately after the visit saves. The Diagnosis &
  Coding screen is the sole edit surface for changing codes afterward.
- **PCE (Physical Condition Examination)**: a six-step clinical wizard
  covering all AcroForm fields on the PCE PDF.
- **Full-visit edit capability is explicitly out of scope** until a
  dedicated product conversation happens — today, only CPT/ICD-10 codes
  have any post-save edit path.

---

## 9. Dashboard Requirements (current state)

Both dashboards below have accumulated substantial functionality across
multiple sessions as targeted responses to specific requests. **Neither
has had a dedicated holistic planning pass** — see `HANDOVER.md` Open
Items for the standing priority to do this properly rather than continue
purely incremental additions.

**Front Desk Dashboard** (`DashboardClient.tsx`): operational queues —
Psych Referral card, NF-2 mailing queue (per §7).

**MD Calendar** (`calendar/page.tsx`): weekly/monthly views, 20-minute
slots, doctor-locking via URL param, jump-to-doctor's-next-working-day
when a doctor is selected (only if the current view doesn't already work
for them), a quick-pick row of the doctor's next 3 working days with
live booked-count/fullness coloring.

**Patient Profile** (FD-facing, `PatientProfile.tsx`): NF-2 mailing UI,
submit-to-billing UI, fee estimates, and the "Referrals & Orders" status
grid — 3-column layout, one card per document type showing "View" (links
to the generated PDF) or "Not yet ordered," covering MRI / VNG / Rx /
DME / PT / ANS / ICD-10 / Ortho / Pain Mgmt (9 types; no placeholder
slots remain). NF-3 card gated on patient signature.

**Patient Chart** (MD-facing, `PatientChart.tsx`): the PCE wizard, the
CPT/ICD-10 picker, and the referral-type grid (routes into each
referral's own screen) covering the same 9 document types as above.

**Admin / Provider Management** (`admin/page.tsx`): six-tab system
(Overview / Carriers / Providers / Lawyers / CPT Codes / ICD-10).
Provider form: three-tab (Credentials / Billing / Schedule). Credentials:
name, license type (MD/PA/NP/DC/PT/Acupuncturist/Psychologist/Podiatrist/
Other), specialty, supervising provider, email, phone, fax, NPI, **license #
(required)**, signature. Billing: mailing address (required for independent
providers, optional for supervised), PC corp name, tax classification.
Supervised providers see a read-only "Billing under Supervisor's PC" card.
Schedule: location assignments (at least one required before Save Provider).
New provider two-step flow: save first, then assign location. Users tab:
full CRUD, role assignment, linked doctor for MD/PA/NP. Office Locations:
main office flag (cyan border, sorts first), Edit button, purple border for
non-main locations.

**Biller Dashboard** (`app/billing/BillerDashboard.tsx`): the
submitted-to-billing queue — see §6 for what it does and the standing
decisions behind it. The one screen in the app using shadcn/ui as a
deliberate, scoped exception (`ARCHITECTURE.md` §10) rather than the
hand-rolled inline-style pattern every other dashboard listed here uses.

---

## 10. Known Future Work (product-level, not yet built)

- **MRI Extremity Studies** (Right/Left Shoulder, Elbow, Hip, Knee,
  Ankle) and **MRI insurance fields** (policy number, group number,
  precert number) — backend ready, pure frontend work, not started.
  Whether to include Wrist is an unresolved product decision.
- **The actual Billing department feature** — built incrementally as
  the Biller dashboard (`/billing`, §6, `ARCHITECTURE.md` §10); real
  Received-amount tracking now exists (§6). Remaining gap, not yet
  scoped: a real per-visit doctor link if the practice ever needs more
  than the current one-doctor-per-patient assumption. Open, unscoped
  questions around payment tracking specifically (partial payments,
  carrier remittance matching) remain a future product conversation,
  separate from the basic column's existence.
- **Full-visit edit capability** — explicitly out of scope pending a
  dedicated product conversation.
- **Holistic Front Desk + MD dashboard planning** — see §9.
- **Desktop sidebar nav** — confirmed target. System intended for desktop
  use by front desk and clinical staff. Mobile-first was the development-
  environment constraint, not the product direction. Sidebar, wider
  containers, and multi-column layouts are the intended end state.

---

## 11. Compliance & Data Integrity Rules

- RLS policy completeness is a data-integrity and compliance concern, not
  just a technical one — an incomplete policy set can silently drop
  writes to compliance-relevant columns (e.g. mailing confirmations,
  billing submission timestamps) with no error. Audit before trusting
  any such column (`ARCHITECTURE.md` §3).
- Every referral PDF carries a standard Provider Attestation: the
  provider attests they personally performed or directly supervised the
  documented services, that the documentation is accurate, and that the
  information is true and complete to the best of their professional
  knowledge. This attestation language and the associated signature
  field must be present on every referral/document type.
- W-9 tax classification must reflect the doctor's actual structure for
  IRS purposes (§5) — defaulting to "Individual/Sole Proprietor" for a
  doctor actually billing through a PC is a compliance-relevant error,
  not just a cosmetic one.
- **Place of service on NF-3 Section 15** must reflect where the MD/PA/NP
  actually saw the patient — the logged-in office location at the time
  of the visit. This is captured via `patient_visits.location_id`
  (migration 016), written from `sessionStorage.cosmos_location_id` at
  visit start. A blank place of service is a billing compliance gap.
- **NF-3 Section 16 LICENSE field is not NPI** — it is the treating
  provider's state-issued license or certification number. NPI is a
  federal identifier used in the billing header (Page 1), not Section 16.
  Using NPI in Section 16 is a billing error. License number is now a
  required field in the provider record.
- **AOB must name the billing entity as assignee** — the AOB legally
  assigns the patient's right to payment to the billing entity (PC corp
  or supervising MD's PC), not to the individual treating provider. Using
  a treating provider's name on an AOB when they bill under a supervisor
  is legally incorrect.
- **W-9 in billing packets** — the W-9 accompanying an NF-3 must belong
  to the billing entity (pay-to entity), not the treating provider.
  For supervised providers, this is the supervising MD's W-9. Cosmos
  automatically routes the correct W-9 at NF-3 generation time.

---

## 12. PDF File Naming Convention

All patient-related PDFs use the following structured naming convention.
Established Session 21 — applies to all generations going forward.

**Pattern:**

```
Per-visit documents:   {patient_id}_{doa}_{dos}_{type}.pdf
Patient-level docs:    {patient_id}_{doa}_{type}.pdf
```

- `patient_id` — e.g. `PT457696`
- `doa` — date of accident in `YYYYMMDD` format (sorts lexicographically)
- `dos` — date of service in `YYYYMMDD` format (unique per visit)
- `type` — lowercase document type token (see table below)

**Type token reference:**

| Document | Token | Scope |
|---|---|---|
| NF-2 | `nf2` | patient-level (no DOS) |
| AOB | `aob` | patient-level (no DOS) |
| NF-3 | `nf3` | per-visit |
| PCE (Initial Report) | `init_rpt` | per-visit |
| ICD-10 Diagnosis PDF | `icd` | per-visit |
| MRI | `mri` | per-visit |
| Rx | `rx` | per-visit |
| DME | `dme` | per-visit |
| Sono | `sono` | per-visit |
| ANS | `ans` | per-visit |
| VNG | `vng` | per-visit |
| PT | `pt` | per-visit |
| Ortho | `ortho` | per-visit |
| Pain Mgmt | `pm` | per-visit |

**Example filenames:**

```
PT457696_20260115_nf2.pdf
PT457696_20260115_aob.pdf
PT457696_20260115_20260704_nf3.pdf
PT457696_20260115_20260704_init_rpt.pdf
PT457696_20260115_20260704_icd.pdf
PT457696_20260115_20260704_mri.pdf
PT457696_20260115_20260704_pm.pdf
```

**Implementation:** `cosmos-api/main.py` — `_fmt_date()` helper converts
DB ISO date strings to `YYYYMMDD`. The `fn_type` key in
`REFERRAL_FORM_CONFIG` holds the filename token; `tag` holds the DB
`form_type` value stored in `patient_forms` — these are separate and
must not be conflated (`HANDOVER.md` Known Architecture Gaps).

**Date format rationale:** `YYYYMMDD` was chosen over `MMDDYYYY` because
it sorts lexicographically in chronological order — files for the same
patient naturally sequence by visit date in any filesystem, storage
browser, or directory listing.

**Billing packet ZIP** — the FD dashboard shows a 📦 zip icon on each
Recent Visits row once the visit has a complete billing packet (same
four-condition gate as Submit to Billing: billing finalized + PCE
generated + NF-3 preflight passed + AOB on file). The zip filename
follows `{patient_id}_{doa}_{dos}.zip`.

Zip contents are collected dynamically — all `patient_forms` rows
matching that `visit_id`, plus `patients.nf2_url` and `patients.aob_url`
(patient-level docs included in every visit zip).

**Standing rule for new document types:** any new per-visit document type
must store its generated PDF as a `patient_forms` row with `visit_id`
explicitly set. This is the sole mechanism that makes it automatically
included in the billing packet zip. A document type that stores its file
anywhere else (directly on `patients`, `patient_visits`, or in
`patient_forms` with `visit_id = null`) will be silently excluded from
the zip with no error.
