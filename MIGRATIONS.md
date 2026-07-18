# MIGRATIONS.md
## Cosmos Medical Technologies — Database Migration & Environment Reference
**Created:** Session 47 — July 17, 2026
**Maintained by:** Godskitchen / cosmos-ai repo

---

## Environment Map

| Environment | URL | Supabase Project | Branch |
|---|---|---|---|
| Production | cosmosmt.com | cosmos (prod) | `main` |
| Preview / Dev | cosmos-dashboard-nu.vercel.app | cosmos-dev | any feature branch |
| Local | localhost:3000 | cosmos-dev | any |

**How it works:** Vercel automatically injects the correct Supabase credentials based on the deployment environment. Feature branch pushes deploy to Preview (cosmos-dev). Merges to `main` deploy to Production.

---

## Environment Variables

### Production (Vercel — scoped to Production)
- `NEXT_PUBLIC_SUPABASE_URL` — production Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — production anon/publishable key
- `SUPABASE_SERVICE_KEY` — production service role key

### Preview (Vercel — scoped to Preview)
- `NEXT_PUBLIC_SUPABASE_URL` — cosmos-dev project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — cosmos-dev publishable key (`sb_publis...`)
- `SUPABASE_SERVICE_KEY_PREVIEW` — cosmos-dev secret key (`sb_secret...`)

### Shared (both environments)
- `NEXT_PUBLIC_PDF_API_URL` — cosmos-api Render URL (same for both)
- `RESEND_API_KEY` — email delivery (same for both)

### Code routing (lib/supabaseServer.ts)
```ts
const supabaseServiceKey =
  process.env.SUPABASE_SERVICE_KEY_PREVIEW ||
  process.env.SUPABASE_SERVICE_KEY!
```
Preview deployments pick up `SUPABASE_SERVICE_KEY_PREVIEW`; production falls through to `SUPABASE_SERVICE_KEY`.

---

## Migration Files

### supabase/migrations/000_initial_schema.sql
**Purpose:** Complete schema for a new Cosmos environment — all 34 tables, RLS, indexes, seed data.

**Tables covered (34 total):**
- Core: `patients`, `doctors`, `doctor_locations`, `office_locations`, `user_profiles`
- Scheduling: `appointments`, `patient_visits`, `patient_forms`, `patient_pain_chart`, `patient_procedures`, `visit_line_items`
- Referrals: `referrals`, `referral_appointments`, `referral_documents`, `referral_notes`, `referral_notifications`, `referral_status_history`, `referral_timeline`, `referral_types`, `referral_providers`
- Billing: `claims`, `billing_events`, `biller_md_flags`
- Reference: `insurance_carriers`, `lawyers`, `cpt_codes`, `icd10_codes`, `cpt_icd10_map`, `practice_settings`
- Security: `login_attempts`, `audit_logs`
- Deprecated: `_deprecated_cpt_templates`, `_deprecated_icd10_templates`, `_deprecated_patient_diagnoses`

**Known limitation:** Migration was generated from a batched CSV export (Supabase SQL Editor 100-row limit). Some tables had columns added via `schema_fix.sql` after initial creation. The migration file should be regenerated from a full pg_dump when desktop access is available.

**Column gaps fixed (Session 47):**
- `doctors` — missing 24 columns added via ALTER TABLE (email, tax_id, specialty, license_number, w9_*, available_days, max_patients_per_day, pc_corp_name, tax_classification, license_type, supervising_provider_id, default_start/end_time, mailing_*, pc_npi)
- `available_days` column type corrected from `TEXT[]` to `JSONB`

---

## RLS Policy Reference

All tables have:
1. `service_role_all_<table>` — service role bypass (full access for cosmos-api)
2. `authenticated_all_<table>` — authenticated users full access (added Session 47)
3. `authenticated_read_own_profile` — users can read their own user_profiles row

**Important:** When creating a new Supabase project, run `000_initial_schema.sql` which includes all RLS policies. No manual policy creation needed.

---

## Setting Up a New Environment

### Step 1 — Create Supabase project
- Go to supabase.com → New project
- Name it (e.g. `cosmos-staging`)
- Free tier is sufficient for dev/staging

