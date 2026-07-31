import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/profile_provider.dart';

const currencies = [
  ('EUR', '€', 'Euro'),
  ('USD', '\$', 'Dólar Americano'),
  ('GBP', '£', 'Libra Esterlina'),
  ('BRL', 'R\$', 'Real Brasileiro'),
  ('JPY', '¥', 'Iene Japonês'),
  ('CHF', 'CHF', 'Franco Suíço'),
  ('CAD', 'CA\$', 'Dólar Canadense'),
  ('AUD', 'A\$', 'Dólar Australiano'),
  ('PLN', 'zł', 'Zloty Polaco'),
  ('CZK', 'Kč', 'Coroa Checa'),
];

class CurrencySettingsPage extends ConsumerWidget {
  const CurrencySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final current = settings.value?['currency'] ?? 'EUR';

    return Scaffold(
      appBar: AppBar(title: const Text('Moeda')),
      body: RadioGroup<String>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) {
            ref.read(profileActionsProvider).updateCurrency(value);
          }
        },
        child: ListView.separated(
          itemCount: currencies.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final (code, symbol, name) = currencies[index];
            return RadioListTile<String>(
              title: Text('$code ($symbol)'),
              subtitle: Text(name),
              value: code,
            );
          },
        ),
      ),
    );
  }
}
