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

- **Navbar mínima**: logo à esquerda, toggle de tema + **Entrar** à direita. Links internos (Apps, Features, Preços, Temas) só aparecem no menu de utilizador autenticado. Após login, mostra o **email** do utilizador em vez de "Entrar".
- **`conta.html`** — página dedicada de login/signup (email/palavra-passe + Google), espelha o auth do app (RPCs `check_app_access`/`add_app_access`, consent dialog para novos users Google, welcome email, metadados de consentimento, confirmação por email). Suporta `?redirect=apps|features|pricing|themes` para voltar à página pretendida após login.
- **Páginas protegidas** (exigem sessão; redirecionam para `/conta.html?redirect=...`):
  - `apps.html`, `features.html`, `pricing.html`, `themes.html`
- **Páginas públicas**: `index.html` (homepage), `conta.html`, `contact.html`, `ativar.html`, `terms.html`, `privacy.html`.
- **Popup de cookies** (RGPD): aparece na primeira visita, com "Aceitar"/"Recusar", escolha guardada em `localStorage`.

## Configuração central de preços/promoções

- **`config.js`** — ficheiro central com preços e promoções (`window.POCKETAPPS_CONFIG`). Editar aqui para mudar preços/promoções em todas as páginas.
- Premium: `€14.99` por ano · `€1.49/mês` · "todas as apps" (`plans.premium.priceTotal`).
- Founder: `€25`/app × `appCount: 3` = **`€75`** pagamento único · `50% OFF` no total enquanto `founder_count < 5` (`plans.founder.promotionThreshold`).

## Monetização no site

- Preços/links em `pricing.html` e `themes.html`; `APP_NAME = 'expenses'` em ambas; `SUPABASE_URL = https://vlbhnlzqixmxtlpqsggd.supabase.co`.
- Botões mock `buy.stripe.com/TODO_*` → decisão de 2026-08: botões **"Comprar" desativados** com labels dinâmicos lidos do `config.js` (`makeBuyButton` em `pricing.html`, ex.: "Comprar Premium · €14.99/ano", "Comprar Founder · €37.50"). Voltar a ativos quando os links reais forem inseridos. `themes.html` mantém "Em breve".
- **Fluxo de planos app → site (2026-08-08)**: o card de topo de Definições e o `_PlanCard` da Conta (PocketExpenses) navegam para `/settings/plans`; o botão "Comprar no website" da página de planos abre `https://pocketapps.pt/pricing.html`, onde o utilizador autenticado vê os botões de compra acima.
- **Loja de temas na app (2026-08-04)**: a página `/settings/themes` do PocketExpenses abre `https://pocketapps.pt/themes.html` para comprar os temas pagos — os temas comprados sincronizam via `get_user_themes`.
- **Temas premium compráveis individualmente (2026-08-06)**: todos os temas (incluindo os 3 do Premium: Midnight, Forest, Sunset) mostram "Comprar" (0,99€) para users free — quem tem Premium vê "Incluído no Premium". Se um user free comprar um tema e depois aderir ao Premium, a compra mantém-se (não é perdida).
- **TODOs a substituir quando os Payment Links Stripe existirem**:
  - `themes.html`: `midnight` / `forest` / `sunset` / `ocean` / `autumn` / `galaxy`
  - `pricing.html`: `premium` / `annual` / `founder`
  - Ver [`docs/monetizacao-stripe.md`](monetizacao-stripe.md) para o plano de Payment Links.
- Páginas legais publicadas: `https://pocketapps.pt/terms` e `/privacy` (HTTP 200) — rascunhos fonte em [`docs/legal/`](legal/).

## Relacionados

- Plano de pagamentos/metadata do webhook: [`docs/monetizacao-stripe.md`](monetizacao-stripe.md).
- Auth (Site URL `https://pocketapps.pt` + allowlist de redirects): [`docs/auth.md`](auth.md).