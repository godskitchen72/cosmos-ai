# Changelog

<!--
VERIFY BEFORE COMMITTING THIS FILE: this document's existence in the
actual repository was never confirmed before this draft was produced.
Run `cat CHANGELOG.md` or `git show HEAD:CHANGELOG.md` first:
  - If the file does not exist or is empty: this content is safe to use
    as-is.
  - If the file already exists with real prior entries: delete this
    comment block and APPEND the entry below to the end of the real
    file instead of overwriting it. Per AI_STYLE_GUIDE.md §3 / this
    protocol's own rule, CHANGELOG.md entries are append-only and never
    modified or deleted retroactively.
-->

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
