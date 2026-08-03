# PocketApps — Estado Global do Projeto

> Resumo completo do monorepo: o que existe, o que está em progresso e o que falta.
> Atualizado em 2026-08-03.

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
  migrations/             → 001_themes.sql, 002_report_type.sql
  functions/              → 5 Edge Functions (Deno)
docs/
  emails.md               → Modelos/conteúdo de emails transacionais
  monetizacao.md          → Estratégia de monetização (planos, fases, sprints)
  monetizacao-status.md   → Estado operacional da monetização (8 passos)
  legal/                  → termos-de-servico.md, politica-de-privacidade.md, play-store-data-safety.md
  project-status.md       → Este documento
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
- Relatórios mensais por email (`report_settings_page` + `report_provider`/`report_service`).
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
- Temas: `get_user_themes`, `validate_theme_activation_code`, `grant_theme_to_user`.
- Trigger genérico `update_updated_at` em profiles/expenses/subscriptions/user_settings/report_preferences.

### Migrations
| Migration | Conteúdo | Estado |
|---|---|---|
| `001_themes.sql` | 3 tabelas (themes, user_themes, theme_purchases) + 3 RPCs + 7 temas seed + unique constraint | ✅ Aplicada e verificada no remoto (`20260803051308`) |
| `002_report_type.sql` | `report_preferences.report_type` (`simple`/`detailed`) | ✅ Aplicada e verificada no remoto (`20260803043706`) |

### Edge Functions (5)
`delete-account`, `report-unsubscribe`, `send-monthly-report` (relatório mensal, usa `report_type`), `send-welcome-email`, `stripe-webhook` (payment link webhook — **não deployado ainda**, usa env vars `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` + SMTP Brevo).

### Email transacional
- Relay SMTP: **`smtp-relay.brevo.com`** (Brevo), from padrão `no-reply@pocketapps.pt`.
- `docs/emails.md` documenta templates/parâmetros.

## 5. Site (`pocketapps.github.io` — repo separado)

Páginas: `index.html`, `apps.html`, `features.html`, `pricing.html`, `themes.html`, `contact.html`, `ativar.html`, `terms.html`, `privacy.html` + `style.css` (27 KB) + `layout.js`. Diretório `apk/` aloja o APK (atualizado automaticamente por CI).

Estado git do site: `pricing.html`, `style.css` e `themes.html` têm **alterações por commitar** (preços/links da monetização).

## 6. CI/CD (`.github/workflows`)

| Workflow | Função |
|---|---|
| `build-expenses.yml` | Build APK PocketExpenses → **release GitHub com APK** + **auto-sync APK para o repo do site** |
| `build-fuel.yml` | Build APK PocketFuel |
| `build-shopping.yml` | Build APK PocketShopping |

Pipeline funcionando (commits recentes `dce2886`, `75d7617`).

## 7. Monetização — resumo executivo

Documento completo: `docs/monetizacao-status.md`.

- **Planos**: Free · Premium 1,49€/mês · Premium Anual 14,99€/ano · Founder 29,99€ (one-time, bundle 3 apps). Temas à la carte 0,99€.
- **Passo 1 (temas/loja)** ✅ feito (migration + webhook) — ver acima.
- **Passos 2–3** ⏳ ação manual no dashboard Supabase: ativar email provider + confirm email; configurar redirects `pt.pocketapps.pocket{expenses,fuel,shopping}://auth-callback`; Site URL `https://pocketapps.github.io`.
- **Passos 4–8** 🔴 **bloqueados**: dashboard da Stripe em baixo (erro do lado da Stripe) — impede criar 6 Payment Links, deploy do `stripe-webhook`, colocar links reais e substituir botões mock.
- **Botões mock**: `buy.stripe.com/TODO_*` → decisão de 2026-08: mostrar **"Em breve"** desativado enquanto não houver link real (`.btn-buy` em `style.css`, `pricing.html`, `themes.html`).

## 8. O que está em progresso (WIP não commitado)

Em `main` (repo principal):
- `report_provider.dart`, `report_service.dart`, `report_settings_page.dart` — feature *tipo de relatório* (simple/detailed).
- `supabase/schema.sql` (+276 linhas) — temas/loja + `report_type`.
- `supabase/functions/send-monthly-report/index.ts` — suporte a `report_type`.
- `docs/emails.md` — documentação de emails atualizada.

Ficheiros untracked relevantes: `supabase/functions/stripe-webhook/`, `supabase/migrations/` (ambos já aplicados no remoto), `docs/monetizacao-status.md`, `devtools_options.yaml` (local — não commitar), e **`index.ts` órfão na raiz** (só `// placeholder` — provavelmente para remover).

## 9. O que falta / próximo

| # | Item | Estado |
|---|---|---|
| 1 | Migration `002_report_type.sql` aplicar no remoto | ✅ feito (verificada) |
| 2 | Dashboard Supabase: email provider + confirm email | ⏳ manual |
| 3 | Dashboard Supabase: redirect URLs + Site URL | ⏳ manual |
| 4–8 | Stripe: Payment Links + deploy webhook + links reais + botões | 🔴 bloqueado (Stripe em baixo) |
| 9 | Botões mock → "Em breve" (decisão tomada) | ⏳ falta aplicar no site |
| 10 | Commit do WIP atual (relatório tipo + temas no schema) | 🔄 este commit |
| 11 | Remover `index.ts` órfão da raiz | ⏳ |
| 12 | Apps Fuel e Shopping: passar de stub para implementação | 🟡 futuro |
| 13 | Fases de monetização no produto (anúncios, gates, widgets, wizard) | 🟡 ver `monetizacao.md` |

## 10. Notas de manutenção

- As páginas do site **não** são versionadas no repo principal (git-ignored); vivem no repo `pocketapps.github.io`.
- `supabase/migrations/` e `stripe-webhook` estão untracked — aplicar via CLI/migration tracker do Supabase.
- Alterações locais: CRLF warnings no git (não bloqueantes, só normalização).
