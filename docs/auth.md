# PocketApps — Autenticação (feature)

> Auth partilhada entre as apps (Supabase Auth + Google).
> Atualizado em 2026-08-03.

## Visão geral

- Pacote partilhado: `packages/pocketapps_auth`.
- Config por app: `AuthConfig` em `lib/config/app_config.dart` de cada app.
- Inicialização: `await PocketAuth.initialize(appAuthConfig)`.
- Providers: email/password + Google.
- Backend `APP_NAME`: `expenses`.

## Fluxos implementados

`packages/pocketapps_auth/lib/src/auth_service.dart`:

| Fluxo | Localização |
|---|---|
| Sign up com confirmação por email (`emailRedirectTo`) | `signUp` (linhas 71–87) |
| Login email/password | `signInWithPassword` (linha 107) |
| Callback de auth (deep link da app) | — |
| Reset de password | — |
| Mudar email / mudar password | — |
| Apagar conta | edge function `delete-account` |

## Configuração no dashboard Supabase (manual — passos 2–3 da monetização)

Auth → Providers:

1. **Email**: Enable + **Confirm email** = ON (é o email de confirmação que gera o magic link no `signUp`). ✅ Ativo no remoto (`external_email_enabled=true`, `mailer_autoconfirm=false`).
   - **Custom SMTP** ✅ configurado (2026-08-03, via Management API) com Brevo Relay — ver [`docs/backend.md`](backend.md) secção "Supabase Auth — Custom SMTP".
2. **Redirect URLs** (URLs exatos — o wildcard `/**` é pouco fiável em produção):
   - `pt.pocketapps.pocketexpenses://auth-callback`
   - `pt.pocketapps.pocketfuel://auth-callback`
   - `pt.pocketapps.pocketshopping://auth-callback`
   - `https://pocketapps.pt` · `https://pocketapps.pt/themes` · `https://pocketapps.pt/themes.html` · `https://pocketapps.pt/pricing` · `https://pocketapps.pt/pricing.html`
   - `https://pocketapps.github.io` · `https://pocketapps.github.io/themes.html` · `https://pocketapps.github.io/pricing.html`
   - Nota: o Cloudflare Pages faz 307 de `foo.html` → `foo`, e `window.location.href` do site é a URL canónica (`/themes`). Por isso é preciso BOTH (`/themes` e `/themes.html`). Um redirect no destino perderia o fragmento `#access_token` e partia o login — usar sempre a URL canónica no allowlist.
3. **Site URL**: ✅ `https://pocketapps.pt` (corrigido 2026-08-03 — antes `pt.pocketapps.pocketexpenses://`, que fazia o clique do magic link do site não levar a lado nenhum)

## Auth no site (`pocketapps.github.io` — repo separado)

O site usa o **mesmo** projeto Supabase/anon key e os **mesmos RPCs** do app (`check_app_access`, `add_app_access`).

### Páginas com auth

| Página | Fluxo |
|---|---|
| `index.html` (homepage) | Botão **Entrar** (redireciona para `conta.html`) — a homepage tem apenas CTA "Entrar". Login/signup dedicado está em `conta.html`. (2026-08-04) |
| `themes.html` | Magic link (`signInWithOtp` + `emailRedirectTo: window.location.href`) |
| `pricing.html` | Magic link (idem) |

### Homepage (`index.html` — login/signup, espelha `auth_service.dart`)

- **Entrar**: `signInWithPassword` → RPC `check_app_access`; sem acesso à app → "Não tens conta nesta app." (e faz `signOut`).
- **Criar conta**: `signUp` com `data: { app_name, privacy_accepted, terms_accepted, age_confirmed }` (mesmos metadados do app) + `emailRedirectTo: https://pocketapps.pt/`. Com `mailer_autoconfirm=false` o user **confirma por email** antes do 1º login. "Already registered" → RPC `add_app_access` + mensagem "Conta encontrada! Faz login."
- **Google** (2026-08-04): `signInWithOAuth({ provider: 'google', redirectTo: 'https://pocketapps.pt/conta.html?google=1' })` — o redirect volta para `conta.html?google=1`; acesso à app concedido automaticamente via `add_app_access` (provider `google` no `app_metadata`). **Novos users Google** → consent dialog (privacy + terms + idade, igual ao `_ConsentDialog` da app Flutter) + welcome email — antes de serem redirecionados para a homepage. Users existentes são redirecionados direto.
- Navbar: após login, mostra o **email** do utilizador (em vez de "Entrar").

### Bugs resolvidos (2026-08-03)

- **`SyntaxError: Identifier 'supabase' has already been declared`**: o UMD do `supabase-js@2` do CDN declara `var supabase` global; o site declarava `const supabase` → **o script inteiro crashava** e o botão do magic link não fazia nada (sem mensagem). Corrigido renomeando a variável local para `supabaseClient` em `themes.html` e `pricing.html`.
- **`signInWithPassword` do SDK v2 devolve `{data, error}`** (não atira exceção) — o login da homepage verifica `error` e `data.user` antes de continuar.

## Relacionados

- Email transacional (boas-vindas, delete-account): [`docs/backend.md`](backend.md) — secção Email.
- Edge function `delete-account`: [`docs/backend.md`](backend.md).
