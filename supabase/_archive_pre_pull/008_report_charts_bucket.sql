-- Bucket público para hospedar os gráficos dos relatórios mensais por email
insert into storage.buckets (id, name, public)
values ('report-charts', 'report-charts', true)
on conflict (id) do nothing;
