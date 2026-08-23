# PocketApps — Estado Global do Projeto

> Resumo completo do monorepo: o que existe, o que está em progresso e o que falta.
> Atualizado em 2026-08-23 — **PocketExpenses em fase de TESTES** (antes da integração Stripe).

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
  migrations/             → 20260823125225_remote_schema.sql (snapshot remoto — histórico antigo consolidado, ver §4)
  functions/              → 6 Edge Functions (Deno)
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
- Relatórios mensais por email (`report_settings_page` + `report_provider`/`report_service`). Desde 2026-08-10 o **relatório de teste escolhe o mês** e o relatório `detailed` inclui a **lista completa "Despesas do mês"**. **Preferências simplificadas (2026-08-21)**: mensal ativo por defeito; detalhado é feature Premium ativada com switch; dia/hora combinados num só campo; o que se vê na página = o que está guardado.
- **Onboarding (2026-08-22)**: fluxo inicial de 5 páginas para novos utilizadores, incluindo slide com exemplo da página principal e campo para alterar o nome de utilizador; utilizadores Free podem usar o **wizard passo a passo 1 vez** (flag `wizard_free_used`, verificada sempre com flags frescas + guarda dura no save). "Rever tutorial" nas definições abre em modo demo (sem alterar dados) e "Simular 1.ª utilização" repõe a flag do wizard.
- **Gates Premium (2026-08-22/23)**: wizard bloqueado após 1.º uso free — ao tentar "Criar outra despesa" verifica premium ANTES de preencher (snackbar → Planos); ao voltar dos Planos vai direto à app (nunca volta ao wizard com dados antigos). Limite de **10 categorias** no plano Free. **Backup diário cloud (snapshots) exclusivo Premium com restauro num toque**.
- **Modo de teste Free/Premium (2026-08-23)**: long-press na versão em Sobre → ativa modo de teste → secção TESTE nas Definições com seletor Real | Free | Premium. Override **local apenas** (SharedPreferences, sem escrever na BD), aplicado no `subscriptionProvider` — toda a app responde instantaneamente (wizard, banners, limites, backup, relatórios). Persiste entre aberturas; badge "MODO DE TESTE ATIVO" na página Sobre. **⚠️ Remover/esconder antes do lançamento público** (issue no GitHub).
- Plataformas de destino: Android (APK gerado em CI). `version: 1.0.0+1`. APK publicado na release GitHub `pocketexpenses-latest` como `PocketExpenses.apk` + sync automático para pocketapps.pt (Ctrl+F5 para cache).

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
> **Reconciliação (2026-08-23, commit `c55ca0d`)**: o histórico local de migrations (001–007) foi consolidado num único **snapshot do schema remoto de produção** — `migrations/20260823125225_remote_schema.sql`. O histórico antigo já não existe como ficheiros individuais; `schema.sql` continua a ser a fonte de verdade e está sincronizado com a produção (commit `bd410a0`). Novas migrations devem partir do snapshot atual.

### Edge Functions (6)
`delete-account`, `report-unsubscribe`, `send-monthly-report` (relatório mensal, usa `report_type`), `send-welcome-email`, `stripe-webhook` (payment link webhook — **deployado (v1, 2026-08-11)**, usa env vars `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` + SMTP Brevo — **env vars ainda por definir no remoto**), `svg-to-png` (conversão SVG → PNG serverless, resvg-wasm — **deployado (v1, 2026-08-13)**).

