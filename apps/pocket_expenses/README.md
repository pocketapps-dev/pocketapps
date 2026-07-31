# PocketExpenses

> Track recurring and one-off expenses, and never miss a payment.

PocketExpenses is part of the [PocketApps](../..) monorepo and reuses the shared
authentication package and Supabase backend.

## Features

- Recurring and one-off expenses
- Monthly status per expense (paid / skipped / variable amount)
- Budget by category with monthly summaries
- Reminders for upcoming payments
- CSV export

## Development

```sh
flutter pub get
flutter run
```

The app's branding and Supabase configuration live in `lib/config/app_config.dart`.
Authentication (Supabase + Google) is shared across all PocketApps in `packages/pocketapps_auth`.

## CI

`.github/workflows/build.yml` builds the signed release APK on every push to `main`.
