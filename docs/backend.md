# PocketApps — Backend (Supabase)

> Backend partilhado: Postgres (schema + RPCs) + Edge Functions (Deno) + email transacional.
> Atualizado em 2026-08-10.

## Projeto remoto

- URL: `https://vlbhnlzqixmxtlpqsggd.supabase.co`
- `APP_NAME`: `expenses`

## Schema (`supabase/schema.sql`, fonte de verdade, ~39 KB)

### Tabelas

`profiles`, `user_app_access`, `categories`, `expenses`, `monthly_status`, `subscriptions`, `user_settings`, `monthly_summaries`, `activation_codes`, `report_preferences` + monetização: `themes`, `user_themes`, `theme_purchases`.

RLS ativado nas tabelas principais. Índices optimizados por `user_id`/`app_name`. Trigger genérico `update_updated_at` em profiles/expenses/subscriptions/user_settings/report_preferences.

### RPCs / Funções

- Auth/usuário: `handle_new_user` (trigger `on_auth_user_created`), `check_username_available`, `get_email_by_username`
- Acesso: `check_app_access`, `add_app_access`
- Despesas: `get_or_create_monthly_status`, `toggle_expense_paid`, `toggle_expense_skip`, `confirm_expense_amount`, `get_effective_amount`
- Relatórios: `archive_monthly_summary`, `cleanup_old_data`
- Códigos: `validate_activation_code`
- Monetização: `get_founder_count` (RPC pública — contagem de founders registados, consumida pela página de planos para o desconto 50% OFF) (2026-08-08)
- Temas: `get_user_themes` (catálogo + disponibilidade por utilizador — consumido pela **loja de temas da app**, ver abaixo; desde 2026-08-09 devolve também a coluna `brightness` do tema; desde 2026-08-10 ordena temas gratuitos primeiro), `validate_theme_activation_code`, `grant_theme_to_user`

### Migrations

| Migration | Conteúdo | Estado |
|---|---|---|
| `001_themes.sql` | 3 tabelas (themes, user_themes, theme_purchases) + 3 RPCs + 7 temas seed + unique constraint | ✅ Aplicada (`20260803051308`) |
| `002_report_type.sql` | `report_preferences.report_type` (`simple`/`detailed`) | ✅ Aplicada (`20260803043706`) |
| `003_founder_count.sql` | RPC pública `get_founder_count()` (leitura da contagem de founders) | ✅ No schema (`supabase/schema.sql`) |
| `004_light_dark_themes.sql` | Temas gratuitos `light` (`Light`) e `dark` (`Dark`) na app `expenses` | ✅ Aplicada no remoto |
| `005_theme_brightness.sql` | Coluna `themes.brightness` (`light`/`dark`) + default/constraint + `get_user_themes` com `brightness` | ✅ Aplicada no remoto |
| `006_remove_default_theme.sql` | Desativa o tema `default` (`is_active=false`) — deixa de constar no catálogo/`get_user_themes` e na validação de códigos | ✅ Aplicada no remoto |
| `007_themes_order_free_first.sql` | Renumera `sort_order` dos temas (gratuitos `light`/`default`/`dark` primeiro) + `get_user_themes` com ordenação free-first | ✅ Aplicada no remoto |

## Edge Functions (5, Deno)

| Função | Versão deployed | verify_jwt | Import map | Uso |
|---|---|---|---|---|
| `send-welcome-email` | 46 | true | `deno.json` | Boas-vindas por app (`expenses`/`fuel`/`shopping` via `APP_CONFIG`) |
| `send-monthly-report` | 10 | true | `deno.json` | Relatório mensal (simple/detailed) |
| `delete-account` | 46 | true | `deno.json` | Confirmação de eliminação de conta |
| `report-unsubscribe` | 4 | false | — | Unsubscribe do relatório (não envia email) |
| `stripe-webhook` | — | — | — | Webhook `checkout.session.completed` — 🔴 não deployado (bloqueado pela Stripe) |

`stripe-webhook` usa env vars `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` + SMTP Brevo; não fazer deploy com chave vazia (`new Stripe('')` rebenta ao arrancar); SDK Stripe `apiVersion: "2024-12-18.acacia"`.

## Email transacional

Arquitetura: App (Flutter) → Edge Function (Supabase) → SMTP (nodemailer) → **Brevo Relay** (`smtp-relay.brevo.com:587`). Os emails enviam a partir de `no-reply@pocketapps.pt` com `reply-to` para `suporte@pocketapps.pt`.

