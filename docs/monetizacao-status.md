# Monetização PocketApps — Estado e Próximos Passos

Ficheiro de retoma. Última atualização: Aug 2026.

## Estado geral

| # | Passo | Estado |
|---|---|---|
| 1 | Migração `001_themes` (tabelas + RPCs + temas seed) | ✅ Feito e verificado no remoto |
| 2 | Auth no Dashboard Supabase: Email provider + Confirm email (magic link) | ⏳ Manual, aguarda confirmação |
| 3 | Dashboard Supabase: Redirect URLs + Site URL | ⏳ Manual, aguarda confirmação |
| 4 | Stripe Payment Links | 🔴 Bloqueado — dashboard Stripe com erro; botões ficaram como mock |
| 5 | Deploy Edge Function `stripe-webhook` | 🔴 Bloqueado — precisa de `STRIPE_SECRET_KEY` + `whsec_...` |
| 6 | Registo do webhook no Stripe (`checkout.session.completed`) | 🔴 Bloqueado |
| 7 | Inserir links reais nos TODOs das páginas | 🔴 Bloqueado |
| 8 | Substituir botões mock por "Comprar" ativo | 🔴 Bloqueado |

## Passos 2–3 (Dashboard Supabase — manual, não depende do Stripe)

- **Auth → Providers → Email → Enable + Confirm email = ON** (é o email de confirmação que gera o magic link no `signUp`).
- SMTP recomendado para fiabilidade.
- **Redirect URLs**:
  - `pt.pocketapps.pocketexpenses://auth-callback`
  - `pt.pocketapps.pocketfuel://auth-callback`
  - `pt.pocketapps.pocketshopping://auth-callback`
  - (wildcard aceite: `pt.pocketapps.pocketexpenses://**`)
- **Site URL**: `https://pocketapps.github.io`

Fluxo confirmado em `packages/pocketapps_auth/lib/src/auth_service.dart`:
`signUp` com `emailRedirectTo` (linhas 71–87) e `signInWithPassword` (linha 107).

## Plano Stripe — 6 Payment Links (Dashboard Stripe → Payments → Payment Links)

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
- Comentário nas páginas pede metadata: `user_id`, `theme_key`, `app_name`.

### TODOs a substituir
- `pocketapps.github.io/themes.html` linhas 142–146: `ocean` / `autumn` / `galaxy` (`https://buy.stripe.com/TODO_*`)
- `pocketapps.github.io/pricing.html` linhas 147–149: `premium` / `annual` / `founder`
- `APP_NAME = 'expenses'` em ambas as páginas; `SUPABASE_URL = https://vlbhnlzqixmxtlpqsggd.supabase.co` em themes.html.

## Edge Function `stripe-webhook`

Ficheiro: `supabase/functions/stripe-webhook/index.ts`

Env vars usadas:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `SMTP_HOST` (default `smtp-relay.brevo.com`), `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_REPLY_TO`

Notas:
- Não fazer deploy com chave vazia — `new Stripe('')` rebenta ao arrancar.
- SDK Stripe com `apiVersion: "2024-12-18.acacia"`.
- Após deploy: Stripe → Developers → Webhooks → add endpoint com evento `checkout.session.completed` e guardar o secret `whsec_...`.
- Definir secrets em Dashboard → Edge Functions → stripe-webhook → Secrets.

## Botões mock (decisão de 2026-08)

- Cliques em "Comprar" vão hoje para `buy.stripe.com/TODO_*` (link partido).
- Tarefa pendente: mudar para botão desativado "Em breve" quando o link for mock/TODO; voltar a "Comprar" automaticamente quando os links reais forem inseridos.
- CSS do botão: `pocketapps.github.io/style.css` linha 932 (`.btn-buy`).
- Nota: as páginas estão git-ignored neste repo.

## Progresso anterior (manutenção)

- Migração `001_themes.sql` re-aplicada de forma idempotente e verificada no remoto (3 tabelas, 3 RPCs, 7 temas seedados, constraint única).
