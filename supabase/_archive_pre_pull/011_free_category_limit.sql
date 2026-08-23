create or replace function public.enforce_free_category_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
      raise exception 'Limite do plano Free atingido: máximo de 10 categorias. Subscreve o Premium para categorias ilimitadas.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_free_category_limit on public.categories;
create trigger trg_enforce_free_category_limit
before insert on public.categories
for each row execute function public.enforce_free_category_limit();
