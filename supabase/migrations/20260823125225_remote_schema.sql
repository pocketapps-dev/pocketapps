-- ============================================================================
-- Snapshot completo do schema de producao (Supabase)
-- Gerado a partir dos catalogos do Postgres em 2026-08-23.
-- Substitui os antigos 001-013 (arquivados em supabase/_archive_pre_pull).
-- Alvo: base de dados nova/limpa com o mesmo layout de producao.
-- ============================================================================

-- Extensoes
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_stat_statements with schema extensions;

-- Tabelas
create table public.activation_codes (
  id uuid default uuid_generate_v4() not null,
  code text not null,
  app_name text not null,
  plan text default 'premium'::text,
  duration_months integer default 12 not null,
  max_uses integer default 1 not null,
  use_count integer default 0 not null,
  is_active boolean default true not null,
  used_by uuid,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone,
  theme_key text
);

create table public.categories (
  id uuid default uuid_generate_v4() not null,
  app_name text not null,
  name text not null,
  icon_name text default 'category'::text not null,
  color_hex text default '#6366f1'::text not null,
  is_default boolean default false not null,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  budget numeric,
  user_id uuid not null
);

create table public.expenses (
  id uuid default uuid_generate_v4() not null,
  user_id uuid not null,
  category_id uuid not null,
  name text not null,
  amount numeric(12,2) default 0 not null,
  type text not null,
  is_variable boolean default false not null,
  due_day integer,
  start_date date,
  end_date date,
  installments integer,
  frequency integer,
  reminder_days integer default 3 not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.monthly_status (
  id uuid default uuid_generate_v4() not null,
  expense_id uuid not null,
  user_id uuid not null,
  expense_month date not null,
  is_paid boolean default false not null,
  paid_date timestamp with time zone,
  is_skipped boolean default false not null,
  amount_confirmed boolean default false not null,
  confirmed_amount numeric(12,2)
);

create table public.monthly_summaries (
  id uuid default uuid_generate_v4() not null,
  user_id uuid not null,
  app_name text not null,
  summary_month date not null,
  total_amount numeric(12,2) default 0 not null,
  paid_amount numeric(12,2) default 0 not null,
  unpaid_amount numeric(12,2) default 0 not null,
  expense_count integer default 0 not null,
  paid_count integer default 0 not null,
  unpaid_count integer default 0 not null,
  generated_at timestamp with time zone default now() not null
);

create table public.profiles (
  id uuid not null,
  full_name text,
  avatar_url text,
  locale text default 'pt-PT'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  username text,
  privacy_accepted_at timestamp with time zone,
  terms_accepted_at timestamp with time zone,
  age_confirmed_at timestamp with time zone,
  onboarding_completed boolean default false not null,
  wizard_free_used boolean default false not null
);

create table public.report_preferences (
  id uuid default uuid_generate_v4() not null,
  user_id uuid not null,
  app_name text not null,
  email_reports_enabled boolean default true not null,
  report_day integer default 28 not null,
  report_hour integer default 9 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  unsubscribe_token uuid default gen_random_uuid(),
  report_type text default 'detailed'::text not null
);

create table public.subscriptions (
  id uuid default uuid_generate_v4() not null,
  user_id uuid not null,
  app_name text not null,
  plan text default 'free'::text not null,
  status text default 'active'::text not null,
  started_at timestamp with time zone default now() not null,
  ends_at timestamp with time zone,
  payment_provider text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.theme_purchases (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  app_name text not null,
  theme_key text not null,
  amount_cents integer not null,
  payment_provider text,
  payment_ref text,
  status text default 'completed'::text not null,
  created_at timestamp with time zone default now() not null
);

create table public.themes (
  id uuid default gen_random_uuid() not null,
  app_name text not null,
  theme_key text not null,
  name text not null,
  description text,
  price_cents integer default 0 not null,
  seed_color text not null,
  is_premium boolean default false not null,
  is_paid boolean default false not null,
  is_active boolean default true not null,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  brightness text default 'light'::text not null
);

create table public.user_app_access (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  app_name text not null,
  created_at timestamp with time zone default now(),
  welcome_email_sent boolean default false
);

create table public.user_settings (
  id uuid default uuid_generate_v4() not null,
  user_id uuid not null,
  app_name text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.user_themes (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  app_name text not null,
  theme_key text not null,
  source text default 'purchase'::text not null,
  purchased_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);

-- Constraints
alter table public.activation_codes add constraint activation_codes_plan_check CHECK (((theme_key IS NOT NULL) OR ((plan IS NOT NULL) AND (plan = ANY (ARRAY['premium'::text, 'founder'::text])))));
alter table public.activation_codes add constraint activation_codes_used_by_fkey FOREIGN KEY (used_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.activation_codes add constraint activation_codes_pkey PRIMARY KEY (id);
alter table public.activation_codes add constraint activation_codes_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.activation_codes add constraint activation_codes_code_key UNIQUE (code);
alter table public.categories add constraint categories_pkey PRIMARY KEY (id);
alter table public.categories add constraint categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.categories add constraint categories_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.categories add constraint categories_app_name_name_key UNIQUE (app_name, name);
alter table public.expenses add constraint expenses_reminder_days_check CHECK (((reminder_days >= 0) AND (reminder_days <= 30)));
alter table public.expenses add constraint expenses_pkey PRIMARY KEY (id);
alter table public.expenses add constraint expenses_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.expenses add constraint expenses_type_check CHECK ((type = ANY (ARRAY['recurring'::text, 'unique'::text])));
alter table public.expenses add constraint expenses_due_day_check CHECK (((due_day >= 1) AND (due_day <= 31)));
alter table public.expenses add constraint expenses_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT;
alter table public.expenses add constraint expenses_installments_check CHECK ((installments > 0));
alter table public.expenses add constraint expenses_frequency_check CHECK ((frequency = ANY (ARRAY[1, 2, 3, 6, 12])));
alter table public.monthly_status add constraint monthly_status_pkey PRIMARY KEY (id);
alter table public.monthly_status add constraint monthly_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.monthly_status add constraint monthly_status_expense_id_expense_month_key UNIQUE (expense_id, expense_month);
alter table public.monthly_status add constraint monthly_status_expense_id_fkey FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE;
alter table public.monthly_summaries add constraint monthly_summaries_user_id_app_name_summary_month_key UNIQUE (user_id, app_name, summary_month);
alter table public.monthly_summaries add constraint monthly_summaries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.monthly_summaries add constraint monthly_summaries_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.monthly_summaries add constraint monthly_summaries_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_username_key UNIQUE (username);
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.report_preferences add constraint report_preferences_report_type_check CHECK ((report_type = ANY (ARRAY['simple'::text, 'detailed'::text])));
alter table public.report_preferences add constraint report_preferences_user_id_app_name_key UNIQUE (user_id, app_name);
alter table public.report_preferences add constraint report_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.report_preferences add constraint report_preferences_report_hour_check CHECK (((report_hour >= 0) AND (report_hour <= 23)));
alter table public.report_preferences add constraint report_preferences_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.report_preferences add constraint report_preferences_pkey PRIMARY KEY (id);
alter table public.report_preferences add constraint report_preferences_report_day_check CHECK (((report_day >= 1) AND (report_day <= 28)));
alter table public.subscriptions add constraint subscriptions_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'cancelled'::text, 'expired'::text])));
alter table public.subscriptions add constraint subscriptions_user_id_app_name_key UNIQUE (user_id, app_name);
alter table public.subscriptions add constraint subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.subscriptions add constraint subscriptions_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.subscriptions add constraint subscriptions_pkey PRIMARY KEY (id);
alter table public.subscriptions add constraint subscriptions_plan_check CHECK ((plan = ANY (ARRAY['free'::text, 'premium'::text, 'founder'::text])));
alter table public.theme_purchases add constraint theme_purchases_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'refunded'::text])));
alter table public.theme_purchases add constraint theme_purchases_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.theme_purchases add constraint theme_purchases_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.theme_purchases add constraint theme_purchases_pkey PRIMARY KEY (id);
alter table public.themes add constraint themes_brightness_check CHECK ((brightness = ANY (ARRAY['light'::text, 'dark'::text])));
alter table public.themes add constraint themes_pkey PRIMARY KEY (id);
alter table public.themes add constraint themes_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.themes add constraint themes_app_name_theme_key_key UNIQUE (app_name, theme_key);
alter table public.user_app_access add constraint user_app_access_user_id_app_name_key UNIQUE (user_id, app_name);
alter table public.user_app_access add constraint user_app_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.user_app_access add constraint user_app_access_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.user_app_access add constraint user_app_access_pkey PRIMARY KEY (id);
alter table public.user_settings add constraint user_settings_user_id_app_name_key UNIQUE (user_id, app_name);
alter table public.user_settings add constraint user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.user_settings add constraint user_settings_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.user_settings add constraint user_settings_pkey PRIMARY KEY (id);
alter table public.user_themes add constraint user_themes_user_id_app_name_theme_key_key UNIQUE (user_id, app_name, theme_key);
alter table public.user_themes add constraint user_themes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.user_themes add constraint user_themes_source_check CHECK ((source = ANY (ARRAY['purchase'::text, 'premium'::text, 'gift'::text, 'activation_code'::text])));
alter table public.user_themes add constraint user_themes_app_name_check CHECK ((app_name = ANY (ARRAY['expenses'::text, 'fuel'::text, 'shopping'::text])));
alter table public.user_themes add constraint user_themes_pkey PRIMARY KEY (id);

