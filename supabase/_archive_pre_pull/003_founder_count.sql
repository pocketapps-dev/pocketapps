-- Public founder count RPC for the pricing page.
-- RLS on subscriptions hides rows from anon, so this runs as definer.
create or replace function public.get_founder_count()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(distinct user_id)::int
  from public.subscriptions
  where plan = 'founder' and status = 'active';
$$;

revoke all on function public.get_founder_count() from public;
grant execute on function public.get_founder_count() to anon, authenticated, service_role;
