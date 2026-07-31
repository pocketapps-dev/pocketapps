# PocketFuel

> Track fuel, tolls, insurance and every cost of owning a vehicle. **In development.**

PocketFuel is part of the [PocketApps](../..) monorepo and reuses the shared
authentication package and Supabase backend.

## Roadmap

- Refueling log (liters, price, per-100km consumption)
- Tolls and parking
- Maintenance, inspection, insurance and road tax reminders
- Monthly and yearly cost summaries

## Development

```sh
flutter pub get
flutter run
```

The app's branding and Supabase configuration live in `lib/config/app_config.dart`.

[![Build PocketFuel APK](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-fuel.yml/badge.svg)](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-fuel.yml)
