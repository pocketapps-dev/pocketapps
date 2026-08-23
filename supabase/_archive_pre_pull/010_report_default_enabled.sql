-- 010: relatório mensal ativo por defeito
-- - email_reports_enabled passa a default true (novas linhas nascem ativas)
alter table public.report_preferences
  alter column email_reports_enabled set default true;
