import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import '../../core/providers/subscription_provider.dart';
import 'activation_code_dialog.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = PocketAuth.client;
    final user = supabase.auth.currentUser;
    final isEmailUser = user?.identities?.any((i) => i.provider != 'google') ?? true;

    final subscription = ref.watch(subscriptionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlanCard(subscription: subscription),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                if (isEmailUser)
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Alterar Email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile/change-email'),
                  ),
                if (isEmailUser)
                  const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outlined),
                  title: const Text('Alterar Palavra-passe'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/change-password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Código de Ativação'),
                  subtitle: const Text('Ativa o plano Premium'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showActivationCodeDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Exportar dados'),
                  subtitle: const Text('Descarrega os teus dados (JSON/CSV)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/export'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Eliminar Conta',
                    style: TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/delete-account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.subscription});

  final dynamic subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = subscription?.isActive == true;
    final planName = subscription?.displayName ?? 'Free';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isPremium
                  ? Colors.amber.shade100
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                isPremium ? Icons.star : Icons.person,
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? 'Ativo até ${_formatDate(subscription.endsAt)}'
                        : 'Ativa o Premium com um código',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'indeterminado';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
