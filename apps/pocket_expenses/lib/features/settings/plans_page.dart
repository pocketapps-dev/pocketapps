import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/subscription_provider.dart';
import 'activation_code_dialog.dart';

class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link. Tenta novamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider).value;
    final isPremium = subscription?.isActive == true;
    final planName = subscription?.displayName ?? 'Free';
    final activeKey = subscription?.plan ?? 'free';
    final founderCount = ref.watch(founderCountProvider).value ?? 0;
    final founderDiscount = founderCount < 5;

    return Scaffold(
      appBar: AppBar(title: const Text('Planos e Preços')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isPremium
                        ? Colors.amber.shade100
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      isPremium
                          ? Icons.workspace_premium
                          : Icons.person_outline,
                      color: isPremium
                          ? Colors.amber.shade800
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'PocketExpenses $planName' : 'Plano Free',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPremium
                              ? 'Ativo até ${_formatDate(subscription?.endsAt)}'
                              : 'Estás a usar o plano gratuito',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'ESCOLHE O TEU PLANO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          _PricingCard(
            icon: Icons.person_outline,
            name: 'Free',
            price: '€0',
            priceNote: 'para sempre',
            features: const [
              'Todas as funcionalidades base',
              'Categorias ilimitadas',
              'Backup manual',
              'Notificações',
              'Sem anúncios',
            ],
            active: activeKey == 'free',
            recommended: false,
          ),
          _PricingCard(
            icon: Icons.workspace_premium,
            name: 'Premium',
            price: '€14.99',
            priceNote: 'por ano · €1.49/mês',
            features: const [
              'Tudo do Free',
              'Relatórios por email',
              'Backup automático na cloud',
              'Exportar dados avançado',
              'Suporte prioritário',
            ],
            active: activeKey == 'premium',
            recommended: true,
          ),
          _PricingCard(
            icon: Icons.emoji_events_outlined,
            name: 'Founder',
            price: founderDiscount ? '€37.50' : '€75',
            priceNote: founderDiscount
                ? '3 apps · pagamento único · 50% OFF (€25/app)'
                : '3 apps · pagamento único · €25/app · Lifetime',
            features: const [
              'Tudo do Premium',
              'Acesso antecipado a novas apps',
              'Nome na página de créditos',
              'Acesso a betas',
              'Voto em novas funcionalidades',
            ],
            active: activeKey == 'founder',
            recommended: false,
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: () =>
                _openUrl(context, 'https://pocketapps.pt/pricing.html'),
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('Comprar no website'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Após a compra no website recebes um código de ativação.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Já tens um código?'),
                  subtitle: const Text('Ativa o plano Premium'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showActivationCodeDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Contacto'),
                  subtitle: const Text('geral@pocketapps.pt'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openUrl(context, 'mailto:geral@pocketapps.pt'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'indeterminado';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PricingCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String price;
  final String priceNote;
  final List<String> features;
  final bool active;
  final bool recommended;

  const _PricingCard({
    required this.icon,
    required this.name,
    required this.price,
    required this.priceNote,
    required this.features,
    required this.active,
    required this.recommended,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accent = recommended
        ? theme.colorScheme.primary
        : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active ? theme.colorScheme.primary : Colors.grey.shade200,
          width: active ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ATUAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  priceNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 18, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
