# PocketApps — Monetização / Stripe (feature)

> Estratégia de monetização + estado operacional (8 passos). Atualizado em 2026-08-08.

## Modelo de planos

| Plano | Tipo | Preço (base, sem IVA) | Inclui |
|---|---|---|---|
| **Free** | — | 0€ | Limites por app (ex.: 10 despesas ativas, 10 categorias, anúncios). **Por conta**: registo numa app → Free em todas |
| **Premium** | Recorrente | 1,49€/mês · 14,99€/ano | **Todas as apps** (atuais + futuras): ilimitado, sem anúncios, widgets, relatórios, wizard, 3 temas |
| **Founder** | One-time (vitalício) | 25€/app × nº apps → 3 apps = **75€**; **50% no total só p/ os 1ºs 5 founders** = 37,50€; founders 6–25 = 75€ | Tudo do Premium vitalício em todas as apps + early access. **Só em fase de desenvolvimento; máximo 25 pessoas** |
| **Temas à la carte** | One-time | 0,99€/tema (a confirmar) | Compra única **por conta** (válida em todas as apps); Premium inclui 3 temas |

Decisões de 2026-08-08:

- **Free e Premium são por conta** — âmbito = todas as apps; o Premium é um **SKU único**.
- O **Founder** é a compra **vitalícia do mesmo Premium** — o "25€/app" é a matemática do preço (soma das apps + desconto aplicado depois), não subscrições por app.
- **IVA**: a taxa varia por país — na UE (regime OSS) aplica-se a taxa do **país do cliente** (PT 23%, ES 21%, DE 19%, ...); fora da UE, serviços digitais B2C normalmente sem IVA. Preços no site exibidos **sem IVA** (nota "**+ IVA**"); o IVA é aplicado apenas **no checkout** (Stripe Tax ou serviço de faturação a escolher).
- **Gateway / faturação**: ainda em estudo — reavaliar Payment Links vs Checkout Session e serviço de invoice (app internacional com foco em PT).

**Na app (2026-08-08)**: a página de planos (`plans_page.dart`) mostra o **total das 3 apps** — Founder `€37,50` (50% OFF) ou `€75` — e lê a contagem real de founders via RPC pública `get_founder_count()` (`subscription_provider.dart`); desconto ativo enquanto `founder_count < 5`. Premium mostrado a `€14.99/ano`.
- **Fluxo de compra (2026-08-08)**: cards de topo em Definições (`settings_page.dart`) e Conta (`account_page.dart` `_PlanCard`) → `/settings/plans`; o botão "Comprar no website" da página de planos abre `https://pocketapps.pt/pricing.html`. O site mantém o utilizador autenticado e mostra botões de compra desativados com labels dinâmicos do `config.js` ("Comprar Premium · €14.99/ano", "Comprar Founder · €37.50").

## Loja de temas (à la carte)

- **Premium** inclui 3 temas exclusivos (midnight, forest, sunset).
- **Loja de temas**: **todos** os temas à venda por 0,99€ cada (compra única, lifetime) — incl. ocean, autumn, galaxy, rose, e também os temas premium (midnight, forest, sunset). (2026-08-06)
- **Âmbito da compra (2026-08-08)**: por **conta** — um tema comprado fica disponível em todas as apps (não só expenses).
- **Free**: light + dark.
- **Regra de negócio (2026-08-06)**: um user free pode comprar qualquer tema individualmente (0,99€). Se depois aderir ao Premium, a compra individual continua válida (não é perdida) — o Premium apenas desbloqueia os temas por subscrição. O webhook `stripe-webhook` trata a duplicação via `user_themes` (unique constraint).

## Fases no produto

| Fase | Descrição | Implementação |
|---|---|---|
| **1 — Anúncios (Free)** | Native no dashboard, Banner no rodapé, Interstitial máx. 1x/dia após criar despesa, Rewarded opcional no paywall | `google_mobile_ads` (AdMob) + Google UMP (RGPD); ~0,63€/user/mês |
| **2 — Gates de limite** | Despesas ativas 10 (Free) / ilimitado; Categorias 10 / ilimitadas; editar categorias = Premium | `ExpenseActions.create()`, `CategoryActions.create()`, `CategoryActions.update()`, `CategoriesPage`; paywall `premium_gate_dialog.dart` |
| **3 — Temas Premium** | Free = light+dark; Premium = +3 temas | `theme_models.dart`, `AppTheme` seedColor dinâmico, gate no `PreferencesPage` |
| **4 — Código Founder** | Bundle **todas as apps** a 25€/app (50% no total só p/ 1ºs 5; máx. 25 pessoas) | Migration SQL (check aceita `'all'`); RPC `validate_activation_code` ativa todas as apps; dialog aceita códigos `all` |
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

> **Em revisão (2026-08-08)**: com o Premium a passar a "todas as apps" (1 SKU por conta), estes links/metadados mudam de âmbito — `app_name: expenses` passa a âmbito de conta/todas as apps; gateway (Payment Links vs Checkout Session) e faturação/IVA ainda em estudo.

## Edge Function `stripe-webhook`

Ficheiro: `supabase/functions/stripe-webhook/index.ts`. Env vars: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, e SMTP (`SMTP_HOST` default `smtp-relay.brevo.com`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_REPLY_TO`).

Após deploy: Stripe → Developers → Webhooks → add endpoint com evento `checkout.session.completed` e guardar o secret `whsec_...`. Secrets: Dashboard → Edge Functions → stripe-webhook → Secrets.

## Botões mock (decisão de 2026-08)

- Cliques em "Comprar" irão para os links reais do Stripe (hoje: botões **desativados**).
- Em `pricing.html` os botões mostram labels dinâmicos do `config.js` (ex.: "Comprar Premium · €14.99/ano", "Comprar Founder · €37.50"); em `themes.html` mostram "Em breve". Ativar quando os links reais forem inseridos.
- CSS: `pocketapps.github.io/style.css` linha 932 (`.btn-buy`). Detalhes: [`docs/site.md`](site.md).

## Notas

- `Subscription.isActive` já funciona para founder (endsAt futuro).
- Widgets requerem configuração nativa (AndroidManifest/Info.plist).
- Website (venda de códigos/temas) é trabalho separado — a app só consome.
