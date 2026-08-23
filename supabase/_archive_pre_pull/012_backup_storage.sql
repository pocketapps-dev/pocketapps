insert into storage.buckets (id, name, public)
values ('backups', 'backups', false)
on conflict (id) do nothing;

drop policy if exists "users_read_own_backups" on storage.objects;
create policy "users_read_own_backups"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users_delete_own_backups" on storage.objects;
create policy "users_delete_own_backups"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

select cron.unschedule('daily-backups')
where exists (select 1 from cron.job where jobname = 'daily-backups');

select cron.schedule(
  'daily-backups',
  '0 3 * * *',
  $$
  select net.http_post(
    url := 'https://vlbhnlzqixmxtlpqsggd.supabase.co/functions/v1/create-daily-backups',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret
                                      from vault.decrypted_secrets
                                     where name = 'service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'
  )
  $$
);
