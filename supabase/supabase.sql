-- عيادتي — مخطط المزامنة السحابية (Supabase / Postgres)
-- كل جدول مربوط بصاحب الحساب auth.users.id ومزوّد بسياسات RLS:
-- لا يرى أي مستخدم إلا بيانات عيادته.

-- دالة تحديث الطابع الزمني
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ملف العيادة (واحد لكل حساب)
create table if not exists public.clinic_profiles (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  spec_key    text not null default '',
  clinic_name text not null default '',
  doctor_name text not null default '',
  address     text not null default '',
  phone       text not null default '',
  fee         double precision not null default 0,
  open        boolean not null default true,
  updated_at  timestamptz not null default now()
);
alter table public.clinic_profiles enable row level security;
create policy "own clinic profile" on public.clinic_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_clinic_profiles_updated before update on public.clinic_profiles
  for each row execute function public.set_updated_at();

-- المرضى (national_id يُخزَّن مشفرًا كما في التطبيق)
create table if not exists public.patients (
  id          text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null default '',
  phone       text not null default '',
  national_id text not null default '',
  age         integer,
  gender      text not null default '',
  blood       text not null default '',
  allergies   text not null default '',
  chronic     text not null default '',
  notes       text not null default '',
  spec_fields jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted     boolean not null default false
);
alter table public.patients enable row level security;
create policy "own patients" on public.patients
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_patients_updated before update on public.patients
  for each row execute function public.set_updated_at();
create index if not exists patients_user_updated on public.patients (user_id, updated_at);

-- القياسات
create table if not exists public.measurements (
  id         text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  patient_id text not null references public.patients(id) on delete cascade,
  name       text not null default '',
  unit       text not null default '',
  value      double precision not null default 0,
  date       timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);
alter table public.measurements enable row level security;
create policy "own measurements" on public.measurements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_measurements_updated before update on public.measurements
  for each row execute function public.set_updated_at();
create index if not exists measurements_patient on public.measurements (patient_id);

-- الزيارات
create table if not exists public.visits (
  id         text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  patient_id text not null references public.patients(id) on delete cascade,
  at         timestamptz not null,
  type       text not null default '',
  dx         text not null default '',
  rx         text not null default '',
  note       text not null default '',
  fee        double precision not null default 0,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);
alter table public.visits enable row level security;
create policy "own visits" on public.visits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_visits_updated before update on public.visits
  for each row execute function public.set_updated_at();
create index if not exists visits_patient on public.visits (patient_id);

-- المواعيد
create table if not exists public.appointments (
  id           text primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  patient_id   text not null default '',
  patient_name text not null default '',
  date         text not null,
  time         text not null,
  type         text not null default '',
  status       text not null default 'مجدول',
  note         text not null default '',
  fee          double precision not null default 0,
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false
);
alter table public.appointments enable row level security;
create policy "own appointments" on public.appointments
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_appointments_updated before update on public.appointments
  for each row execute function public.set_updated_at();
create index if not exists appointments_user_date on public.appointments (user_id, date);

-- الخدمات والأسعار
create table if not exists public.services (
  id         text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null default '',
  price      double precision not null default 0,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false
);
alter table public.services enable row level security;
create policy "own services" on public.services
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_services_updated before update on public.services
  for each row execute function public.set_updated_at();
