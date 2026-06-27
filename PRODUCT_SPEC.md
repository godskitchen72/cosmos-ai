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
| FD-gated, fully manual | NF-2, NF-3, AOB | Front desk explicitly generates |
| MD-discretionary, fully manual | MRI, Rx, DME, ANS, VNG, PT (referrals) | MD chooses to generate, per visit |
| Automatic | ICD-10 Diagnosis PDF | Fires on visit save, no tap required |
| Automatic (finalization, not a document) | Billing (`visit_line_items`) | Auto-finalizes on visit save when codes/pairings are valid; manual "Finalize Billing" button remains as a retry/safety net, not removed |

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

**Reserved/placeholder slots** (FD-facing `PatientProfile.tsx`,
"Referrals & Orders" grid): two non-interactive placeholder slots exist
for future, not-yet-defined referral types — labeled "Reserved" /
"Future referral," no click handler, visually dimmer than a real
"Not yet ordered" card. This is a standing **explicit product-owner
decision**, made after hearing and overruling the default recommendation
against building dead-end UI for undefined features. Don't remove these
or add more without the product owner raising it.

---

## 4. Treating Provider vs. Billing/Pay-To Entity

Legally distinct roles on NY No-Fault forms — **never collapse into the
same value**:
- **Treating provider**: the individual MD who actually saw the patient.
- **Billing/pay-to entity**: who gets paid — the doctor's Professional
  Corporation (PC) when one is on file, otherwise the individual doctor.

On the NF-3, the "Pay-To Provider" box reflects the PC entity
name/address when present, falling back to the individual doctor's own
name/address — independent of, and never overwriting, the
treating-provider field.

---

## 5. Doctor / PC / Tax Classification Rules

NY No-Fault MDs commonly bill through a Professional Corporation (PC),
distinct from their personal identity. Doctor records support:
- PC Corp Name, Registered PC Address (street/city/state/zip).
- Tax Classification: Individual/Sole Proprietor, C-Corp, S-Corp,
  Partnership, LLC, Trust/Estate, Other — matches the real IRS W-9 Line
  3a checkbox set exactly. Selecting **LLC** requires a second
  classification (C/S/P — an LLC is not itself a federal tax category).
  Selecting **Other** requires a free-text description.
- Default for every doctor: `individual` — nothing changes for an
  existing doctor until explicitly set otherwise.

**W-9 generation policy**: once per doctor, at doctor creation. Editing
a doctor's PC/tax info later does **not** retroactively regenerate their
W-9 — this is by design, not a bug. Regenerating requires an explicit
manual action per doctor; no bulk-regenerate path exists.

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
    dashboard. (An earlier version of this document described this as a
    placeholder "Not tracked" value with no backing column — that was
    already inaccurate by the time of this revision; corrected against
    the live code. If real-payment-tracking questions remain — partial
    payments, carrier remittance matching, etc. — those are still a
    separate, unscoped product conversation, just not the basic
    existence of the column itself.)
  - **Outstanding, per carrier, is floored at $0** in the Paid-vs-
    Outstanding chart specifically — an overpaid carrier (negative
    outstanding) renders as fully Paid with no negative segment, rather
    than displaying a negative bar. This is a chart-display-only
    decision; it does not change the real underlying balance shown
    elsewhere (e.g. the per-visit Balance column, which still correctly
    shows a negative/green value for an overpaid visit).
  - **Denial Status** is the current label for what generation/screens
    may still internally refer to as Payment Status — same field
    (`payment_status`), same values (none/Denied/Paid/IME Cut
    Off/Missing Docs/Fraudulent/Policy Exhausted), label-only rename for
    clarity on the dashboard itself.
  - **Denial Docs support biller-initiated hard delete** (confirm-before-
    delete; removes both the uploaded file and its `patient_forms`
    record) — lets a biller correct a wrongly-uploaded document without
    needing a separate workflow or support ticket.
  - **W9 is matched via `patients.doctor_id`, not a per-visit doctor
    field** — `patient_visits` doesn't reliably record which doctor
    treated a given visit (`ARCHITECTURE.md` §3). Using the patient's
    assigned doctor is correct today (one doctor per patient in
    practice) but is a standing assumption, not a guarantee — revisit if
    the practice ever has multiple treating doctors per patient.

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
DME / PT / ANS / ICD-10, plus 2 reserved slots (§3).

**Patient Chart** (MD-facing, `PatientChart.tsx`): the PCE wizard, the
CPT/ICD-10 picker, and the referral-type grid (routes into each
referral's own screen) covering the same document types as above minus
the reserved slots.

**Admin / Doctor Management** (`admin/page.tsx`): doctor signature
capture (canvas), PC Corp/Address/Tax Classification (§5), Specialty
(including Psychology), structured address fields, field validation
(NPI, Tax ID, specialty, license, phone/fax).

**Biller Dashboard** (`app/billing/BillerDashboard.tsx`): the
submitted-to-billing queue — see §6 for what it does and the standing
decisions behind it. The one screen in the app using shadcn/ui as a
deliberate, scoped exception (`ARCHITECTURE.md` §8) rather than the
hand-rolled inline-style pattern every other dashboard listed here uses.

---

## 10. Known Future Work (product-level, not yet built)

- **MRI Extremity Studies** (Right/Left Shoulder, Elbow, Hip, Knee,
  Ankle) and **MRI insurance fields** (policy number, group number,
  precert number) — backend ready, pure frontend work, not started.
  Whether to include Wrist is an unresolved product decision.
- **The actual Billing department feature** — built incrementally as
  the Biller dashboard (`/billing`, §6, `ARCHITECTURE.md` §8); real
  Received-amount tracking now exists (§6). Remaining gap, not yet
  scoped: a real per-visit doctor link if the practice ever needs more
  than the current one-doctor-per-patient assumption. Open, unscoped
  questions around payment tracking specifically (partial payments,
  carrier remittance matching) remain a future product conversation,
  separate from the basic column's existence.
- **Full-visit edit capability** — explicitly out of scope pending a
  dedicated product conversation.
- **Holistic Front Desk + MD dashboard planning** — see §9.

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
