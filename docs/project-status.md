# PocketApps — Estado Global do Projeto

> Resumo completo do monorepo: o que existe, o que está em progresso e o que falta.
> Atualizado em 2026-08-10.

## 1. Visão geral

| | |
|---|---|
| **Nome** | PocketApps — suite de apps pessoais |
| **Apps** | PocketExpenses (despesas), PocketFuel (combustível), PocketShopping (compras) |
| **Stack** | Flutter (Dart ^3.12.2) · Supabase (Postgres + Edge Functions + Auth) |
| **Org** | `pocketapps-dev` |
| **Repos** | `pocketapps.git` (código) · `pocketapps.github.io.git` (site) |
| **Branch** | `main` (ambos) |

## 2. Estrutura do monorepo (`pocketapps`)

```
apps/
  pocket_expenses/        → App ATIVA (única com implementação completa)
  pocket_fuel/            → Stub (esqueleto)
  pocket_shopping/        → Stub (esqueleto)
packages/
  pocketapps_auth/        → Auth partilhada (Supabase + Google)
supabase/
  schema.sql              → Fonte de verdade do schema (todas as apps)
  migrations/             → 001_themes.sql, 002_report_type.sql, 003_founder_count.sql, 004_light_dark_themes.sql, 005_theme_brightness.sql, 006_remove_default_theme.sql
  functions/              → 5 Edge Functions (Deno)
docs/
  auth.md                 → Autenticação (Supabase Auth + Google, setup no dashboard)
  backend.md              → Backend Supabase: schema, RPCs, edge functions, email transacional
  site.md                 → Site institucional (pocketapps.github.io)
  monetizacao-stripe.md   → Monetização/Stripe: planos, fases, estado (8 passos)
  legal/                  → termos-de-servico.md, politica-de-privacidade.md, play-store-data-safety.md
  project-status.md       → Este documento (índice global)
pocketapps.github.io/     → Repo separado do site (git-ignored no main)
.github/workflows/        → build-expenses.yml, build-fuel.yml, build-shopping.yml
scripts/
  cloudflare-email-routing.ps1
TODO.md                   → Tarefas A/B/C concluídas
```

## 3. Estado das apps

| App | Estado | Stack partilhada |
|---|---|---|
| **pocket_expenses** | ✅ Ativa — app completa em `lib/features/{calendar,categories,expenses,home,profile,settings,summary}` + `core/{models,providers,services,config}` | `pocketapps_auth` |
| **pocket_fuel** | 🟡 Stub — só esqueleto (`pubspec` + `main.dart` mínimo) | — |
| **pocket_shopping** | 🟡 Stub — só esqueleto | — |

**pocket_expenses** (app principal):
- Auth Supabase (email/password + Google) com fluxo completo (callback, reset password, mudar email/password, apagar conta).
- Gestão de despesas recorrentes/únicas, categorias, resumo mensal, calendário, temas.
- **Loja de temas (2026-08-04)**: página `/settings/themes` alimentada pelo RPC `get_user_themes` — secções Grátis (Light, Dark) / **TEMAS PAGOS** (todos os não-gratuitos: Premium Midnight, Forest, Sunset + Ocean, Autumn, Galaxy 0,99€, compra no site `themes.html`) + ativação de código de tema. Desde 2026-08-10 tocar num tema premium abre um diálogo ("Ver planos" → `/settings/plans` ou "Obter no site" → `themes.html`); temas pagos abrem a loja diretamente. Desde 2026-08-09 cada tema define a luminosidade da app (light/dark) e o tema `default` foi removido (migration `006_remove_default_theme.sql`).
- Relatórios mensais por email (`report_settings_page` + `report_provider`/`report_service`). Desde 2026-08-10 o **relatório de teste escolhe o mês** (diálogo com grelha de meses + ano) e o relatório `detailed` inclui a **lista completa "Despesas do mês"** (nome, categoria, tipo, valor).
- Plataformas de destino: Android (APK gerado em CI). `version: 1.0.0+1`.

## 4. Backend Supabase

**Projeto remoto**: `https://vlbhnlzqixmxtlpqsggd.supabase.co` — APP_NAME `expenses`.

### Schema (`schema.sql`, ~39 KB) — tabelas
`profiles`, `user_app_access`, `categories`, `expenses`, `monthly_status`, `subscriptions`, `user_settings`, `monthly_summaries`, `activation_codes`, `report_preferences` + **monetização**: `themes`, `user_themes`, `theme_purchases`. RLS ativado nas tabelas principais. Índices optimizados por `user_id`/`app_name`.

