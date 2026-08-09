import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/currency_provider.dart';
import '../../config/theme_provider.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final currentCurrency = currencyByCode(currency);
    final currentTheme = ref.watch(themeNameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferências')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Temas'),
                  subtitle: Text(currentTheme),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/themes'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Idioma'),
                  subtitle: const Text('Português (em breve)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Traduções em breve')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      currentCurrency.symbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  title: const Text('Moeda'),
                  subtitle: Text(
                    '${currentCurrency.name} (${currentCurrency.code})',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/currency'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
