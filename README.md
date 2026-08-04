<div align="center">

# PocketApps

**Expenses · Fuel · Shopping** — a family of personal finance apps sharing one codebase and one auth system.

Flutter · Supabase · Monorepo

</div>

## Overview

PocketApps is a [Flutter](https://flutter.dev) monorepo with a shared authentication package and a common
[Supabase](https://supabase.com) backend. Each app is a separate product that reuses the same auth flow,
edge functions and database schema.

| App | Purpose | Status |
| --- | --- | --- |
| [PocketExpenses](apps/pocket_expenses) | Track recurring and one-off expenses | Active |
| [PocketFuel](apps/pocket_fuel) | Fuel, tolls and vehicle costs | Stub |
| [PocketShopping](apps/pocket_shopping) | Shopping lists and purchases | Stub |

## Repository structure

```
packages/
  pocketapps_auth/      Shared Flutter package: Supabase + Google auth, auth pages
apps/
  pocket_expenses/      Expense tracker
  pocket_fuel/          Vehicle & fuel costs (stub)
  pocket_shopping/      Shopping lists (stub)
supabase/
  functions/            Shared edge functions (send-welcome-email, send-monthly-report,
                        delete-account, report-unsubscribe)
  schema.sql            Source of truth for the database schema
scripts/
  cloudflare-email-routing.ps1  Cloudflare Email Routing setup (destinations + rules)
docs/
  auth.md               Authentication (Supabase Auth + Google, dashboard setup)
  backend.md            Supabase backend: schema, RPCs, edge functions, transactional email
  site.md               Marketing site (pocketapps.github.io)
  monetizacao-stripe.md Monetization/Stripe: plans, phases, operational status
.github/
  workflows/            CI pipeline
```

## Shared authentication

Every app defines an `AuthConfig` in `lib/config/app_config.dart` (`appName`, Supabase credentials,
deep-link callback and branding) and initializes the shared auth in `main()`:

```dart
await PocketAuth.initialize(appAuthConfig);
```

The `appName` scopes data per app (via `user_app_access` in the database), while all auth UI, logic,
edge functions and the schema are shared.

See [`docs/auth.md`](docs/auth.md) for the full auth setup (flows, deep links, dashboard config).

## Getting started

```sh
# Install dependencies
cd packages/pocketapps_auth && flutter pub get
cd apps/pocket_expenses && flutter pub get

# Run an app
cd apps/pocket_expenses && flutter run
```

Each app requires a Supabase project and a Google OAuth client — see the app READMEs.

## Email

Transactional email is sent through the Brevo SMTP relay via shared edge functions.
See [`docs/backend.md`](docs/backend.md) (Email section) for the full setup (senders, DNS, functions, secrets).

## CI

Each app has its own workflow, badge and APK artifact:

| App | Workflow | Status |
| --- | --- | --- |
| PocketExpenses | [`build-expenses.yml`](.github/workflows/build-expenses.yml) | [![Build PocketExpenses APK](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-expenses.yml/badge.svg)](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-expenses.yml) |
| PocketFuel | [`build-fuel.yml`](.github/workflows/build-fuel.yml) | [![Build PocketFuel APK](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-fuel.yml/badge.svg)](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-fuel.yml) |
| PocketShopping | [`build-shopping.yml`](.github/workflows/build-shopping.yml) | [![Build PocketShopping APK](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-shopping.yml/badge.svg)](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-shopping.yml) |

PocketExpenses builds on every push to `main`; PocketFuel and PocketShopping build on demand (`workflow_dispatch`).
