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
- [x] Deploy via MCP: `send-welcome-email` v44, `send-monthly-report` v6, `delete-account` v44, `report-unsubscribe` v2 (deploys atuais confirmados: v46/v9/v46/v4 — ver `docs/backend.md`)
- [x] `docs/backend.md` criado (arquitetura, senders, DNS, funções, secrets, estado do Email Routing) — consolida o antigo `docs/emails.md`
- [x] Secrets das edge functions ✅ (2026-08-03, via Management API): `SMTP_USER=b3d20e001@smtp-brevo.com` (login SMTP, não email da conta) + `SMTP_PASS=<xsmtpsib>` confirmados por hash; adicionado `SMTP_REPLY_TO=suporte@pocketapps.pt`
- [x] **Supabase Auth custom SMTP** ✅ (2026-08-03, via Management API): login `b3d20e001@smtp-brevo.com` + SMTP key, sender `PocketApps <no-reply@pocketapps.pt>` — magic link/OTP do site verificado com envio real (antes: `smtp_user` errado → `535`, nada chegava)
- [x] Script `scripts/cloudflare-email-routing.ps1` criado (API REST Cloudflare: ativar routing, criar 4 destinos Gmail + rotas, validação final)
- [x] **Relatório mensal fix** (2026-08-10): cron enviava `service_role` no `Authorization` → `getUser()` 403 → 401 (nada enviava). `send-monthly-report` v16: batch só com service role; modo utilizador só com JWT validado. Incidente de entrega Gmail (silent drop temporário após rajada de testes) resolveu-se sozinho — ver `docs/backend.md`
- [ ] (utilizador) Configurar Cloudflare Email Routing: preencher token/IDs no script e executá-lo (4 destinos Gmail + rotas `geral@`, `suporte@`, `billing@`, `marketing@`) + confirmar os emails de verificação dos destinos

## Tarefa E — Auth no site ✅ COMPLETA (2026-08-03)
- [x] **Supabase Auth custom SMTP** funcional — magic link/OTP do site entrega na inbox (causa anterior: `smtp_user` errado)
- [x] Fix **magic link não enviava**: `SyntaxError: Identifier 'supabase' has already been declared` (conflito com o `var supabase` global do UMD do CDN `supabase-js@2`) → rename `supabaseClient` em `themes.html`/`pricing.html` (commit `d6f9839`)
- [x] Allowlist de redirects: adicionar URLs canónicas `https://pocketapps.pt/themes` e `/pricing` (Cloudflare 307 perde fragmento `#access_token`)
- [x] Homepage (`index.html`): **login/signup por email/palavra-passe + Google**, espelha o `AuthPage`/`auth_service.dart` do app (RPCs `check_app_access`/`add_app_access`, metadados de consentimento, confirmação por email) (commit `8dfb41e`)
- [x] Verificado no ar (2026-08-03): envio do magic link + mensagens de sucesso/erro + login homepage

## Tarefa F — Loja de temas na app ✅ COMPLETA (2026-08-04)
- [x] 1. `core/models/theme_info.dart` (novo): model do catálogo (`theme_key`, `name`, `description`, `price_cents`, `seed_color`, `is_premium`, `is_paid`, `sort_order`, `available`, `purchased`) + `seedColor`/`priceLabel`
- [x] 2. `core/services/theme_store_service.dart` (novo): chama `get_user_themes` (catálogo + disponibilidade) e `validate_theme_activation_code` (redeem de código)
- [x] 3. `core/providers/theme_store_provider.dart` (novo): `themeStoreProvider` (FutureProvider) + `themeStoreActionsProvider.redeemThemeCode`
- [x] 4. `features/settings/themes_page.dart` (novo): página dedicada com secções **Grátis** (Default) / **Premium** (Midnight, Forest, Sunset — banner "Ver planos" se não for premium) / **Pagos** (Ocean, Autumn, Galaxy 0,99€ — compra abre `https://pocketapps.pt/themes.html`) + "Ativar código de tema"
- [x] 5. `config/router.dart`: rota `/settings/themes`; `preferences_page.dart`: "Temas" navega para a página (removido picker de diálogo com lista hardcoded)
- [x] 6. `config/theme.dart`: seeds `autumn`/`galaxy` + `getThemeFromSeed`; `availableThemes` alinhado com o catálogo (removido 'Purple' do código antigo)
- [x] 7. `flutter analyze` limpo (0 issues)
- [x] 8. Commit + push (este commit)

## Tarefa G — Relatório mensal: mês no teste + lista de despesas ✅ COMPLETA (2026-08-10)
- [x] 1. App `report_settings_page.dart`: "Enviar relatório de teste" abre diálogo de escolha de mês (grelha 12 meses + navegação de ano); SnackBar confirma o mês enviado
- [x] 2. App `report_provider.dart`/`report_service.dart`: `sendTest`/`sendTestReport` aceitam `month` (`"YYYY-MM"`) e enviam no body da edge function
- [x] 3. Edge function `send-monthly-report`: novo `parseMonthParam` + `body.month` no modo teste (default = mês atual); batch inalterado
- [x] 4. Edge function: fix de valores vazios — removido `if (s > now) return false` em `occursInMonth` (excluía recorrentes com `start_date` futuro dentro do mês)
- [x] 5. Edge function: `fetchReportData` devolve `items` (despesas do mês) e o relatório `detailed` ganha a secção "Despesas do mês" (nome, categoria, tipo + quando, valor; ordenada por valor; `escapeHtml`)
- [x] 6. `flutter analyze` limpo (0 issues)
- [x] 7. Docs atualizados (`backend.md`, `project-status.md`) + commit/push
- [ ] (pendente) Deploy da edge function `send-monthly-report` (v9 → v10) no Supabase para ativar o `body.month`/lista de despesas/fix em produção

