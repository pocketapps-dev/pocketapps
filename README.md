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
  functions/            Shared edge functions (send-welcome-email, delete-account)
  schema.sql            Source of truth for the database schema
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

## Getting started

```sh
# Install dependencies
cd packages/pocketapps_auth && flutter pub get
cd apps/pocket_expenses && flutter pub get

# Run an app
cd apps/pocket_expenses && flutter run
```

Each app requires a Supabase project and a Google OAuth client — see the app READMEs.

## CI

`.github/workflows/build.yml` builds the PocketExpenses release APK on every push to `main`.

[![Build PocketExpenses APK](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build.yml/badge.svg)](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build.yml)
