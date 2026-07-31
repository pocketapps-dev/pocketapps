-- ============================================================
-- PocketApps - Complete Schema
-- App: PocketExpenses (expense tracker)
-- Backend: Supabase (PostgreSQL + Auth + RLS)
-- ============================================================

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1. PROFILES (extends auth.users)
-- ============================================================
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  username    text,
  avatar_url  text,
  locale      text not null default 'pt-PT',
  currency    text not null default 'EUR',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Auto-create profile + per-app access + free subscription on signup
-- The app_name comes from the signup metadata (set via PocketAuth).
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, full_name, avatar_url)
  values (
    new.id,
    lower(coalesce(
      new.raw_user_meta_data ->> 'username',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      'user'
    )),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', '')
  );

  insert into public.user_app_access (user_id, app_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'app_name', 'expenses'))
  on conflict (user_id, app_name) do nothing;

  insert into public.subscriptions (user_id, app_name, plan, status)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'app_name', 'expenses'), 'free', 'active')
  on conflict do nothing;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 1b. USER APP ACCESS (which apps each user can use)
-- ============================================================
create table public.user_app_access (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  app_name            text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  welcome_email_sent  boolean not null default false,
  created_at          timestamptz not null default now(),
  unique(user_id, app_name)
);

-- ============================================================
-- 2. CATEGORIES (global per app)
-- ============================================================
create table public.categories (
  id          uuid primary key default uuid_generate_v4(),
  app_name    text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  name        text not null,
  icon_name   text not null default 'category',
  color_hex   text not null default '#6366f1',
  is_default  boolean not null default false,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  unique(app_name, name)
);

