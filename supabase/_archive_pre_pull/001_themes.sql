-- ============================================================
-- Migration: Theme Store System
-- Adds: themes catalog, user_themes, theme_purchases
-- Extends: activation_codes with theme_key
-- Functions: validate_theme_activation_code, get_user_themes
-- ============================================================

-- ============================================================
-- 10. THEMES (catalog of available themes)
-- ============================================================
create table if not exists public.themes (
  id          uuid primary key default gen_random_uuid(),
  app_name    text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  theme_key   text not null,                    -- 'default', 'ocean', 'forest', etc.
  name        text not null,                    -- 'Ocean', 'Forest', etc.
  description text,
  price_cents integer not null default 0,       -- 0 = free, 99 = 0,99€
  seed_color  text not null,                   -- '#0EA5E9'
  is_premium  boolean not null default false,   -- included with Premium subscription?
  is_paid     boolean not null default false,   -- requires one-time purchase?
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  unique(app_name, theme_key)
);

-- ============================================================
-- 11. USER THEMES (which themes each user has access to)
-- ============================================================
create table if not exists public.user_themes (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  app_name     text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  theme_key    text not null,
  source       text not null default 'purchase' check (source in ('purchase', 'premium', 'gift', 'activation_code')),
  purchased_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique(user_id, app_name, theme_key)
);

-- ============================================================
-- 12. THEME PURCHASES (audit log for theme purchases)
-- ============================================================
create table if not exists public.theme_purchases (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  app_name         text not null check (app_name in ('expenses', 'fuel', 'shopping')),
  theme_key        text not null,
  amount_cents     integer not null,
  payment_provider text,                                        -- 'stripe', 'paypal', 'activation_code', 'manual'
  payment_ref      text,                                        -- Stripe payment intent ID, etc.
  status           text not null default 'completed' check (status in ('pending', 'completed', 'refunded')),
  created_at        timestamptz not null default now()
);

-- ============================================================
-- EXTEND ACTIVATION CODES FOR THEMES
-- ============================================================
-- Add theme_key column (nullable: if set, code activates a theme instead of a subscription)
alter table public.activation_codes add column if not exists theme_key text;

-- Update the plan check constraint to allow null plan for theme codes
-- (theme codes don't have a plan, they have a theme_key)
-- Note: We keep the existing constraint but allow plan to be null when theme_key is set
alter table public.activation_codes drop constraint if exists activation_codes_plan_check;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'activation_codes_plan_check'
      and conrelid = 'public.activation_codes'::regclass
  ) then
    alter table public.activation_codes add constraint activation_codes_plan_check
      check (
        (theme_key is not null) or
        (plan is not null and plan in ('premium', 'founder'))
      );
  end if;
end $$;

