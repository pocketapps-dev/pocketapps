-- ============================================================
-- Migration: Monthly Report Type Preference
-- Adds: report_preferences.report_type (simple / detailed)
-- Used by: send-monthly-report Edge Function + PocketExpenses settings
-- ============================================================

-- ============================================================
-- REPORT TYPE (which format the monthly email report uses)
-- 'simple'   -> header + stats row (Total/Recorrentes/Únicas/Despesas) + CTA
-- 'detailed' -> also includes category breakdown and charts (default)
-- ============================================================
alter table public.report_preferences
  add column if not exists report_type text not null default 'detailed'
  check (report_type in ('simple', 'detailed'));