### Step 2 — Apply schema
- Supabase dashboard → SQL Editor
- Paste contents of `supabase/migrations/000_initial_schema.sql`
- Click Run and enable RLS when prompted

### Step 3 — Create first superadmin user
- Supabase → Authentication → Users → Add user
- Enter email and temporary password
- Run `supabase/new_user.sql` (fill in email, role, name, PIN hint)

### Step 4 — Wire Vercel env vars
- Vercel → cosmos-dashboard → Settings → Environment Variables
- Add Preview-scoped vars pointing at new project URL and keys

### Step 5 — Seed reference data
- Run `supabase/seed_from_production.sql` (carriers, lawyers, doctors)
- Or use Dev Tools in Admin to generate test patients

---

## Creating New Users (any environment)

### Step 1 — Create auth user
Supabase → Authentication → Users → Add user → enter email + password

### Step 2 — Run new_user.sql
Fill in `supabase/new_user.sql` with:
- Email (must match auth user exactly)
- Role: `superadmin` | `admin` | `fd` | `md` | `biller` | `pa`
- Full name
- PIN hint (e.g. `****99` for PIN ending in 99)
- `doctor_id` — required for `md` role, null for all others

### Roles reference
| Role | Dashboard | Access Level |
|---|---|---|
| superadmin | All dashboards | Full access + ghost mode + admin panel |
| admin | Admin | Admin panel only, no ghost mode |
| fd | Front Desk V2 | Patient management, scheduling, documents |
| md | MD Chart | Clinical notes, referrals, visit review |
| biller | Billing | Claims, billing events, flags |
| pa | MD Chart | Physician assistant — ghost mode via supervising MD |

---

## Session 47 Schema Changes Applied to cosmos-dev

The following SQL was run manually on cosmos-dev to fix schema gaps. These changes are NOT yet reflected in `000_initial_schema.sql` and should be incorporated on next migration regeneration.

```sql
-- Primary keys added
ALTER TABLE public.insurance_carriers ADD PRIMARY KEY (id);
ALTER TABLE public.lawyers ADD PRIMARY KEY (id);
ALTER TABLE public.doctors ADD PRIMARY KEY (doctor_id);

-- Column type fix
ALTER TABLE public.doctors
  ALTER COLUMN available_days TYPE JSONB
  USING available_days::text::jsonb;

-- RLS policies added
CREATE POLICY "authenticated_read_own_profile" ON public.user_profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "authenticated_all_lawyers" ON public.lawyers
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_carriers" ON public.insurance_carriers
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_doctors" ON public.doctors
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_referral_providers" ON public.referral_providers
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_office_locations" ON public.office_locations
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_patients" ON public.patients
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_appointments" ON public.appointments
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_referrals" ON public.referrals
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_referral_appointments" ON public.referral_appointments
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_referral_documents" ON public.referral_documents
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_referral_types" ON public.referral_types
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_patient_visits" ON public.patient_visits
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_patient_forms" ON public.patient_forms
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
```

---

## Known Technical Debt

- `000_initial_schema.sql` was generated from batched CSV exports due to Supabase SQL Editor 100-row limit and Android/Termux environment constraints. It should be regenerated from a full `pg_dump` when desktop access is available.
- `patients.intake_url` column exists in production via manual SQL — not captured in original migration. Should be verified and added.
- No FK constraints defined in dev schema (PostgREST FK joins return null without them). Production FKs should be documented and added to migration.
- `referral_appointments.needs_review` and `reviewed_at` are vestigial (Migrations 031-032) — flagged for cleanup.

---

## cosmos-dev Seed Data (Session 47)

| Table | Records |
|---|---|
| `user_profiles` | 1 (superadmin: super@cosmos.local) |
| `doctors` | 7 (Yury Gottesman MD, Brad PAian PA, Don Kramer MD, Jim Carrey MD, Ron Pearlman Psychologist, John Orthobot MD, Reza NPian NP) |
| `insurance_carriers` | 20 |
| `lawyers` | 3 |
| `referral_types` | 14 |
| `practice_settings` | 1 |
| `patients` | 1 (DEV-TEST-001 Test Patient) |

---

*This document is maintained alongside HANDOVER.md. Update after any schema change, new migration, or environment configuration change.*
