# PocketApps — Monetização / Stripe (feature)

> Estratégia de monetização + estado operacional (8 passos). Atualizado em 2026-08-03.

## Modelo de planos

| Plano | Tipo | Preço | Inclui |
|---|---|---|---|
| **Free** | — | 0€ | 10 despesas ativas, 10 categorias, anúncios, sem editar categorias |
| **Premium** | Recorrente | 1,49€/mês | Tudo: ilimitado, sem anúncios, widgets, relatórios, wizard, 3 temas |
| **Premium Anual** | Recorrente | 14,99€/ano | Tudo do Premium + 3 temas |
| **Founder** | One-time | 29,99€ (50% off de 59,98€) | Tudo + todas as apps (bundle), lifetime + early access |

## Loja de temas (à la carte)

- **Premium** inclui 3 temas exclusivos (midnight, forest, sunset).
- **Loja de temas**: adicionais à venda por 0,99€ cada (compra única, lifetime) — ex.: ocean, autumn, galaxy, rose.
- **Free**: light + dark.

## Fases no produto

| Fase | Descrição | Implementação |
|---|---|---|
| **1 — Anúncios (Free)** | Native no dashboard, Banner no rodapé, Interstitial máx. 1x/dia após criar despesa, Rewarded opcional no paywall | `google_mobile_ads` (AdMob) + Google UMP (RGPD); ~0,63€/user/mês |
| **2 — Gates de limite** | Despesas ativas 10 (Free) / ilimitado; Categorias 10 / ilimitadas; editar categorias = Premium | `ExpenseActions.create()`, `CategoryActions.create()`, `CategoryActions.update()`, `CategoriesPage`; paywall `premium_gate_dialog.dart` |
| **3 — Temas Premium** | Free = light+dark; Premium = +3 temas | `theme_models.dart`, `AppTheme` seedColor dinâmico, gate no `PreferencesPage` |
| **4 — Código Founder** | Bundle 3 apps a 29,99€ | Migration SQL (check aceita `'all'`); RPC `validate_activation_code` ativa as 3 apps; dialog aceita códigos `all` |
| **5 — Relatórios elaborados** | Free = básico; Premium = Δ% vs mês anterior, top 3, recorrentes vs únicas, dica | `send-monthly-report` verifica subscrição |
| **6 — Widgets Home Screen** | Free = normal; Premium = widgets (próximas despesas, total do mês) | `home_widget` + configuração nativa (AndroidManifest/Info.plist) + cache local |
| **7 — Wizard Premium** | Free = `ExpenseFormPage`; Premium = `ExpenseWizardPage` (7 passos) | gate no acesso ao wizard |

## Ordem de implementação

| Sprint | Fases | Esforço |
|---|---|---|
| Sprint 1 | Fase 1 (anúncios) + Fase 2 (gates) | ~5-6 dias |
| Sprint 2 | Fase 3 (temas) + Fase 7 (wizard) | ~4-5 dias |
| Sprint 3 | Fase 4 (founder) + Fase 5 (relatórios) | ~5-6 dias |
| Sprint 4 | Fase 6 (widgets) | ~3-5 dias |

## Estado operacional (8 passos)

| # | Passo | Estado |
|---|---|---|
| 1 | Migration `001_themes` (tabelas + RPCs + temas seed) | ✅ Feito e verificado no remoto |
| 2 | Auth no Dashboard Supabase: Email provider + Confirm email (magic link) | ✅ Feito — provider ativo, **custom SMTP corrigido e verificado** (OTP chega à inbox); ver [`docs/auth.md`](auth.md) |
| 3 | Dashboard Supabase: Redirect URLs + Site URL | ✅ Feito — allowlist + Site URL `https://pocketapps.pt` (2026-08-03); magic link do site completa login |
| 4 | Stripe Payment Links | 🔴 Bloqueado — dashboard Stripe com erro; botões ficaram como mock |
| 5 | Deploy Edge Function `stripe-webhook` | 🔴 Bloqueado — precisa de `STRIPE_SECRET_KEY` + `whsec_...` |
| 6 | Registo do webhook no Stripe (`checkout.session.completed`) | 🔴 Bloqueado |
| 7 | Inserir links reais nos TODOs das páginas | 🔴 Bloqueado |
| 8 | Substituir botões mock por "Comprar" ativo | 🔴 Bloqueado |

## Plano Stripe — 6 Payment Links

Metadados lidos pelo webhook (em Price/Product metadata):

| Link | Preço | Metadata |
|---|---|---|
| `ocean` | 0,99€ | `theme_key: ocean`, `app_name: expenses` |
| `autumn` | 0,99€ | `theme_key: autumn`, `app_name: expenses` |
| `galaxy` | 0,99€ | `theme_key: galaxy`, `app_name: expenses` |
| `premium` | 1,49€/mês | `plan: premium_monthly`, `app_name: expenses`, `duration_months: 1` |
| `annual` | 14,99€/ano | `plan: premium_annual`, `app_name: expenses`, `duration_months: 12` |
| `founder` | 29,99€ | `plan: founder`, `app_name: expenses` |

- `user_id` resolvido pelo webhook via `client_reference_id` (o link recebe-o por parâmetro na URL).

## Edge Function `stripe-webhook`

Ficheiro: `supabase/functions/stripe-webhook/index.ts`. Env vars: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, e SMTP (`SMTP_HOST` default `smtp-relay.brevo.com`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_REPLY_TO`).

Após deploy: Stripe → Developers → Webhooks → add endpoint com evento `checkout.session.completed` e guardar o secret `whsec_...`. Secrets: Dashboard → Edge Functions → stripe-webhook → Secrets.

## Botões mock (decisão de 2026-08)

- Cliques em "Comprar" vão hoje para `buy.stripe.com/TODO_*` (link partido).
- Mudar para botão desativado "Em breve" enquanto o link for mock; voltar a "Comprar" quando os links reais forem inseridos.
- CSS: `pocketapps.github.io/style.css` linha 932 (`.btn-buy`). Detalhes: [`docs/site.md`](site.md).

## Notas

- `Subscription.isActive` já funciona para founder (endsAt futuro).
- Widgets requerem configuração nativa (AndroidManifest/Info.plist).
- Website (venda de códigos/temas) é trabalho separado — a app só consome.
