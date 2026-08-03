# Emails — Infraestrutura PocketApps

## Visão geral

O envio de emails da PocketApps usa o **Brevo** como relay transacional, com SMTP a partir das Edge Functions do Supabase. O domínio `pocketapps.pt` está autenticado no Brevo e os registos DNS necessários estão verificados, pelo que não há edições DNS pendentes.

## Arquitetura

```
App (Flutter)
   │  Supabase Auth (signup / delete account) · cron mensal (opcional)
   ▼
Edge Function (Supabase)  ── SMTP (nodemailer) ──►  Brevo Relay (smtp-relay.brevo.com:587)
                                                      │
                                                      ▼
                                            Mailbox(es) destinatário
```

- As funções leem credenciais SMTP de secrets do Supabase (variáveis de ambiente).
- Os emails são enviados a partir de `no-reply@pocketapps.pt` com `reply-to` para `suporte@pocketapps.pt`.

## Brevo — Senders

| id | Endereço | Estado |
| --- | --- | --- |
| 1 | `pocketapps.dev.pt@gmail.com` | Ativo |
| 2 | `no-reply@pocketapps.pt` | Ativo |
| 3 | `suporte@pocketapps.pt` | Ativo |
| 4 | `billing@pocketapps.pt` | Ativo |
| 5 | `marketing@pocketapps.pt` | Ativo |

## Brevo — Domínio e DNS

- Domínio `pocketapps.pt` — `authenticated: true`, `verified: true`, provider Cloudflare, authenticator `pocketapps.dev.pt@gmail.com`.
- Verificação pública (todos ✅):
  - TXT `brevo-code:cdb0ba6a2afcc66ecd2dec927c68e1a9`
  - CNAME `brevo1._domainkey` → `b1.pocketapps-pt.dkim.brevo.com`
  - CNAME `brevo2._domainkey` → `b2.pocketapps-pt.dkim.brevo.com`
  - `_dmarc` → `p=none`

## Edge Functions

| Função | Versão deployed | verify_jwt | Import map | Emails |
| --- | --- | --- | --- | --- |
| `send-welcome-email` | 46 | true | `deno.json` | Boas-vindas por app (`expenses`/`fuel`/`shopping` via `APP_CONFIG`) |
| `send-monthly-report` | 9 | true | `deno.json` | Relatório mensal (simple/detailed) |
| `delete-account` | 46 | true | `deno.json` | Confirmação de eliminação de conta |
| `report-unsubscribe` | 4 | false | — | Sem SMTP (não envia email) |

### Reply-to

As funções com SMTP enviam com `replyTo` explícito:

```ts
const replyTo = Deno.env.get("SMTP_REPLY_TO") || "suporte@pocketapps.pt";
```

## Secrets (a definir no Supabase)

Os secrets **não são definíveis via MCP** — executar com a CLI (a partir de `supabase/functions`):

```sh
supabase secrets set \
  SMTP_HOST=smtp-relay.brevo.com \
  SMTP_PORT=587 \
  SMTP_USER=<utilizador_brevo> \
  SMTP_PASS=<senha_brevo> \
  SMTP_FROM=no-reply@pocketapps.pt \
  SMTP_REPLY_TO=suporte@pocketapps.pt
```

Defaults no código: host `smtp-relay.brevo.com`, porta `587`, `SMTP_FROM=no-reply@pocketapps.pt`, `SMTP_REPLY_TO=suporte@pocketapps.pt`.

## Relatório mensal — tipos (simple / detailed)

O `send-monthly-report` suporta dois formatos, controlados pela coluna `report_preferences.report_type`:

- `simple` — cabeçalho + linha de estatísticas (Total/Recorrentes/Únicas/Despesas) + CTA; sem categorias nem gráficos.
- `detailed` (padrão) — além das estatísticas, inclui a quebra por categoria (barras HTML) e, se `include_charts`, os indicadores de total do mês e categorias usadas.