### Senders Brevo (5 ativos)

| id | Endereço |
|---|---|
| 1 | `pocketapps.dev.pt@gmail.com` |
| 2 | `no-reply@pocketapps.pt` |
| 3 | `suporte@pocketapps.pt` |
| 4 | `billing@pocketapps.pt` |
| 5 | `marketing@pocketapps.pt` |

### Domínio e DNS (`pocketapps.pt` — authenticated, verified, provider Cloudflare)

- TXT SPF: `brevo-code:cdb0ba6a2afcc66ecd2dec927c68e1a9`
- CNAME DKIM: `brevo1._domainkey` → `b1.pocketapps-pt.dkim.brevo.com`
- CNAME DKIM: `brevo2._domainkey` → `b2.pocketapps-pt.dkim.brevo.com`
- `_dmarc` → `p=none`

### Reply-to

```ts
const replyTo = Deno.env.get("SMTP_REPLY_TO") || "suporte@pocketapps.pt";
```

### Secrets (edge functions)

**Importante — utilizador SMTP correto:** o Brevo relay autentica com o **login SMTP** (`b3d20e001@smtp-brevo.com`), **não** com o email da conta Brevo. A SMTP key (ex.: `xsmtpsib-...`) é a password.

- **✅ Definidos (2026-08-03, via Management API `POST /v1/projects/{ref}/secrets`) e verificados por hash:**
  `SMTP_HOST=smtp-relay.brevo.com`, `SMTP_PORT=587`, `SMTP_USER=b3d20e001@smtp-brevo.com`, `SMTP_PASS=<xsmtpsib>`, `SMTP_FROM=no-reply@pocketapps.pt`, `SMTP_REPLY_TO=suporte@pocketapps.pt`.
- `SMTP_USER`/`SMTP_PASS` foram corrigidos/confirmados porque a chave anterior era desconhecida.
- Alternativa para voltar a definir pela CLI: `supabase secrets set SMTP_HOST=smtp-relay.brevo.com SMTP_PORT=587 SMTP_USER=b3d20e001@smtp-brevo.com SMTP_PASS=<senha_brevo_xsmtpsib> SMTP_FROM=no-reply@pocketapps.pt SMTP_REPLY_TO=suporte@pocketapps.pt`

Defaults no código: host `smtp-relay.brevo.com`, porta `587`, `SMTP_FROM=no-reply@pocketapps.pt`, `SMTP_REPLY_TO=suporte@pocketapps.pt`.

### Supabase Auth — Custom SMTP (magic link / OTP / confirm email)

O **Supabase Auth** (email de confirmação, magic link/OTP do site, reset de password) tem **configuração própria de SMTP** no projeto — separada dos secrets das edge functions.

- **Configurado em 2026-08-03** via Management API (`PATCH /v1/projects/{ref}/config/auth`, formato plano `smtp_*`).
- Antes disto, o SMTP apontava para o Brevo mas com `smtp_user` errado (`pocketapps.dev.pt@gmail.com` = email da conta) → autenticação falhava (`535`) e **nenhum email OTP chegava**.
- **Valores atuais (verificados com envio real):**

| Campo | Valor |
|---|---|
| `smtp_host` | `smtp-relay.brevo.com` |
| `smtp_port` | `587` |
| `smtp_user` | `b3d20e001@smtp-brevo.com` (login SMTP do Brevo) |
| `smtp_pass` | SMTP key `xsmtpsib-...` (a API devolve mascarada/hash) |
| `smtp_sender_name` | `PocketApps` |
| `smtp_admin_email` | `no-reply@pocketapps.pt` (sender verificado no Brevo) |

> Para alterar no futuro pelo dashboard: Auth → Providers → Email → Custom SMTP.

## Relatório mensal — tipos (simple / detailed)

Controlado por `report_preferences.report_type`:

- `simple` — cabeçalho + linha de estatísticas (Total/Recorrentes/Únicas/Despesas) + CTA; sem categorias nem gráficos.
- `detailed` (padrão) — além das estatísticas, quebra por categoria, e desde 2026-08-10 a **lista "Despesas do mês"** (cada despesa do mês: nome, categoria, tipo + quando, valor — ordenada por valor decrescente, com nomes/categorias escapados). Os **gráficos** aparecem no **fim do email**: donut de distribuição por categoria (`conic-gradient` com cor de cada categoria + centro branco com o total; em clientes sem suporte a `conic-gradient` — Gmail/Outlook Windows — degrada para anel cinzento com a legenda a manter os valores) + legenda (cor, categoria, valor, %) + barra "Recorrentes vs únicas".

