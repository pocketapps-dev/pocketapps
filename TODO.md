# TODO — Plano de Execução

## Tarefa A — Exportação de Dados (Portabilidade RGPD art. 20.º) ✅ COMPLETA
- [x] 1. pubspec.yaml: adicionar `share_plus` + `csv`
- [x] 2. `core/services/export_service.dart` (novo):
  - `fetchAllData()` → expenses (join categories), categories, subscriptions, report_preferences, monthly_status
  - `buildJson()` (tudo) + `buildCsv()` (expenses + categories)
- [x] 3. `core/providers/export_provider.dart` (novo): `ExportActions.exportJson()/exportCsv()` → ficheiro em `getTemporaryDirectory()` + share sheet
- [x] 4. `features/settings/export_data_page.dart` (novo): 2 botões (JSON/CSV) + loading/erro
- [x] 5. `config/router.dart`: rota `/settings/export`
- [x] 6. `settings_page.dart`: atalho "Exportar dados" na secção CONTA
- [x] 7. Correr `flutter analyze` + `flutter test` (app + package)

## Tarefa Extra — Fix categorias default ✅ COMPLETA
- [x] 1. Migração `drop_seed_default_categories_rpc` (drop da RPC órfã)
- [x] 2. Atualizar seed data do `schema.sql` para os nomes oficiais com acentos
- [x] 3. Garantir 'Sem Categoria' consistente em `findOrCreateUncategorized()`/`reorderCategories()` (já estava consistente — verificado)

## Tarefa B — Warnings de segurança Supabase ✅ COMPLETA
- [x] 1. Migração `revoke_anon_and_secure_rpc`: `REVOKE EXECUTE ... FROM anon/PUBLIC` em `add_app_access` (grant explícito authenticated+service_role); drop de `check_welcome_email_sent`
- [x] 2. `SET search_path = ''` em `get_email_by_username` + `check_username_available`
- [x] 3. Atualizar `schema.sql` em paralelo (incluiu criar as 2 funções ausentes no schema)

## Tarefa C — Páginas legais (BLOQUEADA no dono)
- [ ] Entregar rascunhos `docs/legal/` + documentar correções do site

