-- ============================================================
-- Cosmos Medical Technologies
-- 000_initial_schema.sql
-- Complete schema migration — all 34 tables
-- Generated from production Supabase export July 2026
--
-- Usage: paste into Supabase SQL Editor on cosmos-dev project
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── _deprecated_cpt_templates (5 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public._deprecated_cpt_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  cpt_code TEXT NOT NULL,
  template_text TEXT NOT NULL,
  active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── _deprecated_icd10_templates (5 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public._deprecated_icd10_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  icd10_code TEXT NOT NULL,
  template_text TEXT NOT NULL,
  active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── _deprecated_patient_diagnoses (7 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public._deprecated_patient_diagnoses (
  id BIGINT NOT NULL,
  patient_id TEXT NOT NULL,
  visit_date DATE,
  icd10_code TEXT,
  description TEXT,
  primary_dx BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── practice_settings (15 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.practice_settings (
  id INTEGER NOT NULL DEFAULT 1,
  practice_name TEXT,
  corp_name TEXT,
  tax_classification TEXT DEFAULT 'individual'::text,
  llc_tax_classification TEXT,
  tax_id TEXT,
  street TEXT,
  city TEXT,
  state TEXT DEFAULT 'NY'::text,
  zip TEXT,
  phone TEXT,
  fax TEXT,
  updated_at TIMESTAMPTZ DEFAULT now(),
  session_timeout_minutes INTEGER NOT NULL DEFAULT 15,
  mfa_required BOOLEAN NOT NULL DEFAULT false
);

-- ── office_locations (9 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.office_locations (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  street TEXT,
  city TEXT,
  state TEXT DEFAULT 'NY'::text,
  zip TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  is_main_office BOOLEAN NOT NULL DEFAULT false
);

-- ── insurance_carriers (13 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.insurance_carriers (
  id SERIAL,
  carrier_name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  fax TEXT,
  email TEXT,
  street TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  claims_department TEXT,
  street2 TEXT,
  claims_email TEXT
);

-- ── lawyers (12 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.lawyers (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  firm_name TEXT,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  street TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  email TEXT,
  fax TEXT
);

-- ── cpt_codes (10 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.cpt_codes (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  cpt_code TEXT NOT NULL,
  description TEXT NOT NULL,
  fee NUMERIC,
  fee_varies BOOLEAN DEFAULT false,
  provider_type TEXT,
  supported_icd10 TEXT,
  validation_rule TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── icd10_codes (7 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.icd10_codes (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  code TEXT NOT NULL,
  description TEXT NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  category TEXT DEFAULT 'general'::text,
  clinical_note_template TEXT
);

-- ── cpt_icd10_map (4 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.cpt_icd10_map (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  cpt_code TEXT NOT NULL,
  icd10_code TEXT NOT NULL,
  required BOOLEAN DEFAULT false
);

-- ── referral_types (8 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_types (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  code TEXT NOT NULL,
  label TEXT NOT NULL,
  category TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  legacy_form_tag TEXT
);

-- ── referral_providers (19 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_providers (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  name TEXT NOT NULL,
  facility_name TEXT,
  specialty TEXT NOT NULL,
  npi TEXT,
  tax_id TEXT,
  street TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  phone TEXT,
  fax TEXT,
  email TEXT,
  preferred_contact TEXT,
  avg_turnaround_days INTEGER,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true
);

-- ── doctors (7 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.doctors (
  doctor_id UUID NOT NULL DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  npi TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  fax TEXT
);

-- ── doctor_locations (10 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.doctor_locations (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  doctor_id UUID,
  location_id UUID,
  days_of_week TEXT[],
  start_time TIME,
  end_time TIME,
  slot_minutes INTEGER DEFAULT 20,
  capacity INTEGER DEFAULT 25,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── patients (78 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.patients (
  patient_id TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  dob DATE,
  ssn_last4 TEXT,
  phone TEXT,
  street TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  doi DATE,
  time_of_accident TEXT,
  carrier TEXT,
  policy_num TEXT,
  claim_num TEXT,
  accident_description TEXT,
  hospital_treated TEXT,
  hospital_name TEXT,
  employment_status TEXT,
  loss_of_earnings TEXT,
  attorney_firm TEXT,
  attorney_name TEXT,
  attorney_phone TEXT,
  status TEXT DEFAULT 'Active Treatment'::text,
  cervical_rom INTEGER DEFAULT 20,
  lumbar_rom INTEGER DEFAULT 40,
  pain_neck INTEGER DEFAULT 5,
  pain_back INTEGER DEFAULT 5,
  pain_shoulder INTEGER DEFAULT 5,
  pain_knee INTEGER DEFAULT 5,
  pain_wrist INTEGER DEFAULT 1,
  pain_ankle INTEGER DEFAULT 1,
  registration_date DATE,
  last_md_visit DATE,
  clinical_notes TEXT DEFAULT 'Initial baseline established.'::text,
  nf2_url TEXT,
  carrier_address TEXT,
  doctor_id UUID,
  doctor_name TEXT,
  doctor_npi TEXT,
  doctor_address TEXT,
  doctor_phone TEXT,
  doctor_fax TEXT,
  doctor_email TEXT,
  policy_holder_name TEXT,
  accident_time_ampm TEXT,
  injury_description TEXT,
  section_10_answer TEXT,
  section_10_details TEXT,
  section_11_answer TEXT,
  section_11_details TEXT,
  vehicle_type TEXT,
  operator_type TEXT,
  aob_url TEXT,
  patient_signature_url TEXT,
  patient_signature_date TEXT,
  nf3_url TEXT,
  diagnosis TEXT,
  icd10_codes TEXT,
  cpt_codes TEXT,
  treatment_description TEXT,
  charges TEXT,
  future_treatment TEXT,
  carrier_email TEXT,
  carrier_phone TEXT,
  carrier_fax TEXT,
  sex TEXT,
  occupation TEXT,
  doctor_specialty TEXT,
  doctor_tax_id TEXT,
  narrative_url TEXT,
  accident_location TEXT,
  nf2_mailed_at TIMESTAMPTZ,
  nf2_mailed_note TEXT,
  nf2_mailed_receipt_filename TEXT,
  attorney_email TEXT,
  email TEXT,
  intake_url TEXT
);

-- ── user_profiles (8 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID NOT NULL,
  role TEXT NOT NULL,
  doctor_id UUID,
  full_name TEXT NOT NULL,
  pin_hint TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  active BOOLEAN NOT NULL DEFAULT true,
  fd_column_prefs JSONB
);

-- ── login_attempts (4 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.login_attempts (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  success BOOLEAN NOT NULL DEFAULT false
);

-- ── appointments (10 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL,
  doctor_id UUID NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  appointment_type TEXT DEFAULT 'Follow-Up'::text,
  status TEXT DEFAULT 'Scheduled'::text,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  location_id UUID
);

-- ── patient_visits (24 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.patient_visits (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL,
  doctor_name TEXT,
  visit_date DATE DEFAULT CURRENT_DATE,
  diagnosis TEXT,
  icd10_codes TEXT,
  cpt_codes TEXT,
  treatment_description TEXT,
  charges TEXT,
  future_treatment TEXT,
  rehab_recommendation TEXT,
  disability_status TEXT,
  work_status TEXT,
  clinical_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  pce_data JSONB,
  pce_url TEXT,
  visit_type TEXT,
  psych_referral BOOLEAN DEFAULT false,
  submitted_to_billing_at TIMESTAMPTZ,
  claim_status TEXT DEFAULT 'submitted'::text,
  claim_number TEXT,
  received_amount NUMERIC DEFAULT 0,
  payment_status TEXT DEFAULT 'none'::text
);

-- ── patient_forms (10 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.patient_forms (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL,
  form_type TEXT NOT NULL,
  due_date DATE,
  status TEXT DEFAULT 'pending'::text,
  generated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  visit_id UUID,
  filename TEXT,
  referral_data JSONB
);

-- ── patient_pain_chart (12 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.patient_pain_chart (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL,
  visit_id UUID,
  visit_date DATE DEFAULT CURRENT_DATE,
  body_part TEXT,
  side TEXT,
  pain_level INTEGER,
  complaint_type TEXT,
  generated_note TEXT,
  final_note TEXT,
  doctor_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── patient_procedures (9 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.patient_procedures (
  id BIGINT NOT NULL,
  patient_id TEXT NOT NULL,
  visit_date DATE,
  cpt_code TEXT,
  description TEXT,
  units INTEGER DEFAULT 1,
  charge NUMERIC,
  provider TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── visit_line_items (10 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.visit_line_items (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL,
  patient_id TEXT NOT NULL,
  cpt_code TEXT NOT NULL,
  description TEXT,
  fee NUMERIC DEFAULT 0,
  fee_varies BOOLEAN DEFAULT false,
  date_of_service DATE,
  place_of_service TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── referrals (27 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  patient_id TEXT NOT NULL,
  visit_id UUID,
  referral_type_id UUID NOT NULL,
  urgency TEXT NOT NULL DEFAULT 'routine'::text,
  body_part TEXT,
  clinical_reason TEXT NOT NULL,
  icd10_codes TEXT[] NOT NULL DEFAULT '{}'::text[],
  cpt_codes TEXT[] NOT NULL DEFAULT '{}'::text[],
  referral_provider_id UUID,
  preferred_provider_note TEXT,
  status TEXT NOT NULL DEFAULT 'new'::text,
  created_by_user_id UUID,
  assigned_to_user_id UUID,
  md_signature_url TEXT,
  md_signed_at TIMESTAMPTZ,
  auth_required BOOLEAN NOT NULL DEFAULT false,
  auth_number TEXT,
  auth_expires_at DATE,
  auth_obtained_at TIMESTAMPTZ,
  auth_obtained_by_user_id UUID,
  legacy_patient_form_id UUID,
  deleted_at TIMESTAMPTZ,
  deleted_by_user_id UUID,
  body_parts TEXT[] DEFAULT '{}'::text[]
);

-- ── referral_appointments (7 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_appointments (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  referral_id UUID NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME,
  location_name TEXT
);

-- ── referral_documents (13 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_documents (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  referral_id UUID NOT NULL,
  doc_type TEXT NOT NULL,
  filename TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_size_bytes INTEGER,
  mime_type TEXT,
  uploaded_by_user_id UUID,
  notes TEXT,
  deleted_at TIMESTAMPTZ,
  deleted_by_user_id UUID,
  appointment_id UUID
);

-- ── referral_notes (8 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_notes (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  referral_id UUID NOT NULL,
  author_user_id UUID,
  body TEXT NOT NULL,
  is_internal BOOLEAN NOT NULL DEFAULT true,
  deleted_at TIMESTAMPTZ
);

-- ── referral_notifications (10 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  referral_id UUID NOT NULL,
  notification_type TEXT NOT NULL,
  recipient_user_id UUID,
  recipient_role TEXT,
  queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  delivery_status TEXT NOT NULL DEFAULT 'queued'::text,
  error_message TEXT
);

-- ── referral_status_history (7 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_status_history (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  referral_id UUID NOT NULL,
  from_status TEXT,
  to_status TEXT NOT NULL,
  changed_by_user_id UUID,
  note TEXT
);

-- ── referral_timeline (8 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_timeline (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  referral_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_label TEXT NOT NULL,
  event_data JSONB,
  actor_user_id UUID,
  actor_label TEXT
);

-- ── claims (8 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.claims (
  claim_id UUID NOT NULL DEFAULT gen_random_uuid(),
  patient_id UUID,
  date_of_accident DATE,
  claim_number TEXT,
  insurance_company_name TEXT,
  policy_number TEXT,
  attorney_firm TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── billing_events (7 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.billing_events (
  event_id UUID NOT NULL DEFAULT gen_random_uuid(),
  claim_id UUID,
  nf2_received_date DATE,
  deadline_30_day DATE,
  usps_tracking_number TEXT,
  proof_of_mailing_date TIMESTAMPTZ,
  status TEXT DEFAULT 'Pending'::text
);

-- ── biller_md_flags (14 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.biller_md_flags (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL,
  patient_id TEXT NOT NULL,
  flagged_by UUID NOT NULL,
  flag_reason TEXT NOT NULL,
  flag_note TEXT,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  suggested_cpt_codes TEXT[] DEFAULT '{}'::text[],
  suggested_icd10_codes TEXT[] DEFAULT '{}'::text[],
  resolution TEXT,
  rejection_note TEXT,
  biller_dismissed_at TIMESTAMPTZ
);

-- ── audit_logs (13 columns) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID,
  user_email TEXT,
  user_role TEXT,
  action TEXT NOT NULL,
  category TEXT NOT NULL,
  record_type TEXT,
  record_id TEXT,
  record_label TEXT,
  old_data JSONB,
  new_data JSONB,
  metadata JSONB
);

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE public.practice_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.office_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_carriers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lawyers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cpt_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.icd10_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cpt_icd10_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_pain_chart ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_procedures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biller_md_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Service role bypass policies
-- Cosmos API authenticates with service role key
-- ============================================================

CREATE POLICY "service_role_all_practice_settings"
  ON public.practice_settings FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_office_locations"
  ON public.office_locations FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_insurance_carriers"
  ON public.insurance_carriers FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_lawyers"
  ON public.lawyers FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_cpt_codes"
  ON public.cpt_codes FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_icd10_codes"
  ON public.icd10_codes FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_cpt_icd10_map"
  ON public.cpt_icd10_map FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_types"
  ON public.referral_types FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_providers"
  ON public.referral_providers FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_doctors"
  ON public.doctors FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_doctor_locations"
  ON public.doctor_locations FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_patients"
  ON public.patients FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_user_profiles"
  ON public.user_profiles FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_login_attempts"
  ON public.login_attempts FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_appointments"
  ON public.appointments FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_patient_visits"
  ON public.patient_visits FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_patient_forms"
  ON public.patient_forms FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_patient_pain_chart"
  ON public.patient_pain_chart FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_patient_procedures"
  ON public.patient_procedures FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_visit_line_items"
  ON public.visit_line_items FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referrals"
  ON public.referrals FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_appointments"
  ON public.referral_appointments FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_documents"
  ON public.referral_documents FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_notes"
  ON public.referral_notes FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_notifications"
  ON public.referral_notifications FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_status_history"
  ON public.referral_status_history FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_referral_timeline"
  ON public.referral_timeline FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_claims"
  ON public.claims FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_billing_events"
  ON public.billing_events FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_biller_md_flags"
  ON public.biller_md_flags FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_audit_logs"
  ON public.audit_logs FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================
-- Performance indexes (mirrors Migration 028)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_patients_patient_id ON public.patients (patient_id);
CREATE INDEX IF NOT EXISTS idx_patients_status ON public.patients (status);
CREATE INDEX IF NOT EXISTS idx_patient_visits_patient_id ON public.patient_visits (patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_visits_visit_date ON public.patient_visits (visit_date);
CREATE INDEX IF NOT EXISTS idx_appointments_patient_id ON public.appointments (patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_id ON public.appointments (doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_appointment_date ON public.appointments (appointment_date);
CREATE INDEX IF NOT EXISTS idx_referrals_patient_id ON public.referrals (patient_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals (status);
CREATE INDEX IF NOT EXISTS idx_referral_appointments_referral_id ON public.referral_appointments (referral_id);
CREATE INDEX IF NOT EXISTS idx_referral_documents_referral_id ON public.referral_documents (referral_id);
CREATE INDEX IF NOT EXISTS idx_referral_timeline_referral_id ON public.referral_timeline (referral_id);
CREATE INDEX IF NOT EXISTS idx_referral_notes_referral_id ON public.referral_notes (referral_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_doctor_locations_doctor_id ON public.doctor_locations (doctor_id);
CREATE INDEX IF NOT EXISTS idx_login_attempts_user_id ON public.login_attempts (user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_id ON public.user_profiles (id);
CREATE INDEX IF NOT EXISTS idx_patient_forms_patient_id ON public.patient_forms (patient_id);
CREATE INDEX IF NOT EXISTS idx_visit_line_items_visit_id ON public.visit_line_items (visit_id);
CREATE INDEX IF NOT EXISTS idx_biller_md_flags_visit_id ON public.biller_md_flags (visit_id);
CREATE INDEX IF NOT EXISTS idx_biller_md_flags_patient_id ON public.biller_md_flags (patient_id);

-- ============================================================
-- Required seed data
-- ============================================================

-- practice_settings: app always reads id=1
INSERT INTO public.practice_settings (id, practice_name, session_timeout_minutes, mfa_required)
VALUES (1, 'Cosmos Medical Technologies (DEV)', 15, false)
ON CONFLICT (id) DO NOTHING;

-- referral_types: must match production codes exactly
INSERT INTO public.referral_types (code, label, category)
VALUES ('MRI', 'MRI', 'imaging')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('MRA', 'MRA', 'imaging')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('CT', 'CT Scan', 'imaging')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('SONO', 'Ultrasound', 'imaging')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('PT', 'Physical Therapy', 'therapy')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('ORT', 'Orthopedic', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('PAIN', 'Pain Management', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('VNG', 'VNG', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('ANS', 'ANS', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('EMG', 'EMG', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('FC', 'Functional Capacity', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('PSY', 'Psychology', 'specialist')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('DME', 'DME', 'dme')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.referral_types (code, label, category)
VALUES ('RX', 'Prescription', 'rx')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- Dev seed: one test patient for smoke testing
-- ============================================================

INSERT INTO public.patients (
  patient_id, first_name, last_name, status, doi, dob,
  claim_num, carrier, email
) VALUES (
  'DEV-TEST-001', 'Test', 'Patient', 'Active',
  '2026-01-15', '1985-06-20',
  'CLM-DEV-001', 'Dev Insurance Co', 'test@cosmosmt.com'
) ON CONFLICT (patient_id) DO NOTHING;

-- ============================================================
-- End of 000_initial_schema.sql
-- ============================================================
-- ============================================================
-- RLS Read Policies (client-side auth — anon key reads)
-- These allow authenticated users to read their own profile
-- and the app to function correctly on first login.
-- ============================================================

CREATE POLICY "authenticated_read_own_profile"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "authenticated_read_doctors"
  ON public.doctors
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "authenticated_read_locations"
  ON public.office_locations
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "authenticated_read_referral_types"
  ON public.referral_types
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "authenticated_read_practice_settings"
  ON public.practice_settings
  FOR SELECT
  TO authenticated
  USING (true);
