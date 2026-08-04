# PocketApps — Site (feature)

> Site institucional num repo separado, git-ignored no monorepo principal.
> Atualizado em 2026-08-04.

## Visão geral

- Repo: `pocketapps.github.io` (branch `main`).
- As páginas do site **não** são versionadas no repo principal (git-ignored).
- Stack: HTML/CSS/JS estáticos (sem framework).
- Deploy: **Cloudflare Pages** ligado ao GitHub (push para `main` → build automático). O domínio `pocketapps.github.io` **não** está ativo (404) — o site real é `https://pocketapps.pt`. O Cloudflare Pages faz 307 de `foo.html` → `foo` (clean URLs).

## Estrutura

- Páginas: `index.html`, `conta.html`, `apps.html`, `features.html`, `pricing.html`, `themes.html`, `contact.html`, `ativar.html`, `terms.html`, `privacy.html`.
- Assets: `style.css`, `layout.js`, `config.js`.
- Diretório `apk/`: aloja o APK do PocketExpenses, atualizado automaticamente por CI (`build-expenses.yml`).

## Fluxo de autenticação (2026-08-04)

- **Navbar mínima**: logo à esquerda, toggle de tema + **Entrar** / **Criar conta** à direita. Links internos (Apps, Features, Preços, Temas) só aparecem no menu de utilizador autenticado.
- **`conta.html`** — página dedicada de login/signup (email/palavra-passe + Google), espelha o auth do app (RPCs `check_app_access`/`add_app_access`, metadados de consentimento, confirmação por email). Suporta `?redirect=apps|features|pricing|themes` para voltar à página pretendida após login.
- **Páginas protegidas** (exigem sessão; redirecionam para `/conta.html?redirect=...`):
  - `apps.html`, `features.html`, `pricing.html`, `themes.html`
- **Páginas públicas**: `index.html` (homepage), `conta.html`, `contact.html`, `ativar.html`, `terms.html`, `privacy.html`.
- **Popup de cookies** (RGPD): aparece na primeira visita, com "Aceitar"/"Recusar", escolha guardada em `localStorage`.

## Configuração central de preços/promoções

- **`config.js`** — ficheiro central com preços e promoções (`window.POCKETAPPS_CONFIG`). Editar aqui para mudar preços/promoções em todas as páginas.
- Premium: `€17.88` por ano · `€1.49/mês` (preço total anual visível).
- Founder: `€29.99` pagamento único · `50% OFF` (de `€59.99`).

## Monetização no site

- Preços/links em `pricing.html` e `themes.html`; `APP_NAME = 'expenses'` em ambas; `SUPABASE_URL = https://vlbhnlzqixmxtlpqsggd.supabase.co`.
- Botões mock `buy.stripe.com/TODO_*` → decisão de 2026-08: mostrar **"Em breve"** desativado enquanto não houver link real. Voltar a "Comprar" automaticamente quando os links reais forem inseridos.
- **Loja de temas na app (2026-08-04)**: a página `/settings/themes` do PocketExpenses abre `https://pocketapps.pt/themes.html` para comprar os temas pagos (Ocean, Autumn, Galaxy) — os temas comprados sincronizam via `get_user_themes`.
- **TODOs a substituir quando os Payment Links Stripe existirem**:
  - `themes.html`: `ocean` / `autumn` / `galaxy`
  - `pricing.html`: `premium` / `annual` / `founder`
  - Ver [`docs/monetizacao-stripe.md`](monetizacao-stripe.md) para o plano de Payment Links.
- Páginas legais publicadas: `https://pocketapps.pt/terms` e `/privacy` (HTTP 200) — rascunhos fonte em [`docs/legal/`](legal/).

## Relacionados

- Plano de pagamentos/metadata do webhook: [`docs/monetizacao-stripe.md`](monetizacao-stripe.md).
- Auth (Site URL `https://pocketapps.pt` + allowlist de redirects): [`docs/auth.md`](auth.md).