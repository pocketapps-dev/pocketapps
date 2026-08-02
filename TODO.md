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

## Tarefa C — Páginas legais ✅ COMPLETA
- [x] Rascunhos em `docs/legal/` (termos-de-servico.md, politica-de-privacidade.md)
- [x] Páginas `/terms` e `/privacy` publicadas no site (repo `pocketapps-dev/pocketapps.github.io`):
  - `terms.html` e `privacy.html` com o mesmo estilo/estrutura do index
  - CSS legal (`.legal-section`, `.legal-container`, `.legal-table`) em `style.css`
  - Rodapé do `index.html` com link para `/terms`
- [x] Verificado online: `https://pocketapps.pt/terms` e `https://pocketapps.pt/privacy` (HTTP 200)

## Tarefa D — Infraestrutura de email ✅ COMPLETA
- [x] Senders Brevo ativos (no-reply, suporte, billing, marketing) + domínio `pocketapps.pt` autenticado e verificado
- [x] DNS verificado: SPF `brevo-code:cdb0ba6a2afcc66ecd2dec927c68e1a9`, DKIM `brevo1`/`brevo2._domainkey`, DMARC `p=none`
- [x] `replyTo` adicionado às funções SMTP (`send-welcome-email`, `send-monthly-report`, `delete-account`), default `suporte@pocketapps.pt`
- [x] Deploy via MCP: `send-welcome-email` v44, `send-monthly-report` v6, `delete-account` v44, `report-unsubscribe` v2
- [x] `docs/emails.md` criado (arquitetura, senders, DNS, funções, secrets, estado do Email Routing)
- [ ] (utilizador) Definir secrets: `supabase secrets set SMTP_HOST=... SMTP_PORT=587 SMTP_USER=... SMTP_PASS=... SMTP_FROM=no-reply@pocketapps.pt SMTP_REPLY_TO=suporte@pocketapps.pt`
- [x] Script `scripts/cloudflare-email-routing.ps1` criado (API REST Cloudflare: ativar routing, criar 4 destinos Gmail + rotas, validação final)
- [ ] (utilizador) Configurar Cloudflare Email Routing: preencher token/IDs no script e executá-lo (4 destinos Gmail + rotas `geral@`, `suporte@`, `billing@`, `marketing@`) + confirmar os emails de verificação dos destinos

