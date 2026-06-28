# Changelog
## 2026-06-27 — Biller Dashboard: typography fixes, charting, Denial Docs delete

- Fixed production 500 crash on `/billing` (stale `claim_status` values; defensive `StatusCell` fallback + data migration)
- Renamed "Payment Status" column to "Denial Status"; "Submitted" column to "Bill Received" (disambiguates from the existing `$` Received column) — label-only, no field/schema change
- Brightened Biller-scoped green from `#19a866` to `#2ee08a`
- Reordered Denial Docs column to sit immediately after Denial Status
- Added biller-initiated hard-delete capability for uploaded Denial Docs (confirm-before-delete; removes both the storage file and the `patient_forms` record)
- New shared font module `app/lib/fonts.ts` (Oxanium) — fixes the font not reaching Radix Select/DropdownMenu portaled content
- Fixed missing font-size on sortable column headers, missing font on `ReceivedCell`, `SelectTrigger` rendering black text once a value is selected, and `Button` `outline`/`ghost` variants rendering black text — five related instances of the same root cause (no Tailwind preflight reset on this project, so bare interactive elements never inherit color/font/size automatically)
- Added `text-size-adjust: 100%` globally to disable Android Chrome's font-boosting heuristic
- Added Status + Denial Status donut charts (Recharts, built without shadcn's `chart.tsx` wrapper due to an open upstream Recharts v3 compatibility issue — `shadcn-ui/ui#9892`)
- Replaced the above two donuts with a single "Paid vs Outstanding by Carrier" stacked bar chart (Paid = sum of `received_amount`, Outstanding = `billed - received_amount` floored at $0); kept the existing plain "By Carrier" list as a separate, second card
- **Documentation correction**: prior `HANDOVER.md`/`ARCHITECTURE.md`/`PRODUCT_SPEC.md` describing the Biller dashboard's "Received" column as an unbacked placeholder were stale — live code confirms a real, working `received_amount` column already existed; corrected in this session's documentation pass

## 2026-06-27 (evening) — Orthopedic Surgeon & Pain Management referrals; Save/View pattern; PDF filename cleanup

- New referral types **Orthopedic Surgeon** and **Pain Management**, full stack: `forms/ortho.py`/`forms/pain_mgmt.py` (field names verified 1:1 against the real PDFs via `pypdf.get_fields()`), `main.py`/`pdf_engine.py` wiring, MD chart buttons, FD profile cards (filled the 2 prior "Reserved" placeholder slots — none remain)
- Verified end-to-end against real production data: direct API test (`curl`) plus human visual review of both generated PDFs for a real patient with nearly every checkbox exercised
- **Save→View button pattern** adopted as the standing pattern for all MD-discretionary referral types except ICD-10 (explicit product decision) — replaces Generate→View; saving no longer auto-opens the PDF, and revisiting an already-saved referral now shows "View" immediately (checked server-side on page load) instead of resetting to "Save", to prevent an accidental overwrite. A confirm-gated "Regenerate" link is the deliberate escape hatch. Applied to DME, Ortho, Pain Mgmt, ANS, MRI, PT, Rx, VNG — **deploy status unconfirmed, see `HANDOVER.md`**
- Renamed 7 referral PDF templates to short filenames (`ANS.pdf`, `DME.pdf`, `ICD10.pdf`, `MRI.pdf`, `PT.pdf`, `RX.pdf`, `VNG.pdf`) plus `PCE.pdf`, with matching `forms/*.py` updates
- Resolved two real merge collisions mid-session, both from a separate GitHub-web upload landing on `origin/main` independently of this Termux session — one a true duplicate (byte-identical), one a git case-sensitivity false-collision (`ans.pdf` vs `ANS.pdf`); both confirmed via `md5sum` before merging, zero data loss
