import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = PocketAuth.client;
    final user = supabase.auth.currentUser;
    final isEmailUser = user?.identities?.any((i) => i.provider != 'google') ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
