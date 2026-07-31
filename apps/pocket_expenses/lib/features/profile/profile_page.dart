import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import '../../core/providers/profile_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.watch(supabaseClientProvider);
    final user = supabase.auth.currentUser;
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);

    final username = profile.value?['username'] ?? '';
    final currency = settings.value?['currency'] ?? 'EUR';
    final notifications = settings.value?['notifications_enabled'] ?? true;
    final isEmailUser = user?.identities?.any((i) => i.provider != 'google') ?? true;

    final currencySymbols = {
      'EUR': '€',
      'USD': '\$',
      'GBP': '£',
      'BRL': 'R\$',
      'JPY': '¥',
      'CHF': 'CHF',
      'CAD': 'CA\$',
      'AUD': 'A\$',
      'PLN': 'zł',
      'CZK': 'Kč',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(
              username.isNotEmpty
                  ? username[0].toUpperCase()
                  : (user?.email?[0].toUpperCase() ?? '?'),
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '@$username',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Perfil
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Editar Perfil'),
                  subtitle: const Text('Username'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/edit'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Moeda'),
                  subtitle: Text(
                    '$currency (${currencySymbols[currency] ?? currency})',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/currency'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notificações e Tema
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificações'),
                  subtitle: const Text('Lembretes de pagamentos'),
                  value: notifications,
                  onChanged: (value) {
                    ref.read(profileActionsProvider).updateNotifications(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Premium (stub)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.star_outline, color: Colors.amber),
                  title: const Text('PocketExpenses Premium'),
                  subtitle: const Text('Em breve'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium em breve!')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Código de Ativação'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium em breve!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Conta
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Eliminar Conta',
                    style: TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/delete-account'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Terminar Sessão',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    await supabase.auth.signOut();
                    if (context.mounted) context.go('/auth');
                  },
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
