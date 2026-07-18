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
- `NEXT_PUBLIC_SUPABASE_URL` — production Supabase project URL (`https://ttudxnzmybcwrtqlbtta.supabase.co`)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — production anon/publishable key
- `SUPABASE_SERVICE_KEY` — production service role key

### Preview (Vercel — scoped to Preview)
- `NEXT_PUBLIC_SUPABASE_URL` — cosmos-dev project URL (`https://tpwbgqfdznqtjqimxric.supabase.co`)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — cosmos-dev publishable key
- `SUPABASE_SERVICE_KEY_PREVIEW` — cosmos-dev secret key

### Shared (both environments)
- `NEXT_PUBLIC_PDF_API_URL` — cosmos-api Render URL (same for both)
- `RESEND_API_KEY` — email delivery (same for both)

### Code routing (lib/supabaseServer.ts)
```ts
const supabaseServiceKey =
  process.env.SUPABASE_SERVICE_KEY_PREVIEW ||
  process.env.SUPABASE_SERVICE_KEY!
```

**Warning:** Vercel mobile UI cannot reliably manage per-environment scoping for variables with the same name — always use Vercel desktop UI for env var changes.

---

## Migration Files

### supabase/migrations/000_initial_schema.sql
**Purpose:** Complete schema for a new Cosmos environment — all 34 tables, RLS, indexes, seed data.

**Known limitation:** Generated from batched CSV exports. Must be supplemented with manual fixes (see Session 47 Schema Changes below) until regenerated from a full pg_dump.

### supabase/new_user.sql
Reusable template for creating Cosmos users in any environment.

### supabase/seed_from_production.sql
Seed data copied from production: 20 insurance carriers, 3 lawyers, 7 doctors.

---

## RLS Policy Reference

All tables have:
1. `service_role_all_<table>` — service role bypass (full access for cosmos-api)
2. `authenticated_all_<table>` — authenticated users full access (added Session 47)
3. `authenticated_read_own_profile` — users can read their own user_profiles row

---

## Setting Up a New Environment

1. Create Supabase project (free tier)
2. SQL Editor → paste `000_initial_schema.sql` → Run and enable RLS
3. Run Session 47 Schema Changes SQL below
4. Supabase → Authentication → Users → Add user → run `new_user.sql`
5. Vercel env vars (desktop browser) → add Preview-scoped vars
6. Run `seed_from_production.sql` or use Dev Tools to generate test patients

---

## Creating New Users (any environment)

1. Supabase → Authentication → Users → Add user → enter email + password
2. Fill in `supabase/new_user.sql` and run

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

Run these after `000_initial_schema.sql` on any new environment until migration is regenerated.

```sql
-- Primary keys
ALTER TABLE public.insurance_carriers ADD PRIMARY KEY (id);
ALTER TABLE public.lawyers ADD PRIMARY KEY (id);
ALTER TABLE public.doctors ADD PRIMARY KEY (doctor_id);
ALTER TABLE public.referral_types ADD PRIMARY KEY (id);
ALTER TABLE public.referrals ADD PRIMARY KEY (id);
ALTER TABLE public.referral_appointments ADD PRIMARY KEY (id);
ALTER TABLE public.referral_documents ADD PRIMARY KEY (id);
ALTER TABLE public.referral_timeline ADD PRIMARY KEY (id);
ALTER TABLE public.referral_notes ADD PRIMARY KEY (id);
ALTER TABLE public.patients ADD PRIMARY KEY (patient_id);

-- Column type fix
ALTER TABLE public.doctors
  ALTER COLUMN available_days TYPE JSONB
  USING available_days::text::jsonb;

-- FK constraints
ALTER TABLE public.referrals ADD CONSTRAINT fk_referrals_referral_type FOREIGN KEY (referral_type_id) REFERENCES public.referral_types(id);
ALTER TABLE public.referrals ADD CONSTRAINT fk_referrals_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id);
ALTER TABLE public.referral_appointments ADD CONSTRAINT fk_ref_appointments_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.referral_documents ADD CONSTRAINT fk_ref_documents_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.referral_timeline ADD CONSTRAINT fk_ref_timeline_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.referral_notes ADD CONSTRAINT fk_ref_notes_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.patient_visits ADD CONSTRAINT fk_patient_visits_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id);
ALTER TABLE public.appointments ADD CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id);

-- RLS policies
CREATE POLICY "authenticated_read_own_profile" ON public.user_profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "authenticated_all_lawyers" ON public.lawyers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_carriers" ON public.insurance_carriers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_doctors" ON public.doctors FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_providers" ON public.referral_providers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_office_locations" ON public.office_locations FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_patients" ON public.patients FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_appointments" ON public.appointments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referrals" ON public.referrals FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_appointments" ON public.referral_appointments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_documents" ON public.referral_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_types" ON public.referral_types FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_patient_visits" ON public.patient_visits FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_patient_forms" ON public.patient_forms FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';
```

---

## Known Technical Debt

- `000_initial_schema.sql` needs regeneration from a full `pg_dump` (desktop required)
- `patients.intake_url` column exists in production via manual SQL — not in migration
- `referral_appointments.needs_review` and `reviewed_at` are vestigial — flagged for cleanup
- PostgREST on free-tier Supabase does not reliably pick up FK constraints — use flat selects + client-side joins (Cosmos standard pattern; `app/reports/referrals/page.tsx` is the reference implementation)

---

## cosmos-dev Seed Data (Session 47)

| Table | Records |
|---|---|
| `user_profiles` | 1 (superadmin: super@cosmos.local / PIN 999999) |
| `doctors` | 7 |
| `insurance_carriers` | 20 |
| `lawyers` | 3 |
| `referral_types` | 14 |
| `practice_settings` | 1 |
| `patients` | 25+ (seed + Dev Tools generated) |

---

*This document is maintained alongside HANDOVER.md. Update after any schema change, new migration, or environment configuration change.*