-- ============================================================
-- 3. EXPENSES (main data)
-- ============================================================
create table public.expenses (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  category_id     uuid not null references public.categories(id) on delete restrict,
  name            text not null,
  amount          numeric(12,2) not null default 0,
  type            text not null check (type in ('recurring', 'unique')),
  is_variable     boolean not null default false,
  due_day         integer check (due_day between 1 and 31),
  start_date      date,
  end_date        date,
  installments    integer check (installments > 0),
  frequency       integer check (frequency in (1, 2, 3, 6, 12)),
  reminder_days   integer not null default 3 check (reminder_days between 0 and 30),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ============================================================
-- 4. MONTHLY STATUS (per-expense per-month state)
-- ============================================================
create table public.monthly_status (
  id                uuid primary key default uuid_generate_v4(),
  expense_id        uuid not null references public.expenses(id) on delete cascade,
  user_id           uuid not null references auth.users(id) on delete cascade,
  expense_month     date not null,
  is_paid           boolean not null default false,
  paid_date         timestamptz,
  is_skipped        boolean not null default false,
  amount_confirmed  boolean not null default false,
  confirmed_amount  numeric(12,2),
  unique(expense_id, expense_month)
);

-- ============================================================
-- 5. SUBSCRIPTIONS (free/premium/founder per app)
-- ============================================================
create table public.subscriptions (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  app_name          text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  plan              text not null default 'free' check (plan in ('free', 'premium', 'founder')),
  status            text not null default 'active' check (status in ('active', 'inactive', 'cancelled', 'expired')),
  started_at        timestamptz not null default now(),
  ends_at           timestamptz,
  payment_provider  text,
  metadata          jsonb default '{}',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique(user_id, app_name)
);

-- ============================================================
-- 6. USER SETTINGS (per app)
-- ============================================================
create table public.user_settings (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  app_name    text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  settings    jsonb not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(user_id, app_name)
);

-- ============================================================
-- 7. MONTHLY SUMMARIES (archived per month)
-- ============================================================
create table public.monthly_summaries (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  app_name        text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  summary_month   date not null,
  total_amount    numeric(12,2) not null default 0,
  paid_amount     numeric(12,2) not null default 0,
  unpaid_amount   numeric(12,2) not null default 0,
  expense_count   integer not null default 0,
  paid_count      integer not null default 0,
  unpaid_count    integer not null default 0,
  generated_at    timestamptz not null default now(),
  unique(user_id, app_name, summary_month)
);

-- ============================================================
-- 8. ACTIVATION CODES
-- ============================================================
create table public.activation_codes (
  id                uuid primary key default uuid_generate_v4(),
  code              text not null unique,
  app_name          text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  plan              text not null default 'premium' check (plan in ('premium', 'founder')),
  duration_months   integer not null default 12,
  max_uses          integer not null default 1,
  use_count         integer not null default 0,
  is_active         boolean not null default true,
  used_by           uuid references auth.users(id) on delete set null,
  used_at           timestamptz,
  created_at        timestamptz not null default now(),
  expires_at        timestamptz
);

-- ============================================================
-- 9. REPORT PREFERENCES
-- ============================================================
create table public.report_preferences (
  id                      uuid primary key default uuid_generate_v4(),
  user_id                 uuid not null references auth.users(id) on delete cascade,
  app_name                text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  email_reports_enabled   boolean not null default false,
  report_day              integer not null default 28 check (report_day between 1 and 28),
  report_hour             integer not null default 9 check (report_hour between 0 and 23),
  include_categories      boolean not null default true,
  include_charts          boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique(user_id, app_name)
);

-- ============================================================
-- INDEXES
-- ============================================================
create index idx_expenses_user_id on public.expenses(user_id);
create index idx_expenses_user_active on public.expenses(user_id, is_active);
create index idx_expenses_user_category on public.expenses(user_id, category_id);
create index idx_expenses_user_type on public.expenses(user_id, type);
create index idx_expenses_due_day on public.expenses(user_id, due_day) where is_active = true;

create index idx_monthly_status_expense on public.monthly_status(expense_id);
create index idx_monthly_status_user_month on public.monthly_status(user_id, expense_month);
create index idx_monthly_status_user_paid on public.monthly_status(user_id, is_paid);
create index idx_monthly_status_month on public.monthly_status(expense_month);

create index idx_subscriptions_user on public.subscriptions(user_id);
create index idx_subscriptions_user_app on public.subscriptions(user_id, app_name);

create index idx_categories_app on public.categories(app_name);

create index idx_monthly_summaries_user on public.monthly_summaries(user_id, app_name);

create index idx_activation_codes_code on public.activation_codes(code);
create index idx_activation_codes_active on public.activation_codes(is_active) where is_active = true;

create index idx_user_settings_user_app on public.user_settings(user_id, app_name);

create index idx_user_app_access_user on public.user_app_access(user_id);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_profiles_updated_at
  before update on public.profiles
  for each row execute function public.update_updated_at();

create trigger update_expenses_updated_at
  before update on public.expenses
  for each row execute function public.update_updated_at();

create trigger update_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.update_updated_at();

create trigger update_user_settings_updated_at
  before update on public.user_settings
  for each row execute function public.update_updated_at();

create trigger update_report_preferences_updated_at
  before update on public.report_preferences
  for each row execute function public.update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.expenses enable row level security;
alter table public.monthly_status enable row level security;
alter table public.subscriptions enable row level security;
alter table public.user_settings enable row level security;
alter table public.monthly_summaries enable row level security;
alter table public.activation_codes enable row level security;
alter table public.report_preferences enable row level security;
alter table public.user_app_access enable row level security;

-- PROFILES
create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- USER APP ACCESS (view + create own access only; updates done by edge functions)
create policy "Users can view own app access"
  on public.user_app_access for select using (auth.uid() = user_id);
create policy "Users can insert own app access"
  on public.user_app_access for insert with check (auth.uid() = user_id);

-- CATEGORIES (all authenticated can read)
create policy "Authenticated users can view categories"
  on public.categories for select using (auth.role() = 'authenticated');

-- EXPENSES (full CRUD for owner)
create policy "Users can view own expenses"
  on public.expenses for select using (auth.uid() = user_id);
create policy "Users can insert own expenses"
  on public.expenses for insert with check (auth.uid() = user_id);
create policy "Users can update own expenses"
  on public.expenses for update using (auth.uid() = user_id);
create policy "Users can delete own expenses"
  on public.expenses for delete using (auth.uid() = user_id);

-- MONTHLY STATUS (full CRUD for owner)
create policy "Users can view own monthly status"
  on public.monthly_status for select using (auth.uid() = user_id);
create policy "Users can insert own monthly status"
  on public.monthly_status for insert with check (auth.uid() = user_id);
create policy "Users can update own monthly status"
  on public.monthly_status for update using (auth.uid() = user_id);
create policy "Users can delete own monthly status"
  on public.monthly_status for delete using (auth.uid() = user_id);

-- SUBSCRIPTIONS (read-only for user)
create policy "Users can view own subscriptions"
  on public.subscriptions for select using (auth.uid() = user_id);

-- USER SETTINGS (full CRUD for owner)
create policy "Users can view own settings"
  on public.user_settings for select using (auth.uid() = user_id);
create policy "Users can insert own settings"
  on public.user_settings for insert with check (auth.uid() = user_id);
create policy "Users can update own settings"
  on public.user_settings for update using (auth.uid() = user_id);

-- MONTHLY SUMMARIES (read-only for user)
create policy "Users can view own summaries"
  on public.monthly_summaries for select using (auth.uid() = user_id);

-- ACTIVATION CODES: service role only (no user policies)

-- REPORT PREFERENCES (full CRUD for owner)
create policy "Users can view own report preferences"
  on public.report_preferences for select using (auth.uid() = user_id);
create policy "Users can insert own report preferences"
  on public.report_preferences for insert with check (auth.uid() = user_id);
create policy "Users can update own report preferences"
  on public.report_preferences for update using (auth.uid() = user_id);

-- ============================================================
-- SEED DATA: Default categories
-- ============================================================

-- PocketExpenses categories
insert into public.categories (app_name, name, icon_name, color_hex, is_default, sort_order) values
  ('expenses', 'Casa',          'home',          '#f59e0b', true, 1),
  ('expenses', 'Electricidade', 'bolt',          '#eab308', true, 2),
  ('expenses', 'Agua',          'water_drop',    '#3b82f6', true, 3),
  ('expenses', 'Gas',           'local_fire_department', '#ef4444', true, 4),
  ('expenses', 'Veiculo',       'directions_car', '#8b5cf6', true, 5),
  ('expenses', 'Subscricoes',   'subscriptions', '#06b6d4', true, 6),
  ('expenses', 'Credito',       'account_balance', '#6366f1', true, 7),
  ('expenses', 'Saude',         'favorite',      '#ec4899', true, 8),
  ('expenses', 'Alimentacao',   'shopping_cart',  '#22c55e', true, 9),
  ('expenses', 'Restauracao',   'restaurant',    '#f97316', true, 10),
  ('expenses', 'Lazer',         'sports_esports', '#a855f7', true, 11),
  ('expenses', 'Educacao',      'school',        '#14b8a6', true, 12),
  ('expenses', 'Telecomunicacoes', 'phone',      '#64748b', true, 13),
  ('expenses', 'Seguros',       'shield',        '#0ea5e9', true, 14),
  ('expenses', 'Roupa',         'checkroom',     '#d946ef', true, 15),
  ('expenses', 'Outros',        'category',      '#78716c', true, 99);

-- PocketFuel categories
insert into public.categories (app_name, name, icon_name, color_hex, is_default, sort_order) values
  ('fuel', 'Gasolina',      'local_gas_station', '#ef4444', true, 1),
  ('fuel', 'Diesel',        'local_gas_station', '#3b82f6', true, 2),
  ('fuel', 'GPL',           'local_gas_station', '#22c55e', true, 3),
  ('fuel', 'Eletrico',      'ev_station',        '#f59e0b', true, 4),
  ('fuel', 'Manutencao',    'build',             '#8b5cf6', true, 5),
  ('fuel', 'Inspecao',      'policy',            '#06b6d4', true, 6),
  ('fuel', 'Seguro',        'shield',            '#ec4899', true, 7),
  ('fuel', 'IUC',           'receipt',           '#6366f1', true, 8),
  ('fuel', 'Estacionamento', 'pin_drop',         '#f97316', true, 9),
  ('fuel', 'Portagens',     'toll',              '#14b8a6', true, 10),
  ('fuel', 'Outros',        'category',          '#78716c', true, 99);

-- PocketShopping categories
insert into public.categories (app_name, name, icon_name, color_hex, is_default, sort_order) values
  ('shopping', 'Supermercado',  'shopping_cart',  '#22c55e', true, 1),
  ('shopping', 'Roupa',         'checkroom',      '#d946ef', true, 2),
  ('shopping', 'Eletronica',    'devices',        '#3b82f6', true, 3),
  ('shopping', 'Casa',          'home',           '#f59e0b', true, 4),
  ('shopping', 'Livros',        'menu_book',     '#a855f7', true, 5),
  ('shopping', 'Brinquedos',    'toys',           '#ec4899', true, 6),
  ('shopping', 'Desporto',      'sports_soccer',  '#ef4444', true, 7),
  ('shopping', 'Saude',         'favorite',       '#14b8a6', true, 8),
  ('shopping', 'Beleza',        'spa',            '#f97316', true, 9),
  ('shopping', 'Outros',        'category',       '#78716c', true, 99);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Check if the current user has access to an app
create or replace function public.check_app_access(p_app_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_app_access
    where user_id = auth.uid()
      and app_name = p_app_name
  );
$$;

-- Grant an existing user access to an app (+ free subscription)
create or replace function public.add_app_access(p_email text, p_app_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  select id into v_user_id from auth.users where email = lower(p_email) limit 1;
  if v_user_id is null then
    raise exception 'User not found';
  end if;

  insert into public.user_app_access (user_id, app_name)
  values (v_user_id, p_app_name)
  on conflict (user_id, app_name) do nothing;

  insert into public.subscriptions (user_id, app_name, plan, status)
  values (v_user_id, p_app_name, 'free', 'active')
  on conflict do nothing;
end;
$$;

-- Check if the welcome email was already sent for the current user in this app
create or replace function public.check_welcome_email_sent(p_app_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select welcome_email_sent from public.user_app_access
     where user_id = auth.uid() and app_name = p_app_name),
    false
  );
$$;

-- Get or create monthly status for an expense in a given month
create or replace function public.get_or_create_monthly_status(
  p_expense_id uuid,
  p_user_id uuid,
  p_month date
)
returns public.monthly_status as $$
declare
  v_status public.monthly_status;
begin
  select * into v_status
  from public.monthly_status
  where expense_id = p_expense_id and expense_month = p_month;

  if not found then
    insert into public.monthly_status (expense_id, user_id, expense_month)
    values (p_expense_id, p_user_id, p_month)
    returning * into v_status;
  end if;

  return v_status;
end;
$$ language plpgsql security definer;

-- Toggle paid status
create or replace function public.toggle_expense_paid(
  p_expense_id uuid,
  p_month date
)
returns public.monthly_status as $$
declare
  v_user_id uuid;
  v_status public.monthly_status;
begin
  select user_id into v_user_id from public.expenses where id = p_expense_id;
  if not found then raise exception 'Expense not found'; end if;

  v_status := public.get_or_create_monthly_status(p_expense_id, v_user_id, p_month);

  update public.monthly_status
  set is_paid = not v_status.is_paid,
      paid_date = case when not v_status.is_paid then now() else null end
  where id = v_status.id
  returning * into v_status;

  return v_status;
end;
$$ language plpgsql security definer;

-- Toggle skip status
create or replace function public.toggle_expense_skip(
  p_expense_id uuid,
  p_month date
)
returns public.monthly_status as $$
declare
  v_user_id uuid;
  v_status public.monthly_status;
begin
  select user_id into v_user_id from public.expenses where id = p_expense_id;
  if not found then raise exception 'Expense not found'; end if;

  v_status := public.get_or_create_monthly_status(p_expense_id, v_user_id, p_month);

  update public.monthly_status
  set is_skipped = not v_status.is_skipped
  where id = v_status.id
  returning * into v_status;

  return v_status;
end;
$$ language plpgsql security definer;

-- Confirm variable amount
create or replace function public.confirm_expense_amount(
  p_expense_id uuid,
  p_month date,
  p_amount numeric
)
returns public.monthly_status as $$
declare
  v_user_id uuid;
  v_status public.monthly_status;
begin
  select user_id into v_user_id from public.expenses where id = p_expense_id;
  if not found then raise exception 'Expense not found'; end if;

  v_status := public.get_or_create_monthly_status(p_expense_id, v_user_id, p_month);

  update public.monthly_status
  set amount_confirmed = true, confirmed_amount = p_amount
  where id = v_status.id
  returning * into v_status;

  return v_status;
end;
$$ language plpgsql security definer;

-- Get effective amount (mirrors Bill Pit's effectiveAmount)
create or replace function public.get_effective_amount(
  p_expense_id uuid,
  p_month date
)
returns numeric as $$
declare
  v_expense public.expenses;
  v_status public.monthly_status;
begin
  select * into v_expense from public.expenses where id = p_expense_id;

  if v_expense.is_variable then
    select * into v_status
    from public.monthly_status
    where expense_id = p_expense_id and expense_month = p_month;

    if found and v_status.amount_confirmed and v_status.confirmed_amount is not null then
      return v_status.confirmed_amount;
    end if;
  end if;

  return v_expense.amount;
end;
$$ language plpgsql security definer;

-- Validate activation code
create or replace function public.validate_activation_code(
  p_code text,
  p_app_name text
)
returns jsonb as $$
declare
  v_code public.activation_codes;
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('valid', false, 'error', 'Not authenticated');
  end if;

  select * into v_code
  from public.activation_codes
  where code = upper(trim(p_code))
    and app_name = p_app_name
    and is_active = true;

  if not found then
    return jsonb_build_object('valid', false, 'error', 'Código inválido');
  end if;

  if v_code.expires_at is not null and v_code.expires_at < now() then
    return jsonb_build_object('valid', false, 'error', 'Código expirado');
  end if;

  if v_code.use_count >= v_code.max_uses then
    return jsonb_build_object('valid', false, 'error', 'Código totalmente utilizado');
  end if;

  insert into public.subscriptions (user_id, app_name, plan, status, started_at, ends_at, payment_provider)
  values (
    v_user_id, p_app_name, v_code.plan, 'active', now(),
    now() + (v_code.duration_months || ' months')::interval, 'activation_code'
  )
  on conflict (user_id, app_name) do update
  set plan = v_code.plan, status = 'active', started_at = now(),
      ends_at = now() + (v_code.duration_months || ' months')::interval,
      payment_provider = 'activation_code',
      updated_at = now();

  update public.activation_codes
  set use_count = use_count + 1, used_by = v_user_id, used_at = now(),
      is_active = case when use_count + 1 >= max_uses then false else true end
  where id = v_code.id;

  return jsonb_build_object(
    'valid', true, 'plan', v_code.plan,
    'duration_months', v_code.duration_months
  );
end;
$$ language plpgsql security definer;

-- Archive monthly summaries
create or replace function public.archive_monthly_summary(
  p_user_id uuid,
  p_app_name text,
  p_month date
)
returns public.monthly_summaries as $$
declare
  v_summary public.monthly_summaries;
  v_total numeric := 0;
  v_paid numeric := 0;
  v_unpaid numeric := 0;
  v_total_count integer := 0;
  v_paid_count integer := 0;
  v_unpaid_count integer := 0;
  r record;
begin
  for r in
    select
      e.id,
      public.get_effective_amount(e.id, p_month) as eff_amount,
      coalesce(ms.is_paid, false) as is_paid
    from public.expenses e
    left join public.monthly_status ms on ms.expense_id = e.id and ms.expense_month = p_month
    where e.user_id = p_user_id
      and e.is_active = true
      and e.type = 'recurring'
  loop
    v_total := v_total + r.eff_amount;
    v_total_count := v_total_count + 1;
    if r.is_paid then
      v_paid := v_paid + r.eff_amount;
      v_paid_count := v_paid_count + 1;
    else
      v_unpaid := v_unpaid + r.eff_amount;
      v_unpaid_count := v_unpaid_count + 1;
    end if;
  end loop;

  insert into public.monthly_summaries (
    user_id, app_name, summary_month,
    total_amount, paid_amount, unpaid_amount,
    expense_count, paid_count, unpaid_count
  ) values (
    p_user_id, p_app_name, p_month,
    v_total, v_paid, v_unpaid,
    v_total_count, v_paid_count, v_unpaid_count
  )
  on conflict (user_id, app_name, summary_month) do update
  set total_amount = v_total, paid_amount = v_paid, unpaid_amount = v_unpaid,
      expense_count = v_total_count, paid_count = v_paid_count,
      unpaid_count = v_unpaid_count, generated_at = now()
  returning * into v_summary;

  return v_summary;
end;
$$ language plpgsql security definer;

-- Cleanup old data (called by Edge Function cron)
create or replace function public.cleanup_old_data(
  p_retention_months integer default 60
)
returns jsonb as $$
declare
  v_cutoff date := date_trunc('month', now()) - (p_retention_months || ' months')::interval;
  v_status_count integer;
  v_summary_count integer;
begin
  delete from public.monthly_status where expense_month < v_cutoff;
  get diagnostics v_status_count = row_count;

  delete from public.monthly_summaries
  where summary_month < v_cutoff - interval '12 months';
  get diagnostics v_summary_count = row_count;

  return jsonb_build_object(
    'deleted_monthly_status', v_status_count,
    'deleted_monthly_summaries', v_summary_count,
    'cutoff', v_cutoff
  );
end;
$$ language plpgsql security definer;
