-- Simplificar preferências de relatório:
-- - include_categories / include_charts removidos (relatório detalhado inclui sempre)
-- - report_type passa a toggle simples/detalhado (feature premium)
-- - report_day + report_hour mantidos (apresentados como campo único na app, premium)

alter table public.report_preferences
  drop column if exists include_categories,
  drop column if exists include_charts;