-- Make plan nullable (for theme codes that don't have a plan)
alter table public.activation_codes alter column plan drop not null;

-- ============================================================
-- INDEXES FOR THEME TABLES
-- ============================================================
create index if not exists idx_themes_app on public.themes(app_name);
create index if not exists idx_themes_app_active on public.themes(app_name) where is_active = true;
create index if not exists idx_user_themes_user on public.user_themes(user_id);
create index if not exists idx_user_themes_user_app on public.user_themes(user_id, app_name);
create index if not exists idx_theme_purchases_user on public.theme_purchases(user_id);
create index if not exists idx_theme_purchases_user_theme on public.theme_purchases(user_id, theme_key);
create index if not exists idx_activation_codes_theme on public.activation_codes(theme_key) where theme_key is not null;

-- ============================================================
-- ROW LEVEL SECURITY FOR THEME TABLES
-- ============================================================
alter table public.themes enable row level security;
alter table public.user_themes enable row level security;
alter table public.theme_purchases enable row level security;

-- THEMES: all authenticated users can view the catalog
create policy "Authenticated users can view themes"
  on public.themes for select using (auth.role() = 'authenticated');

-- USER THEMES: users can view their own themes
create policy "Users can view own themes"
  on public.user_themes for select using (auth.uid() = user_id);

-- THEME PURCHASES: users can view their own purchase history
create policy "Users can view own theme purchases"
  on public.theme_purchases for select using (auth.uid() = user_id);

-- Note: Inserts/updates to user_themes and theme_purchases are done
-- exclusively via service_role (Edge Functions) or security definer functions

-- ============================================================
-- SEED DATA: Themes catalog for PocketExpenses
-- ============================================================
insert into public.themes (app_name, theme_key, name, description, price_cents, seed_color, is_premium, is_paid, is_active, sort_order) values
  ('expenses', 'default', 'Default',  'Tema padrão indigo.',           0,  '#6366F1', false, false, true, 1),
  ('expenses', 'midnight','Midnight', 'Tema escuro elegante.',         0,  '#1E1B4B', true,  false, true, 2),
  ('expenses', 'forest',  'Forest',   'Tema verde natureza.',          0,  '#22C55E', true,  false, true, 3),
  ('expenses', 'sunset',  'Sunset',   'Tema quente e vibrante.',       0,  '#F97316', true,  false, true, 4),
  ('expenses', 'ocean',   'Ocean',    'Tema azul oceano.',             99, '#0EA5E9', false, true,  true, 5),
  ('expenses', 'autumn',  'Autumn',   'Tema outono quente.',           99, '#EA580C', false, true,  true, 6),
  ('expenses', 'galaxy',  'Galaxy',   'Tema roxo galáxia.',            99, '#8B5CF6', false, true,  true, 7)
on conflict (app_name, theme_key) do nothing;

-- ============================================================
-- HELPER FUNCTIONS FOR THEMES
-- ============================================================

-- Get all themes available to the current user (free + premium if subscribed + purchased)
-- Returns: jsonb array of theme objects with an 'available' boolean
create or replace function public.get_user_themes(p_app_name text)
returns jsonb as $$
declare
  v_user_id uuid;
  v_has_premium boolean;
  v_result jsonb;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('error', 'Not authenticated');
  end if;

  -- Check if user has premium or founder subscription
  select exists(
    select 1 from public.subscriptions
    where user_id = v_user_id
      and app_name = p_app_name
      and plan in ('premium', 'founder')
      and status = 'active'
      and (ends_at is null or ends_at > now())
  ) into v_has_premium;

  -- Build the result: all themes with availability info
  select jsonb_agg(
    jsonb_build_object(
      'theme_key', t.theme_key,
      'name', t.name,
      'description', t.description,
      'price_cents', t.price_cents,
      'seed_color', t.seed_color,
      'is_premium', t.is_premium,
      'is_paid', t.is_paid,
      'sort_order', t.sort_order,
      'available',
        case
          when not t.is_premium and not t.is_paid then true  -- free theme
          when t.is_premium and v_has_premium then true       -- premium theme + user has premium
          when t.is_paid and exists(                          -- paid theme + user purchased it
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
    order by t.sort_order
  )
  into v_result
  from public.themes t
  where t.app_name = p_app_name
    and t.is_active = true;

  return coalesce(v_result, '[]'::jsonb);
end;
$$ language plpgsql security definer;

-- Grant execute to authenticated users
revoke execute on function public.get_user_themes(text) from public;
grant execute on function public.get_user_themes(text) to authenticated;

-- Validate a theme activation code and unlock the theme for the user
create or replace function public.validate_theme_activation_code(
  p_code text,
  p_app_name text
)
returns jsonb as $$
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
    return jsonb_build_object('valid', false, 'error', 'Código inválido');
  end if;

  -- Check expiry
  if v_code.expires_at is not null and v_code.expires_at < now() then
    return jsonb_build_object('valid', false, 'error', 'Código expirado');
  end if;

  -- Check usage limit
  if v_code.use_count >= v_code.max_uses then
    return jsonb_build_object('valid', false, 'error', 'Código totalmente utilizado');
  end if;

  -- Verify the theme exists and is active
  select * into v_theme
  from public.themes
  where app_name = p_app_name
    and theme_key = v_code.theme_key
    and is_active = true;

  if not found then
    return jsonb_build_object('valid', false, 'error', 'Tema não encontrado');
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
$$ language plpgsql security definer;

-- Grant execute to authenticated users
revoke execute on function public.validate_theme_activation_code(text, text) from public;
grant execute on function public.validate_theme_activation_code(text, text) to authenticated;

-- Grant a theme to a user (called by Edge Functions with service_role)
-- This is used by the Stripe webhook to unlock a purchased theme
create or replace function public.grant_theme_to_user(
  p_user_id uuid,
  p_app_name text,
  p_theme_key text,
  p_source text default 'purchase',
  p_payment_provider text default 'stripe',
  p_payment_ref text default null,
  p_amount_cents integer default 99
)
returns jsonb as $$
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
    return jsonb_build_object('success', false, 'error', 'Tema não encontrado');
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
$$ language plpgsql security definer;

-- Only service_role can call grant_theme_to_user (used by Edge Functions)
revoke execute on function public.grant_theme_to_user(uuid, text, text, text, text, text, integer) from public;
grant execute on function public.grant_theme_to_user(uuid, text, text, text, text, text, integer) to service_role;