Precedência na função: `body.report_type` → `report_preferences.report_type` → `'detailed'`. A app grava com `report_type` no upsert de `report_preferences` (`report_provider.dart` usa `'detailed'` como fallback). Migration `002_report_type.sql` adiciona a coluna com `add column if not exists`, mantendo `detailed` para preferências existentes.

### PDF em anexo (2026-08-10)

- O email passa a incluir um **PDF em anexo** (`relatorio-AAAA-MM.pdf`), gerado com `pdf-lib` (via `esm.sh`, corre nativamente em Deno) — contém cabeçalho, estatísticas, categorias, despesas do mês e, no fim, os gráficos (donut vetorial desenhado com `drawSvgPath` + barra "Recorrentes vs únicas").
- O PDF só usa fontes standard (Helvetica) e caracteres Latin-1 (função `pdfSafe`) — **fix 2026-08-10:** o carácter `■` (U+25A0) na legenda fazia `pdf-lib` lançar `WinAnsi cannot encode` e o anexo falhava silenciosamente (email seguia sem PDF); substituído por quadrados de legenda desenhados (retângulos) e texto sem `■`.
- A geração falha graciosamente: se o PDF der erro, o email segue sem anexo (log `[PDF] ...`).
- **Persistência dos toggles na app (2026-08-10):** `report_settings_page.dart` agora lê o valor em cache no `initState` (`ref.read(...).value`) antes de registar o `ref.listen` — antes, ao reabrir a página, o listener não disparava com o valor já em cache e os toggles voltavam aos defaults em vez da escolha guardada. Nota: o Riverpod 3.3.2 não tem `fireImmediately` no `ref.listen` (só `onError`/`weak`), daí a leitura explícita no `initState`.

### Relatório de teste — escolha do mês (2026-08-10)

- A app (`report_settings_page.dart`) pergunta o **mês** antes de enviar o teste ("Enviar relatório de teste" → diálogo com grelha de meses e navegação de ano).
- A app envia `body.month` (`"YYYY-MM"`) na invocação da função; em modo teste (com `Authorization`) a função usa esse mês como período do relatório (`parseMonthParam`; default = mês atual).
- **Fix de valores vazios**: removido `if (s > now) return false` em `occursInMonth` — excluía despesas recorrentes com `start_date` posterior à data de execução (ex.: recorrente que começa a 15/ago ficava fora do relatório de agosto enviado a 10/ago). A iteração mensal é a única fonte de verdade do mês.
- Modo batch (cron) inalterado: ignora `body.month` e continua a reportar o mês anterior.

## Loja de temas (app PocketExpenses)

Desde 2026-08-04 a app consome `get_user_themes` (`p_app_name='expenses'`) para a página `/settings/themes`:

- O RPC devolve o catálogo com `available`/`purchased` (free ⇒ `available=true`; premium ⇒ depende da subscrição `subscriptions`; pagos ⇒ depende de `user_themes`).
- `validate_theme_activation_code` é usado para ativar um código de tema.
- A compra dos temas pagos (Ocean, Autumn, Galaxy, 0,99€) é feita no site (`https://pocketapps.pt/themes.html`); o webhook `stripe-webhook`/`grant_theme_to_user` desbloqueia na conta e a app sincroniza automaticamente.
- **Brilho por tema (2026-08-09):** a coluna `themes.brightness` (migration `005_theme_brightness.sql`) define o tema claro/escuro por tema — `dark`/`midnight` são escuros, os restantes (`light`, `forest`, `sunset`, `ocean`, `autumn`, `galaxy`) são claros. `get_user_themes` devolve `brightness` e a app deriva o `themeMode` do tema ativo; o toggle manual foi removido. O tema `default` foi removido pela migration `006_remove_default_theme.sql` (catálogo e loja já não o oferecem); sem tema ativo a app usa `AppTheme.light`.
- **Ordem free-first (2026-08-10):** a migration `007_themes_order_free_first.sql` renumera `sort_order` dos temas (`light`=1, `default`=1, `dark`=2, `midnight`=3, `forest`=4, `sunset`=5, `ocean`=6, `autumn`=7, `galaxy`=8) e `get_user_themes` passa a ordenar gratuitos primeiro (`case when not is_premium and not is_paid then 0 else 1 end, sort_order`) — a loja mostra os temas livres no topo.
- **UI da loja na app (2026-08-10):** a página `/settings/themes` deixou de ter o banner "Desbloqueia os temas Premium" e a secção PREMIUM separada — todos os temas não-gratuitos ficam agrupados em **TEMAS PAGOS**. Tocar num tema premium abre um diálogo ("Ver planos" → `/settings/plans` ou "Obter no site" → `themes.html`); os temas pagos abrem a loja diretamente. A ativação de código ("Ativar código de tema") mantém-se.