### RPCs / Funções
- Auth/usuário: `handle_new_user` (trigger `on_auth_user_created`), `check_username_available`, `get_email_by_username`.
- Acesso: `check_app_access`, `add_app_access`.
- Despesas: `get_or_create_monthly_status`, `toggle_expense_paid`, `toggle_expense_skip`, `confirm_expense_amount`, `get_effective_amount`.
- Relatórios: `archive_monthly_summary`, `cleanup_old_data`.
- Códigos: `validate_activation_code`.
- Monetização (2026-08-08): `get_founder_count` — RPC pública que devolve o nº de founders registados; consumida pela página de planos para mostrar o desconto Founder 50% OFF (`founder_count < 5`).
- Temas: `get_user_themes` (desde 2026-08-09 devolve também a coluna `brightness` do tema), `validate_theme_activation_code`, `grant_theme_to_user`.
- Trigger genérico `update_updated_at` em profiles/expenses/subscriptions/user_settings/report_preferences.

### Migrations
| Migration | Conteúdo | Estado |
|---|---|---|
| `001_themes.sql` | 3 tabelas (themes, user_themes, theme_purchases) + 3 RPCs + 7 temas seed + unique constraint | ✅ Aplicada e verificada no remoto (`20260803051308`) |
| `002_report_type.sql` | `report_preferences.report_type` (`simple`/`detailed`) | ✅ Aplicada e verificada no remoto (`20260803043706`) |
| `003_founder_count.sql` | RPC pública `get_founder_count()` | ✅ No schema (`supabase/schema.sql`) |
| `004_light_dark_themes.sql` | Temas gratuitos `Light` e `Dark` (app `expenses`) | ✅ Aplicada no remoto |
| `005_theme_brightness.sql` | Coluna `themes.brightness` + default/constraint + `get_user_themes` com `brightness` | ✅ Aplicada no remoto |
| `006_remove_default_theme.sql` | Desativa o tema `default` (`is_active=false`) — fora do catálogo e da validação de códigos | ✅ Aplicada no remoto |
| `007_themes_order_free_first.sql` | Renumera `sort_order` dos temas (gratuitos `light`/`default`/`dark` primeiro) + `get_user_themes` com ordenação free-first | ✅ Aplicada no remoto |

### Edge Functions (5)
`delete-account`, `report-unsubscribe`, `send-monthly-report` (relatório mensal, usa `report_type`), `send-welcome-email`, `stripe-webhook` (payment link webhook — **não deployado ainda**, usa env vars `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` + SMTP Brevo).

