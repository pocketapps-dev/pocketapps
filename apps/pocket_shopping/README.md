# PocketShopping

> Shopping lists that keep your budget on track. **In development.**

PocketShopping is part of the [PocketApps](../..) monorepo and reuses the shared
authentication package and Supabase backend.

## Roadmap

- Shared shopping lists across devices
- Store-specific categories and favorite products
- Price comparison and purchase history
- Budget tracking per list and per month

## Development

```sh
flutter pub get
flutter run
```

The app's branding and Supabase configuration live in `lib/config/app_config.dart`.

[![Build PocketShopping APK](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-shopping.yml/badge.svg)](https://github.com/pocketapps-dev/pocketapps/actions/workflows/build-shopping.yml)