-- Indices
create index if not exists idx_activation_codes_theme ON public.activation_codes USING btree (theme_key) WHERE (theme_key IS NOT NULL);
create index if not exists idx_expenses_user_id ON public.expenses USING btree (user_id);
create index if not exists idx_monthly_status_user_id ON public.monthly_status USING btree (user_id);
create index if not exists idx_theme_purchases_user_theme ON public.theme_purchases USING btree (user_id, theme_key);
create index if not exists idx_theme_purchases_user ON public.theme_purchases USING btree (user_id);
create index if not exists idx_themes_app_active ON public.themes USING btree (app_name) WHERE (is_active = true);
create index if not exists idx_themes_app ON public.themes USING btree (app_name);
create index if not exists idx_user_app_access_user_id ON public.user_app_access USING btree (user_id);
create index if not exists idx_user_app_access_app_name ON public.user_app_access USING btree (app_name);
create index if not exists idx_user_themes_user_app ON public.user_themes USING btree (user_id, app_name);
create index if not exists idx_user_themes_user ON public.user_themes USING btree (user_id);

-- Funcoes
CREATE OR REPLACE FUNCTION public.add_app_access(p_email text, p_app_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = lower(p_email) LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  INSERT INTO public.user_app_access (user_id, app_name)
  VALUES (v_user_id, p_app_name)
  ON CONFLICT (user_id, app_name) DO NOTHING;

  -- Criar subscription free se nÃ£o existir
  INSERT INTO public.subscriptions (user_id, app_name, plan, status)
  VALUES (v_user_id, p_app_name, 'free', 'active')
  ON CONFLICT DO NOTHING;
END;
$function$

CREATE OR REPLACE FUNCTION public.archive_monthly_summary(p_user_id uuid, p_app_name text, p_month date)
 RETURNS monthly_summaries
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.check_app_access(p_app_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.user_app_access
    WHERE user_id = (select auth.uid())
    AND app_name = p_app_name
  );
$function$

CREATE OR REPLACE FUNCTION public.check_username_available(p_username text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  SELECT NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = lower(p_username))
$function$

CREATE OR REPLACE FUNCTION public.cleanup_old_data(p_retention_months integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.confirm_expense_amount(p_expense_id uuid, p_month date, p_amount numeric)
 RETURNS monthly_status
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.enforce_free_category_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_premium boolean;
  v_count int;
begin
  select exists (
    select 1
    from public.subscriptions s
    where s.user_id = new.user_id
      and s.app_name = new.app_name
      and s.status = 'active'
      and s.plan <> 'free'
      and (s.ends_at is null or s.ends_at > now())
  ) into v_premium;

  if v_premium is not true then
    select count(*) into v_count
    from public.categories c
    where c.user_id = new.user_id
      and c.app_name = new.app_name;

    if v_count >= 10 then
      raise exception 'Limite do plano Free atingido: mÃ¡ximo de 10 categorias. Subscreve o Premium para categorias ilimitadas.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.get_effective_amount(p_expense_id uuid, p_month date)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT email FROM auth.users
  WHERE id = (SELECT id FROM public.profiles WHERE username = lower(p_username) LIMIT 1)
  LIMIT 1;
$function$

CREATE OR REPLACE FUNCTION public.get_founder_count()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(distinct user_id)::int
  from public.subscriptions
  where plan = 'founder' and status = 'active';
$function$

CREATE OR REPLACE FUNCTION public.get_or_create_monthly_status(p_expense_id uuid, p_user_id uuid, p_month date)
 RETURNS monthly_status
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.get_user_app_access()
 RETURNS TABLE(app_name text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT ua.app_name, ua.created_at
  FROM public.user_app_access ua
  WHERE ua.user_id = (select auth.uid())
  ORDER BY ua.created_at;
$function$

CREATE OR REPLACE FUNCTION public.get_user_themes(p_app_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_user_id uuid;
  v_has_premium boolean;
  v_result jsonb;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('error', 'Not authenticated');
  end if;

  select exists(
    select 1 from public.subscriptions
    where user_id = v_user_id
      and app_name = p_app_name
      and plan in ('premium', 'founder')
      and status = 'active'
      and (ends_at is null or ends_at > now())
  ) into v_has_premium;

  select jsonb_agg(
    jsonb_build_object(
      'theme_key', t.theme_key,
      'name', t.name,
      'description', t.description,
      'price_cents', t.price_cents,
      'seed_color', t.seed_color,
      'brightness', t.brightness,
      'is_premium', t.is_premium,
      'is_paid', t.is_paid,
      'sort_order', t.sort_order,
      'available',
        case
          when not t.is_premium and not t.is_paid then true
          when t.is_premium and v_has_premium then true
          when t.is_paid and exists(
            select 1 from public.user_themes ut
            where ut.user_id = v_user_id
              and ut.app_name = p_app_name
              and ut.theme_key = t.theme_key
          ) then true
          else false
        end,
      'purchased',
        exists(
          select 1 from public.user_themes ut
          where ut.user_id = v_user_id
            and ut.app_name = p_app_name
            and ut.theme_key = t.theme_key
        )
    )
    order by
      case when not t.is_premium and not t.is_paid then 0 else 1 end,
      t.sort_order
  )
  into v_result
  from public.themes t
  where t.app_name = p_app_name
    and t.is_active = true;

  return coalesce(v_result, '[]'::jsonb);
end;
$function$

CREATE OR REPLACE FUNCTION public.grant_theme_to_user(p_user_id uuid, p_app_name text, p_theme_key text, p_source text DEFAULT 'purchase'::text, p_payment_provider text DEFAULT 'stripe'::text, p_payment_ref text DEFAULT NULL::text, p_amount_cents integer DEFAULT 99)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_theme public.themes;
begin
  -- Verify the theme exists
  select * into v_theme
  from public.themes
  where app_name = p_app_name
    and theme_key = p_theme_key
    and is_active = true;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Tema nÃ£o encontrado');
  end if;

  -- Add theme to user's themes
  insert into public.user_themes (user_id, app_name, theme_key, source)
  values (p_user_id, p_app_name, p_theme_key, p_source)
  on conflict (user_id, app_name, theme_key) do nothing;

  -- Log the purchase
  insert into public.theme_purchases (user_id, app_name, theme_key, amount_cents, payment_provider, payment_ref, status)
  values (p_user_id, p_app_name, p_theme_key, p_amount_cents, p_payment_provider, p_payment_ref, 'completed');

  return jsonb_build_object(
    'success', true,
    'theme_key', p_theme_key,
    'theme_name', v_theme.name
  );
end;
$function$

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.profiles (id, username, full_name, avatar_url, privacy_accepted_at, terms_accepted_at, age_confirmed_at)
  values (
    new.id,
    lower(coalesce(
      new.raw_user_meta_data ->> 'username',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      'user'
    )),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', ''),
    case when coalesce(new.raw_user_meta_data ->> 'privacy_accepted', 'false') = 'true' then now() end,
    case when coalesce(new.raw_user_meta_data ->> 'terms_accepted', 'false') = 'true' then now() end,
    case when coalesce(new.raw_user_meta_data ->> 'age_confirmed', 'false') = 'true' then now() end
  );

  insert into public.user_app_access (user_id, app_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'app_name', 'expenses'))
  on conflict (user_id, app_name) do nothing;

  insert into public.subscriptions (user_id, app_name, plan, status)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'app_name', 'expenses'), 'free', 'active')
  on conflict do nothing;

  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$

CREATE OR REPLACE FUNCTION public.toggle_expense_paid(p_expense_id uuid, p_month date)
 RETURNS monthly_status
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.toggle_expense_skip(p_expense_id uuid, p_month date)
 RETURNS monthly_status
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.validate_activation_code(p_code text, p_app_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    return jsonb_build_object('valid', false, 'error', 'CÃ³digo invÃ¡lido');
  end if;

  if v_code.expires_at is not null and v_code.expires_at < now() then
    return jsonb_build_object('valid', false, 'error', 'CÃ³digo expirado');
  end if;

  if v_code.use_count >= v_code.max_uses then
    return jsonb_build_object('valid', false, 'error', 'CÃ³digo totalmente utilizado');
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
$function$

CREATE OR REPLACE FUNCTION public.validate_theme_activation_code(p_code text, p_app_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_code public.activation_codes;
  v_user_id uuid;
  v_theme public.themes;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('valid', false, 'error', 'Not authenticated');
  end if;

  -- Find the code
  select * into v_code
  from public.activation_codes
  where code = upper(trim(p_code))
    and app_name = p_app_name
    and is_active = true
    and theme_key is not null;

  if not found then
    return jsonb_build_object('valid', false, 'error', 'CÃ³digo invÃ¡lido');
  end if;

  -- Check expiry
  if v_code.expires_at is not null and v_code.expires_at < now() then
    return jsonb_build_object('valid', false, 'error', 'CÃ³digo expirado');
  end if;

  -- Check usage limit
  if v_code.use_count >= v_code.max_uses then
    return jsonb_build_object('valid', false, 'error', 'CÃ³digo totalmente utilizado');
  end if;

  -- Verify the theme exists and is active
  select * into v_theme
  from public.themes
  where app_name = p_app_name
    and theme_key = v_code.theme_key
    and is_active = true;

  if not found then
    return jsonb_build_object('valid', false, 'error', 'Tema nÃ£o encontrado');
  end if;

  -- Add theme to user's themes
  insert into public.user_themes (user_id, app_name, theme_key, source)
  values (v_user_id, p_app_name, v_code.theme_key, 'activation_code')
  on conflict (user_id, app_name, theme_key) do nothing;

  -- Log the purchase
  insert into public.theme_purchases (user_id, app_name, theme_key, amount_cents, payment_provider, payment_ref, status)
  values (v_user_id, p_app_name, v_code.theme_key, 0, 'activation_code', v_code.code, 'completed');

  -- Mark code as used
  update public.activation_codes
  set use_count = use_count + 1, used_by = v_user_id, used_at = now(),
      is_active = case when use_count + 1 >= max_uses then false else true end
  where id = v_code.id;

  return jsonb_build_object(
    'valid', true,
    'theme_key', v_code.theme_key,
    'theme_name', v_theme.name
  );
end;
$function$

-- Triggers
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()
CREATE TRIGGER update_report_preferences_updated_at BEFORE UPDATE ON public.report_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at()
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at()
CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON public.user_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at()
CREATE TRIGGER trg_enforce_free_category_limit BEFORE INSERT ON public.categories FOR EACH ROW EXECUTE FUNCTION enforce_free_category_limit()
CREATE TRIGGER update_expenses_updated_at BEFORE UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION update_updated_at()
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()

-- Row Level Security
alter table public.activation_codes enable row level security;
alter table public.categories enable row level security;
alter table public.expenses enable row level security;
alter table public.monthly_status enable row level security;
alter table public.monthly_summaries enable row level security;
alter table public.profiles enable row level security;
alter table public.report_preferences enable row level security;
alter table public.subscriptions enable row level security;
alter table public.theme_purchases enable row level security;
alter table public.themes enable row level security;
alter table public.user_app_access enable row level security;
alter table public.user_settings enable row level security;
alter table public.user_themes enable row level security;

-- Policies
create policy "No direct access to activation_codes"
    on public.activation_codes
    to {public}
    using (false);
create policy "Authenticated users can delete categories"
    on public.categories
    to {public}
    for DELETE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Authenticated users can insert categories"
    on public.categories
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = user_id));
create policy "Authenticated users can update categories"
    on public.categories
    to {public}
    for UPDATE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Authenticated users can view categories"
    on public.categories
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can delete own categories"
    on public.categories
    to {public}
    for DELETE
    using ((auth.uid() = user_id));
create policy "Users can insert own categories"
    on public.categories
    to {public}
    for INSERT
    with check ((auth.uid() = user_id));
create policy "Users can update own categories"
    on public.categories
    to {public}
    for UPDATE
    using ((auth.uid() = user_id));
create policy "Users can view own categories"
    on public.categories
    to {public}
    for SELECT
    using ((auth.uid() = user_id));
create policy "Users can delete own expenses"
    on public.expenses
    to {public}
    for DELETE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can insert own expenses"
    on public.expenses
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can update own expenses"
    on public.expenses
    to {public}
    for UPDATE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own expenses"
    on public.expenses
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can delete own monthly status"
    on public.monthly_status
    to {public}
    for DELETE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can insert own monthly status"
    on public.monthly_status
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can update own monthly status"
    on public.monthly_status
    to {public}
    for UPDATE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own monthly status"
    on public.monthly_status
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own summaries"
    on public.monthly_summaries
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can insert own profile"
    on public.profiles
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = id));
create policy "Users can update own profile"
    on public.profiles
    to {public}
    for UPDATE
    using ((( SELECT auth.uid() AS uid) = id));
create policy "Users can view own profile"
    on public.profiles
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = id));
create policy "Users can insert own report preferences"
    on public.report_preferences
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can update own report preferences"
    on public.report_preferences
    to {public}
    for UPDATE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own report preferences"
    on public.report_preferences
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own subscriptions"
    on public.subscriptions
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own theme purchases"
    on public.theme_purchases
    to {public}
    for SELECT
    using ((auth.uid() = user_id));
create policy "Authenticated users can view themes"
    on public.themes
    to {public}
    for SELECT
    using ((auth.role() = 'authenticated'::text));
create policy "Users can insert own app access"
    on public.user_app_access
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own app access"
    on public.user_app_access
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can insert own settings"
    on public.user_settings
    to {public}
    for INSERT
    with check ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can update own settings"
    on public.user_settings
    to {public}
    for UPDATE
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own settings"
    on public.user_settings
    to {public}
    for SELECT
    using ((( SELECT auth.uid() AS uid) = user_id));
create policy "Users can view own themes"
    on public.user_themes
    to {public}
    for SELECT
    using ((auth.uid() = user_id));