Precedência na função: `body.report_type` → `report_preferences.report_type` → `'detailed'`. A preferência é definida na app (Flutter) nas definições do relatório e gravada com `report_type` no upsert de `report_preferences` (o `report_provider.dart` usa `'detailed'` como fallback).

A migração correspondente (`supabase/migrations/002_report_type.sql`) aplica a coluna com `add column if not exists`, mantendo o valor existente (`detailed`) para quem já tinha preferências.

## Agendar o relatório mensal (pg_cron)

O `send-monthly-report` em modo **batch** (sem `Authorization`) lê `report_preferences` e envia a todos os utilizadores com `email_reports_enabled=true` cujo `report_day`/`report_hour` correspondam ao momento da invocação. O job só envia para quem deve, pelo que basta correr de hora em hora.

**Aplicado** (2026-08-03) no projeto `vlbhnlzqixmxtlpqsggd`: job `monthly-report-hourly` (jobid 2, schedule `0 * * * *`, active), com a `service_role` guardada no Vault (`service_role_key`). SQL de referência:

```sql
select cron.schedule('monthly-report-hourly', '0 * * * *', $net$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-monthly-report',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
      'Content-Type', 'application/json'
    ),
    body := '{}'
  )
$net$);
```

Requisitos: extensão `pg_net` (e `pg_cron`) ativas no Supabase; `<SERVICE_ROLE_KEY>` em secret no Postgres (ex.: via `supabase secrets` não aplicável — usar `ALTER ROLE`/Dashboard).

## Cloudflare Email Routing

Objetivo: encaminhar `geral@`, `suporte@`, `billing@`, `marketing@` para Gmail.

A configuração é feita pelo script [`scripts/cloudflare-email-routing.ps1`](../scripts/cloudflare-email-routing.ps1)
(API REST do Cloudflare) porque as ferramentas MCP do Cloudflare não expõem a zona/Email Routing
(a listagem de zonas devolveu vazia).

> **Estado live verificado por DNS (2026-08-03):** o routing está ativo — MX `route1/2/3.mx.cloudflare.net`
> e SPF com `include:_spf.mx.cloudflare.net` + `include:spf.brevo.com`. Falta apenas confirmar a
> receção dos emails de verificação do Cloudflare nos destinos Gmail.

### Destinos e rotas

Todos os endereços encaminham para a **única mailbox** `pocketapps.dev.pt@gmail.com`.
A distinção por produto/área faz-se pelo campo **To original** preservado pela Cloudflare
(por ex. `suporte@pocketapps.pt`), podendo criar-se filtros Gmail por destinatário.

| Endereço local | Destino (Gmail) |
| --- | --- |
| `geral@` | `pocketapps.dev.pt@gmail.com` |
| `suporte@` | `pocketapps.dev.pt@gmail.com` |
| `billing@` | `pocketapps.dev.pt@gmail.com` |
| `marketing@` | `pocketapps.dev.pt@gmail.com` |

### Utilização

1. Preencher no topo do script: `$CF_API_TOKEN` (permissões de edição em *Email Routing Rules* e
   *Email Routing Addresses*) e `$CF_ACCOUNT_ID`. `$CF_ZONE_ID` é opcional (auto-descoberto pelo nome).
2. Executar `.\scripts\cloudflare-email-routing.ps1` (PowerShell, requer `curl.exe`).
   Se o routing já estiver ativo, usar `-SkipEnable` (o endpoint `/email/routing/enable`
   precisa de um token com permissão de zona — `CF_API_TOKEN` com *Zone > Email Routing Rules*).
3. Confirmar os **emails de verificação** enviados pelo Cloudflare para os 4 destinos Gmail.

O script ativa o routing (`POST /zones/{zone_id}/email/routing/enable`), cria os destinos
(`/accounts/{account_id}/email/routing/addresses`) e as regras (`/zones/{zone_id}/email/routing/rules`),
evitando duplicados, e termina com uma validação que lista destinos e rotas existentes.

## Notas

- Preferência de stack: apenas serviços gratuitos.
- `docs/monetizacao.md` descreve os planos/gates que definem quando cada tipo de email (billing, marketing) é usado.
