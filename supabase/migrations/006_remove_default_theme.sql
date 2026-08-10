-- ============================================================
-- 006: Remove Default theme
-- Deactivates the legacy 'default' theme for PocketExpenses.
-- Legacy clients storing 'Default'/'default' are normalized to
-- 'Light' client-side; this removes it from get_user_themes and
-- validate_theme_activation_code (both filter is_active = true).
-- ============================================================

update public.themes
set is_active = false
where app_name = 'expenses'
  and theme_key = 'default';
