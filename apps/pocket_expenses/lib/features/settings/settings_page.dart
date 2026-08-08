import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import '../../core/providers/profile_provider.dart';
import '../../core/providers/subscription_provider.dart';
import '../categories/categories_page.dart';
import '../profile/profile_page.dart';
import 'account_page.dart';
import 'preferences_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = PocketAuth.client;
    final user = supabase.auth.currentUser;
    final profile = ref.watch(profileProvider);
    final subscription = ref.watch(subscriptionProvider).value;

    final username = profile.value?['username'] ?? '';
    final isPremium = subscription?.isActive == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/settings/plans'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        username.isNotEmpty
                            ? username[0].toUpperCase()
                            : (user?.email?[0].toUpperCase() ?? '?'),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$username',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'FREE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gerir
          Text(
            'GERIR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Categorias'),
                  subtitle: const Text('Gerir categorias de despesas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoriesPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Perfil'),
                  subtitle: const Text('Nome de utilizador'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preferencias
          Text(
            'PREFERENCIAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Geral'),
                  subtitle: const Text('Tema, idioma, moeda'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PreferencesPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Relatórios por Email'),
                  subtitle: const Text(
                    'Recebe resumos mensais das tuas despesas',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/reports'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Conta
          Text(
            'CONTA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Conta'),
                  subtitle: const Text('Email, palavra-passe, plano, dados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sobre
          Text(
            'SOBRE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sobre'),
                  subtitle: const Text('Versão, termos, privacidade'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/about'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Terminar sessao no fundo
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Terminar Sessão',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    await PocketAuth.signOut();
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