## Agendamento do relatório (pg_cron)

Modo **batch**: lê `report_preferences` e envia a todos com `email_reports_enabled=true` cujo `report_day`/`report_hour` correspondam à invocação. Basta correr de hora em hora. O batch é ativado quando **não há `Authorization`** ou quando o header é a **`service_role`** (é o caso do cron); se houver um JWT de utilizador válido, envia só para esse utilizador (modo teste da app). Corrigido em 2026-08-10: antes, o cron (que envia `Authorization: Bearer <service_role>`) fazia `getUser()` devolver 403 → a função respondia 401 e **não enviava**; agora o JWT só é tratado como utilizador se `getUser()` validar, senão cai no batch (só se for service role).

**Aplicado** (2026-08-03): job `monthly-report-hourly` (jobid 2, schedule `0 * * * *`, active), com a `service_role` no Vault (`service_role_key`). Requisitos: extensões `pg_net` e `pg_cron` ativas.

> **Incidente 2026-08-10 (resolvido):** após uma rajada de envios de teste (~6 em 10 min) o Gmail começou a **descartar em silêncio** os emails (aceitava na fila, sem entrega nem bounce — até um endereço Gmail inexistente não devolvia `550`), coincidindo com o deploy do fix `due_day`. SPF/DKIM/DMARC/MX estavam todos corretos e o IP do Brevo não estava em blocklists. O *silent drop* foi **temporário** e passou sozinho em ~1-2h (os emails acumulados foram todos entregues). Lição: não fazer muitos envios de teste seguidos; para diagnosticar entrega usar um único envio por vez e esperar.

## Cloudflare Email Routing

Objetivo: encaminhar `geral@`, `suporte@`, `billing@`, `marketing@` para Gmail.

Configuração feita pelo script [`scripts/cloudflare-email-routing.ps1`](../scripts/cloudflare-email-routing.ps1) (API REST do Cloudflare — as ferramentas MCP do Cloudflare não expõem a zona/Email Routing).

> **Estado live verificado por DNS (2026-08-03):** routing ativo — MX `route1/2/3.mx.cloudflare.net` e SPF `include:_spf.mx.cloudflare.net` + `include:spf.brevo.com`. Falta confirmar a receção dos emails de verificação do Cloudflare nos destinos Gmail.

### Destinos e rotas

Todos os endereços encaminham para a única mailbox `pocketapps.dev.pt@gmail.com`; a distinção faz-se pelo campo **To original** (ex.: `suporte@pocketapps.pt`) preservado pela Cloudflare.

| Endereço local | Destino (Gmail) |
|---|---|
| `geral@` | `pocketapps.dev.pt@gmail.com` |
| `suporte@` | `pocketapps.dev.pt@gmail.com` |
| `billing@` | `pocketapps.dev.pt@gmail.com` |
| `marketing@` | `pocketapps.dev.pt@gmail.com` |

### Utilização

1. Preencher no topo do script: `$CF_API_TOKEN` (permissões de edição em *Email Routing Rules* e *Email Routing Addresses*) e `$CF_ACCOUNT_ID`. `$CF_ZONE_ID` é opcional (auto-descoberto pelo nome).
2. Executar `.\scripts\cloudflare-email-routing.ps1` (PowerShell, requer `curl.exe`). Se o routing já estiver ativo, usar `-SkipEnable`.
3. Confirmar os **emails de verificação** enviados pelo Cloudflare para os 4 destinos Gmail.

O script ativa o routing, cria destinos e regras (evitando duplicados) e termina com validação.

## Notas

- Preferência de stack: apenas serviços gratuitos.
- Gates de monetização que definem quando billing/marketing são usados: [`docs/monetizacao-stripe.md`](monetizacao-stripe.md).
