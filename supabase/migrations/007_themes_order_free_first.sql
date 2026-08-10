-- ============================================================
-- 007_themes_order_free_first.sql
-- Reorder themes so free themes appear first, then premium,
-- then paid. Adjusts the sort_order column (introduced as
-- light=8/dark=9 in 004) to the current production order and
-- updates get_user_themes to order free-first.
-- ============================================================

update public.themes
set sort_order = case theme_key
    when 'light'    then 1
    when 'default'  then 1
    when 'dark'     then 2
    when 'midnight' then 3
    when 'forest'   then 4
    when 'sunset'   then 5
    when 'ocean'    then 6
    when 'autumn'   then 7
    when 'galaxy'   then 8
    else sort_order
  end
where app_name = 'expenses';

-- Get all themes available to the current user, free themes first
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
$$ security definer
  set search_path = public;