### Email transacional
- Relay SMTP: **`smtp-relay.brevo.com`** (Brevo), from padrão `no-reply@pocketapps.pt`.
- Documentado em [`docs/backend.md`](backend.md) (secção "Email transacional").
- **Supabase Auth custom SMTP** ✅ configurado e **verificado com envio real** (2026-08-03): magic link/OTP do site chega à inbox. Causa do problema anterior: `smtp_user` errado (email da conta em vez do login SMTP do Brevo).
- **Relatório mensal** ✅ (2026-08-10): fix do cron — o `send-monthly-report` tratava a `service_role` do cron como JWT de utilizador (`getUser()` → 403 → 401, nada enviava); agora o batch só entra com service role e o modo utilizador só com JWT validado (deploy v16). Diagnóstico de entrega: SPF/DKIM/DMARC/MX/verificação Brevo todos corretos; o *silent drop* temporário do Gmail (rajada de envios de teste) resolveu-se sozinho — ver [`backend.md`](backend.md#agendamento-do-relatrio-pgcron).
- **Relatório — gráficos + PDF** ✅ (2026-08-10): `include_charts` passa a mostrar gráficos no **fim do email** — donut de distribuição por categoria (`conic-gradient` + legenda) e barra "Recorrentes vs únicas"; o email passa a incluir **PDF em anexo** (`pdf-lib`, Deno; donut vetorial com `drawSvgPath`). Fix: o `■` na legenda do PDF rebentava a geração (WinAnsi) — substituído por retângulos de legenda. Na app, fix de persistência dos toggles (`report_settings_page.dart` lê o valor em cache no `initState` — o Riverpod 3.3.2 não tem `fireImmediately`).
- **Relatório — cores por categoria** ✅ (2026-08-11): cada categoria recebe uma cor estável de `CATEGORY_PALETTE` (paleta fixa de 10 cores; validada e com fallback por índice), usada consistentemente no email e no PDF — swatches nas listas, donut, legenda e novas **barras horizontais "Despesas por categoria"** (email e PDF). Ver [`backend.md`](backend.md#cores-por-categoria-2026-08-11).
- **Relatório — donut visível em todos os clientes + PDF idêntico ao email** ✅ (2026-08-21): o donut passou a ser um **PNG gerado pelo QuickChart.io e hospedado num URL público do Supabase Storage** (bucket `report-charts`, criado pela própria função se não existir; path `donuts/{user_id}-{AAAA-MM}.png` com `upsert` → URL estável e cacheável) — substitui a data URI base64 (bloqueada pelo Gmail/Outlook → gráfico invisível), o `conic-gradient` (sem suporte nesses clientes) **e o CID inline, que o Gmail continuava a listar como anexo fantasma ("attachment-1")**; como a imagem nem viaja no email, o único anexo é o PDF. O donut foi também **redesenhado** (Chart.js v4: cantos arredondados `borderRadius`, espaçamento branco entre fatias, sem legenda dentro da imagem) com **legenda HTML elegante ao lado** (dot colorido + nome + valor + %). O **PDF em anexo espelha o email**: mesmas secções pela mesma ordem (cabeçalho, estatísticas, despesas do mês, donut à esquerda + legenda à direita, barra "Recorrentes vs únicas"). Fallback: se o QuickChart ou o upload falharem, o email usa barras por categoria (sem donut) e o PDF sai sem imagem.

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
- **Passos 4–8** 🟡 **parciais**: `stripe-webhook` já deployado (v1, 2026-08-11); falta definir env vars, criar 6 Payment Links, registar o webhook na Stripe, colocar links reais e substituir botões mock (dashboard da Stripe em baixo — erro do lado da Stripe).
- **Botões mock**: `buy.stripe.com/TODO_*` → decisão de 2026-08: botões **"Comprar" desativados** com labels dinâmicos do `config.js` em `pricing.html` (ex.: "Comprar Premium · €14.99/ano"); `themes.html` mantém "Em breve" (`.btn-buy` em `style.css`).

- **Botões mock**: `buy.stripe.com/TODO_*` → decisão de 2026-08: botões **"Comprar" desativados** com labels dinâmicos do `config.js` em `pricing.html` (ex.: "Comprar Premium · €14.99/ano"); `themes.html` mantém "Em breve" (`.btn-buy` em `style.css`).
- **Gates Premium já implementados na app (2026-08-22/23)**: wizard passo a passo só free 1.ª vez; limite de 10 categorias no Free; relatório detalhado Premium; backup diário cloud Premium. Ainda por implementar: anúncios (fase 1) e widgets home screen (fase 6). Detalhe das fases: [`monetizacao-stripe.md`](monetizacao-stripe.md).
- **Decisão de fluxo (2026-08-23)**: integração Stripe (passos 4–8) fica **em pausa até concluída a fase de testes** da app.

## 8. Estado atual (2026-08-23) — fim da fase de desenvolvimento, início dos testes

Última sessão de desenvolvimento fechou o ciclo onboarding → wizard → gating premium:

| Commit | O que fez |
|---|---|
| `e206841` | Backup diário cloud (snapshots) Premium com restauro num toque |
| `740885f` | Limite de 10 categorias no plano Free |
| `8c329ad` `0faf08f` `47c0ebb` | Onboarding 5 páginas + slide com exemplo e nome de utilizador + fix redirect (ecrã preto) |
| `2130435` `5b008e4` `b919149` | Wizard free bloqueia após 1.º uso (`wizard_free_used`, flags frescas + guarda no save); rever tutorial em modo demo; simular 1.ª utilização |
| `f662305` `621ce20` | Gate premium ANTES de preencher nova despesa ("criar outra"); voltar dos Planos → app (nunca wizard com dados antigos) |
| `413835f` | Modo de teste Free/Premium (long-press na versão em Sobre; override local no `subscriptionProvider`) |

- `flutter analyze`: ✅ sem issues.
- CI verde: APK publicado na release `pocketexpenses-latest` (SHA256 do último build: `56F65159069D9FA20F60863F030784945B0387C5F93FC5AD7C9173BD1C730087`).

## 9. O que falta / próximo

**Ordem acordada (2026-08-23): 1º testar a app → só depois integrar Stripe.**

| # | Item | Estado |
|---|---|---|
| 1 | **Fase de testes PocketExpenses** — checklist no issue GitHub correspondente | 🟡 PRÓXIMO — app considerada feature-complete para esta fase |
| 2 | Stripe passos 4–8: env vars (`STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET`), Payment Links, registo webhook, links reais, botões ativos | ⏳ EM PAUSA até concluírem os testes |
| 3 | Remover/esconder modo de teste Free/Premium antes do lançamento público | ⏳ pendente (issue criada) |
| 4 | Fases de monetização em falta: anúncios (1) e widgets home screen (6) | ⏳ futuro — ver `monetizacao-stripe.md` |
| 5 | Apps Fuel e Shopping: passar de stub para implementação | ⏳ futuro |
| 6 | Dashboard Supabase: email provider + SMTP + redirects + Site URL | ✅ feito |
| 7 | Onboarding + wizard com gating free (1 uso) + rever tutorial/simular 1.ª utilização | ✅ feito (2026-08-22) |
| 8 | Gates premium: wizard, 10 categorias, relatório detalhado, backup cloud | ✅ feito (2026-08-22/23) |
| 9 | Modo de teste Free/Premium local (sem tocar na BD) | ✅ feito (2026-08-23, commit `413835f`) |
| 10 | Migrations reconciliadas com produção (snapshot remoto único) | ✅ feito (2026-08-23, commit `c55ca0d`) |
| 11 | Relatórios: preferências simplificadas, donut final (percentagens fora, linhas guia), PDF espelhado | ✅ feito (2026-08-21/22) |

## 10. Notas de manutenção

- As páginas do site **não** são versionadas no repo principal (git-ignored); vivem no repo `pocketapps.github.io`.
- `supabase/migrations/` contém apenas o snapshot remoto consolidado (`20260823125225_remote_schema.sql`) — novas migrations partem dele.
- `supabase/functions/stripe-webhook/` commitado e deployado (v1, 2026-08-11) — env vars ainda por definir no remoto.
- Alterações locais: CRLF warnings no git (não bloqueantes, só normalização).
- Issues de acompanhamento no GitHub (`pocketapps-dev/pocketapps`): fase de testes, integração Stripe, remoção do modo de teste.
