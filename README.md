# PocketApps

Monorepo das aplicações PocketApps.

## Estrutura

```
packages/
  pocketapps_auth/      # package Flutter partilhado (auth Supabase + Google, páginas de auth)
apps/
  pocket_expenses/      # gestão de despesas
  pocket_fuel/          # combustível e despesas do veículo (stub)
  pocket_shopping/      # listas de compras (stub)
supabase/
  functions/            # edge functions partilhadas (send-welcome-email, delete-account)
  schema.sql            # schema completo da base de dados
```

## Autenticação partilhada

Cada app define um `AuthConfig` (`lib/config/app_config.dart`) com
`appName`, credenciais Supabase, deep-link de callback e branding, e
inicializa o auth no `main()`:

```dart
await PocketAuth.initialize(appAuthConfig);
```

O `appName` separa os dados entre apps (`user_app_access` na base de dados),
e toda a UI/logica de auth, as edge functions e o schema são partilhados.

## Desenvolvimento

```sh
# dependências de todas as apps/package
cd packages/pocketapps_auth && flutter pub get
cd apps/pocket_expenses && flutter pub get && flutter run
```

## Base de dados (Supabase)

- `supabase/schema.sql` é a fonte de verdade do schema.
- `supabase/functions/*` são as edge functions (deploy via Supabase CLI).

## CI

`.github/workflows/build.yml` compila o APK de `apps/pocket_expenses` em cada push para `main`.
