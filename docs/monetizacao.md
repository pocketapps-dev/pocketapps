# Monetização — PocketApps

> Documento de referência para a estratégia de monetização. Atualizado em 2026-08-01.

## Modelo de planos

| Plano | Tipo | Preço | Inclui |
|-------|------|-------|--------|
| **Free** | — | 0€ | 10 despesas ativas, 10 categorias, anúncios, sem editar categorias |
| **Premium** | Recorrente | 1,49€/mês | Tudo: ilimitado, sem anúncios, widgets, relatórios, wizard, 3 temas |
| **Premium Anual** | Recorrente | 14,99€/ano | Tudo do Premium + 3 temas |
| **Founder** | One-time | 29,99€ (50% off de 59,98€) | Tudo + todas as apps (bundle), lifetime + early access |

## Loja de temas (à la carte)

- **Premium** inclui 3 temas exclusivos (midnight, forest, sunset)
- **Loja de temas**: temas adicionais à venda por 0,99€ cada (compra única, lifetime)
- Exemplo: ocean, autumn, galaxy, rose

## Fase 1 — Anúncios no Plano Free

- **Native** no dashboard (integrado, discreto)
- **Banner** no rodapé da lista de despesas
- **Interstitial** máx. 1x/dia, apenas após criar despesa
- **Rewarded** opcional: "Desbloquear com anúncio" no paywall
- **Gate**: Free = anúncios · Premium/Founder = zero anúncios
- **Implementação**: `google_mobile_ads` (AdMob) + Google UMP para consentimento RGPD
- **Estimativa**: ~0,63€/user/mês

## Fase 2 — Gates de Limite

- **Despesas ativas**: Free = 10 máx · Premium = ilimitado
- **Categorias**: Free = 10 máx · Premium = ilimitadas
- **Editar categorias**: Premium (Free pode criar e apagar)
- **Implementação**: `ExpenseActions.create()`, `CategoryActions.create()`, `CategoryActions.update()`, `CategoriesPage`
- **Paywall dialog**: `premium_gate_dialog.dart` reutilizável

## Fase 3 — Temas Premium

- **Free**: light + dark
- **Premium**: +3 temas (midnight, forest, sunset)
- **Loja de temas**: temas adicionais à venda (0,99€ cada)
- **Implementação**: `theme_models.dart`, `AppTheme` com seedColor dinâmico, gate no `PreferencesPage`

## Fase 4 — Código Founder (Bundle)

- Acesso completo a todas as apps (expenses + fuel + shopping) a 29,99€ (50% de desconto)
- **Backend**: migration SQL — check constraints aceitam `'all'`; RPC `validate_activation_code` ativa as 3 apps
- **App**: dialog de ativação aceita códigos `all`

## Fase 5 — Relatórios Elaborados

- **Free**: relatórios básicos (total + categorias)
- **Premium**: relatórios elaborados (Δ% vs mês anterior, top 3 categorias, recorrentes vs únicas, dica de poupança)
- **Implementação**: edge function `send-monthly-report` verifica subscrição

## Fase 6 — Widgets Home Screen

- **Free**: página inicial normal
- **Premium**: widgets na página inicial (próximas despesas, total do mês)
- **Implementação**: `home_widget` package + configuração nativa + cache local

## Fase 7 — Wizard Premium

- **Free**: formulário simples (`ExpenseFormPage`)
- **Premium**: wizard completo (`ExpenseWizardPage` — 7 passos)
- **Implementação**: gate no acesso ao wizard

## Ordem de implementação

| Sprint | Fases | Esforço |
|--------|-------|---------|
| Sprint 1 | Fase 1 (anúncios) + Fase 2 (gates) | ~5-6 dias |
| Sprint 2 | Fase 3 (temas) + Fase 7 (wizard) | ~4-5 dias |
| Sprint 3 | Fase 4 (founder bundle) + Fase 5 (relatórios) | ~5-6 dias |
| Sprint 4 | Fase 6 (widgets) | ~3-5 dias |

## Notas

- `Subscription.isActive` já funciona para founder (endsAt futuro)
- Widgets requerem configuração nativa (AndroidManifest/Info.plist)
- Website (venda de códigos/temas) é trabalho separado — a app só consome
