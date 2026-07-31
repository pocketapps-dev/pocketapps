# PocketExpenses

Aplicação de gestão de despesas recorrentes.

Parte do monorepo [PocketApps](../../README.md).

## Desenvolvimento

```sh
flutter pub get
flutter run
```

A autenticação (Supabase + Google) é partilhada entre todas as apps do monorepo e vive em `packages/pocketapps_auth`. A configuração específica da app está em `lib/config/app_config.dart`.
