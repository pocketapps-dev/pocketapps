import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/currency_provider.dart';

class CurrencySettingsPage extends ConsumerWidget {
  const CurrencySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moeda')),
      body: RadioGroup<String>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) {
            ref.read(currencyProvider.notifier).setCurrency(value);
          }
        },
        child: ListView.separated(
          itemCount: currencies.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final currency = currencies[index];
            return RadioListTile<String>(
              secondary: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                child: Text(
                  currency.symbol,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              title: Text('${currency.name} (${currency.code})'),
              value: currency.code,
            );
          },
        ),
      ),
    );
  }
}
