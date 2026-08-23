-- ============================================================
-- Migration: Light and Dark free themes
-- Adds: 'light' and 'dark' themes for PocketExpenses
-- These force the app brightness when applied (handled client-side)
-- ============================================================

insert into public.themes (app_name, theme_key, name, description, price_cents, seed_color, is_premium, is_paid, is_active, sort_order) values
  ('expenses', 'light', 'Light', 'Força o modo claro.',   0,  '#6366F1', false, false, true, 8),
  ('expenses', 'dark',  'Dark',  'Força o modo escuro.',  0,  '#6366F1', false, false, true, 9)
on conflict (app_name, theme_key) do nothing;