### Email transacional
- Relay SMTP: **`smtp-relay.brevo.com`** (Brevo), from padrão `no-reply@pocketapps.pt`.
- Documentado em [`docs/backend.md`](backend.md) (secção "Email transacional").
- **Supabase Auth custom SMTP** ✅ configurado e **verificado com envio real** (2026-08-03): magic link/OTP do site chega à inbox. Causa do problema anterior: `smtp_user` errado (email da conta em vez do login SMTP do Brevo).
- **Relatório mensal** ✅ (2026-08-10): fix do cron — o `send-monthly-report` tratava a `service_role` do cron como JWT de utilizador (`getUser()` → 403 → 401, nada enviava); agora o batch só entra com service role e o modo utilizador só com JWT validado (deploy v16). Diagnóstico de entrega: SPF/DKIM/DMARC/MX/verificação Brevo todos corretos; o *silent drop* temporário do Gmail (rajada de envios de teste) resolveu-se sozinho — ver [`backend.md`](backend.md#agendamento-do-relatrio-pgcron).
- **Relatório — gráficos + PDF** ✅ (2026-08-10): `include_charts` passa a mostrar barras reais por categoria (com a cor de cada categoria) + barra "Recorrentes vs únicas" no email; o email passa a incluir **PDF em anexo** (`pdf-lib`, Deno). Na app, fix de persistência dos toggles (`report_settings_page.dart` lê o valor em cache no `initState` — o Riverpod 3.3.2 não tem `fireImmediately`).

## 5. Site (`pocketapps.github.io` — repo separado)

Páginas: `index.html`, `apps.html`, `features.html`, `pricing.html`, `themes.html`, `contact.html`, `ativar.html`, `terms.html`, `privacy.html` + `style.css` (27 KB) + `layout.js`. Diretório `apk/` aloja o APK (atualizado automaticamente por CI).

Auth no site (2026-08-03, tudo publicado e verificado no ar):
- **Homepage (`index.html`)**: login/signup por email/palavra-passe + Google, espelhando o auth do app (RPCs partilhados, metadados de consentimento, confirmação por email). Depois de entrar fica na homepage com a barra de sessão.
- **`themes.html` / `pricing.html`**: magic link funcional — bug `SyntaxError: Identifier 'supabase' has already been declared` (conflito com o global do UMD do CDN) corrigido com o rename `supabaseClient` (commit `d6f9839`).
- Login/signup na homepage: commit `8dfb41e`.

Estado git do site: commits `d6f9839` (fix magic link) e `8dfb41e` (login/signup homepage) já pushados.

## 6. CI/CD (`.github/workflows`)

| Workflow | Função |
|---|---|
| `build-expenses.yml` | Build APK PocketExpenses → **release GitHub com APK** + **auto-sync APK para o repo do site** |
| `build-fuel.yml` | Build APK PocketFuel |
| `build-shopping.yml` | Build APK PocketShopping |

Pipeline funcionando (commits recentes `dce2886`, `75d7617`).

## 7. Monetização — resumo executivo

Documento completo: [`docs/monetizacao-stripe.md`](monetizacao-stripe.md).

- **Planos (decisão 2026-08-08)**: Free por conta (todas as apps) · Premium 1,49€/mês · 14,99€/ano — **todas as apps** (1 SKU) · Founder 25€/app (3 apps = 75€; 50% no total só p/ 1ºs 5 = 37,50€; máx. 25 pessoas, só em desenvolvimento) · Temas à la carte 0,99€/tema por conta. Preços base **sem IVA** ("+ IVA" no site, aplicado no checkout — OSS por país do cliente). Gateway/faturação ainda em estudo — ver [`docs/monetizacao-stripe.md`](monetizacao-stripe.md).
- **Passo 1 (temas/loja)** ✅ feito (migration + webhook) — ver acima.
- **Passos 2–3** ✅: email provider + confirm email + **custom SMTP corrigido** (OTP chega à inbox); redirects e **Site URL** `https://pocketapps.pt` corrigidos (2026-08-03). Magic link do site a funcionar após fix do `SyntaxError` (rename `supabaseClient`, commit `d6f9839`); homepage com login/signup email/password + Google (commit `8dfb41e`).
- **Passos 4–8** 🔴 **bloqueados**: dashboard da Stripe em baixo (erro do lado da Stripe) — impede criar 6 Payment Links, deploy do `stripe-webhook`, colocar links reais e substituir botões mock.
- **Botões mock**: `buy.stripe.com/TODO_*` → decisão de 2026-08: botões **"Comprar" desativados** com labels dinâmicos do `config.js` em `pricing.html` (ex.: "Comprar Premium · €14.99/ano"); `themes.html` mantém "Em breve" (`.btn-buy` em `style.css`).

## 8. WIP neste commit (2026-08-08)

- **Novo modelo de planos na app** (PocketExpenses): página de planos (`plans_page.dart`) mostra Premium `€14.99/ano` e Founder **total das 3 apps** — `€37,50` (50% OFF) ou `€75`; `founderCountProvider` (`subscription_provider.dart`) lê a RPC `get_founder_count()` e ativa o desconto enquanto `founder_count < 5`; banner do dashboard `€14.99/ano`; termos atualizados em `about_page.dart`.
- **Fluxo de planos app → site** (commit `7cb7bd8`): card de topo de Definições (`settings_page.dart`) e `_PlanCard` da Conta (`account_page.dart`) navegam para `/settings/plans`; botão "Comprar no website" em `plans_page.dart` abre `https://pocketapps.pt/pricing.html`. No site, `pricing.html` (repo `pocketapps.github.io`) mostra botões "Comprar" desativados com labels dinâmicos do `config.js` (ex.: "Comprar Premium · €14.99/ano", "Comprar Founder · €37.50").
- Docs: `003_founder_count.sql` + RPC `get_founder_count` registados em `backend.md`/`project-status.md`; nota da app em `monetizacao-stripe.md`; fluxo app → site e labels do pricing em `site.md`/`monetizacao-stripe.md`.
- **Brilho por tema (2026-08-09)**: cada tema define a luminosidade da app — coluna `themes.brightness` (`light`/`dark`) na migration `005_theme_brightness.sql` (backfill + default + constraint) e devolvida por `get_user_themes`; `ThemeInfo.brightness` usada em `themes_page.dart`; `theme_provider.setMode()` substitui o toggle manual de dark mode (removido de `preferences_page.dart`); `main.dart` deriva o `themeMode` do tema ativo (fallback `AppTheme.light`). Migrations `004_light_dark_themes.sql` (temas Light/Dark gratuitos), `005` e `006_remove_default_theme.sql` (desativação do tema `default`, fora do catálogo e da validação de códigos) aplicadas no remoto.
- `flutter analyze`: ✅ sem issues.

### Fixes app → site (este commit)

- **Bug app (botão não abria o link)**: `_openUrl(BuildContext, String)` em `plans_page.dart`, `about_page.dart` e `legal_page.dart` estava gateado por `canLaunchUrl()`, que devolve `false` para `https` em muitos emuladores/simuladores e falhava **silenciosamente** (sem reencaminhar nem avisar). Corrigido: `launchUrl(uri, mode: LaunchMode.externalApplication)` direto com try/catch + SnackBar "Não foi possível abrir o link. Tenta novamente.".
- **Bug web (pricing sem botões "Comprar")**: `pricing.html` carregava `config.js` com `defer`, mas o script inline lê `window.POCKETAPPS_CONFIG` **sincronamente** → `CONFIG` era `undefined` → `TypeError` matava todo o script (sem botões comprar, sem countdown founder, sem redirect de auth). Corrigido: `defer` removido, `config.js` mantém-se na `<head>` antes do SDK Supabase.
- `flutter analyze`/`dart analyze` excederam timeout nesta máquina (180s/300s) — análise estática não validada localmente; compilação confirmada pelo build (este commit).

`devtools_options.yaml` (local) — não commitar. `supabase/migrations/` e `supabase/functions/stripe-webhook/` já aplicados no remoto (commit `a6c2740`).

## 9. O que falta / próximo

| # | Item | Estado |
|---|---|---|
| 1 | Migration `002_report_type.sql` aplicar no remoto | ✅ feito (verificada) |
| 2 | Dashboard Supabase: email provider + confirm email + **custom SMTP** | ✅ feito (SMTP corrigido e verificado) |
| 3 | Dashboard Supabase: redirect URLs + Site URL | ✅ feito — allowlist + Site URL `https://pocketapps.pt` (2026-08-03) |
| 4–8 | Stripe: Payment Links + deploy webhook + links reais + botões | 🔴 bloqueado (Stripe em baixo) |
| 9 | Botões mock → "Em breve" (decisão tomada) | ⏳ falta aplicar no site |
| 10 | Commit do WIP (relatório tipo + temas no schema + reorg de docs) | ✅ feito (commits `a6c2740`, `9253aba`, este) |
| 11 | Remover `index.ts` órfão da raiz | ✅ removido localmente (sem commit) |
| 12 | Apps Fuel e Shopping: passar de stub para implementação | 🟡 futuro |
| 13 | Fases de monetização no produto (anúncios, gates, widgets, wizard) | 🟡 ver `monetizacao-stripe.md` |
| 14 | Site: magic link não enviava (SyntaxError do CDN) + allowlist `/themes` `/pricing` | ✅ corrigido (2026-08-03, commit `d6f9839`) |
| 15 | Site: login/signup por email/password + Google na homepage | ✅ feito (2026-08-03, commit `8dfb41e`) |
| 16 | App: loja de temas (`/settings/themes` via `get_user_themes`) | ✅ feito (2026-08-04, commit `7eeb809`) |
| 17 | App: botão "Comprar no website" não reencaminhava (`canLaunchUrl` falhava silenciosamente) | ✅ corrigido (este commit — `launchUrl` direto + SnackBar) |
| 18 | Site: `pricing.html` sem botões "Comprar" (`config.js` carregado com `defer`, script corria antes) | ✅ corrigido (este commit — `defer` removido) |
| 19 | App: brilho por tema (light/dark) — tema ativo controla o `themeMode` | ✅ feito (2026-08-09) |
| 20 | App: relatório de teste com escolha de mês + lista "Despesas do mês" no `detailed` + fix valores vazios (`s > now`) | ✅ feito (2026-08-10) |

## 10. Notas de manutenção

- As páginas do site **não** são versionadas no repo principal (git-ignored); vivem no repo `pocketapps.github.io`.
- Migrations versionadas em `supabase/migrations/` (001–005) e aplicadas no remoto. `supabase/functions/stripe-webhook/` permanece untracked — não deployado (bloqueado pela Stripe).
- Alterações locais: CRLF warnings no git (não bloqueantes, só normalização).
