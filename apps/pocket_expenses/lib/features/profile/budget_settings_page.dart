import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/profile_provider.dart';

class BudgetSettingsPage extends ConsumerStatefulWidget {
  const BudgetSettingsPage({super.key});

  @override
  ConsumerState<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends ConsumerState<BudgetSettingsPage> {
  final _budgetController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final budget = ref.read(settingsProvider).value?['monthly_budget'];
    if (budget != null) {
      _budgetController.text = budget.toString();
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final text = _budgetController.text.trim();
    double? budget;
    if (text.isNotEmpty) {
      budget = double.tryParse(text);
      if (budget == null || budget < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valor inválido'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }
    }
    await ref.read(profileActionsProvider).updateBudget(budget);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento atualizado!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamento Mensal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Define o teu orçamento mensal para acompanhamento.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Orçamento mensal',
                prefixIcon: Icon(Icons.account_balance_wallet),
                prefixText: '€ ',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _budgetController.clear();
              },
              child: const Text('Remover orçamento'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
